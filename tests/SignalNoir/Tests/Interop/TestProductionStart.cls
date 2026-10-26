Class SignalNoir.Tests.Interop.TestProductionStart Extends %UnitTest.TestCase
{

/// T031 - Start the Production and route the Order through the Business Service.
/// The dev container runs a plain IRIS without Interoperability, so the
/// production is the portable shape documented in research.md D6: same name,
/// same single Business Service item, same start/stop surface.
Method TestProductionStartsAndStops()
{
	Set status = ##class(SignalNoir.Interop.Production).Start()
	Do $$$AssertTrue($$$ISOK(status), "Start returns an OK status")
	Do $$$AssertEquals($Get(^SignalNoir.Production("started")), 1, "started flag set")
	Do $$$AssertEquals($Get(^SignalNoir.Production("mode")), "portable", "mode is portable")
	Do $$$AssertTrue($Get(^SignalNoir.Production("startedAt")) '= "", "startedAt recorded")

	Set status = ##class(SignalNoir.Interop.Production).Stop()
	Do $$$AssertTrue($$$ISOK(status), "Stop returns an OK status")
	Do $$$AssertEquals(+$Get(^SignalNoir.Production("started")), 0, "started flag cleared on stop")
}

Method TestDefinitionHasExactlyTheOrderInService()
{
	Set def = ##class(SignalNoir.Interop.Production).Definition()
	Do $$$AssertTrue($IsObject(def), "definition is an object")
	Do $$$AssertEquals(def.name, "SignalNoir.Interop.Production", "production name")
	Do $$$AssertEquals(def.settings, "Default", "settings")
	Do $$$AssertTrue($IsObject(def.items), "items array present")
	Do $$$AssertEquals(def.items.%Size(), 1, "exactly one item")
	Set item = def.items.%Get(0)
	Do $$$AssertEquals(item.name, "OrderInService", "item name")
	Do $$$AssertEquals(item.type, "BusinessService", "item type")
	Do $$$AssertEquals(item.class, "SignalNoir.Interop.Service.OrderIn", "item class")
	Do $$$AssertEquals(item.poolSize, 1, "poolSize")
	Do $$$AssertEquals(item.messaging, "InMemory", "messaging")
}

Method TestStatusReportsItemsAndWebApplications()
{
	Do ##class(SignalNoir.Interop.Production).Start()
	Set status = ##class(SignalNoir.Interop.Production).Status()
	Do $$$AssertEquals(status.name, "SignalNoir.Interop.Production", "status name")
	Do $$$AssertEquals(status.mode, "portable", "status mode")
	Do $$$AssertEquals(status.started, 1, "status started")
	Do $$$AssertEquals(status.items.%Size(), 1, "one item reported")
	Do $$$AssertEquals(status.items.%Get(0), "SignalNoir.Interop.Service.OrderIn", "item class reported")
	Do $$$AssertEquals(status.webApplications.%Size(), 1, "one web application owned")
	Do $$$AssertEquals(status.webApplications.%Get(0), "/signalnoir/api/v1", "web application path")
	Do ##class(SignalNoir.Interop.Production).Stop()
}

/// The intake path the production feeds: the Business Service hands the Order to
/// the single command path and the Case appears.
Method TestOrderInServiceRoutesToTheCommandPath()
{
	; 003: OrderIn accepts the raw Origin Order, and a reported failed
	; delivery opens the Case through the single command path
	Set orderId = ##class(SignalNoir.Tests.Support).Uid("T031-route")
	Set json = ##class(SignalNoir.Tests.Support).Snapshot(orderId).%ToJSON()
	Set r = ##class(SignalNoir.Interop.Service.OrderIn).Accept(json, "tx-route")
	Do $$$AssertTrue(r.ok, "OrderIn accepted the Order")
	Do $$$AssertEquals(r.ref, orderId, "OrderIn returned the orderId")
	Set f = ##class(SignalNoir.Interop.Service.OrderIn).ReportException(orderId, "http_error", 500, "{""error"":""validation""}", "", "att-1")
	Do $$$AssertTrue(f.ok, "the failed delivery was recorded")
	Set g = ##class(SignalNoir.Application.CaseService).Default().GetCase(f.ref)
	Do $$$AssertTrue(g.ok, "the Case exists after the failure")
	Do $$$AssertEquals(g.obj.orderId, orderId, "the Case carries the orderId")
}

}
