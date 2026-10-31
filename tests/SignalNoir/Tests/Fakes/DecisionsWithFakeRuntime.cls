Class SignalNoir.Tests.Fakes.DecisionsWithFakeRuntime Extends SignalNoir.Proposers.Decisions
{

/// The real Decisions proposer (questions, conversion) over the fake runtime
Method %OnNew() As %Status
{
	Set ..Runtime = ##class(SignalNoir.Tests.Fakes.FakeDecisionsRuntime).%New()
	Return $$$OK
}

}
