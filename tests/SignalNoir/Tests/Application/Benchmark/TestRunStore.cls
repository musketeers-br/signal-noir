Class SignalNoir.Tests.Application.Benchmark.TestRunStore Extends %UnitTest.TestCase
{

Method OnBeforeOneTest(testname As %String) As %Status
{
	Do ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%KillExtent()
	Return $$$OK
}

Method TestFindReadsTheRecord()
{
	Set rec = ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%New()
	Set rec.runId = "run_store1", rec.mode = "replay", rec.purpose = "quick_validation", rec.status = "running"
	Set rec.policyVersion = "2026.10.1", rec.mappingVersion = "2026.10.2"
	$$$ThrowOnError(rec.%Save())
	Set found = ##class(SignalNoir.Application.Benchmark.RunStore).%New().Find("run_store1")
	Do $$$AssertEquals(found.runId, "run_store1", "runId")
	Do $$$AssertEquals(found.mode, "replay", "mode")
	Do $$$AssertEquals(found.status, "running", "status")
	Do $$$AssertEquals(found.purpose, "quick_validation", "purpose")
	Do $$$AssertEquals(found.policyVersion, "2026.10.1", "policy pin")
	Do $$$AssertEquals(found.mappingVersion, "2026.10.2", "mapping pin")
}

Method TestFindIsEmptyForWhatIsNotARun()
{
	Set store = ##class(SignalNoir.Application.Benchmark.RunStore).%New()
	Do $$$AssertEquals(store.Find("run_nothere"), "", "an unknown id")
	Do $$$AssertEquals(store.Find(""), "", "an empty id")
}

Method TestFindFollowsAStatusChange()
{
	Set rec = ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%New()
	Set rec.runId = "run_store2", rec.mode = "rules", rec.purpose = "benchmark", rec.status = "running"
	$$$ThrowOnError(rec.%Save())
	Set store = ##class(SignalNoir.Application.Benchmark.RunStore).%New()
	Do $$$AssertEquals(store.Find("run_store2").status, "running", "running")
	Set rec.status = "completed"
	$$$ThrowOnError(rec.%Save())
	Do $$$AssertEquals(store.Find("run_store2").status, "completed", "completed is seen at once")
}

}
