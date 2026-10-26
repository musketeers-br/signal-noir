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
	Do $$$AssertEquals($ListLength(base), 5, "five base Tools leave one call for the proposer")
	For i = 1 : 1 : $ListLength(base) {
		Do $$$AssertTrue(##class(SignalNoir.Core.ToolCatalog).IsReadTool($ListGet(base, i)), "base Tool is a reading Tool")
	}
}

}
