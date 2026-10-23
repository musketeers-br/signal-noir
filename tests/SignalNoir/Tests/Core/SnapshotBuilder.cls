/// Builds, from one row of the normative table, a CaseSnapshot and a TransitionCommand that satisfy
/// every precondition of the row. An independent reading of the check vocabulary
/// (specs/001 data-model), so the parity test does not reuse the Core's own logic.
Class SignalNoir.Tests.Core.SnapshotBuilder Extends %RegisteredObject
{

/// Fixed clock of the tests.
Parameter NOW = "2026-10-26T12:00:00.000Z";

Parameter PAST = "2026-10-26T11:00:00.000Z";

Parameter FUTURE = "2026-10-26T13:00:00.000Z";

ClassMethod Build(row As %DynamicObject, Output snapshot As SignalNoir.Core.CaseSnapshot, Output command As SignalNoir.Core.TransitionCommand)
{
    set snapshot = ##class(SignalNoir.Core.CaseSnapshot).%New()
    set snapshot.CaseId = $select(row.%GetTypeOf("from") = "null": "", 1: "case_parity")
    set snapshot.OrderId = "ORD-PARITY"
    set snapshot.State = $select(row.%GetTypeOf("from") = "null": "", 1: row.from)
    set snapshot.CaseVersion = $select(snapshot.State = "": 0, 1: 4)
    set snapshot.CurrentProposalId = "prop_current"
    set snapshot.StepLeaseUntil = ..#FUTURE

    set command = ##class(SignalNoir.Core.TransitionCommand).%New()
    set command.RequestedState = row.to
    set command.Command = $select(row.%GetTypeOf("command") = "null": "", 1: row.command)
    set command.Actor = $replace(row.actors.%Get(0), "operator:*", "operator:Carla")
    set command.ExpectedState = snapshot.State
    set command.ExpectedCaseVersion = snapshot.CaseVersion
    if (command.Actor = "agent") || (command.Actor = "rules") || (command.Actor = "replay") set snapshot.ProposerMode = command.Actor
    if command.Actor = "benchmark" set snapshot.BenchmarkRunId = "run_parity"

    set it = row.preconditions.%GetIterator()
    while it.%GetNext(.i, .pre) { do ..Satisfy(pre.check, pre.%Get("expected"), snapshot, command) }
}

ClassMethod Satisfy(check As %String, expected, snapshot As SignalNoir.Core.CaseSnapshot, command As SignalNoir.Core.TransitionCommand)
{
    set facts = command.Facts
    set value = ..Resolve(expected)
    if check = "state" { set snapshot.State = value, command.ExpectedState = value }
    elseif check = "caseVersionMatches" { set command.ExpectedCaseVersion = snapshot.CaseVersion }
    elseif check = "noOpenCaseForOrder" { set snapshot.State = "" }
    elseif check = "previousCaseExists" { set snapshot.PreviousCaseExists = value }
    elseif check = "previousCaseTerminal" { set snapshot.PreviousCaseExists = 1, snapshot.PreviousCaseTerminal = value }
    elseif check = "leaseValid" { set snapshot.StepLeaseUntil = ..#FUTURE }
    elseif check = "leaseExpired" { set snapshot.StepLeaseUntil = ..#PAST }
    elseif check = "proposerMatchesMode" { set snapshot.ProposerMode = command.Actor }
    elseif check = "proposalIsCurrent" { set command.TargetId = snapshot.CurrentProposalId }
    elseif check = "noExecutionInFlight" { set snapshot.ExecutionOutcome = "" }
    elseif check = "benchmarkRun" { set snapshot.BenchmarkRunId = "run_parity" }
    elseif check = "denialCountBelow" { set snapshot.DenialCount = value - 1 }
    elseif check = "denialCount" { set snapshot.DenialCount = value }
    elseif check = "approvalForCurrentProposal" {
        set snapshot.ApprovalId = "appr_current", snapshot.ApprovalProposalId = snapshot.CurrentProposalId, snapshot.ApprovalDecision = "approved"
        set:snapshot.ApprovalExpiresAt="" snapshot.ApprovalExpiresAt = ..#FUTURE
    }
    elseif check = "approvalNotExpired" { set snapshot.ApprovalExpiresAt = ..#FUTURE }
    elseif check = "approvalExpired" {
        set snapshot.ApprovalId = "appr_current", snapshot.ApprovalProposalId = snapshot.CurrentProposalId, snapshot.ApprovalDecision = "approved", snapshot.ApprovalExpiresAt = ..#PAST
    }
    elseif check = "noAuthorization" { set snapshot.ExecutionId = "", snapshot.ExecutionApprovalId = "" }
    elseif check = "executionOutcome" { set snapshot.ExecutionId = "exec_current", snapshot.ExecutionOutcome = value }
    elseif check = "noAttemptSent" { set snapshot.ExecutionAttemptsSent = 0 }
    elseif check = "inconclusiveReconciliations" {
        set snapshot.ExecutionInconclusiveReconciliations = value - 1
        do facts.%Set("reconciliationResult", "inconclusive")
    }
    elseif check = "revalidationFailed" {
        do facts.%Set("revalidationFailed", $select($isobject(value): [(value.%Get(0))], 1: [(value)]))
    }
    elseif check = "reasonPresent" { do facts.%Set("reason", "test reason") }
    elseif $isobject(value) { do facts.%Set(check, value.%Get(0)) }
    elseif (value = 1) || (value = 0) { do facts.%Set(check, value, "boolean") }
    else { do facts.%Set(check, value) }
}

ClassMethod Resolve(expected)
{
    if $isobject(expected) quit expected
    set parameter = ##class(SignalNoir.Tests.Core.TableFixture).Load().parameters.%Get(expected)
    quit $select(parameter '= "": parameter, 1: expected)
}

}
