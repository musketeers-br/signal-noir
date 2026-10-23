Class SignalNoir.Tests.Fakes.FakeTools Extends SignalNoir.Core.Port.Tools
{

/// Returns a canned Evidence (seam contract). Read-only by contract: this
/// fake never calls a partner and never mutates anything.

Property Evidence As SignalNoir.Core.Dto.Evidence;

Property LastToolName As %String;

Method %OnNew() As %Status
{
	Set evidence = ##class(SignalNoir.Core.Dto.Evidence).%New()
	Set evidence.evidenceId = "evid_000001"
	Set evidence.kind = "observation"
	Set evidence.source = "tool.fake"
	Set evidence.observedAt = "2026-01-01T00:00:00Z"
	Set evidence.payload = ##class(%DynamicObject).%New()
	Set ..Evidence = evidence
	Return $$$OK
}

Method Invoke(toolName As %String, args As %DynamicObject) As SignalNoir.Core.Result
{
	Set ..LastToolName = toolName
	Return ##class(SignalNoir.Core.Result).OkObj(..Evidence)
}

}
