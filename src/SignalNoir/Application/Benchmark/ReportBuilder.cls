Class SignalNoir.Application.Benchmark.ReportBuilder Extends %RegisteredObject
{

/// The two-part report of a run and the comparison of runs (feature 010, FR-019 to FR-024).
/// It reads the run's items and the persisted Cases, hands the facts to the Core (Scorer,
/// Stats, Guarantees) and assembles the contract's BenchmarkReport. It changes no Case. A
/// report exists only once the run has completed; it is built and stored once.
Parameter SCORED = "clean,P5,P8,P9";

/// Builds the report of a run from its items (any status of the run). Result.obj = the report.
/// final: the report Store keeps, written by the Runner just before it marks the run completed
ClassMethod Build(runId As %String, final As %Boolean = 0) As SignalNoir.Core.Result
{
	Set run = ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%OpenId(runId)
	If '$IsObject(run) Return ##class(SignalNoir.Core.Result).Error("NOT_FOUND", "no such BenchmarkRun: " _ runId)
	Set cases = [], evidence = ..NewEvidence()
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT itemNo FROM SignalNoir_Application_Model.BenchmarkItemRecord WHERE runId = ? ORDER BY itemNo", runId)
	While rs.%Next() {
		Set item = ##class(SignalNoir.Application.Model.BenchmarkItemRecord).%OpenId(runId _ "||" _ rs.%Get("itemNo"))
		Do cases.%Push(..CaseRow(run, item, evidence))
	}
	Set report = {"runId": (run.runId), "mode": (run.mode), "purpose": (run.purpose)}
	Do report.%Set("provider", run.provider, $Select(run.provider = "": "null", 1: "string"))
	Do report.%Set("model", run.model, $Select(run.model = "": "null", 1: "string"))
	Set report.repetitions = run.repetitions
	Set report.policyVersion = run.policyVersion, report.mappingVersion = run.mappingVersion
	Set report.generatedAt = ##class(SignalNoir.Application.SystemClock).%New().NowUtc()
	Set report.labels = {"synthetic": true}
	Do report.labels.%Set("replay", (run.mode = "replay"), "boolean")
	Do report.%Set("development", run.development, "boolean")
	Do report.%Set("developmentReasons", $Select(run.developmentReasonsJson = "": [], 1: [].%FromJSON(run.developmentReasonsJson)))
	Do report.%Set("freezeId", run.freezeId, $Select(run.freezeId = "": "null", 1: "string"))
	Do report.%Set("publishableAsReference", ((run.purpose = "reference") && 'run.development && (final || (run.status = "completed"))), "boolean")
	Set report.reference = ..Reference(run, ##class(SignalNoir.Benchmark.Data.ReferenceResult).Load("Record"))
	Set report.setup = ..Setup(run, cases)
	If run.purpose = "quick_validation" Set report.quickValidation = ##class(SignalNoir.Application.Benchmark.QuickValidation).Results(cases, ##class(SignalNoir.Benchmark.Data.ReferenceResult).Load("Record"), report.reference.differsFromReference)
	Set report.agentDecision = ##class(SignalNoir.Core.Benchmark.Stats).Rows(cases, run.mode)
	Set report.platformGuarantees = ##class(SignalNoir.Core.Benchmark.Guarantees).Evaluate(..Finish(evidence))
	Set report.cases = cases
	Return ##class(SignalNoir.Core.Result).OkObj(report)
}

/// Builds and stores the final report of a run (once)
ClassMethod Store(runId As %String) As SignalNoir.Core.Result
{
	Set run = ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%OpenId(runId)
	If '$IsObject(run) Return ##class(SignalNoir.Core.Result).Error("NOT_FOUND", "no such BenchmarkRun: " _ runId)
	If run.reportJson '= "" Return ##class(SignalNoir.Core.Result).OkObj({}.%FromJSON(run.reportJson))
	Set built = ..Build(runId, 1)
	If 'built.ok Return built
	Set run.reportJson = built.obj.%ToJSON()
	$$$ThrowOnError(run.%Save())
	Return built
}

/// The final report of a run: NOT_FOUND for an unknown run and INVALID_TRANSITION (409) until
/// it has completed. A report is never partial (FR-024).
ClassMethod Report(runId As %String) As SignalNoir.Core.Result
{
	Set run = $Select(runId = "": "", 1: ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%OpenId(runId))
	If '$IsObject(run) Return ##class(SignalNoir.Core.Result).Error("NOT_FOUND", "no such BenchmarkRun: " _ runId)
	If run.status '= "completed" Return ##class(SignalNoir.Core.Result).Error("INVALID_TRANSITION", "the report is not ready: the run is " _ run.status)
	Return ..Store(runId)
}

/// The comparison of two to four completed runs over the same scenarios, side by side by mode.
/// Refuses (VALIDATION_FAILED) a replay run, a quick validation run and runs over different
/// scenarios; INVALID_TRANSITION if one has not completed; NOT_FOUND if one is unknown.
ClassMethod Compare(runIds As %DynamicArray) As SignalNoir.Core.Result
{
	If '$IsObject(runIds) || (runIds.%Size() < 2) || (runIds.%Size() > 4) Return ..Refuse("a comparison takes two to four runs")
	Set reports = [], sets = ""
	For i = 0 : 1 : runIds.%Size() - 1 {
		Set id = runIds.%Get(i)
		For j = 0 : 1 : i - 1 {
			If runIds.%Get(j) = id Return ..Refuse("a run is named twice: " _ id)
		}
		Set run = ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%OpenId(id)
		If '$IsObject(run) Return ##class(SignalNoir.Core.Result).Error("NOT_FOUND", "no such BenchmarkRun: " _ id)
		If run.mode = "replay" Return ..Refuse("a replay run never counts as a real run and is not compared: " _ id)
		If run.purpose = "quick_validation" Return ..Refuse("a quick validation run is not compared with benchmark or reference runs: " _ id)
		If run.status '= "completed" Return ##class(SignalNoir.Core.Result).Error("INVALID_TRANSITION", "the run has not completed: " _ id)
		Set scenarios = ..ScenarioSet(id)
		If (sets '= "") && (scenarios '= sets) Return ..Refuse("the runs are over different scenarios: " _ id)
		Set sets = scenarios
		Set r = ..Report(id)
		If 'r.ok Return r
		Do reports.%Push(r.obj)
	}
	Set rows = [], guarantees = [], setups = []
	For i = 0 : 1 : reports.%Size() - 1 {
		Set report = reports.%Get(i)
		For j = 0 : 1 : report.agentDecision.%Size() - 1 Do rows.%Push(report.agentDecision.%Get(j))
		For j = 0 : 1 : report.platformGuarantees.%Size() - 1 {
			Set row = {}.%FromJSON(report.platformGuarantees.%Get(j).%ToJSON())
			Set row.runId = report.runId
			Do guarantees.%Push(row)
		}
		Set one = {"runId": (report.runId), "mode": (report.mode), "purpose": (report.purpose), "policyVersion": (report.policyVersion), "mappingVersion": (report.mappingVersion)}
		Do one.%Set("provider", report.provider, $Select(report.%GetTypeOf("provider") = "string": "string", 1: "null"))
		Do one.%Set("model", report.model, $Select(report.%GetTypeOf("model") = "string": "string", 1: "null"))
		Do one.%Set("development", report.development, "boolean")
		Do setups.%Push(one)
	}
	Set out = {"runIds": (runIds), "generatedAt": (##class(SignalNoir.Application.SystemClock).%New().NowUtc()), "sameScenarioSet": true}
	Set out.agentDecision = rows, out.platformGuarantees = guarantees, out.setups = setups
	Return ##class(SignalNoir.Core.Result).OkObj(out)
}

/// The scenarios of a run as one comparable text: family and variant of each distinct item
ClassMethod ScenarioSet(runId As %String) As %String
{
	Set text = ""
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT DISTINCT family, variant FROM SignalNoir_Application_Model.BenchmarkItemRecord WHERE runId = ? ORDER BY family, variant", runId)
	While rs.%Next() {
		Set text = text _ rs.%Get("family") _ ":" _ rs.%Get("variant") _ ";"
	}
	Return text
}

/// One BenchmarkCaseResult for an item, and the platform evidence its Case adds
ClassMethod CaseRow(run As SignalNoir.Application.Model.BenchmarkRunRecord, item As SignalNoir.Application.Model.BenchmarkItemRecord, ByRef evidence) As %DynamicObject [ Private ]
{
	Set facts = ##class(SignalNoir.Application.Benchmark.CaseFacts).For(item)
	Set scored = ((","_..#SCORED_",") [ ("," _ item.family _ ","))
	Set key = $Select(scored: ##class(SignalNoir.Benchmark.Data.Base).KeyFor(item.variant), 1: "")
	If scored && '$IsObject(key) {
		Set score = {"outcome": null, "notDecidedReason": "no_answer_key", "blockedWrongProposals": 0}
		Do score.%Set("countsInMetrics", 1, "boolean")
		Do score.%Set("notDecided", 1, "boolean")
		Do score.%Set("wrongEffect", 0, "boolean")
	} ElseIf scored {
		Set score = ##class(SignalNoir.Core.Benchmark.Scorer).Score(key, facts)
	} Else {
		Set score = {"outcome": null, "notDecidedReason": null, "blockedWrongProposals": 0}
		Do score.%Set("countsInMetrics", 0, "boolean")
		Do score.%Set("notDecided", 0, "boolean")
		Do score.%Set("wrongEffect", 0, "boolean")
	}
	Set row = {"family": (item.family), "subtype": (item.subtype), "variant": (item.variant), "set": (item.set), "repetition": (item.repetition)}
	; a control that opened no Case has neither a caseId nor a final state: both are null
	Do row.%Set("caseId", item.caseId, $Select(item.caseId = "": "null", 1: "string"))
	Do row.%Set("finalState", $Select(facts.finalState = "NoCase": "", 1: facts.finalState), $Select(facts.finalState = "NoCase": "null", 1: "string"))
	If $IsObject(facts.effect) {
		Set row.action = facts.effect.action, row.actionParams = facts.effect.params
	} Else {
		Do row.%Set("action", "", "null")
		Do row.%Set("actionParams", "", "null")
	}
	Do row.%Set("confidence", "", "null")
	Set expected = {"acceptableActions": [], "acceptableStates": []}
	If $IsObject(key) {
		For i = 0 : 1 : key.acceptable.%Size() - 1 Do expected.acceptableActions.%Push(key.acceptable.%Get(i).action)
		If key.%GetTypeOf("acceptableStates") = "array" Set expected.acceptableStates = key.acceptableStates
	}
	Set row.expected = expected
	If score.%GetTypeOf("outcome") = "string" {
		Set row.outcome = score.outcome
	} Else {
		Do row.%Set("outcome", "", "null")
	}
	Do row.%Set("notDecidedReason", score.notDecidedReason, $Select(score.notDecidedReason = "": "null", 1: "string"))
	Do ..Measures(item.caseId, run.mode, row)
	Do row.%Set("replay", facts.replay, "boolean")
	Do row.%Set("countsInMetrics", ''(score.countsInMetrics && 'facts.replay), "boolean")
	Do row.%Set("touchedByPerson", facts.touchedByPerson, "boolean")
	Set row.blockedWrongProposals = score.blockedWrongProposals
	Do row.%Set("wrongEffect", score.wrongEffect, "boolean")
	Do ..Collect(item, evidence)
	Return row
}

/// The provider and model of the published reference run, and whether this run used others (FR-023):
/// a report from another provider or model says so. record: the committed ReferenceResult. A rules run
/// has no provider to compare. With no reference recorded yet the report says there is none.
ClassMethod Reference(run As SignalNoir.Application.Model.BenchmarkRunRecord, record) As %DynamicObject
{
	Set out = {}
	Set recorded = $IsObject(record) && (record.%GetTypeOf("provider") = "string") && (record.%GetTypeOf("model") = "string") && (record.provider '= "") && (record.model '= "")
	If 'recorded {
		Do out.%Set("provider", "", "null")
		Do out.%Set("model", "", "null")
		Do out.%Set("differsFromReference", 0, "boolean")
		Set out.warning = "no reference result is recorded yet, so this run is not compared with one"
		Return out
	}
	Set out.provider = record.provider, out.model = record.model
	Set differs = (run.mode '= "rules") && ((run.provider '= record.provider) || (run.model '= record.model))
	Do out.%Set("differsFromReference", ''differs, "boolean")
	If differs {
		Set out.warning = "this run used provider " _ run.provider _ " and model " _ run.model _ ", not the reference's " _ record.provider _ " and " _ record.model _ ": its numbers are not comparable with the published reference"
	} Else {
		Do out.%Set("warning", "", "null")
	}
	Return out
}

/// How the run was set up (CC-6): the versions it ran with, the freeze, the sets it covered and who held
/// which role (FR-023, FR-029). The roles and reviews are those committed in SignalNoir.Benchmark.Data;
/// reviewStatus says how each review was done (FreezeCheck.ReviewStatus), so a self-review is plain to see.
ClassMethod Setup(run As SignalNoir.Application.Model.BenchmarkRunRecord, cases As %DynamicArray) As %DynamicObject [ Private ]
{
	Set inputs = $Select(run.inputsDigestJson = "": {}, 1: {}.%FromJSON(run.inputsDigestJson))
	Set sets = "", fams = {}
	For i = 0 : 1 : cases.%Size() - 1 {
		Set c = cases.%Get(i)
		If (","_sets_",") '[ ("," _ c.set _ ",") Set sets = sets _ $Select(sets = "": "", 1: ",") _ c.set
		Do fams.%Set(c.family, 1)
	}
	Set roles = ##class(SignalNoir.Benchmark.Data.Roles).Load("Record"), shown = {}
	If $IsObject(roles) && (roles.%GetTypeOf("families") = "object") {
		Set it = fams.%GetIterator()
		While it.%GetNext(.family) {
			If roles.families.%GetTypeOf(family) = "object" Do shown.%Set(family, roles.families.%Get(family))
		}
	}
	Set setup = {"promptVersion": (inputs.%Get("promptVersion")), "baselineVersion": (inputs.%Get("baselineVersion")), "evaluatorVersion": (inputs.%Get("evaluatorVersion"))}
	Do setup.%Set("freezeId", run.freezeId, $Select(run.freezeId = "": "null", 1: "string"))
	Set setup.variantSet = $Select(sets = "tuning": "tuning", sets = "test": "test", 1: "mixed")
	Set reviews = ##class(SignalNoir.Benchmark.Data.Reviews).Load("Records"), names = ""
	Set it = fams.%GetIterator()
	While it.%GetNext(.family) { Set names = names _ $Select(names = "": "", 1: ",") _ family }
	Set setup.independence = {"roles": (shown), "reviews": (reviews), "reviewStatus": (##class(SignalNoir.Core.Benchmark.FreezeCheck).ReviewStatus(reviews, names))}
	Return setup
}

/// Latency, tool calls and estimated cost of the Case's last Investigation (null when it had none).
/// A rules run costs nothing: 0, not null.
ClassMethod Measures(caseId As %String, mode As %String, row As %DynamicObject) [ Private ]
{
	Set found = 0
	If caseId '= "" {
		Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 durationMs, toolCalls, estCostUsd FROM SignalNoir_Application_Model.InvestigationRecord WHERE caseId = ? ORDER BY startedAt DESC, investigationId DESC", caseId)
		If rs.%Next() {
			Set found = 1
			Do row.%Set("latencyMs", +rs.%Get("durationMs"), "number")
			Do row.%Set("toolCalls", +rs.%Get("toolCalls"), "number")
			Do row.%Set("estCostUsd", $Select(rs.%Get("estCostUsd") = "": $Select(mode = "rules": 0, 1: ""), 1: +rs.%Get("estCostUsd")), $Select((rs.%Get("estCostUsd") = "") && (mode '= "rules"): "null", 1: "number"))
		}
	}
	If 'found {
		Do row.%Set("latencyMs", "", "null")
		Do row.%Set("toolCalls", "", "null")
		Do row.%Set("estCostUsd", "", "null")
	}
}

ClassMethod NewEvidence() As %DynamicObject [ Private ]
{
	Return {
		"p3": {"exercised": 0, "staleExecutions": 0, "invalidActionsExecuted": 0},
		"idempotency": {"exercised": 0, "duplicateReceipts": 0},
		"timeout": {"exercised": 0, "resentBeforeReconcile": 0},
		"repeatedApproval": {"exercised": 0, "extraEffectiveApprovals": 0},
		"recoverySuite": ""
	}
}

/// What the run's executions show about the platform's promises (plan D10): added to the evidence
ClassMethod Collect(item As SignalNoir.Application.Model.BenchmarkItemRecord, evidence As %DynamicObject) [ Private ]
{
	If item.caseId = "" Quit
	If item.family = "P3" Set evidence.p3.exercised = evidence.p3.exercised + 1
	If item.subtype = "idempotency.repeated_approval" {
		Set evidence.repeatedApproval.exercised = evidence.repeatedApproval.exercised + 1
		Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT proposalId, COUNT(*) AS n FROM SignalNoir_Application_Model.ApprovalRecord WHERE caseId = ? AND decision = 'approved' AND status IN ('valid','consumed') GROUP BY proposalId", item.caseId)
		While rs.%Next() {
			If rs.%Get("n") > 1 Set evidence.repeatedApproval.extraEffectiveApprovals = evidence.repeatedApproval.extraEffectiveApprovals + rs.%Get("n") - 1
		}
	}
	; more than one Receipt for one effect is a duplicate
	Set dups = ##class(%SQL.Statement).%ExecDirect(, "SELECT idempotencyKey, COUNT(DISTINCT receiptId) AS n FROM SignalNoir_Application_Model.ReceiptCopyRecord WHERE caseId = ? GROUP BY idempotencyKey", item.caseId)
	While dups.%Next() {
		If dups.%Get("n") > 1 Set evidence.idempotency.duplicateReceipts = evidence.idempotency.duplicateReceipts + dups.%Get("n") - 1
	}
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT attemptsJson, reconciliationsJson, revalidationJson, action, idempotencyKey FROM SignalNoir_Application_Model.ExecutionRecord WHERE caseId = ?", item.caseId)
	While rs.%Next() {
		Set evidence.idempotency.exercised = evidence.idempotency.exercised + 1
		If '##class(SignalNoir.Core.Vocab).IsAction(rs.%Get("action")) Set evidence.p3.invalidActionsExecuted = evidence.p3.invalidActionsExecuted + 1
		Set attempts = $Select(rs.%Get("attemptsJson") = "": [], 1: [].%FromJSON(rs.%Get("attemptsJson")))
		Set reconciliations = $Select(rs.%Get("reconciliationsJson") = "": [], 1: [].%FromJSON(rs.%Get("reconciliationsJson")))
		If (rs.%Get("revalidationJson") '= "") && attempts.%Size() {
			Set reval = {}.%FromJSON(rs.%Get("revalidationJson"))
			If (reval.%GetTypeOf("passed") = "boolean") && 'reval.passed Set evidence.p3.staleExecutions = evidence.p3.staleExecutions + 1
		}
		Set uncertainAt = ""
		For i = 0 : 1 : attempts.%Size() - 1 {
			If attempts.%Get(i).responseClass = "uncertain" Set uncertainAt = $Select(uncertainAt = "": i, 1: uncertainAt)
		}
		If uncertainAt '= "" {
			Set evidence.timeout.exercised = evidence.timeout.exercised + 1
			If (attempts.%Size() > (uncertainAt + 1)) && 'reconciliations.%Size() Set evidence.timeout.resentBeforeReconcile = evidence.timeout.resentBeforeReconcile + 1
		}
	}
}

/// Duplicate Receipts per effect, over the Cases of the run, and the recorded recovery-suite evidence
ClassMethod Finish(evidence As %DynamicObject) As %DynamicObject [ Private ]
{
	Set evidence.recoverySuite = ..RecoverySuite()
	Return evidence
}

/// The recovery-suite evidence recorded with the published reference (Benchmark.Data.ReferenceResult),
/// or "" when none is recorded yet
ClassMethod RecoverySuite() As %DynamicAbstractObject
{
	Set class = "SignalNoir.Benchmark.Data.ReferenceResult"
	If '##class(%Dictionary.CompiledClass).%ExistsId(class) Return ""
	Set record = ##class(SignalNoir.Benchmark.Data.Base).Read(class, "Record")
	If '$IsObject(record) || (record.%GetTypeOf("recoverySuite") '= "object") Return ""
	Return record.recoverySuite
}

ClassMethod Refuse(message As %String) As SignalNoir.Core.Result [ Private ]
{
	Return ##class(SignalNoir.Core.Result).ErrorWith("VALIDATION_FAILED", message, {"errors": [(message)]})
}

}
