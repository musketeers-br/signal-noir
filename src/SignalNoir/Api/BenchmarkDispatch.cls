Class SignalNoir.Api.BenchmarkDispatch Extends %RegisteredObject
{

/// The benchmark routes of the product API (feature 010, contract tag Benchmark).
/// Api.Dispatch routes /benchmark-runs and /benchmark-reports here. Each Handle* method
/// returns {status, headers, body} and writes nothing, so it is tested without HTTP; the
/// Write* methods put that on the response. Errors use the closed envelope of
/// Api.Dispatch. A run is created by RunService; this class holds no rule.
ClassMethod Service() As SignalNoir.Application.Benchmark.RunService [ Private ]
{
	Return ##class(SignalNoir.Application.Benchmark.RunService).%New()
}

/// POST /benchmark-runs: 202 with the run and Location, or the closed error
ClassMethod HandleCreate(content As %String, service As SignalNoir.Application.Benchmark.RunService = "") As %DynamicObject
{
	If '$IsObject(service) Set service = ..Service()
	Set request = ""
	Try {
		Set request = ##class(%DynamicAbstractObject).%FromJSON(content)
	}
	Catch {
		Set request = ""
	}
	If '$IsObject(request) || request.%IsA("%Library.DynamicArray") {
		Return ..Failure(##class(SignalNoir.Core.Result).Error("VALIDATION_FAILED", "the request body must be a JSON object"))
	}
	Set r = service.Create(request)
	If 'r.ok Return ..Failure(r)
	Return {"status": "202 Accepted", "headers": {"Location": ("/benchmark-runs/" _ r.obj.runId)}, "body": (r.obj)}
}

/// GET /benchmark-runs/{runId}
ClassMethod HandleGet(runId As %String) As %DynamicObject
{
	Set r = ..Service().Get(runId)
	If 'r.ok Return ..Failure(r)
	Return {"status": "200 OK", "headers": {}, "body": (r.obj)}
}

/// GET /benchmark-runs?status=&limit= (limit arrives as text)
ClassMethod HandleList(status As %String, limit As %String) As %DynamicObject
{
	If limit = "" Set limit = 20
	If (limit '= +limit) || (limit '= (limit \ 1)) Return ..Failure(##class(SignalNoir.Core.Result).Error("VALIDATION_FAILED", "limit must be an integer from 1 to 100"))
	Set r = ..Service().List(status, +limit)
	If 'r.ok Return ..Failure(r)
	Return {"status": "200 OK", "headers": {}, "body": (r.obj)}
}

/// GET /benchmark-runs/{runId}/report: the final report, 404 for an unknown run, 409 until it ends
ClassMethod HandleReport(runId As %String) As %DynamicObject
{
	Set r = ##class(SignalNoir.Application.Benchmark.ReportBuilder).Report(runId)
	If 'r.ok Return ..Failure(r)
	Return {"status": "200 OK", "headers": {}, "body": (r.obj)}
}

/// GET /benchmark-reports?runId=&runId=: the runs side by side (runIds is an array of ids)
ClassMethod HandleCompare(runIds As %DynamicArray) As %DynamicObject
{
	Set r = ##class(SignalNoir.Application.Benchmark.ReportBuilder).Compare(runIds)
	If 'r.ok Return ..Failure(r)
	Return {"status": "200 OK", "headers": {}, "body": (r.obj)}
}

// ---------------------------------------------------------------- the route methods

ClassMethod Report(runid As %String) As %Status
{
	Return ..Write(..HandleReport(runid))
}

ClassMethod Compare() As %Status
{
	Set ids = [], n = ""
	For {
		Set n = $Order(%request.Data("runId", n))
		Quit:n=""
		Do ids.%Push(%request.Data("runId", n))
	}
	Return ..Write(..HandleCompare(ids))
}


ClassMethod Create() As %Status
{
	Set content = $Select($IsObject(%request.Content): %request.Content.Read(3000000), 1: %request.Content)
	Return ..Write(..HandleCreate(content))
}

ClassMethod Get(runid As %String) As %Status
{
	Return ..Write(..HandleGet(runid))
}

ClassMethod List() As %Status
{
	Return ..Write(..HandleList($Get(%request.Data("status", 1)), $Get(%request.Data("limit", 1))))
}

/// Writes a handler's {status, headers, body} on the response
ClassMethod Write(answer As %DynamicObject) As %Status
{
	Set %response.ContentType = "application/json"
	Set %response.Status = answer.status
	Set it = answer.headers.%GetIterator()
	While it.%GetNext(.name, .value) {
		Do %response.SetHeader(name, value)
	}
	Write answer.body.%ToJSON()
	Return $$$OK
}

/// The closed error envelope, with the status of its code
ClassMethod Failure(r As SignalNoir.Core.Result) As %DynamicObject
{
	Set code = r.code
	Set status = ##class(SignalNoir.Api.Dispatch).HttpStatus(code)
	; an internal failure is not a contract code: report it without inventing one
	If code = "" Set code = "VALIDATION_FAILED"
	Return {"status": (status), "headers": {}, "body": (##class(SignalNoir.Api.Dispatch).ErrorPayload(code, r.message, r.details))}
}

}
