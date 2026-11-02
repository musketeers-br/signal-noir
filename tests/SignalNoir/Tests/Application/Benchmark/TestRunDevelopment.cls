Class SignalNoir.Tests.Application.Benchmark.TestRunDevelopment Extends %UnitTest.TestCase
{

/// 010 T050 - a run knows whether it can be the reference (FR-025 to FR-029): a reference over
/// tuning variants is refused; one whose frozen inputs differ, whose test set was used, or whose
/// roles are not distinct runs but is development data, with every reason, and its report says so.
/// A catalog and the committed records are injected, so no Simulator is needed.
Method OnBeforeOneTest(testname As %String) As %Status
{
	Do ##class(SignalNoir.Application.Model.BenchmarkItemRecord).%KillExtent()
	Do ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%KillExtent()
	Return $$$OK
}

/// The runs are created and never started (AutoStart 0): left behind, one would block the next
/// run of the namespace ("a BenchmarkRun is already created or running")
Method OnAfterOneTest(testname As %String) As %Status
{
	Return ..OnBeforeOneTest(testname)
}

ClassMethod Catalog() As %DynamicArray
{
	Return [
		{"family": "P5", "subtype": "P5", "variant": "P5-tune-01", "set": "tuning"},
		{"family": "P5", "subtype": "P5", "variant": "P5-test-01", "set": "test"},
		{"family": "P8", "subtype": "P8b", "variant": "P8b-tune-01", "set": "tuning"},
		{"family": "P8", "subtype": "P8b", "variant": "P8b-test-01", "set": "test"}
	]
}

ClassMethod Service(data As %DynamicObject = "") As SignalNoir.Application.Benchmark.RunService
{
	Set svc = ##class(SignalNoir.Application.Benchmark.RunService).%New()
	Set svc.AutoStart = 0
	Set svc.Catalog = ..Catalog()
	If $IsObject(data) Set svc.Data = data
	Return svc
}

ClassMethod Reference() As %DynamicObject
{
	Return {"mode": "rules", "purpose": "reference", "repetitions": 1, "scenarios": [{"family": "P5", "set": "test"}, {"family": "P8", "set": "test"}]}
}

/// Committed records that match the inputs of a rules run as they are now, with distinct roles and the reviews
ClassMethod Matching() As %DynamicObject
{
	Set force = ##class(SignalNoir.Application.Reference.Store).InForce().obj
	Set freeze = ##class(SignalNoir.Application.Benchmark.Inputs).Current("m", force.policyVersion, force.mappingVersion, ..Catalog())
	Set freeze.freezeId = "freeze_t", freeze.commit = "abc1234"
	Return {
		"freeze": (freeze),
		"roles": {"families": {"P5": {"answerKeyBy": "henrique", "baselineBy": "henry"}, "P8": {"answerKeyBy": "henrique", "baselineBy": "henry"}}},
		"reviews": [
			{"kind": "baseline", "family": "P5", "author": "henry", "reviewer": "jose", "commit": "r1", "date": "2026-11-03"},
			{"kind": "baseline", "family": "P8", "author": "henry", "reviewer": "jose", "commit": "r1", "date": "2026-11-03"},
			{"kind": "evaluator", "family": "*", "author": "henrique", "reviewer": "jose", "commit": "r2", "date": "2026-11-03"}
		],
		"usage": []
	}
}

Method TestAReferenceOverTuningVariantsIsRefused()
{
	Set r = ..Service().Create({"mode": "rules", "purpose": "reference", "scenarios": [{"family": "P5", "set": "tuning"}]})
	Do $$$AssertNotTrue(r.ok, "refused")
	Do $$$AssertEquals(r.code, "VALIDATION_FAILED", "400")
	Set mixed = ..Service().Create({"mode": "rules", "purpose": "reference", "scenarios": [{"family": "P5", "set": "test"}, {"family": "P8", "set": "tuning"}]})
	Do $$$AssertNotTrue(mixed.ok, "a mix is refused too")
}

/// The placeholder record is injected: since T056 the committed Freeze.cls holds a real freeze
Method TestWithNoFreezeTheRunIsDevelopmentAndSaysWhy()
{
	Set data = ..Matching()
	Set data.freeze = {"freezeId": "", "commit": "", "files": []}
	Set r = ..Service(data).Create(..Reference())
	Do $$$AssertTrue(r.ok, "it is created and runs: " _ r.message)
	Do $$$AssertEquals(r.obj.development, 1, "development")
	Do $$$AssertTrue(r.obj.developmentReasons.%ToJSON() [ "no freeze", "because nothing is frozen")
	Do $$$AssertEquals(r.obj.%GetTypeOf("freezeId"), "null", "no freeze id")
}

Method TestInputsThatMatchTheFreezeAreNotDevelopment()
{
	Set r = ..Service(..Matching()).Create(..Reference())
	Do $$$AssertTrue(r.ok, "created: " _ r.message)
	Do $$$AssertEquals(r.obj.development, 0, "not development: " _ r.obj.developmentReasons.%ToJSON())
	Do $$$AssertEquals(r.obj.freezeId, "freeze_t", "it records the freeze it ran under")
}

Method TestAChangedFrozenInputMakesItDevelopment()
{
	Set data = ..Matching()
	Set data.freeze.promptVersion = "agent-v0"
	Set r = ..Service(data).Create(..Reference())
	Do $$$AssertEquals(r.obj.development, 1, "development")
	Do $$$AssertTrue(r.obj.developmentReasons.%ToJSON() [ "promptVersion", "and the input is named")
}

Method TestAUsedTestSetMakesItDevelopment()
{
	Set data = ..Matching()
	Do data.usage.%Push({"set": "P5/test", "by": "henrique", "at": "2026-11-04", "why": "tuned the rules on it"})
	Set r = ..Service(data).Create(..Reference())
	Do $$$AssertEquals(r.obj.development, 1, "development")
	Do $$$AssertTrue(r.obj.developmentReasons.%ToJSON() [ "declared used", "a new reserved test is required")
}

Method TestRolesThatAreNotDistinctMakeItDevelopment()
{
	Set data = ..Matching()
	Set data.roles.families.P8.baselineBy = "henrique"
	Set r = ..Service(data).Create(..Reference())
	Do $$$AssertEquals(r.obj.development, 1, "development")
	Do $$$AssertTrue(r.obj.developmentReasons.%ToJSON() [ "P8", "for the family")
}

Method TestAFrozenInputThatChangesBeforeTheStartIsCaught()
{
	Set svc = ..Service(..Matching())
	Set r = svc.Create(..Reference())
	Do $$$AssertEquals(r.obj.development, 0, "not development at creation")
	Set rec = ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%OpenId(r.obj.runId)
	Set seen = {}.%FromJSON(rec.inputsDigestJson)
	Set seen.evaluatorVersion = "scorer-v0"
	Set rec.inputsDigestJson = seen.%ToJSON()
	$$$ThrowOnError(rec.%Save())
	Set runner = ##class(SignalNoir.Application.Benchmark.Runner).%New()
	Set runner.Service = svc
	Set runner.Sweep = 0
	Do runner.Step(r.obj.runId)
	Set after = ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%OpenId(r.obj.runId)
	Do $$$AssertEquals(after.development, 1, "the first step finds the difference")
	Do $$$AssertTrue(after.developmentReasonsJson [ "evaluatorVersion", "and names it")
}

Method TestTheReportSaysWhyAndIsNotPublishable()
{
	Set r = ..Service().Create(..Reference())
	Set rec = ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%OpenId(r.obj.runId)
	Set rec.status = "completed"
	$$$ThrowOnError(rec.%Save())
	Set report = ##class(SignalNoir.Application.Benchmark.ReportBuilder).Report(r.obj.runId).obj
	Do $$$AssertEquals(report.development, 1, "development")
	Do $$$AssertEquals(report.publishableAsReference, 0, "not publishable as the reference")
	Do $$$AssertTrue(report.developmentReasons.%Size() > 0, "with its reasons")
	For key = "promptVersion", "baselineVersion", "evaluatorVersion", "freezeId", "variantSet", "independence" {
		Do $$$AssertTrue(report.setup.%IsDefined(key), "the setup has " _ key)
	}
	Do $$$AssertEquals(report.setup.variantSet, "test", "the set it covered")
	Do $$$AssertTrue(report.setup.independence.%IsDefined("roles") && report.setup.independence.%IsDefined("reviews"), "and the independence metadata")
	Do $$$AssertEquals(report.setup.independence.reviewStatus.evaluator, "missing", "how each review was done: none is committed yet")
	Do $$$AssertEquals(report.setup.independence.reviewStatus.baseline.%Get("P5"), "missing", "per core family of the run")
}

/// The Runner stores the final report just before it marks the run completed: a reference run
/// that matches the freeze is publishable in that report (run_000241 was stored as not publishable)
Method TestTheStoredReportOfAMatchingReferenceRunIsPublishable()
{
	Set r = ..Service(..Matching()).Create(..Reference())
	Do $$$AssertEquals(r.obj.development, 0, "not development: " _ r.obj.developmentReasons.%ToJSON())
	Do $$$AssertNotEquals(r.obj.status, "completed", "not completed yet, as when the Runner stores the report")
	Set report = ##class(SignalNoir.Application.Benchmark.ReportBuilder).Store(r.obj.runId).obj
	Do $$$AssertEquals(report.publishableAsReference, 1, "publishable as the reference")
}

Method TestTuningResultsAreLabelledApart()
{
	Set r = ..Service().Create({"mode": "rules", "purpose": "benchmark", "repetitions": 1, "scenarios": [{"family": "P5", "set": "tuning"}]})
	Set rec = ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%OpenId(r.obj.runId)
	Set rec.status = "completed"
	$$$ThrowOnError(rec.%Save())
	Set report = ##class(SignalNoir.Application.Benchmark.ReportBuilder).Report(r.obj.runId).obj
	Do $$$AssertEquals(report.setup.variantSet, "tuning", "a tuning run says so")
	Do $$$AssertEquals(report.publishableAsReference, 0, "and is never the reference")
	For i = 0 : 1 : report.agentDecision.%Size() - 1 Do $$$AssertEquals(report.agentDecision.%Get(i).set, "tuning", "its rows carry the set")
}

}
