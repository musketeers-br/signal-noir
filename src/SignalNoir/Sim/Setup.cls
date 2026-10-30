Class SignalNoir.Sim.Setup Extends %RegisteredObject
{

/// Registers the Simulator's web application /sim/api/v1 (research D2),
/// delete-then-create, with the same settings as the product's bootstrap
/// (Type 2: V5). Called by the tests now and by the bootstrap at gate G1.
Parameter APP = "/sim/api/v1";

ClassMethod EnsureWebApplication() As %Status
{
	Set ns = $NAMESPACE
	Set sc = $$$OK
	Try {
		Set $NAMESPACE = "%SYS"
		Set props("DispatchClass") = "SignalNoir.Sim.Api.Dispatch", props("Name") = "Signal Noir Simulator"
		Set props("Type") = 2, props("NameSpace") = ns, props("AutheEnabled") = 64, props("MatchRoles") = ":%All"
		If ##class(Security.Applications).Exists(..#APP) {
			Set sc = ##class(Security.Applications).Get(..#APP, .current)
			; already registered for this namespace and dispatcher: leave it
			If $$$ISOK(sc) && ($Get(current("DispatchClass")) = props("DispatchClass")) && ($Get(current("NameSpace")) = ns) Quit
			Do ##class(Security.Applications).Delete(..#APP)
		}
		Set sc = ##class(Security.Applications).Create(..#APP, .props)
	}
	Catch ex {
		Set sc = ex.AsStatus()
	}
	Set $NAMESPACE = ns
	Return sc
}

ClassMethod Exists(app As %String) As %Boolean
{
	Set ns = $NAMESPACE
	Set $NAMESPACE = "%SYS"
	Set out = ##class(Security.Applications).Exists(app)
	Set $NAMESPACE = ns
	Return out
}

}
