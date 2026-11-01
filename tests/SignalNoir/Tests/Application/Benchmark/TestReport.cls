Class SignalNoir.Tests.Application.Benchmark.TestReport Extends %UnitTest.TestCase
{

/// 010 T041 - the two-part report of a run (FR-019 to FR-024): the agent decision part by family,
/// subtype, set and mode; the platform guarantees part with no score; controls apart; replay
/// out of every metric; never a partial report. Cases are built as in TestScoringEndToEnd.
Parameter E = "SignalNoir.Tests.Application.Benchmark.TestScoringEndToEnd";

Parameter R = "SignalNoir.Application.Benchmark.ReportBuilder";

Method OnBeforeOneTest(testname As %String) As %Status
{
	Do ##class(SignalNoir.Application.Model.BenchmarkItemRecord).%KillExtent()
	Do ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%KillExtent()
	Return $$$OK
}

Method TestAReportHasTheFieldsOfTheContract()
{
	Do $ClassMethod(..#E, "Run", "run_rep_1")
	Do $ClassMethod(..#E, "Item", "run_rep_1", 1, "P8", "P8b", "P8b-tune-01", $ClassMethod(..#E, "Resolved", [{"mappingId": "map_glicj_plasma", "verdict": "accepted"}]))
	Set r = $ClassMethod(..#R, "Report", "run_rep_1")
	Do $$$AssertTrue(r.ok, "a completed run has a report: " _ r.message)
	Quit:'r.ok
	Set report = r.obj
	For key = "runId", "mode", "purpose", "generatedAt", "labels", "agentDecision", "platformGuarantees", "cases", "repetitions", "policyVersion", "mappingVersion", "development", "publishableAsReference" {
		Do $$$AssertTrue(report.%IsDefined(key), "the report has " _ key)
	}
	Do $$$AssertEquals(report.labels.synthetic, 1, "labelled synthetic")
	Do $$$AssertEquals(report.labels.replay, 0, "not a replay")
	Set c = report.cases.%Get(0)
	For key = "caseId", "family", "subtype", "variant", "set", "repetition", "finalState", "action", "actionParams", "expected", "outcome", "latencyMs", "toolCalls", "estCostUsd", "replay", "countsInMetrics", "touchedByPerson", "blockedWrongProposals", "wrongEffect", "notDecidedReason" {
		Do $$$AssertTrue(c.%IsDefined(key), "a Case row has " _ key)
	}
	Do $$$AssertEquals(c.expected.acceptableActions.%Get(0), "APPLY_APPROVED_MAPPING", "the answer key's Action is shown")
	Set row = report.agentDecision.%Get(0)
	For key = "family", "subtype", "set", "mode", "variantCount", "repetitionsCovered", "outcomes", "outcomesWithoutNotDecided", "counts", "denominator", "latencyMsP50", "latencyMsP95", "toolCallsPerCase", "estCostUsdPerCase", "blockedWrongProposals", "wrongEffects" {
		Do $$$AssertTrue(row.%IsDefined(key), "a row has " _ key)
	}
	Do $$$AssertEquals(row.mode, "rules", "by mode")
}

Method TestControlsAreNotInAFamilyScoreAndPlatformCasesAreNotInTheAgentDecision()
{
	Do $ClassMethod(..#E, "Run", "run_rep_2")
	Do $ClassMethod(..#E, "Item", "run_rep_2", 1, "P8", "P8b", "P8b-tune-01", $ClassMethod(..#E, "Resolved", [{"mappingId": "map_glicj_plasma", "verdict": "accepted"}]))
	Do $ClassMethod(..#E, "Item", "run_rep_2", 2, "clean", "clean.success", "clean-success-tune-01", "")
	Do $ClassMethod(..#E, "Item", "run_rep_2", 3, "P3", "P3.partner_fails_again", "P3-fails-tune-01", $ClassMethod(..#E, "Resolved", [{"mappingId": "map_glicj_plasma", "verdict": "accepted"}]))
	Set report = $ClassMethod(..#R, "Report", "run_rep_2").obj
	Set families = ""
	For i = 0 : 1 : report.agentDecision.%Size() - 1 Set families = families _ report.agentDecision.%Get(i).family _ ","
	Do $$$AssertTrue(families [ "P8,", "P8 has a row")
	Do $$$AssertTrue(families [ "clean,", "the clean control has a row of its own")
	Do $$$AssertTrue(families '[ "P5,", "P5 does not appear: it is not in the run")
	Do $$$AssertTrue(families '[ "P9,", "P9 does not appear unless it is part of the run")
	Do $$$AssertTrue(families '[ "P3,", "a platform scenario is not an agent-decision row")
	Set p3 = ""
	For i = 0 : 1 : report.cases.%Size() - 1 {
		If report.cases.%Get(i).family = "P3" Set p3 = report.cases.%Get(i)
	}
	Do $$$AssertEquals(p3.countsInMetrics, 0, "its Case is kept as raw data but counts in no agent metric")
	Set guarantee = ""
	For i = 0 : 1 : report.platformGuarantees.%Size() - 1 {
		If report.platformGuarantees.%Get(i).guarantee = "P3" Set guarantee = report.platformGuarantees.%Get(i)
	}
	Do $$$AssertEquals(guarantee.passed, 1, "P3 was exercised by the run and passed")
	Do $$$AssertEquals(report.platformGuarantees.%Size(), 6, "six guarantees")
}

Method TestReplayCasesAreLabelledAndLeftOutOfEveryMetric()
{
	Do $ClassMethod(..#E, "Run", "run_rep_3", "replay")
	Set caseId = $ClassMethod(..#E, "Resolved", [{"mappingId": "map_glicj_plasma", "verdict": "accepted"}])
	Set rec = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(caseId)
	Set rec.replay = 1
	$$$ThrowOnError(rec.%Save())
	Do $ClassMethod(..#E, "Item", "run_rep_3", 1, "P8", "P8b", "P8b-tune-01", caseId)
	Set report = $ClassMethod(..#R, "Report", "run_rep_3").obj
	Do $$$AssertEquals(report.labels.replay, 1, "the report says replay")
	Do $$$AssertEquals(report.cases.%Get(0).replay, 1, "the Case row says replay")
	Do $$$AssertEquals(report.cases.%Get(0).countsInMetrics, 0, "and counts in nothing")
	Do $$$AssertEquals(report.agentDecision.%Size(), 0, "no agent-decision row from a replay run")
}

Method TestAReportBeforeTheEndIsNotReady()
{
	Do $ClassMethod(..#E, "Run", "run_rep_4", "rules", "running")
	Set r = $ClassMethod(..#R, "Report", "run_rep_4")
	Do $$$AssertNotTrue(r.ok, "not ready")
	Do $$$AssertEquals(r.code, "INVALID_TRANSITION", "the contract's 409")
	Do $$$AssertEquals(##class(SignalNoir.Application.Model.BenchmarkRunRecord).%OpenId("run_rep_4").reportJson, "", "and nothing is stored")
	Do $ClassMethod(..#E, "Run", "run_rep_5", "rules", "failed")
	Do $$$AssertEquals($ClassMethod(..#R, "Report", "run_rep_5").code, "INVALID_TRANSITION", "a failed run offers no report either")
	Do $$$AssertEquals($ClassMethod(..#R, "Report", "run_rep_none").code, "NOT_FOUND", "an unknown run")
}

Method TestTheFinalReportIsWrittenOnce()
{
	Do $ClassMethod(..#E, "Run", "run_rep_6")
	Do $ClassMethod(..#E, "Item", "run_rep_6", 1, "P8", "P8b", "P8b-tune-01", $ClassMethod(..#E, "Resolved", [{"mappingId": "map_glicj_plasma", "verdict": "accepted"}]))
	Set first = $ClassMethod(..#R, "Report", "run_rep_6").obj
	Hang 0.05
	Set second = $ClassMethod(..#R, "Report", "run_rep_6").obj
	Do $$$AssertEquals(second.generatedAt, first.generatedAt, "the stored report is returned, not built again")
	Do $$$AssertTrue(##class(SignalNoir.Application.Model.BenchmarkRunRecord).%OpenId("run_rep_6").reportJson '= "", "it is stored with the run")
}

Method TestADevelopmentRunIsNotPublishableAsTheReference()
{
	Do $ClassMethod(..#E, "Run", "run_rep_7", "agent", "completed", "reference")
	Set rec = ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%OpenId("run_rep_7")
	Set rec.development = 1, rec.developmentReasonsJson = "[""a frozen input differs: prompt""]"
	$$$ThrowOnError(rec.%Save())
	Set report = $ClassMethod(..#R, "Report", "run_rep_7").obj
	Do $$$AssertEquals(report.development, 1, "marked development")
	Do $$$AssertEquals(report.publishableAsReference, 0, "not publishable as the reference")
	Do $$$AssertEquals(report.developmentReasons.%Get(0), "a frozen input differs: prompt", "and it says why")
}

Method TestRepetitionsGiveARangeAndAVariantCountsOnce()
{
	Do $ClassMethod(..#E, "Run", "run_rep_8", "rules", "completed", "benchmark", 2)
	Do $ClassMethod(..#E, "Item", "run_rep_8", 1, "P8", "P8b", "P8b-tune-01", $ClassMethod(..#E, "Resolved", [{"mappingId": "map_glicj_plasma", "verdict": "accepted"}]), 1)
	Do $ClassMethod(..#E, "Item", "run_rep_8", 2, "P8", "P8b", "P8b-tune-01", $ClassMethod(..#E, "Review"), 2)
	Set row = $ClassMethod(..#E, "Row", $ClassMethod(..#R, "Report", "run_rep_8").obj, "P8", "P8b", "tuning")
	Do $$$AssertEquals(row.variantCount, 1, "one variant, two repetitions")
	Do $$$AssertEquals(row.repetitionsCovered, 2, "two repetitions")
	Do $$$AssertEquals(row.outcomes.correct.min, 0, "correct in one repetition only: the range starts at 0")
	Do $$$AssertEquals(row.outcomes.correct.max, 1, "and ends at 1")
	Do $$$AssertEquals(row.denominator.withNotDecided.max, 1, "the repetition's denominator is the variants, not the runs")
}

}
