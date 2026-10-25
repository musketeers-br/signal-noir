Class SignalNoir.Tests.Fakes.AgentWithFakeRuntime Extends SignalNoir.Proposers.Agent
{

/// The real Agent proposer (prompt, input, parsing) over the fake runtime
Method %OnNew() As %Status
{
	Set ..Runtime = ##class(SignalNoir.Tests.Fakes.FakeAgentRuntime).%New()
	Return $$$OK
}

}
