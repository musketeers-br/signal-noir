Class SignalNoir.Tests.Application.Benchmark.TestScoringEndToEnd Extends %UnitTest.TestCase
{

/// 010 T034 - from persisted Cases to the numbers of the report: the facts are read from the
/// Cases, the evaluator scores them against the answer keys, the statistics count them. The
/// Cases are built directly (final state, Proposals, executions, Dossier) so each outcome is known.
Parameter F = "SignalNoir.Tests.Application.Benchmark.TestCaseFacts";

Method OnBeforeOneTest(testname As %String) As %Status
{
	Do ##class(SignalNoir.Application.Model.BenchmarkItemRecord).%KillExtent()
	Do ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%KillExtent()
	Return $$$OK
}

/// A run record (default: completed, rules, benchmark)
ClassMethod Run(runId As %String, mode As %String = "rules", status As %String = "completed", purpose As %String = "benchmark", repetitions As %Integer = 1)
{
	Set run = ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%New()
	Set run.runId = runId, run.mode = mode, run.purpose = purpose, run.status = status, run.repetitions = repetitions
	Set run.policyVersion = "2026.10.1", run.mappingVersion = "2026.10.1", run.createdAt = "2026-11-01T00:00:00Z"
	$$$ThrowOnError(run.%Save())
}

/// An item of a run; caseId may be "" (a scenario that raised no exception)
ClassMethod Item(runId As %String, no As %Integer, family As %String, subtype As %String, variant As %String, caseId As %String = "", repetition As %Integer = 1, set As %String = "tuning")
{
	Set item = ##class(SignalNoir.Application.Model.BenchmarkItemRecord).%New()
	Set item.runId = runId, item.itemNo = no, item.family = family, item.subtype = subtype, item.variant = variant
	Set item.set = set, item.repetition = repetition, item.caseId = caseId, item.status = "ended"
	$$$ThrowOnError(item.%Save())
}

/// A Case that was resolved by applying a Mapping (the Proposals are given as a list of
/// {mappingId, verdict}; the last one is executed)
ClassMethod Resolved(mappings As %DynamicArray) As %String
{
	Set caseId = $ClassMethod(..#F, "NewCase", "Resolved")
	For i = 0 : 1 : mappings.%Size() - 1 {
		Set m = mappings.%Get(i)
		Set last = $ClassMethod(..#F, "Proposal", caseId, "APPLY_APPROVED_MAPPING", {"mappingId": (m.mappingId)}.%ToJSON(), m.verdict)
	}
	Do $ClassMethod(..#F, "Execution", caseId, last, "APPLY_APPROVED_MAPPING")
	Return caseId
}

ClassMethod Review(providerDown As %Boolean = 0) As %String
{
	Set caseId = $ClassMethod(..#F, "NewCase", "ReviewRequired")
	Do $ClassMethod(..#F, "Proposal", caseId, "REQUEST_REVIEW", "{}", "accepted")
	If providerDown {
		Set d = ##class(SignalNoir.Application.Model.DossierRecord).%New()
		Set d.caseId = caseId, d.createdAt = "2026-11-01T00:00:09Z", d.reason = "provider_unavailable", d.dossierJson = "{}"
		$$$ThrowOnError(d.%Save())
	}
	Return caseId
}

ClassMethod Outcome(report As %DynamicObject, variant As %String) As %DynamicObject
{
	For i = 0 : 1 : report.cases.%Size() - 1 {
		If report.cases.%Get(i).variant = variant Return report.cases.%Get(i)
	}
	Return ""
}

ClassMethod Row(report As %DynamicObject, family As %String, subtype As %String, set As %String) As %DynamicObject
{
	For i = 0 : 1 : report.agentDecision.%Size() - 1 {
		Set r = report.agentDecision.%Get(i)
		If (r.family = family) && (r.subtype = subtype) && (r.set = set) Return r
	}
	Return ""
}

Method TestKnownCasesAreScoredAsTheTableSays()
{
	Do ..Run("run_e2e_1")
	Do ..Item("run_e2e_1", 1, "P8", "P8b", "P8b-tune-01", ..Resolved([{"mappingId": "map_glicj_plasma", "verdict": "accepted"}]))
	Do ..Item("run_e2e_1", 2, "P8", "P8b", "P8b-tune-02", ..Resolved([{"mappingId": "map_glicj_plasma", "verdict": "blocked"}, {"mappingId": "map_glicj_soro", "verdict": "accepted"}]))
	Do ..Item("run_e2e_1", 3, "clean", "clean.ambiguous_identity", "clean-ambiguous-identity-tune-01", ..Review())
	Do ..Item("run_e2e_1", 4, "P5", "P5", "P5-tune-01", ..Review())
	Do ..Item("run_e2e_1", 5, "P5", "P5", "P5-tune-02", ..Review(1))
	Do ..Item("run_e2e_1", 6, "P5", "P5", "P5-tune-03", ..Resolved([{"mappingId": "map_glicj_plasma", "verdict": "accepted"}]))
	Do ..Item("run_e2e_1", 7, "clean", "clean.success", "clean-success-tune-01", "")
	Set built = ##class(SignalNoir.Application.Benchmark.ReportBuilder).Build("run_e2e_1")
	Do $$$AssertTrue(built.ok, "the report is built: " _ built.message)
	Quit:'built.ok
	Set report = built.obj
	Do $$$AssertEquals(..Outcome(report, "P8b-tune-01").outcome, "correct", "the right Mapping")
	Set second = ..Outcome(report, "P8b-tune-02")
	Do $$$AssertEquals(second.outcome, "correct", "a wrong Proposal that the Validator blocked, then the right one")
	Do $$$AssertEquals(second.blockedWrongProposals, 1, "the blocked wrong Proposal is counted")
	Do $$$AssertEquals(second.wrongEffect, 0, "and it is not a wrong effect")
	Do $$$AssertEquals(..Outcome(report, "clean-ambiguous-identity-tune-01").outcome, "safe_review", "a needed review")
	Do $$$AssertEquals(..Outcome(report, "P5-tune-01").outcome, "unnecessary_review", "an unneeded review")
	Set down = ..Outcome(report, "P5-tune-02")
	Do $$$AssertEquals(down.%GetTypeOf("outcome"), "null", "a provider outage has no outcome")
	Do $$$AssertEquals(down.notDecidedReason, "provider_unavailable", "and says why")
	Set wrong = ..Outcome(report, "P5-tune-03")
	Do $$$AssertEquals(wrong.outcome, "incorrect", "the plasma Mapping on a serum Order")
	Do $$$AssertEquals(wrong.wrongEffect, 1, "a wrong effect was sent")
	Do $$$AssertEquals(..Outcome(report, "clean-success-tune-01").outcome, "correct", "a control that raised nothing")
	Set p8 = ..Row(report, "P8", "P8b", "tuning")
	Do $$$AssertEquals(p8.counts.correct.max, 2, "P8b: two correct")
	Do $$$AssertEquals(p8.blockedWrongProposals.max, 1, "one blocked wrong Proposal, as its own column")
	Do $$$AssertEquals(p8.wrongEffects.max, 0, "and no wrong effect")
	Set p5 = ..Row(report, "P5", "P5", "tuning")
	Do $$$AssertEquals(p5.counts.notDecided.max, 1, "P5: one not decided")
	Do $$$AssertEquals(p5.counts.%Get("unnecessary_review").max, 1, "one unnecessary review")
	Do $$$AssertEquals(p5.counts.incorrect.max, 1, "one incorrect")
	Do $$$AssertEquals(p5.counts.%Get("safe_review").max, 0, "the outage is not a safe review")
	Do $$$AssertEquals(p5.denominator.withNotDecided.max, 3, "denominator with the Case that did not decide")
	Do $$$AssertEquals(p5.denominator.withoutNotDecided.max, 2, "and without it")
	Do $$$AssertEquals(p5.wrongEffects.max, 1, "one wrong effect")
}

}
