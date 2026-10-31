Class SignalNoir.Proposers.Factory Extends %RegisteredObject
{

/// The only place that reads the proposer mode (006 FR-012): before the
/// Proposer port. Everything after the port is mode-blind.
ClassMethod ClassFor(mode As %String) As %String
{
	If mode = "rules" Return "SignalNoir.Proposers.Rules"
	If mode = "replay" Return "SignalNoir.Proposers.Replay"
	If mode = "agent" Return "SignalNoir.Proposers.Agent"
	If mode = "decisions" Return "SignalNoir.Proposers.Decisions"
	If mode = "hybrid" Return "SignalNoir.Proposers.Hybrid"
	Return "SignalNoir.Proposers.Unavailable"
}

/// Whether the mode's proposer can run at all on this instance (used to
/// route a new Case to ReviewRequired early when the provider is missing)
ClassMethod Ready(mode As %String) As %Boolean
{
	If (mode = "rules") || (mode = "replay") Return 1
	If mode = "agent" Return ##class(SignalNoir.Proposers.AiHubRuntime).Configured()
	If mode = "decisions" Return ##class(SignalNoir.Proposers.DecisionsHttp).Configured()
	; 016: either half can answer; with neither the Case goes to review at open
	If mode = "hybrid" Return ##class(SignalNoir.Proposers.AiHubRuntime).Configured() || ##class(SignalNoir.Proposers.DecisionsHttp).Configured()
	Return 0
}

/// The proposer mode of new Cases (013 FR-017): SN_PROPOSER_MODE, one of
/// agent (default), rules, decisions or hybrid (016); anything else is agent. Replay is
/// chosen by the Benchmark, never by the deployment.
ClassMethod ConfiguredMode() As %String
{
	Set mode = $ZConvert($System.Util.GetEnviron("SN_PROPOSER_MODE"), "L")
	Return $Select($ListFind($ListBuild("rules", "decisions", "hybrid"), mode): mode, 1: "agent")
}

}
