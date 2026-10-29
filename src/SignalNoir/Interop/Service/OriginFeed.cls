Class SignalNoir.Interop.Service.OriginFeed Extends %RegisteredObject
{

/// The inbound path from the Simulator's Origin (FR-1..3; spec 002 "Gap: nobody
/// reads GET /origin/feed"). Poll reads the feed after a cursor, accepts each
/// Order through OrderIn, makes the first delivery to the Partner (one
/// Attempt) and, when it ends without a valid Receipt, reports the Exception,
/// which opens the Case; the Case's Investigate request is then delivered.
/// The Simulator is reached only over HTTP (Constitution I). In the
/// Production this is the inbound Business Service's polling; the portable
/// Production calls Poll.
/// The Simulator's base URL ("" = SimulatorSource.Base())
Property Base As %String(MAXLEN = 512);

/// Cursor name under ^SignalNoir.Interop.Feed (tests use their own)
Property Cursor As %String [ InitialExpression = "default" ];

/// Deliver the Investigate request of an opened Case after its commit
Property Dispatch As %Boolean [ InitialExpression = 1 ];

/// Client timeout of the first delivery (SN_PARTNER_TIMEOUT_SECONDS, default 60)
Property TimeoutSeconds As %Integer;

Method %OnNew() As %Status
{
	Set ..TimeoutSeconds = ##class(SignalNoir.Interop.Bootstrap).EnvSeconds("SN_PARTNER_TIMEOUT_SECONDS", 60)
	Return $$$OK
}

/// Reads up to limit feed items. details: read, accepted, refused,
/// delivered, exceptions, lastSeq
Method Poll(limit As %Integer = 50) As SignalNoir.Core.Result
{
	Set after = +$Get(^SignalNoir.Interop.Feed(..Cursor))
	Set page = ..Get("/origin/feed?afterSeq=" _ after _ "&limit=" _ limit)
	If 'page.ok Return page
	Set out = {"read": 0, "accepted": 0, "refused": 0, "delivered": 0, "exceptions": 0, "lastSeq": (after)}
	Set items = page.obj.items
	For i = 0 : 1 : items.%Size() - 1 {
		Set item = items.%Get(i)
		Set out.read = out.read + 1
		Do ..Handle(item, out)
		; the cursor moves one item at a time: a crash re-reads at most this item
		Set ^SignalNoir.Interop.Feed(..Cursor) = item.feedSeq, out.lastSeq = item.feedSeq
	}
	Set r = ##class(SignalNoir.Core.Result).OkRef(out.read)
	Set r.details = out
	Return r
}

/// Moves the cursor to the end of the feed (a fresh reader on an instance
/// whose feed already holds other items)
Method SkipToHead() As SignalNoir.Core.Result
{
	Set after = +$Get(^SignalNoir.Interop.Feed(..Cursor))
	For {
		Set page = ..Get("/origin/feed?afterSeq=" _ after _ "&limit=200")
		If 'page.ok Return page
		Quit:page.obj.items.%Size()=0
		Set after = page.obj.lastSeq
	}
	Set ^SignalNoir.Interop.Feed(..Cursor) = after
	Return ##class(SignalNoir.Core.Result).OkRef(after)
}

/// One feed item: accept, deliver once, report the exception
Method Handle(item As %DynamicObject, out As %DynamicObject) [ Private ]
{
	Set order = item.order, orderId = order.orderId
	Set accepted = ##class(SignalNoir.Interop.Service.OrderIn).Accept(order.%ToJSON(), item.transactionId, $Select(item.%GetTypeOf("runId") = "string": item.runId, 1: ""), item.scenarioInstanceId)
	If 'accepted.ok {
		Set out.refused = out.refused + 1
		Quit
	}
	Set out.accepted = out.accepted + 1
	; one first delivery per Order, even if the feed is read again
	If $Data(^SignalNoir.Interop.Feed(..Cursor, "delivered", orderId)) Quit
	Set ^SignalNoir.Interop.Feed(..Cursor, "delivered", orderId) = $ZDateTime($ZTimestamp, 3)
	Set attempt = ..Deliver(item)
	If attempt.receipt {
		Set out.delivered = out.delivered + 1
		Quit
	}
	Set out.exceptions = out.exceptions + 1
	Set opened = ##class(SignalNoir.Interop.Service.OrderIn).ReportException(orderId, attempt.kind, attempt.httpStatus, attempt.body, "", attempt.attemptId)
	If opened.ok && ..Dispatch Do ..DispatchInvestigation(opened.ref)
}

/// The first Attempt: POST to the Partner with a key derived from the Order.
/// {receipt, kind, httpStatus, body, attemptId}. Only a Receipt whose
/// orderId and key match the request is a success (FR-2).
Method Deliver(item As %DynamicObject) As %DynamicObject
{
	Set order = item.order, key = ..DeliveryKey(order.orderId)
	Set request = {"idempotencyKey": (key), "transactionId": (item.transactionId), "scenarioInstanceId": (item.scenarioInstanceId), "order": (order)}
	Do request.%Set("runId", item.runId, $Select(item.%GetTypeOf("runId") = "string": "string", 1: "null"))
	Set http = ..Http("POST", "/partners/" _ $ZConvert(order.partnerId, "O", "URL") _ "/orders", request, ..TimeoutSeconds)
	Set out = {"receipt": 0, "attemptId": ("first-" _ key)}
	If 'http.answered {
		Set out.kind = "timeout", out.httpStatus = "", out.body = ""
		Return out
	}
	Set body = http.text, parsed = http.json
	If (http.status = 200) && $IsObject(parsed) && (parsed.orderId = order.orderId) && (parsed.idempotencyKey = key) && (parsed.receiptId '= "") {
		Do out.%Set("receipt", 1, "boolean")
		Return out
	}
	Set out.kind = $Select(http.status = 200: "invalid_receipt", 1: "http_error"), out.httpStatus = http.status, out.body = body
	Return out
}

/// The key of an Order's first delivery: stable per Order, opaque to the Partner
ClassMethod DeliveryKey(orderId As %String) As %String
{
	Set h = $System.Encryption.SHAHash(256, "first-delivery|" _ orderId), hex = ""
	For i = 1 : 1 : 12 Set hex = hex _ $ZConvert($Translate($Justify($ZHex($Ascii(h, i)), 2), " ", "0"), "L")
	Return "idk_first_" _ hex
}

/// Delivers the pending Investigate request of a Case opened by an exception
Method DispatchInvestigation(caseId As %String) [ Private ]
{
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT commandId FROM SignalNoir_Application_Model.OutboxRecord WHERE caseId = ? AND type = 'Investigate' AND status = 'pending'", caseId)
	While rs.%Next() {
		Job ##class(SignalNoir.Application.CommandBus).DeliverJob(rs.%Get("commandId"))
	}
}

/// GET returning the parsed JSON (Result.obj) or an error
Method Get(path As %String) As SignalNoir.Core.Result [ Private ]
{
	Set http = ..Http("GET", path, "", 10)
	If 'http.answered Return ##class(SignalNoir.Core.Result).Error("", "simulator unreachable: " _ http.error)
	If (http.status '= 200) || '$IsObject(http.json) Return ##class(SignalNoir.Core.Result).Error("", "simulator answered HTTP " _ http.status)
	Return ##class(SignalNoir.Core.Result).OkObj(http.json)
}

/// {answered, status, text, json, error} (Interop.SimulatorHttp)
Method Http(method As %String, path As %String, body, timeout As %Integer) As %DynamicObject [ Private ]
{
	Return ##class(SignalNoir.Interop.SimulatorHttp).Call(..Base, method, path, body, timeout)
}

}
