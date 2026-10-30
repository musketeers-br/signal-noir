Class SignalNoir.Sim.Partner Extends %RegisteredObject
{

/// The simulated Partner: one Attempt per delivery, deduplicated atomically
/// before the script (research D5), answered as the script declares
/// (FR-015..021); health and history per instance (FR-025, FR-026).
/// Result.obj of Deliver: {status (number or "none"), body (object, text or
/// ""), replayed, hold (seconds)}.
ClassMethod Deliver(partnerId As %String, req) As SignalNoir.Sim.Result
{
	Set why = ..Check(req)
	If why '= "" Return ##class(SignalNoir.Sim.Result).Error("INVALID_REQUEST", why)
	Set sci = req.scenarioInstanceId
	Set inst = ##class(SignalNoir.Sim.Scenarios).Load(sci)
	If '$IsObject(inst) Return ##class(SignalNoir.Sim.Result).Error("NOT_FOUND", "scenario instance not found: " _ sci)
	If inst.partnerId '= partnerId Return ##class(SignalNoir.Sim.Result).Error("NOT_FOUND", "partner " _ partnerId _ " is not the partner of " _ sci)
	Set key = req.idempotencyKey, order = req.order
	Set canon = ##class(SignalNoir.Sim.Canon).Payload(order)
	Lock +^SignalNoir.Sim.Key(key):30
	If '$Test Return ##class(SignalNoir.Sim.Result).Error("INVALID_REQUEST", "idempotency key busy: " _ key)
	Try {
		Set now = ##class(SignalNoir.Sim.Clock).NowUtc()
		Set existing = ..ReceiptOf(key)
		If $IsObject(existing) {
			If existing.payloadCanon '= canon {
				Set result = ##class(SignalNoir.Sim.Result).Error("IDEMPOTENCY_KEY_REUSED", "idempotencyKey already used with a different payload", {"idempotencyKey": (key), "originalReceiptId": (existing.receiptId)})
				Quit
			}
			Do ..Log(inst, req, "", 200, "duplicate", 0, "duplicate delivery; original receipt " _ existing.receiptId, now)
			Set result = ##class(SignalNoir.Sim.Result).Ok({"status": 200, "body": (##class(SignalNoir.Sim.Receipts).Json(existing, 0)), "replayed": 1, "hold": 0})
			Quit
		}
		Set attempt = $Increment(^SignalNoir.Sim.Counter(sci, "attempt", order.orderId))
		Do ##class(SignalNoir.Sim.Scenarios).Touch(sci, "attempt")
		Set inst = ##class(SignalNoir.Sim.Scenarios).Load(sci)
		Set variant = ##class(SignalNoir.Sim.Catalog.Loader).Find(inst.family, inst.variant)
		Set rule = ##class(SignalNoir.Sim.Script).Match(variant, attempt, order, ##class(SignalNoir.Sim.Script).Active([].%FromJSON(inst.appliedEventsJson)))
		Set hold = ##class(SignalNoir.Sim.Script).Hold($Select(rule.lose: "timeout", 1: rule.delay), inst.timeScale)
		Set status = rule.status, body = ""
		If rule.receipt {
			Set rcp = ..Record(inst, req, canon, now)
			Set body = ##class(SignalNoir.Sim.Receipts).Json(rcp, 0)
			Set message = "accepted; receipt " _ rcp.receiptId
		} Else {
			Set vars = {"code": (order.exams.%Get(0).code), "orderId": (order.orderId), "patientId": ($Select($IsObject(order.patient): order.patient.patientId, 1: "")), "priorReceiptId": ("rcp_" _ $Extract(sci, 5, *) _ "_0"), "specimen": ($Select($IsObject(order.specimen): order.specimen.type, 1: ""))}
			Set body = ##class(SignalNoir.Sim.Catalog.Wording).Body(rule.body, inst.language, inst.seed, inst.variant, attempt, vars)
			Set message = $Select(status = "none": "no response before the client timeout", body = "": "status " _ status _ " without a body", 1: ##class(SignalNoir.Sim.Catalog.Wording).Log(body))
		}
		Do ..Log(inst, req, attempt, status, ..Outcome(status, rule.receipt), hold * 1000 \ 1, message, now)
		Set result = ##class(SignalNoir.Sim.Result).Ok({"status": (status), "body": (body), "replayed": 0, "hold": (hold)})
	}
	Catch ex {
		Set result = ##class(SignalNoir.Sim.Result).Error("INVALID_REQUEST", "delivery failed: " _ ex.DisplayString())
	}
	Lock -^SignalNoir.Sim.Key(key)
	Return result
}

/// GET /partners/{partnerId}/health (what the Partner says, FR-025)
ClassMethod Health(partnerId As %String, sci As %String) As SignalNoir.Sim.Result
{
	Set found = ..Find(partnerId, sci)
	If 'found.ok Return found
	Do ##class(SignalNoir.Sim.Scenarios).Touch(sci, "read:health")
	Set inst = ##class(SignalNoir.Sim.Scenarios).Load(sci)
	Set h = {}.%FromJSON(inst.healthJson)
	Set out = {"partnerId": (partnerId), "scenarioInstanceId": (sci), "status": (h.status)}
	If h.message '= "" Set out.message = h.message
	If $IsObject(h.maintenance) {
		Set out.maintenance = h.maintenance
	} Else {
		Do out.%Set("maintenance", "", "null")
	}
	Set out.checkedAt = ##class(SignalNoir.Sim.Clock).NowUtc()
	Return ##class(SignalNoir.Sim.Result).Ok(out)
}

/// GET /partners/{partnerId}/history (what happened, FR-026)
ClassMethod History(partnerId As %String, sci As %String, orderId As %String, since As %String, limit As %Integer) As SignalNoir.Sim.Result
{
	Set found = ..Find(partnerId, sci)
	If 'found.ok Return found
	Do ##class(SignalNoir.Sim.Scenarios).Touch(sci, "read:history")
	Set now = ##class(SignalNoir.Sim.Clock).NowUtc()
	If since = "" Set since = ##class(SignalNoir.Sim.Clock).Shift(now, -300)
	Set sinceSecs = ##class(SignalNoir.Sim.Clock).Seconds(since)
	Set items = [], total = 0, delivered = 0, errors = 0, timeouts = 0
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM SignalNoir_Sim_Model.Delivery WHERE scenarioInstanceId = ? ORDER BY ID DESC", sci)
	While rs.%Next() {
		Set row = ##class(SignalNoir.Sim.Model.Delivery).%OpenId(rs.%Get("ID"))
		If (orderId '= "") && (row.orderId '= orderId) Continue
		If ##class(SignalNoir.Sim.Clock).Seconds(row.loggedAt) < sinceSecs Continue
		Set total = total + 1
		If (row.outcome = "delivered") || (row.outcome = "duplicate") {
			Set delivered = delivered + 1
		} ElseIf row.outcome = "timeout" {
			Set timeouts = timeouts + 1
		} Else {
			Set errors = errors + 1
		}
		If items.%Size() < limit Do items.%Push(..Entry(row))
	}
	Set window = {"since": (since), "until": (now), "total": (total), "delivered": (delivered), "errors": (errors), "timeouts": (timeouts)}
	Do window.%Set("errorRate", $Select(total = 0: 0, 1: $Normalize((errors + timeouts) / total, 4)), "number")
	Return ##class(SignalNoir.Sim.Result).Ok({"partnerId": (partnerId), "scenarioInstanceId": (sci), "window": (window), "items": (items), "serverTime": (now)})
}

/// The instance of a partner read, or NOT_FOUND
ClassMethod Find(partnerId As %String, sci As %String) As SignalNoir.Sim.Result [ Private ]
{
	Set inst = ##class(SignalNoir.Sim.Scenarios).Load(sci)
	If '$IsObject(inst) Return ##class(SignalNoir.Sim.Result).Error("NOT_FOUND", "scenario instance not found: " _ sci)
	If inst.partnerId '= partnerId Return ##class(SignalNoir.Sim.Result).Error("NOT_FOUND", "partner " _ partnerId _ " is not the partner of " _ sci)
	Return ##class(SignalNoir.Sim.Result).Ok({})
}

/// "" when the DeliveryRequest is well formed, else why not
ClassMethod Check(req) As %String [ Private ]
{
	If '$IsObject(req) || 'req.%IsA("%DynamicObject") Return "body must be a JSON object"
	If (req.%GetTypeOf("idempotencyKey") '= "string") || ($Length(req.idempotencyKey) < 8) || ($Length(req.idempotencyKey) > 128) Return "idempotencyKey must have 8 to 128 characters"
	If (req.%GetTypeOf("transactionId") '= "string") || (req.transactionId = "") Return "transactionId is required"
	If (req.%GetTypeOf("scenarioInstanceId") '= "string") || '$Match(req.scenarioInstanceId, "^sci_[A-Za-z0-9_-]{4,64}$") Return "scenarioInstanceId is required"
	If req.%IsDefined("runId") && (req.%GetTypeOf("runId") '= "null") && ((req.%GetTypeOf("runId") '= "string") || '$Match(req.runId, "^run_[A-Za-z0-9_-]{4,64}$")) Return "runId must match run_..."
	Set o = req.%Get("order")
	If '$IsObject(o) || 'o.%IsA("%DynamicObject") Return "order is required"
	For f = "orderId", "partnerId", "requestedAt" If (o.%GetTypeOf(f) '= "string") || (o.%Get(f) = "") Return "order." _ f _ " is required"
	If '$IsObject(o.patient) || (o.patient.%GetTypeOf("patientId") '= "string") Return "order.patient.patientId is required"
	If '$IsObject(o.exams) || 'o.exams.%IsA("%DynamicArray") || (o.exams.%Size() = 0) Return "order.exams needs at least one exam"
	For i = 0 : 1 : o.exams.%Size() - 1 If '$IsObject(o.exams.%Get(i)) || (o.exams.%Get(i).%GetTypeOf("code") '= "string") Return "order.exams[].code is required"
	If '$IsObject(o.specimen) || (o.specimen.%GetTypeOf("specimenId") '= "string") || (o.specimen.%GetTypeOf("collectedAt") '= "string") Return "order.specimen needs specimenId and collectedAt"
	If (o.%GetTypeOf("synthetic") '= "boolean") || 'o.synthetic Return "order.synthetic must be true"
	Return ""
}

ClassMethod ReceiptOf(key As %String) As SignalNoir.Sim.Model.Receipt [ Private ]
{
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT receiptId FROM SignalNoir_Sim_Model.Receipt WHERE idempotencyKey = ?", key)
	Return $Select(rs.%Next(): ##class(SignalNoir.Sim.Model.Receipt).%OpenId(rs.%Get("receiptId")), 1: "")
}

ClassMethod Record(inst As SignalNoir.Sim.Model.Instance, req As %DynamicObject, canon As %String, now As %String) As SignalNoir.Sim.Model.Receipt [ Private ]
{
	Set sci = inst.scenarioInstanceId
	Set rcp = ##class(SignalNoir.Sim.Model.Receipt).%New()
	Set rcp.receiptId = ##class(SignalNoir.Sim.Ids).ReceiptId(sci, $Increment(^SignalNoir.Sim.Counter(sci, "receipt")))
	Set rcp.idempotencyKey = req.idempotencyKey, rcp.orderId = req.order.orderId, rcp.scenarioInstanceId = sci
	Set rcp.patientId = $ZStrip(req.order.patient.patientId, "<>W"), rcp.partnerId = inst.partnerId
	Set rcp.transactionId = req.transactionId, rcp.receivedAt = now
	Set rcp.orderSnapshotJson = req.order.%ToJSON(), rcp.payloadCanon = canon
	$$$ThrowOnError(rcp.%Save())
	Return rcp
}

ClassMethod Log(inst, req As %DynamicObject, attempt, status, outcome As %String, latencyMs As %Integer, message As %String, now As %String) [ Private ]
{
	Set row = ##class(SignalNoir.Sim.Model.Delivery).%New()
	Set row.scenarioInstanceId = inst.scenarioInstanceId, row.partnerId = inst.partnerId
	Set row.orderId = req.order.orderId, row.transactionId = req.transactionId, row.idempotencyKey = req.idempotencyKey
	Set row.attempt = attempt, row.httpStatus = $Select(status = "none": "", 1: status)
	Set row.outcome = outcome, row.latencyMs = latencyMs, row.message = $Extract(message, 1, 4000), row.loggedAt = now
	$$$ThrowOnError(row.%Save())
}

ClassMethod Outcome(status, receipt As %Boolean) As %String [ Private ]
{
	If status = "none" Return "timeout"
	If receipt Return "delivered"
	If status = 503 Return "unavailable"
	If status >= 500 Return "error"
	Return "rejected"
}

/// A history item (PartnerLogEntry)
ClassMethod Entry(row As SignalNoir.Sim.Model.Delivery) As %DynamicObject [ Private ]
{
	Set e = {"at": (row.loggedAt)}
	For f = "orderId", "transactionId", "idempotencyKey" If $Property(row, f) '= "" Do e.%Set(f, $Property(row, f))
	Do e.%Set("httpStatus", row.httpStatus, $Select(row.httpStatus = "": "null", 1: "number"))
	Set e.outcome = row.outcome
	Do e.%Set("latencyMs", +row.latencyMs, "number")
	Set e.message = row.message
	Return e
}

}
