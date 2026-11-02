Class SignalNoir.Tests.Application.TestPrecedentNeutrality Extends %UnitTest.TestCase
{

/// 015 T019/T021 - precedents never decide, and the Agent block is opt-in
Method TestSearchWritesNothingButItsRecord()
{
	Set PS = "SignalNoir.Tests.Application.PrecedentSupport"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set p = $ClassMethod(PS, "Service", svc)
	Set partner = ##class(SignalNoir.Tests.Support).Uid("PNEU")
	For i = 1 : 1 : 3 Do p.IndexCase($ClassMethod(PS, "FamilyCase", svc, partner, "timeout", "Resolved"))
	Set open = $ClassMethod(PS, "FamilyCase", svc, partner, "timeout", "")
	Set before = svc.GetCase(open).obj
	Set types = ##class(SignalNoir.Tests.Support).Types(svc, open)
	Set evidence = ##class(SignalNoir.Tests.Support).Count("SELECT COUNT(*) FROM SignalNoir_Application_Model.EvidenceRecord WHERE caseId = ?", open)
	Set r = p.Search(open)
	Do $$$AssertEquals(r.details.status, "results", "precedents found")
	Set after = svc.GetCase(open).obj
	Do $$$AssertEquals(after.state, before.state, "state unchanged")
	Do $$$AssertEquals(after.caseVersion, before.caseVersion, "version unchanged")
	Do $$$AssertEquals(after.currentProposalId, before.currentProposalId, "no Proposal")
	Do $$$AssertEquals(##class(SignalNoir.Tests.Support).Count("SELECT COUNT(*) FROM SignalNoir_Application_Model.EvidenceRecord WHERE caseId = ?", open), evidence, "no Evidence")
	Do $$$AssertEquals(##class(SignalNoir.Tests.Support).Types(svc, open), types _ "Annotation;", "only the search record is added")
	Do $ClassMethod(PS, "Cleanup", p)
}

/// A precedent cannot be cited: the core accepts only Evidence ids
Method TestPrecedentNotCitable()
{
	Set ids = ##class(%ListOfDataTypes).%New()
	Do ids.Insert("evid_1")
	Set answer = {"diagnosis": {"summary": "s", "claims": [{"text": "same as before", "evidenceIds": ["case_000118"]}], "hypotheses": []}, "action": "RETRY", "params": {}, "confidence": "LOW", "preconditions": []}
	Set r = ##class(SignalNoir.Core.ProposalShape).Convert(answer, ids, "agent", {}, {})
	Set refused = 'r.ok
	If r.ok Set refused = (r.obj.diagnosis.%ToJSON() '[ "case_000118")
	Do $$$AssertTrue(refused, "a precedent id is never kept as Evidence")
}

/// Same model answer, same Proposal, with or without precedents in context
Method TestSameProposalWithAndWithout()
{
	Set PS = "SignalNoir.Tests.Application.PrecedentSupport"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set p = $ClassMethod(PS, "Service", svc)
	Set partner = ##class(SignalNoir.Tests.Support).Uid("PAG")
	Do p.IndexCase($ClassMethod(PS, "FamilyCase", svc, partner, "timeout", "Resolved"))
	Set open = $ClassMethod(PS, "FamilyCase", svc, partner, "timeout", "")
	Do $$$AssertEquals(##class(SignalNoir.Application.PrecedentService).AgentEnabled(), 0, "off by default")
	Do $$$AssertEquals(##class(SignalNoir.Application.InvestigationService).Precedents(open), "", "no precedents when off")
	Set items = ##class(SignalNoir.Application.InvestigationService).Precedents(open, p)
	Do $$$AssertTrue($IsObject(items) && (items.%Size() >= 1), "precedents when on")
	Set ^SignalNoir.TestScript("agent", "content") = "{""diagnosis"": {""summary"": ""s"", ""claims"": [], ""hypotheses"": []}, ""action"": ""REQUEST_REVIEW"", ""params"": {}, ""confidence"": ""LOW"", ""preconditions"": []}"
	Set agent = ##class(SignalNoir.Tests.Fakes.AgentWithFakeRuntime).%New()
	Set ctx = ##class(SignalNoir.Core.Dto.InvestigationContext).%New()
	Set ctx.investigationId = "inv-neutral", ctx.case = svc.GetCase(open).obj, ctx.order = ctx.case.order
	Set without = agent.Propose(ctx)
	Set inputWithout = ##class(SignalNoir.Proposers.Agent).Input(ctx)
	Set ctx.precedents = items
	Set with = agent.Propose(ctx)
	Set inputWith = ##class(SignalNoir.Proposers.Agent).Input(ctx)
	Do $$$AssertEquals(with.obj.%ToJSON(), without.obj.%ToJSON(), "identical answer")
	Do $$$AssertNotTrue(inputWithout [ "PRECEDENTS", "no block when absent")
	Do $$$AssertTrue(inputWith [ "PRECEDENTS (similarity results from earlier Cases; not Evidence", "labelled block when present")
	Do $$$AssertEquals($Piece(inputWith, $Char(10), 1, 6), inputWithout, "Evidence and CHECKS blocks unchanged")
	Kill ^SignalNoir.TestScript("agent")
	Do $ClassMethod(PS, "Cleanup", p)
}

/// 015 T020 - rebuild after a model change, interrupted and resumed
Method TestRebuild()
{
	Set PS = "SignalNoir.Tests.Application.PrecedentSupport"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set a = $ClassMethod(PS, "Service", svc)
	Set partner = ##class(SignalNoir.Tests.Support).Uid("PREB")
	Set c1 = $ClassMethod(PS, "FamilyCase", svc, partner, "timeout", "Resolved")
	Do a.IndexCase(c1)
	Set b = $ClassMethod(PS, "Service", svc)
	; interrupted: the mark stays set and searches say so
	Set state = ##class(SignalNoir.Application.Model.PrecedentIndexState).Current()
	Set state.rebuilding = 1
	Do state.%Save()
	Do $$$AssertEquals(b.Search(c1).details.status, "rebuilding", "rebuilding")
	Do b.IndexCase(c1)
	Set r = b.Rebuild()
	Do $$$AssertTrue(r.ok, "rebuild completes")
	Do $$$AssertEquals($ClassMethod(PS, "Records", c1, b.Embedder.Model()), 1, "once for the new model")
	Do $$$AssertEquals($ClassMethod(PS, "Records", c1, a.Embedder.Model()), 0, "old model removed")
	Do $$$AssertEquals(##class(SignalNoir.Application.Model.PrecedentIndexState).Current().rebuilding, 0, "mark cleared")
	Set eligible = ##class(SignalNoir.Tests.Support).Count("SELECT COUNT(*) FROM SignalNoir_Application_Model.CaseRecord WHERE state IN ('Resolved','ResolvedByPriorReceipt','Cancelled','Failed') AND (runId IS NULL OR runId = '') AND (replay IS NULL OR replay = 0) AND 1 = ?", 1)
	Do $$$AssertEquals(r.details.total, eligible, "every eligible Case, once")
	Do $ClassMethod(PS, "Cleanup", b)
}

}
