Class SignalNoir.Api.Dispatch Extends %CSP.REST
{

/// Product API dispatch for /signalnoir/api/v1 (AD-16).
/// This slice exposes GET /cases and GET /cases/{caseId}. Errors use the
/// closed envelope { "error": { "code", "message", "details" } }.

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/health" Method="GET" Call="Health"/>
<Route Url="/cases" Method="GET" Call="ListCases"/>
<Route Url="/cases/:caseid" Method="GET" Call="GetCase"/>
</Routes>
}

ClassMethod Health() As %Status
{
	Set %response.ContentType = "application/json"
	Write ##class(SignalNoir.Api.Health).Payload().%ToJSON()
	Return $$$OK
}

ClassMethod ListCases() As %Status
{
	Set %response.ContentType = "application/json"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set r = svc.ListCases("")
	If 'r.ok {
		Set %response.Status = "400 Bad Request"
		Write ##class(SignalNoir.Api.Dispatch).ErrorPayload(r.code, r.message).%ToJSON()
		Return $$$OK
	}
	Write ##class(SignalNoir.Api.Dispatch).ListPayload(r.list).%ToJSON()
	Return $$$OK
}

ClassMethod GetCase(caseid) As %Status
{
	Set %response.ContentType = "application/json"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set r = svc.GetCase(caseid)
	If 'r.ok {
		Set %response.Status = "404 Not Found"
		Write ##class(SignalNoir.Api.Dispatch).ErrorPayload(r.code, r.message).%ToJSON()
		Return $$$OK
	}
	Write ##class(SignalNoir.Api.Dispatch).CasePayload(r.obj).%ToJSON()
	Return $$$OK
}

/// The list page: items, headCursor and serverTime.
ClassMethod ListPayload(list As %ListOfObjects) As %DynamicObject
{
	Set payload = ##class(%DynamicObject).%New()
	Set items = ##class(%DynamicArray).%New()
	Set headCursor = ""
	If $IsObject(list) {
		For i = 1 : 1 : list.Count() {
			Do items.%Push(##class(SignalNoir.Api.Dispatch).SummaryPayload(list.GetAt(i)))
			Set headCursor = list.GetAt(i).caseId
		}
	}
	Do payload.%Set("items", items)
	Do payload.%Set("headCursor", headCursor)
	Do payload.%Set("serverTime", ##class(SignalNoir.Application.SystemClock).%New().NowUtc())
	Return payload
}

/// The Case payload for this slice: the CaseHeader fields the DTO carries
/// plus the versioning fields every Case response carries (AD-17).
ClassMethod CasePayload(dto As SignalNoir.Core.Dto.Case) As %DynamicObject
{
	Set payload = ##class(%DynamicObject).%New()
	Do payload.%Set("caseId", dto.caseId)
	Do payload.%Set("orderId", dto.orderId)
	If dto.partnerId '= "" {
		Do payload.%Set("partnerId", dto.partnerId)
	}
	Do payload.%Set("state", dto.state)
	Set labels = ##class(%DynamicObject).%New()
	Do labels.%Set("synthetic", dto.synthetic)
	Do labels.%Set("replay", dto.replay)
	Do payload.%Set("labels", labels)
	Do payload.%Set("createdAt", dto.createdAt)
	Do payload.%Set("lastEventAt", dto.lastEventAt)
	Do payload.%Set("caseVersion", dto.caseVersion)
	Do payload.%Set("lastEventSeq", dto.lastEventSeq)
	If dto.reviewReason '= "" {
		Do payload.%Set("reviewReason", dto.reviewReason)
	}
	Do payload.%Set("serverTime", ##class(SignalNoir.Application.SystemClock).%New().NowUtc())
	Return payload
}

ClassMethod SummaryPayload(dto As SignalNoir.Core.Dto.CaseSummary) As %DynamicObject
{
	Set payload = ##class(%DynamicObject).%New()
	Do payload.%Set("caseId", dto.caseId)
	Do payload.%Set("state", dto.state)
	Set labels = ##class(%DynamicObject).%New()
	Do labels.%Set("synthetic", dto.synthetic)
	Do labels.%Set("replay", 0)
	Do payload.%Set("labels", labels)
	Do payload.%Set("caseVersion", dto.caseVersion)
	Do payload.%Set("lastEventAt", dto.lastEventAt)
	Do payload.%Set("pendingApproval", (dto.state = "PendingApproval"))
	Do payload.%Set("exceptionCount", 0)
	Return payload
}

/// The closed error envelope.
ClassMethod ErrorPayload(code As %String, message As %String) As %DynamicObject
{
	Set details = ##class(%DynamicObject).%New()
	Set error = ##class(%DynamicObject).%New()
	Do error.%Set("code", code)
	Do error.%Set("message", message)
	Do error.%Set("details", details)
	Set payload = ##class(%DynamicObject).%New()
	Do payload.%Set("error", error)
	Return payload
}

}
