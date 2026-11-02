Class SignalNoir.Tests.Application.Benchmark.TestCaseFacts Extends %UnitTest.TestCase
{

/// 010 T032 - the facts the evaluator is given are read from the persisted Case: its final
/// state, what was sent, every Proposal with the Validator's verdict, whether a person acted,
/// and why it did not decide (a coded reason, never matched text). Read only.
ClassMethod Item(caseId As %String, status As %String = "ended", reason As %String = "") As SignalNoir.Application.Model.BenchmarkItemRecord
{
	Set item = ##class(SignalNoir.Application.Model.BenchmarkItemRecord).%New()
	Set item.runId = "run_facts", item.itemNo = 1, item.caseId = caseId, item.status = status, item.notDecidedReason = reason
	Return item
}

ClassMethod NewCase(state As %String) As %String
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ##class(SignalNoir.Tests.Support).OpenCase(svc, ##class(SignalNoir.Tests.Support).Uid("facts"))
	Set rec = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(caseId)
	Set rec.state = state
	$$$ThrowOnError(rec.%Save())
	Return caseId
}

/// Records a Proposal of the Case and returns its id (unique, and recorded in order)
ClassMethod Proposal(caseId As %String, action As %String, params As %String, verdict As %String) As %String
{
	Set p = ##class(SignalNoir.Application.Model.ProposalRecord).%New()
	Set p.proposalId = ##class(SignalNoir.Tests.Support).Uid("prop"), p.caseId = caseId, p.author = "rules", p.action = action, p.paramsJson = params
	Hang 0.01
	Set p.createdAt = ##class(SignalNoir.Application.SystemClock).%New().NowUtc()
	Set p.verdictJson = {"verdict": (verdict)}.%ToJSON()
	$$$ThrowOnError(p.%Save())
	Return p.proposalId
}

ClassMethod Execution(caseId As %String, proposalId As %String, action As %String)
{
	Set rec = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(caseId)
	Set e = ##class(SignalNoir.Application.Model.ExecutionRecord).%New()
	Set e.executionId = "exec_" _ proposalId, e.caseId = caseId, e.orderId = rec.orderId, e.proposalId = proposalId, e.action = action
	Set e.authorizedAt = "2026-11-01T00:00:09Z", e.outcome = "resolved"
	$$$ThrowOnError(e.%Save())
}

Method TestAScenarioWithoutAnExceptionHasNoCase()
{
	Set facts = ##class(SignalNoir.Application.Benchmark.CaseFacts).For(..Item(""))
	Do $$$AssertEquals(facts.finalState, "NoCase", "a control that raised nothing")
	Do $$$AssertEquals(facts.%GetTypeOf("effect"), "null", "nothing sent")
	Do $$$AssertEquals(facts.proposals.%Size(), 0, "no Proposals")
}

Method TestWhatWasSentIsTheExecutedProposal()
{
	Set caseId = ..NewCase("Resolved")
	Do ..Proposal(caseId, "APPLY_APPROVED_MAPPING", "{""mappingId"":""map_glicj_plasma""}", "blocked")
	Set sent = ..Proposal(caseId, "APPLY_APPROVED_MAPPING", "{""mappingId"":""map_glicj_soro""}", "accepted")
	Do ..Execution(caseId, sent, "APPLY_APPROVED_MAPPING")
	Set facts = ##class(SignalNoir.Application.Benchmark.CaseFacts).For(..Item(caseId))
	Do $$$AssertEquals(facts.finalState, "Resolved", "final state")
	Do $$$AssertEquals(facts.effect.action, "APPLY_APPROVED_MAPPING", "the Action sent")
	Do $$$AssertEquals(facts.effect.params.mappingId, "map_glicj_soro", "with its parameters")
	Do $$$AssertEquals(facts.proposals.%Size(), 2, "both Proposals, in order")
	Do $$$AssertEquals(facts.proposals.%Get(0).verdict, "blocked", "the first was blocked")
	Do $$$AssertEquals(facts.proposals.%Get(0).params.mappingId, "map_glicj_plasma", "with its parameters")
	Do $$$AssertEquals(facts.proposals.%Get(1).verdict, "accepted", "the second was accepted")
	Do $$$AssertEquals(facts.touchedByPerson, 0, "no person acted")
	Do $$$AssertEquals(facts.replay, 0, "not a replay")
}

Method TestAHoldIsAnEffectOnlyWhenTheProposalWasAHold()
{
	Set held = ..NewCase("Held")
	Set hold = ..Proposal(held, "HOLD", "{}", "accepted")
	Set rec = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(held)
	Set rec.currentProposalId = hold
	$$$ThrowOnError(rec.%Save())
	Set facts = ##class(SignalNoir.Application.Benchmark.CaseFacts).For(..Item(held))
	Do $$$AssertEquals(facts.effect.action, "HOLD", "a HOLD Proposal that holds is the effect")
	Set stopped = ..NewCase("Held")
	Set apply = ..Proposal(stopped, "APPLY_APPROVED_MAPPING", "{""mappingId"":""map_glicj_soro""}", "accepted")
	Set rec = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(stopped)
	Set rec.currentProposalId = apply
	$$$ThrowOnError(rec.%Save())
	Set facts = ##class(SignalNoir.Application.Benchmark.CaseFacts).For(..Item(stopped))
	Do $$$AssertEquals(facts.%GetTypeOf("effect"), "null", "an Action held by a failed Revalidation was not sent")
}

/// A Case that ended Failed has no effect even when an execution was authorized: the Action did not
/// reach the Partner as a result (contracts/scoring.md, Step 1). The failure belongs to the platform part.
Method TestAFailedCaseHasNoEffect()
{
	Set caseId = ..NewCase("Failed")
	Set sent = ..Proposal(caseId, "APPLY_APPROVED_MAPPING", "{""mappingId"":""map_glicj_soro""}", "accepted")
	Do ..Execution(caseId, sent, "APPLY_APPROVED_MAPPING")
	Set facts = ##class(SignalNoir.Application.Benchmark.CaseFacts).For(..Item(caseId))
	Do $$$AssertEquals(facts.finalState, "Failed", "failed")
	Do $$$AssertEquals(facts.%GetTypeOf("effect"), "null", "nothing counts as sent")
	Do $$$AssertEquals(facts.proposals.%Size(), 1, "the Proposal is still there to be read")
}

Method TestReviewHasNoEffect()
{
	Set caseId = ..NewCase("ReviewRequired")
	Do ..Proposal(caseId, "REQUEST_REVIEW", "{}", "accepted")
	Set facts = ##class(SignalNoir.Application.Benchmark.CaseFacts).For(..Item(caseId))
	Do $$$AssertEquals(facts.finalState, "ReviewRequired", "review")
	Do $$$AssertEquals(facts.%GetTypeOf("effect"), "null", "nothing sent")
	Do $$$AssertEquals(facts.%GetTypeOf("notDecidedReason"), "null", "and it decided")
}

Method TestAProviderOutageIsReadFromTheCodedDossierReason()
{
	Set caseId = ..NewCase("ReviewRequired")
	Set d = ##class(SignalNoir.Application.Model.DossierRecord).%New()
	Set d.caseId = caseId, d.createdAt = "2026-11-01T00:00:09Z", d.reason = "provider_unavailable", d.dossierJson = "{}"
	$$$ThrowOnError(d.%Save())
	Set facts = ##class(SignalNoir.Application.Benchmark.CaseFacts).For(..Item(caseId))
	Do $$$AssertEquals(facts.notDecidedReason, "provider_unavailable", "the coded reason, not text")
	Set other = ..NewCase("ReviewRequired")
	Set d2 = ##class(SignalNoir.Application.Model.DossierRecord).%New()
	Set d2.caseId = other, d2.createdAt = "2026-11-01T00:00:09Z", d2.reason = "ambiguous_identity", d2.dossierJson = "{}"
	$$$ThrowOnError(d2.%Save())
	Set facts2 = ##class(SignalNoir.Application.Benchmark.CaseFacts).For(..Item(other))
	Do $$$AssertEquals(facts2.%GetTypeOf("notDecidedReason"), "null", "any other reason is a decision to ask for review")
}

Method TestAnItemThatDidNotDecideCarriesItsReason()
{
	Set caseId = ..NewCase("Investigating")
	Set facts = ##class(SignalNoir.Application.Benchmark.CaseFacts).For(..Item(caseId, "not_decided", "deadline"))
	Do $$$AssertEquals(facts.notDecidedReason, "deadline", "from the item")
}

Method TestAPersonsActionMarksTheCase()
{
	Set caseId = ..NewCase("Resolved")
	Set e = ##class(SignalNoir.Application.Model.CaseEventRecord).%New()
	Set e.caseId = caseId, e.seq = 99, e.at = "2026-11-01T00:00:10Z", e.type = "ApprovalRecorded", e.actor = "operator:ana", e.payloadJson = "{}"
	$$$ThrowOnError(e.%Save())
	Set facts = ##class(SignalNoir.Application.Benchmark.CaseFacts).For(..Item(caseId))
	Do $$$AssertEquals(facts.touchedByPerson, 1, "an operator acted on it")
	Set other = ..NewCase("Resolved")
	Do $$$AssertEquals(##class(SignalNoir.Application.Benchmark.CaseFacts).For(..Item(other)).touchedByPerson, 0, "system, rules and benchmark are not a person")
}

Method TestAReplayCaseIsMarked()
{
	Set caseId = ..NewCase("Resolved")
	Set rec = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(caseId)
	Set rec.replay = 1
	$$$ThrowOnError(rec.%Save())
	Do $$$AssertEquals(##class(SignalNoir.Application.Benchmark.CaseFacts).For(..Item(caseId)).replay, 1, "replay")
}

}
