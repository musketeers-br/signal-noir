Class SignalNoir.Interop.PartnerHttp Extends SignalNoir.Core.Port.PartnerClient
{

/// The Partner adapter over the Simulator's HTTP contract (feature 008):
/// delivery, Receipts, health and Origin status. Reads answers, never
/// interprets them (classification is Core.ResponseClass).
/// The Simulator's base URL ("" = SimulatorSource.Base())
Property Base As %String(MAXLEN = 512);

/// Client timeout of a delivery (SN_PARTNER_TIMEOUT_SECONDS, default 60)
Property TimeoutSeconds As %Integer;

/// Timeout of the reads (Receipts, health, status)
Parameter READTIMEOUT = 10;

Method %OnNew() As %Status
{
	Set ..TimeoutSeconds = ##class(SignalNoir.Interop.Bootstrap).EnvSeconds("SN_PARTNER_TIMEOUT_SECONDS", 60)
	Return $$$OK
}

Method Deliver(partnerId As %String, request As %DynamicObject) As %DynamicObject
{
	Return ##class(SignalNoir.Interop.SimulatorHttp).Call(..Base, "POST", "/partners/" _ ..Enc(partnerId) _ "/orders", request, ..TimeoutSeconds)
}

Method SearchReceipts(query As %DynamicObject) As SignalNoir.Core.Result
{
	Set q = ""
	For name = "idempotencyKey", "orderId", "scenarioInstanceId" {
		If query.%Get(name) '= "" Set q = q _ $Select(q = "": "?", 1: "&") _ name _ "=" _ ..Enc(query.%Get(name))
	}
	Return ..Read("/receipts" _ q)
}

Method Health(partnerId As %String, scenarioInstanceId As %String) As SignalNoir.Core.Result
{
	Return ..Read("/partners/" _ ..Enc(partnerId) _ "/health?scenarioInstanceId=" _ ..Enc(scenarioInstanceId))
}

Method OriginStatus(orderId As %String) As SignalNoir.Core.Result
{
	Return ..Read("/origin/orders/" _ ..Enc(orderId))
}

/// GET returning the parsed JSON (Result.obj), or an error when it cannot be read
Method Read(path As %String) As SignalNoir.Core.Result [ Private ]
{
	Set http = ##class(SignalNoir.Interop.SimulatorHttp).Call(..Base, "GET", path, "", ..#READTIMEOUT)
	If 'http.answered Return ##class(SignalNoir.Core.Result).Error("", "simulator unreachable: " _ http.error)
	If (http.status '= 200) || '$IsObject(http.json) Return ##class(SignalNoir.Core.Result).Error("", "simulator answered HTTP " _ http.status)
	Return ##class(SignalNoir.Core.Result).OkObj(http.json)
}

ClassMethod Enc(value As %String) As %String [ Private ]
{
	Return $ZConvert($Get(value), "O", "URL")
}

}
