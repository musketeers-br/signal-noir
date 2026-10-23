/// The single decision of the Case state machine (specs/002 contracts/core-port.md): given the Case
/// as it is, a command and the current time, answer Accepted, Refused or Attach. Pure: no storage,
/// network or clock of its own (Constitution Principle I).
Class SignalNoir.Core.Decider Extends %RegisteredObject
{

/// Revalidation exits, strongest first (D3).
Parameter REVALIDATIONPRECEDENCE = "Cancelled,Investigating,Held";

ClassMethod Decide(snapshot As SignalNoir.Core.CaseSnapshot, command As SignalNoir.Core.TransitionCommand, now As %String) As SignalNoir.Core.Decision
{
    if command.Kind = "Attach" quit ..Attach(snapshot, command)
    if ..IsRepeatApproval(snapshot, command) {
        set decision = ##class(SignalNoir.Core.Decision).%New()
        set decision.Kind = "Accepted", decision.IdempotentReplay = 1
        set decision.FromState = snapshot.State, decision.ToState = snapshot.State
        quit decision
    }
    if ..IsStale(snapshot, command) quit ##class(SignalNoir.Core.Decision).Refused("STALE_VERSION", snapshot, command)

    set candidates = ##class(SignalNoir.Core.TransitionTable).Rows(snapshot.State, command.RequestedState)
    if command.Facts.%Get("newException") set candidates = ..ExceptionRows(candidates)
    if candidates.%Size() = 0 quit ..NoRow(snapshot, command)

    set allowed = []
    set it = candidates.%GetIterator()
    while it.%GetNext(.i, .row) { do:..ActorAllowed(row, snapshot, command) allowed.%Push(row) }
    if allowed.%Size() = 0 {
        if command.AttachEvent '= "" quit ..Attach(snapshot, command)
        quit ##class(SignalNoir.Core.Decision).Refused("INVALID_ACTOR", snapshot, command)
    }

    set matches = []
    set it = allowed.%GetIterator()
    while it.%GetNext(.i, .row) { do:..AllHold(row, snapshot, command, now) matches.%Push(row) }
    if matches.%Size() = 0 {
        if ..OnlyApprovalExpired(allowed, snapshot, command, now) quit ##class(SignalNoir.Core.Decision).Refused("APPROVAL_EXPIRED", snapshot, command)
        quit ..NoRow(snapshot, command)
    }
    if matches.%Size() = 1 quit ..Accept(matches.%Get(0), snapshot, command)

    set winner = ..ByPrecedence(matches)
    if winner '= "" quit ..Accept(winner, snapshot, command)
    set decision = ##class(SignalNoir.Core.Decision).Refused("INVALID_TRANSITION", snapshot, command)
    set decision.TableDefect = 1
    quit decision
}

/// A repeated approval of a Proposal already approved, once the Case has moved on: the existing
/// Approval stands and nothing is recorded (specs/001 FR-014). Checked before the version, so an
/// old screen gets the idempotent answer. In PendingApproval the earlier Approval has expired (T18)
/// and a new one is a real transition.
ClassMethod IsRepeatApproval(snapshot As SignalNoir.Core.CaseSnapshot, command As SignalNoir.Core.TransitionCommand) As %Boolean
{
    quit (command.RequestedState = "Approved") && (command.Facts.%Get("decision") = "approved") && (command.TargetId '= "") && (snapshot.State '= "PendingApproval") && (snapshot.ApprovalDecision = "approved") && (snapshot.ApprovalProposalId = command.TargetId)
}

/// The command was built from a Case that has since changed: state, version or target differ.
ClassMethod IsStale(snapshot As SignalNoir.Core.CaseSnapshot, command As SignalNoir.Core.TransitionCommand) As %Boolean
{
    if (command.ExpectedState '= snapshot.State) || (command.ExpectedCaseVersion '= snapshot.CaseVersion) quit 1
    if ($extract(command.TargetId, 1, 5) = "prop_") && (command.TargetId '= snapshot.CurrentProposalId) quit 1
    if ($extract(command.TargetId, 1, 5) = "exec_") && (command.TargetId '= snapshot.ExecutionId) quit 1
    quit 0
}

/// The row lists the actor (operator:* stands for any Operator); a proposer must be the Case's
/// mode and benchmark needs a BenchmarkRun (FR-013).
ClassMethod ActorAllowed(row As %DynamicObject, snapshot As SignalNoir.Core.CaseSnapshot, command As SignalNoir.Core.TransitionCommand) As %Boolean
{
    set actor = command.Actor
    if ((actor = "agent") || (actor = "rules") || (actor = "replay")) && (actor '= snapshot.ProposerMode) quit 0
    if (actor = "benchmark") && (snapshot.BenchmarkRunId = "") quit 0
    set it = row.actors.%GetIterator()
    while it.%GetNext(.i, .listed) {
        if (listed = actor) || ((listed = "operator:*") && ($extract(actor, 1, 9) = "operator:")) return 1
    }
    quit 0
}

/// The authorization CAS (T17) fails only because the Approval expired: the Execution BO refuses
/// with APPROVAL_EXPIRED and leaves expiring to the sweeper (FR-007).
ClassMethod OnlyApprovalExpired(rows As %DynamicArray, snapshot As SignalNoir.Core.CaseSnapshot, command As SignalNoir.Core.TransitionCommand, now As %String) As %Boolean
{
    set it = rows.%GetIterator()
    while it.%GetNext(.i, .row) {
        set failing = "", pit = row.preconditions.%GetIterator()
        while pit.%GetNext(.j, .pre) {
            if '##class(SignalNoir.Core.Preconditions).Holds(pre.check, pre.%Get("expected"), snapshot, command, now) set failing = failing_","_pre.check
        }
        if failing = ",approvalNotExpired" return 1
    }
    quit 0
}

/// No row applies: attach the command's fallback event if it has one, else refuse.
ClassMethod NoRow(snapshot As SignalNoir.Core.CaseSnapshot, command As SignalNoir.Core.TransitionCommand) As SignalNoir.Core.Decision
{
    if command.AttachEvent '= "" quit ..Attach(snapshot, command)
    quit ##class(SignalNoir.Core.Decision).Refused("INVALID_TRANSITION", snapshot, command)
}

/// D1: a new Exception may only fire rows that declare the newException precondition.
ClassMethod ExceptionRows(rows As %DynamicArray) As %DynamicArray
{
    set out = [], it = rows.%GetIterator()
    while it.%GetNext(.i, .row) {
        set pit = row.preconditions.%GetIterator()
        while pit.%GetNext(.j, .pre) { if pre.check = "newException" { do out.%Push(row)  quit } }
    }
    quit out
}

ClassMethod AllHold(row As %DynamicObject, snapshot As SignalNoir.Core.CaseSnapshot, command As SignalNoir.Core.TransitionCommand, now As %String) As %Boolean
{
    set it = row.preconditions.%GetIterator()
    while it.%GetNext(.i, .pre) {
        if '##class(SignalNoir.Core.Preconditions).Holds(pre.check, pre.%Get("expected"), snapshot, command, now) return 0
    }
    quit 1
}

/// Several Revalidation exits hold at once: the strongest wins (D3). Anything else is a defect.
ClassMethod ByPrecedence(matches As %DynamicArray) As %DynamicObject
{
    set it = matches.%GetIterator()
    while it.%GetNext(.i, .row) {
        set revalidation = 0, pit = row.preconditions.%GetIterator()
        while pit.%GetNext(.j, .pre) { set:pre.check="revalidationFailed" revalidation = 1 }
        if 'revalidation return ""
    }
    for k = 1:1:$length(..#REVALIDATIONPRECEDENCE, ",") {
        set target = $piece(..#REVALIDATIONPRECEDENCE, ",", k)
        set it = matches.%GetIterator()
        while it.%GetNext(.i, .row) { if row.to = target return row }
    }
    quit ""
}

ClassMethod Accept(row As %DynamicObject, snapshot As SignalNoir.Core.CaseSnapshot, command As SignalNoir.Core.TransitionCommand) As SignalNoir.Core.Decision
{
    set decision = ##class(SignalNoir.Core.Decision).%New()
    set decision.Kind = "Accepted", decision.TransitionId = row.id
    set decision.FromState = snapshot.State, decision.ToState = row.to
    set changed = {"from": (snapshot.State), "to": (row.to), "reason": (row.reason), "caseVersionAfter": (snapshot.CaseVersion + 1)}
    do decision.Events.%Push({"type": "StateChanged", "payload": (changed)})
    set it = row.events.%GetIterator()
    while it.%GetNext(.i, .type) { do decision.Events.%Push({"type": (type), "payload": {"transitionId": (row.id), "facts": (command.Facts)}}) }
    set decision.RecordEffects = row.effects, decision.Outbox = row.outbox, decision.SameStep = row.sameStepAs
    quit decision
}

/// Attachments: allowed per state by the table; terminal Cases take only the listed annotations.
ClassMethod Attach(snapshot As SignalNoir.Core.CaseSnapshot, command As SignalNoir.Core.TransitionCommand) As SignalNoir.Core.Decision
{
    set event = command.AttachEvent, state = snapshot.State, facts = command.Facts
    if '##class(SignalNoir.Core.TransitionTable).AttachmentAllowed(event, state) quit ##class(SignalNoir.Core.Decision).Refused("INVALID_TRANSITION", snapshot, command)
    if ##class(SignalNoir.Core.TransitionTable).IsTerminal(state) && (event = "Annotation") {
        set allowed = 0, it = ##class(SignalNoir.Core.TransitionTable).TerminalKinds(event).%GetIterator()
        while it.%GetNext(.i, .kind) { set:kind=facts.%Get("kind") allowed = 1 }
        if 'allowed quit ##class(SignalNoir.Core.Decision).Refused("INVALID_TRANSITION", snapshot, command)
    }
    set decision = ##class(SignalNoir.Core.Decision).%New()
    set decision.Kind = "Attach", decision.FromState = state, decision.ToState = state
    do decision.Events.%Push({"type": (event), "payload": {"facts": (facts)}})
    if (event = "ExceptionRecorded") && ((state = "Approved") || (state = "Executing")) do decision.RecordEffects.%Push("IncrementPendingReassessment")
    if event = "AttemptRecorded" {
        do decision.RecordEffects.%Push("IncrementAttemptsSent")
        if facts.%Get("responseClass") = "uncertain" { do decision.RecordEffects.%Push("SetExecutionOutcome:reconciling")  do decision.Outbox.%Push("Reconcile") }
    }
    if event = "ReconciliationPerformed" {
        set result = facts.%Get("reconciliationResult")
        if result = "inconclusive" { do decision.RecordEffects.%Push("IncrementInconclusive") }
        elseif state = "Executing" { do:result="not_delivered" decision.RecordEffects.%Push("SetExecutionOutcome:in_progress") }
        elseif result = "receipt_found" { do decision.RecordEffects.%Push("CloseExecution:resolved") }
        elseif result = "not_delivered" { do decision.RecordEffects.%Push("CloseExecution:failed") }
    }
    quit decision
}

}
