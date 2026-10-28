Class SignalNoir.Sim.Canon Extends %RegisteredObject
{

/// Canonical text of a delivered Order for the Partner's deduplication
/// (research D5, FR-017): objects with keys sorted recursively, arrays in
/// their order, values with their JSON types. Raw case and offsets are kept.
/// This is not the product's equivalence key, which the Simulator never makes.
ClassMethod Payload(value) As %String
{
	If '$IsObject(value) Return ..Scalar(value, "string")
	If value.%IsA("%DynamicArray") {
		Set out = "", it = value.%GetIterator()
		While it.%GetNext(.k, .v, .t) {
			Set out = out _ $Select(out = "": "", 1: ",") _ $Select($IsObject(v): ..Payload(v), 1: ..Scalar(v, t))
		}
		Return "[" _ out _ "]"
	}
	Kill keys
	Set it = value.%GetIterator()
	While it.%GetNext(.k, .v, .t) {
		Set keys(k) = ""
	}
	Set out = "", k = ""
	For {
		Set k = $Order(keys(k))
		Quit:k=""
		Set v = value.%Get(k), t = value.%GetTypeOf(k)
		Set out = out _ $Select(out = "": "", 1: ",") _ ..Scalar(k, "string") _ ":" _ $Select($IsObject(v): ..Payload(v), 1: ..Scalar(v, t))
	}
	Return "{" _ out _ "}"
}

/// A JSON scalar with its type (string, number, boolean, null)
ClassMethod Scalar(value, type As %String) As %String [ Private ]
{
	Set a = []
	If type = "null" {
		Do a.%Push("", "null")
	} ElseIf (type = "boolean") || (type = "number") {
		Do a.%Push(value, type)
	} Else {
		Do a.%Push(value, "string")
	}
	Set json = a.%ToJSON()
	Return $Extract(json, 2, *-1)
}

}
