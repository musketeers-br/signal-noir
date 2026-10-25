Class SignalNoir.Application.CaseService Extends SignalNoir.Core.Port.CaseQueries
{

/// The single mutation path: implements CaseCommands and CaseQueries (seam
/// v3). Every mutation goes through here (Constitution V). A transition
/// commits the new state, its StateChanged event and its follow-up work
/// together, in one short transaction with no I/O. The compare-and-swap on
/// caseVersion (and, when given, expected state and target) runs under a
/// short per-Case lock held until TCOMMIT, so a losing writer is visible and
/// Timeline seqs commit in order (research R3, R4).
Property Clock As SignalNoir.Core.Port.Clock;

Property Ids As SignalNoir.Core.Port.IdGenerator;

Property Proposer As SignalNoir.Core.Port.Proposer;

/// Seconds to wait for a per-Case or per-Order lock
Parameter LOCKTIMEOUT = 5;

ClassMethod Default() As SignalNoir.Application.CaseService
{
	Set svc = ##class(SignalNoir.Application.CaseService).%New()
	Set svc.Clock = ##class(SignalNoir.Application.SystemClock).%New()
	Set svc.Ids = ##class(SignalNoir.Application.IdFactory).%New()
	Set svc.Proposer = ##class(SignalNoir.Proposers.Unavailable).%New()
	Return svc
}

// ---------------------------------------------------------------- intake

/// Checks the Origin Order shape in the core and stores or correlates the
/// Order. A malformed Order is refused with VALIDATION_FAILED (details.reasons)
/// and recorded as an intake refusal. Opens no Case. Result.ref = orderId.
Method AcceptOrder(order As SignalNoir.Core.Dto.Order) As SignalNoir.Core.Result
{
	If '$IsObject(order) Return ..Refuse("", "", ##class(SignalNoir.Core.OrderShape).Check(""))
	Set snapshot = order.snapshot
	Set reasons = ##class(SignalNoir.Core.OrderShape).Check(snapshot)
	Set orderId = order.orderId
	If $IsObject(snapshot) && snapshot.%IsA("%DynamicObject") && '$IsObject(snapshot.orderId) && (snapshot.orderId '= "") Set orderId = snapshot.orderId
	If (reasons.Count() = 0) && (order.orderId '= "") && (order.orderId '= snapshot.orderId) Do reasons.Insert("mismatch:orderId")
	If reasons.Count() > 0 Return ..Refuse(orderId, order.transactionId, reasons)
	Set key = ##class(SignalNoir.Core.Canon).FromSnapshot(snapshot)
	Set now = ..Now()
	Set result = ""
	TSTART
	Try {
		If '..Acquire("^SignalNoir.OrderLock", orderId, .locks) {
			Set result = ..Err("", "order busy: " _ orderId)
			Quit
		}
		Set rec = ##class(SignalNoir.Application.Model.OrderRecord).%OpenId(orderId)
		If $IsObject(rec) {
			Do rec.%Reload()
			If (order.transactionId '= "") && (rec.transactionIds.Find(order.transactionId) = "") {
				Do rec.transactionIds.Insert(order.transactionId)
				$$$ThrowOnError(rec.%Save())
			}
		} Else {
			Set rec = ##class(SignalNoir.Application.Model.OrderRecord).%New()
			Set rec.orderId = orderId
			Set rec.partnerId = snapshot.partnerId
			Set rec.correlationId = ..Ids.New("corr_")
			If order.transactionId '= "" Do rec.transactionIds.Insert(order.transactionId)
			Set rec.runId = order.runId
			Set rec.snapshotJson = snapshot.%ToJSON()
			Set rec.equivalenceKey = key
			Set rec.receivedAt = now
			Set rec.synthetic = 1
			$$$ThrowOnError(rec.%Save())
		}
		Set result = ##class(SignalNoir.Core.Result).OkRef(orderId)
		Set result.details = {"correlationId": (rec.correlationId)}
	}
	Catch ex {
		Set result = ..FromException(ex, "accept order failed")
	}
	Return ..Finish(result, .locks)
}

/// Records an Exception of an accepted Order (FR-009 to FR-013): opens the
/// Case on the first one, joins the non-terminal Case (and reinvestigates
/// when the state calls for it), or opens a related Case after a terminal
/// one. Result.ref = caseId; details.route = open, attach or
/// attach_and_investigate.
Method RecordException(orderId As %String, exception As SignalNoir.Core.Dto.CaseException) As SignalNoir.Core.Result
{
	If '$IsObject(exception) Return ..Err("VALIDATION_FAILED", "exception is required")
	If '##class(SignalNoir.Core.Vocab).IsExceptionKind(exception.kind) Return ..Err("VALIDATION_FAILED", "unknown exception kind: " _ exception.kind)
	Set observedAt = exception.observedAt
	If observedAt = "" Set observedAt = ..Now()
	If ##class(SignalNoir.Core.Canon).NormalizeUtc(observedAt) = "" Return ..Err("VALIDATION_FAILED", "unreadable observedAt: " _ observedAt)
	If '##class(SignalNoir.Application.Model.OrderRecord).%ExistsId(orderId) Return ..Err("NOT_FOUND", "order not found: " _ orderId)
	Set now = ..Now()
	Set result = ""
	TSTART
	Try {
		If '..Acquire("^SignalNoir.OrderLock", orderId, .locks) {
			Set result = ..Err("", "order busy: " _ orderId)
			Quit
		}
		Set orderRec = ##class(SignalNoir.Application.Model.OrderRecord).%OpenId(orderId)
		Do orderRec.%Reload()
		Set latest = ""
		Set latestState = ""
		If orderRec.caseId '= "" {
			If '..Acquire("^SignalNoir.CaseLock", orderRec.caseId, .locks) {
				Set result = ..Err("", "case busy: " _ orderRec.caseId)
				Quit
			}
			Set latest = ..Load(orderRec.caseId)
			If $IsObject(latest) Set latestState = latest.state
		}
		Set route = ##class(SignalNoir.Core.CaseMachine).RouteException(latestState)
		If route = "open" {
			Set rec = ..NewCase(orderRec, $Select($IsObject(latest): latest.caseId, 1: ""), now)
		} Else {
			Set rec = latest
		}
		Set during = ((rec.state = "Approved") || (rec.state = "Executing"))
		Set exceptionId = ..SaveException(rec, orderId, exception, observedAt, during)
		Set payload = {"exceptionId": (exceptionId), "kind": (exception.kind), "observedAt": (observedAt), "duringExecution": (during)}
		Do payload.%Set("httpStatus", exception.httpStatus, $Select(exception.httpStatus = "": "null", 1: "number"))
		Do ..AppendEvent(rec, "ExceptionRecorded", "system", exceptionId, payload, now)
		If route = "attach_and_investigate" {
			Set moved = ..ApplyTransition(rec, "Investigating", "system", {"reason": "new exception"}, "", now)
			If 'moved.ok {
				Set result = moved
				Quit
			}
		}
		$$$ThrowOnError(rec.%Save())
		If orderRec.caseId '= rec.caseId {
			Set orderRec.caseId = rec.caseId
			$$$ThrowOnError(orderRec.%Save())
		}
		Set result = ##class(SignalNoir.Core.Result).OkRef(rec.caseId)
		Set result.details = {"route": (route), "exceptionId": (exceptionId)}
	}
	Catch ex {
		Set result = ..FromException(ex, "record exception failed")
	}
	Return ..Finish(result, .locks)
}

/// Records the Exception and, when it opened a new Case, routes the Case:
/// to ReviewRequired when the provider is unavailable (001 behavior), else
/// to Investigating with an Investigate request.
Method ProcessException(orderId As %String, exception As SignalNoir.Core.Dto.CaseException) As SignalNoir.Core.Result
{
	Set r = ..RecordException(orderId, exception)
	If 'r.ok || (r.details.route '= "open") Return r
	Set g = ..GetCase(r.ref)
	If 'g.ok Return g
	Set caseDto = g.obj
	Set unavailable = 0
	If $IsObject(..Proposer) {
		Set p = ..Proposer.Propose(caseDto)
		Set unavailable = ('p.ok && (p.code = "provider_unavailable"))
	}
	If unavailable {
		Set reason = "provider unavailable: " _ ##class(SignalNoir.Application.CaseService).ProviderName()
		Set moved = ..MarkReviewRequired(r.ref, caseDto.caseVersion, "system", reason)
	} Else {
		Set moved = ..Transition(r.ref, caseDto.caseVersion, "Investigating", "system", ..Event({"reason": "case routed to investigation"}))
	}
	If 'moved.ok Return moved
	Return r
}

/// Returns the non-terminal Case of the Order; never creates one.
Method OpenCase(orderId As %String) As SignalNoir.Core.Result
{
	Set caseId = ..OpenCaseOf(orderId)
	If caseId = "" Return ..Err("NOT_FOUND", "no non-terminal case for order: " _ orderId)
	Return ##class(SignalNoir.Core.Result).OkRef(caseId)
}

// ----------------------------------------------------------- transitions

/// Compare-and-swap transition (FR-015 to FR-021): expectedVersion, and when
/// given expectedState and expectedTarget (currentProposalId or
/// currentExecutionId), must still hold or the command loses with
/// STALE_VERSION and writes nothing. State, StateChanged and follow-up commit
/// together. event.payload may carry reason and other facts.
Method Transition(caseId As %String, expectedVersion As %Integer, toState As %String, actor As %String, event As SignalNoir.Core.Dto.TimelineEvent, expectedState As %String = "", expectedTarget As %String = "") As SignalNoir.Core.Result
{
	Return ..DoTransition(caseId, expectedVersion, toState, actor, event, expectedState, expectedTarget, "")
}

/// Moves the Case to ReviewRequired with a reason naming the cause.
Method MarkReviewRequired(caseId As %String, expectedVersion As %Integer, actor As %String, reason As %String) As SignalNoir.Core.Result
{
	Return ..Transition(caseId, expectedVersion, "ReviewRequired", actor, ..Event({"reason": (reason)}))
}

/// Rejected -> Investigating on the first rejection, carrying the reason to
/// the new investigation request; -> ReviewRequired on the second (FR-024).
Method ResolveRejection(caseId As %String, expectedVersion As %Integer, reason As %String) As SignalNoir.Core.Result
{
	Set rec = ..Load(caseId)
	If '$IsObject(rec) Return ..Err("NOT_FOUND", "case not found: " _ caseId)
	Set to = ##class(SignalNoir.Core.CaseMachine).AfterRejection(rec.denialCount)
	If to = "ReviewRequired" {
		Return ..DoTransition(caseId, expectedVersion, to, "system", ..Event({"reason": "second rejection", "rejectionReason": (reason)}), "Rejected", "", "")
	}
	Return ..DoTransition(caseId, expectedVersion, to, "system", ..Event({"reason": "first rejection", "rejectionReason": (reason)}), "Rejected", "", {"rejectionReason": (reason)})
}

/// Attachment command (FR-021): appends a Timeline event of a contract type
/// without changing state or caseVersion.
Method Append(caseId As %String, event As SignalNoir.Core.Dto.TimelineEvent) As SignalNoir.Core.Result
{
	If '$IsObject(event) Return ..Err("VALIDATION_FAILED", "event is required")
	If '##class(SignalNoir.Core.Vocab).IsEventType(event.type) Return ..Err("VALIDATION_FAILED", "unknown event type: " _ event.type)
	If event.type = "StateChanged" Return ..Err("VALIDATION_FAILED", "StateChanged is written only by a transition")
	If '##class(SignalNoir.Core.Vocab).IsActor(event.actor) Return ..Err("INVALID_ACTOR", "unknown actor: " _ event.actor)
	If '##class(SignalNoir.Application.Model.CaseRecord).%ExistsId(caseId) Return ..Err("NOT_FOUND", "case not found: " _ caseId)
	Set at = event.at
	If at = "" Set at = ..Now()
	Set result = ""
	TSTART
	Try {
		If '..Acquire("^SignalNoir.CaseLock", caseId, .locks) {
			Set result = ..Err("", "case busy: " _ caseId)
			Quit
		}
		Set rec = ..Load(caseId)
		If ##class(SignalNoir.Core.Vocab).IsTerminal(rec.state) && (event.type '= "Annotation") {
			Set result = ..ErrorWithCase("INVALID_TRANSITION", "case is terminal: " _ rec.state, rec, "")
			Quit
		}
		Set seq = ..AppendEvent(rec, event.type, event.actor, event.refId, event.payload, at)
		$$$ThrowOnError(rec.%Save())
		Set out = ##class(SignalNoir.Core.Dto.TimelineEvent).%New()
		Set out.seq = seq
		Set out.at = at
		Set out.type = event.type
		Set out.actor = event.actor
		Set out.refId = event.refId
		Set out.payload = event.payload
		Set result = ##class(SignalNoir.Core.Result).OkObj(out)
	}
	Catch ex {
		Set result = ..FromException(ex, "append failed")
	}
	Return ..Finish(result, .locks)
}

// --------------------------------------------------- restart and outbox

/// Start-up recovery (FR-027, research R10): a Case in Investigating whose
/// Investigate request was picked up (dispatched) and not finished was
/// interrupted, and moves to ReviewRequired. A pending request was never
/// started and is left for the consumer. Result.ref = number moved.
Method RecoverInterrupted() As SignalNoir.Core.Result
{
	Set moved = 0
	Set sql = "SELECT c.caseId, c.caseVersion FROM SignalNoir_Application_Model.CaseRecord c WHERE c.state = 'Investigating'"
	_ " AND EXISTS (SELECT 1 FROM SignalNoir_Application_Model.OutboxRecord o WHERE o.caseId = c.caseId AND o.type = 'Investigate' AND o.status = 'dispatched')"
	_ " AND NOT EXISTS (SELECT 1 FROM SignalNoir_Application_Model.OutboxRecord p WHERE p.caseId = c.caseId AND p.type = 'Investigate' AND p.status = 'pending')"
	Set rs = ##class(%SQL.Statement).%ExecDirect(, sql)
	If rs.%SQLCODE < 0 Return ..Err("", "recovery query failed: " _ rs.%Message)
	While rs.%Next() {
		Set r = ..MarkReviewRequired(rs.%Get("caseId"), rs.%Get("caseVersion"), "system", "investigation interrupted")
		If r.ok {
			Set moved = moved + 1
			Do ..CloseDispatched(rs.%Get("caseId"))
		}
	}
	Return ##class(SignalNoir.Core.Result).OkRef(moved)
}

/// The outbox consumer picked the request up (feature 006/007 consumer)
Method MarkDispatched(commandId As %String) As SignalNoir.Core.Result
{
	Return ..SetOutboxStatus(commandId, "pending", "dispatched")
}

Method MarkDone(commandId As %String) As SignalNoir.Core.Result
{
	Return ..SetOutboxStatus(commandId, "dispatched", "done")
}

// ----------------------------------------------------------------- reads

/// Case detail: the Case, its Order view and its Exceptions.
Method GetCase(caseId As %String) As SignalNoir.Core.Result
{
	Set rec = ..Load(caseId)
	If '$IsObject(rec) Return ..Err("NOT_FOUND", "case not found: " _ caseId)
	Set dto = ..ToCaseDto(rec)
	Set orderRec = ##class(SignalNoir.Application.Model.OrderRecord).%OpenId(rec.orderId)
	If $IsObject(orderRec) Set dto.order = ..ToOrderDto(orderRec)
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT exceptionId FROM SignalNoir_Application_Model.ExceptionRecord WHERE caseId = ? ORDER BY observedAt, exceptionId", caseId)
	While rs.%Next() {
		Set ex = ##class(SignalNoir.Application.Model.ExceptionRecord).%OpenId(rs.%Get("exceptionId"))
		If $IsObject(ex) Do dto.exceptions.Insert(..ToExceptionDto(ex))
	}
	Return ##class(SignalNoir.Core.Result).OkObj(dto)
}

/// Events with seq > sinceSeq up to the committed watermark (FR-030, FR-031).
/// details: hasMore, nextSinceSeq, caseVersion, lastEventSeq, state.
Method GetTimeline(caseId As %String, sinceSeq As %Integer = 0, limit As %Integer = 200) As SignalNoir.Core.Result
{
	If (sinceSeq '? 1.N) Return ..Err("VALIDATION_FAILED", "sinceSeq must be an integer >= 0")
	If (limit '? 1.N) || (limit < 1) || (limit > 500) Return ..Err("VALIDATION_FAILED", "limit must be between 1 and 500")
	; a shared lock waits for an in-flight writer of this Case to commit, so
	; the watermark read is committed (IRIS reads are otherwise uncommitted)
	Lock +^SignalNoir.CaseLock(caseId)#"S":..#LOCKTIMEOUT
	If '$Test Return ..Err("", "case busy: " _ caseId)
	Set rec = ..Load(caseId)
	Lock -^SignalNoir.CaseLock(caseId)#"S"
	If '$IsObject(rec) Return ..Err("NOT_FOUND", "case not found: " _ caseId)
	Set watermark = +rec.lastEventSeq
	Set list = ##class(%ListOfObjects).%New()
	Set last = +sinceSeq
	For seq = sinceSeq + 1 : 1 : watermark {
		If list.Count() >= limit Quit
		Set ev = ##class(SignalNoir.Application.Model.CaseEventRecord).%OpenId(caseId _ "||" _ seq)
		If '$IsObject(ev) Quit
		Do list.Insert(..ToEventDto(ev))
		Set last = seq
	}
	Set r = ##class(SignalNoir.Core.Result).OkList(list)
	Set r.details = {"hasMore": (last < watermark), "nextSinceSeq": (last), "caseVersion": (rec.caseVersion), "lastEventSeq": (watermark), "state": (rec.state)}
	Return r
}

/// Case list over (lastEventAt, caseId) (FR-028). direction older: newest
/// first, from the cursor backwards; newer: ascending, strictly after the
/// cursor. filters: state (array), status (open|terminal|all),
/// pendingApproval, runId, includeBenchmark. details: nextCursor, headCursor.
Method ListCases(cursor As %String = "", direction As %String = "older", limit As %Integer = 50, filters As %DynamicObject = "") As SignalNoir.Core.Result
{
	If direction = "" Set direction = "older"
	If (direction '= "older") && (direction '= "newer") Return ..Err("VALIDATION_FAILED", "direction must be older or newer")
	If (limit '? 1.N) || (limit < 1) || (limit > 200) Return ..Err("VALIDATION_FAILED", "limit must be between 1 and 200")
	Set (curAt, curId) = ""
	If (cursor '= "") && '##class(SignalNoir.Core.Cursor).Decode(cursor, .curAt, .curId) Return ..Err("VALIDATION_FAILED", "invalid cursor")
	If '$IsObject(filters) Set filters = {}
	Set where = ""
	Set n = 0
	Kill args
	Set args = 0
	Set states = filters.%Get("state")
	If $IsObject(states) && (states.%Size() > 0) {
		Set marks = ""
		For i = 0 : 1 : states.%Size() - 1 {
			Set st = states.%Get(i)
			If '##class(SignalNoir.Core.Vocab).IsState(st) Return ..Err("VALIDATION_FAILED", "unknown state: " _ st)
			Set marks = marks _ $Select(marks = "": "", 1: ",") _ "?"
			Set n = n + 1, args(n) = st
		}
		Set where = where _ " AND state IN (" _ marks _ ")"
	}
	Set status = filters.%Get("status")
	If (status '= "") && (status '= "all") {
		If (status '= "open") && (status '= "terminal") Return ..Err("VALIDATION_FAILED", "status must be open, terminal or all")
		Set where = where _ " AND state " _ $Select(status = "terminal": "IN", 1: "NOT IN") _ " ('Resolved','ResolvedByPriorReceipt','Cancelled','Failed')"
	}
	If filters.%IsDefined("pendingApproval") {
		Set where = where _ " AND state " _ $Select(filters.%Get("pendingApproval"): "=", 1: "<>") _ " 'PendingApproval'"
	}
	If filters.%Get("runId") '= "" {
		Set n = n + 1, args(n) = filters.%Get("runId")
		Set where = where _ " AND runId = ?"
	}
	If filters.%IsDefined("includeBenchmark") && 'filters.%Get("includeBenchmark") {
		Set where = where _ " AND (runId IS NULL OR runId = '')"
	}
	Set filterWhere = where
	Set filterN = n
	If curAt '= "" {
		Set op = $Select(direction = "newer": ">", 1: "<")
		Set where = where _ " AND (lastEventAt " _ op _ " ? OR (lastEventAt = ? AND caseId " _ op _ " ?))"
		Set n = n + 1, args(n) = curAt
		Set n = n + 1, args(n) = curAt
		Set n = n + 1, args(n) = curId
	}
	Set args = n
	Set order = $Select(direction = "newer": "ASC", 1: "DESC")
	Set sql = "SELECT TOP " _ (limit + 1) _ " caseId, lastEventAt FROM SignalNoir_Application_Model.CaseRecord WHERE 1=1" _ where _ " ORDER BY lastEventAt " _ order _ ", caseId " _ order
	Set rs = ##class(%SQL.Statement).%ExecDirect(, sql, args...)
	If rs.%SQLCODE < 0 Return ..Err("", "list query failed: " _ rs.%Message)
	Set list = ##class(%ListOfObjects).%New()
	Set nextCursor = ""
	Set (lastAt, lastId) = ""
	While rs.%Next() {
		If list.Count() >= limit {
			Set nextCursor = ##class(SignalNoir.Core.Cursor).Encode(lastAt, lastId)
			Quit
		}
		Set rec = ..Load(rs.%Get("caseId"))
		If '$IsObject(rec) Continue
		Do list.Insert(..ToSummaryDto(rec))
		Set lastAt = rec.lastEventAt, lastId = rec.caseId
	}
	; head: the greatest (lastEventAt, caseId) that matches the filters now
	Kill hargs
	For i = 1 : 1 : filterN Set hargs(i) = args(i)
	Set hargs = filterN
	Set head = ""
	Set hs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 caseId, lastEventAt FROM SignalNoir_Application_Model.CaseRecord WHERE 1=1" _ filterWhere _ " ORDER BY lastEventAt DESC, caseId DESC", hargs...)
	If hs.%Next() Set head = ##class(SignalNoir.Core.Cursor).Encode(hs.%Get("lastEventAt"), hs.%Get("caseId"))
	If (head = "") && (cursor '= "") Set head = cursor
	Set r = ##class(SignalNoir.Core.Result).OkList(list)
	Set r.details = {"nextCursor": (nextCursor), "headCursor": (head)}
	Return r
}

// --------------------------------------------------------------- private

Method DoTransition(caseId As %String, expectedVersion As %Integer, toState As %String, actor As %String, event As SignalNoir.Core.Dto.TimelineEvent, expectedState As %String, expectedTarget As %String, followPayload As %DynamicObject) As SignalNoir.Core.Result [ Private ]
{
	If '##class(SignalNoir.Application.Model.CaseRecord).%ExistsId(caseId) Return ..Err("NOT_FOUND", "case not found: " _ caseId)
	Set payload = ""
	If $IsObject(event) && $IsObject(event.payload) Set payload = event.payload
	Set now = ..Now()
	Set result = ""
	TSTART
	Try {
		If '..Acquire("^SignalNoir.CaseLock", caseId, .locks) {
			Set result = ..Err("", "case busy: " _ caseId)
			Quit
		}
		Set rec = ..Load(caseId)
		Set stale = ((expectedVersion '= "") && (+expectedVersion '= rec.caseVersion))
		Set stale = stale || ((expectedState '= "") && (expectedState '= rec.state))
		Set stale = stale || ((expectedTarget '= "") && (expectedTarget '= rec.currentProposalId) && (expectedTarget '= rec.currentExecutionId))
		If stale {
			Set result = ..ErrorWithCase("STALE_VERSION", "Case changed since it was read", rec, expectedVersion)
			Quit
		}
		Set result = ..ApplyTransition(rec, toState, actor, payload, followPayload, now)
		If 'result.ok Quit
		$$$ThrowOnError(rec.%Save())
	}
	Catch ex {
		Set result = ..FromException(ex, "transition failed")
	}
	Return ..Finish(result, .locks)
}

/// Applies an allowed transition to a loaded, locked Case inside the
/// caller's transaction: state, caseVersion + 1, StateChanged event and the
/// follow-up work. The caller saves the Case and commits.
Method ApplyTransition(rec As SignalNoir.Application.Model.CaseRecord, toState As %String, actor As %String, payload As %DynamicObject, followPayload As %DynamicObject, now As %String) As SignalNoir.Core.Result [ Private ]
{
	Set from = rec.state
	Set code = ##class(SignalNoir.Core.CaseMachine).Check(from, toState, actor)
	If code '= "" Return ..ErrorWithCase(code, "transition " _ from _ " -> " _ toState _ $Select(code = "INVALID_ACTOR": " not allowed to " _ actor, 1: " rejected"), rec, "")
	Set reason = ""
	If $IsObject(payload) Set reason = payload.reason
	Set rec.state = toState
	Set rec.caseVersion = rec.caseVersion + 1
	Set rec.updatedAt = now
	If toState = "ReviewRequired" Set rec.reviewReason = $Select(reason = "": "review required", 1: reason)
	If toState = "Rejected" Set rec.denialCount = rec.denialCount + 1
	If (from = "Approved") && (toState = "PendingApproval") Set rec.currentApprovalId = ""
	If ##class(SignalNoir.Core.Vocab).IsTerminal(toState) Set rec.openOrderId = ""
	Set facts = {"from": (from), "to": (toState), "reason": (reason), "caseVersionAfter": (rec.caseVersion)}
	If $IsObject(payload) {
		Set it = payload.%GetIterator()
		While it.%GetNext(.k, .v) {
			If 'facts.%IsDefined(k) Do facts.%Set(k, v)
		}
	}
	Do ..AppendEvent(rec, "StateChanged", actor, rec.caseId, facts, now)
	Set command = ##class(SignalNoir.Core.CaseMachine).FollowUp(from, toState)
	Set commandId = ""
	If command '= "" {
		Set outbox = ##class(SignalNoir.Application.Model.OutboxRecord).%New()
		Set outbox.commandId = ..Ids.New("cmd_")
		Set outbox.type = command
		Set outbox.caseId = rec.caseId
		Set outbox.caseVersionAfter = rec.caseVersion
		Set outbox.status = "pending"
		Set outbox.payloadJson = $Select($IsObject(followPayload): followPayload.%ToJSON(), 1: "{}")
		Set outbox.createdAt = now
		$$$ThrowOnError(outbox.%Save())
		Set commandId = outbox.commandId
	}
	Set r = ##class(SignalNoir.Core.Result).OkRef(rec.caseId)
	Set r.details = {"commandId": (commandId), "caseVersion": (rec.caseVersion), "state": (toState)}
	Return r
}

/// A new Case in Open for the Order, with CaseOpened (inside the caller's
/// transaction). The unique openOrderIdx refuses a second non-terminal Case.
Method NewCase(orderRec As SignalNoir.Application.Model.OrderRecord, previousCaseId As %String, now As %String) As SignalNoir.Application.Model.CaseRecord [ Private ]
{
	Set rec = ##class(SignalNoir.Application.Model.CaseRecord).%New()
	Set rec.caseId = ..Ids.New("case_")
	Set rec.orderId = orderRec.orderId
	Set rec.openOrderId = orderRec.orderId
	Set rec.previousCaseId = previousCaseId
	Set rec.partnerId = orderRec.partnerId
	Set rec.state = "Open"
	Set rec.caseVersion = 1
	Set rec.lastEventSeq = 0
	Set rec.runId = orderRec.runId
	Set rec.proposerMode = "agent"
	Set rec.synthetic = 1
	Set rec.replay = 0
	Set rec.createdAt = now
	Set rec.updatedAt = now
	Set opened = {"orderId": (orderRec.orderId), "correlationId": (orderRec.correlationId), "state": "Open"}
	If previousCaseId '= "" Do opened.%Set("previousCaseId", previousCaseId)
	Do ..AppendEvent(rec, "CaseOpened", "system", rec.caseId, opened, now)
	$$$ThrowOnError(rec.%Save())
	Return rec
}

Method SaveException(rec As SignalNoir.Application.Model.CaseRecord, orderId As %String, exception As SignalNoir.Core.Dto.CaseException, observedAt As %String, during As %Boolean) As %String [ Private ]
{
	Set ex = ##class(SignalNoir.Application.Model.ExceptionRecord).%New()
	Set ex.exceptionId = ..Ids.New("exc_")
	Set ex.caseId = rec.caseId
	Set ex.orderId = orderId
	Set ex.kind = exception.kind
	Set ex.httpStatus = exception.httpStatus
	If $IsObject(exception.body) {
		Set ex.bodyJson = exception.body.%ToJSON()
	} ElseIf exception.bodyText '= "" {
		Set wrap = []
		Do wrap.%Push(exception.bodyText)
		Set ex.bodyJson = wrap.%ToJSON()
	}
	Set ex.responseClass = exception.responseClass
	Set ex.observedAt = observedAt
	Set ex.attemptId = exception.attemptId
	Set ex.duringExecution = during
	$$$ThrowOnError(ex.%Save())
	Return ex.exceptionId
}

/// Appends one Timeline row inside the caller's transaction, under the
/// per-Case lock: seq = watermark + 1, never reused, no gap (research R4).
/// The caller saves the Case row, which publishes the new watermark.
Method AppendEvent(rec As SignalNoir.Application.Model.CaseRecord, eventType As %String, actor As %String, refId As %String, payload As %DynamicObject, at As %String) As %Integer [ Private ]
{
	Set seq = rec.lastEventSeq + 1
	Set ev = ##class(SignalNoir.Application.Model.CaseEventRecord).%New()
	Set ev.caseId = rec.caseId
	Set ev.seq = seq
	Set ev.at = at
	Set ev.type = eventType
	Set ev.actor = actor
	Set ev.refId = refId
	Set ev.payloadJson = $Select($IsObject(payload): payload.%ToJSON(), 1: "{}")
	$$$ThrowOnError(ev.%Save())
	Set rec.lastEventSeq = seq
	Set rec.lastEventAt = at
	Return seq
}

Method OpenCaseOf(orderId As %String) As %String [ Private ]
{
	If orderId = "" Return ""
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT caseId FROM SignalNoir_Application_Model.CaseRecord WHERE openOrderId = ?", orderId)
	If rs.%Next() Return rs.%Get("caseId")
	Return ""
}

Method CloseDispatched(caseId As %String) [ Private ]
{
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT commandId FROM SignalNoir_Application_Model.OutboxRecord WHERE caseId = ? AND type = 'Investigate' AND status = 'dispatched'", caseId)
	While rs.%Next() {
		Do ..SetOutboxStatus(rs.%Get("commandId"), "dispatched", "done")
	}
}

Method SetOutboxStatus(commandId As %String, from As %String, to As %String) As SignalNoir.Core.Result [ Private ]
{
	Set rec = ##class(SignalNoir.Application.Model.OutboxRecord).%OpenId(commandId)
	If '$IsObject(rec) Return ..Err("NOT_FOUND", "command not found: " _ commandId)
	Do rec.%Reload()
	If rec.status '= from Return ..Err("INVALID_TRANSITION", "command " _ commandId _ " is " _ rec.status)
	Set rec.status = to
	If to = "dispatched" Set rec.dispatchedAt = ..Now()
	Set sc = rec.%Save()
	If $$$ISERR(sc) Return ..Err("", $System.Status.GetErrorText(sc))
	Return ##class(SignalNoir.Core.Result).OkRef(commandId)
}

/// Fresh read of a Case row (never a stale in-memory copy)
Method Load(caseId As %String) As SignalNoir.Application.Model.CaseRecord [ Private ]
{
	If caseId = "" Return ""
	Set rec = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(caseId)
	If $IsObject(rec) Do rec.%Reload()
	Return rec
}

/// LOCK inside the transaction; released at TCOMMIT/TROLLBACK by Finish
Method Acquire(global As %String, key As %String, ByRef locks) As %Boolean [ Private ]
{
	Set ref = $Name(@global@(key))
	Lock +@ref:..#LOCKTIMEOUT
	If '$Test Return 0
	Set locks($Increment(locks)) = ref
	Return 1
}

/// Commits when the result is ok, rolls back this level otherwise, and
/// releases the locks taken by the command.
Method Finish(result As SignalNoir.Core.Result, ByRef locks) As SignalNoir.Core.Result [ Private ]
{
	If '$IsObject(result) Set result = ..Err("", "command produced no result")
	If result.ok {
		For i = 1 : 1 : $Get(locks) {
			Set ref = locks(i)
			Lock -@ref
		}
		TCOMMIT
	} Else {
		TROLLBACK 1
		For i = 1 : 1 : $Get(locks) {
			Set ref = locks(i)
			Lock -@ref
		}
	}
	Return result
}

Method FromException(ex As %Exception.AbstractException, context As %String) As SignalNoir.Core.Result [ Private ]
{
	Set sc = ex.AsStatus()
	If $System.Status.Equals(sc, 5800) Return ..Err("STALE_VERSION", "Case changed since it was read")
	If $System.Status.Equals(sc, 5808) Return ..Err("STALE_VERSION", "a non-terminal Case already exists for this order")
	Return ..Err("", context _ ": " _ ex.DisplayString())
}

Method Refuse(orderId As %String, transactionId As %String, reasons As %ListOfDataTypes) As SignalNoir.Core.Result [ Private ]
{
	Set refusal = ##class(SignalNoir.Application.Model.IntakeRefusalRecord).%New()
	Set refusal.orderId = orderId
	Set refusal.transactionId = transactionId
	Set list = []
	For i = 1 : 1 : reasons.Count() {
		Do refusal.reasons.Insert(reasons.GetAt(i))
		Do list.%Push(reasons.GetAt(i))
	}
	Set refusal.refusedAt = ..Now()
	Do refusal.%Save()
	Set text = ""
	For i = 1 : 1 : reasons.Count() {
		Set text = text _ $Select(i = 1: "", 1: ", ") _ reasons.GetAt(i)
	}
	Return ##class(SignalNoir.Core.Result).ErrorWith("VALIDATION_FAILED", "order refused: " _ text, {"reasons": (list), "orderId": (orderId)})
}

/// Conflict result with the current Case facts the client needs to reload
Method ErrorWithCase(code As %String, message As %String, rec As SignalNoir.Application.Model.CaseRecord, expectedVersion As %String) As SignalNoir.Core.Result [ Private ]
{
	Set details = {"caseVersion": (rec.caseVersion), "lastEventSeq": (rec.lastEventSeq), "state": (rec.state), "serverTime": (..Now())}
	If expectedVersion '= "" Do details.%Set("expectedCaseVersion", +expectedVersion)
	Do details.%Set("currentProposalId", rec.currentProposalId, $Select(rec.currentProposalId = "": "null", 1: "string"))
	Return ##class(SignalNoir.Core.Result).ErrorWith(code, message, details)
}

Method Event(payload As %DynamicObject) As SignalNoir.Core.Dto.TimelineEvent [ Private ]
{
	Set event = ##class(SignalNoir.Core.Dto.TimelineEvent).%New()
	Set event.type = "StateChanged"
	Set event.payload = payload
	Return event
}

Method ToCaseDto(rec As SignalNoir.Application.Model.CaseRecord) As SignalNoir.Core.Dto.Case [ Private ]
{
	Set dto = ##class(SignalNoir.Core.Dto.Case).%New()
	Set dto.caseId = rec.caseId
	Set dto.orderId = rec.orderId
	Set dto.partnerId = rec.partnerId
	Set dto.state = rec.state
	Set dto.caseVersion = rec.caseVersion
	Set dto.lastEventSeq = rec.lastEventSeq
	Set dto.lastEventAt = rec.lastEventAt
	Set dto.synthetic = rec.synthetic
	Set dto.replay = rec.replay
	Set dto.reviewReason = rec.reviewReason
	Set dto.createdAt = rec.createdAt
	Set dto.updatedAt = rec.updatedAt
	Set dto.denialCount = rec.denialCount
	Set dto.previousCaseId = rec.previousCaseId
	Set dto.currentProposalId = rec.currentProposalId
	Set dto.currentApprovalId = rec.currentApprovalId
	Set dto.currentExecutionId = rec.currentExecutionId
	Set dto.executionOutcome = rec.executionOutcome
	Set dto.runId = rec.runId
	Set dto.proposerMode = rec.proposerMode
	Return dto
}

Method ToOrderDto(rec As SignalNoir.Application.Model.OrderRecord) As SignalNoir.Core.Dto.Order [ Private ]
{
	Set dto = ##class(SignalNoir.Core.Dto.Order).%New()
	Set dto.orderId = rec.orderId
	Set dto.partnerId = rec.partnerId
	Set dto.correlationId = rec.correlationId
	For i = 1 : 1 : rec.transactionIds.Count() {
		Do dto.transactionIds.Insert(rec.transactionIds.GetAt(i))
	}
	Set dto.runId = rec.runId
	Set dto.snapshot = ..PayloadObject(rec.snapshotJson)
	Set dto.equivalenceKey = rec.equivalenceKey
	Set dto.receivedAt = rec.receivedAt
	Set dto.synthetic = rec.synthetic
	Set dto.caseId = rec.caseId
	Return dto
}

Method ToExceptionDto(rec As SignalNoir.Application.Model.ExceptionRecord) As SignalNoir.Core.Dto.CaseException [ Private ]
{
	Set dto = ##class(SignalNoir.Core.Dto.CaseException).%New()
	Set dto.exceptionId = rec.exceptionId
	Set dto.kind = rec.kind
	Set dto.httpStatus = rec.httpStatus
	If rec.bodyJson '= "" {
		Set body = ##class(%DynamicAbstractObject).%FromJSON(rec.bodyJson)
		If body.%IsA("%DynamicArray") && (body.%Size() = 1) && (body.%GetTypeOf(0) = "string") {
			Set dto.bodyText = body.%Get(0)
		} Else {
			Set dto.body = body
		}
	}
	Set dto.responseClass = rec.responseClass
	Set dto.observedAt = rec.observedAt
	Set dto.attemptId = rec.attemptId
	Set dto.duringExecution = rec.duringExecution
	Return dto
}

Method ToSummaryDto(rec As SignalNoir.Application.Model.CaseRecord) As SignalNoir.Core.Dto.CaseSummary [ Private ]
{
	Set dto = ##class(SignalNoir.Core.Dto.CaseSummary).%New()
	Set dto.caseId = rec.caseId
	Set dto.orderId = rec.orderId
	Set dto.partnerId = rec.partnerId
	Set dto.state = rec.state
	Set dto.caseVersion = rec.caseVersion
	Set dto.lastEventSeq = rec.lastEventSeq
	Set dto.lastEventAt = rec.lastEventAt
	Set dto.createdAt = rec.createdAt
	Set dto.synthetic = rec.synthetic
	Set dto.replay = rec.replay
	Set dto.currentProposalId = rec.currentProposalId
	Set dto.executionOutcome = rec.executionOutcome
	Set dto.runId = rec.runId
	Set dto.proposerMode = rec.proposerMode
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT kind, httpStatus FROM SignalNoir_Application_Model.ExceptionRecord WHERE caseId = ? ORDER BY observedAt DESC, exceptionId DESC", rec.caseId)
	Set count = 0
	While rs.%Next() {
		Set count = count + 1
		If count = 1 Set dto.lastExceptionSummary = rs.%Get("kind") _ $Select(rs.%Get("httpStatus") '= "": " " _ rs.%Get("httpStatus"), 1: "")
	}
	Set dto.exceptionCount = count
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
	Set dto.payload = ..PayloadObject(ev.payloadJson)
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
