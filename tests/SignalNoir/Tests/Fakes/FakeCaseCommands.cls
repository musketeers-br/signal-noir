Class SignalNoir.Tests.Fakes.FakeCaseCommands Extends SignalNoir.Core.Port.CaseCommands
{

/// In-memory command handling with version checks (seam contract).
/// Usable with no live provider and no database.

Property cases As %ListOfObjects;

Property events As %ListOfObjects;

Property counter As %Integer;

Method %OnNew() As %Status
{
	Set ..cases = ##class(%ListOfObjects).%New()
	Set ..events = ##class(%ListOfObjects).%New()
	Set ..counter = 0
	Return $$$OK
}

Method AcceptOrder(order As SignalNoir.Core.Dto.Order) As SignalNoir.Core.Result
{
	If '$IsObject(order) Return ##class(SignalNoir.Core.Result).Error("VALIDATION_FAILED", "order is required")
	Set caseId = ..NextId("case_")
	Set dto = ##class(SignalNoir.Core.Dto.Case).%New()
	Set dto.caseId = caseId
	Set dto.orderId = order.orderId
	Set dto.state = "Open"
	Set dto.caseVersion = 1
	Set dto.lastEventSeq = 0
	Set dto.lastEventAt = "2026-01-01T00:00:00Z"
	Set dto.synthetic = 1
	Set dto.replay = 0
	Do ..cases.Insert(dto)
	Do ##this.AddEvent(dto, "OrderAccepted")
	Do ##this.AddEvent(dto, "CaseOpened")
	Return ##class(SignalNoir.Core.Result).OkRef(caseId)
}

Method OpenCase(orderId As %String) As SignalNoir.Core.Result
{
	For i = 1 : 1 : ..cases.Count() {
		Set dto = ..cases.GetAt(i)
		If dto.orderId = orderId Return ##class(SignalNoir.Core.Result).OkRef(dto.caseId)
	}
	Return ##class(SignalNoir.Core.Result).Error("NOT_FOUND", "order not found: " _ orderId)
}

Method Transition(caseId As %String, expectedVersion As %Integer, toState As %String, actor As %String, event As SignalNoir.Core.Dto.TimelineEvent) As SignalNoir.Core.Result
{
	Set dto = ..Find(caseId)
	If '$IsObject(dto) Return ##class(SignalNoir.Core.Result).Error("NOT_FOUND", "case not found: " _ caseId)
	If (expectedVersion '= "") && (dto.caseVersion '= expectedVersion) {
		Return ##class(SignalNoir.Core.Result).Error("STALE_VERSION", "expected version " _ expectedVersion _ ", current " _ dto.caseVersion)
	}
	Set dto.state = toState
	Set dto.caseVersion = dto.caseVersion + 1
	Do ##this.AddEvent(dto, event.type)
	Return ##class(SignalNoir.Core.Result).OkRef(caseId)
}

Method Append(caseId As %String, event As SignalNoir.Core.Dto.TimelineEvent) As SignalNoir.Core.Result
{
	Set dto = ..Find(caseId)
	If '$IsObject(dto) Return ##class(SignalNoir.Core.Result).Error("NOT_FOUND", "case not found: " _ caseId)
	Set dto.lastEventSeq = dto.lastEventSeq + 1
	Set out = ##class(SignalNoir.Core.Dto.TimelineEvent).%New()
	Set out.seq = dto.lastEventSeq
	Set out.at = "2026-01-01T00:00:00Z"
	Set out.type = event.type
	Set out.actor = event.actor
	Set out.refId = event.refId
	Set out.payload = event.payload
	Do ..events.Insert(out)
	Return ##class(SignalNoir.Core.Result).OkObj(out)
}

Method MarkReviewRequired(caseId As %String, expectedVersion As %Integer, actor As %String, reason As %String) As SignalNoir.Core.Result
{
	Set event = ##class(SignalNoir.Core.Dto.TimelineEvent).%New()
	Set event.type = "ReviewRequired"
	Set event.actor = actor
	Set payload = ##class(%DynamicObject).%New()
	Set payload.reason = reason
	Set event.payload = payload
	Return ..Transition(caseId, expectedVersion, "ReviewRequired", actor, event)
}

Method Find(caseId As %String) As SignalNoir.Core.Dto.Case [ Private ]
{
	For i = 1 : 1 : ..cases.Count() {
		Set dto = ..cases.GetAt(i)
		If dto.caseId = caseId Return dto
	}
	Return ""
}

Method AddEvent(dto As SignalNoir.Core.Dto.Case, type As %String) [ Private ]
{
	Set dto.lastEventSeq = dto.lastEventSeq + 1
	Set event = ##class(SignalNoir.Core.Dto.TimelineEvent).%New()
	Set event.seq = dto.lastEventSeq
	Set event.at = "2026-01-01T00:00:00Z"
	Set event.type = type
	Set event.actor = "system"
	Set event.refId = dto.caseId
	Set event.payload = ##class(%DynamicObject).%New()
	Do ..events.Insert(event)
}

Method NextId(prefix As %String) As %String [ Private ]
{
	Set ..counter = ..counter + 1
	Return prefix _ ..counter
}

}
