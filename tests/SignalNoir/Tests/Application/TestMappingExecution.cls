Class SignalNoir.Tests.Application.TestMappingExecution Extends %UnitTest.TestCase
{

Parameter S = "SignalNoir.Tests.Support";

/// 004/008 - an approved Mapping reaches the Partner: the execution policy of the product reads the
/// Mapping from the set the Proposal names and sends the Order with its target code
ClassMethod Executor(partner) As SignalNoir.Application.ExecutionService
{
	Set ex = $ClassMethod(..#S, "Executor", partner)
	Set ex.Policy = ##class(SignalNoir.Application.ReferenceExecutionPolicy).%New()
	Return ex
}

/// An approved APPLY_APPROVED_MAPPING Case for a GLIC-J Order, with these params
ClassMethod ApprovedMapping(svc, tag As %String, params As %DynamicObject) As %String
{
	Set caseId = $ClassMethod(..#S, "OpenCase", svc, $ClassMethod(..#S, "Uid", tag), "", "GLIC-J")
	Do $ClassMethod(..#S, "DriveTo", svc, caseId, "DecisionProposed")
	; a Proposal is immutable: its params are set when it is created
	Do $ClassMethod(..#S, "FixtureProposal", caseId, "APPLY_APPROVED_MAPPING", params)
	Set g = svc.GetCase(caseId).obj
	Do svc.Transition(caseId, g.caseVersion, "PendingApproval", "system", $ClassMethod(..#S, "Ev", "test walk"))
	Do $ClassMethod(..#S, "Decide", svc, caseId, "approved", "ana")
	Return caseId
}

Method TestAnApprovedMappingIsSentWithItsTargetCode()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ..ApprovedMapping(svc, "map-exec-ok", {"mappingId": "map_glicj_soro", "mappingVersion": "2026.10.1"})
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Set r = $ClassMethod(..#S, "DeliverLast", $ClassMethod(..#S, "ExecBus", ..Executor(partner)), caseId)
	Do $$$AssertTrue(r.ok, "delivered: " _ r.message)
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "Resolved", "the Case is resolved")
	Do $$$AssertEquals(partner.Deliveries, 1, "one delivery")
	If partner.Sent.%Size() = 0 Quit
	Do $$$AssertEquals(partner.Sent.%Get(0).order.exams.%Get(0).code, "GLIC-S", "the Partner receives the target code")
	Do $$$AssertEquals(partner.Sent.%Get(0).order.orderId, c.orderId, "for the same Order")
	Set ref = partner.Sent.%Get(0).mappingRef
	Do $$$AssertEquals($Select($IsObject(ref): ref.mappingId _ " " _ ref.mappingVersion, 1: ""), "map_glicj_soro 2026.10.1", "the request names the Mapping")
}

Method TestAnUnknownMappingIsHeldNotSent()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ..ApprovedMapping(svc, "map-exec-unknown", {"mappingId": "map_none", "mappingVersion": "2026.10.1"})
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Do $ClassMethod(..#S, "DeliverLast", $ClassMethod(..#S, "ExecBus", ..Executor(partner)), caseId)
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state _ ":" _ partner.Calls.deliver, "Held:0", "held, nothing sent")
	Do $$$AssertTrue(##class(SignalNoir.Application.Model.ExecutionRecord).%OpenId(c.executions.%Get(0).executionId).failureReason [ "map_none is not in Mapping set 2026.10.1", "says why")
}

Method TestTheProductUsesThePolicyWithReferenceData()
{
	Do $$$AssertEquals($ClassName(##class(SignalNoir.Application.ExecutionService).Default().Policy), "SignalNoir.Application.ReferenceExecutionPolicy", "Default() sends approved Mappings")
}

}
