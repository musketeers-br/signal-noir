Class SignalNoir.Tests.Recovery.TestGateG3 Extends %UnitTest.TestCase
{

/// Gate G3 (008 + 009): a Case the Operator resolves from review reaches the
/// Partner only through the execution path, and what execution cannot
/// finish comes back to an Operator with a Dossier. The last case runs live
/// against the Simulator over HTTP.
Parameter S = "SignalNoir.Tests.Support";

Property Ready As %Boolean;

Method OnBeforeAllTests() As %Status
{
	Do ##class(SignalNoir.Tests.Sim.ClientTimeout).Set(##class(SignalNoir.Tests.Recovery.TestRecoverySuite).#TIMEOUT)
	Set ..Ready = ##class(SignalNoir.Tests.Recovery.TestRecoverySuite).Partner().SearchReceipts({"idempotencyKey": "bek_probe"}).ok
	Return $$$OK
}

Method OnAfterAllTests() As %Status
{
	Do ##class(SignalNoir.Tests.Sim.ClientTimeout).Clear()
	Return $$$OK
}

/// The Operator's choice on a Case in review
ClassMethod Resolve(svc As SignalNoir.Application.CaseService, caseId As %String, action As %String, params As %DynamicObject = "") As SignalNoir.Core.Result
{
	Set input = {"kind": "action", "operator": "Carla", "expectedCaseVersion": (svc.GetCase(caseId).obj.caseVersion), "action": (action), "note": "gate G3"}
	If $IsObject(params) Set input.params = params
	Return svc.ResolveReview(caseId, input)
}

Method TestOperatorRetryIsExecuted()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ##class(SignalNoir.Tests.Application.TestResolution).ReviewCase(svc, "g3-retry")
	Set r = ..Resolve(svc, caseId, "RETRY")
	Do $$$AssertTrue(r.ok, "resolved: " _ r.message)
	Set approvalId = svc.GetCase(caseId).obj.currentApprovalId
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Set d = $ClassMethod(..#S, "DeliverLast", $ClassMethod(..#S, "ExecBus", $ClassMethod(..#S, "Executor", partner)), caseId)
	Do $$$AssertEquals(d.details.status, "resolved", "executed: " _ d.message)
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "Resolved", "Resolved")
	Do $$$AssertEquals(partner.Deliveries, 1, "one delivery")
	Do $$$AssertEquals(c.executions.%Get(0).approvalId, approvalId, "on the Operator's own Approval")
	Do $$$AssertEquals(c.executions.%Get(0).proposalId, c.currentProposalId, "of the Operator's Proposal")
	Do $$$AssertTrue($IsObject(c.receipt) && (c.receipt.receiptId '= ""), "the Receipt copy")
	Set types = $ClassMethod(..#S, "Types", svc, caseId)
	Do $$$AssertTrue($Find(types, "RevalidationPerformed") > $Find(types, "OperatorResolution"), "revalidated after the resolution")
}

Method TestOperatorHoldMakesNoCall()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ##class(SignalNoir.Tests.Application.TestResolution).ReviewCase(svc, "g3-hold")
	Do $$$AssertTrue(..Resolve(svc, caseId, "HOLD", {"reason": "maintenance"}).ok, "resolved")
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Do $ClassMethod(..#S, "DeliverLast", $ClassMethod(..#S, "ExecBus", $ClassMethod(..#S, "Executor", partner)), caseId)
	Do $$$AssertEquals(svc.GetCase(caseId).obj.state, "Held", "Held")
	Do $$$AssertEquals(partner.Calls.deliver, 0, "no Partner call")
}

/// Until 004 publishes the mapping payloads, an approved mapping is held,
/// never sent with a guessed payload
Method TestOperatorMappingIsHeldUntil004()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ##class(SignalNoir.Tests.Application.TestResolution).ReviewCase(svc, "g3-mapping", "GLIC-J")
	Set r = ..Resolve(svc, caseId, "APPLY_APPROVED_MAPPING", {"mappingId": "map_glicj_soro", "mappingVersion": "2026.10.1"})
	Do $$$AssertTrue(r.ok, "resolved: " _ r.message)
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Do $ClassMethod(..#S, "DeliverLast", $ClassMethod(..#S, "ExecBus", $ClassMethod(..#S, "Executor", partner)), caseId)
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state _ ":" _ partner.Calls.deliver, "Held:0", "held, nothing sent")
	Do $$$AssertTrue(##class(SignalNoir.Application.Model.ExecutionRecord).%OpenId(c.executions.%Get(0).executionId).failureReason [ "mapping unavailable", "says why")
}

/// A refusal of the Operator's choice opens a related Case; when its
/// investigation cannot finish (no provider), it reaches review with a
/// fresh Dossier, whether or not this instance has a provider
Method TestRefusalComesBackWithADossier()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ##class(SignalNoir.Tests.Application.TestResolution).ReviewCase(svc, "g3-refused")
	Set orderId = svc.GetCase(caseId).obj.orderId
	Do $$$AssertTrue(..Resolve(svc, caseId, "RETRY").ok, "resolved")
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Set body = "{""error"":""exam code retired""}"
	Do partner.Answers.%Push({"status": 422, "text": (body)})
	Do $ClassMethod(..#S, "DeliverLast", $ClassMethod(..#S, "ExecBus", $ClassMethod(..#S, "Executor", partner)), caseId)
	Do $$$AssertEquals(svc.GetCase(caseId).obj.state, "Failed", "the refused Case fails")
	Set related = svc.OpenCase(orderId).ref
	Set inv = svc.GetCase(related).obj
	Do $$$AssertEquals(inv.previousCaseId, caseId, "a related Case")
	; with a provider it is investigated, and the investigation fails here
	; (Unavailable proposer); without one it goes to review at once
	If inv.state = "Investigating" {
		Do $ClassMethod(..#S, "Investigate", ##class(SignalNoir.Tests.Application.TestCommandBus).Last(related, "Investigate"), "SignalNoir.Proposers.Unavailable")
	}
	Set rc = svc.GetCase(related).obj
	Do $$$AssertEquals(rc.state, "ReviewRequired", "ReviewRequired")
	Do $$$AssertTrue($IsObject(rc.dossier) && (rc.dossier.%Size() > 0), "with a Dossier")
	Do $$$AssertEquals(rc.exceptions.GetAt(1).httpStatus, 422, "the refusal is its Exception")
}

/// Live: an Order from the Simulator, a Case the Operator resolves, one
/// Receipt at the Partner
Method TestLiveOperatorRetry()
{
	If '..Ready Do $$$LogMessage("skipped: the Simulator is not reachable") Quit
	Set sim = "SignalNoir.Tests.Interop.TestOriginFeed"
	Set c = $ClassMethod(sim, "Post", "/scenarios", {"family": "clean", "variant": "clean-success-tune-01", "seed": 33, "timeScale": 0.01})
	Set e = $ClassMethod(sim, "Post", "/scenarios/" _ c.scenarioInstanceId _ "/emissions", "")
	Set order = e.emitted.%Get(0).order
	Do ##class(SignalNoir.Interop.Service.OrderIn).Accept(order.%ToJSON(), "tx-" _ order.orderId, "", c.scenarioInstanceId)
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	; the Exception opens the Case (Open); its routing is not under test here
	Set caseId = svc.RecordException(order.orderId, $ClassMethod(..#S, "Exception")).ref
	Do svc.MarkReviewRequired(caseId, 1, "system", "gate G3 live")
	Do $$$AssertTrue(..Resolve(svc, caseId, "RETRY").ok, "resolved")
	Do $ClassMethod(..#S, "DeliverLast", $ClassMethod(..#S, "ExecBus", ##class(SignalNoir.Tests.Recovery.TestRecoverySuite).Executor()), caseId)
	Do $$$AssertEquals(svc.GetCase(caseId).obj.state, "Resolved", "Resolved")
	Do $$$AssertEquals(##class(SignalNoir.Tests.Recovery.TestRecoverySuite).Receipts(order.orderId), 1, "1 Receipt")
}

}
