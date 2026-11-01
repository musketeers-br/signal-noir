Class SignalNoir.Benchmark.Data.Base [ Abstract ]
{

/// Committed, versioned data of the Benchmark (feature 010, plan D1, D8): the answer keys,
/// and later the roles, reviews, used-set declarations, freeze record and recorded
/// reference result. Each subclass holds its records in XData and is read by name, the
/// same pattern as Sim.Catalog.*. Nothing here is writable through the API.
/// {variant: key} of every XData Keys of every subclass. A variant listed twice keeps its
/// first key; Duplicates() reports the repetition (the answer-key test fails on it).
ClassMethod Keys() As %DynamicObject
{
	Set all = {}
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.CompiledClass WHERE Name %STARTSWITH 'SignalNoir.Benchmark.Data.' ORDER BY Name")
	While rs.%Next() {
		Set name = rs.%Get("Name")
		If (name = "SignalNoir.Benchmark.Data.Base") || '$ClassMethod(name, "%Extends", "SignalNoir.Benchmark.Data.Base") Continue
		Set list = ..Read(name, "Keys")
		If '$IsObject(list) Continue
		For i = 0 : 1 : list.%Size() - 1 {
			Set key = list.%Get(i)
			If all.%IsDefined(key.variant) Continue
			Do all.%Set(key.variant, key)
		}
	}
	Return all
}

/// The key of a variant, or "" when none is declared
ClassMethod KeyFor(variant As %String) As %DynamicObject
{
	Set all = ..Keys()
	Return $Select(all.%IsDefined(variant): all.%Get(variant), 1: "")
}

/// The variants named by more than one key, as a list (for the answer-key test)
ClassMethod Duplicates() As %DynamicArray
{
	Set seen = {}, dup = []
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.CompiledClass WHERE Name %STARTSWITH 'SignalNoir.Benchmark.Data.' ORDER BY Name")
	While rs.%Next() {
		Set name = rs.%Get("Name")
		If (name = "SignalNoir.Benchmark.Data.Base") || '$ClassMethod(name, "%Extends", "SignalNoir.Benchmark.Data.Base") Continue
		Set list = ..Read(name, "Keys")
		If '$IsObject(list) Continue
		For i = 0 : 1 : list.%Size() - 1 {
			Set v = list.%Get(i).variant
			If seen.%IsDefined(v) Do dup.%Push(v)
			Do seen.%Set(v, 1)
		}
	}
	Return dup
}

/// The JSON of one XData of a class, or "" when the class has none by that name
ClassMethod Read(class As %String, xdata As %String) As %DynamicAbstractObject
{
	Set x = ##class(%Dictionary.CompiledXData).%OpenId(class _ "||" _ xdata)
	If '$IsObject(x) || 'x.Data.Size Return ""
	Return ##class(%DynamicAbstractObject).%FromJSON(x.Data.Read(x.Data.Size))
}

}
