Class SignalNoir.Tests.Application.Benchmark.TestRunnerObserves Extends %UnitTest.TestCase
{

Property SavedBase As %String;

/// 010 T022 - the runner creates the tagged scenario instances over the Simulator's HTTP
/// contract, lets the product open and drive the Cases, and only observes (FR-007).
/// Live: needs the Simulator. The base URL is set for this class only.
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

ClassMethod Start(variants As %DynamicArray, Output why As %String) As %String
{
	Set svc = ##class(SignalNoir.Application.Benchmark.RunService).%New()
	Set svc.AutoStart = 0
	Set r = svc.Create({"mode": "rules", "purpose": "benchmark", "repetitions": 1, "seed": 5, "scenarios": [{"family": "P8", "variants": (variants)}]})
	Set why = $Select(r.ok: "", 1: r.code _ ": " _ r.message)
	Return $Select(r.ok: r.obj.runId, 1: "")
}

Method TestARunOpensItsCasesAndEnds()
{
	If '..Reachable() Do $$$LogMessage("Simulator not reachable: skipped") Quit
	Set runId = ..Start(["P8b-tune-01", "P8b-tune-02"])
	Do $$$AssertTrue(runId '= "", "run created")
	Set runner = ##class(SignalNoir.Application.Benchmark.Runner).%New()
	Set done = 0
	For i = 1 : 1 : 90 {
		Set r = runner.Step(runId)
		Do $$$AssertTrue(r.ok, "step " _ i _ " is a value, not an error")
		Quit:'r.ok
		If r.details.done Set done = 1
		Quit:done
		Hang 1
	}
	Do $$$AssertTrue(done, "the run ended within the time allowed")
	Set rec = ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%OpenId(runId)
	Do $$$AssertEquals(rec.status, "completed", "completed")
	Do $$$AssertTrue(rec.completedAt '= "", "with a completion time")
	Set items = ##class(%SQL.Statement).%ExecDirect(, "SELECT variant, status, caseId, scenarioInstanceId FROM SignalNoir_Application_Model.BenchmarkItemRecord WHERE runId = ? ORDER BY itemNo", runId)
	Set seen = 0
	While items.%Next() {
		Set seen = seen + 1
		Do $$$AssertTrue((items.%Get("status") = "ended") || (items.%Get("status") = "not_decided"), items.%Get("variant") _ " reached an end: " _ items.%Get("status"))
		Do $$$AssertTrue(items.%Get("scenarioInstanceId") '= "", items.%Get("variant") _ " has its Simulator instance")
		If items.%Get("caseId") '= "" {
			Set case = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(items.%Get("caseId"))
			Do $$$AssertEquals(case.runId, runId, items.%Get("variant") _ ": the Case carries the run")
			Do $$$AssertEquals(case.proposerMode, "rules", items.%Get("variant") _ ": and the run's mode")
		}
	}
	Do $$$AssertEquals(seen, 2, "both items")
}

Method TestAStepTwiceDoesNotDuplicateAnInstance()
{
	If '..Reachable() Do $$$LogMessage("Simulator not reachable: skipped") Quit
	Set runId = ..Start(["P8b-tune-01"])
	Set runner = ##class(SignalNoir.Application.Benchmark.Runner).%New()
	Set runner.Sweep = 0
	Do runner.Step(runId)
	Set first = ##class(SignalNoir.Application.Model.BenchmarkItemRecord).%OpenId(runId _ "||1").scenarioInstanceId
	Do $$$AssertTrue(first '= "", "the first step created the instance")
	Do runner.Step(runId)
	Do runner.Step(runId)
	Set item = ##class(SignalNoir.Application.Model.BenchmarkItemRecord).%OpenId(runId _ "||1")
	Do $$$AssertEquals(item.scenarioInstanceId, first, "the same instance after more steps")
	Set n = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS n FROM SignalNoir_Application_Model.OrderRecord WHERE scenarioInstanceId = ?", first)
	Do n.%Next()
	Do $$$AssertEquals(n.%Get("n"), 1, "and one Order came from it")
}

Method TestACaseThatDoesNotDecideInTimeIsNotDecided()
{
	If '..Reachable() Do $$$LogMessage("Simulator not reachable: skipped") Quit
	Set runId = ..Start(["P8b-tune-01"], .why)
	Do $$$AssertTrue(runId '= "", "run created: " _ why)
	Quit:(runId = "")
	Set runner = ##class(SignalNoir.Application.Benchmark.Runner).%New()
	Set runner.Sweep = 0, runner.ItemSeconds = 0
	; the deadline is the instant the Case opened and a time stamp has a resolution of one second:
	; step until the item is past it, for as long as that takes (at most 20 s)
	Set until = $ZHorolog + 20
	While $ZHorolog < until {
		Do runner.Step(runId)
		Set status = ##class(SignalNoir.Application.Model.BenchmarkItemRecord).%OpenId(runId _ "||1").status
		If (status '= "planned") && (status '= "opened") Quit
		Hang 0.25
	}
	Set item = ##class(SignalNoir.Application.Model.BenchmarkItemRecord).%OpenId(runId _ "||1")
	Do $$$AssertTrue((item.status = "not_decided") || (item.status = "ended"), "decided or not decided by now: " _ item.status)
	If item.status = "not_decided" Do $$$AssertEquals(item.notDecidedReason, "deadline", "the reason is the deadline")
}

}
