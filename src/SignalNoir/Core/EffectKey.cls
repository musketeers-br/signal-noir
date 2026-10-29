Class SignalNoir.Core.EffectKey Extends %RegisteredObject
{

/// The identity of an effect on the Partner (Constitution VI, 008 research
/// R3, resolving API-Q11): H(orderId, partnerId, canonical payload). Two
/// Proposals that send the same payload get the same key; the key never
/// depends on the Proposal. Pure.
ClassMethod Derive(orderId As %String, partnerId As %String, payload As %DynamicAbstractObject) As %String
{
	Set h = $System.Encryption.SHAHash(256, $ZConvert(orderId _ "|" _ partnerId _ "|" _ ..Canonical(payload), "O", "UTF8")), hex = ""
	For i = 1 : 1 : 16 Set hex = hex _ $ZConvert($Translate($Justify($ZHex($Ascii(h, i)), 2), " ", "0"), "L")
	Return "bek_" _ hex
}

/// JSON with object keys sorted at every level, arrays in order, no whitespace
ClassMethod Canonical(value) As %String
{
	If '$IsObject(value) Return ##class(%DynamicArray).%New().%Push(value).%ToJSON()
	If value.%IsA("%DynamicArray") {
		Set out = "["
		For i = 0 : 1 : value.%Size() - 1 Set out = out _ $Select(i: ",", 1: "") _ ..Item(value, i)
		Return out _ "]"
	}
	Set it = value.%GetIterator()
	While it.%GetNext(.k) {
		Set keys(k) = ""
	}
	Set out = "{", k = "", n = 0
	For {
		Set k = $Order(keys(k))
		Quit:k=""
		Set name = [(k)].%ToJSON()
		Set out = out _ $Select(n: ",", 1: "") _ $Extract(name, 2, *-1) _ ":" _ ..Item(value, k)
		Set n = n + 1
	}
	Return out _ "}"
}

/// One member, keeping its JSON type (true/false/null are not strings)
ClassMethod Item(container, key) As %String [ Private ]
{
	Set type = container.%GetTypeOf(key)
	If (type = "object") || (type = "array") Return ..Canonical(container.%Get(key))
	If type = "null" Return "null"
	If type = "boolean" Return $Select(container.%Get(key): "true", 1: "false")
	Set one = []
	Do one.%Push(container.%Get(key), $Select(type = "number": "number", 1: "string"))
	Return $Extract(one.%ToJSON(), 2, *-1)
}

}
