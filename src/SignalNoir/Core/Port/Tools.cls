Class SignalNoir.Core.Port.Tools Extends %RegisteredObject [ Abstract ]
{

/// Read-only by contract (seam). No write-capable tool may implement this
/// port. Implementation arrives in later slices.

Method Invoke(toolName As %String, args As %DynamicObject) As SignalNoir.Core.Result
{
	Return $$$ERROR($$$GeneralError, "Abstract port method - override in adapter or fake")
}

}
