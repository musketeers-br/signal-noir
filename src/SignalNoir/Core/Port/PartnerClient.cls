Class SignalNoir.Core.Port.PartnerClient Extends %RegisteredObject [ Abstract ]
{

/// Effect seam (seam contract). Send/FetchReceipts are the seam's v1 shape;
/// the execution path (feature 008) uses Deliver, SearchReceipts, Health and
/// OriginStatus, which follow the Partner's HTTP contract (openapi-sim.yaml).
Method Send(orderId As %String, action As %String, params As %DynamicObject, idempotencyKey As %String) As SignalNoir.Core.Result
{
	Return $$$ERROR($$$GeneralError, "Abstract port method - override in adapter or fake")
}

Method FetchReceipts(orderId As %String) As SignalNoir.Core.Result
{
	Return $$$ERROR($$$GeneralError, "Abstract port method - override in adapter or fake")
}

/// One Attempt: request is a DeliveryRequest. Returns the raw answer
/// {answered, status, text, json, replayed, error}; never classifies it
/// (Core.ResponseClass does)
Method Deliver(partnerId As %String, request As %DynamicObject) As %DynamicObject
{
	Return {"answered": false, "error": "no partner client"}
}

/// query: {idempotencyKey?, orderId?, scenarioInstanceId?}. Result.obj = {items}
/// (an empty list is an answer); an error when the Partner could not be read
Method SearchReceipts(query As %DynamicObject) As SignalNoir.Core.Result
{
	Return ##class(SignalNoir.Core.Result).Error("", "no partner client")
}

/// Result.obj = PartnerHealth, or an error when unreadable
Method Health(partnerId As %String, scenarioInstanceId As %String) As SignalNoir.Core.Result
{
	Return ##class(SignalNoir.Core.Result).Error("", "no partner client")
}

/// Result.obj = OriginOrderStatus, or an error when unreadable
Method OriginStatus(orderId As %String) As SignalNoir.Core.Result
{
	Return ##class(SignalNoir.Core.Result).Error("", "no partner client")
}

}
