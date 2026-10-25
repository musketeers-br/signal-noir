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

/// The single Validator every Proposal passes (feature 009 resolution)
Property Validator As SignalNoir.Core.Port.Validator;

/// Seconds to wait for a per-Case or per-Order lock
Parameter LOCKTIMEOUT = 5;

ClassMethod Default() As SignalNoir.Application.CaseService
{
	Set svc = ##class(SignalNoir.Application.CaseService).%New()
	Set svc.Clock = ##class(SignalNoir.Application.SystemClock).%New()
	Set svc.Ids = ##class(SignalNoir.Application.IdFactory).%New()
	Set svc.Validator = ##class(SignalNoir.Core.Validator).%New()
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
			Set rec.scenarioInstanceId = order.scenarioInstanceId
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
/// to ReviewRequired when the Case's proposer cannot run (no provider for
/// agent mode, 001 behavior), else to Investigating with an Investigate
/// request (handled by InvestigationService, feature 006).
Method ProcessException(orderId As %String, exception As SignalNoir.Core.Dto.CaseException) As SignalNoir.Core.Result
{
	Set r = ..RecordException(orderId, exception)
	If 'r.ok || (r.details.route '= "open") Return r
	Set g = ..GetCase(r.ref)
	If 'g.ok Return g
	Set caseDto = g.obj
	Set unavailable = '##class(SignalNoir.Proposers.Factory).Ready(caseDto.proposerMode)
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
	Set evidence = ..ListEvidence(caseId)
	For i = 1 : 1 : evidence.Count() Do dto.evidence.Insert(evidence.GetAt(i))
	Set proposals = ..ListProposals(caseId)
	For i = 1 : 1 : proposals.Count() Do dto.proposals.Insert(proposals.GetAt(i))
	Set dto.metrics = ..CaseMetrics(caseId)
	Set dto.dossier = ..LatestDossier(caseId)
	Set dto.approvals = ..ListApprovals(caseId)
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

// --------------------------------------------------------- investigation

/// Claims an Investigate request at most once (pending -> dispatched) and
/// opens its Investigation when the Case is still Investigating at the
/// request's version (006 FR-001, FR-002); records the Case's Exceptions as
/// Evidence and scans the Order for embedded instructions. A stale or
/// repeated request is discarded and recorded (details.discarded = 1).
/// Result.ref = investigationId (the request's commandId).
Method StartInvestigation(commandId As %String, proposerClass As %String, sourceClass As %String, budgetMs As %Integer = {##class(SignalNoir.Core.Budget).#MAXMILLIS}) As SignalNoir.Core.Result
{
	Set outbox = ##class(SignalNoir.Application.Model.OutboxRecord).%OpenId(commandId)
	If '$IsObject(outbox) || (outbox.type '= "Investigate") Return ..Err("NOT_FOUND", "investigation request not found: " _ commandId)
	Set caseId = outbox.caseId
	Set now = ..Now()
	Set result = ""
	TSTART
	Try {
		If '..Acquire("^SignalNoir.CaseLock", caseId, .locks) {
			Set result = ..Err("", "case busy: " _ caseId)
			Quit
		}
		Do outbox.%Reload()
		Set rec = ..Load(caseId)
		Set why = ""
		If outbox.status '= "pending" Set why = "request already " _ outbox.status
		If (why = "") && ((rec.state '= "Investigating") || (rec.caseVersion '= outbox.caseVersionAfter)) Set why = "case moved: " _ rec.state _ " v" _ rec.caseVersion
		If why '= "" {
			If outbox.status = "pending" {
				Set outbox.status = "done"
				$$$ThrowOnError(outbox.%Save())
			}
			Do ..AppendEvent(rec, "CommandDiscarded", "system", commandId, {"commandId": (commandId), "reason": (why)}, now)
			$$$ThrowOnError(rec.%Save())
			Set result = ##class(SignalNoir.Core.Result).OkRef("")
			Set result.details = {"discarded": 1, "reason": (why)}
			Quit
		}
		Set outbox.status = "dispatched"
		Set outbox.dispatchedAt = now
		$$$ThrowOnError(outbox.%Save())
		Set inv = ##class(SignalNoir.Application.Model.InvestigationRecord).%New()
		Set inv.investigationId = commandId
		Set inv.caseId = caseId
		Set inv.caseVersionAtStart = rec.caseVersion
		Set inv.mode = rec.proposerMode
		Set inv.proposerClass = proposerClass
		Set inv.sourceClass = sourceClass
		Set inv.status = "open"
		Set inv.startedAt = now
		Set inv.startedMs = ..NowMs()
		Set inv.budgetMs = budgetMs
		Set inv.toolCalls = 0
		$$$ThrowOnError(inv.%Save())
		Do ..AppendEvent(rec, "Annotation", "system", commandId, {"kind": "investigation_started", "investigationId": (commandId), "mode": (rec.proposerMode)}, now)
		; the Exceptions already on the Case are system Evidence
		Set ids = []
		Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT exceptionId FROM SignalNoir_Application_Model.ExceptionRecord WHERE caseId = ? ORDER BY observedAt, exceptionId", caseId)
		While rs.%Next() {
			Set ex = ##class(SignalNoir.Application.Model.ExceptionRecord).%OpenId(rs.%Get("exceptionId"))
			Set ev = ##class(SignalNoir.Core.Dto.Evidence).%New()
			Set ev.source = "system.exception"
			Set ev.kind = "fact"
			Set ev.calledBy = "system"
			Set ev.params = {"exceptionId": (ex.exceptionId)}
			Set body = $Select(ex.bodyJson = "": "", 1: ##class(%DynamicAbstractObject).%FromJSON(ex.bodyJson))
			Set res = {"exceptionId": (ex.exceptionId), "kind": (ex.kind), "observedAt": (ex.observedAt), "duringExecution": (+ex.duringExecution)}
			Do res.%Set("httpStatus", ex.httpStatus, $Select(ex.httpStatus = "": "null", 1: "number"))
			If $IsObject(body) Do res.%Set("body", body)
			Set ev.result = res
			Set ev.observedAt = ex.observedAt
			Set ev.durationMs = 0
			Set found = ##class(SignalNoir.Core.Suspicion).Scan(res)
			Do ..SaveEvidence(rec, commandId, ev, found, now)
			Do ids.%Push(ev.evidenceId)
		}
		; the Order itself is data: an embedded instruction is recorded, not obeyed
		Set orderRec = ##class(SignalNoir.Application.Model.OrderRecord).%OpenId(rec.orderId)
		If $IsObject(orderRec) {
			Set found = ##class(SignalNoir.Core.Suspicion).Scan(..PayloadObject(orderRec.snapshotJson))
			If found.Count() > 0 Do ..AppendEvent(rec, "Annotation", "system", rec.orderId, {"kind": "embedded_instruction_blocked", "source": "order.snapshot", "excerpts": (..ToArray(found))}, now)
		}
		$$$ThrowOnError(rec.%Save())
		Set result = ##class(SignalNoir.Core.Result).OkRef(commandId)
		Set result.details = {"discarded": 0, "evidenceIds": (ids)}
	}
	Catch ex {
		Set result = ..FromException(ex, "start investigation failed")
	}
	Return ..Finish(result, .locks)
}

/// Charges one Tool call against the server-side budget (006 FR-003). A call
/// beyond 6, or after the time budget, closes the Investigation (the Case
/// goes to ReviewRequired) and is refused with code budget_exceeded. A
/// closed Investigation refuses with code closed.
Method ChargeToolCall(investigationId As %String) As SignalNoir.Core.Result
{
	Set inv = ##class(SignalNoir.Application.Model.InvestigationRecord).%OpenId(investigationId)
	If '$IsObject(inv) Return ..Err("NOT_FOUND", "investigation not found: " _ investigationId)
	Set now = ..Now()
	Set result = ""
	TSTART
	Try {
		If '..Acquire("^SignalNoir.CaseLock", inv.caseId, .locks) {
			Set result = ..Err("", "case busy: " _ inv.caseId)
			Quit
		}
		Do inv.%Reload()
		If inv.status '= "open" {
			Set result = ..Err("closed", "investigation is " _ inv.status)
			Quit
		}
		Set breach = ##class(SignalNoir.Core.Budget).Breach(inv.toolCalls, ..NowMs() - inv.startedMs, inv.budgetMs)
		If breach '= "" {
			Set reason = ##class(SignalNoir.Core.Budget).Reason(breach)
			Set closed = ..CloseLocked(inv, reason, "", now)
			If 'closed.ok {
				Set result = closed
				Quit
			}
			; the closure commits; the call itself is refused
			Set result = ##class(SignalNoir.Core.Result).OkRef("")
			Set result.details = {"refused": 1, "code": "budget_exceeded", "reason": (reason)}
			Quit
		}
		Set inv.toolCalls = inv.toolCalls + 1
		$$$ThrowOnError(inv.%Save())
		Set result = ##class(SignalNoir.Core.Result).OkRef(inv.toolCalls)
		Set result.details = {"refused": 0}
	}
	Catch ex {
		Set result = ..FromException(ex, "charge tool call failed")
	}
	Set result = ..Finish(result, .locks)
	If result.ok && result.details.refused Return ##class(SignalNoir.Core.Result).Error("budget_exceeded", result.details.reason)
	Return result
}

/// Attachment: records one Evidence (and its ToolCalled event, and the
/// blocked embedded instruction when suspicious). Result.ref = evidenceId.
Method RecordEvidence(investigationId As %String, evidence As SignalNoir.Core.Dto.Evidence) As SignalNoir.Core.Result
{
	Set inv = ##class(SignalNoir.Application.Model.InvestigationRecord).%OpenId(investigationId)
	If '$IsObject(inv) Return ..Err("NOT_FOUND", "investigation not found: " _ investigationId)
	If '$IsObject(evidence) Return ..Err("VALIDATION_FAILED", "evidence is required")
	Set now = ..Now()
	Set result = ""
	TSTART
	Try {
		If '..Acquire("^SignalNoir.CaseLock", inv.caseId, .locks) {
			Set result = ..Err("", "case busy: " _ inv.caseId)
			Quit
		}
		Set rec = ..Load(inv.caseId)
		Set found = ##class(%ListOfDataTypes).%New()
		For i = 1 : 1 : evidence.suspiciousExcerpts.Count() Do found.Insert(evidence.suspiciousExcerpts.GetAt(i))
		Do ..SaveEvidence(rec, investigationId, evidence, found, now)
		$$$ThrowOnError(rec.%Save())
		Set result = ##class(SignalNoir.Core.Result).OkRef(evidence.evidenceId)
	}
	Catch ex {
		Set result = ..FromException(ex, "record evidence failed")
	}
	Return ..Finish(result, .locks)
}

/// Attachment: a refused non-reading Tool (006 FR-008)
Method RecordBlockedTool(investigationId As %String, toolName As %String, caller As %String) As SignalNoir.Core.Result
{
	Set inv = ##class(SignalNoir.Application.Model.InvestigationRecord).%OpenId(investigationId)
	If '$IsObject(inv) Return ..Err("NOT_FOUND", "investigation not found: " _ investigationId)
	Set event = ##class(SignalNoir.Core.Dto.TimelineEvent).%New()
	Set event.type = "Annotation"
	Set event.actor = $Select(##class(SignalNoir.Core.Vocab).IsActor(caller): caller, 1: "system")
	Set event.refId = investigationId
	Set event.payload = {"kind": "write_attempt_blocked", "tool": (toolName), "investigationId": (investigationId)}
	Return ..Append(inv.caseId, event)
}

/// Records the Proposal and moves the Case Investigating -> DecisionProposed
/// in one transaction, with the mode as actor, only while the Investigation
/// is open, within its time budget, and the Case unchanged since it started
/// (006 FR-005, FR-015, FR-016). A closed Investigation refuses with code
/// closed. Result.ref = proposalId.
Method CompleteInvestigation(investigationId As %String, proposal As SignalNoir.Core.Dto.Proposal, meta As %DynamicObject = "") As SignalNoir.Core.Result
{
	Set inv = ##class(SignalNoir.Application.Model.InvestigationRecord).%OpenId(investigationId)
	If '$IsObject(inv) Return ..Err("NOT_FOUND", "investigation not found: " _ investigationId)
	If '$IsObject(proposal) Return ..Err("VALIDATION_FAILED", "proposal is required")
	Set now = ..Now()
	Set result = ""
	TSTART
	Try {
		If '..Acquire("^SignalNoir.CaseLock", inv.caseId, .locks) {
			Set result = ..Err("", "case busy: " _ inv.caseId)
			Quit
		}
		Do inv.%Reload()
		If inv.status '= "open" {
			Set result = ..Err("closed", "investigation is " _ inv.status)
			Quit
		}
		Set rec = ..Load(inv.caseId)
		If (..NowMs() - inv.startedMs) >= inv.budgetMs {
			Set result = ..CloseLocked(inv, ##class(SignalNoir.Core.Budget).Reason("time"), meta, now)
			If result.ok Set result = ##class(SignalNoir.Core.Result).OkRef("")
			Set result.details = {"closedLate": 1}
			Quit
		}
		If (rec.state '= "Investigating") || (rec.caseVersion '= inv.caseVersionAtStart) {
			Set inv.status = "discarded"
			Set inv.closedAt = now
			Set inv.outcomeReason = "case moved: " _ rec.state _ " v" _ rec.caseVersion
			Do ..ApplyMeta(inv, meta)
			$$$ThrowOnError(inv.%Save())
			Do ..AppendEvent(rec, "CommandDiscarded", "system", investigationId, {"investigationId": (investigationId), "reason": (inv.outcomeReason)}, now)
			$$$ThrowOnError(rec.%Save())
			Set result = ..Err("closed", inv.outcomeReason)
			Quit
		}
		Set proposalId = ..Ids.New("prop_")
		If rec.currentProposalId '= "" {
			Set old = ##class(SignalNoir.Application.Model.ProposalRecord).%OpenId(rec.currentProposalId)
			If $IsObject(old) {
				Set old.current = 0
				Set old.supersededBy = proposalId
				$$$ThrowOnError(old.%Save())
			}
		}
		Set pr = ##class(SignalNoir.Application.Model.ProposalRecord).%New()
		Set pr.proposalId = proposalId
		Set pr.caseId = rec.caseId
		Set pr.investigationId = investigationId
		Set pr.author = inv.mode
		Set pr.createdAt = now
		Set pr.current = 1
		Set pr.diagnosisJson = ..Json(proposal.diagnosis)
		Set pr.action = proposal.action
		Set pr.paramsJson = ..Json(proposal.params)
		Set pr.scope = "single_case"
		Set pr.confidence = proposal.confidence
		Set pr.preconditionsJson = $Select($IsObject(proposal.preconditions): proposal.preconditions.%ToJSON(), 1: "[]")
		Set pr.versionsJson = ..Json(proposal.versions)
		Set pr.metricsJson = ..Json(proposal.metrics)
		Set prior = proposal.priorReceiptCandidate
		Set pr.priorReceiptCandidateJson = $Select($IsObject(prior) && (prior.%Size() > 0): prior.%ToJSON(), 1: "")
		$$$ThrowOnError(pr.%Save())
		Set rec.currentProposalId = proposalId
		Do ..AppendEvent(rec, "ProposalCreated", inv.mode, proposalId, {"proposalId": (proposalId), "author": (inv.mode), "action": (proposal.action), "confidence": (proposal.confidence), "investigationId": (investigationId)}, now)
		Set moved = ..ApplyTransition(rec, "DecisionProposed", inv.mode, {"reason": "proposal recorded", "proposalId": (proposalId)}, "", now)
		If 'moved.ok {
			Set result = moved
			Quit
		}
		$$$ThrowOnError(rec.%Save())
		Set inv.status = "proposed"
		Set inv.closedAt = now
		Set inv.proposalId = proposalId
		Set inv.outcomeReason = "proposal recorded"
		Do ..ApplyMeta(inv, meta)
		$$$ThrowOnError(inv.%Save())
		Do ..FinishRequest(investigationId)
		Set result = ##class(SignalNoir.Core.Result).OkRef(proposalId)
	}
	Catch ex {
		Set result = ..FromException(ex, "complete investigation failed")
	}
	Set result = ..Finish(result, .locks)
	If result.ok && $IsObject(result.details) && result.details.closedLate Return ..Err("closed", ##class(SignalNoir.Core.Budget).Reason("time"))
	Return result
}

/// Closes an open Investigation without a Proposal: the Case goes to
/// ReviewRequired with the reason (006 FR-003, FR-018). A closed
/// Investigation refuses with code closed.
Method CloseInvestigation(investigationId As %String, reason As %String, meta As %DynamicObject = "") As SignalNoir.Core.Result
{
	Set inv = ##class(SignalNoir.Application.Model.InvestigationRecord).%OpenId(investigationId)
	If '$IsObject(inv) Return ..Err("NOT_FOUND", "investigation not found: " _ investigationId)
	Set now = ..Now()
	Set result = ""
	TSTART
	Try {
		If '..Acquire("^SignalNoir.CaseLock", inv.caseId, .locks) {
			Set result = ..Err("", "case busy: " _ inv.caseId)
			Quit
		}
		Do inv.%Reload()
		If inv.status '= "open" {
			Set result = ..Err("closed", "investigation is " _ inv.status)
			Quit
		}
		Set result = ..CloseLocked(inv, reason, meta, now)
	}
	Catch ex {
		Set result = ..FromException(ex, "close investigation failed")
	}
	Return ..Finish(result, .locks)
}

/// Attachment: an answer that arrived for a closed Investigation (FR-005)
Method DiscardAnswer(investigationId As %String, reason As %String) As SignalNoir.Core.Result
{
	Set inv = ##class(SignalNoir.Application.Model.InvestigationRecord).%OpenId(investigationId)
	If '$IsObject(inv) Return ..Err("NOT_FOUND", "investigation not found: " _ investigationId)
	Set event = ##class(SignalNoir.Core.Dto.TimelineEvent).%New()
	Set event.type = "CommandDiscarded"
	Set event.actor = "system"
	Set event.refId = investigationId
	Set event.payload = {"investigationId": (investigationId), "reason": (reason)}
	Set rec = ..Load(inv.caseId)
	If ##class(SignalNoir.Core.Vocab).IsTerminal(rec.state) Set event.type = "Annotation", event.payload.kind = "late_answer_discarded"
	Return ..Append(inv.caseId, event)
}

/// Evidence of a Case, in recording order
Method ListEvidence(caseId As %String) As %ListOfObjects
{
	Set list = ##class(%ListOfObjects).%New()
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT evidenceId FROM SignalNoir_Application_Model.EvidenceRecord WHERE caseId = ? ORDER BY observedAt, evidenceId", caseId)
	While rs.%Next() {
		Set ev = ##class(SignalNoir.Application.Model.EvidenceRecord).%OpenId(rs.%Get("evidenceId"))
		If $IsObject(ev) Do list.Insert(..ToEvidenceDto(ev))
	}
	Return list
}

/// Proposals of a Case, oldest first
Method ListProposals(caseId As %String) As %ListOfObjects
{
	Set list = ##class(%ListOfObjects).%New()
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT proposalId FROM SignalNoir_Application_Model.ProposalRecord WHERE caseId = ? ORDER BY createdAt, proposalId", caseId)
	While rs.%Next() {
		Set pr = ##class(SignalNoir.Application.Model.ProposalRecord).%OpenId(rs.%Get("proposalId"))
		If $IsObject(pr) {
			Do pr.%Reload()
			Do list.Insert(..ToProposalDto(pr))
		}
	}
	Return list
}

/// Metrics of the latest Investigation of a Case (contract CaseMetrics)
Method CaseMetrics(caseId As %String) As %DynamicObject
{
	Set metrics = {}
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 investigationId FROM SignalNoir_Application_Model.InvestigationRecord WHERE caseId = ? ORDER BY startedAt DESC, investigationId DESC", caseId)
	If 'rs.%Next() Return metrics
	Set inv = ##class(SignalNoir.Application.Model.InvestigationRecord).%OpenId(rs.%Get("investigationId"))
	Do metrics.%Set("provider", inv.provider, $Select(inv.provider = "": "null", 1: "string"))
	Do metrics.%Set("model", inv.model, $Select(inv.model = "": "null", 1: "string"))
	Do metrics.%Set("promptVersion", inv.promptVersion, $Select(inv.promptVersion = "": "null", 1: "string"))
	If inv.policyVersion '= "" Do metrics.%Set("policyVersion", inv.policyVersion)
	If inv.mappingVersion '= "" Do metrics.%Set("mappingVersion", inv.mappingVersion)
	If inv.durationMs '= "" Do metrics.%Set("investigationDurationMs", +inv.durationMs)
	Do metrics.%Set("toolCalls", +inv.toolCalls)
	If inv.tokensIn '= "" Do metrics.%Set("tokensIn", +inv.tokensIn)
	If inv.tokensOut '= "" Do metrics.%Set("tokensOut", +inv.tokensOut)
	If inv.estCostUsd '= "" Do metrics.%Set("estCostUsd", +inv.estCostUsd)
	Return metrics
}

/// UTC milliseconds since 1970 (budget arithmetic)
ClassMethod NowMs() As %Integer
{
	Set z = $ZTimestamp
	Return ((+z - 47117) * 86400000) + ($Piece(z, ",", 2) * 1000 \ 1)
}

// ------------------------------------------------------------ resolution

/// Operator resolution of a review (feature 009, contract resolveReview):
/// a catalog Action with its allowed parameters, which becomes a Proposal
/// authored operator:<name> and passes the single Validator, or a
/// cancellation with a reason. Refusals: VALIDATION_FAILED (shape, details.reasons;
/// or the Validator's verdict in details.verdict, with only the verdict
/// recorded), STALE_VERSION, INVALID_TRANSITION, NOT_FOUND. On success
/// Result.details: kind, proposalId, approvalId, caseId, state, caseVersion,
/// lastEventSeq, commandId.
Method ResolveReview(caseId As %String, request As %DynamicObject) As SignalNoir.Core.Result
{
	Set reasons = ##class(SignalNoir.Core.ResolutionShape).Check(request)
	If reasons.Count() > 0 {
		Set list = []
		For i = 1 : 1 : reasons.Count() Do list.%Push(reasons.GetAt(i))
		Return ##class(SignalNoir.Core.Result).ErrorWith("VALIDATION_FAILED", "invalid resolution: " _ list.%Get(0), {"reasons": (list)})
	}
	If '##class(SignalNoir.Application.Model.CaseRecord).%ExistsId(caseId) Return ..Err("NOT_FOUND", "case not found: " _ caseId)
	Set operatorName = ##class(SignalNoir.Core.Canon).Trim(request.operator)
	Set actor = "operator:" _ operatorName
	Set now = ..Now()
	Set result = ""
	TSTART
	Try {
		If '..Acquire("^SignalNoir.CaseLock", caseId, .locks) {
			Set result = ..Err("", "case busy: " _ caseId)
			Quit
		}
		Set rec = ..Load(caseId)
		If rec.caseVersion '= request.expectedCaseVersion {
			Set result = ..ErrorWithCase("STALE_VERSION", "Case changed since it was read", rec, request.expectedCaseVersion)
			Quit
		}
		If rec.state '= "ReviewRequired" {
			Set result = ..ErrorWithCase("INVALID_TRANSITION", "Case is " _ rec.state _ ", not ReviewRequired", rec, "")
			Quit
		}
		Set out = {"kind": (request.kind), "proposalId": "", "approvalId": "", "commandId": ""}
		If request.kind = "cancel" {
			Set reason = ##class(SignalNoir.Core.Canon).Trim(request.reason)
			Set moved = ..ApplyTransition(rec, "Cancelled", actor, {"reason": (reason)}, "", now)
			If 'moved.ok {
				Set result = moved
				Quit
			}
			Do ..AppendEvent(rec, "OperatorResolution", actor, caseId, {"kind": "cancel", "reason": (reason)}, now)
		} Else {
			Set dossier = ..LatestDossier(caseId)
			Set ids = $Select($IsObject(dossier.relevantEvidenceIds): dossier.relevantEvidenceIds, 1: [])
			Set proposal = ##class(SignalNoir.Core.OperatorProposal).Build(request.action, request.params, operatorName, ids, request.note)
			Set verdict = ##class(SignalNoir.Application.ResolutionValidator).Verdict(..Validator, proposal, now)
			Do ..AppendEvent(rec, "ValidatorVerdict", actor, caseId, {"proposalAuthor": (actor), "action": (proposal.action), "verdict": (verdict.verdict), "reasons": (verdict.reasons), "requiresApproval": (verdict.requiresApproval)}, now)
			If verdict.verdict '= "accepted" {
				; only the verdict is recorded; the refusal is reported after the commit
				$$$ThrowOnError(rec.%Save())
				Set result = ##class(SignalNoir.Core.Result).OkRef("")
				Set result.details = {"blocked": 1, "verdict": (verdict), "caseVersion": (rec.caseVersion), "lastEventSeq": (rec.lastEventSeq), "serverTime": (now)}
				Quit
			}
			Set proposalId = ..Ids.New("prop_")
			If rec.currentProposalId '= "" {
				Set old = ##class(SignalNoir.Application.Model.ProposalRecord).%OpenId(rec.currentProposalId)
				If $IsObject(old) {
					Set old.current = 0
					Set old.supersededBy = proposalId
					$$$ThrowOnError(old.%Save())
				}
			}
			Set pr = ##class(SignalNoir.Application.Model.ProposalRecord).%New()
			Set pr.proposalId = proposalId, pr.caseId = caseId, pr.author = actor, pr.createdAt = now, pr.current = 1
			Set pr.diagnosisJson = ..Json(proposal.diagnosis), pr.action = proposal.action, pr.paramsJson = ..Json(proposal.params)
			Set pr.scope = "single_case", pr.confidence = proposal.confidence, pr.preconditionsJson = proposal.preconditions.%ToJSON()
			Set pr.versionsJson = ..Json(proposal.versions), pr.metricsJson = ..Json(proposal.metrics), pr.verdictJson = verdict.%ToJSON()
			$$$ThrowOnError(pr.%Save())
			Set rec.currentProposalId = proposalId
			Do ..AppendEvent(rec, "ProposalCreated", actor, proposalId, {"proposalId": (proposalId), "author": (actor), "action": (proposal.action), "confidence": (proposal.confidence)}, now)
			Set moved = ..ApplyTransition(rec, "DecisionProposed", actor, {"reason": "operator resolution", "proposalId": (proposalId)}, "", now)
			If 'moved.ok {
				Set result = moved
				Quit
			}
			If verdict.requiresApproval {
				Set moved = ..ApplyTransition(rec, "PendingApproval", "system", {"reason": "validator accepted; approval required", "proposalId": (proposalId)}, "", now)
				If 'moved.ok {
					Set result = moved
					Quit
				}
				Set appr = ##class(SignalNoir.Application.Model.ApprovalRecord).%New()
				Set appr.approvalId = ..Ids.New("appr_"), appr.caseId = caseId, appr.proposalId = proposalId, appr.decision = "approved", appr.by = actor
				Set appr.at = now, appr.expiresAt = ..Plus(now, 15 * 60), appr.status = "valid"
				$$$ThrowOnError(appr.%Save())
				Set rec.currentApprovalId = appr.approvalId
				Do ..AppendEvent(rec, "ApprovalRecorded", actor, appr.approvalId, {"approvalId": (appr.approvalId), "proposalId": (proposalId), "decision": "approved", "by": (actor), "expiresAt": (appr.expiresAt)}, now)
				Set moved = ..ApplyTransition(rec, "Approved", actor, {"reason": "approved by the resolving operator", "proposalId": (proposalId)}, "", now)
				Set out.approvalId = appr.approvalId
			} Else {
				Set moved = ..ApplyTransition(rec, "Executing", "system", {"reason": "validator accepted; no approval required", "proposalId": (proposalId)}, "", now)
			}
			If 'moved.ok {
				Set result = moved
				Quit
			}
			Set out.commandId = moved.details.commandId
			Set out.proposalId = proposalId
			Do ..AppendEvent(rec, "OperatorResolution", actor, proposalId, {"kind": "action", "action": (proposal.action), "proposalId": (proposalId)}, now)
		}
		$$$ThrowOnError(rec.%Save())
		Do out.%Set("caseId", caseId), out.%Set("state", rec.state), out.%Set("caseVersion", rec.caseVersion), out.%Set("lastEventSeq", rec.lastEventSeq), out.%Set("serverTime", now)
		Set result = ##class(SignalNoir.Core.Result).OkObj(out)
		Set result.details = out
	}
	Catch ex {
		Set result = ..FromException(ex, "resolve review failed")
	}
	Set result = ..Finish(result, .locks)
	If result.ok && $IsObject(result.details) && result.details.blocked {
		Set message = "The validator blocked the operator proposal"
		If result.details.verdict.message '= "" Set message = message _ ": " _ result.details.verdict.message
		Do result.details.verdict.%Remove("message")
		Do result.details.%Remove("blocked")
		Return ##class(SignalNoir.Core.Result).ErrorWith("VALIDATION_FAILED", message, result.details)
	}
	Return result
}

/// The latest Review Dossier of a Case (contract Dossier), or {} when none
Method LatestDossier(caseId As %String) As %DynamicObject
{
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 dossierJson FROM SignalNoir_Application_Model.DossierRecord WHERE caseId = ? ORDER BY createdAt DESC, ID DESC", caseId)
	If rs.%Next() Return ..PayloadObject(rs.%Get("dossierJson"))
	Return {}
}

/// Approvals of a Case (contract Approval[]), oldest first
Method ListApprovals(caseId As %String) As %DynamicArray
{
	Set out = []
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT approvalId FROM SignalNoir_Application_Model.ApprovalRecord WHERE caseId = ? ORDER BY approvalId", caseId)
	While rs.%Next() {
		Do out.%Push(..ApprovalJson(rs.%Get("approvalId")))
	}
	Return out
}

Method ApprovalJson(approvalId As %String) As %DynamicObject
{
	Set a = ##class(SignalNoir.Application.Model.ApprovalRecord).%OpenId(approvalId)
	If '$IsObject(a) Return ""
	Set o = {"approvalId": (a.approvalId), "proposalId": (a.proposalId), "decision": (a.decision), "by": (a.by), "at": (a.at), "status": (a.status)}
	Do o.%Set("expiresAt", a.expiresAt, $Select(a.expiresAt = "": "null", 1: "string"))
	Do o.%Set("reason", a.reason, $Select(a.reason = "": "null", 1: "string"))
	Return o
}

/// One Proposal as the DTO (for command answers)
Method ProposalById(proposalId As %String) As SignalNoir.Core.Dto.Proposal
{
	Set pr = ##class(SignalNoir.Application.Model.ProposalRecord).%OpenId(proposalId)
	If '$IsObject(pr) Return ""
	Return ..ToProposalDto(pr)
}

/// The Validator's verdict recorded with a Proposal ({} when none)
Method VerdictOf(proposalId As %String) As %DynamicObject
{
	Set pr = ##class(SignalNoir.Application.Model.ProposalRecord).%OpenId(proposalId)
	If '$IsObject(pr) || (pr.verdictJson = "") Return {}
	Return ..PayloadObject(pr.verdictJson)
}

// --------------------------------------------------------------- private

/// Builds and saves the Dossier inside the caller's transaction (009)
Method SaveDossier(rec As SignalNoir.Application.Model.CaseRecord, reviewReason As %String, now As %String) [ Private ]
{
	Set evidence = ..ListEvidence(rec.caseId)
	Set proposal = ""
	If rec.currentProposalId '= "" Set proposal = ..ProposalById(rec.currentProposalId)
	Set order = {}
	Set orderRec = ##class(SignalNoir.Application.Model.OrderRecord).%OpenId(rec.orderId)
	If $IsObject(orderRec) Set order = ..PayloadObject(orderRec.snapshotJson)
	Set dossier = ##class(SignalNoir.Core.DossierBuilder).Build(reviewReason, evidence, proposal, order, now)
	Set row = ##class(SignalNoir.Application.Model.DossierRecord).%New()
	Set row.caseId = rec.caseId
	Set row.createdAt = now
	Set row.reason = dossier.reason
	Set row.dossierJson = dossier.%ToJSON()
	$$$ThrowOnError(row.%Save())
	Do ..AppendEvent(rec, "DossierCreated", "system", rec.caseId, {"reason": (dossier.reason)}, now)
}

/// ISO-8601 UTC plus seconds
ClassMethod Plus(iso As %String, seconds As %Integer) As %String [ Private ]
{
	Set day = $ZDateH($Extract(iso, 1, 10), 3)
	Set secs = $ZTimeH($Extract(iso, 12, 19)) + seconds
	Set day = day + (secs \ 86400), secs = secs # 86400
	Set frac = $Piece($Piece(iso, ".", 2), "Z", 1)
	Return $ZDate(day, 3) _ "T" _ $ZTime(secs, 1) _ $Select(frac '= "": "." _ frac, 1: "") _ "Z"
}

Method CloseLocked(inv As SignalNoir.Application.Model.InvestigationRecord, reason As %String, meta As %DynamicObject, now As %String) As SignalNoir.Core.Result [ Private ]
{
	Set rec = ..Load(inv.caseId)
	Set inv.closedAt = now
	Set inv.outcomeReason = reason
	Do ..ApplyMeta(inv, meta)
	If (rec.state = "Investigating") && (rec.caseVersion = inv.caseVersionAtStart) {
		Set moved = ..ApplyTransition(rec, "ReviewRequired", "system", {"reason": (reason), "investigationId": (inv.investigationId)}, "", now)
		If 'moved.ok Return moved
		Set inv.status = "review"
	} Else {
		Set inv.status = "discarded"
		Do ..AppendEvent(rec, "CommandDiscarded", "system", inv.investigationId, {"investigationId": (inv.investigationId), "reason": (reason)}, now)
	}
	$$$ThrowOnError(rec.%Save())
	$$$ThrowOnError(inv.%Save())
	Do ..FinishRequest(inv.investigationId)
	Set r = ##class(SignalNoir.Core.Result).OkRef(inv.investigationId)
	Set r.details = {"status": (inv.status)}
	Return r
}

/// Duration, versions and usage of an Investigation as it closes
Method ApplyMeta(inv As SignalNoir.Application.Model.InvestigationRecord, meta As %DynamicObject) [ Private ]
{
	Set inv.durationMs = ..NowMs() - inv.startedMs
	If '$IsObject(meta) Return
	For key = "provider", "model", "promptVersion", "policyVersion", "mappingVersion", "tokensIn", "tokensOut", "estCostUsd" {
		If meta.%Get(key) '= "" Set $Property(inv, key) = meta.%Get(key)
	}
}

/// The request that carried the Investigation is done (dispatched -> done)
Method FinishRequest(commandId As %String) [ Private ]
{
	Set outbox = ##class(SignalNoir.Application.Model.OutboxRecord).%OpenId(commandId)
	If '$IsObject(outbox) Return
	Do outbox.%Reload()
	If outbox.status = "done" Return
	Set outbox.status = "done"
	$$$ThrowOnError(outbox.%Save())
}

/// Saves one Evidence row and its Timeline events inside the caller's
/// transaction (record first, then return: 006 FR-009)
Method SaveEvidence(rec As SignalNoir.Application.Model.CaseRecord, investigationId As %String, ev As SignalNoir.Core.Dto.Evidence, found As %ListOfDataTypes, now As %String) [ Private ]
{
	Set row = ##class(SignalNoir.Application.Model.EvidenceRecord).%New()
	Set row.evidenceId = ..Ids.New("evid_")
	Set row.caseId = rec.caseId
	Set row.investigationId = investigationId
	Set row.source = ev.source
	Set row.kind = $Select(ev.kind = "": "fact", 1: ev.kind)
	Set row.calledBy = ev.calledBy
	Set row.paramsJson = ..Json(ev.params)
	Set row.resultJson = $Select($IsObject(ev.result): ev.result.%ToJSON(), 1: "null")
	Set row.observedAt = $Select(ev.observedAt = "": now, 1: ev.observedAt)
	Set row.durationMs = ev.durationMs
	Set row.suspicious = (found.Count() > 0)
	For i = 1 : 1 : found.Count() Do row.suspiciousExcerpts.Insert(found.GetAt(i))
	$$$ThrowOnError(row.%Save())
	Set ev.evidenceId = row.evidenceId
	Set ev.caseId = rec.caseId
	Set ev.investigationId = investigationId
	Set ev.suspicious = row.suspicious
	Set actor = $Select(##class(SignalNoir.Core.Vocab).IsActor(ev.calledBy): ev.calledBy, 1: "system")
	If $Extract(ev.source, 1, 5) = "tool." {
		Do ..AppendEvent(rec, "ToolCalled", actor, row.evidenceId, {"evidenceId": (row.evidenceId), "tool": (ev.source), "kind": (row.kind), "suspicious": (+row.suspicious), "durationMs": (+ev.durationMs)}, now)
	} Else {
		Do ..AppendEvent(rec, "Annotation", actor, row.evidenceId, {"kind": "evidence", "evidenceId": (row.evidenceId), "source": (ev.source)}, now)
	}
	If row.suspicious Do ..AppendEvent(rec, "Annotation", "system", row.evidenceId, {"kind": "embedded_instruction_blocked", "evidenceId": (row.evidenceId), "source": (ev.source), "excerpts": (..ToArray(found))}, now)
}

Method ToEvidenceDto(row As SignalNoir.Application.Model.EvidenceRecord) As SignalNoir.Core.Dto.Evidence [ Private ]
{
	Set ev = ##class(SignalNoir.Core.Dto.Evidence).%New()
	Set ev.evidenceId = row.evidenceId
	Set ev.caseId = row.caseId
	Set ev.investigationId = row.investigationId
	Set ev.kind = row.kind
	Set ev.source = row.source
	Set ev.calledBy = row.calledBy
	Set ev.params = ..PayloadObject(row.paramsJson)
	Set ev.result = $Select((row.resultJson = "") || (row.resultJson = "null"): "", 1: ##class(%DynamicAbstractObject).%FromJSON(row.resultJson))
	If $IsObject(ev.result) && ev.result.%IsA("%DynamicObject") Set ev.payload = ev.result
	Set ev.observedAt = row.observedAt
	Set ev.durationMs = row.durationMs
	Set ev.suspicious = row.suspicious
	For i = 1 : 1 : row.suspiciousExcerpts.Count() Do ev.suspiciousExcerpts.Insert(row.suspiciousExcerpts.GetAt(i))
	Set ev.obsoletedBy = row.obsoletedBy
	Return ev
}

Method ToProposalDto(pr As SignalNoir.Application.Model.ProposalRecord) As SignalNoir.Core.Dto.Proposal [ Private ]
{
	Set p = ##class(SignalNoir.Core.Dto.Proposal).%New()
	Set p.proposalId = pr.proposalId
	Set p.caseId = pr.caseId
	Set p.origin = pr.author
	Set p.createdAt = pr.createdAt
	Set p.current = pr.current
	Set p.supersededBy = pr.supersededBy
	Set p.diagnosis = ..PayloadObject(pr.diagnosisJson)
	Set p.action = pr.action
	Set p.params = ..PayloadObject(pr.paramsJson)
	Set p.scope = pr.scope
	Set p.confidence = pr.confidence
	Set p.preconditions = $Select(pr.preconditionsJson = "": [], 1: ##class(%DynamicArray).%FromJSON(pr.preconditionsJson))
	Set p.versions = ..PayloadObject(pr.versionsJson)
	Set p.metrics = ..PayloadObject(pr.metricsJson)
	If (pr.priorReceiptCandidateJson '= "") && (pr.priorReceiptCandidateJson '= "{}") Set p.priorReceiptCandidate = ..PayloadObject(pr.priorReceiptCandidateJson)
	Return p
}

Method Json(obj) As %String [ Private ]
{
	If '$IsObject(obj) Return "{}"
	Return obj.%ToJSON()
}

ClassMethod ToArray(list As %ListOfDataTypes) As %DynamicArray [ Private ]
{
	Set arr = []
	For i = 1 : 1 : list.Count() Do arr.%Push(list.GetAt(i))
	Return arr
}

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
	; every entry into review records its Dossier in the same transaction (009)
	If toState = "ReviewRequired" Do ..SaveDossier(rec, rec.reviewReason, now)
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
	Set dto.scenarioInstanceId = rec.scenarioInstanceId
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
	If rec.currentProposalId '= "" {
		Set pr = ##class(SignalNoir.Application.Model.ProposalRecord).%OpenId(rec.currentProposalId)
		If $IsObject(pr) {
			Set dto.currentAction = pr.action
			Set dto.currentConfidence = pr.confidence
		}
	}
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
