Class SignalNoir.Core.ToolCatalog Extends %RegisteredObject
{

/// The reading Tools (contract Evidence.source tool.*). The Tools gateway
/// accepts nothing else: no write-capable Tool exists (Constitution II).
Parameter READTOOLS = "tool.partner_failure_history,tool.policies,tool.partner_health,tool.mapping_catalog,tool.receipts_and_orders_by_patient,tool.origin_order_status,tool.order_timeline";

/// The base Evidence package every Investigation collects before the
/// proposer runs (AD-9), in this order. It spends the whole budget: recent
/// receipts and orders by patient are needed for identity and prior-receipt
/// review (feature 009).
Parameter BASEPACKAGE = "tool.partner_health,tool.partner_failure_history,tool.origin_order_status,tool.mapping_catalog,tool.policies,tool.receipts_and_orders_by_patient";

ClassMethod ReadTools() As %List
{
	Return $ListFromString(..#READTOOLS, ",")
}

ClassMethod BasePackage() As %List
{
	Return $ListFromString(..#BASEPACKAGE, ",")
}

ClassMethod IsReadTool(name As %String) As %Boolean
{
	If name = "" Return 0
	Return ($ListFind(..ReadTools(), name) > 0)
}

}
