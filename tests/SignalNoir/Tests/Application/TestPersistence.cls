Class SignalNoir.Tests.Application.TestPersistence Extends %UnitTest.TestCase
{

/// T008 - persistence and optimistic concurrency through the real
/// CaseService in namespace IRISAPP.
Method TestStaleSaveRejectedByVersionProperty()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set order = ..MakeOrder(##class(SignalNoir.Tests.Support).Uid("T008-stale"))
	Set r = ..Open(svc, order.orderId)
	Do $$$AssertTrue(r.ok, "order accepted and its first Exception opened the Case")
	If 'r.ok Return
	Set caseId = r.ref

	; two writers open the same Case
	Set w1 = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(caseId)
	Set w2 = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(caseId)
	Do $$$AssertTrue($IsObject(w1), "writer 1 opened")
	Do $$$AssertTrue($IsObject(w2), "writer 2 opened")

	; writer 1 commits: VERSIONPROPERTY keeps the version in step with the row
	Set v1 = w1.Version
	Set w1.reviewReason = "writer one"
	Set sc1 = w1.%Save()
	Do $$$AssertEquals($$$ISOK(sc1), 1, "first save wins")
	Do $$$AssertTrue(w1.Version > v1, "the version increments on save")

	; writer 2 presents a version that is not the stored one: IRIS rejects the save
	Set wrong = 9999
	Set w2.reviewReason = "writer two"
	Set w2.Version = wrong
	Set sc2 = w2.%Save()
	Do $$$AssertEquals($$$ISERR(sc2), 1, "stale save rejected by VERSIONPROPERTY")
}

Method TestStaleTransitionRejected()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set order = ..MakeOrder(##class(SignalNoir.Tests.Support).Uid("T008-cas"))
	Set r = ..Open(svc, order.orderId)
	Do $$$AssertTrue(r.ok, "order accepted and its first Exception opened the Case")
	If 'r.ok Return
	Set caseId = r.ref
	Set cur = svc.GetCase(caseId)
	Do $$$AssertTrue(cur.ok, "case readable")
	Set version = cur.obj.caseVersion

	; a transition based on the current version succeeds
	Set t1 = svc.Transition(caseId, version, "Investigating", "system", ..MakeEvent())
	Do $$$AssertTrue(t1.ok, "transition with the current version succeeds")

	; a transition based on the stale version loses visibly
	Set t2 = svc.Transition(caseId, version, "ReviewRequired", "system", ..MakeEvent())
	Do $$$AssertTrue(t2.ok = 0, "stale transition refused")
	Do $$$AssertEquals(t2.code, "STALE_VERSION", "conflict uses the closed vocabulary")
}

Method TestAtMostOneNonTerminalCasePerOrderId()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set orderId = ##class(SignalNoir.Tests.Support).Uid("T008-dup")
	Set r1 = ..Open(svc, orderId)
	Do $$$AssertTrue(r1.ok, "first Exception opens the Case")
	Set r2 = svc.RecordException(orderId, ##class(SignalNoir.Tests.Support).Exception())
	Do $$$AssertTrue(r2.ok, "second Exception is recorded")
	Do $$$AssertEquals(r2.ref, r1.ref, "it joins the non-terminal Case instead of opening another")
}

Method TestFreshOpenIdAfterReconnectReturnsSameCaseAndTimeline()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set orderId = ##class(SignalNoir.Tests.Support).Uid("T008-reconnect")
	Set r = ..Open(svc, orderId)
	Do $$$AssertTrue(r.ok, "order accepted")
	If 'r.ok Return
	Set caseId = r.ref

	; snapshot what we read through the queries
	Set before = svc.GetCase(caseId)
	Do $$$AssertTrue(before.ok, "case readable")
	Set tl = svc.GetTimeline(caseId, 0)
	Do $$$AssertTrue(tl.ok, "timeline readable")
	Set beforeJson = ..TimelineJson(tl.list)

	; simulate a reconnect: drop every in-memory reference and re-open
	Kill svc, before, tl
	Set svc2 = ##class(SignalNoir.Application.CaseService).Default()
	Set after = svc2.GetCase(caseId)
	Do $$$AssertTrue(after.ok, "case readable after reconnect")
	Do $$$AssertEquals(after.obj.caseId, caseId, "same caseId")
	Do $$$AssertEquals(after.obj.orderId, orderId, "same orderId")
	Do $$$AssertEquals(after.obj.state, "Open", "same state")
	Set tl2 = svc2.GetTimeline(caseId, 0)
	Do $$$AssertEquals(..TimelineJson(tl2.list), beforeJson, "timeline identical after reconnect")
}

/// 003: an Order becomes a Case on its first Exception. Accepts a valid
/// Origin Order and records a timeout; Result.ref is the caseId.
ClassMethod Open(svc As SignalNoir.Application.CaseService, orderId As %String) As SignalNoir.Core.Result
{
	Set a = svc.AcceptOrder(##class(SignalNoir.Tests.Support).Order(orderId))
	If 'a.ok Return a
	Return svc.RecordException(orderId, ##class(SignalNoir.Tests.Support).Exception())
}

/// A minimal synthetic Order
ClassMethod MakeOrder(orderId As %String) As SignalNoir.Core.Dto.Order
{
	Set order = ##class(SignalNoir.Core.Dto.Order).%New()
	Set order.orderId = orderId
	Set snapshot = ##class(%DynamicObject).%New()
	Do snapshot.%Set("patientId", "P-" _ orderId)
	Set exams = ##class(%DynamicArray).%New()
	Do exams.%Push("GLICJ")
	Do snapshot.%Set("exams", exams)
	Set order.snapshot = snapshot
	Set order.equivalenceKey = "P-" _ orderId _ "|glicj|2026-10-23T10:00:00Z|SP-1"
	Set order.receivedAt = ##class(SignalNoir.Application.SystemClock).%New().NowUtc()
	Set order.synthetic = 1
	Return order
}

/// A minimal timeline event
ClassMethod MakeEvent() As SignalNoir.Core.Dto.TimelineEvent
{
	Set event = ##class(SignalNoir.Core.Dto.TimelineEvent).%New()
	Set event.type = "StateChanged"
	Set event.actor = "system"
	Set event.refId = ""
	Set event.payload = ##class(%DynamicObject).%New()
	Return event
}

ClassMethod TimelineJson(list As %ListOfObjects) As %String
{
	Set out = "["
	For i = 1 : 1 : list.Count() {
		Set ev = list.GetAt(i)
		If i > 1 Set out = out _ ","
		Set out = out _ ev.seq _ "|" _ ev.type _ "|" _ ev.actor _ "|" _ ev.refId
	}
	Return out _ "]"
}

}
