Class SignalNoir.Tests.Api.TestBenchmarkApi Extends %UnitTest.TestCase
{

Property SavedBase As %String;

/// 010 T026 - the benchmark routes of contracts/openapi-signalnoir.yaml: create (202 with
/// Location), get, list, and the closed error envelope. The handlers return
/// {status, headers, body}; the route methods only write them, so no HTTP is needed here
/// (the same split as the other dispatch tests). The Simulator's catalog is read over HTTP.
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

ClassMethod Service() As SignalNoir.Application.Benchmark.RunService
{
	Set svc = ##class(SignalNoir.Application.Benchmark.RunService).%New()
	Set svc.AutoStart = 0
	Return svc
}

ClassMethod Reachable() As %Boolean
{
	Return ##class(SignalNoir.Application.Benchmark.RunService).%New().LoadCatalog().ok
}

ClassMethod Create(body As %DynamicObject) As %DynamicObject
{
	Return ##class(SignalNoir.Api.BenchmarkDispatch).HandleCreate(body.%ToJSON(), ..Service())
}

Method TestCreateAnswers202WithLocation()
{
	If '..Reachable() Do $$$LogMessage("Simulator not reachable: skipped") Quit
	Set r = ..Create({"mode": "rules", "purpose": "benchmark", "scenarios": [{"family": "P8", "variants": ["P8b-tune-01"]}]})
	Do $$$AssertEquals(r.status, "202 Accepted", "accepted for execution")
	Do $$$AssertTrue($Match(r.body.runId, "^run_[A-Za-z0-9_-]{4,64}$"), "a contract run id")
	Do $$$AssertEquals(r.headers.Location, "/benchmark-runs/" _ r.body.runId, "Location names the run")
	Do $$$AssertEquals(r.body.status, "running", "started")
	Do $$$AssertEquals(r.body.labels.synthetic, 1, "labelled synthetic")
}

Method TestMalformedAndRefusedRequestsAre400()
{
	If '..Reachable() Do $$$LogMessage("Simulator not reachable: skipped") Quit
	Set bad = ##class(%DynamicArray).%New()
	Do bad.%Push("not json {")
	Do bad.%Push("[]")
	Do bad.%Push("{""mode"": ""rules"", ""purpose"": ""benchmark"", ""scenarios"": []}")
	Do bad.%Push("{""mode"": ""oracle"", ""purpose"": ""benchmark"", ""scenarios"": [{""family"": ""P5""}]}")
	Do bad.%Push("{""mode"": ""rules"", ""purpose"": ""reference"", ""scenarios"": [{""family"": ""P5"", ""set"": ""tuning""}]}")
	For i = 0 : 1 : bad.%Size() - 1 {
		Set r = ##class(SignalNoir.Api.BenchmarkDispatch).HandleCreate(bad.%Get(i), ..Service())
		Do $$$AssertEquals(r.status, "400 Bad Request", "request " _ i _ " is refused")
		Do $$$AssertEquals(r.body.error.code, "VALIDATION_FAILED", "request " _ i _ ": the closed envelope")
	}
}

Method TestASecondRunWhileOneRunsIs409()
{
	If '..Reachable() Do $$$LogMessage("Simulator not reachable: skipped") Quit
	Set body = {"mode": "rules", "purpose": "benchmark", "scenarios": [{"family": "P8", "variants": ["P8b-tune-01"]}]}
	Do ..Create(body)
	Set r = ..Create(body)
	Do $$$AssertEquals(r.status, "409 Conflict", "refused while a run runs")
	Do $$$AssertEquals(r.body.error.code, "INVALID_TRANSITION", "with the contract's code")
}

Method TestGetAndListAndNotFound()
{
	If '..Reachable() Do $$$LogMessage("Simulator not reachable: skipped") Quit
	Set created = ..Create({"mode": "rules", "purpose": "benchmark", "scenarios": [{"family": "P8", "variants": ["P8b-tune-01"]}]})
	Set runId = created.body.runId
	Set got = ##class(SignalNoir.Api.BenchmarkDispatch).HandleGet(runId)
	Do $$$AssertEquals(got.status, "200 OK", "get")
	Do $$$AssertEquals(got.body.runId, runId, "the run")
	Do $$$AssertEquals(got.body.progress.casesPlanned, 3, "with its progress (one variant, k = 3 by default): " _ got.body.progress.%ToJSON())
	Set missing = ##class(SignalNoir.Api.BenchmarkDispatch).HandleGet("run_nothere")
	Do $$$AssertEquals(missing.status, "404 Not Found", "an unknown run is 404")
	Do $$$AssertEquals(missing.body.error.code, "NOT_FOUND", "NOT_FOUND")
	Set list = ##class(SignalNoir.Api.BenchmarkDispatch).HandleList("", "")
	Do $$$AssertEquals(list.status, "200 OK", "list")
	Do $$$AssertEquals(list.body.items.%Get(0).runId, runId, "newest first")
	Do $$$AssertTrue(list.body.%IsDefined("serverTime"), "serverTime")
	Do $$$AssertEquals(##class(SignalNoir.Api.BenchmarkDispatch).HandleList("completed", "").body.items.%Size(), 0, "status filter")
	Do $$$AssertEquals(##class(SignalNoir.Api.BenchmarkDispatch).HandleList("bogus", "").status, "400 Bad Request", "a bad status is 400")
	Do $$$AssertEquals(##class(SignalNoir.Api.BenchmarkDispatch).HandleList("", "500").status, "400 Bad Request", "a limit past 100 is 400")
	Do $$$AssertEquals(##class(SignalNoir.Api.BenchmarkDispatch).HandleList("", "abc").status, "400 Bad Request", "a limit that is not a number is 400")
}

}
