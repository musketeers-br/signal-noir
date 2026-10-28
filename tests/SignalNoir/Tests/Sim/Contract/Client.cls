Class SignalNoir.Tests.Sim.Contract.Client Extends %RegisteredObject
{

/// HTTP client of the Simulator contract tests (research D13): calls
/// localhost:52773/sim/api/v1 and records captures for the schema check.
Parameter BASE = "/sim/api/v1";

Parameter CAPTURES = "/home/irisowner/dev/tests/sim-contract/captures/";

/// {status, body (JSON or text, "" when empty), text, replayed, location}
ClassMethod Call(method As %String, path As %String, body = "", timeout As %Integer = 20) As %DynamicObject
{
	Set req = ##class(%Net.HttpRequest).%New()
	Set req.Server = "localhost", req.Port = 52773, req.Timeout = timeout
	If $IsObject(body) {
		Set req.ContentType = "application/json"
		Do req.EntityBody.Write(body.%ToJSON())
	}
	Set sc = $Select(method = "POST": req.Post(..#BASE _ path), 1: req.Get(..#BASE _ path))
	If $$$ISERR(sc) Return {"status": 0, "error": ($System.Status.GetErrorText(sc)), "body": "", "text": ""}
	Set resp = req.HttpResponse
	Set text = ""
	If $IsObject(resp.Data) {
		While 'resp.Data.AtEnd {
			Set text = text _ resp.Data.Read(32000)
		}
	} Else {
		Set text = resp.Data
	}
	Set parsed = ""
	Try {
		If text '= "" Set parsed = {}.%FromJSON(text)
	}
	Catch {
		Set parsed = ""
	}
	Set out = {"status": (resp.StatusCode), "text": (text), "replayed": (resp.GetHeader("IDEMPOTENT-REPLAYED")), "location": (resp.GetHeader("LOCATION")), "contentType": (resp.ContentType)}
	If $IsObject(parsed) {
		Do out.%Set("body", parsed)
	} Else {
		Do out.%Set("body", "")
	}
	Return out
}

/// Writes one capture and its manifest entry (replacing an entry of the same file)
ClassMethod Capture(name As %String, operationId As %String, status As %Integer, schema As %String, body As %DynamicAbstractObject)
{
	Set file = name _ ".json"
	Set stream = ##class(%Stream.FileCharacter).%New()
	Set stream.Filename = ..#CAPTURES _ file, stream.TranslateTable = "UTF8"
	; a text/plain answer is captured as a JSON string
	Do stream.Write($Select($IsObject(body): ..Pretty(body), 1: $Extract([(body)].%ToJSON(), 2, *-1)))
	Do stream.%Save()
	Lock +^SignalNoir.Tests.Sim.Manifest:10
	Set manifest = ..ReadManifest()
	Set kept = []
	For i = 0 : 1 : manifest.fixtures.%Size() - 1 {
		If manifest.fixtures.%Get(i).file '= file Do kept.%Push(manifest.fixtures.%Get(i))
	}
	Do kept.%Push({"file": (file), "operationId": (operationId), "status": (status), "schema": (schema)})
	Set manifest.fixtures = kept
	Set out = ##class(%Stream.FileCharacter).%New()
	Set out.Filename = ..#CAPTURES _ "manifest.json", out.TranslateTable = "UTF8"
	Do out.Write(..Pretty(manifest))
	Do out.%Save()
	Lock -^SignalNoir.Tests.Sim.Manifest
}

ClassMethod ReadManifest() As %DynamicObject
{
	Set in = ##class(%Stream.FileCharacter).%New()
	Set in.Filename = ..#CAPTURES _ "manifest.json", in.TranslateTable = "UTF8"
	If in.Size = 0 Return {"fixtures": []}
	Return {}.%FromJSON(in)
}

ClassMethod Pretty(obj As %DynamicAbstractObject) As %String
{
	Set formatter = ##class(%JSON.Formatter).%New()
	Set formatter.Indent = 1, formatter.IndentChars = "  "
	Do formatter.FormatToString(obj, .out)
	Return out
}

/// A created and emitted instance of a variant: {sci, orders: [order...]}
ClassMethod Emitted(family As %String, variant As %String, seed As %Integer = 7, timeScale As %Numeric = 1) As %DynamicObject
{
	Set c = ..Call("POST", "/scenarios", {"family": (family), "variant": (variant), "seed": (seed), "timeScale": (timeScale)})
	Set sci = c.body.scenarioInstanceId
	Set e = ..Call("POST", "/scenarios/" _ sci _ "/emissions")
	Set orders = []
	For i = 0 : 1 : e.body.emitted.%Size() - 1 Do orders.%Push(e.body.emitted.%Get(i).order)
	Return {"sci": (sci), "orders": (orders), "partnerId": (c.body.partnerId), "emission": (e.body)}
}

/// A delivery request for an Order of an instance
ClassMethod Delivery(sci As %String, order As %DynamicObject, key As %String, transactionId As %String = "txn-test-1") As %DynamicObject
{
	Return {"idempotencyKey": (key), "transactionId": (transactionId), "scenarioInstanceId": (sci), "runId": null, "order": (order)}
}

}
