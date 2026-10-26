Class SignalNoir.Tests.Fakes.ScriptedSource Extends SignalNoir.Core.Port.EvidenceSource
{

/// Test-only EvidenceSource: canned Simulator/reference answers, overridable
/// per Case and Tool in ^SignalNoir.TestScript(caseId, "source", tool)
/// (JSON result, or "absent:<reason>"). Counts reads per Case so a test can
/// prove a refused call never reached the source.
Method Read(toolName As %String, args As %DynamicObject) As SignalNoir.Core.Result
{
	Set caseId = args.%Get("caseId")
	Set reads = $Increment(^SignalNoir.TestScript(caseId, "reads"))
	Set ^SignalNoir.TestScript(caseId, "read", reads) = toolName
	; record-first probe: how many Evidence rows exist for this Case right now
	Set ^SignalNoir.TestScript(caseId, "evidenceAtRead", reads) = ##class(SignalNoir.Tests.Support).Count("SELECT COUNT(*) FROM SignalNoir_Application_Model.EvidenceRecord WHERE caseId = ?", caseId)
	Set scripted = $Get(^SignalNoir.TestScript(caseId, "source", toolName))
	If $Extract(scripted, 1, 7) = "absent:" Return ##class(SignalNoir.Core.Result).OkObj({"available": false, "reason": ($Extract(scripted, 8, *))})
	If scripted '= "" Return ##class(SignalNoir.Core.Result).OkObj({"available": true, "result": ({}.%FromJSON(scripted))})
	Return ##class(SignalNoir.Core.Result).OkObj({"available": true, "result": (..Default(toolName))})
}

ClassMethod Default(toolName As %String) As %DynamicAbstractObject
{
	If toolName = "tool.partner_health" Return {"partnerId": "partner-a", "status": "UP", "message": "all systems nominal", "checkedAt": "2026-10-25T10:00:00Z"}
	If toolName = "tool.partner_failure_history" Return {"partnerId": "partner-a", "window": {"since": "2026-10-25T09:55:00Z", "until": "2026-10-25T10:00:00Z", "total": 3, "delivered": 2, "errors": 1, "timeouts": 0, "errorRate": 0.33}, "items": [{"at": "2026-10-25T09:59:00Z", "httpStatus": 500, "outcome": "rejected", "message": "validation error: unknown exam code GLIC-J"}]}
	If toolName = "tool.origin_order_status" Return {"status": "ACTIVE"}
	If toolName = "tool.policies" Return {"version": "pol-2026.10.1", "items": []}
	If toolName = "tool.mapping_catalog" Return {}.%FromJSON(##class(SignalNoir.Tests.Fakes.ScriptedSource).Catalog())
	If toolName = "tool.order_timeline" Return {"events": []}
	Return {}
}

ClassMethod Catalog() As %String
{
	Return "{""mappingVersion"":""2026.10.1"",""items"":[{""mappingId"":""map_glicj_plasma"",""mappingVersion"":""2026.10.1"",""sourceCode"":""GLIC-J"",""targetCode"":""GLIC-P"",""conditions"":{""specimenType"":""PLASMA""}},{""mappingId"":""map_glicj_soro"",""mappingVersion"":""2026.10.1"",""sourceCode"":""GLIC-J"",""targetCode"":""GLIC-S"",""conditions"":{""specimenType"":""SERUM""}}]}"
}

}
