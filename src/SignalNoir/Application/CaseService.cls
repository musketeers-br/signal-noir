Class SignalNoir.Application.CaseService Extends SignalNoir.Core.Port.CaseQueries
{

/// The single mutation path: implements CaseCommands and CaseQueries.
/// Every mutation goes through here (Constitution V). A transition commits
/// the new state, its timeline event and the outbox entry together, and the
/// CAS on caseVersion makes a losing writer visible.

Property Clock As SignalNoir.Core.Port.Clock;

Property Ids As SignalNoir.Core.Port.IdGenerator;

Property Proposer As SignalNoir.Core.Port.Proposer;

ClassMethod Default() As SignalNoir.Application.CaseService
{
	Set svc = ##class(SignalNoir.Application.CaseService).%New()
	Set svc.Clock = ##class(SignalNoir.Application.SystemClock).%New()
	Set svc.Ids = ##class(SignalNoir.Application.IdFactory).%New()
	Set svc.Proposer = ##class(SignalNoir.Proposers.Unavailable).%New()
	Return svc
}

/// Accepts one synthetic Order and opens its Case.
/// Result.ref carries the caseId.
Method AcceptOrder(order As SignalNoir.Core.Dto.Order) As SignalNoir.Core.Result
{
	If '$IsObject(order) Return ##this.Err("VALIDATION_FAILED", "order is required")
	Set orderId = order.orderId
	If orderId = "" Return ##this.Err("VALIDATION_FAILED", "orderId is required")
	If $Get(^SignalNoir.OpenCaseByOrder(orderId)) '= "" Return ##this.Err("INVALID_TRANSITION", "order already has a non-terminal Case")
	Set key = ##class(SignalNoir.Core.Canon).Canonize(order.equivalenceKey)
	If key = "" Return ##this.Err("VALIDATION_FAILED", "equivalenceKey is required")
	Set order.equivalenceKey = key
	Set now = ##this.Now()
	Set failed = 0
	Set failMsg = ""
	Set caseId = ""
	TSTART
	Try {
		Set orderRec = ##class(SignalNoir.Application.Model.OrderRecord).%New()
		Set orderRec.orderId = order.orderId
		Set orderRec.snapshotJson = ##this.SnapshotJson(order.snapshot)
		Set orderRec.equivalenceKey = key
		Set orderRec.receivedAt = now
		Set orderRec.synthetic = 1
		$$$ThrowOnError(orderRec.%Save())
		Set caseId = ##this.OpenCaseRecord(order, now)
	}
	Catch ex {
		Set failed = 1
		Set failMsg = ex.DisplayString()
		If $TLevel > 0 {
			TROLLBACK
		}
	}
	If failed {
		Return ##this.Err("", "accept order failed: " _ failMsg)
	}
	TCOMMIT
	Return ##class(SignalNoir.Core.Result).OkRef(caseId)
}

/// Opens the Case of an already accepted Order.
Method OpenCase(orderId As %String) As SignalNoir.Core.Result
{
	Set orderRec = ##class(SignalNoir.Application.Model.OrderRecord).%OpenId(orderId)
	If '$IsObject(orderRec) Return ##this.Err("NOT_FOUND", "order not found: " _ orderId)
	If orderRec.caseId '= "" Return ##class(SignalNoir.Core.Result).OkRef(orderRec.caseId)
	Set order = ##class(SignalNoir.Core.Dto.Order).%New()
	Set order.orderId = orderRec.orderId
	Set order.equivalenceKey = orderRec.equivalenceKey
	Set order.receivedAt = orderRec.receivedAt
	Set order.synthetic = 1
	Set now = ##this.Now()
	Set failed = 0
	Set failMsg = ""
	Set caseId = ""
	TSTART
	Try {
		Set caseId = ##this.OpenCaseRecord(order, now)
	}
	Catch ex {
		Set failed = 1
		Set failMsg = ex.DisplayString()
		If $TLevel > 0 {
			TROLLBACK
		}
	}
	If failed {
		Return ##this.Err("", "open case failed: " _ failMsg)
	}
	TCOMMIT
	Return ##class(SignalNoir.Core.Result).OkRef(caseId)
}

/// Compare-and-swap transition: state, timeline event and outbox entry commit
/// together. A stale expectedVersion loses visibly with STALE_VERSION.
Method Transition(caseId As %String, expectedVersion As %Integer, toState As %String, actor As %String, event As SignalNoir.Core.Dto.TimelineEvent) As SignalNoir.Core.Result
{
	Set rec = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(caseId)
	If '$IsObject(rec) Return ##this.Err("NOT_FOUND", "case not found: " _ caseId)
	If (expectedVersion '= "") && (rec.Version '= expectedVersion) Return ##this.Err("STALE_VERSION", "expected version " _ expectedVersion _ ", current " _ rec.Version)
	Set code = ##class(SignalNoir.Core.CaseMachine).Check(rec.state, toState, actor)
	If code '= "" Return ##this.Err(code, "transition " _ rec.state _ " -> " _ toState _ " rejected")
	Set now = ##this.Now()
	Set failed = 0
	Set failMsg = ""
	Set eventType = "CaseTransition"
	Set payload = ##class(%DynamicObject).%New()
	If $IsObject(event) {
		If event.type '= "" Set eventType = event.type
		If $IsObject(event.payload) Set payload = event.payload
	}
	TSTART
	Try {
		Set rec.state = toState
		Set rec.updatedAt = now
		If toState = "ReviewRequired" {
			Set reason = payload.reason
			If reason = "" Set reason = "review required"
			Set rec.reviewReason = reason
		}
		Set seq = ##this.AppendEvent(caseId, eventType, actor, caseId, payload, now)
		Set rec.lastEventSeq = seq
		Set rec.lastEventAt = now
		If expectedVersion '= "" Set rec.Version = expectedVersion
		$$$ThrowOnError(rec.%Save())
		If toState = "Investigating" {
			Set outbox = ##class(SignalNoir.Application.Model.OutboxRecord).%New()
			Set outbox.commandId = ..Ids.New("cmd_")
			Set outbox.type = "Investigate"
			Set outbox.caseId = caseId
			Set outbox.caseVersionAfter = rec.Version
			Set outbox.status = "pending"
			Set outbox.createdAt = now
			$$$ThrowOnError(outbox.%Save())
		}
		If ##class(SignalNoir.Core.Vocab).IsTerminal(toState) {
			Set recOrderId = rec.orderId
			Kill ^SignalNoir.OpenCaseByOrder(recOrderId)
		}
	}
	Catch ex {
		Set failed = 1
		Set failMsg = ex.DisplayString()
		If $TLevel > 0 {
			TROLLBACK
		}
	}
	If failed {
		Return ##this.Err("", "transition failed: " _ failMsg)
	}
	TCOMMIT
	Return ##class(SignalNoir.Core.Result).OkRef(caseId)
}

/// Attachment command: appends a timeline event without bumping caseVersion.
Method Append(caseId As %String, event As SignalNoir.Core.Dto.TimelineEvent) As SignalNoir.Core.Result
{
	Set rec = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(caseId)
	If '$IsObject(rec) Return ##this.Err("NOT_FOUND", "case not found: " _ caseId)
	If '$IsObject(event) Return ##this.Err("VALIDATION_FAILED", "event is required")
	Set at = event.at
	If at = "" Set at = ##this.Now()
	Set failed = 0
	Set failMsg = ""
	Set seq = 0
	TSTART
	Try {
		Set seq = ##this.AppendEvent(caseId, event.type, event.actor, event.refId, event.payload, at)
	}
	Catch ex {
		Set failed = 1
		Set failMsg = ex.DisplayString()
		If $TLevel > 0 {
			TROLLBACK
		}
	}
	If failed {
		Return ##this.Err("", "append failed: " _ failMsg)
	}
	TCOMMIT
	Set out = ##class(SignalNoir.Core.Dto.TimelineEvent).%New()
	Set out.seq = seq
	Set out.at = at
	Set out.type = event.type
	Set out.actor = event.actor
	Set out.refId = event.refId
	Set out.payload = event.payload
	Return ##class(SignalNoir.Core.Result).OkObj(out)
}

/// Moves the Case to ReviewRequired with a reason naming the cause.
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

/// Reads one Case.
Method GetCase(caseId As %String) As SignalNoir.Core.Result
{
	Set rec = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(caseId)
	If '$IsObject(rec) Return ##this.Err("NOT_FOUND", "case not found: " _ caseId)
	Return ##class(SignalNoir.Core.Result).OkObj(##this.ToCaseDto(rec))
}

/// Reads the timeline from sinceSeq (inclusive of seq > sinceSeq).
Method GetTimeline(caseId As %String, sinceSeq As %Integer = 0) As SignalNoir.Core.Result
{
	Set last = +$Get(^SignalNoir.CaseSeq(caseId))
	Set list = ##class(%ListOfObjects).%New()
	For seq = sinceSeq + 1 : 1 : last {
		Set ev = ##class(SignalNoir.Application.Model.CaseEventRecord).%OpenId(caseId _ "||" _ seq)
		If $IsObject(ev) {
			Do list.Insert(##this.ToEventDto(ev))
		}
	}
	Return ##class(SignalNoir.Core.Result).OkList(list)
}

/// Lists the Case summaries. The cursor is the last caseId of the previous
/// page; an empty cursor starts at the beginning.
Method ListCases(cursor As %String = "") As SignalNoir.Core.Result
{
	Set list = ##class(%ListOfObjects).%New()
	Set id = $Get(cursor)
	For {
		Set id = $ORDER(^SignalNoir.Cases(id))
		If id = "" Break
		Set rec = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(id)
		If $IsObject(rec) {
			Do list.Insert(##this.ToSummaryDto(rec))
		}
	}
	Return ##class(SignalNoir.Core.Result).OkList(list)
}

/// Accepts an Order and, when the Proposer reports the provider unavailable,
/// moves the Case to ReviewRequired naming the provider (FR-004, FR-016).
Method ProcessOrder(order As SignalNoir.Core.Dto.Order) As SignalNoir.Core.Result
{
	Set r = ..AcceptOrder(order)
	If 'r.ok Return r
	Set g = ..GetCase(r.ref)
	If 'g.ok Return g
	Set caseDto = g.obj
	If '$IsObject(..Proposer) Return r
	Set p = ..Proposer.Propose(caseDto)
	If p.ok Return r
	If p.code = "provider_unavailable" {
		Set reason = "provider unavailable: " _ ##class(SignalNoir.Application.CaseService).ProviderName()
		Set rr = ..MarkReviewRequired(r.ref, caseDto.caseVersion, "system", reason)
		If 'rr.ok Return rr
	}
	Return r
}

/// Creates the Case and its first two timeline events (OrderAccepted, CaseOpened).
Method OpenCaseRecord(order As SignalNoir.Core.Dto.Order, now As %String) As %String [ Private ]
{
	Set caseId = ..Ids.New("case_")
	Set payload = ##class(%DynamicObject).%New()
	Set payload.orderId = order.orderId
	Set seq = ##this.AppendEvent(caseId, "OrderAccepted", "system", order.orderId, payload, now)
	Set opened = ##class(%DynamicObject).%New()
	Set opened.state = "Open"
	Set seq = ##this.AppendEvent(caseId, "CaseOpened", "system", caseId, opened, now)
	Set rec = ##class(SignalNoir.Application.Model.CaseRecord).%New()
	Set rec.caseId = caseId
	Set rec.orderId = order.orderId
	Set rec.partnerId = ##this.SnapshotPartnerId(order.snapshot)
	Set rec.state = "Open"
	Set rec.lastEventSeq = seq
	Set rec.lastEventAt = now
	Set rec.synthetic = 1
	Set rec.replay = 0
	Set rec.createdAt = now
	Set rec.updatedAt = now
	Set rec.Version = 1
	$$$ThrowOnError(rec.%Save())
	Set ^SignalNoir.Cases(caseId) = ""
	Set orderId = order.orderId
	Set ^SignalNoir.OpenCaseByOrder(orderId) = caseId
	Set orderRec = ##class(SignalNoir.Application.Model.OrderRecord).%OpenId(orderId)
	If $IsObject(orderRec) {
		Set orderRec.caseId = caseId
		$$$ThrowOnError(orderRec.%Save())
	}
	Return caseId
}

/// Appends one timeline row. The seq is per-Case and never reused.
Method AppendEvent(caseId As %String, eventType As %String, actor As %String, refId As %String, payload As %DynamicObject, at As %String) As %Integer [ Private ]
{
	Set seq = $INCREMENT(^SignalNoir.CaseSeq(caseId))
	Set ev = ##class(SignalNoir.Application.Model.CaseEventRecord).%New()
	Set ev.caseId = caseId
	Set ev.seq = seq
	Set ev.at = at
	Set ev.type = eventType
	Set ev.actor = actor
	Set ev.refId = refId
	Set ev.payloadJson = ##this.PayloadJson(payload)
	$$$ThrowOnError(ev.%Save())
	Set ^SignalNoir.CaseLast(caseId) = at
	Return seq
}

Method ToCaseDto(rec As SignalNoir.Application.Model.CaseRecord) As SignalNoir.Core.Dto.Case [ Private ]
{
	Set dto = ##class(SignalNoir.Core.Dto.Case).%New()
	Set dto.caseId = rec.caseId
	Set dto.orderId = rec.orderId
	Set dto.state = rec.state
	Set dto.caseVersion = rec.Version
	Set caseId = rec.caseId
	Set dto.lastEventSeq = +$Get(^SignalNoir.CaseSeq(caseId))
	Set dto.lastEventAt = $Get(^SignalNoir.CaseLast(caseId))
	Set dto.synthetic = rec.synthetic
	Set dto.replay = rec.replay
	Set dto.reviewReason = rec.reviewReason
	Set dto.createdAt = rec.createdAt
	Set dto.partnerId = rec.partnerId
	Return dto
}

Method ToSummaryDto(rec As SignalNoir.Application.Model.CaseRecord) As SignalNoir.Core.Dto.CaseSummary [ Private ]
{
	Set dto = ##class(SignalNoir.Core.Dto.CaseSummary).%New()
	Set dto.caseId = rec.caseId
	Set dto.state = rec.state
	Set dto.caseVersion = rec.Version
	Set caseId = rec.caseId
	Set dto.lastEventAt = $Get(^SignalNoir.CaseLast(caseId))
	Set dto.synthetic = rec.synthetic
	Return dto
}

Method ToEventDto(ev As SignalNoir.Application.Model.CaseEventRecord) As SignalNoir.Core.Dto.TimelineEvent [ Private ]
{
	Set dto = ##class(SignalNoir.Core.Dto.TimelineEvent).%New()
	Set dto.seq = ev.seq
	Set dto.at = ev.at
	Set dto.type = ev.type
	Set dto.actor = ev.actor
	Set dto.refId = ev.refId
	Set dto.payload = ##this.PayloadObject(ev.payloadJson)
	Return dto
}

Method Now() As %String [ Private ]
{
	If '$IsObject(..Clock) Return ##class(SignalNoir.Application.SystemClock).%New().NowUtc()
	Return ..Clock.NowUtc()
}

ClassMethod ProviderName() As %String
{
	Set name = $Get(^SignalNoir.Provider("provider"))
	If name = "" Set name = "unknown-provider"
	Return name
}

Method SnapshotJson(snapshot As %DynamicObject) As %String [ Private ]
{
	If '$IsObject(snapshot) Return "{}"
	Return snapshot.%ToJSON()
}

/// The partner identifier, when the raw Order snapshot carries one.
Method SnapshotPartnerId(snapshot As %DynamicObject) As %String [ Private ]
{
	If '$IsObject(snapshot) Return ""
	Return snapshot.partnerId
}

Method PayloadJson(payload As %DynamicObject) As %String [ Private ]
{
	If '$IsObject(payload) Return "{}"
	Return payload.%ToJSON()
}

Method PayloadObject(json As %String) As %DynamicObject [ Private ]
{
	If json = "" Return ##class(%DynamicObject).%New()
	Set obj = ##class(%DynamicObject).%FromJSON(json)
	If '$IsObject(obj) Return ##class(%DynamicObject).%New()
	Return obj
}

Method Err(code As %String, message As %String) As SignalNoir.Core.Result [ Private ]
{
	Return ##class(SignalNoir.Core.Result).Error(code, message)
}

}
