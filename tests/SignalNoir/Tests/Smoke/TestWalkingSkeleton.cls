Class SignalNoir.Tests.Smoke.TestWalkingSkeleton Extends %UnitTest.TestCase
{

/// T037 - Smoke test: start, accept an order, read the case and timeline,
/// restart with a fresh service and verify persistence, and exercise the
/// provider-unavailable path end to end. No provider key is required.

Method TestWalkingSkeleton()
{
	; 1. Start: bootstrap never throws and records provider availability
	Set boot = ##class(SignalNoir.Interop.Bootstrap).OnStart()
	Do $$$AssertTrue(boot.ok, "start: bootstrap ok")

	; 2. Accept an Order directly through the CaseService -> Case opens in "Open"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set orderId = "smoke-" _ $JOB
	Set order = ..MakeOrder(orderId)
	Set r = svc.AcceptOrder(order)
	Do $$$AssertTrue(r.ok, "accept: order accepted")
	Set caseId = r.ref
	Do $$$AssertTrue(caseId '= "", "accept: caseId returned")

	; 3. Read the case and its timeline
	Set g = svc.GetCase(caseId)
	Do $$$AssertTrue(g.ok, "read: case readable")
	Do $$$AssertEquals(g.obj.state, "Open", "read: state Open")
	Do $$$AssertEquals(g.obj.orderId, orderId, "read: same orderId")
	Set tl = svc.GetTimeline(caseId, 0)
	Do $$$AssertTrue(tl.ok, "read: timeline readable")
	Do $$$AssertTrue(tl.list.Count() >= 2, "read: OrderAccepted and CaseOpened both present")

	; 4. Restart: drop every in-memory reference and re-open from a fresh service
	Kill svc, g, tl
	Set svc2 = ##class(SignalNoir.Application.CaseService).Default()
	Set g2 = svc2.GetCase(caseId)
	Do $$$AssertTrue(g2.ok, "restart: case still readable")
	Do $$$AssertEquals(g2.obj.caseId, caseId, "restart: same caseId")
	Do $$$AssertEquals(g2.obj.state, "Open", "restart: state Open")
	Do $$$AssertEquals(g2.obj.caseVersion, 1, "restart: caseVersion preserved")

	; 5. Provider-unavailable path: ProcessOrder lands a new Case in ReviewRequired
	Set providerOrderId = "smoke-provider-" _ $JOB
	Set providerJson = "{""orderId"":""" _ providerOrderId _ """,""equivalenceKey"":""P-" _ providerOrderId _ "|glicj|2026-10-23T10:00:00Z|SP-1"",""receivedAt"":""2026-10-23T10:00:00Z""}"
	Set pr = ##class(SignalNoir.Interop.Service.OrderIn).ProcessOrderJson(providerJson)
	Do $$$AssertTrue(pr.ok, "provider path: order accepted")
	Set pg = svc2.GetCase(pr.ref)
	Do $$$AssertTrue(pg.ok, "provider path: case readable")
	Do $$$AssertEquals(pg.obj.state, "ReviewRequired", "provider path: state ReviewRequired")
	Do $$$AssertTrue(pg.obj.reviewReason '= "", "provider path: review reason recorded")
}

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

}