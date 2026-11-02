Class SignalNoir.Tests.Application.Benchmark.TestReplay Extends %UnitTest.TestCase
{

/// 010 T063 - a recorded response (Replay) is found by the reference case, not by the Order, which
/// differs on every scenario instance; its evidence references are resolved to the Evidence of the
/// Case being replayed; and a replay Case is labelled replay wherever it is shown (FR-031, FR-032).
Method OnBeforeOneTest(testname As %String) As %Status
{
	Do ##class(SignalNoir.Application.Model.BenchmarkItemRecord).%KillExtent()
	Do ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%KillExtent()
	Return $$$OK
}

/// A Case of a scenario instance that the item points at, and the context an Investigation gives the proposer
ClassMethod Context(variant As %String, repetition As %Integer, ByRef caseId As %String) As SignalNoir.Core.Dto.InvestigationContext
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set orderId = ##class(SignalNoir.Tests.Support).Uid("replay")
	Set caseId = ##class(SignalNoir.Tests.Support).OpenCase(svc, orderId)
	Set orderRec = ##class(SignalNoir.Application.Model.OrderRecord).%OpenId(orderId)
	Set orderRec.scenarioInstanceId = "sci_" _ $Translate(orderId, "-", "_")
	$$$ThrowOnError(orderRec.%Save())
	Set item = ##class(SignalNoir.Application.Model.BenchmarkItemRecord).%New()
	Set item.runId = "run_replay", item.itemNo = 1, item.family = "P8", item.variant = variant, item.repetition = repetition, item.scenarioInstanceId = orderRec.scenarioInstanceId
	$$$ThrowOnError(item.%Save())
	Set context = ##class(SignalNoir.Core.Dto.InvestigationContext).%New()
	Set context.case = svc.GetCase(caseId).obj
	Set context.order = ""
	Set ev = ##class(SignalNoir.Core.Dto.Evidence).%New()
	Set ev.evidenceId = "evid_replay_" _ $Increment(^SignalNoir.TestSeq), ev.source = "tool.mapping_catalog", ev.kind = "fact"
	Do context.evidence.Insert(ev)
	Set ev2 = ##class(SignalNoir.Core.Dto.Evidence).%New()
	Set ev2.evidenceId = "evid_replay_" _ $Increment(^SignalNoir.TestSeq), ev2.source = "system.exception", ev2.kind = "fact"
	Do context.evidence.Insert(ev2)
	Return context
}

ClassMethod Reference(variant As %String, repetition As %Integer) As %DynamicObject
{
	Set answer = {}.%FromJSON(##class(SignalNoir.Tests.Support).P8bAnswer())
	Return {"cases": [{"referenceCase": (variant _ "/" _ repetition), "family": "P8", "variant": (variant), "repetition": (repetition), "finalState": "Resolved", "action": "APPLY_APPROVED_MAPPING", "params": {"mappingId": "map_glicj_soro"}, "answer": (answer)}]}
}

Method TestTheAnswerIsFoundByTheReferenceCase()
{
	Set context = ..Context("P8b-test-01", 1, .caseId)
	Set replay = ##class(SignalNoir.Proposers.Replay).%New()
	Set replay.Reference = ..Reference("P8b-test-01", 1)
	Set r = replay.Propose(context)
	Do $$$AssertTrue(r.ok, "found: " _ r.message)
	Quit:'r.ok
	Do $$$AssertEquals(r.obj.action, "APPLY_APPROVED_MAPPING", "the recorded Action")
	Do $$$AssertEquals(r.obj.params.mappingId, "map_glicj_soro", "with its parameters")
	Do $$$AssertEquals(r.details.provider, "replay", "authored as a replay, never a real run")
}

/// In a quick validation run the item is always repetition 1, but quickCases may name another
/// repetition of the variant: Replay plays that one, the one the run is compared with. Any other run
/// keeps the item's own repetition.
Method TestAQuickValidationReplaysTheNamedRepetition()
{
	Set context = ..Context("P8b-test-01", 1, .caseId)
	Set reference = ..Reference("P8b-test-01", 1)
	Set second = ..Reference("P8b-test-01", 2).cases.%Get(0)
	Set second.answer = {}.%FromJSON($Replace(second.answer.%ToJSON(), "map_glicj_soro", "map_glicj_plasma"))
	Do reference.cases.%Push(second)
	Set reference.quickCases = ["P8b-test-01/2"]
	Set run = ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%New()
	Set run.runId = "run_replay", run.mode = "replay", run.purpose = "quick_validation", run.status = "running"
	$$$ThrowOnError(run.%Save())
	Set replay = ##class(SignalNoir.Proposers.Replay).%New()
	Set replay.Reference = reference
	Set r = replay.Propose(context)
	Do $$$AssertTrue(r.ok, "found: " _ r.message)
	Quit:'r.ok
	Do $$$AssertEquals(r.obj.params.mappingId, "map_glicj_plasma", "the named repetition 2, not the item's repetition 1")
	Set run.purpose = "benchmark"
	$$$ThrowOnError(run.%Save())
	Set r = replay.Propose(context)
	Do $$$AssertEquals(r.obj.params.mappingId, "map_glicj_soro", "a benchmark run keeps the item's repetition")
}

Method TestEvidenceReferencesPointAtTheEvidenceOfThisCase()
{
	Set context = ..Context("P8b-test-01", 1, .caseId)
	Set replay = ##class(SignalNoir.Proposers.Replay).%New()
	Set replay.Reference = ..Reference("P8b-test-01", 1)
	Set r = replay.Propose(context)
	Set text = r.obj.%ToJSON()
	Do $$$AssertTrue(text '[ "@ev:", "no placeholder is left")
	Do $$$AssertTrue(text [ context.evidence.GetAt(1).evidenceId, "the Evidence of this Case from tool.mapping_catalog")
	Do $$$AssertTrue(text [ context.evidence.GetAt(2).evidenceId, "and from system.exception")
}

Method TestARepetitionWithoutItsOwnRecordingUsesTheVariants()
{
	Set context = ..Context("P8b-test-01", 3, .caseId)
	Set replay = ##class(SignalNoir.Proposers.Replay).%New()
	Set replay.Reference = ..Reference("P8b-test-01", 1)
	Do $$$AssertTrue(replay.Propose(context).ok, "the variant's recording serves another repetition")
}

Method TestNoRecordingIsAValueNotASuccess()
{
	Set context = ..Context("P8b-test-02", 1, .caseId)
	Set replay = ##class(SignalNoir.Proposers.Replay).%New()
	Set replay.Reference = ..Reference("P8b-test-01", 1)
	Set r = replay.Propose(context)
	Do $$$AssertNotTrue(r.ok, "nothing recorded for this variant")
	Do $$$AssertEquals(r.code, "invalid_response", "a value the Investigation turns into review")
}

Method TestTheRecordingByOrderStillWorks()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ##class(SignalNoir.Tests.Support).OpenCase(svc, ##class(SignalNoir.Tests.Support).Uid("replay-old"))
	Set rec = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(caseId)
	Do ##class(SignalNoir.Proposers.Replay).Record(rec.orderId, ##class(SignalNoir.Tests.Support).P5Answer())
	Set context = ##class(SignalNoir.Core.Dto.InvestigationContext).%New()
	Set context.case = svc.GetCase(caseId).obj
	Set r = ##class(SignalNoir.Proposers.Replay).%New().Propose(context)
	Do $$$AssertTrue(r.ok, "the recording by Order of feature 006 is still found")
}

Method TestAReplayCaseIsLabelledWhereverItIsShown()
{
	Set dir = ##class(SignalNoir.Tests.Fakes.FakeRunDirectory).%New()
	Do dir.Add({"runId": "run_replay_lbl", "mode": "replay", "status": "running", "purpose": "quick_validation", "policyVersion": "", "mappingVersion": ""})
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set svc.Runs = dir
	Set caseId = ##class(SignalNoir.Tests.Support).OpenCase(svc, ##class(SignalNoir.Tests.Support).Uid("replay-lbl"), "run_replay_lbl")
	Set dto = svc.GetCase(caseId).obj
	Do $$$AssertEquals(##class(SignalNoir.Api.Dispatch).CasePayload(dto).labels.replay, 1, "the Case payload says replay")
	Set list = ##class(SignalNoir.Api.Dispatch).ListPayload(svc.ListCases("", "older", 5, {"runId": "run_replay_lbl"}))
	Do $$$AssertEquals(list.items.%Get(0).labels.replay, 1, "and so does the list")
}

}
