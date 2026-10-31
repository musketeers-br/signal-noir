Class SignalNoir.Tests.Application.TestPrecedentSearch Extends %UnitTest.TestCase
{

/// 015 T010/T011 - search, honest statuses and the search record
Method TestSameFamilyFirst()
{
	Set PS = "SignalNoir.Tests.Application.PrecedentSupport"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set p = $ClassMethod(PS, "Service", svc)
	Set partner = ##class(SignalNoir.Tests.Support).Uid("PSRCH")
	For family = "timeout", "mapping", "partnerdown", "rejected" {
		For i = 1, 2 {
			Set caseId = $ClassMethod(PS, "FamilyCase", svc, partner, family, $Select(i = 1: "Resolved", 1: "Cancelled"))
			Set fam(caseId) = family
			Do p.IndexCase(caseId)
		}
	}
	; a closed Case searching for itself never sees itself
	Set self = $Order(fam(""))
	Set r = p.Search(self, 10)
	Set it = r.details.items.%GetIterator()
	While it.%GetNext(, .item) { Do $$$AssertNotEquals(item.caseId, self, "self excluded") }
	; SC-001: the top precedent of a new Case is of its family, every time
	Set hits = 0, total = 0
	For family = "timeout", "mapping", "partnerdown", "rejected" {
		Set open = $ClassMethod(PS, "FamilyCase", svc, partner, family, "")
		Set first = p.Search(open, 5)
		Set again = p.Search(open, 5)
		Do $$$AssertEquals(first.details.status, "results", "results for " _ family)
		Do $$$AssertEquals(first.details.mode, "lexical", "lexical mode")
		Do $$$AssertEquals(first.details.items.%ToJSON(), again.details.items.%ToJSON(), "same ranking on every run")
		Set top = first.details.items.%Get(0)
		Set total = total + 1, hits = hits + ($Get(fam(top.caseId)) = family)
		Set prev = 2
		Set it = first.details.items.%GetIterator()
		While it.%GetNext(, .item) {
			Do $$$AssertTrue(item.similarity <= prev, "ordered by similarity")
			Do $$$AssertTrue(item.similarity >= p.MinSimilarity, "above the minimum")
			Do $$$AssertNotTrue(item.%IsDefined("embedding") || item.%IsDefined("rawText"), "no vector, no raw text")
			Set prev = item.similarity
		}
	}
	Do $$$AssertTrue((hits / total) >= 0.9, "top-1 same family: " _ hits _ "/" _ total)
	Do $ClassMethod(PS, "Cleanup", p)
}

Method TestStatuses()
{
	Set PS = "SignalNoir.Tests.Application.PrecedentSupport"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set p = $ClassMethod(PS, "Service", svc)
	Set partner = ##class(SignalNoir.Tests.Support).Uid("PSTAT")
	Set open = $ClassMethod(PS, "FamilyCase", svc, partner, "timeout", "")
	Do $$$AssertEquals(p.Search(open).details.status, "no_precedents", "empty")
	; a different family only: below the minimum
	Set other = $ClassMethod(PS, "FamilyCase", svc, ##class(SignalNoir.Tests.Support).Uid("POTHER"), "rejected", "Resolved")
	Do p.IndexCase(other)
	Set r = p.Search(open)
	Do $$$AssertEquals(r.details.status, "nothing_similar", "below minimum")
	Do $$$AssertEquals(r.details.items.%Size(), 0, "none listed")
	; the configured model changed: never mixes, asks for a rebuild
	Set q = $ClassMethod(PS, "Service", svc)
	Set r = q.Search(open)
	Do $$$AssertEquals(r.details.status, "needs_rebuild", "other model only")
	Do $$$AssertEquals(r.details.reason, "model_changed", "reason")
	; the embedder fails: the Case still reads, the search says why
	Set p.Embedder.Fail = 1
	Set r = p.Search(open)
	Do $$$AssertTrue(r.ok, "a value, not an error")
	Do $$$AssertEquals(r.details.status, "unavailable", "unavailable")
	Do $$$AssertEquals(r.details.reason, "provider_unavailable", "reason")
	Do $$$AssertTrue(svc.GetCase(open).ok, "the Case opens")
	Set p.Embedder.Fail = 0
	; rebuilding
	Set state = ##class(SignalNoir.Application.Model.PrecedentIndexState).Current()
	Set state.rebuilding = 1
	Do state.%Save()
	Set r = p.Search(open)
	Do $$$AssertEquals(r.details.status, "rebuilding", "rebuilding")
	Do $$$AssertEquals(r.details.items.%Size(), 0, "no stale results")
	; k bounds
	Do $$$AssertEquals(p.Search(open, 0).code, "VALIDATION_FAILED", "k=0")
	Do $$$AssertEquals(p.Search(open, 11).code, "VALIDATION_FAILED", "k=11")
	Do $$$AssertEquals(p.Search("case_nope").code, "NOT_FOUND", "unknown Case")
	Do $ClassMethod(PS, "Cleanup", p)
}

Method TestSearchRecord()
{
	Set PS = "SignalNoir.Tests.Application.PrecedentSupport"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set p = $ClassMethod(PS, "Service", svc)
	Set p.RecordSeconds = 60
	Set partner = ##class(SignalNoir.Tests.Support).Uid("PREC")
	Set closed = $ClassMethod(PS, "FamilyCase", svc, partner, "timeout", "Resolved")
	Do p.IndexCase(closed)
	Set open = $ClassMethod(PS, "FamilyCase", svc, partner, "timeout", "")
	Set version = svc.GetCase(open).obj.caseVersion
	Set r = p.Search(open)
	Do $$$AssertEquals(r.details.recorded, 1, "recorded")
	Set again = p.Search(open)
	Do $$$AssertEquals(again.details.recorded, 0, "rate-limited")
	Do $$$AssertEquals(p.Search(open, , "agent").details.recorded, 1, "another requester records")
	Set events = svc.GetTimeline(open).list, n = 0
	For i = 1 : 1 : events.Count() {
		Set ev = events.GetAt(i)
		If (ev.type '= "Annotation") || (ev.payload.kind '= "precedent_search") Continue
		Set n = n + 1
		If n > 1 Continue
		Do $$$AssertEquals(ev.actor, "system", "console search by system")
		Do $$$AssertEquals(ev.payload.mode, "lexical", "mode")
		Do $$$AssertEquals(ev.payload.count, 1, "count")
		Do $$$AssertEquals(ev.payload.precedentCaseIds.%Get(0), closed, "ids")
		Do $$$AssertTrue(ev.payload.%IsDefined("durationMs") && ev.payload.%IsDefined("model"), "duration and model")
		Do $$$AssertNotTrue(ev.payload.%ToJSON() [ "exception=", "no description text")
	}
	Do $$$AssertEquals(n, 2, "one per requester in the window")
	Do $$$AssertEquals(svc.GetCase(open).obj.caseVersion, version, "no state change")
	; a terminal Case also takes the record
	Do $$$AssertEquals(p.Search(closed).details.recorded, 1, "terminal Case")
	Do $ClassMethod(PS, "Cleanup", p)
}

/// SC-006: 1,000 precedents answer in under a second
Method TestThousandUnderASecond()
{
	Set PS = "SignalNoir.Tests.Application.PrecedentSupport"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set p = $ClassMethod(PS, "Service", svc)
	Set model = p.Embedder.Model()
	Set open = $ClassMethod(PS, "FamilyCase", svc, ##class(SignalNoir.Tests.Support).Uid("PPERF"), "timeout", "")
	Set families = $ListBuild("exception=timeout exam=HB", "exception=http_error http=422 exam=GLICJ", "exception=business_rejection http=409 exam=CREAT")
	For i = 1 : 1 : 1000 {
		Set text = "partner=P" _ (i # 7) _ " " _ $ListGet(families, i # 3 + 1) _ " final=Resolved"
		Set vec = ##class(SignalNoir.Core.LexicalVector).Csv(##class(SignalNoir.Core.LexicalVector).Of(text))
		&sql(INSERT INTO SignalNoir_Application_Model.PrecedentRecord (caseId, embeddingModel, description, rawText, mode, dimension, embedding, finalState, closedAt, durationSeconds) VALUES (:i, :model, 'synthetic', :text, 'lexical', 1536, TO_VECTOR(:vec, DOUBLE, 1536), 'Resolved', '2026-10-31T00:00:00Z', 60))
	}
	Set t = $ZHorolog
	Set r = p.Search(open, 10)
	Set ms = ($ZHorolog - t) * 1000
	Do $$$AssertTrue(r.ok, "searched")
	Do $$$AssertTrue(ms < 1000, "under 1 s: " _ ms _ " ms")
	Do $ClassMethod(PS, "Cleanup", p)
}

}
