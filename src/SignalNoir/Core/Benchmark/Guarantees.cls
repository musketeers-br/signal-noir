Class SignalNoir.Core.Benchmark.Guarantees Extends %RegisteredObject
{

/// The platform guarantees part of a report (feature 010, FR-020, plan D10). Pure: counts in,
/// rows out. Each guarantee is passed or failed with its evidence, or not exercised (passed
/// is null) when the run held nothing that could test it: absence is not a pass (Principle
/// VII). There is no score and no comparison between modes: these guarantees hold whoever
/// proposes. Restart and late worker cannot be provoked through the Simulator; their
/// evidence is the recovery suite, recorded with the commit it ran on.
/// evidence: {p3: {exercised, staleExecutions, invalidActionsExecuted},
/// idempotency: {exercised, duplicateReceipts}, timeout: {exercised, resentBeforeReconcile},
/// repeatedApproval: {exercised, extraEffectiveApprovals},
/// recoverySuite: {restart: {passed, commit}, lateWorker: {passed, commit}} | ""}
ClassMethod Evaluate(evidence As %DynamicObject) As %DynamicArray
{
	Set rows = []
	Set p3 = evidence.p3
	Do rows.%Push(..FromRun("P3", p3.exercised, (p3.staleExecutions = 0) && (p3.invalidActionsExecuted = 0), {"duplicateReceipts": 0, "invalidActionsExecuted": (p3.invalidActionsExecuted), "staleExecutions": (p3.staleExecutions)}, p3.staleExecutions _ " executions with a stale precondition, " _ p3.invalidActionsExecuted _ " invalid Actions executed"))
	Set idem = evidence.idempotency
	Do rows.%Push(..FromRun("idempotency", idem.exercised, (idem.duplicateReceipts = 0), {"duplicateReceipts": (idem.duplicateReceipts), "invalidActionsExecuted": 0, "staleExecutions": 0}, idem.duplicateReceipts _ " duplicate Receipts over " _ idem.exercised _ " effects"))
	Set tm = evidence.timeout
	Do rows.%Push(..FromRun("timeout", tm.exercised, (tm.resentBeforeReconcile = 0), {"duplicateReceipts": 0, "invalidActionsExecuted": 0, "staleExecutions": 0}, tm.resentBeforeReconcile _ " resends before the Reconciliation over " _ tm.exercised _ " uncertain outcomes"))
	Do rows.%Push(..FromSuite("restart", evidence.recoverySuite, "restart"))
	Set ra = evidence.repeatedApproval
	Do rows.%Push(..FromRun("repeated_approval", ra.exercised, (ra.extraEffectiveApprovals = 0), {"duplicateReceipts": 0, "invalidActionsExecuted": 0, "staleExecutions": 0}, ra.extraEffectiveApprovals _ " extra effective Approvals over " _ ra.exercised _ " repeated decisions"))
	Do rows.%Push(..FromSuite("late_worker", evidence.recoverySuite, "lateWorker"))
	Return rows
}

ClassMethod FromRun(name As %String, exercised As %Integer, ok As %Boolean, counts As %DynamicObject, details As %String) As %DynamicObject [ Private ]
{
	Set row = {"guarantee": (name), "source": "run", "evidenceCommit": null}
	Set it = counts.%GetIterator()
	While it.%GetNext(.k, .v) {
		Do row.%Set(k, v)
	}
	If +exercised = 0 {
		Do row.%Set("passed", "", "null")
		Set row.details = "not exercised: the run held no scenario that tests " _ name
	} Else {
		Do row.%Set("passed", ''ok, "boolean")
		Set row.details = details
	}
	Return row
}

ClassMethod FromSuite(name As %String, suite, key As %String) As %DynamicObject [ Private ]
{
	Set row = {"guarantee": (name), "source": "recovery_suite", "duplicateReceipts": 0, "invalidActionsExecuted": 0, "staleExecutions": 0}
	Set found = $Select($IsObject(suite) && (suite.%GetTypeOf(key) = "object"): suite.%Get(key), 1: "")
	If '$IsObject(found) {
		Do row.%Set("passed", "", "null")
		Do row.%Set("evidenceCommit", "", "null")
		Set row.details = "not exercised: no recovery-suite evidence was recorded for " _ name
		Return row
	}
	Do row.%Set("passed", ''found.passed, "boolean")
	Set row.evidenceCommit = found.commit
	Set row.details = "recovery suite " _ $Select(found.passed: "passed", 1: "failed") _ " on commit " _ found.commit
	Return row
}

}
