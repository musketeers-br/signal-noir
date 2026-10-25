Class SignalNoir.Tests.Api.TestResolutionApi Extends %UnitTest.TestCase
{

/// 009 T014 - the console reads the Dossier, Approvals, resolution answers
/// and the catalog over the contract
Method TestDetailCarriesDossierAndApprovals()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ##class(SignalNoir.Tests.Application.TestResolution).ReviewCase(svc, "api-dos")
	Set p = ##class(SignalNoir.Api.Dispatch).CasePayload(svc.GetCase(caseId).obj)
	Do $$$AssertEquals(p.%GetTypeOf("dossier"), "object", "dossier in review")
	For f = "reason", "reasonText", "createdAt", "suggestedNextStep", "unknowns" Do $$$AssertTrue(p.dossier.%IsDefined(f), "Dossier." _ f)
	Do svc.ResolveReview(caseId, {"kind": "action", "operator": "Carla", "expectedCaseVersion": 2, "action": "RETRY"})
	Set p = ##class(SignalNoir.Api.Dispatch).CasePayload(svc.GetCase(caseId).obj)
	Do $$$AssertEquals(p.%GetTypeOf("dossier"), "null", "no dossier while the case is active again")
	Do $$$AssertEquals(p.approvals.%Size(), 1, "approvals listed")
	For f = "approvalId", "proposalId", "decision", "by", "at" Do $$$AssertTrue(p.approvals.%Get(0).%IsDefined(f), "Approval." _ f)
	Set open = ##class(SignalNoir.Tests.Support).OpenCase(svc, ##class(SignalNoir.Tests.Support).Uid("api-nodos"))
	Do $$$AssertEquals(##class(SignalNoir.Api.Dispatch).CasePayload(svc.GetCase(open).obj).%GetTypeOf("dossier"), "null", "no dossier before any review")
}

Method TestResolutionPayload()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ##class(SignalNoir.Tests.Application.TestResolution).ReviewCase(svc, "api-res")
	Set r = svc.ResolveReview(caseId, {"kind": "action", "operator": "Carla", "expectedCaseVersion": 2, "action": "RETRY"})
	Set p = ##class(SignalNoir.Api.Dispatch).ResolutionPayload(svc, r.details)
	Do $$$AssertEquals(p.kind, "action", "kind")
	Do $$$AssertEquals(p.proposal.author, "operator:Carla", "author")
	Do $$$AssertEquals(p.proposal.validatorVerdict.verdict, "accepted", "verdict on the proposal")
	Do $$$AssertEquals(p.approval.by, "operator:Carla", "approval")
	For f = "caseId", "state", "caseVersion", "lastEventSeq", "serverTime", "commandId" Do $$$AssertTrue(p.case.%IsDefined(f), "CommandAck." _ f)
	Set c2 = ##class(SignalNoir.Tests.Application.TestResolution).ReviewCase(svc, "api-cancel")
	Set r = svc.ResolveReview(c2, {"kind": "cancel", "operator": "Carla", "expectedCaseVersion": 2, "reason": "dup"})
	Set p = ##class(SignalNoir.Api.Dispatch).ResolutionPayload(svc, r.details)
	Do $$$AssertEquals(p.%GetTypeOf("proposal"), "null", "no proposal on cancel")
	Do $$$AssertEquals(p.%GetTypeOf("approval"), "null", "no approval on cancel")
	Do $$$AssertEquals(p.case.state, "Cancelled", "cancelled")
}

Method TestRealValidatorBlocksMissingMappingParams()
{
	; the seam-v1 Validator refuses a mapping without its parameters: 422 material
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ##class(SignalNoir.Tests.Application.TestResolution).ReviewCase(svc, "api-422")
	Set r = svc.ResolveReview(caseId, {"kind": "action", "operator": "Carla", "expectedCaseVersion": 2, "action": "APPLY_APPROVED_MAPPING", "params": {"mappingId": "map_glicj_soro"}})
	Do $$$AssertEquals(r.code, "VALIDATION_FAILED", "refused")
	Do $$$AssertEquals(r.details.verdict.verdict, "blocked", "by the Validator")
	Do $$$AssertTrue(r.details.verdict.reasons.%Size() > 0, "reason codes")
}

Method TestCatalog()
{
	Set items = ##class(SignalNoir.Core.ActionCatalog).Entries()
	Do $$$AssertEquals(items.%Size(), 4, "four entries")
	Do $$$AssertEquals(items.%Get(2).%GetTypeOf("requiresApproval"), "boolean", "boolean flags")
}

}
