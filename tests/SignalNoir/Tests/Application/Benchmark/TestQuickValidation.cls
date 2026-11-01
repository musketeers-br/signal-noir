Class SignalNoir.Tests.Application.Benchmark.TestQuickValidation Extends %UnitTest.TestCase
{

/// 010 T066 - the quick validation (FR-033, FR-034): three recorded reference cases, a control, a
/// P5 or P8b case and a Dossier case, each compared with the recorded result as "matches the
/// reference" or "diverged" with the reason; a run of its own purpose that is never mixed into the
/// benchmark or reference results. The reference result is injected: it exists only once the
/// reference run does.
Parameter Q = "SignalNoir.Application.Benchmark.QuickValidation";

Method OnBeforeOneTest(testname As %String) As %Status
{
	Do ##class(SignalNoir.Application.Model.BenchmarkItemRecord).%KillExtent()
	Do ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%KillExtent()
	Return $$$OK
}

ClassMethod Record() As %DynamicObject
{
	Return {
		"provider": "openai", "model": "m1", "seed": 7,
		"quickCases": ["clean-success-test-01/1", "P8b-test-01/1", "clean-ambiguous-identity-test-01/1"],
		"cases": [
			{"referenceCase": "clean-success-test-01/1", "family": "clean", "variant": "clean-success-test-01", "repetition": 1, "finalState": "NoCase", "action": null, "params": {}},
			{"referenceCase": "P8b-test-01/1", "family": "P8", "variant": "P8b-test-01", "repetition": 1, "finalState": "Resolved", "action": "APPLY_APPROVED_MAPPING", "params": {"mappingId": "map_glicj_soro"}},
			{"referenceCase": "clean-ambiguous-identity-test-01/1", "family": "clean", "variant": "clean-ambiguous-identity-test-01", "repetition": 1, "finalState": "ReviewRequired", "action": null, "params": {}},
			{"referenceCase": "P5-test-01/1", "family": "P5", "variant": "P5-test-01", "repetition": 1, "finalState": "Resolved", "action": "APPLY_APPROVED_MAPPING", "params": {"mappingId": "map_glicj_soro"}}
		]
	}
}

ClassMethod Catalog() As %DynamicArray
{
	Return [
		{"family": "clean", "subtype": "clean.success", "variant": "clean-success-test-01", "set": "test"},
		{"family": "P8", "subtype": "P8b", "variant": "P8b-test-01", "set": "test"},
		{"family": "clean", "subtype": "clean.ambiguous_identity", "variant": "clean-ambiguous-identity-test-01", "set": "test"}
	]
}

Method TestThePlanIsThreeCasesOfTheRightKinds()
{
	Set r = $ClassMethod(..#Q, "Plan", ..Record())
	Do $$$AssertTrue(r.ok, "planned: " _ r.message)
	Quit:'r.ok
	Do $$$AssertEquals(r.obj.purpose, "quick_validation", "a purpose of its own")
	Do $$$AssertEquals(r.obj.repetitions, 1, "once")
	Do $$$AssertEquals(r.obj.seed, 7, "with the recorded seed")
	Do $$$AssertEquals(r.obj.scenarios.%Size(), 3, "three cases")
}

Method TestTheCompositionIsChecked()
{
	Set two = ..Record()
	Set two.quickCases = ["P8b-test-01/1", "P5-test-01/1", "clean-ambiguous-identity-test-01/1"]
	Do $$$AssertNotTrue($ClassMethod(..#Q, "Plan", two).ok, "two P5/P8b cases and no control is refused")
	Set four = ..Record()
	Do four.quickCases.%Push("P5-test-01/1")
	Do $$$AssertNotTrue($ClassMethod(..#Q, "Plan", four).ok, "four cases are refused")
	Set unknown = ..Record()
	Set unknown.quickCases = ["clean-success-test-01/1", "P8b-test-01/1", "nope/1"]
	Do $$$AssertNotTrue($ClassMethod(..#Q, "Plan", unknown).ok, "a case the reference does not have")
	Do $$$AssertNotTrue($ClassMethod(..#Q, "Plan", {"quickCases": [], "cases": []}).ok, "no cases named yet")
	Do $$$AssertNotTrue($ClassMethod(..#Q, "Plan", "").ok, "no record at all")
}

Method TestP9TakesThePlaceOfTheControl()
{
	Set rec = ..Record()
	Do rec.cases.%Push({"referenceCase": "P9-test-01/1", "family": "P9", "variant": "P9-test-01", "repetition": 1, "finalState": "ResolvedByPriorReceipt", "action": "REQUEST_REVIEW", "params": {}})
	Set rec.quickCases = ["P9-test-01/1", "P8b-test-01/1", "clean-ambiguous-identity-test-01/1"]
	Do $$$AssertTrue($ClassMethod(..#Q, "Plan", rec).ok, "P9 replaces the clean control")
}

/// A reference result copied from the report's Case rows has finalState null for a control (the
/// report writes no Case as null): it is the same control as one written NoCase
Method TestAControlRecordedAsNullIsAControl()
{
	Set rec = ..Record()
	Do rec.cases.%Get(0).%Set("finalState", "", "null")
	Set r = $ClassMethod(..#Q, "Plan", rec)
	Do $$$AssertTrue(r.ok, "the plan reads a null final state as no Case: " _ r.message)
	Set out = $ClassMethod(..#Q, "Results", [{"caseId": "", "variant": "clean-success-test-01", "finalState": null, "action": null, "actionParams": null}], rec, 0)
	Do $$$AssertEquals(out.%Get(0).status, "matches_reference", "and a control with no Case matches it: " _ out.%Get(0).reason)
}

/// quickCases names one repetition of a variant; the Case is compared with that repetition, not
/// with the variant's first recording
Method TestTheNamedRepetitionIsTheReference()
{
	Set rec = ..Record()
	Do rec.cases.%Push({"referenceCase": "P8b-test-01/2", "family": "P8", "variant": "P8b-test-01", "repetition": 2, "finalState": "Resolved", "action": "APPLY_APPROVED_MAPPING", "params": {"mappingId": "map_glicj_plasma"}})
	Set rec.quickCases = ["clean-success-test-01/1", "P8b-test-01/2", "clean-ambiguous-identity-test-01/1"]
	Do $$$AssertTrue($ClassMethod(..#Q, "Plan", rec).ok, "planned")
	Set row = {"caseId": "case_q2", "variant": "P8b-test-01", "repetition": 1, "finalState": "Resolved", "action": "APPLY_APPROVED_MAPPING", "actionParams": {"mappingId": "map_glicj_plasma"}}
	Set out = $ClassMethod(..#Q, "Results", [(row)], rec, 0)
	Do $$$AssertEquals(out.%Get(0).referenceCase, "P8b-test-01/2", "compared with the named repetition")
	Do $$$AssertEquals(out.%Get(0).status, "matches_reference", "which it matches: " _ out.%Get(0).reason)
}

Method TestTheModeIsTheAgentOnlyWithAProvider()
{
	Do $$$AssertEquals($ClassMethod(..#Q, "ModeFor", 1), "agent", "a provider is configured")
	Do $$$AssertEquals($ClassMethod(..#Q, "ModeFor", 0), "replay", "none: replay, deterministic and needing no key")
}

Method TestStartCreatesARunOfItsOwnPurpose()
{
	Set svc = ##class(SignalNoir.Application.Benchmark.RunService).%New()
	Set svc.AutoStart = 0
	Set svc.Catalog = ..Catalog()
	Set r = $ClassMethod(..#Q, "Start", svc, ..Record())
	Do $$$AssertTrue(r.ok, "started: " _ r.message)
	Quit:'r.ok
	Do $$$AssertEquals(r.obj.purpose, "quick_validation", "purpose")
	Do $$$AssertEquals(r.obj.progress.casesPlanned, 3, "three Cases")
	Do $$$AssertEquals(r.obj.mode, $ClassMethod(..#Q, "ModeFor", ##class(SignalNoir.Proposers.Factory).Ready("agent")), "the mode follows the provider")
}

Method TestEachCaseIsComparedWithItsReference()
{
	Set cases = [
		{"caseId": "", "variant": "clean-success-test-01", "finalState": null, "action": null, "actionParams": null},
		{"caseId": "case_q2", "variant": "P8b-test-01", "finalState": "Resolved", "action": "APPLY_APPROVED_MAPPING", "actionParams": {"mappingId": "map_glicj_plasma"}},
		{"caseId": "case_q3", "variant": "clean-ambiguous-identity-test-01", "finalState": "ReviewRequired", "action": null, "actionParams": null}
	]
	Set out = $ClassMethod(..#Q, "Results", cases, ..Record(), 0)
	Do $$$AssertEquals(out.%Size(), 3, "one result per Case")
	Do $$$AssertEquals(out.%Get(0).status, "matches_reference", "the control matches")
	Do $$$AssertEquals(out.%Get(0).referenceCase, "clean-success-test-01/1", "against its reference case")
	Do $$$AssertEquals(out.%Get(1).status, "diverged", "the Mapping differs")
	Do $$$AssertTrue(out.%Get(1).reason [ "parameters", "and the reason says so")
	Do $$$AssertEquals(out.%Get(2).status, "matches_reference", "the Dossier case matches")
	Set unknown = $ClassMethod(..#Q, "Results", [{"caseId": "c", "variant": "not-recorded", "finalState": "Resolved"}], ..Record(), 0)
	Do $$$AssertEquals(unknown.%Get(0).status, "diverged", "a variant with no recorded reference diverges")
	Do $$$AssertTrue(unknown.%Get(0).reason [ "no reference result", "and says why")
}

Method TestTheReportOfAQuickRunHasTheSectionAndIsKeptApart()
{
	Do ##class(SignalNoir.Tests.Application.Benchmark.TestScoringEndToEnd).Run("run_quick_1", "replay", "completed", "quick_validation", 1)
	Do ##class(SignalNoir.Tests.Application.Benchmark.TestScoringEndToEnd).Item("run_quick_1", 1, "clean", "clean.success", "clean-success-tune-01", "")
	Set report = ##class(SignalNoir.Application.Benchmark.ReportBuilder).Report("run_quick_1").obj
	Do $$$AssertTrue(report.%IsDefined("quickValidation"), "a quick run's report has quickValidation")
	Do $$$AssertEquals(report.quickValidation.%Size(), 1, "one result per Case")
	Do ##class(SignalNoir.Tests.Application.Benchmark.TestScoringEndToEnd).Run("run_quick_2", "rules", "completed", "benchmark", 1)
	Do ##class(SignalNoir.Tests.Application.Benchmark.TestScoringEndToEnd).Item("run_quick_2", 1, "clean", "clean.success", "clean-success-tune-01", "")
	Set other = ##class(SignalNoir.Application.Benchmark.ReportBuilder).Report("run_quick_2").obj
	Do $$$AssertNotTrue(other.%IsDefined("quickValidation"), "another purpose has none")
	Set cmp = ##class(SignalNoir.Application.Benchmark.ReportBuilder).Compare(["run_quick_1", "run_quick_2"])
	Do $$$AssertNotTrue(cmp.ok, "a quick validation run is never compared with benchmark or reference runs")
}

}
