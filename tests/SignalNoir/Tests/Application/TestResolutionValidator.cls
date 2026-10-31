Class SignalNoir.Tests.Application.TestResolutionValidator Extends %UnitTest.TestCase
{

/// 004 T018 - the adapter builds the Validation Input from the Case and both
/// paths (investigation, operator resolution) record the v2 verdict with versions
ClassMethod Investigated(svc, tag, ByRef cmd, ByRef started) As %String
{
	Set S = "SignalNoir.Tests.Support"
	Set caseId = $ClassMethod(S, "InvestigatingCase", svc, tag, "agent", .cmd, "SERUM")
	Set started = svc.StartInvestigation(cmd, "SignalNoir.Tests.Fakes.ScriptedProposer", "SignalNoir.Tests.Fakes.ScriptedSource")
	; the investigation itself is not run here: the Case holds the Evidence it would have recorded
	Do $ClassMethod(S, "SeedEvidence", caseId)
	Return caseId
}

ClassMethod P8bProposal(started) As SignalNoir.Core.Dto.Proposal
{
	Set S = "SignalNoir.Tests.Support"
	Set ids = ##class(%ListOfDataTypes).%New()
	Do ids.Insert(started.details.evidenceIds.%Get(0))
	Set answer = {}.%FromJSON($Replace($ClassMethod(S, "P8bAnswer"), """@ev:tool.mapping_catalog""", """" _ ids.GetAt(1) _ """"))
	Set answer = {}.%FromJSON($Replace(answer.%ToJSON(), """@ev:system.exception""", """" _ ids.GetAt(1) _ """"))
	Return ##class(SignalNoir.Core.ProposalShape).Convert(answer, ids, "agent", {"policy": "p", "mapping": "m"}, {}).obj
}

ClassMethod LastVerdictEvent(svc, caseId) As %DynamicObject
{
	Set list = svc.GetTimeline(caseId, 0).list, found = ""
	For i = 1 : 1 : list.Count() If list.GetAt(i).type = "ValidatorVerdict" Set found = list.GetAt(i).payload
	Return found
}

Method TestInputForBuildsTheInputFromTheCase()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ..Investigated(svc, "rv-input", .cmd, .started)
	Set rec = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(caseId)
	Set proposal = ..P8bProposal(started)
	Set in = ##class(SignalNoir.Application.ResolutionValidator).InputFor(rec, proposal, "2026-10-31T12:00:00Z")
	Do $$$AssertTrue($IsObject(in) && in.%IsA("SignalNoir.Core.Dto.ValidationInput"), "a ValidationInput")
	Do $$$AssertTrue(in.proposal = proposal, "the Proposal as given")
	Do $$$AssertEquals(in.proposal.caseId, caseId, "an unrecorded Proposal takes the Case it is validated for")
	Do $$$AssertEquals(in.now, "2026-10-31T12:00:00Z", "now as given")
	Set evidence = svc.ListEvidence(caseId)
	Do $$$AssertTrue(evidence.Count() > 0, "the Case has Evidence")
	Do $$$AssertEquals(in.evidence.Count(), evidence.Count(), "every Evidence of the Case")
	Do $$$AssertEquals(in.evidence.GetAt(1).evidenceId, evidence.GetAt(1).evidenceId, "in recording order")
	Do $$$AssertEquals(in.order.orderId, rec.orderId, "the Order snapshot")
	Do $$$AssertEquals(in.order.specimen.type, "SERUM", "raw snapshot values")
	Do $$$AssertEquals(in.attemptCount, 0, "attempt count is 0 until 008")
	Do $$$AssertEquals(in.run.%GetTypeOf("inRun") _ ":" _ in.run.inRun, "boolean:0", "not in a run")
	Set inForce = ##class(SignalNoir.Application.Reference.Store).InForce()
	Do $$$AssertTrue(inForce.ok, "reference data in force")
	Do $$$AssertEquals(in.reference.policyVersion _ ":" _ in.reference.mappingVersion, inForce.obj.policyVersion _ ":" _ inForce.obj.mappingVersion, "snapshot from Store.For(run)")
}

Method TestInvestigationPathRecordsVersions()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ..Investigated(svc, "rv-inv", .cmd, .started)
	Set r = svc.CompleteInvestigation(cmd, ..P8bProposal(started))
	Do $$$AssertTrue(r.ok, "proposal recorded: " _ r.message)
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "PendingApproval", "accepted with effect -> PendingApproval")
	Set pr = ##class(SignalNoir.Application.Model.ProposalRecord).%OpenId(r.ref)
	Set stored = {}.%FromJSON(pr.verdictJson)
	Set inForce = ##class(SignalNoir.Application.Reference.Store).InForce().obj
	For f = "verdict", "reasons", "requiresApproval", "at", "versions" Do $$$AssertTrue(stored.%IsDefined(f), "stored verdict has " _ f)
	Do $$$AssertEquals(stored.verdict, "accepted", "accepted")
	Do $$$AssertEquals(stored.versions.policy _ ":" _ stored.versions.mapping, inForce.policyVersion _ ":" _ inForce.mappingVersion, "stored versions")
	Set payload = ..LastVerdictEvent(svc, caseId)
	Do $$$AssertTrue($IsObject(payload), "ValidatorVerdict event")
	Do $$$AssertEquals(payload.verdict _ ":" _ (+payload.requiresApproval) _ ":" _ payload.reasons.%Size(), "accepted:1:" _ stored.reasons.%Size(), "event verdict, approval, reasons")
	Do $$$AssertEquals(payload.versions.policy _ ":" _ payload.versions.mapping, inForce.policyVersion _ ":" _ inForce.mappingVersion, "event versions")
}

Method TestResolutionPathRecordsVersions()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ##class(SignalNoir.Tests.Application.TestResolution).ReviewCase(svc, "rv-res")
	Set r = svc.ResolveReview(caseId, {"kind": "action", "operator": "Carla", "expectedCaseVersion": 2, "action": "HOLD", "params": {"reason": "maintenance"}})
	Do $$$AssertTrue(r.ok, "accepted: " _ r.message)
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "Executing", "HOLD accepted -> Executing")
	Set inForce = ##class(SignalNoir.Application.Reference.Store).InForce().obj
	Set payload = ..LastVerdictEvent(svc, caseId)
	Do $$$AssertEquals(payload.verdict, "accepted", "event verdict")
	Do $$$AssertEquals(+payload.requiresApproval, 0, "HOLD needs no approval")
	Do $$$AssertEquals(payload.versions.policy _ ":" _ payload.versions.mapping, inForce.policyVersion _ ":" _ inForce.mappingVersion, "event versions")
	Set p = c.proposals.GetAt(c.proposals.Count())
	Set pr = ##class(SignalNoir.Application.Model.ProposalRecord).%OpenId(p.proposalId)
	Do $$$AssertEquals({}.%FromJSON(pr.verdictJson).versions.mapping, inForce.mappingVersion, "stored versions")
}

Method TestBlockedRoutesToReviewWithVersions()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set fake = ##class(SignalNoir.Tests.Fakes.FakeValidator).%New()
	Set fake.Verdict = "blocked"
	Set fake.Reasons = $ListBuild("MAPPING_CONDITION_MISMATCH")
	Set svc.Validator = fake
	Set caseId = ..Investigated(svc, "rv-blk", .cmd, .started)
	Set r = svc.CompleteInvestigation(cmd, ..P8bProposal(started))
	Do $$$AssertTrue(r.ok, "proposal recorded: " _ r.message)
	Do $$$AssertEquals(svc.GetCase(caseId).obj.state, "ReviewRequired", "blocked -> ReviewRequired")
	Set payload = ..LastVerdictEvent(svc, caseId)
	Do $$$AssertEquals(payload.verdict _ ":" _ payload.reasons.%Get(0), "blocked:MAPPING_CONDITION_MISMATCH", "event reasons")
	Do $$$AssertTrue(payload.versions.%IsDefined("policy") && payload.versions.%IsDefined("mapping"), "event versions")
}

}
