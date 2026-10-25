Class SignalNoir.Tests.Fakes.BrokenCmdIds Extends SignalNoir.Core.Port.IdGenerator
{

/// Test-only IdGenerator that cannot issue cmd_ ids, so the follow-up work of
/// a transition fails to save after the state and the event were written.
/// Proves the transition is all-or-nothing (FR-018).
Method New(prefix As %String) As %String
{
	If prefix = "cmd_" Return ""
	Return ##class(SignalNoir.Application.IdFactory).%New().New(prefix)
}

}
