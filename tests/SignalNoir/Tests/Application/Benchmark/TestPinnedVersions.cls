Class SignalNoir.Tests.Application.Benchmark.TestPinnedVersions Extends %UnitTest.TestCase
{

Parameter STORE = "SignalNoir.Application.Reference.Store";

Parameter FIX = "SignalNoir.Tests.Application.Reference.Fixtures";

/// 010 T020 - a Case validates against the versions its run pinned, from its first
/// Proposal to its end, whatever the version in force becomes meanwhile (FR-006). The
/// Store's globals are saved and restored around each test, as TestStore does.
Method OnBeforeOneTest() As %Status
{
	Kill ^||SaveRef
	Merge ^||SaveRef = ^SignalNoir.Reference
	Kill ^SignalNoir.Reference
	Do $ClassMethod(..#STORE, "Load", "SignalNoir.Application.Reference")
	Do $ClassMethod(..#STORE, "Load", ..#FIX _ ".Good")
	Do $ClassMethod(..#STORE, "SetInForce", "2026.10.1", "2026.10.1")
	Do ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%KillExtent()
	Return $$$OK
}

Method OnAfterOneTest() As %Status
{
	Kill ^SignalNoir.Reference
	Merge ^SignalNoir.Reference = ^||SaveRef
	Kill ^||SaveRef
	Return $$$OK
}

ClassMethod PinnedRun(runId As %String, policy As %String, mapping As %String)
{
	Set run = ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%New()
	Set run.runId = runId, run.mode = "rules", run.purpose = "benchmark", run.status = "running"
	Set run.policyVersion = policy, run.mappingVersion = mapping
	$$$ThrowOnError(run.%Save())
}

Method TestARunPinsItsVersionsForItsCases()
{
	Do ..PinnedRun("run_pin_a", "2026.10.2", "2026.10.2")
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ##class(SignalNoir.Tests.Support).OpenCase(svc, ##class(SignalNoir.Tests.Support).Uid("pin"), "run_pin_a")
	Set rec = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(caseId)
	Do $$$AssertEquals(rec.runId, "run_pin_a", "the Case belongs to the run")
	Set run = ##class(SignalNoir.Application.ResolutionValidator).RunFor(rec)
	Do $$$AssertEquals(run.policyVersion _ ":" _ run.mappingVersion, "2026.10.2:2026.10.2", "RunFor carries the pins")
	Do $$$AssertEquals(run.inRun, 1, "in a run")
	Set input = ##class(SignalNoir.Application.ResolutionValidator).InputFor(rec, ##class(SignalNoir.Core.Dto.Proposal).%New(), "2026-10-31T12:00:00Z")
	Do $$$AssertEquals(input.reference.policyVersion _ ":" _ input.reference.mappingVersion, "2026.10.2:2026.10.2", "the Validator's reference data is the pinned version")
	Do $ClassMethod(..#STORE, "SetInForce", "2026.10.2", "2026.10.2")
	Do ..PinnedRun("run_pin_b", "2026.10.1", "2026.10.1")
	Set other = ##class(SignalNoir.Tests.Support).OpenCase(svc, ##class(SignalNoir.Tests.Support).Uid("pin"), "run_pin_b")
	Set input2 = ##class(SignalNoir.Application.ResolutionValidator).InputFor(##class(SignalNoir.Application.Model.CaseRecord).%OpenId(other), ##class(SignalNoir.Core.Dto.Proposal).%New(), "2026-10-31T12:00:00Z")
	Do $$$AssertEquals(input2.reference.policyVersion, "2026.10.1", "an older pin is kept after the version in force moved on")
	Set input3 = ##class(SignalNoir.Application.ResolutionValidator).InputFor(rec, ##class(SignalNoir.Core.Dto.Proposal).%New(), "2026-10-31T12:00:00Z")
	Do $$$AssertEquals(input3.reference.policyVersion, "2026.10.2", "and the first run's pin is unchanged")
}

Method TestACaseOutsideARunUsesTheVersionInForce()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ##class(SignalNoir.Tests.Support).OpenCase(svc, ##class(SignalNoir.Tests.Support).Uid("pin-none"))
	Set rec = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(caseId)
	Set run = ##class(SignalNoir.Application.ResolutionValidator).RunFor(rec)
	Do $$$AssertEquals(run.inRun, 0, "not in a run")
	Do $$$AssertEquals(run.%GetTypeOf("policyVersion"), "null", "no pin")
	Set input = ##class(SignalNoir.Application.ResolutionValidator).InputFor(rec, ##class(SignalNoir.Core.Dto.Proposal).%New(), "2026-10-31T12:00:00Z")
	Do $$$AssertEquals(input.reference.policyVersion, "2026.10.1", "the version in force")
	Do $ClassMethod(..#STORE, "SetInForce", "2026.10.2", "2026.10.2")
	Set input2 = ##class(SignalNoir.Application.ResolutionValidator).InputFor(rec, ##class(SignalNoir.Core.Dto.Proposal).%New(), "2026-10-31T12:00:00Z")
	Do $$$AssertEquals(input2.reference.policyVersion, "2026.10.2", "follows the version in force")
}

}
