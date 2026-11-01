Class SignalNoir.Application.ReferenceExecutionPolicy Extends SignalNoir.Core.ExecutionPolicy
{

/// The versions a Case is held to now (POLICY_VERSION_UNCHANGED, MAPPING_VERSION_UNCHANGED): those
/// in force, or, for a Case of a BenchmarkRun, the versions the run pinned, so a pinned run is not
/// held because the versions in force moved on. "" when no reference data can be read.
Method CurrentVersions(run As %DynamicObject = "") As %DynamicObject
{
	Set ref = ##class(SignalNoir.Application.Reference.Store).For(run)
	If 'ref.ok Return {"policy": "", "mapping": ""}
	Return {"policy": (ref.obj.policyVersion), "mapping": (ref.obj.mappingVersion)}
}

/// The execution policy with 004's reference data (008 coordination: "EffectPayload is where 004
/// applies an approved mapping"). An approved Mapping is read from the Mapping set of the version
/// the Proposal names, never the one in force, and sent through Core.MappingEffect. A Mapping that
/// cannot be read is still held with "mapping unavailable", never sent with a guessed payload.
/// Every other rule is the default policy's.
Method EffectPayload(action As %String, params As %DynamicObject, snapshot As %DynamicObject) As SignalNoir.Core.Result
{
	If action '= "APPLY_APPROVED_MAPPING" Return ##super(action, params, snapshot)
	Set mappingId = $Select($IsObject(params): params.%Get("mappingId"), 1: "")
	Set version = $Select($IsObject(params): params.%Get("mappingVersion"), 1: "")
	If (mappingId = "") || (version = "") Return ##class(SignalNoir.Core.Result).Error("", "mapping unavailable: the Proposal names no Mapping and version")
	Set ref = ##class(SignalNoir.Application.Reference.Store).For({"inRun": true, "mappingVersion": (version)})
	If 'ref.ok Return ##class(SignalNoir.Core.Result).Error("", "mapping unavailable: " _ ref.message)
	Set items = ref.obj.mappings
	For i = 0 : 1 : $Select($IsObject(items): items.%Size(), 1: 0) - 1 {
		Set m = items.%Get(i)
		If $IsObject(m) && (m.%Get("mappingId") = mappingId) Return ##class(SignalNoir.Core.MappingEffect).Payload(snapshot, m)
	}
	Return ##class(SignalNoir.Core.Result).Error("", "mapping unavailable: " _ mappingId _ " is not in Mapping set " _ version)
}

}
