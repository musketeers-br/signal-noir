Class SignalNoir.Application.ToolGateway Extends SignalNoir.Core.Port.Tools
{

/// The single Tools entry point of an Investigation (006 FR-007 to FR-011).
/// Read-only by construction: only Core.ToolCatalog's reading Tools pass.
/// Each call is charged against the server-side budget before any source is
/// read, read outside any transaction, scanned for embedded instructions,
/// and recorded as Evidence before its result is returned.
Property Service As SignalNoir.Application.CaseService;

Property InvestigationId As %String;

/// Actor recorded as Evidence.calledBy (system for the base package, then
/// the proposer's mode)
Property Caller As %String [ InitialExpression = "system" ];

Property Source As SignalNoir.Core.Port.EvidenceSource;

/// Defaults merged into every call's arguments (orderId, partnerId,
/// scenarioInstanceId, patientId, caseId)
Property Defaults As %DynamicObject;

Method Invoke(toolName As %String, args As %DynamicObject) As SignalNoir.Core.Result
{
	If '##class(SignalNoir.Core.ToolCatalog).IsReadTool(toolName) {
		Do ..Service.RecordBlockedTool(..InvestigationId, toolName, ..Caller)
		Return ##class(SignalNoir.Core.Result).Error("VALIDATION_FAILED", "not a reading tool: " _ toolName)
	}
	Set charged = ..Service.ChargeToolCall(..InvestigationId)
	If 'charged.ok Return charged
	Set params = {}
	If $IsObject(..Defaults) {
		Set it = ..Defaults.%GetIterator()
		While it.%GetNext(.k, .v) {
			Do params.%Set(k, v)
		}
	}
	If $IsObject(args) {
		Set it = args.%GetIterator()
		While it.%GetNext(.k, .v) {
			Do params.%Set(k, v)
		}
	}
	Set started = $ZHorolog
	Set read = ""
	Try {
		Set read = ..Source.Read(toolName, params)
	}
	Catch ex {
		Set read = ##class(SignalNoir.Core.Result).Error("", "source failed: " _ ex.DisplayString())
	}
	Set ev = ##class(SignalNoir.Core.Dto.Evidence).%New()
	Set ev.source = toolName
	Set ev.calledBy = ..Caller
	Set ev.params = params
	Set ev.observedAt = ##class(SignalNoir.Application.SystemClock).%New().NowUtc()
	Set ev.durationMs = ($ZHorolog - started) * 1000 \ 1
	If read.ok && $IsObject(read.obj) && read.obj.%Get("available") {
		Set ev.kind = "fact"
		Set ev.result = read.obj.%Get("result")
	} Else {
		Set ev.kind = "absence"
		Set reason = $Select(read.ok && $IsObject(read.obj): read.obj.%Get("reason"), 1: read.message)
		Set ev.result = {"available": false, "reason": (reason)}
	}
	Set found = ##class(SignalNoir.Core.Suspicion).Scan(ev.result)
	For i = 1 : 1 : found.Count() Do ev.suspiciousExcerpts.Insert(found.GetAt(i))
	Set recorded = ..Service.RecordEvidence(..InvestigationId, ev)
	If 'recorded.ok Return recorded
	If $IsObject(ev.result) && ev.result.%IsA("%DynamicObject") Set ev.payload = ev.result
	Return ##class(SignalNoir.Core.Result).OkObj(ev)
}

}
