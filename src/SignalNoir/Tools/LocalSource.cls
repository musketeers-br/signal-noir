Class SignalNoir.Tools.LocalSource Extends SignalNoir.Core.Port.EvidenceSource
{

/// Reading Tools served from the product itself: the Order timeline from the
/// Case store, and the versioned reference data (policies, mapping catalog)
/// owned by feature 004, from the same snapshot the Validator uses for the Case.
/// With no reference data loaded they report an absence, never an invented value.
Method Read(toolName As %String, args As %DynamicObject) As SignalNoir.Core.Result
{
	If toolName = "tool.order_timeline" Return ..OrderTimeline(args.%Get("caseId"))
	If (toolName = "tool.policies") || (toolName = "tool.mapping_catalog") Return ..ReferenceData(toolName, args.%Get("caseId"))
	Return ##class(SignalNoir.Core.Result).OkObj({"available": false, "reason": ("no local source for " _ toolName)})
}

/// tool.policies: the policy document and its version. tool.mapping_catalog: the Mappings with
/// their conditions, the specimen synonyms and the Mapping version (contracts/validation-input.md).
/// The run of the Case decides which versions: its pinned ones inside a BenchmarkRun, else the
/// ones in force.
Method ReferenceData(toolName As %String, caseId As %String) As SignalNoir.Core.Result [ Private ]
{
	Set rec = $Select(caseId '= "": ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(caseId), 1: "")
	Set snapshot = ##class(SignalNoir.Application.Reference.Store).For(##class(SignalNoir.Application.ResolutionValidator).RunFor(rec))
	If 'snapshot.ok Return ##class(SignalNoir.Core.Result).OkObj({"available": false, "reason": ("reference data not loaded: " _ snapshot.message)})
	Set data = snapshot.obj
	If toolName = "tool.mapping_catalog" {
		Return ##class(SignalNoir.Core.Result).OkObj({"available": true, "result": {"mappingVersion": (data.mappingVersion), "items": (data.mappings), "synonyms": (data.synonyms)}})
	}
	Set policies = {"policyVersion": (data.policyVersion)}
	Set each = data.policies.%GetIterator()
	While each.%GetNext(.key, .value) {
		Do policies.%Set(key, value)
	}
	Return ##class(SignalNoir.Core.Result).OkObj({"available": true, "result": (policies)})
}

Method OrderTimeline(caseId As %String) As SignalNoir.Core.Result [ Private ]
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set g = svc.GetCase(caseId)
	If 'g.ok Return ##class(SignalNoir.Core.Result).OkObj({"available": false, "reason": (g.message)})
	Set t = svc.GetTimeline(caseId, 0, 500)
	Set events = []
	For i = 1 : 1 : t.list.Count() {
		Set ev = t.list.GetAt(i)
		Do events.%Push({"seq": (+ev.seq), "at": (ev.at), "type": (ev.type), "actor": (ev.actor)})
	}
	Set order = $Select($IsObject(g.obj.order): g.obj.order.snapshot, 1: {})
	Return ##class(SignalNoir.Core.Result).OkObj({"available": true, "result": {"order": (order), "events": (events)}})
}

}
