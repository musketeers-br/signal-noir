Class SignalNoir.Interop.Production Extends %RegisteredObject
{

/// The minimal Production (D6): one Business Service, the Order intake,
/// which calls the single command path.
/// The dev container for this slice runs a plain IRIS without
/// Interoperability, so the production is realized in a portable shape: the
/// same name, the same single item, the same start/stop surface, and the
/// definition an Interoperability-enabled instance registers as an
/// Ens.Production. See research.md D6/D2 for the environment constraint.

Parameter NAME = "SignalNoir.Interop.Production";

Parameter SETTINGS = "Default";

/// The one item of this slice: the Business Service that consumes the
/// synthetic Orders and hands them to the command path.
Parameter ITEMS = "SignalNoir.Interop.Service.OrderIn";

/// The web applications this Production owns.
Parameter WEBAPPLICATIONS = "/signalnoir/api/v1";

ClassMethod Start() As %Status
{
	Set ^SignalNoir.Production("started") = 1
	Set ^SignalNoir.Production("mode") = "portable"
	Set ^SignalNoir.Production("startedAt") = ##class(SignalNoir.Application.SystemClock).%New().NowUtc()
	Return $$$OK
}

ClassMethod Stop() As %Status
{
	Kill ^SignalNoir.Production("started")
	Return $$$OK
}

ClassMethod Status() As %DynamicObject
{
	Set status = ##class(%DynamicObject).%New()
	Do status.%Set("name", ..#NAME)
	Do status.%Set("mode", "portable")
	Do status.%Set("started", +$Get(^SignalNoir.Production("started")))
	Set items = ##class(%DynamicArray).%New()
	Do items.%Push("SignalNoir.Interop.Service.OrderIn")
	Do status.%Set("items", items)
	Set webApps = ##class(%DynamicArray).%New()
	Do webApps.%Push(..#WEBAPPLICATIONS)
	Do status.%Set("webApplications", webApps)
	Return status
}

/// The production definition, as an Interoperability-enabled instance
/// registers it: one business service item fed by the Order intake.
ClassMethod Definition() As %DynamicObject
{
	Set definition = ##class(%DynamicObject).%New()
	Do definition.%Set("name", ..#NAME)
	Do definition.%Set("settings", ..#SETTINGS)
	Set item = ##class(%DynamicObject).%New()
	Do item.%Set("name", "OrderInService")
	Do item.%Set("type", "BusinessService")
	Do item.%Set("class", "SignalNoir.Interop.Service.OrderIn")
	Do item.%Set("poolSize", 1)
	Do item.%Set("messaging", "InMemory")
	Set items = ##class(%DynamicArray).%New()
	Do items.%Push(item)
	Do definition.%Set("items", items)
	Return definition
}

}
