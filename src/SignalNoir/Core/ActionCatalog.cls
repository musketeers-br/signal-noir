Class SignalNoir.Core.ActionCatalog Extends %RegisteredObject
{

/// The closed Action catalog with its approval and parameter rules
/// (Constitution II; PRD FR-14, FR-16). Pure. HOLD has no external effect
/// and needs no approval; the other effectful Actions need one.
ClassMethod Entries() As %DynamicArray
{
	Set out = []
	For action = "RETRY", "APPLY_APPROVED_MAPPING", "HOLD", "REQUEST_REVIEW" {
		Set params = ..AllowedParams(action)
		Set props = {}
		For i = 1 : 1 : $ListLength(params) Do props.%Set($ListGet(params, i), {"type": "string"})
		Set schema = {"type": "object", "additionalProperties": false, "properties": (props)}
		If action = "APPLY_APPROVED_MAPPING" Do schema.%Set("required", ["mappingId", "mappingVersion"])
		Set entry = {"action": (action), "paramsSchema": (schema), "requiredEvidence": []}
		Do entry.%Set("externalEffect", ..ExternalEffect(action), "boolean")
		Do entry.%Set("requiresApproval", ..RequiresApproval(action), "boolean")
		Do out.%Push(entry)
	}
	Return out
}

ClassMethod ExternalEffect(action As %String) As %Boolean
{
	Return ((action = "RETRY") || (action = "APPLY_APPROVED_MAPPING"))
}

/// Only an Action with an external effect needs human Approval (R19, PRD
/// FR-16): REQUEST_REVIEW stops automation and has nothing to authorize (009b)
ClassMethod RequiresApproval(action As %String) As %Boolean
{
	Return ..ExternalEffect(action)
}

/// Parameter names an Action accepts ("" for none)
ClassMethod AllowedParams(action As %String) As %List
{
	If action = "APPLY_APPROVED_MAPPING" Return $ListBuild("mappingId", "mappingVersion")
	If (action = "HOLD") || (action = "REQUEST_REVIEW") Return $ListBuild("reason")
	Return ""
}

}
