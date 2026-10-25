Class SignalNoir.Consumer.Consumer Extends %RegisteredObject
{

/// T036 - a test-only sample consumer built against `docs/seams.md`.
/// It imports ONLY the seam (SignalNoir.Core.Port.*, SignalNoir.Core.Dto.*,
/// SignalNoir.Core.Result) and the test doubles (SignalNoir.Tests.Fakes.*).
/// It never references SignalNoir.Application, SignalNoir.Api,
/// SignalNoir.Interop or SignalNoir.Proposers: that is the consumer guarantee.
Property Commands As SignalNoir.Core.Port.CaseCommands;

Property Queries As SignalNoir.Core.Port.CaseQueries;

Property Validator As SignalNoir.Core.Port.Validator;

Property Proposer As SignalNoir.Core.Port.Proposer;

Property Tools As SignalNoir.Core.Port.Tools;

Property Partner As SignalNoir.Core.Port.PartnerClient;

Property Clock As SignalNoir.Core.Port.Clock;

Property Ids As SignalNoir.Core.Port.IdGenerator;

Method %OnNew() As %Status
{
	Set ..Commands = ##class(SignalNoir.Tests.Fakes.FakeCaseCommands).%New()
	Set ..Queries = ##class(SignalNoir.Tests.Fakes.FakeCaseQueries).%New()
	Set ..Validator = ##class(SignalNoir.Tests.Fakes.FakeValidator).%New()
	Set ..Proposer = ##class(SignalNoir.Tests.Fakes.FakeProposer).%New()
	Set ..Tools = ##class(SignalNoir.Tests.Fakes.FakeTools).%New()
	Set ..Partner = ##class(SignalNoir.Tests.Fakes.FakePartnerClient).%New()
	Set ..Clock = ##class(SignalNoir.Tests.Fakes.FixedClock).%New()
	Set ..Ids = ##class(SignalNoir.Tests.Fakes.SeqIdGenerator).%New()
	Return $$$OK
}

/// Uses every port once through its fake and returns the outcomes, so a test
/// can assert that the seam is sufficient without touching the runtime.
Method RunOnce(orderId As %String) As %DynamicObject
{
	Set out = ##class(%DynamicObject).%New()

	; CaseCommands: accept stores the Order; the first Exception opens the Case
	Set order = ##class(SignalNoir.Core.Dto.Order).%New()
	Set order.orderId = orderId
	Set order.snapshot = ##class(%DynamicObject).%New()
	Set order.equivalenceKey = "P-" _ orderId _ "|GLICJ|2026-10-23T10:00:00Z|SP-1"
	Set order.receivedAt = ..Clock.NowUtc()
	Set order.synthetic = 1
	Set accepted = ..Commands.AcceptOrder(order)
	Do out.%Set("accepted", accepted.ok)
	If 'accepted.ok Return out
	Set exception = ##class(SignalNoir.Core.Dto.CaseException).%New()
	Set exception.kind = "timeout"
	Set exception.observedAt = ..Clock.NowUtc()
	Set opened = ..Commands.RecordException(orderId, exception)
	Do out.%Set("opened", opened.ok)
	Set caseId = opened.ref
	Do out.%Set("caseId", caseId)
	If 'opened.ok Return out

	; CaseCommands: an attachment advances the timeline without bumping caseVersion
	Set event = ##class(SignalNoir.Core.Dto.TimelineEvent).%New()
	Set event.type = "Annotation"
	Set event.actor = "operator:" _ "consumer"
	Set event.refId = caseId
	Set event.payload = ##class(%DynamicObject).%New()
	Set appended = ..Commands.Append(caseId, event)
	Do out.%Set("appended", appended.ok)
	Do out.%Set("appendSeq", appended.obj.seq)

	; CaseCommands: a transition with the current version wins
	Set move = ##class(SignalNoir.Core.Dto.TimelineEvent).%New()
	Set move.type = "StateChanged"
	Set move.actor = "system"
	Set move.refId = caseId
	Set move.payload = ##class(%DynamicObject).%New()
	Set transitioned = ..Commands.Transition(caseId, 1, "Investigating", "system", move)
	Do out.%Set("transitioned", transitioned.ok)

	; CaseQueries: reads
	Set listed = ..Queries.ListCases("")
	Do out.%Set("listed", listed.ok)
	Set timeline = ..Queries.GetTimeline(caseId, 0)
	Do out.%Set("timeline", timeline.ok)
	Set fetched = ..Queries.GetCase(caseId)
	Do out.%Set("getCaseOk", fetched.ok)
	Do out.%Set("getCaseCode", fetched.code)

	; Validator
	Set verdict = ..Validator.Validate(##class(SignalNoir.Core.Dto.Proposal).%New())
	Do out.%Set("verdict", verdict.verdict)

	; Proposer (unavailable by default in the fake)
	Set proposal = ..Proposer.Propose(##class(SignalNoir.Core.Dto.Case).%New())
	Do out.%Set("proposerOk", proposal.ok)
	Do out.%Set("proposerCode", proposal.code)

	; Tools (read-only)
	Set tool = ..Tools.Invoke("tool.policies", ##class(%DynamicObject).%New())
	Do out.%Set("toolOk", tool.ok)

	; PartnerClient
	Set sent = ..Partner.Send(orderId, "RETRY", ##class(%DynamicObject).%New(), "idem-" _ orderId)
	Do out.%Set("partnerOk", sent.ok)
	Do out.%Set("idempotencyKey", ..Partner.LastIdempotencyKey)
	Set receipts = ..Partner.FetchReceipts(orderId)
	Do out.%Set("receiptCount", receipts.list.Count())

	; Clock and IdGenerator
	Do out.%Set("now", ..Clock.NowUtc())
	Do out.%Set("id", ..Ids.New("cmd_"))

	Return out
}

}
