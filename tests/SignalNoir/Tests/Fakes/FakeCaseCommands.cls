Class SignalNoir.Tests.Fakes.FakeCaseCommands Extends SignalNoir.Core.Port.CaseCommands
{

/// In-memory command handling with version checks (seam contract v3).
/// Usable with no live provider and no database. Acceptance stores the
/// Order only; the first Exception opens the Case.
Property cases As %ListOfObjects;

Property events As %ListOfObjects;

Property orders As %ListOfObjects;

Property counter As %Integer;

Method %OnNew() As %Status
{
	Set ..cases = ##class(%ListOfObjects).%New()
	Set ..events = ##class(%ListOfObjects).%New()
	Set ..orders = ##class(%ListOfObjects).%New()
	Set ..counter = 0
	Return $$$OK
}

Method AcceptOrder(order As SignalNoir.Core.Dto.Order) As SignalNoir.Core.Result
{
	If '$IsObject(order) Return ##class(SignalNoir.Core.Result).Error("VALIDATION_FAILED", "order is required")
	If order.orderId = "" Return ##class(SignalNoir.Core.Result).Error("VALIDATION_FAILED", "orderId is required")
	If '$IsObject(..FindOrder(order.orderId)) Do ..orders.Insert(order)
	Return ##class(SignalNoir.Core.Result).OkRef(order.orderId)
}

Method RecordException(orderId As %String, exception As SignalNoir.Core.Dto.CaseException) As SignalNoir.Core.Result
{
	If '$IsObject(..FindOrder(orderId)) Return ##class(SignalNoir.Core.Result).Error("NOT_FOUND", "order not found: " _ orderId)
	If '$IsObject(exception) Return ##class(SignalNoir.Core.Result).Error("VALIDATION_FAILED", "exception is required")
	Set open = ..FindOpen(orderId)
	If $IsObject(open) {
		Do ##this.AddEvent(open, "ExceptionRecorded")
		Return ##class(SignalNoir.Core.Result).OkRef(open.caseId)
	}
	Set dto = ##class(SignalNoir.Core.Dto.Case).%New()
	Set dto.caseId = ..NextId("case_")
	Set dto.orderId = orderId
	Set dto.state = "Open"
	Set dto.caseVersion = 1
	Set dto.lastEventSeq = 0
	Set dto.lastEventAt = "2026-01-01T00:00:00Z"
	Set dto.synthetic = 1
	Set dto.replay = 0
	Do ..cases.Insert(dto)
	Do ##this.AddEvent(dto, "CaseOpened")
	Do ##this.AddEvent(dto, "ExceptionRecorded")
	Return ##class(SignalNoir.Core.Result).OkRef(dto.caseId)
}

Method OpenCase(orderId As %String) As SignalNoir.Core.Result
{
	Set dto = ..FindOpen(orderId)
	If $IsObject(dto) Return ##class(SignalNoir.Core.Result).OkRef(dto.caseId)
	Return ##class(SignalNoir.Core.Result).Error("NOT_FOUND", "no non-terminal case for order: " _ orderId)
}

Method Transition(caseId As %String, expectedVersion As %Integer, toState As %String, actor As %String, event As SignalNoir.Core.Dto.TimelineEvent, expectedState As %String = "", expectedTarget As %String = "") As SignalNoir.Core.Result
{
	Set dto = ..Find(caseId)
	If '$IsObject(dto) Return ##class(SignalNoir.Core.Result).Error("NOT_FOUND", "case not found: " _ caseId)
	If ((expectedVersion '= "") && (dto.caseVersion '= expectedVersion)) || ((expectedState '= "") && (dto.state '= expectedState)) || ((expectedTarget '= "") && (dto.currentProposalId '= expectedTarget) && (dto.currentExecutionId '= expectedTarget)) {
		Return ##class(SignalNoir.Core.Result).Error("STALE_VERSION", "expected version " _ expectedVersion _ ", current " _ dto.caseVersion)
	}
	Set code = ##class(SignalNoir.Core.CaseMachine).Check(dto.state, toState, actor)
	If code '= "" Return ##class(SignalNoir.Core.Result).Error(code, "transition " _ dto.state _ " -> " _ toState _ " rejected")
	Set dto.state = toState
	Set dto.caseVersion = dto.caseVersion + 1
	Do ##this.AddEvent(dto, "StateChanged")
	Return ##class(SignalNoir.Core.Result).OkRef(caseId)
}

Method Append(caseId As %String, event As SignalNoir.Core.Dto.TimelineEvent) As SignalNoir.Core.Result
{
	Set dto = ..Find(caseId)
	If '$IsObject(dto) Return ##class(SignalNoir.Core.Result).Error("NOT_FOUND", "case not found: " _ caseId)
	If '##class(SignalNoir.Core.Vocab).IsEventType(event.type) Return ##class(SignalNoir.Core.Result).Error("VALIDATION_FAILED", "unknown event type: " _ event.type)
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
	Set event.type = "StateChanged"
	Set event.actor = actor
	Set payload = ##class(%DynamicObject).%New()
	Set payload.reason = reason
	Set event.payload = payload
	Return ..Transition(caseId, expectedVersion, "ReviewRequired", actor, event)
}

Method ResolveRejection(caseId As %String, expectedVersion As %Integer, reason As %String) As SignalNoir.Core.Result
{
	Set dto = ..Find(caseId)
	If '$IsObject(dto) Return ##class(SignalNoir.Core.Result).Error("NOT_FOUND", "case not found: " _ caseId)
	Set to = ##class(SignalNoir.Core.CaseMachine).AfterRejection(dto.denialCount)
	Set event = ##class(SignalNoir.Core.Dto.TimelineEvent).%New()
	Set event.type = "StateChanged"
	Set event.actor = "system"
	Return ..Transition(caseId, expectedVersion, to, "system", event, "Rejected")
}

Method Find(caseId As %String) As SignalNoir.Core.Dto.Case [ Private ]
{
	For i = 1 : 1 : ..cases.Count() {
		Set dto = ..cases.GetAt(i)
		If dto.caseId = caseId Return dto
	}
	Return ""
}

Method FindOpen(orderId As %String) As SignalNoir.Core.Dto.Case [ Private ]
{
	For i = 1 : 1 : ..cases.Count() {
		Set dto = ..cases.GetAt(i)
		If (dto.orderId = orderId) && '##class(SignalNoir.Core.Vocab).IsTerminal(dto.state) Return dto
	}
	Return ""
}

Method FindOrder(orderId As %String) As SignalNoir.Core.Dto.Order [ Private ]
{
	For i = 1 : 1 : ..orders.Count() {
		Set order = ..orders.GetAt(i)
		If order.orderId = orderId Return order
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
