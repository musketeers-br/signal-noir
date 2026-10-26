Class SignalNoir.Tools.Sources Extends SignalNoir.Core.Port.EvidenceSource
{

/// Routes each reading Tool to its source: the Simulator over HTTP, or the
/// local Case store and reference data.
Property Simulator As SignalNoir.Core.Port.EvidenceSource;

Property Local As SignalNoir.Core.Port.EvidenceSource;

Method %OnNew() As %Status
{
	Set ..Simulator = ##class(SignalNoir.Tools.SimulatorSource).%New()
	Set ..Local = ##class(SignalNoir.Tools.LocalSource).%New()
	Return $$$OK
}

Method Read(toolName As %String, args As %DynamicObject) As SignalNoir.Core.Result
{
	If $ListFind($ListBuild("tool.order_timeline", "tool.policies", "tool.mapping_catalog"), toolName) Return ..Local.Read(toolName, args)
	Return ..Simulator.Read(toolName, args)
}

}
