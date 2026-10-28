Class SignalNoir.Sim.Catalog.Loader Extends %RegisteredObject
{

/// Reads every variant of every SignalNoir.Sim.Catalog.Base subclass and
/// serves their public form (contracts/scenario-script.md, research D7, D8).
/// Result.obj = the variants (full, with partnerRule) as a %DynamicArray.
ClassMethod All() As SignalNoir.Sim.Result
{
	Set all = []
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.CompiledClass WHERE Name %STARTSWITH 'SignalNoir.Sim.Catalog.' ORDER BY Name")
	While rs.%Next() {
		Set name = rs.%Get("Name")
		If (name = "SignalNoir.Sim.Catalog.Base") || '$ClassMethod(name, "%Extends", "SignalNoir.Sim.Catalog.Base") Continue
		Set xdata = ##class(%Dictionary.CompiledXData).%OpenId(name _ "||Variants")
		If '$IsObject(xdata) Continue
		Set list = [].%FromJSON(xdata.Data)
		For i = 0 : 1 : list.%Size() - 1 Do all.%Push(list.%Get(i))
	}
	Set check = ..Check(all)
	If 'check.ok Return check
	Return ##class(SignalNoir.Sim.Result).Ok(all)
}

/// Refuses a catalog where a variant id appears twice
ClassMethod Check(variants As %DynamicArray) As SignalNoir.Sim.Result
{
	Kill seen
	For i = 0 : 1 : variants.%Size() - 1 {
		Set id = variants.%Get(i).variant
		If $Data(seen(id)) Return ##class(SignalNoir.Sim.Result).Error("INVALID_REQUEST", "duplicate variant id in the catalog: " _ id)
		Set seen(id) = ""
	}
	Return ##class(SignalNoir.Sim.Result).Ok(variants)
}

/// The full variant (with its private rule) for this family, or ""
ClassMethod Find(family As %String, variant As %String) As %DynamicObject
{
	Set all = ..All()
	If 'all.ok Return ""
	For i = 0 : 1 : all.obj.%Size() - 1 {
		Set v = all.obj.%Get(i)
		If (v.variant = variant) && (v.family = family) Return v
	}
	Return ""
}

/// The served form of the catalog, filtered by family and set ("" = any)
ClassMethod List(family As %String = "", set As %String = "") As %DynamicArray
{
	Set out = []
	Set all = ..All()
	If 'all.ok Return out
	For i = 0 : 1 : all.obj.%Size() - 1 {
		Set v = all.obj.%Get(i)
		If (family '= "") && (v.family '= family) Continue
		If (set '= "") && (v.set '= set) Continue
		Do out.%Push(..Served(v))
	}
	Return out
}

/// What GET /scenario-catalog serves: no partnerRule; orders reduced to
/// their count and declared quirks, under script.emission
ClassMethod Served(variant As %DynamicObject) As %DynamicObject
{
	Set out = {}
	For f = "family", "subtype", "variant", "set", "partnerId", "language", "description" {
		If variant.%IsDefined(f) Do out.%Set(f, variant.%Get(f))
	}
	Set script = $Select($IsObject(variant.script): {}.%FromJSON(variant.script.%ToJSON()), 1: {})
	Set quirks = []
	Set orders = $Select($IsObject(variant.orders): variant.orders, 1: [])
	For i = 0 : 1 : orders.%Size() - 1 {
		Set q = orders.%Get(i).quirks
		If $IsObject(q) {
			For j = 0 : 1 : q.%Size() - 1 Do quirks.%Push(q.%Get(j))
		}
	}
	Set script.emission = {"orders": (orders.%Size()), "quirks": (quirks)}
	Set out.script = script
	Return out
}

}
