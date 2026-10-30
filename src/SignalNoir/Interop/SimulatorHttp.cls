Class SignalNoir.Interop.SimulatorHttp Extends %RegisteredObject
{

/// One HTTP call to the Simulator (Constitution I: the only way to reach
/// it). Shared by the Origin feed reader and the Partner adapter.
/// Returns {answered, status, text, json, replayed, error}; never raises.
ClassMethod Call(base As %String, method As %String, path As %String, body, timeout As %Integer) As %DynamicObject
{
	If base = "" Set base = ##class(SignalNoir.Tools.SimulatorSource).Base()
	If base = "" Return {"answered": false, "error": "simulator not configured (SN_SIM_BASE_URL)"}
	Set rest = $Piece(base, "://", 2), hostPort = $Piece(rest, "/", 1)
	Set prefix = $Select($Length(rest, "/") > 1: "/" _ $Piece(rest, "/", 2, *), 1: "")
	If $Extract(prefix, *) = "/" Set prefix = $Extract(prefix, 1, *-1)
	Set req = ##class(%Net.HttpRequest).%New()
	Set req.Server = $Piece(hostPort, ":", 1), req.Https = ($Piece(base, "://", 1) = "https")
	If $Piece(hostPort, ":", 2) '= "" Set req.Port = $Piece(hostPort, ":", 2)
	Set req.Timeout = timeout, req.OpenTimeout = 5
	If $IsObject(body) {
		Set req.ContentType = "application/json"
		Do req.EntityBody.Write(body.%ToJSON())
	}
	Set sc = $$$OK
	Try {
		Set sc = $Select(method = "POST": req.Post(prefix _ path), 1: req.Get(prefix _ path))
	}
	Catch ex {
		Set sc = ex.AsStatus()
	}
	If $$$ISERR(sc) Return {"answered": false, "error": ($System.Status.GetOneErrorText(sc))}
	Set text = ""
	If $IsObject(req.HttpResponse.Data) {
		While 'req.HttpResponse.Data.AtEnd {
			Set text = text _ req.HttpResponse.Data.Read(32000)
		}
	} Else {
		Set text = req.HttpResponse.Data
	}
	Set json = ""
	Try {
		If text '= "" Set json = {}.%FromJSON(text)
	}
	Catch {
		Set json = ""
	}
	Set out = {"answered": true, "status": (req.HttpResponse.StatusCode), "text": (text)}
	Do out.%Set("json", json, $Select($IsObject(json): "", 1: "null"))
	Do out.%Set("replayed", ($ZConvert(req.HttpResponse.GetHeader("IDEMPOTENT-REPLAYED"), "L") = "true"), "boolean")
	Return out
}

}
