Class SignalNoir.Core.Port.PartnerClient Extends %RegisteredObject [ Abstract ]
{

/// Effect seam (seam contract). Not called in this slice.
Method Send(orderId As %String, action As %String, params As %DynamicObject, idempotencyKey As %String) As SignalNoir.Core.Result
{
	Return $$$ERROR($$$GeneralError, "Abstract port method - override in adapter or fake")
}

Method FetchReceipts(orderId As %String) As SignalNoir.Core.Result
{
	Return $$$ERROR($$$GeneralError, "Abstract port method - override in adapter or fake")
}

}
