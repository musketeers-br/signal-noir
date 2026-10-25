Class SignalNoir.Tests.Support Extends %RegisteredObject
{

/// 003 test helpers: synthetic Origin Orders, Exceptions and walks through
/// the transition table. Test-only (not a TestCase).
ClassMethod Uid(tag As %String) As %String
{
	Return tag _ "-" _ $JOB _ "-" _ $Increment(^SignalNoir.TestSeq)
}

ClassMethod Snapshot(orderId As %String) As %DynamicObject
{
	Set o = ##class(SignalNoir.Tests.Core.TestOrderShape).ValidOrder()
	Set o.orderId = orderId
	Set o.patient.patientId = "P-" _ orderId
	Return o
}

ClassMethod Order(orderId As %String, transactionId As %String = "", runId As %String = "") As SignalNoir.Core.Dto.Order
{
	Set order = ##class(SignalNoir.Core.Dto.Order).%New()
	Set order.orderId = orderId
	Set order.snapshot = ..Snapshot(orderId)
	Set order.transactionId = $Select(transactionId = "": "tx-" _ orderId, 1: transactionId)
	Set order.runId = runId
	Set order.synthetic = 1
	Return order
}

ClassMethod Exception(kind As %String = "timeout", httpStatus As %String = "") As SignalNoir.Core.Dto.CaseException
{
	Set ex = ##class(SignalNoir.Core.Dto.CaseException).%New()
	Set ex.kind = kind
	Set ex.httpStatus = httpStatus
	If httpStatus '= "" Set ex.body = {"error": "validation", "detail": "unknown exam code"}
	Set ex.observedAt = ##class(SignalNoir.Application.SystemClock).%New().NowUtc()
	Set ex.attemptId = "att-1"
	Return ex
}

/// Accepts an Order and records its first Exception: returns the caseId (Open)
ClassMethod OpenCase(svc As SignalNoir.Application.CaseService, orderId As %String, runId As %String = "") As %String
{
	Set a = svc.AcceptOrder(..Order(orderId, , runId))
	If 'a.ok Return ""
	Set r = svc.RecordException(orderId, ..Exception())
	Return $Select(r.ok: r.ref, 1: "")
}

ClassMethod Ev(reason As %String = "") As SignalNoir.Core.Dto.TimelineEvent
{
	Set event = ##class(SignalNoir.Core.Dto.TimelineEvent).%New()
	Set event.type = "StateChanged"
	Set event.payload = {"reason": (reason)}
	Return event
}

/// Walks a Case from Open to the target state through allowed transitions.
/// Returns "" on success or the code that stopped it.
ClassMethod DriveTo(svc As SignalNoir.Application.CaseService, caseId As %String, target As %String) As %String
{
	Set paths("Open") = ""
	Set paths("Investigating") = "Investigating:system"
	Set paths("DecisionProposed") = paths("Investigating") _ ",DecisionProposed:agent"
	Set paths("PendingApproval") = paths("DecisionProposed") _ ",PendingApproval:system"
	Set paths("Approved") = paths("PendingApproval") _ ",Approved:operator:ana"
	Set paths("Rejected") = paths("PendingApproval") _ ",Rejected:operator:ana"
	Set paths("Executing") = paths("Approved") _ ",Executing:system"
	Set paths("Held") = paths("Approved") _ ",Held:system"
	Set paths("Resolved") = paths("Executing") _ ",Resolved:system"
	Set paths("ReviewRequired") = "ReviewRequired:system"
	Set paths("Cancelled") = paths("ReviewRequired") _ ",Cancelled:operator:ana"
	Set path = $Get(paths(target), "?")
	If path = "?" Return "NO_PATH"
	For i = 1 : 1 : $Length(path, ",") {
		Set step = $Piece(path, ",", i)
		If step = "" Continue
		Set to = $Piece(step, ":", 1)
		Set actor = $Piece(step, ":", 2, 3)
		Set g = svc.GetCase(caseId)
		If 'g.ok Return g.code
		Set t = svc.Transition(caseId, g.obj.caseVersion, to, actor, ..Ev("test walk"))
		If 't.ok Return t.code _ " at " _ to _ ": " _ t.message
	}
	Return ""
}

/// Outbox rows of a Case: count by "type:status"
ClassMethod Outbox(caseId As %String, ByRef rows) As %Integer
{
	Kill rows
	Set n = 0
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT commandId, type, status, caseVersionAfter, payloadJson FROM SignalNoir_Application_Model.OutboxRecord WHERE caseId = ? ORDER BY createdAt, commandId", caseId)
	While rs.%Next() {
		Set n = n + 1
		Set rows(n) = $ListBuild(rs.%Get("commandId"), rs.%Get("type"), rs.%Get("status"), rs.%Get("caseVersionAfter"), rs.%Get("payloadJson"))
	}
	Return n
}

ClassMethod Count(sql As %String, arg As %String) As %Integer
{
	Set rs = ##class(%SQL.Statement).%ExecDirect(, sql, arg)
	If rs.%Next() Return +rs.%GetData(1)
	Return -1
}

/// JOB worker for the concurrency tests: waits on the barrier, then tries
/// one transition and records ok or the error code.
ClassMethod RaceTransition(key As %String, caseId As %String, version As %Integer, toState As %String)
{
	For i = 1 : 1 : 500 {
		Quit:$Get(^SignalNoir.TestBarrier(key))
		Hang 0.01
	}
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set r = svc.Transition(caseId, version, toState, "system", ..Ev("race"))
	Set ^SignalNoir.TestRace(key, $JOB) = $Select(r.ok: "ok", 1: r.code)
}

/// JOB worker: reports an Exception after the barrier
ClassMethod RaceException(key As %String, orderId As %String)
{
	For i = 1 : 1 : 500 {
		Quit:$Get(^SignalNoir.TestBarrier(key))
		Hang 0.01
	}
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set r = svc.RecordException(orderId, ..Exception())
	Set ^SignalNoir.TestRace(key, $JOB) = $Select(r.ok: r.ref, 1: "ERR:" _ r.code _ ":" _ r.message)
}

/// JOB worker: appends an Annotation inside an outer transaction and holds
/// the commit for a while (a late confirmation)
ClassMethod SlowAppend(key As %String, caseId As %String, holdSeconds As %Numeric)
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	TSTART
	Set event = ##class(SignalNoir.Core.Dto.TimelineEvent).%New()
	Set event.type = "Annotation"
	Set event.actor = "system"
	Set event.payload = {"note": "late"}
	Set r = svc.Append(caseId, event)
	Set ^SignalNoir.TestRace(key, "appended") = $Select(r.ok: r.obj.seq, 1: "ERR:" _ r.code)
	Hang holdSeconds
	TCOMMIT
	Set ^SignalNoir.TestRace(key, "committed") = 1
}

/// Waits until n results are recorded under key (max ~20s)
ClassMethod WaitResults(key As %String, n As %Integer) As %Integer
{
	For i = 1 : 1 : 2000 {
		Set count = 0
		Set j = ""
		For {
			Set j = $Order(^SignalNoir.TestRace(key, j))
			Quit:j=""
			Set count = count + 1
		}
		If count >= n Return count
		Hang 0.01
	}
	Return count
}

}
