Class SignalNoir.Sim.Scenarios Extends %RegisteredObject
{

/// Scenario instances: create, read, emit, events and scripted triggers
/// (spec US1, US5, US7). Every operation returns a SignalNoir.Sim.Result.
Parameter FAMILIES = "clean,P1,P3,P5,P8,P9,idempotency";

Parameter EVENTS = "PARTNER_DEGRADES,PARTNER_RECOVERS,MAINTENANCE_STARTS,MAINTENANCE_ENDS,ORDER_CANCELLED_AT_ORIGIN";

/// POST /scenarios: 201 ScenarioInstance (details.location), 400, 404
ClassMethod Create(req) As SignalNoir.Sim.Result
{
	If '$IsObject(req) || 'req.%IsA("%DynamicObject") Return ..Invalid("body must be a JSON object")
	If (req.%GetTypeOf("family") '= "string") || '$ListFind($ListFromString(..#FAMILIES), req.family) Return ..Invalid("family must be one of " _ ..#FAMILIES)
	If (req.%GetTypeOf("variant") '= "string") || (req.variant = "") Return ..Invalid("variant is required")
	If (req.%GetTypeOf("seed") '= "number") || (req.seed '? 1.N) Return ..Invalid("seed must be an integer >= 0")
	Set repetition = 1, timeScale = 1, runId = ""
	If req.%IsDefined("repetition") {
		If (req.%GetTypeOf("repetition") '= "number") || (req.repetition '? 1.N) || (req.repetition < 1) Return ..Invalid("repetition must be an integer >= 1")
		Set repetition = req.repetition
	}
	If req.%IsDefined("timeScale") {
		If (req.%GetTypeOf("timeScale") '= "number") || (req.timeScale <= 0) || (req.timeScale > 1) Return ..Invalid("timeScale must be in (0, 1]")
		Set timeScale = req.timeScale
	}
	If req.%IsDefined("runId") && (req.%GetTypeOf("runId") '= "null") {
		If (req.%GetTypeOf("runId") '= "string") || '$Match(req.runId, "^run_[A-Za-z0-9_-]{4,64}$") Return ..Invalid("runId must match run_...")
		Set runId = req.runId
	}
	Set variant = ##class(SignalNoir.Sim.Catalog.Loader).Find(req.family, req.variant)
	If '$IsObject(variant) Return ##class(SignalNoir.Sim.Result).Error("NOT_FOUND", "unknown variant " _ req.family _ "/" _ req.variant)
	Set inst = ##class(SignalNoir.Sim.Model.Instance).%New()
	Set inst.scenarioInstanceId = ##class(SignalNoir.Sim.Ids).NewInstanceId()
	Set inst.family = variant.family, inst.subtype = variant.subtype, inst.variant = variant.variant, inst.variantSet = variant.set
	Set inst.partnerId = variant.partnerId, inst.language = variant.language
	Set inst.seed = req.seed, inst.runId = runId, inst.repetition = repetition, inst.timeScale = timeScale
	Set health = $Select($IsObject(variant.script) && $IsObject(variant.script.health): variant.script.health, 1: {"status": "UP"})
	Set inst.healthJson = {"status": (health.status), "message": (health.message)}.%ToJSON()
	Set inst.createdAt = ##class(SignalNoir.Sim.Clock).NowUtc()
	Set sc = inst.%Save()
	If $$$ISERR(sc) Return ##class(SignalNoir.Sim.Result).Error("INVALID_REQUEST", $System.Status.GetErrorText(sc))
	Set r = ##class(SignalNoir.Sim.Result).Ok(..Json(inst), 201)
	Set r.details = {"location": ("/sim/api/v1/scenarios/" _ inst.scenarioInstanceId)}
	Return r
}

ClassMethod Get(sci As %String) As SignalNoir.Sim.Result
{
	Set inst = ..Load(sci)
	If '$IsObject(inst) Return ..NotFound(sci)
	Return ##class(SignalNoir.Sim.Result).Ok(..Json(inst))
}

/// POST /scenarios/{id}/emissions: 201 the first time, 200 with the same
/// emissions after (FR-011). Content is drawn from (seed, variant), never
/// from the instance id, so the same seed gives the same Orders (FR-006).
ClassMethod Emit(sci As %String) As SignalNoir.Sim.Result
{
	If '$IsObject(..Load(sci)) Return ..NotFound(sci)
	Lock +^SignalNoir.Sim.InstanceLock(sci):10
	If '$Test Return ##class(SignalNoir.Sim.Result).Error("INVALID_REQUEST", "instance busy: " _ sci)
	Try {
		Set inst = ..Load(sci)
		If inst.status = "emitted" {
			Set result = ##class(SignalNoir.Sim.Result).Ok({}.%FromJSON(inst.emissionJson), 200)
			Quit
		}
		Set variant = ##class(SignalNoir.Sim.Catalog.Loader).Find(inst.family, inst.variant)
		Set now = ##class(SignalNoir.Sim.Clock).NowUtc()
		Set templates = $Select($IsObject(variant.orders): variant.orders, 1: [{}])
		Set emitted = [], ids = []
		Kill built
		For i = 0 : 1 : templates.%Size() - 1 {
			Set t = templates.%Get(i), ordinal = i + 1
			If t.%IsDefined("priorOf") Continue
			Set built(ordinal) = ..Build(inst, variant, t, ordinal)
			Set env = ..Publish(inst, built(ordinal), ordinal, now)
			Do emitted.%Push(env), ids.%Push(built(ordinal).orderId)
		}
		; P9: the original of an emitted Order, received before the resend (SIM-Q8)
		For i = 0 : 1 : templates.%Size() - 1 {
			Set t = templates.%Get(i), ordinal = i + 1
			If 't.%IsDefined("priorOf") || '$Data(built(t.priorOf)) Continue
			Do ..SeedPrior(inst, built(t.priorOf), ordinal, ##class(SignalNoir.Sim.Clock).Shift(now, +t.receivedAtOffsetSeconds))
		}
		Set emission = {"scenarioInstanceId": (sci), "emitted": (emitted)}
		Set inst.status = "emitted", inst.emittedOrderIdsJson = ids.%ToJSON(), inst.emissionJson = emission.%ToJSON()
		$$$ThrowOnError(inst.%Save())
		Set result = ##class(SignalNoir.Sim.Result).Ok(emission, 201)
	}
	Catch ex {
		Set result = ##class(SignalNoir.Sim.Result).Error("INVALID_REQUEST", "emission failed: " _ ex.DisplayString())
	}
	Lock -^SignalNoir.Sim.InstanceLock(sci)
	Return result
}

/// POST /scenarios/{id}/events: 202 ScenarioInstance, 400, 404 (FR-027..029)
ClassMethod Event(sci As %String, req) As SignalNoir.Sim.Result
{
	If '$IsObject(req) || 'req.%IsA("%DynamicObject") Return ..Invalid("body must be a JSON object")
	If (req.%GetTypeOf("type") '= "string") || '$ListFind($ListFromString(..#EVENTS), req.type) Return ..Invalid("type must be one of " _ ..#EVENTS)
	If '$IsObject(..Load(sci)) Return ..NotFound(sci)
	Return ..Apply(sci, req.type, req.%Get("orderId"), "explicit")
}

/// Applies a world change to one instance, under its lock
ClassMethod Apply(sci As %String, type As %String, orderId As %String, source As %String) As SignalNoir.Sim.Result
{
	If type = "ORDER_CANCELLED_AT_ORIGIN" {
		If orderId = "" Return ..Invalid("orderId is required for ORDER_CANCELLED_AT_ORIGIN")
		Set order = ##class(SignalNoir.Sim.Model.OriginOrder).%OpenId(orderId)
		If '$IsObject(order) || (order.scenarioInstanceId '= sci) Return ..Invalid("orderId " _ orderId _ " does not belong to " _ sci)
	}
	Lock +^SignalNoir.Sim.InstanceLock(sci):10
	If '$Test Return ##class(SignalNoir.Sim.Result).Error("INVALID_REQUEST", "instance busy: " _ sci)
	Try {
		Set inst = ..Load(sci)
		Set variant = ##class(SignalNoir.Sim.Catalog.Loader).Find(inst.family, inst.variant)
		Set now = ##class(SignalNoir.Sim.Clock).NowUtc()
		Set health = {}.%FromJSON(inst.healthJson)
		Set after = $Select($IsObject(variant.script) && $IsObject(variant.script.afterEvent): variant.script.afterEvent.%Get(type), 1: "")
		If type = "PARTNER_DEGRADES" {
			Set health.status = "DEGRADED", inst.phase = "partner_degraded"
		} ElseIf type = "PARTNER_RECOVERS" {
			Set base = variant.script.health
			Set health.status = $Select($IsObject(base) && (base.status '= "DOWN"): base.status, 1: "UP")
			Set health.message = $Select($IsObject(base): base.message, 1: ""), inst.phase = "partner_recovered"
		} ElseIf type = "MAINTENANCE_STARTS" {
			Set health.maintenance = {"active": true, "startsAt": (now), "endsAt": (##class(SignalNoir.Sim.Clock).Shift(now, 3600))}
			Set inst.phase = "maintenance"
		} ElseIf type = "MAINTENANCE_ENDS" {
			If $IsObject(health.maintenance) Do health.maintenance.%Set("active", 0, "boolean"), health.maintenance.%Set("endsAt", now)
			Set inst.phase = "initial"
		} Else {
			Set order = ##class(SignalNoir.Sim.Model.OriginOrder).%OpenId(orderId)
			Set order.status = "cancelled", order.statusChangedAt = now
			Set order.reason = ##class(SignalNoir.Sim.Catalog.Wording).Body("cancelled-reason", inst.language, inst.seed, inst.variant, 1)
			$$$ThrowOnError(order.%Save())
			Set inst.phase = "order_cancelled"
		}
		If $IsObject(after) {
			If $IsObject(after.health) {
				If after.health.%IsDefined("status") Set health.status = after.health.status
				If after.health.%IsDefined("message") Set health.message = after.health.message
			}
			If $IsObject(after.history) Do ..ThirdParty(inst, after.history, now)
		}
		Set events = [].%FromJSON(inst.appliedEventsJson)
		Do events.%Push({"type": (type), "at": (now)})
		Set inst.appliedEventsJson = events.%ToJSON(), inst.healthJson = health.%ToJSON()
		$$$ThrowOnError(inst.%Save())
		Set result = ##class(SignalNoir.Sim.Result).Ok(..Json(inst), 202)
	}
	Catch ex {
		Set result = ##class(SignalNoir.Sim.Result).Error("INVALID_REQUEST", "event failed: " _ ex.DisplayString())
	}
	Lock -^SignalNoir.Sim.InstanceLock(sci)
	Return result
}

/// Counts a read (read:health, read:history, read:originStatus) or an
/// attempt, and fires the variant's trigger for that count, once (D12)
ClassMethod Touch(sci As %String, on As %String)
{
	Set inst = ..Load(sci)
	If '$IsObject(inst) Quit
	Set count = $Increment(^SignalNoir.Sim.Counter(sci, "on", on))
	Set variant = ##class(SignalNoir.Sim.Catalog.Loader).Find(inst.family, inst.variant)
	If '$IsObject(variant.script) || '$IsObject(variant.script.triggers) Quit
	For i = 0 : 1 : variant.script.triggers.%Size() - 1 {
		Set t = variant.script.triggers.%Get(i)
		If (t.on '= on) || (+t.nth '= count) Continue
		Set orderId = ""
		If t.%IsDefined("orderOrdinal") Set orderId = ##class(SignalNoir.Sim.Ids).OrderId(sci, t.orderOrdinal)
		Do ..Apply(sci, t.event, orderId, "trigger")
	}
}

/// The contract's ScenarioInstance
ClassMethod Json(inst As SignalNoir.Sim.Model.Instance) As %DynamicObject
{
	Set out = {"scenarioInstanceId": (inst.scenarioInstanceId), "family": (inst.family), "subtype": (inst.subtype), "variant": (inst.variant), "set": (inst.variantSet)}
	Do out.%Set("seed", inst.seed, "number")
	Do out.%Set("runId", inst.runId, $Select(inst.runId = "": "null", 1: "string"))
	Do out.%Set("repetition", inst.repetition, "number")
	Set out.partnerId = inst.partnerId
	Do out.%Set("timeScale", +inst.timeScale, "number")
	Set out.status = inst.status, out.phase = inst.phase
	Set out.appliedEvents = [].%FromJSON(inst.appliedEventsJson), out.emittedOrderIds = [].%FromJSON(inst.emittedOrderIdsJson)
	Set out.createdAt = inst.createdAt
	Return out
}

ClassMethod Load(sci As %String) As SignalNoir.Sim.Model.Instance
{
	If (sci = "") || '##class(SignalNoir.Sim.Model.Instance).%ExistsId(sci) Return ""
	Set inst = ##class(SignalNoir.Sim.Model.Instance).%OpenId(sci)
	Do inst.%Reload()
	Return inst
}

/// One synthetic Order of a template, drawn from (seed, variant, ordinal)
ClassMethod Build(inst As SignalNoir.Sim.Model.Instance, variant As %DynamicObject, t As %DynamicObject, ordinal As %Integer) As %DynamicObject
{
	Set P = "SignalNoir.Sim.Prng", seed = inst.seed, v = inst.variant
	Set exams = []
	Set codes = $Select($IsObject(t.exams): t.exams, 1: ["HEMO"])
	For i = 0 : 1 : codes.%Size() - 1 Do exams.%Push({"code": (codes.%Get(i))})
	Set day = $ClassMethod(P, "Range", 20, 27, seed, v, "day", ordinal)
	Set hour = $ClassMethod(P, "Range", 6, 10, seed, v, "hour", ordinal), minute = $ClassMethod(P, "Range", 0, 59, seed, v, "minute", ordinal)
	Set collected = "2026-10-" _ day _ "T" _ $Translate($Justify(hour, 2), " ", "0") _ ":" _ $Translate($Justify(minute, 2), " ", "0") _ ":00-03:00"
	Set requested = "2026-10-" _ day _ "T" _ $Translate($Justify(hour, 2), " ", "0") _ ":" _ $Translate($Justify((minute + 5) # 60, 2), " ", "0") _ ":00-03:00"
	Set specimen = {"specimenId": ("SP-" _ $ClassMethod(P, "Range", 10000, 99999, seed, v, "specimen", ordinal)), "collectedAt": (collected)}
	If $IsObject(t.specimen) {
		If t.specimen.%IsDefined("type") Set specimen.type = t.specimen.type
		If t.specimen.%IsDefined("unit") Set specimen.unit = t.specimen.unit
	}
	Set patient = {"patientId": ("SYN-PAT-" _ $ClassMethod(P, "Range", 100000, 999999, seed, v, "patient", ordinal)), "name": ($ClassMethod(P, "Pick", ["Ana Sintética", "Bruno Fictício", "Carla Modelo", "Davi Exemplo", "Eva Teste"], seed, v, "name", ordinal)), "birthDate": ("19" _ $ClassMethod(P, "Range", 50, 99, seed, v, "birth", ordinal) _ "-0" _ $ClassMethod(P, "Range", 1, 9, seed, v, "month", ordinal) _ "-1" _ $ClassMethod(P, "Range", 0, 9, seed, v, "dom", ordinal)), "sex": ($ClassMethod(P, "Pick", ["F", "M"], seed, v, "sex", ordinal))}
	Set order = {"orderId": (##class(SignalNoir.Sim.Ids).OrderId(inst.scenarioInstanceId, ordinal)), "partnerId": (variant.partnerId), "originUnit": ($ClassMethod(P, "Pick", ["UNIT-NORTE", "UNIT-SUL", "UNIT-CENTRO"], seed, v, "unit", ordinal)), "patient": (patient), "exams": (exams), "specimen": (specimen), "requestedAt": (requested)}
	Set notes = $Select(t.%IsDefined("notes"): ##class(SignalNoir.Sim.Catalog.Wording).Body(t.notes, inst.language, seed, v, ordinal), 1: $ClassMethod(P, "Pick", ["Coleta de rotina.", "Routine morning collection.", "Paciente em jejum."], seed, v, "notes", ordinal))
	If notes '= "" Set order.notes = notes
	Do order.%Set("synthetic", 1, "boolean")
	Return order
}

/// Stores an emitted Order and publishes it in the feed; returns its OrderEnvelope
ClassMethod Publish(inst As SignalNoir.Sim.Model.Instance, order As %DynamicObject, ordinal As %Integer, now As %String) As %DynamicObject
{
	Set row = ##class(SignalNoir.Sim.Model.OriginOrder).%New()
	Set row.orderId = order.orderId, row.scenarioInstanceId = inst.scenarioInstanceId, row.patientId = order.patient.patientId
	Set row.transactionId = ##class(SignalNoir.Sim.Ids).TransactionId(inst.scenarioInstanceId, ordinal), row.ordinal = ordinal
	Set row.orderJson = order.%ToJSON(), row.inFeed = 1, row.emittedAt = now
	$$$ThrowOnError(row.%Save())
	Set item = ##class(SignalNoir.Sim.Model.FeedItem).%New()
	Set item.feedSeq = $Increment(^SignalNoir.Sim.FeedSeq)
	Set item.scenarioInstanceId = inst.scenarioInstanceId, item.runId = inst.runId, item.repetition = inst.repetition
	Set item.transactionId = row.transactionId, item.emittedAt = now, item.orderJson = row.orderJson
	$$$ThrowOnError(item.%Save())
	Return ##class(SignalNoir.Sim.Origin).Envelope(item)
}

/// P9: the original Order (same patient, exams and specimen, its own ids),
/// in the Origin history only, with its receipt at the Partner
ClassMethod SeedPrior(inst As SignalNoir.Sim.Model.Instance, resend As %DynamicObject, ordinal As %Integer, at As %String)
{
	Set sci = inst.scenarioInstanceId
	Set original = {}.%FromJSON(resend.%ToJSON())
	Set original.orderId = ##class(SignalNoir.Sim.Ids).OrderId(sci, ordinal)
	Set row = ##class(SignalNoir.Sim.Model.OriginOrder).%New()
	Set row.orderId = original.orderId, row.scenarioInstanceId = sci, row.patientId = original.patient.patientId
	Set row.transactionId = ##class(SignalNoir.Sim.Ids).TransactionId(sci, ordinal), row.ordinal = ordinal
	Set row.orderJson = original.%ToJSON(), row.inFeed = 0, row.emittedAt = ##class(SignalNoir.Sim.Clock).Shift(at, -60)
	$$$ThrowOnError(row.%Save())
	Set rcp = ##class(SignalNoir.Sim.Model.Receipt).%New()
	Set rcp.receiptId = ##class(SignalNoir.Sim.Ids).ReceiptId(sci, $Increment(^SignalNoir.Sim.Counter(sci, "receipt")))
	Set rcp.idempotencyKey = "idk_prior_" _ $Extract(sci, 5, *) _ "_" _ ordinal
	Set rcp.orderId = original.orderId, rcp.scenarioInstanceId = sci, rcp.patientId = original.patient.patientId
	Set rcp.partnerId = inst.partnerId, rcp.transactionId = row.transactionId, rcp.receivedAt = at
	Set rcp.orderSnapshotJson = original.%ToJSON(), rcp.payloadCanon = ##class(SignalNoir.Sim.Canon).Payload(original)
	$$$ThrowOnError(rcp.%Save())
}

/// Third-party traffic an event writes in the history (no order fields)
ClassMethod ThirdParty(inst As SignalNoir.Sim.Model.Instance, entries As %DynamicArray, now As %String) [ Private ]
{
	For i = 0 : 1 : entries.%Size() - 1 {
		Set e = entries.%Get(i)
		Set row = ##class(SignalNoir.Sim.Model.Delivery).%New()
		Set row.scenarioInstanceId = inst.scenarioInstanceId, row.partnerId = inst.partnerId
		Set row.httpStatus = $Select(e.%GetTypeOf("httpStatus") = "number": e.httpStatus, 1: "")
		Set row.outcome = e.outcome, row.latencyMs = +e.latencyMs, row.loggedAt = now
		Set row.message = ##class(SignalNoir.Sim.Catalog.Wording).Body(e.message, inst.language, inst.seed, inst.variant, i + 1)
		$$$ThrowOnError(row.%Save())
	}
}

ClassMethod Invalid(message As %String) As SignalNoir.Sim.Result [ Private ]
{
	Return ##class(SignalNoir.Sim.Result).Error("INVALID_REQUEST", message)
}

ClassMethod NotFound(sci As %String) As SignalNoir.Sim.Result [ Private ]
{
	Return ##class(SignalNoir.Sim.Result).Error("NOT_FOUND", "scenario instance not found: " _ sci)
}

}
