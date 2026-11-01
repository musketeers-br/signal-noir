Class SignalNoir.Tests.Application.Benchmark.TestRunLifecycle Extends %UnitTest.TestCase
{

Property SavedBase As %String;

/// 010 T018 - creating a run: the plan, the pins, the one-run rule, and the read side
/// (FR-001, FR-002, FR-004, FR-005, FR-006). Reads the Simulator's catalog over HTTP; the
/// base URL is set for this class only (the baseline suite runs with it empty).
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

Method TestCreatePersistsTheRunAndItsPlan()
{
	If '..Reachable() Do $$$LogMessage("Simulator not reachable: skipped") Quit
	Set svc = ..Service()
	Set r = svc.Create({"mode": "rules", "purpose": "benchmark", "repetitions": 2, "seed": 11, "scenarios": [{"family": "P5", "set": "tuning"}]})
	Do $$$AssertTrue(r.ok, "created: " _ r.message)
	Quit:'r.ok
	Set run = r.obj
	Do $$$AssertTrue($Match(run.runId, "^run_[A-Za-z0-9_-]{4,64}$"), "a run id of the contract's form: " _ run.runId)
	Do $$$AssertEquals(run.status, "running", "created and started")
	Do $$$AssertEquals(run.mode, "rules", "mode")
	Do $$$AssertEquals(run.repetitions, 2, "repetitions")
	Do $$$AssertEquals(run.seed, 11, "seed")
	Set variants = svc.LoadCatalog().obj
	Set n = 0
	For i = 0 : 1 : variants.%Size() - 1 {
		If (variants.%Get(i).family = "P5") && (variants.%Get(i).set = "tuning") Set n = n + 1
	}
	Do $$$AssertTrue(n > 0, "P5 has tuning variants in the catalog")
	Do $$$AssertEquals(run.progress.casesPlanned, n * 2, "one item per variant and repetition")
	Do $$$AssertEquals(run.progress.casesOpened, 0, "nothing opened yet")
	Do $$$AssertEquals(run.progress.casesTerminal, 0, "nothing ended yet")
	Set items = ##class(%SQL.Statement).%ExecDirect(, "SELECT itemNo, variant, repetition, seed, status FROM SignalNoir_Application_Model.BenchmarkItemRecord WHERE runId = ? ORDER BY itemNo", run.runId)
	Set seen = 0
	While items.%Next() {
		Set seen = seen + 1
		Do $$$AssertEquals(items.%Get("status"), "planned", "item " _ seen _ " is planned")
		Do $$$AssertEquals(items.%Get("seed"), ##class(SignalNoir.Core.Benchmark.Seed).For(11, "P5", items.%Get("variant"), items.%Get("repetition")), "item " _ seen _ " has its derived seed")
	}
	Do $$$AssertEquals(seen, n * 2, "all items stored")
}

Method TestTheVersionsInForceArePinned()
{
	If '..Reachable() Do $$$LogMessage("Simulator not reachable: skipped") Quit
	Set force = ##class(SignalNoir.Application.Reference.Store).InForce().obj
	Set r = ..Service().Create({"mode": "rules", "purpose": "benchmark", "scenarios": [{"family": "P8", "variants": ["P8b-tune-01"]}]})
	Do $$$AssertTrue(r.ok, "created")
	Do $$$AssertEquals(r.obj.policyVersion, force.policyVersion, "policy in force is pinned")
	Do $$$AssertEquals(r.obj.mappingVersion, force.mappingVersion, "Mapping in force is pinned")
	Set stored = ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%OpenId(r.obj.runId)
	Do $$$AssertEquals(stored.policyVersion, force.policyVersion, "and stored")
}

Method TestAnExplicitFixtureSetIsPinnedOrRefused()
{
	If '..Reachable() Do $$$LogMessage("Simulator not reachable: skipped") Quit
	Set force = ##class(SignalNoir.Application.Reference.Store).InForce().obj
	Set ok = ..Service().Create({"mode": "rules", "purpose": "benchmark", "fixtureSet": {"policyVersion": (force.policyVersion), "mappingVersion": (force.mappingVersion)}, "scenarios": [{"family": "P8", "variants": ["P8b-tune-01"]}]})
	Do $$$AssertTrue(ok.ok, "an existing version is accepted")
	Do ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%KillExtent()
	Set bad = ..Service().Create({"mode": "rules", "purpose": "benchmark", "fixtureSet": {"policyVersion": "1999.01.1"}, "scenarios": [{"family": "P8", "variants": ["P8b-tune-01"]}]})
	Do $$$AssertNotTrue(bad.ok, "a version that does not exist is refused")
	Do $$$AssertEquals(bad.code, "VALIDATION_FAILED", "as a validation failure")
}

Method TestRulesModeIgnoresTheProvider()
{
	If '..Reachable() Do $$$LogMessage("Simulator not reachable: skipped") Quit
	Set r = ..Service().Create({"mode": "rules", "purpose": "benchmark", "provider": "openai", "model": "gpt", "scenarios": [{"family": "P8", "variants": ["P8b-tune-01"]}]})
	Do $$$AssertTrue(r.ok, "created")
	Do $$$AssertEquals(r.obj.%GetTypeOf("provider"), "null", "no provider in rules mode")
	Do $$$AssertEquals(r.obj.%GetTypeOf("model"), "null", "no model in rules mode")
}

Method TestAnAgentRunWithoutAProviderIsRefused()
{
	If '..Reachable() Do $$$LogMessage("Simulator not reachable: skipped") Quit
	If ##class(SignalNoir.Proposers.Factory).Ready("agent") Do $$$LogMessage("a provider is configured here: skipped") Quit
	Set r = ..Service().Create({"mode": "agent", "purpose": "benchmark", "scenarios": [{"family": "P8", "variants": ["P8b-tune-01"]}]})
	Do $$$AssertNotTrue(r.ok, "refused at creation, not left half done")
	Do $$$AssertEquals(r.code, "VALIDATION_FAILED", "code")
	Set n = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS n FROM SignalNoir_Application_Model.BenchmarkRunRecord")
	Do n.%Next()
	Do $$$AssertEquals(n.%Get("n"), 0, "nothing was stored")
}

Method TestOneRunAtATime()
{
	If '..Reachable() Do $$$LogMessage("Simulator not reachable: skipped") Quit
	Set svc = ..Service()
	Set request = {"mode": "rules", "purpose": "benchmark", "scenarios": [{"family": "P8", "variants": ["P8b-tune-01"]}]}
	Set first = svc.Create(request)
	Do $$$AssertTrue(first.ok, "the first run")
	Set second = svc.Create(request)
	Do $$$AssertNotTrue(second.ok, "a second run while one runs is refused")
	Do $$$AssertEquals(second.code, "INVALID_TRANSITION", "as a conflict")
	Set rec = ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%OpenId(first.obj.runId)
	Set rec.status = "completed"
	$$$ThrowOnError(rec.%Save())
	Set third = svc.Create(request)
	Do $$$AssertTrue(third.ok, "once it ended another may start")
}

Method TestGetAndListAreContractShaped()
{
	If '..Reachable() Do $$$LogMessage("Simulator not reachable: skipped") Quit
	Set svc = ..Service()
	Set a = svc.Create({"mode": "rules", "purpose": "benchmark", "label": "first", "scenarios": [{"family": "P8", "variants": ["P8b-tune-01"]}]})
	Set rec = ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%OpenId(a.obj.runId)
	Set rec.status = "completed", rec.completedAt = svc.Clock.NowUtc()
	$$$ThrowOnError(rec.%Save())
	Hang 1.1
	Set b = svc.Create({"mode": "rules", "purpose": "benchmark", "scenarios": [{"family": "P8", "variants": ["P8b-tune-02"]}]})
	Set got = svc.Get(b.obj.runId)
	Do $$$AssertTrue(got.ok, "get")
	Set run = got.obj
	For key = "runId", "mode", "purpose", "status", "createdAt", "repetitions", "scenarios", "progress", "labels", "policyVersion", "mappingVersion", "serverTime" {
		Do $$$AssertTrue(run.%IsDefined(key), "the run has " _ key)
	}
	Do $$$AssertEquals(run.labels.synthetic, 1, "synthetic label")
	Do $$$AssertEquals(run.labels.replay, 0, "not a replay")
	Do $$$AssertEquals(run.scenarios.%Get(0).family, "P8", "scenarios name the family")
	Do $$$AssertEquals(run.scenarios.%Get(0).variants.%Get(0), "P8b-tune-02", "and the explicit variants")
	Do $$$AssertEquals(run.scenarios.%Get(0).set, "tuning", "and the set")
	Set list = svc.List("", 20)
	Do $$$AssertEquals(list.obj.items.%Size(), 2, "both runs are listed")
	Do $$$AssertEquals(list.obj.items.%Get(0).runId, b.obj.runId, "newest first")
	Do $$$AssertTrue(list.obj.%IsDefined("serverTime"), "list has serverTime")
	Set done = svc.List("completed", 20)
	Do $$$AssertEquals(done.obj.items.%Size(), 1, "status filter")
	Do $$$AssertEquals(done.obj.items.%Get(0).runId, a.obj.runId, "the completed one")
	Do $$$AssertEquals(svc.List("", 1).obj.items.%Size(), 1, "limit")
	Do $$$AssertEquals(svc.List("bogus", 20).code, "VALIDATION_FAILED", "a bad status filter is refused")
	Set gone = svc.Get("run_missing")
	Do $$$AssertNotTrue(gone.ok, "unknown run")
	Do $$$AssertEquals(gone.code, "NOT_FOUND", "is NOT_FOUND")
}

}
