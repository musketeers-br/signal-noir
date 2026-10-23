/// Behavior of SignalNoir.Core.Decider beyond row-by-row parity.
Class SignalNoir.Tests.Core.Decide Extends %UnitTest.TestCase
{

Parameter NOW = "2026-10-26T12:00:00.000Z";

Method TestRevalidationPrecedence()
{
    set snapshot = ..Executing()
    set command = ..Command("system", snapshot, "")
    do command.Facts.%Set("revalidationFailed", ["ORDER_ACTIVE_AT_ORIGIN", "PARTNER_HEALTHY_WINDOW"])
    set decision = ##class(SignalNoir.Core.Decider).Decide(snapshot, command, ..#NOW)
    do $$$AssertEquals(decision.TransitionId, "T21", "origin cancelled wins over partner unstable")

    set command = ..Command("system", snapshot, "")
    do command.Facts.%Set("revalidationFailed", ["PARTNER_HEALTHY_WINDOW", "POLICY_VERSION_UNCHANGED"])
    set decision = ##class(SignalNoir.Core.Decider).Decide(snapshot, command, ..#NOW)
    do $$$AssertEquals(decision.TransitionId, "T22", "changed policy wins over partner unstable")

    set command = ..Command("system", snapshot, "")
    do command.Facts.%Set("revalidationFailed", ["PARTNER_HEALTHY_WINDOW"])
    set decision = ##class(SignalNoir.Core.Decider).Decide(snapshot, command, ..#NOW)
    do $$$AssertEquals(decision.TransitionId, "T19", "partner unstable alone holds")
    do $$$AssertTrue(..Has(decision.RecordEffects, "VoidAuthorization"), "authorization voided")
}

Method TestVoidedAuthorizationNeverAccepted()
{
    set snapshot = ##class(SignalNoir.Core.CaseSnapshot).%New()
    set snapshot.CaseId = "case_void", snapshot.State = "Held", snapshot.CaseVersion = 8
    set snapshot.ExecutionId = "exec_old", snapshot.ExecutionOutcome = "held", snapshot.ExecutionAuthorizationVoided = 1
    set command = ..Command("system", snapshot, "Executing")
    set command.TargetId = "exec_old"
    set decision = ##class(SignalNoir.Core.Decider).Decide(snapshot, command, ..#NOW)
    do $$$AssertEquals(decision.Kind, "Refused", "a voided authorization cannot execute again")
}

Method TestDenialCount()
{
    set snapshot = ##class(SignalNoir.Core.CaseSnapshot).%New()
    set snapshot.CaseId = "case_deny", snapshot.State = "PendingApproval", snapshot.CaseVersion = 4, snapshot.CurrentProposalId = "prop_1"
    set command = ..Command("operator:Carla", snapshot, "Rejected")
    set command.TargetId = "prop_1"
    do command.Facts.%Set("decision", "denied"), command.Facts.%Set("reason", "wrong specimen")
    set decision = ##class(SignalNoir.Core.Decider).Decide(snapshot, command, ..#NOW)
    do $$$AssertEquals(decision.TransitionId, "T13", "denial")
    do $$$AssertTrue(..Has(decision.RecordEffects, "IncrementDenialCount"), "denial increments the counter")

    set snapshot.State = "Rejected"
    for count = 1, 2 {
        set snapshot.DenialCount = count
        set decision = ##class(SignalNoir.Core.Decider).Decide(snapshot, ..Command("system", snapshot, ""), ..#NOW)
        do $$$AssertEquals(decision.TransitionId, $select(count = 1: "T14", 1: "T15"), "denialCount "_count)
    }
    for id = "T22", "T27" {
        set row = ##class(SignalNoir.Core.TransitionTable).Row(id)
        do $$$AssertNotTrue(..Has(row.effects, "IncrementDenialCount") || ..Has(row.effects, "ResetDenialCount"), id_" leaves denialCount alone")
    }
}

Method TestAttachments()
{
    set snapshot = ..Executing()
    set command = ..Command("system", snapshot, "")
    set command.Kind = "Attach", command.AttachEvent = "ExceptionRecorded"
    set decision = ##class(SignalNoir.Core.Decider).Decide(snapshot, command, ..#NOW)
    do $$$AssertEquals(decision.Kind, "Attach", "new Exception while Executing is an attachment")
    do $$$AssertTrue(..Has(decision.RecordEffects, "IncrementPendingReassessment"), "kept for reassessment")
    do $$$AssertEquals(decision.Events.%Get(0).type, "ExceptionRecorded")

    set command = ..Command("agent", snapshot, "")
    set command.Kind = "Attach", command.AttachEvent = "ToolCalled"
    set decision = ##class(SignalNoir.Core.Decider).Decide(snapshot, command, ..#NOW)
    do $$$AssertEquals(decision.Kind_"/"_decision.RefusalCode, "Refused/INVALID_TRANSITION", "ToolCalled is not accepted while Executing")
}

Method TestInvalidTransition()
{
    set snapshot = ##class(SignalNoir.Core.CaseSnapshot).%New()
    set snapshot.CaseId = "case_open", snapshot.State = "Open", snapshot.CaseVersion = 1
    set decision = ##class(SignalNoir.Core.Decider).Decide(snapshot, ..Command("system", snapshot, "Executing"), ..#NOW)
    do $$$AssertEquals(decision.Kind_"/"_decision.RefusalCode, "Refused/INVALID_TRANSITION", "Open -> Executing")
    do $$$AssertEquals(decision.Events.%Get(0).payload.code, "INVALID_TRANSITION", "CommandDiscarded carries the code")
}

Method TestInvalidActor()
{
    set snapshot = ..Pending()
    set command = ..Command("benchmark", snapshot, "Approved")
    do command.Facts.%Set("sameStepAsValidation", 1, "boolean")
    set decision = ##class(SignalNoir.Core.Decider).Decide(snapshot, command, ..#NOW)
    do $$$AssertEquals(decision.RefusalCode, "INVALID_ACTOR", "benchmark outside a BenchmarkRun")

    set investigating = ##class(SignalNoir.Core.CaseSnapshot).%New()
    set investigating.CaseId = "case_inv", investigating.State = "Investigating", investigating.CaseVersion = 2
    set investigating.ProposerMode = "agent", investigating.StepLeaseUntil = "2026-10-26T13:00:00.000Z"
    set command = ..Command("rules", investigating, "DecisionProposed")
    do command.Facts.%Set("proposalDtoValid", 1, "boolean"), command.Facts.%Set("claimsCiteEvidence", 1, "boolean")
    set decision = ##class(SignalNoir.Core.Decider).Decide(investigating, command, ..#NOW)
    do $$$AssertEquals(decision.RefusalCode, "INVALID_ACTOR", "rules on a Case in agent mode")

    set approved = ..Approved("2026-10-26T11:00:00.000Z")
    set decision = ##class(SignalNoir.Core.Decider).Decide(approved, ..Command("system", approved, "PendingApproval"), ..#NOW)
    do $$$AssertEquals(decision.RefusalCode, "INVALID_ACTOR", "only the sweeper expires an Approval")
}

Method TestStaleVersion()
{
    set snapshot = ..Pending()
    set command = ..Command("operator:Carla", snapshot, "Approved")
    set command.TargetId = "prop_1", command.ExpectedCaseVersion = 3
    do command.Facts.%Set("decision", "approved")
    set decision = ##class(SignalNoir.Core.Decider).Decide(snapshot, command, ..#NOW)
    do $$$AssertEquals(decision.RefusalCode, "STALE_VERSION", "expected version 3, Case at 4")

    set command = ..Command("operator:Carla", snapshot, "Approved")
    set command.TargetId = "prop_old"
    do command.Facts.%Set("decision", "approved")
    set decision = ##class(SignalNoir.Core.Decider).Decide(snapshot, command, ..#NOW)
    do $$$AssertEquals(decision.RefusalCode, "STALE_VERSION", "the Proposal on screen is no longer current")
}

Method TestApprovalExpired()
{
    set approved = ..Approved("2026-10-26T11:59:59.999Z")
    set decision = ##class(SignalNoir.Core.Decider).Decide(approved, ..Command("system", approved, "Executing"), ..#NOW)
    do $$$AssertEquals(decision.Kind_"/"_decision.RefusalCode, "Refused/APPROVAL_EXPIRED", "authorization CAS with an expired Approval")
}

Method TestIdempotentApproval()
{
    set approved = ..Approved("2026-10-26T12:10:00.000Z")
    set command = ..Command("operator:Ana", approved, "Approved")
    set command.TargetId = "prop_1", command.ExpectedCaseVersion = 2
    do command.Facts.%Set("decision", "approved")
    set decision = ##class(SignalNoir.Core.Decider).Decide(approved, command, ..#NOW)
    do $$$AssertTrue(decision.IdempotentReplay, "repeat approval of the same Proposal, even with a stale version")
    do $$$AssertEquals(decision.Events.%Size() + decision.Outbox.%Size(), 0, "nothing to record")
}

ClassMethod Pending() As SignalNoir.Core.CaseSnapshot
{
    set snapshot = ##class(SignalNoir.Core.CaseSnapshot).%New()
    set snapshot.CaseId = "case_pending", snapshot.State = "PendingApproval", snapshot.CaseVersion = 4, snapshot.CurrentProposalId = "prop_1"
    quit snapshot
}

ClassMethod Approved(expiresAt As %String) As SignalNoir.Core.CaseSnapshot
{
    set snapshot = ##class(SignalNoir.Core.CaseSnapshot).%New()
    set snapshot.CaseId = "case_approved", snapshot.State = "Approved", snapshot.CaseVersion = 5, snapshot.CurrentProposalId = "prop_1"
    set snapshot.ApprovalId = "appr_1", snapshot.ApprovalProposalId = "prop_1", snapshot.ApprovalDecision = "approved", snapshot.ApprovalExpiresAt = expiresAt
    quit snapshot
}

ClassMethod Executing() As SignalNoir.Core.CaseSnapshot
{
    set snapshot = ##class(SignalNoir.Core.CaseSnapshot).%New()
    set snapshot.CaseId = "case_exec", snapshot.State = "Executing", snapshot.CaseVersion = 7
    set snapshot.ExecutionId = "exec_1", snapshot.ExecutionOutcome = "in_progress", snapshot.ExecutionAttemptsSent = 0
    quit snapshot
}

ClassMethod Command(actor As %String, snapshot As SignalNoir.Core.CaseSnapshot, target As %String) As SignalNoir.Core.TransitionCommand
{
    set command = ##class(SignalNoir.Core.TransitionCommand).%New()
    set command.Actor = actor, command.RequestedState = target
    set command.ExpectedState = snapshot.State, command.ExpectedCaseVersion = snapshot.CaseVersion
    quit command
}

ClassMethod Has(array, value As %String) As %Boolean
{
    if '$isobject(array) quit 0
    set it = array.%GetIterator()
    while it.%GetNext(.i, .item) { if item = value return 1 }
    quit 0
}

}
