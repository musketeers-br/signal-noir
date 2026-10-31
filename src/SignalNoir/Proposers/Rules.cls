Class SignalNoir.Proposers.Rules Extends SignalNoir.Core.Port.Proposer
{

/// Rules Mode: a deterministic proposer over the same Evidence, gateway and
/// budget as the Agent (Constitution VIII). Minimal rule set for the shared
/// path; the strengthened baseline is written on this port in wave 4.
/// 1. recorded patient records collide with the Order's patient -> REQUEST_REVIEW
/// 2. Partner DOWN, or >= 50% errors/timeouts in the window -> HOLD
/// 3. exactly one approved mapping matches an exam code and the specimen
///    type of the Order -> APPLY_APPROVED_MAPPING
/// 4. otherwise -> REQUEST_REVIEW
/// The base package spends the whole budget, so Rules reads only it.
Parameter VERSION = "rules-v1";

Method Propose(context As SignalNoir.Core.Dto.InvestigationContext) As SignalNoir.Core.Result
{
	Set evidence = ##class(%ListOfObjects).%New()
	For i = 1 : 1 : context.evidence.Count() Do evidence.Insert(context.evidence.GetAt(i))
	Set (health, history, catalog, exception, receipts) = ""
	For i = 1 : 1 : evidence.Count() {
		Set ev = evidence.GetAt(i)
		If ev.source = "tool.partner_health" Set health = ev
		If ev.source = "tool.partner_failure_history" Set history = ev
		If ev.source = "tool.mapping_catalog" Set catalog = ev
		If (ev.source = "system.exception") && (exception = "") Set exception = ev
		If ev.source = "tool.receipts_and_orders_by_patient" Set receipts = ev
	}
	Set details = {"provider": "rules", "model": (..#VERSION), "promptVersion": (..#VERSION)}
	; 1. ambiguous identity: never act automatically
	Set order = $Select($IsObject(context.order) && $IsObject(context.order.snapshot): context.order.snapshot, 1: {})
	If ##class(SignalNoir.Core.Identity).Collisions(evidence, order).%Size() > 0 {
		Set cite = [(receipts.evidenceId)]
		Return ..Answer("REQUEST_REVIEW", {"reason": "ambiguous identity"}, "LOW", "More than one patient record matches this order", "Recorded patient records share the name but differ in identity", cite, [], details)
	}
	; 2. unstable partner
	Set unstable = 0, cite = []
	If ..IsFact(health) && (health.result.status = "DOWN") Set unstable = 1 Do cite.%Push(health.evidenceId)
	If ..IsFact(history) && $IsObject(history.result.window) && (history.result.window.errorRate >= 0.5) && (history.result.window.total > 0) Set unstable = 1 Do cite.%Push(history.evidenceId)
	If unstable {
		Return ..Answer("HOLD", {"reason": "partner unstable"}, "MEDIUM", "The partner is unstable; hold until it recovers", "Partner health or recent history shows instability", cite, [{"check": "PARTNER_HEALTHY_WINDOW", "expected": false}], details)
	}
	; 3. exactly one applicable approved mapping
	If ..IsFact(catalog) && $IsObject(context.order) && $IsObject(context.order.snapshot) {
		Set matches = ##class(SignalNoir.Core.MappingMatch).Candidates(context.order.snapshot, catalog.result.items)
		If matches.%Size() = 1 {
			Set m = matches.%Get(0)
			Set cite = [(catalog.evidenceId)]
			If ..IsFact(exception) Do cite.%Push(exception.evidenceId)
			Return ..Answer("APPLY_APPROVED_MAPPING", {"mappingId": (m.mappingId), "mappingVersion": (m.mappingVersion)}, "MEDIUM", "One approved mapping matches the Order's exam and specimen", "Mapping " _ m.mappingId _ " applies to this Order", cite, [{"check": "MAPPING_VERSION_UNCHANGED", "expected": (m.mappingVersion)}], details)
		}
	}
	; 4. no safe rule applies
	Set cite = []
	If exception '= "" Do cite.%Push(exception.evidenceId)
	Return ..Answer("REQUEST_REVIEW", {"reason": "no rule applies"}, "LOW", "No deterministic rule identifies a safe Action", "The failure is recorded but no rule matches it", cite, [], details)
}

ClassMethod Answer(action, params, confidence, summary, claim, cite As %DynamicArray, preconditions, details) As SignalNoir.Core.Result [ Private ]
{
	Set answer = {"diagnosis": {"summary": (summary), "claims": [{"text": (claim), "evidenceIds": (cite)}], "hypotheses": [{"text": (summary), "status": "chosen"}]}, "action": (action), "params": (params), "confidence": (confidence), "preconditions": (preconditions)}
	Set r = ##class(SignalNoir.Core.Result).OkObj(answer)
	Set r.details = details
	Return r
}

ClassMethod IsFact(ev) As %Boolean [ Private ]
{
	Return ($IsObject(ev) && (ev.kind = "fact") && $IsObject(ev.result) && ev.result.%IsA("%DynamicObject"))
}

}
