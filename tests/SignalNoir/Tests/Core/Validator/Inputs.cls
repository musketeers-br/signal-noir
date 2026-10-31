Class SignalNoir.Tests.Core.Validator.Inputs Extends %RegisteredObject
{

/// 004 T011 - test-only builder of Validator inputs, in memory, no persistence. The reference
/// data is a literal equal to Policy Set and Mapping Set 2026.10.1; the Application.Reference
/// test asserts the Store serves the same snapshot.
Parameter CASE = "case_000123";

Parameter NOW = "2026-10-29T13:02:11Z";

/// Snapshot of policy and mapping 2026.10.1 (data-model "Reference data")
ClassMethod Reference() As SignalNoir.Core.Dto.ReferenceData
{
	Return ##class(SignalNoir.Core.Dto.ReferenceData).FromJson({
		"policyVersion": "2026.10.1",
		"mappingVersion": "2026.10.1",
		"policies": {
			"attempt": {"maxAttempts": 3},
			"substitution": {"enabled": true},
			"maintenanceWindows": [],
			"partnerHealth": {"windowSeconds": 300, "maxErrorRate": 0.2},
			"approval": {"deadlineSeconds": 900}
		},
		"mappings": [
			{"mappingId": "map_glicj_plasma", "mappingVersion": "2026.10.1", "sourceCode": "GLIC-J", "targetCode": "GLIC-P", "conditions": {"specimenType": "PLASMA"}},
			{"mappingId": "map_glicj_soro", "mappingVersion": "2026.10.1", "sourceCode": "GLIC-J", "targetCode": "GLIC-S", "conditions": {"specimenType": "SERUM"}},
			{"mappingId": "map_hba1c_legacy", "mappingVersion": "2026.10.1", "sourceCode": "HBA1C-L", "targetCode": "HBA1C", "conditions": {}},
			{"mappingId": "map_tsh_legacy", "mappingVersion": "2026.10.1", "sourceCode": "TSH-OLD", "targetCode": "TSH", "conditions": {}}
		],
		"synonyms": {"specimenType": {"PLASMA": ["PLASMA"], "SERUM": ["SERUM", "SORO"]}}
	})
}

/// Raw Order snapshots, as an Origin may send them (lower-case specimen types)
ClassMethod PlasmaOrder() As %DynamicObject
{
	Return {"orderId": "ORD-1", "patient": {"patientId": "SYN-PAT-0107", "name": "Ana Souza", "birthDate": "1980-01-02"}, "exams": [{"code": "GLIC-J"}], "specimen": {"specimenId": "SP-1", "collectedAt": "2026-10-23T10:00:00Z", "type": "plasma"}}
}

ClassMethod SerumOrder() As %DynamicObject
{
	Return {"orderId": "ORD-2", "patient": {"patientId": "SYN-PAT-0108", "name": "Bruno Lima", "birthDate": "1975-05-06"}, "exams": [{"code": "GLIC-J"}], "specimen": {"specimenId": "SP-2", "collectedAt": "2026-10-23T10:05:00Z", "type": "soro"}}
}

/// An Order whose exam only a condition-free Mapping covers
ClassMethod LegacyTshOrder() As %DynamicObject
{
	Return {"orderId": "ORD-3", "patient": {"patientId": "SYN-PAT-0109", "name": "Carla Reis", "birthDate": "1990-09-10"}, "exams": [{"code": "TSH-OLD"}], "specimen": {"specimenId": "SP-3", "collectedAt": "2026-10-23T10:10:00Z", "type": "SERUM"}}
}

/// A recorded Evidence: a fact by default
ClassMethod Evidence(id As %String, source As %String, result As %DynamicObject, kind As %String = "fact") As SignalNoir.Core.Dto.Evidence
{
	Set e = ##class(SignalNoir.Core.Dto.Evidence).%New()
	Set e.evidenceId = id, e.caseId = ..#CASE, e.source = source, e.kind = kind, e.result = result
	Set e.observedAt = ..#NOW
	Return e
}

/// The result of tool.policies, as the Store serves it
ClassMethod PoliciesResult() As %DynamicObject
{
	Return {"policyVersion": "2026.10.1", "attempt": {"maxAttempts": 3}, "substitution": {"enabled": true}, "maintenanceWindows": [], "partnerHealth": {"windowSeconds": 300, "maxErrorRate": 0.2}, "approval": {"deadlineSeconds": 900}}
}

ClassMethod HistoryResult() As %DynamicObject
{
	Return {"window": {"from": "2026-10-29T12:00:00Z", "to": "2026-10-29T13:00:00Z"}, "items": []}
}

ClassMethod HealthResult() As %DynamicObject
{
	Return {"partnerId": "labpartner-c", "status": "UP", "message": "all systems nominal", "maintenance": null}
}

/// The result of tool.mapping_catalog: the items of the Mapping Set plus the synonyms
ClassMethod CatalogResult() As %DynamicObject
{
	Set ref = ..Reference()
	Return {"mappingVersion": (ref.mappingVersion), "items": (ref.mappings), "synonyms": (ref.synonyms)}
}

/// The Evidence that is complete for an Action (data-model "Action catalog"). The Order field
/// a Mapping depends on is read from the Order the Case holds, so it needs no Evidence.
ClassMethod EvidenceFor(action As %String) As %ListOfObjects
{
	Set list = ##class(%ListOfObjects).%New()
	If action = "RETRY" {
		Do list.Insert(..Evidence("evid_pol", "tool.policies", ..PoliciesResult()))
		Do list.Insert(..Evidence("evid_hist", "tool.partner_failure_history", ..HistoryResult()))
		Do list.Insert(..Evidence("evid_health", "tool.partner_health", ..HealthResult()))
	} ElseIf action = "APPLY_APPROVED_MAPPING" {
		Do list.Insert(..Evidence("evid_pol", "tool.policies", ..PoliciesResult()))
		Do list.Insert(..Evidence("evid_map", "tool.mapping_catalog", ..CatalogResult()))
	} ElseIf action = "HOLD" {
		Do list.Insert(..Evidence("evid_health", "tool.partner_health", ..HealthResult()))
	}
	Return list
}

/// Another patient record with the same name, as the receipts-by-patient tool returns it
ClassMethod CollidingEvidence(order As %DynamicObject = "") As SignalNoir.Core.Dto.Evidence
{
	If '$IsObject(order) Set order = ..PlasmaOrder()
	Set other = {"patientId": "SYN-PAT-0311", "name": (order.patient.name), "birthDate": "1981-03-04"}
	Return ..Evidence("evid_pat", "tool.receipts_and_orders_by_patient", {"items": [{"receiptId": "rcp_9", "orderId": "ORD-9", "orderSnapshot": {"patient": (other)}}]})
}

ClassMethod Proposal(action As %String, params As %DynamicObject = "", confidence As %String = "HIGH") As SignalNoir.Core.Dto.Proposal
{
	Set p = ##class(SignalNoir.Core.Dto.Proposal).%New()
	Set p.proposalId = "prop_000045", p.caseId = ..#CASE, p.origin = "agent", p.action = action
	Set p.params = $Select($IsObject(params): params, 1: {})
	Set p.scope = "single_case", p.confidence = confidence
	Set p.preconditions = [], p.versions = {"policy": "2026.10.1", "mapping": "2026.10.1"}
	Return p
}

ClassMethod MappingParams(mappingId As %String = "map_glicj_plasma", version As %String = "2026.10.1") As %DynamicObject
{
	Return {"mappingId": (mappingId), "mappingVersion": (version)}
}

/// A complete input: the Reference snapshot, a clean run, the fixed clock
ClassMethod Input(proposal As SignalNoir.Core.Dto.Proposal, evidence As %ListOfObjects = "", order As %DynamicObject = "", attemptCount As %Integer = 0) As SignalNoir.Core.Dto.ValidationInput
{
	Set in = ##class(SignalNoir.Core.Dto.ValidationInput).%New()
	Set in.proposal = proposal
	Set in.evidence = $Select($IsObject(evidence): evidence, 1: ..EvidenceFor(proposal.action))
	Set in.order = $Select($IsObject(order): order, 1: ..PlasmaOrder())
	Set in.attemptCount = attemptCount
	Set in.run = {"inRun": false, "runId": null, "policyVersion": null, "mappingVersion": null}
	Set in.reference = ..Reference()
	Set in.now = ..#NOW
	Return in
}

}
