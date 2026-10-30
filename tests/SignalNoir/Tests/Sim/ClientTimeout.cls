Class SignalNoir.Tests.Sim.ClientTimeout Extends %RegisteredObject
{

/// Test-only switch of the client timeout the Simulator outlasts (research
/// D6), so suites outside the Simulator's test package never touch its
/// storage (TestNoCrossReference)
ClassMethod Set(seconds As %Integer)
{
	Set ^SignalNoir.Sim.Config("clientTimeoutSeconds") = seconds
}

ClassMethod Clear()
{
	Kill ^SignalNoir.Sim.Config("clientTimeoutSeconds")
}

}
