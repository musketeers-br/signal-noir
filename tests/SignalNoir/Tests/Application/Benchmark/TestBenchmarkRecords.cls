Class SignalNoir.Tests.Application.Benchmark.TestBenchmarkRecords Extends %UnitTest.TestCase
{

Method OnBeforeOneTest(testname As %String) As %Status
{
	Do ##class(SignalNoir.Application.Model.BenchmarkItemRecord).%KillExtent()
	Do ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%KillExtent()
	Return $$$OK
}

Method TestARunSavesAndReloads()
{
	Set rec = ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%New()
	Set rec.runId = "run_rec001", rec.mode = "rules", rec.purpose = "benchmark", rec.seed = 11, rec.repetitions = 2
	Set rec.policyVersion = "2026.10.1", rec.mappingVersion = "2026.10.1"
	Set rec.scenariosJson = "[{""family"":""P5"",""set"":""tuning""}]"
	Do $$$AssertStatusOK(rec.%Save(), "saved")
	Set back = ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%OpenId("run_rec001")
	Do $$$AssertEquals(back.mode, "rules", "mode")
	Do $$$AssertEquals(back.status, "created", "status defaults to created")
	Do $$$AssertEquals(back.casesPlanned, 0, "progress defaults to zero")
	Do $$$AssertEquals(back.development, 0, "development defaults to false")
	Do $$$AssertEquals(back.policyVersion, "2026.10.1", "pins are stored")
	Do $$$AssertEquals(back.scenariosJson, rec.scenariosJson, "selection is stored")
}

Method TestTheRunIdIsUnique()
{
	Set a = ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%New()
	Set a.runId = "run_rec002", a.mode = "rules", a.purpose = "benchmark"
	Do $$$AssertStatusOK(a.%Save(), "first save")
	Set b = ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%New()
	Set b.runId = "run_rec002", b.mode = "agent", b.purpose = "benchmark"
	Do $$$AssertStatusNotOK(b.%Save(), "a second run with the same id is refused")
	Do $$$AssertEquals(##class(SignalNoir.Application.Model.BenchmarkRunRecord).%OpenId("run_rec002").mode, "rules", "the first stays")
}

Method TestAnItemIsUniquePerRunAndNumber()
{
	Set a = ##class(SignalNoir.Application.Model.BenchmarkItemRecord).%New()
	Set a.runId = "run_rec003", a.itemNo = 1, a.family = "P5", a.variant = "P5-tune-01", a.set = "tuning", a.repetition = 1
	Do $$$AssertStatusOK(a.%Save(), "item saved")
	Set back = ##class(SignalNoir.Application.Model.BenchmarkItemRecord).%OpenId("run_rec003||1")
	Do $$$AssertEquals(back.status, "planned", "an item starts planned")
	Do $$$AssertEquals(back.variant, "P5-tune-01", "variant")
	Set dup = ##class(SignalNoir.Application.Model.BenchmarkItemRecord).%New()
	Set dup.runId = "run_rec003", dup.itemNo = 1, dup.family = "P8"
	Do $$$AssertStatusNotOK(dup.%Save(), "the same (run, itemNo) is refused")
	Set other = ##class(SignalNoir.Application.Model.BenchmarkItemRecord).%New()
	Set other.runId = "run_rec003", other.itemNo = 2, other.family = "P8"
	Do $$$AssertStatusOK(other.%Save(), "another number of the same run is fine")
}

}
