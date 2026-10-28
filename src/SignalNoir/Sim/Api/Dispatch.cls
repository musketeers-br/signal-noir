Class SignalNoir.Sim.Api.Dispatch Extends %CSP.REST
{

/// The Simulator's HTTP surface, /sim/api/v1, one to one with
/// contracts/openapi-sim.yaml (research D11). Interface errors use the
/// envelope with INVALID_REQUEST, NOT_FOUND or IDEMPOTENCY_KEY_REUSED;
/// Partner delivery answers are written as the scenario declares.
Parameter CONTENTTYPE = "application/json";

Parameter CHARSET = "utf-8";

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/partners/:partnerId/orders" Method="POST" Call="Deliver"/>
<Route Url="/partners/:partnerId/health" Method="GET" Call="Health"/>
<Route Url="/partners/:partnerId/history" Method="GET" Call="History"/>
<Route Url="/receipts" Method="GET" Call="SearchReceipts"/>
<Route Url="/receipts/:receiptId" Method="GET" Call="GetReceipt"/>
<Route Url="/origin/feed" Method="GET" Call="Feed"/>
<Route Url="/origin/orders" Method="GET" Call="OriginOrders"/>
<Route Url="/origin/orders/:orderId" Method="GET" Call="OriginStatus"/>
<Route Url="/scenario-catalog" Method="GET" Call="Catalog"/>
<Route Url="/scenarios" Method="POST" Call="CreateScenario"/>
<Route Url="/scenarios/:sci" Method="GET" Call="GetScenario"/>
<Route Url="/scenarios/:sci/emissions" Method="POST" Call="Emit"/>
<Route Url="/scenarios/:sci/events" Method="POST" Call="Event"/>
<Route Url="/(.*)" Method="GET" Call="NotFound"/>
<Route Url="/(.*)" Method="POST" Call="NotFound"/>
</Routes>
}

/// POST /partners/{partnerId}/orders (deliverOrder)
ClassMethod Deliver(partnerId As %String) As %Status
{
	Set r = ##class(SignalNoir.Sim.Partner).Deliver(partnerId, ..Body())
	If 'r.ok Return ..WriteError(r)
	Set answer = r.obj, hold = answer.hold
	; the gateway must outlast the hold, so the caller sees its own timeout (V4)
	If hold > 1 Set %response.Timeout = (hold \ 1) + 30
	If hold > 0 Hang hold
	If answer.replayed Do %response.SetHeader("Idempotent-Replayed", "true")
	If answer.status = "none" {
		; the caller gave up long ago: a 5xx without a body
		Set %response.Status = "504 Gateway Timeout"
		Return $$$OK
	}
	Set %response.Status = ..StatusLine(answer.status)
	Set body = answer.body
	If $IsObject(body) {
		Write body.%ToJSON()
	} ElseIf body '= "" {
		Set %response.ContentType = "text/plain"
		Write body
	}
	Return $$$OK
}

ClassMethod Health(partnerId As %String) As %Status
{
	Set sci = ..Param("scenarioInstanceId")
	If sci = "" Return ..WriteError(..Invalid("scenarioInstanceId is required"))
	Return ..WriteResult(##class(SignalNoir.Sim.Partner).Health(partnerId, sci))
}

ClassMethod History(partnerId As %String) As %Status
{
	Set sci = ..Param("scenarioInstanceId")
	If sci = "" Return ..WriteError(..Invalid("scenarioInstanceId is required"))
	Set since = ..Param("since")
	If (since '= "") && '##class(SignalNoir.Sim.Clock).IsUtc(since) Return ..WriteError(..Invalid("since must be a UTC instant"))
	Set limit = ..Limit()
	If limit = "" Return ..WriteError(..Invalid("limit must be an integer from 1 to 200"))
	Return ..WriteResult(##class(SignalNoir.Sim.Partner).History(partnerId, sci, ..Param("orderId"), since, limit))
}

ClassMethod SearchReceipts() As %Status
{
	Set after = ..Param("receivedAfter")
	If (after '= "") && '##class(SignalNoir.Sim.Clock).IsUtc(after) Return ..WriteError(..Invalid("receivedAfter must be a UTC instant"))
	Set limit = ..Limit()
	If limit = "" Return ..WriteError(..Invalid("limit must be an integer from 1 to 200"))
	Return ..WriteResult(##class(SignalNoir.Sim.Receipts).Search(..Param("idempotencyKey"), ..Param("orderId"), ..Param("patientId"), ..Param("scenarioInstanceId"), after, limit))
}

ClassMethod GetReceipt(receiptId As %String) As %Status
{
	Return ..WriteResult(##class(SignalNoir.Sim.Receipts).Get(receiptId))
}

ClassMethod Feed() As %Status
{
	Set after = ..Param("afterSeq")
	If after = "" Set after = 0
	If after '? 1.N Return ..WriteError(..Invalid("afterSeq must be an integer >= 0"))
	Set limit = ..Limit()
	If limit = "" Return ..WriteError(..Invalid("limit must be an integer from 1 to 200"))
	Return ..WriteResult(##class(SignalNoir.Sim.Origin).Feed(+after, limit))
}

ClassMethod OriginOrders() As %Status
{
	Set patientId = ..Param("patientId"), sci = ..Param("scenarioInstanceId")
	If (patientId = "") || (sci = "") Return ..WriteError(..Invalid("patientId and scenarioInstanceId are required"))
	Set after = ..Param("emittedAfter")
	If (after '= "") && '##class(SignalNoir.Sim.Clock).IsUtc(after) Return ..WriteError(..Invalid("emittedAfter must be a UTC instant"))
	Set limit = ..Limit()
	If limit = "" Return ..WriteError(..Invalid("limit must be an integer from 1 to 200"))
	Return ..WriteResult(##class(SignalNoir.Sim.Origin).ByPatient(sci, patientId, after, limit))
}

ClassMethod OriginStatus(orderId As %String) As %Status
{
	Return ..WriteResult(##class(SignalNoir.Sim.Origin).Status(orderId))
}

ClassMethod Catalog() As %Status
{
	Set family = ..Param("family"), set = ..Param("set")
	If (family '= "") && '$ListFind($ListFromString(##class(SignalNoir.Sim.Scenarios).#FAMILIES), family) Return ..WriteError(..Invalid("unknown family " _ family))
	If (set '= "") && (set '= "tuning") && (set '= "test") Return ..WriteError(..Invalid("set must be tuning or test"))
	Return ..WriteResult(##class(SignalNoir.Sim.Result).Ok({"items": (##class(SignalNoir.Sim.Catalog.Loader).List(family, set)), "serverTime": (##class(SignalNoir.Sim.Clock).NowUtc())}))
}

ClassMethod CreateScenario() As %Status
{
	Set r = ##class(SignalNoir.Sim.Scenarios).Create(..Body())
	If r.ok && $IsObject(r.details) Do %response.SetHeader("Location", r.details.location)
	Return ..WriteResult(r)
}

ClassMethod GetScenario(sci As %String) As %Status
{
	Return ..WriteResult(##class(SignalNoir.Sim.Scenarios).Get(sci))
}

ClassMethod Emit(sci As %String) As %Status
{
	Return ..WriteResult(##class(SignalNoir.Sim.Scenarios).Emit(sci))
}

ClassMethod Event(sci As %String) As %Status
{
	Return ..WriteResult(##class(SignalNoir.Sim.Scenarios).Event(sci, ..Body()))
}

ClassMethod NotFound(path As %String) As %Status
{
	Return ..WriteError(##class(SignalNoir.Sim.Result).Error("NOT_FOUND", "no such resource: /" _ path))
}

ClassMethod WriteResult(r As SignalNoir.Sim.Result) As %Status
{
	If 'r.ok Return ..WriteError(r)
	Set %response.Status = ..StatusLine(r.status)
	Write r.obj.%ToJSON()
	Return $$$OK
}

ClassMethod WriteError(r As SignalNoir.Sim.Result) As %Status
{
	Set %response.Status = $Case(r.code, "NOT_FOUND": "404 Not Found", "IDEMPOTENCY_KEY_REUSED": "422 Unprocessable Entity", : "400 Bad Request")
	Set code = $Select($ListFind($ListBuild("INVALID_REQUEST", "NOT_FOUND", "IDEMPOTENCY_KEY_REUSED"), r.code): r.code, 1: "INVALID_REQUEST")
	Write {"error": {"code": (code), "message": (r.message), "details": ($Select($IsObject(r.details): r.details, 1: {}))}}.%ToJSON()
	Return $$$OK
}

ClassMethod StatusLine(status As %Integer) As %String
{
	Return status _ " " _ $Case(status, 200: "OK", 201: "Created", 202: "Accepted", 400: "Bad Request", 404: "Not Found", 409: "Conflict", 422: "Unprocessable Entity", 500: "Internal Server Error", 503: "Service Unavailable", : "Status")
}

/// The JSON body, or "" when there is none or it does not parse
ClassMethod Body()
{
	Set body = ""
	Try {
		If $IsObject(%request.Content) && (%request.Content.Size > 0) Set body = {}.%FromJSON(%request.Content)
	}
	Catch {
		Set body = ""
	}
	Return body
}

ClassMethod Param(name As %String) As %String
{
	Return $Get(%request.Data(name, 1))
}

/// limit in [1, 200], default 50; "" when invalid
ClassMethod Limit() As %String
{
	Set limit = ..Param("limit")
	If limit = "" Return 50
	If (limit '? 1.N) || (limit < 1) || (limit > 200) Return ""
	Return +limit
}

ClassMethod Invalid(message As %String) As SignalNoir.Sim.Result
{
	Return ##class(SignalNoir.Sim.Result).Error("INVALID_REQUEST", message)
}

}
