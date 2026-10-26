Class SignalNoir.Proposers.Factory Extends %RegisteredObject
{

/// The only place that reads the proposer mode (006 FR-012): before the
/// Proposer port. Everything after the port is mode-blind.
ClassMethod ClassFor(mode As %String) As %String
{
	If mode = "rules" Return "SignalNoir.Proposers.Rules"
	If mode = "replay" Return "SignalNoir.Proposers.Replay"
	If mode = "agent" Return "SignalNoir.Proposers.Agent"
	Return "SignalNoir.Proposers.Unavailable"
}

/// Whether the mode's proposer can run at all on this instance (used to
/// route a new Case to ReviewRequired early when the provider is missing)
ClassMethod Ready(mode As %String) As %Boolean
{
	If (mode = "rules") || (mode = "replay") Return 1
	If mode = "agent" Return ##class(SignalNoir.Proposers.AiHubRuntime).Configured()
	Return 0
}

}
