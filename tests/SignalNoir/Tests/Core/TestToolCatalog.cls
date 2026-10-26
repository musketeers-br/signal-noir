Class SignalNoir.Tests.Core.TestToolCatalog Extends %UnitTest.TestCase
{

/// 006 T009 - only reading Tools exist
Method TestReadToolsExactly()
{
	Set expected = $ListBuild("tool.partner_failure_history", "tool.policies", "tool.partner_health", "tool.mapping_catalog", "tool.receipts_and_orders_by_patient", "tool.origin_order_status", "tool.order_timeline")
	Do $$$AssertEquals(##class(SignalNoir.Core.ToolCatalog).ReadTools(), expected, "the 7 reading Tools of the contract")
	For name = "partner.send", "case.transition", "tool.partner_send", "", "TOOL.PARTNER_HEALTH" {
		Do $$$AssertEquals(##class(SignalNoir.Core.ToolCatalog).IsReadTool(name), 0, "not a reading Tool: " _ name)
	}
}

Method TestBasePackage()
{
	Set base = ##class(SignalNoir.Core.ToolCatalog).BasePackage()
	Do $$$AssertEquals($ListLength(base), 6, "six base Tools: the whole budget (009: identity and prior receipts need recorded patient records)")
	Do $$$AssertTrue($ListFind(base, "tool.receipts_and_orders_by_patient"), "recent receipts and orders by patient are in the base package")
	For i = 1 : 1 : $ListLength(base) {
		Do $$$AssertTrue(##class(SignalNoir.Core.ToolCatalog).IsReadTool($ListGet(base, i)), "base Tool is a reading Tool")
	}
}

}
