Class SignalNoir.Tests.Fakes.ScriptedPartner Extends SignalNoir.Core.Port.PartnerClient
{

/// Test-only Partner (feature 008): declared health, Origin status, a queue
/// of delivery answers, Receipts kept in memory with the Partner's duplicate
/// rule (same key + payload -> original Receipt; same key, other payload ->
/// 422) applied before the script, and a call log. In-process only.
/// UP, DEGRADED, DOWN, or "" (unreadable)
Property HealthStatus As %String [ InitialExpression = "UP" ];

Property Maintenance As %Boolean [ InitialExpression = 0 ];

/// active, cancelled, or "" (unreadable)
Property OriginStatusValue As %String [ InitialExpression = "active" ];

Property ReceiptsReadable As %Boolean [ InitialExpression = 1 ];

/// Answers in order; each {status, text?, receipt?} or {lose: 1} (records the
/// Receipt, answer lost) or {timeout: 1} (nothing recorded, no answer). When
/// empty: 200 with a Receipt.
Property Answers As %DynamicArray;

Property Receipts As %DynamicArray;

Property Deliveries As %Integer [ InitialExpression = 0 ];

Property Sent As %DynamicArray;

/// Calls by kind (health, status, receipts, deliver)
Property Calls As %DynamicObject;

Method %OnNew() As %Status
{
	Set ..Answers = [], ..Receipts = [], ..Sent = [], ..Calls = {"health": 0, "status": 0, "receipts": 0, "deliver": 0}
	Return $$$OK
}

Method Deliver(partnerId As %String, request As %DynamicObject) As %DynamicObject
{
	Set ..Calls.deliver = ..Calls.deliver + 1
	Do ..Sent.%Push(request)
	Set key = request.idempotencyKey, canon = ##class(SignalNoir.Core.EffectKey).Canonical(request.order)
	For i = 0 : 1 : ..Receipts.%Size() - 1 {
		Set r = ..Receipts.%Get(i)
		If r.idempotencyKey '= key Continue
		Set reused = "{""error"":{""code"":""IDEMPOTENCY_KEY_REUSED""}}"
		If r.canon '= canon Return {"answered": true, "status": 422, "text": (reused)}
		Return {"answered": true, "status": 200, "json": (..Public(r)), "replayed": true}
	}
	Set ..Deliveries = ..Deliveries + 1
	Set answer = $Select(..Answers.%Size() > 0: ..Answers.%Remove(0), 1: {"status": 200, "receipt": 1})
	If answer.%Get("timeout") Return {"answered": false, "error": "timeout"}
	If answer.%Get("lose") || answer.%Get("receipt") {
		Set r = ..Record(partnerId, request, canon)
		If answer.%Get("lose") Return {"answered": false, "error": "timeout"}
		Return {"answered": true, "status": (answer.status), "json": (..Public(r))}
	}
	If answer.%IsDefined("json") Return {"answered": true, "status": (answer.status), "json": (answer.json)}
	Return {"answered": true, "status": (answer.status), "text": (answer.%Get("text"))}
}

Method SearchReceipts(query As %DynamicObject) As SignalNoir.Core.Result
{
	Set ..Calls.receipts = ..Calls.receipts + 1
	If '..ReceiptsReadable Return ##class(SignalNoir.Core.Result).Error("", "simulator unreachable: scripted")
	Set items = []
	For i = 0 : 1 : ..Receipts.%Size() - 1 {
		Set r = ..Receipts.%Get(i)
		If (query.%Get("idempotencyKey") '= "") && (r.idempotencyKey '= query.idempotencyKey) Continue
		If (query.%Get("orderId") '= "") && (r.orderId '= query.orderId) Continue
		Do items.%Push(..Public(r))
	}
	Return ##class(SignalNoir.Core.Result).OkObj({"items": (items), "serverTime": "2026-10-28T10:00:00Z"})
}

Method Health(partnerId As %String, scenarioInstanceId As %String) As SignalNoir.Core.Result
{
	Set ..Calls.health = ..Calls.health + 1
	If ..HealthStatus = "" Return ##class(SignalNoir.Core.Result).Error("", "simulator unreachable: scripted")
	Set h = {"partnerId": (partnerId), "scenarioInstanceId": (scenarioInstanceId), "status": (..HealthStatus), "checkedAt": "2026-10-28T10:00:00Z", "maintenance": null}
	If ..Maintenance Set h.maintenance = {"active": true, "startsAt": "2026-10-28T09:00:00Z", "endsAt": "2026-10-28T23:00:00Z"}
	Return ##class(SignalNoir.Core.Result).OkObj(h)
}

Method OriginStatus(orderId As %String) As SignalNoir.Core.Result
{
	Set ..Calls.status = ..Calls.status + 1
	If ..OriginStatusValue = "" Return ##class(SignalNoir.Core.Result).Error("", "simulator unreachable: scripted")
	Return ##class(SignalNoir.Core.Result).OkObj({"orderId": (orderId), "scenarioInstanceId": "sci_fake", "status": (..OriginStatusValue), "statusChangedAt": "2026-10-28T10:00:00Z"})
}

/// A Receipt already held by the Partner for an Order (e.g. an earlier delivery)
Method Hold(orderId As %String, key As %String)
{
	Do ..Receipts.%Push({"receiptId": ("rcp_pre_" _ $Increment(^SignalNoir.TestSeq)), "orderId": (orderId), "idempotencyKey": (key), "receivedAt": "2026-10-28T09:00:00Z", "partnerId": "labpartner-a", "canon": ""})
}

Method Count(orderId As %String) As %Integer
{
	Set n = 0
	For i = 0 : 1 : ..Receipts.%Size() - 1 {
		If ..Receipts.%Get(i).orderId = orderId Set n = n + 1
	}
	Return n
}

Method Record(partnerId As %String, request As %DynamicObject, canon As %String) As %DynamicObject [ Private ]
{
	Set r = {"receiptId": ("rcp_fake_" _ $Increment(^SignalNoir.TestSeq)), "orderId": (request.order.orderId), "idempotencyKey": (request.idempotencyKey), "receivedAt": "2026-10-28T10:00:01Z", "partnerId": (partnerId), "canon": (canon)}
	Do ..Receipts.%Push(r)
	Return r
}

ClassMethod Public(r As %DynamicObject) As %DynamicObject [ Private ]
{
	Return {"receiptId": (r.receiptId), "orderId": (r.orderId), "idempotencyKey": (r.idempotencyKey), "receivedAt": (r.receivedAt), "partnerId": (r.partnerId)}
}

}
