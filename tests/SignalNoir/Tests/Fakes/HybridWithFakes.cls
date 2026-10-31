Class SignalNoir.Tests.Fakes.HybridWithFakes Extends SignalNoir.Proposers.Hybrid
{

/// The real hybrid cascade over the fake Decisions runtime and the fake AI
/// Hub runtime
Method %OnNew() As %Status
{
	Set ..First = ##class(SignalNoir.Tests.Fakes.DecisionsWithFakeRuntime).%New()
	Set ..Fallback = ##class(SignalNoir.Tests.Fakes.AgentWithFakeRuntime).%New()
	Return $$$OK
}

}
