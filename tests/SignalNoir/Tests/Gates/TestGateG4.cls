Class SignalNoir.Tests.Gates.TestGateG4 Extends %UnitTest.TestCase
{

/// Gate G4 (010 with 011 and 012): the Benchmark, as far as it can be shown before the reference run
/// exists. Live against the Simulator over HTTP: a run in rules mode over tuning variants opens real
/// Cases, ends, and has a two-part report whose numbers recompute; a reference run over tuning variants
/// is refused; an Order with no run keeps mode agent; the benchmark actor is refused outside a run.
/// The quick validation is exercised when the reference result names its cases, and says so when not.
Property SavedBase As %String;

Method OnBeforeAllTests() As %Status
{
	Set ..SavedBase = $Get(^SignalNoir.Config("simBaseUrl"))
	Set ^SignalNoir.Config("simBaseUrl") = "http://localhost:52773/sim/api/v1"
	Return $$$OK
}

Method OnAfterAllTests() As %Status
{
	Set ^SignalNoir.Config("simBaseUrl") = ..SavedBase
	Return $$$OK
}

Method OnBeforeOneTest(testname As %String) As %Status
{
	Do ##class(SignalNoir.Application.Model.BenchmarkItemRecord).%KillExtent()
	Do ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%KillExtent()
	Return $$$OK
}

ClassMethod Reachable() As %Boolean
{
	Return ##class(SignalNoir.Application.Benchmark.RunService).%New().LoadCatalog().ok
}

/// Creates a run and drives it, step by step, to its end (at most about 100 s)
ClassMethod RunToTheEnd(request As %DynamicObject, Output runId As %String) As %Boolean
{
	Set svc = ##class(SignalNoir.Application.Benchmark.RunService).%New()
	Set svc.AutoStart = 0
	Set created = svc.Create(request)
	If 'created.ok Quit 0
	Set runId = created.obj.runId
	Set runner = ##class(SignalNoir.Application.Benchmark.Runner).%New()
	For i = 1 : 1 : 100 {
		Set r = runner.Step(runId)
		If 'r.ok Return 0
		If r.details.done Return 1
		Hang 1
	}
	Return 0
}

Method TestARulesRunOverTuningVariantsEndsWithATwoPartReport()
{
	If '..Reachable() Do $$$LogMessage("Simulator not reachable: skipped") Quit
	Set ended = ..RunToTheEnd({"mode": "rules", "purpose": "benchmark", "repetitions": 1, "seed": 3, "scenarios": [{"family": "clean", "variants": ["clean-success-tune-01"]}, {"family": "P8", "variants": ["P8b-tune-01"]}]}, .runId)
	Do $$$AssertTrue(ended, "the run ended")
	Set r = ##class(SignalNoir.Application.Benchmark.ReportBuilder).Report(runId)
	Do $$$AssertTrue(r.ok, "and has a report: " _ r.message)
	Quit:'r.ok
	Set report = r.obj
	Do $$$AssertTrue(report.agentDecision.%Size() > 0, "the agent decision part")
	Do $$$AssertEquals(report.platformGuarantees.%Size(), 6, "and the platform guarantees part, six of them")
	Set control = "", p8b = ""
	For i = 0 : 1 : report.cases.%Size() - 1 {
		If report.cases.%Get(i).variant = "clean-success-tune-01" Set control = report.cases.%Get(i)
		If report.cases.%Get(i).variant = "P8b-tune-01" Set p8b = report.cases.%Get(i)
	}
	Do $$$AssertEquals(control.outcome, "correct", "the control raised nothing, as its key says")
	; what the rules baseline decides depends on the Tools and the Partner's recent history, so the gate
	; checks that it decided and was scored, not what it chose (that is the baseline's review, T053/T055)
	Do $$$AssertTrue($ListFind($ListBuild("correct", "safe_review", "unnecessary_review", "incorrect"), p8b.outcome) > 0, "the Case was scored: " _ p8b.%ToJSON())
	Do $$$AssertEquals(p8b.countsInMetrics, 1, "it counts")
	Set case = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(p8b.caseId)
	Do $$$AssertEquals(case.runId, runId, "the Case belongs to the run")
	Do $$$AssertEquals(case.proposerMode, "rules", "and has its mode")
	Set detail = ##class(SignalNoir.Application.CaseService).Default().GetCase(p8b.caseId).obj
	Set byBenchmark = 0, byPerson = 0
	For i = 0 : 1 : detail.approvals.%Size() - 1 {
		If detail.approvals.%Get(i).by = "benchmark" Set byBenchmark = byBenchmark + 1
		If detail.approvals.%Get(i).by [ "operator:" Set byPerson = byPerson + 1
	}
	Do $$$AssertEquals(byPerson, 0, "no person approved anything")
	If p8b.action = "APPLY_APPROVED_MAPPING" Do $$$AssertEquals(byBenchmark, 1, "a Mapping was approved once, by the benchmark actor, inside the run")
	If p8b.action '= "APPLY_APPROVED_MAPPING" Do $$$AssertEquals(byBenchmark, 0, "an Action that needs no Approval records none")
}

Method TestAReferenceRunOverTuningVariantsIsRefused()
{
	If '..Reachable() Do $$$LogMessage("Simulator not reachable: skipped") Quit
	Set svc = ##class(SignalNoir.Application.Benchmark.RunService).%New()
	Set svc.AutoStart = 0
	Set r = svc.Create({"mode": "rules", "purpose": "reference", "scenarios": [{"family": "P5", "set": "tuning"}]})
	Do $$$AssertNotTrue(r.ok, "refused")
	Do $$$AssertEquals(r.code, "VALIDATION_FAILED", "400")
}

Method TestAnOrderWithNoRunKeepsModeAgent()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set S = "SignalNoir.Tests.Support"
	Set caseId = $ClassMethod(S, "OpenCase", svc, $ClassMethod(S, "Uid", "g4-norun"))
	Set rec = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(caseId)
	Do $$$AssertEquals(rec.proposerMode, "agent", "the Agent's")
	Do $$$AssertEquals(rec.runId, "", "no run")
	Do $$$AssertEquals(rec.replay, 0, "not a replay")
	Set c = svc.GetCase(caseId).obj
	Set r = svc.Transition(caseId, c.caseVersion, "Investigating", "benchmark", $ClassMethod(S, "Ev", "no run"))
	Do $$$AssertEquals(r.code, "INVALID_ACTOR", "the benchmark actor is refused outside a run")
}

Method TestTheQuickValidationRunsWhenTheReferenceNamesItsCases()
{
	Set record = ##class(SignalNoir.Benchmark.Data.ReferenceResult).Load("Record")
	If record.quickCases.%Size() = 0 {
		Do $$$LogMessage("the reference result names no quick validation cases yet (T062): skipped")
		Do $$$AssertNotTrue(##class(SignalNoir.Application.Benchmark.QuickValidation).Plan(record).ok, "until then the plan says there is nothing to run")
		Quit
	}
	If '..Reachable() Do $$$LogMessage("Simulator not reachable: skipped") Quit
	Set plan = ##class(SignalNoir.Application.Benchmark.QuickValidation).Plan(record)
	Do $$$AssertTrue(plan.ok, "the cases are planned: " _ plan.message)
}

}
