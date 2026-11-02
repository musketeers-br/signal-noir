Class SignalNoir.Tests.Application.Benchmark.TestRunDirectorySeam Extends %UnitTest.TestCase
{

/// 010 T004 - the port of the run directory exists in the Core and both the fake and
/// the application adapter implement it (plan D2)
Method TestPortAndImplementations()
{
	Set port = "SignalNoir.Core.Port.RunDirectory"
	Do $$$AssertTrue(##class(%Dictionary.CompiledClass).%ExistsId(port), "the port exists")
	Do $$$AssertTrue(##class(%Dictionary.CompiledMethod).%ExistsId(port _ "||Find"), "the port declares Find")
	Do $$$AssertTrue($ClassMethod("SignalNoir.Tests.Fakes.FakeRunDirectory", "%Extends", port), "the fake implements it")
	Do $$$AssertTrue($ClassMethod("SignalNoir.Application.Benchmark.RunStore", "%Extends", port), "RunStore implements it")
}

Method TestFakeAnswers()
{
	Set fake = ##class(SignalNoir.Tests.Fakes.FakeRunDirectory).%New()
	Do fake.Add({"runId": "run_one1", "mode": "rules", "status": "running", "purpose": "benchmark", "policyVersion": "", "mappingVersion": ""})
	Do $$$AssertEquals(fake.Find("run_one1").mode, "rules", "a registered run is found")
	Do $$$AssertEquals(fake.Find("run_none"), "", "an unknown run is empty")
	Do $$$AssertEquals(fake.Find(""), "", "an empty id is empty")
}

}
