Class SignalNoir.Tests.Smoke.TestWalkingSkeleton Extends %UnitTest.TestCase
{

/// T037 (updated by 003) - Smoke test: start, accept an Order, report its
/// first failed delivery so a Case opens, read the Case and Timeline, restart
/// with a fresh service and verify persistence, and exercise the
/// provider-unavailable path end to end. No provider key is required.
Method TestWalkingSkeleton()
{
	; 1. Start: bootstrap never throws and records provider availability
	Set boot = ##class(SignalNoir.Interop.Bootstrap).OnStart()
	Do $$$AssertTrue(boot.ok, "start: bootstrap ok")

	; 2. Accept an Order; its first Exception opens a Case in "Open"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set orderId = ##class(SignalNoir.Tests.Support).Uid("smoke")
	Set a = svc.AcceptOrder(##class(SignalNoir.Tests.Support).Order(orderId))
	Do $$$AssertTrue(a.ok, "accept: order accepted")
	Do $$$AssertEquals(svc.OpenCase(orderId).code, "NOT_FOUND", "accept: no Case before a failure")
	Set r = svc.RecordException(orderId, ##class(SignalNoir.Tests.Support).Exception())
	Set caseId = r.ref
	Do $$$AssertTrue(caseId '= "", "failure: caseId returned")

	; 3. Read the case and its timeline
	Set g = svc.GetCase(caseId)
	Do $$$AssertTrue(g.ok, "read: case readable")
	Do $$$AssertEquals(g.obj.state, "Open", "read: state Open")
	Do $$$AssertEquals(g.obj.orderId, orderId, "read: same orderId")
	Set tl = svc.GetTimeline(caseId, 0)
	Do $$$AssertTrue(tl.ok, "read: timeline readable")
	Do $$$AssertEquals(tl.list.Count(), 2, "read: CaseOpened and ExceptionRecorded")

	; 4. Restart: drop every in-memory reference and re-open from a fresh service
	Kill svc, g, tl
	Set svc2 = ##class(SignalNoir.Application.CaseService).Default()
	Set g2 = svc2.GetCase(caseId)
	Do $$$AssertTrue(g2.ok, "restart: case still readable")
	Do $$$AssertEquals(g2.obj.caseId, caseId, "restart: same caseId")
	Do $$$AssertEquals(g2.obj.state, "Open", "restart: state Open")
	Do $$$AssertEquals(g2.obj.caseVersion, 1, "restart: caseVersion preserved")

	; 5. Provider-unavailable path through the Business Service entry points
	Set providerOrderId = ##class(SignalNoir.Tests.Support).Uid("smoke-provider")
	Set json = ##class(SignalNoir.Tests.Support).Snapshot(providerOrderId).%ToJSON()
	Set acc = ##class(SignalNoir.Interop.Service.OrderIn).Accept(json, "tx-smoke")
	Do $$$AssertTrue(acc.ok, "provider path: order accepted")
	Set pr = ##class(SignalNoir.Interop.Service.OrderIn).ReportException(providerOrderId, "timeout", "", "", "", "att-1")
	Do $$$AssertTrue(pr.ok, "provider path: failure recorded")
	Set pg = svc2.GetCase(pr.ref)
	Do $$$AssertTrue(pg.ok, "provider path: case readable")
	Do $$$AssertEquals(pg.obj.state, "ReviewRequired", "provider path: state ReviewRequired")
	Do $$$AssertTrue(pg.obj.reviewReason '= "", "provider path: review reason recorded")
}

}
