Class SignalNoir.Core.Dto.ValidatorVerdict Extends %RegisteredObject
{

/// Seam v2 (contract change 004): accepted / blocked / review / prior_receipt_confirmed
Property verdict As %String(MAXLEN = 32);

/// Ordered closed codes (contracts/reason-codes.md)
Property reasons As list Of %String(MAXLEN = 64);

Property requiresApproval As %Boolean [ InitialExpression = 0 ];

Property at As %String(MAXLEN = 40);

/// policy, mapping: the reference-data versions the verdict was computed with
Property versions As %DynamicObject;

ClassMethod FromJson(json As %DynamicObject) As SignalNoir.Core.Dto.ValidatorVerdict
{
	If '$IsObject(json) || 'json.%IsA("%Library.DynamicObject") Return ""
	Set v = ..%New()
	Set v.verdict = json.%Get("verdict"), v.requiresApproval = +json.%Get("requiresApproval"), v.at = json.%Get("at")
	If json.%GetTypeOf("reasons") = "array" {
		For i = 0 : 1 : json.reasons.%Size() - 1 Do v.reasons.Insert(json.reasons.%Get(i))
	}
	If json.%GetTypeOf("versions") = "object" Set v.versions = json.versions
	Return v
}

Method ToJson() As %DynamicObject
{
	Set o = {"verdict": (..verdict), "reasons": (..ReasonsJson())}
	Do o.%Set("requiresApproval", ..requiresApproval, "boolean")
	Set o.at = ..at
	Set versions = {}
	For key = "policy", "mapping" {
		Set value = $Select($IsObject(..versions): ..versions.%Get(key), 1: "")
		If value = "" {
			Do versions.%Set(key, "", "null")
		} Else {
			Do versions.%Set(key, value)
		}
	}
	Set o.versions = versions
	Return o
}

Method ReasonsJson() As %DynamicArray
{
	Set out = []
	For i = 1 : 1 : ..reasons.Count() Do out.%Push(..reasons.GetAt(i))
	Return out
}

}
