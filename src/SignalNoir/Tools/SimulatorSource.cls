Class SignalNoir.Tools.SimulatorSource Extends SignalNoir.Core.Port.EvidenceSource
{

/// Reads evidence from the Simulator's read endpoints (contracts/openapi-sim.yaml),
/// GET only, over HTTP: no part of the application references Simulator code
/// (Constitution I). A failure to answer is absence of information, never a
/// negative finding.
Parameter TIMEOUTSECONDS = 5;

Method Read(toolName As %String, args As %DynamicObject) As SignalNoir.Core.Result
{
	Set base = $System.Util.GetEnviron("SN_SIM_BASE_URL")
	If base = "" Return ..Absent("simulator not configured (SN_SIM_BASE_URL)")
	Set partnerId = args.%Get("partnerId"), sid = args.%Get("scenarioInstanceId"), orderId = args.%Get("orderId")
	Set query = ""
	If toolName = "tool.partner_health" {
		Set path = "/partners/" _ ..Enc(partnerId) _ "/health"
		Set query = "scenarioInstanceId=" _ ..Enc(sid)
	} ElseIf toolName = "tool.partner_failure_history" {
		Set path = "/partners/" _ ..Enc(partnerId) _ "/history"
		Set query = "scenarioInstanceId=" _ ..Enc(sid) _ "&orderId=" _ ..Enc(orderId)
	} ElseIf toolName = "tool.origin_order_status" {
		Set path = "/origin/orders/" _ ..Enc(orderId)
		If sid '= "" Set query = "scenarioInstanceId=" _ ..Enc(sid)
	} ElseIf toolName = "tool.receipts_and_orders_by_patient" {
		Set path = "/receipts"
		Set query = "patientId=" _ ..Enc(args.%Get("patientId")) _ "&scenarioInstanceId=" _ ..Enc(sid)
	} Else {
		Return ..Absent("no simulator source for " _ toolName)
	}
	Return ..Get(base, path, query)
}

Method Get(base As %String, path As %String, query As %String) As SignalNoir.Core.Result [ Private ]
{
	Set scheme = $Piece(base, "://", 1)
	Set rest = $Piece(base, "://", 2)
	Set hostPort = $Piece(rest, "/", 1)
	Set prefix = $Select($Length(rest, "/") > 1: "/" _ $Piece(rest, "/", 2, *), 1: "")
	If $Extract(prefix, *) = "/" Set prefix = $Extract(prefix, 1, *-1)
	Set req = ##class(%Net.HttpRequest).%New()
	Set req.Server = $Piece(hostPort, ":", 1)
	If $Piece(hostPort, ":", 2) '= "" Set req.Port = $Piece(hostPort, ":", 2)
	Set req.Https = (scheme = "https")
	Set req.Timeout = ..#TIMEOUTSECONDS
	Set req.OpenTimeout = ..#TIMEOUTSECONDS
	Set target = prefix _ path _ $Select(query = "": "", 1: "?" _ query)
	Set sc = $$$OK
	Try {
		Set sc = req.Get(target)
	}
	Catch ex {
		Set sc = ex.AsStatus()
	}
	If $$$ISERR(sc) Return ..Absent("simulator unreachable: " _ $System.Status.GetOneErrorText(sc))
	Set status = req.HttpResponse.StatusCode
	If (status < 200) || (status > 299) Return ..Absent("simulator answered HTTP " _ status)
	Set body = ""
	Try {
		Set body = ##class(%DynamicAbstractObject).%FromJSON(req.HttpResponse.Data)
	}
	Catch {
		Set body = ""
	}
	If '$IsObject(body) Return ..Absent("simulator answer is not JSON")
	Return ##class(SignalNoir.Core.Result).OkObj({"available": true, "result": (body)})
}

ClassMethod Enc(value As %String) As %String [ Private ]
{
	Return $ZConvert($Get(value), "O", "URL")
}

ClassMethod Absent(reason As %String) As SignalNoir.Core.Result [ Private ]
{
	Return ##class(SignalNoir.Core.Result).OkObj({"available": false, "reason": (reason)})
}

}
