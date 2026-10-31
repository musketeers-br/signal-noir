Class SignalNoir.Core.Dto.ReferenceData Extends %RegisteredObject
{

/// Immutable snapshot of one policy version and one mapping version (004). Built by
/// Application.Reference.Store and carried inside the ValidationInput, so the Validator does
/// no I/O.
Property policyVersion As %String(MAXLEN = 32);

Property mappingVersion As %String(MAXLEN = 32);

/// attempt, substitution, maintenanceWindows, partnerHealth, approval
Property policies As %DynamicObject;

/// [{mappingId, mappingVersion, sourceCode, targetCode, conditions}]
Property mappings As %DynamicArray;

/// {field: {canonical: [variants]}}
Property synonyms As %DynamicObject;

ClassMethod FromJson(json As %DynamicObject) As SignalNoir.Core.Dto.ReferenceData
{
	If '$IsObject(json) || 'json.%IsA("%Library.DynamicObject") Return ""
	Set ref = ..%New()
	Set ref.policyVersion = json.%Get("policyVersion"), ref.mappingVersion = json.%Get("mappingVersion")
	Set ref.policies = $Select(json.%GetTypeOf("policies") = "object": json.policies, 1: {})
	Set ref.mappings = $Select(json.%GetTypeOf("mappings") = "array": json.mappings, 1: [])
	Set ref.synonyms = $Select(json.%GetTypeOf("synonyms") = "object": json.synonyms, 1: {})
	Return ref
}

Method ToJson() As %DynamicObject
{
	Return {"policyVersion": (..policyVersion), "mappingVersion": (..mappingVersion), "policies": (..policies), "mappings": (..mappings), "synonyms": (..synonyms)}
}

}
