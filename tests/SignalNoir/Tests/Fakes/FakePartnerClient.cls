Class SignalNoir.Tests.Fakes.FakePartnerClient Extends SignalNoir.Core.Port.PartnerClient
{

/// Returns a canned Receipt (seam contract). It never calls a partner.

Property Receipt As SignalNoir.Core.Dto.Receipt;

Property LastIdempotencyKey As %String;

Method %OnNew() As %Status
{
	Set receipt = ##class(SignalNoir.Core.Dto.Receipt).%New()
	Set receipt.receiptId = "rcpt_000001"
	Set receipt.orderId = "order_000001"
	Set receipt.outcome = "accepted"
	Set receipt.receivedAt = "2026-01-01T00:00:00Z"
	Set receipt.raw = ##class(%DynamicObject).%New()
	Set ..Receipt = receipt
	Return $$$OK
}

Method Send(orderId As %String, action As %String, params As %DynamicObject, idempotencyKey As %String) As SignalNoir.Core.Result
{
	Set ..LastIdempotencyKey = idempotencyKey
	Return ##class(SignalNoir.Core.Result).OkObj(..Receipt)
}

Method FetchReceipts(orderId As %String) As SignalNoir.Core.Result
{
	Set list = ##class(%ListOfObjects).%New()
	Do list.Insert(..Receipt)
	Return ##class(SignalNoir.Core.Result).OkList(list)
}

}
