Class SignalNoir.Tests.Fakes.BrokenExecIds Extends SignalNoir.Core.Port.IdGenerator
{

/// Test-only IdGenerator that cannot issue exec_ ids, so the authorization
/// of an execution fails to save. Proves no Partner call happens when the
/// authorization cannot be persisted (008 FR-004).
Method New(prefix As %String) As %String
{
	If prefix = "exec_" Return ""
	Return ##class(SignalNoir.Application.IdFactory).%New().New(prefix)
}

}
