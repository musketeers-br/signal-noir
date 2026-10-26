Class SignalNoir.Tools.LocalSource Extends SignalNoir.Core.Port.EvidenceSource
{

/// Reading Tools served from the product itself: the Order timeline from the
/// Case store, and the versioned reference data (policies, mapping catalog)
/// owned by feature 004. Until 004 is integrated the reference data is
/// reported as absent, never invented.
Method Read(toolName As %String, args As %DynamicObject) As SignalNoir.Core.Result
{
	If toolName = "tool.order_timeline" Return ..OrderTimeline(args.%Get("caseId"))
	If (toolName = "tool.policies") || (toolName = "tool.mapping_catalog") {
		Return ##class(SignalNoir.Core.Result).OkObj({"available": false, "reason": "reference data not loaded (feature 004)"})
	}
	Return ##class(SignalNoir.Core.Result).OkObj({"available": false, "reason": ("no local source for " _ toolName)})
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
