Class SignalNoir.Tests.Application.Benchmark.TestProviderDiffers Extends %UnitTest.TestCase
{

/// 010 T059 - a report from another provider or model than the published reference says so
/// (FR-023); with no reference recorded it says there is none; a rules run has nothing to compare.
Parameter R = "SignalNoir.Application.Benchmark.ReportBuilder";

ClassMethod Run(mode As %String, provider As %String, model As %String) As SignalNoir.Application.Model.BenchmarkRunRecord
{
	Set run = ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%New()
	Set run.runId = "run_prov", run.mode = mode, run.purpose = "benchmark", run.provider = provider, run.model = model
	Return run
}

Method TestTheSameProviderAndModelDoNotWarn()
{
	Set ref = $ClassMethod(..#R, "Reference", ..Run("agent", "openai", "m1"), {"provider": "openai", "model": "m1"})
	Do $$$AssertEquals(ref.differsFromReference, 0, "same")
	Do $$$AssertEquals(ref.provider, "openai", "the reference's provider is shown")
	Do $$$AssertEquals(ref.model, "m1", "and its model")
	Do $$$AssertEquals(ref.%GetTypeOf("warning"), "null", "no warning")
}

Method TestAnotherModelOrProviderWarns()
{
	Set ref = $ClassMethod(..#R, "Reference", ..Run("agent", "openai", "m2"), {"provider": "openai", "model": "m1"})
	Do $$$AssertEquals(ref.differsFromReference, 1, "another model")
	Do $$$AssertTrue(ref.warning [ "m2", "the warning names what this run used")
	Do $$$AssertTrue(ref.warning [ "m1", "and the reference's")
	Set ref = $ClassMethod(..#R, "Reference", ..Run("agent", "other", "m1"), {"provider": "openai", "model": "m1"})
	Do $$$AssertEquals(ref.differsFromReference, 1, "another provider")
}

Method TestWithNoReferenceRecordedTheReportSaysSo()
{
	Set ref = $ClassMethod(..#R, "Reference", ..Run("agent", "openai", "m1"), {"provider": null, "model": null})
	Do $$$AssertEquals(ref.%GetTypeOf("provider"), "null", "no provider")
	Do $$$AssertEquals(ref.differsFromReference, 0, "no claim of a difference")
	Do $$$AssertTrue(ref.warning [ "no reference result", "it says there is none")
	Set ref2 = $ClassMethod(..#R, "Reference", ..Run("agent", "openai", "m1"), "")
	Do $$$AssertTrue(ref2.warning [ "no reference result", "an absent record too")
}

Method TestARulesRunHasNothingToCompare()
{
	Set ref = $ClassMethod(..#R, "Reference", ..Run("rules", "", ""), {"provider": "openai", "model": "m1"})
	Do $$$AssertEquals(ref.differsFromReference, 0, "a rules run uses no model")
}

Method TestTheReportCarriesIt()
{
	Do ##class(SignalNoir.Application.Model.BenchmarkItemRecord).%KillExtent()
	Do ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%KillExtent()
	Do $ClassMethod("SignalNoir.Tests.Application.Benchmark.TestScoringEndToEnd", "Run", "run_prov2")
	Set report = ##class(SignalNoir.Application.Benchmark.ReportBuilder).Report("run_prov2").obj
	Do $$$AssertTrue(report.%IsDefined("reference"), "the report has a reference section")
	Do $$$AssertTrue(report.reference.%IsDefined("differsFromReference"), "with the verdict")
}

}
