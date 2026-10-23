/// The only way to change a Case (AD-2, specs/002 contracts/command-path.md). Reads the Case, asks
/// the Core, and records the decision in one short transaction with no external I/O: state with a
/// compare-and-swap (AD-3), Timeline events and outbox entries (AD-20), or CommandDiscarded.
Class SignalNoir.Application.CaseCommands Extends %RegisteredObject
{

/// Step lease written by SetStepLease, in seconds. Provisional: AD-22 fixes it at startup as
/// greater than the Partner timeout plus the Investigation budget.
Parameter STEPLEASESECONDS = 120;

/// Applies a command to an existing Case.
ClassMethod Submit(caseId As %String, command As SignalNoir.Core.TransitionCommand) As SignalNoir.Application.CommandResult
{
    set result = ##class(SignalNoir.Application.CommandResult).%New()
    set result.CaseId = caseId
    try {
        set now = ..Now()
        set case = ##class(SignalNoir.Application.Store.Case).%OpenId(caseId, 0)
        if '$isobject(case) {
            set result.Outcome = "Failed", result.FailureText = "Case "_caseId_" not found"
            quit
        }
        set snapshot = ..Snapshot(case)
        set decision = ##class(SignalNoir.Core.Decider).Decide(snapshot, command, now)
        do ..Record(case, snapshot, command, decision, now, result)
    } catch error {
        do ..Fail(result, error.DisplayString())
    }
    quit result
}

/// Records an Exception for an Order: opens a Case (T01, or T02 after a terminal Case), moves a
/// Case in PendingApproval back to Investigating (T16), or attaches it (D1).
ClassMethod RecordException(orderId As %String, exception As %DynamicObject, actor As %String) As SignalNoir.Application.CommandResult
{
    set result = ##class(SignalNoir.Application.CommandResult).%New()
    try {
        for attempt = 1, 2 {
            set now = ..Now()
            set facts = {"newException": true, "exception": (exception)}
            set openId = ..OpenCaseId(orderId)
            if openId '= "" {
                set case = ##class(SignalNoir.Application.Store.Case).%OpenId(openId, 0)
                set snapshot = ..Snapshot(case)
                set command = ..NewCommand(actor, snapshot, "", facts)
                set command.AttachEvent = "ExceptionRecorded"
                set result.CaseId = openId
                do ..Record(case, snapshot, command, ##class(SignalNoir.Core.Decider).Decide(snapshot, command, now), now, result)
                // Lost the compare-and-swap to another writer: read again so the Exception is not lost.
                if (attempt = 1) && (result.RefusalCode = "STALE_VERSION") { set result = ##class(SignalNoir.Application.CommandResult).%New()  continue }
                quit
            }
            set snapshot = ..CreationSnapshot(orderId)
            // A first Exception opens a Case; newException applies only to an existing one (D1).
            set facts = {"orderSnapshotRecorded": true, "exception": (exception)}
            set command = ..NewCommand(actor, snapshot, "Open", facts)
            set decision = ##class(SignalNoir.Core.Decider).Decide(snapshot, command, now)
            if ..Open(orderId, snapshot, command, decision, now, result) quit
            // Lost the unique OpenOrderKey to a concurrent first Exception: attach to the winner.
            set result = ##class(SignalNoir.Application.CommandResult).%New()
        }
    } catch error {
        do ..Fail(result, error.DisplayString())
    }
    quit result
}

// ---------- recording ----------

ClassMethod Record(case As SignalNoir.Application.Store.Case, snapshot As SignalNoir.Core.CaseSnapshot, command As SignalNoir.Core.TransitionCommand, decision As SignalNoir.Core.Decision, now As %String, result As SignalNoir.Application.CommandResult)
{
    set result.CaseId = case.CaseId
    if decision.Kind = "Refused" {
        do ..Refuse(case, command, decision, now, result)
        quit
    }
    if decision.IdempotentReplay {
        set result.Outcome = "IdempotentReplay", result.State = case.State, result.CaseVersion = case.CaseVersion
        quit
    }
    tstart
    try {
        if decision.Kind = "Attach" {
            do ..ApplyEffects(case, command, decision, now, result)
            do ..AppendEvents(case.CaseId, command, decision, result, now)
            do ..QueueOutbox(case, command, decision, now, result)
            set case.LastEventAt = now
            $$$ThrowOnError(case.%Save())
            set result.Outcome = "Attached"
        } else {
            if '..Apply(case, snapshot, command, decision, now, result) {
                trollback 1
                do case.%Reload()
                do ..Refuse(case, command, ##class(SignalNoir.Core.Decision).Refused("STALE_VERSION", snapshot, command), now, result)
                quit
            }
            do ..Chain(case, command, decision, now, result)
            set result.Outcome = "Applied"
        }
        tcommit
        set result.State = case.State, result.CaseVersion = case.CaseVersion
    } catch error {
        trollback:$tlevel 1
        // The caller may hold the same in-memory Case; bring it back to what is stored.
        do case.%Reload()
        do ..Fail(result, error.DisplayString())
    }
}

/// Applies one accepted transition inside the open transaction. Returns 0 when the
/// compare-and-swap loses (another writer committed first).
ClassMethod Apply(case As SignalNoir.Application.Store.Case, snapshot As SignalNoir.Core.CaseSnapshot, command As SignalNoir.Core.TransitionCommand, decision As SignalNoir.Core.Decision, now As %String, result As SignalNoir.Application.CommandResult) As %Boolean
{
    set caseId = case.CaseId, from = snapshot.State, version = snapshot.CaseVersion
    set to = decision.ToState, after = version + 1
    &sql(UPDATE SignalNoir_Application_Store.CaseRecord SET State = :to, CaseVersion = :after, LastEventAt = :now
         WHERE CaseId = :caseId AND CaseVersion = :version AND State = :from)
    if SQLCODE = 100 quit 0
    if SQLCODE < 0 $$$ThrowStatus($$$ERROR($$$SQLError, SQLCODE, $get(%msg)))
    do result.Transitions.%Push(decision.TransitionId)
    do case.%Reload()
    do ..ApplyEffects(case, command, decision, now, result)
    $$$ThrowOnError(case.%Save())
    do ..AppendEvents(caseId, command, decision, result, now)
    do ..QueueOutbox(case, command, decision, now, result)
    quit 1
}

/// Same-step chains the table declares (sameStepAs): the Validator step after an Operator
/// resolution (T28 -> T07/T08), the Operator's own Approval after it (T07 -> T11), and the
/// Benchmark Automatic Approval in a BenchmarkRun (T07 -> T12).
ClassMethod Chain(case As SignalNoir.Application.Store.Case, command As SignalNoir.Core.TransitionCommand, decision As SignalNoir.Core.Decision, now As %String, result As SignalNoir.Application.CommandResult, origin As SignalNoir.Core.TransitionCommand = "")
{
    // origin: the command that started the chain (the Operator's resolution, for T07 -> T11).
    set:origin="" origin = command
    set next = ""
    if decision.TransitionId = "T28" {
        set next = ..NewCommand("system", ..Snapshot(case), "", command.Facts)
        set next.TargetId = case.CurrentProposalId
    } elseif (decision.TransitionId = "T07") && (result.Transitions.%Get(0) = "T28") {
        set next = ..NewCommand(origin.Actor, ..Snapshot(case), "Approved", {"decision": "approved"})
        set next.TargetId = case.CurrentProposalId
    } elseif (decision.TransitionId = "T07") && (case.BenchmarkRunId '= "") {
        set next = ..NewCommand("benchmark", ..Snapshot(case), "Approved", {"sameStepAsValidation": true})
    }
    quit:next=""
    set next.Command = origin.Command
    set next.CommandId = command.CommandId
    set snapshot = ..Snapshot(case)
    set chained = ##class(SignalNoir.Core.Decider).Decide(snapshot, next, now)
    if chained.Kind '= "Accepted" $$$ThrowStatus($$$ERROR($$$GeneralError, "Chained step after "_decision.TransitionId_" refused: "_chained.RefusalCode))
    if '..Apply(case, snapshot, next, chained, now, result) $$$ThrowStatus($$$ERROR($$$GeneralError, "Chained step lost its compare-and-swap"))
    do ..Chain(case, next, chained, now, result, origin)
}

ClassMethod ApplyEffects(case As SignalNoir.Application.Store.Case, command As SignalNoir.Core.TransitionCommand, decision As SignalNoir.Core.Decision, now As %String, result As SignalNoir.Application.CommandResult)
{
    set it = decision.RecordEffects.%GetIterator()
    while it.%GetNext(.i, .effect) {
        set name = $piece(effect, ":"), argument = $piece(effect, ":", 2)
        if name = "SetStepLease" { set case.StepLeaseUntil = ..AddSeconds(now, ..#STEPLEASESECONDS) }
        elseif name = "ClearStepLease" { set case.StepLeaseUntil = "" }
        elseif name = "SetCurrentProposal" { set case.CurrentProposalId = command.Facts.%Get("proposalId") }
        elseif name = "ClearCurrentProposal" { set case.CurrentProposalId = "" }
        elseif name = "IncrementDenialCount" { set case.DenialCount = case.DenialCount + 1 }
        elseif name = "IncrementPendingReassessment" { set case.PendingReassessmentExceptions = case.PendingReassessmentExceptions + 1 }
        elseif name = "ClearPendingReassessment" { set case.PendingReassessmentExceptions = 0 }
        elseif name = "RecordApproval" { do ..RecordApproval(case, command, argument, now) }
        elseif name = "CreateExecution" { do ..CreateExecution(case, now) }
        elseif name = "CloseExecution" { do ..UpdateExecution(case, "Outcome", argument) }
        elseif name = "SetExecutionOutcome" { do ..UpdateExecution(case, "Outcome", argument) }
        elseif name = "VoidAuthorization" { do ..UpdateExecution(case, "AuthorizationVoided", 1) }
        elseif name = "IncrementAttemptsSent" { do ..UpdateExecution(case, "AttemptsSent", "+1") }
        elseif name = "IncrementInconclusive" { do ..UpdateExecution(case, "InconclusiveReconciliations", "+1") }
        elseif name = "OpenNewEpisodeIfPending" { do ..OpenNewEpisodeIfPending(case, command, now, result) }
        else { $$$ThrowStatus($$$ERROR($$$GeneralError, "Unknown record effect "_effect)) }
    }
}

ClassMethod RecordApproval(case As SignalNoir.Application.Store.Case, command As SignalNoir.Core.TransitionCommand, decision As %String, now As %String)
{
    set approval = ##class(SignalNoir.Application.Store.Approval).%New()
    set approval.ApprovalId = ##class(SignalNoir.Application.Store.Approval).NewId()
    set approval.CaseId = case.CaseId
    set approval.ProposalId = $select(command.TargetId '= "": command.TargetId, 1: case.CurrentProposalId)
    set approval.Decision = decision, approval.ByActor = command.Actor, approval.At = now
    set approval.Reason = command.Facts.%Get("reason")
    if decision = "approved" set approval.ExpiresAt = ..AddSeconds(now, ..DurationSeconds(##class(SignalNoir.Core.TransitionTable).Parameter("approvalTtl")))
    $$$ThrowOnError(approval.%Save())
    set case.CurrentApprovalId = approval.ApprovalId
}

ClassMethod CreateExecution(case As SignalNoir.Application.Store.Case, now As %String)
{
    set execution = ##class(SignalNoir.Application.Store.Execution).%New()
    set execution.ExecutionId = ##class(SignalNoir.Application.Store.Execution).NewId()
    set execution.CaseId = case.CaseId, execution.ProposalId = case.CurrentProposalId
    set execution.ApprovalId = $select(case.State = "Executing": case.CurrentApprovalId, 1: "")
    set execution.AuthorizedAt = now
    $$$ThrowOnError(execution.%Save())
    set case.CurrentExecutionId = execution.ExecutionId, case.StepLeaseUntil = ..AddSeconds(now, ..#STEPLEASESECONDS)
}

/// Sets a field of the Case's current Execution; "+1" increments it.
ClassMethod UpdateExecution(case As SignalNoir.Application.Store.Case, field As %String, value As %String)
{
    set execution = ##class(SignalNoir.Application.Store.Execution).%OpenId(case.CurrentExecutionId)
    if '$isobject(execution) $$$ThrowStatus($$$ERROR($$$GeneralError, "Case "_case.CaseId_" has no current Execution"))
    set $property(execution, field) = $select(value = "+1": $property(execution, field) + 1, 1: value)
    $$$ThrowOnError(execution.%Save())
}

/// T25: when Exceptions were attached during Approved/Executing, the new episode opens with them
/// in the same transaction (D2). Runs inside the caller's transaction, after the Case became Failed.
ClassMethod OpenNewEpisodeIfPending(case As SignalNoir.Application.Store.Case, command As SignalNoir.Core.TransitionCommand, now As %String, result As SignalNoir.Application.CommandResult)
{
    set pending = case.PendingReassessmentExceptions
    quit:pending=0
    set case.PendingReassessmentExceptions = 0
    $$$ThrowOnError(case.%Save())
    set snapshot = ..CreationSnapshot(case.OrderId)
    set facts = {"orderSnapshotRecorded": true, "exception": {"reassessedFrom": (case.CaseId), "count": (pending)}}
    set open = ..NewCommand("system", snapshot, "Open", facts)
    set open.CommandId = $select(command.CommandId '= "": command.CommandId_".episode", 1: "")
    set inner = ##class(SignalNoir.Application.CommandResult).%New()
    if '..Open(case.OrderId, snapshot, open, ##class(SignalNoir.Core.Decider).Decide(snapshot, open, now), now, inner) || (inner.Outcome '= "Applied") {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "New episode after "_case.CaseId_" not opened: "_inner.Outcome_" "_inner.RefusalCode_inner.FailureText))
    }
    for k = 0:1:inner.Transitions.%Size() - 1 { do result.Transitions.%Push(inner.Transitions.%Get(k)) }
    for k = 0:1:inner.OutboxCommandIds.%Size() - 1 { do result.OutboxCommandIds.%Push(inner.OutboxCommandIds.%Get(k)) }
}

ClassMethod AppendEvents(caseId As %String, command As SignalNoir.Core.TransitionCommand, decision As SignalNoir.Core.Decision, result As SignalNoir.Application.CommandResult, now As %String)
{
    set it = decision.Events.%GetIterator()
    while it.%GetNext(.i, .event) {
        set refId = $select(decision.TransitionId '= "": decision.TransitionId, 1: command.TargetId)
        $$$ThrowOnError(##class(SignalNoir.Application.Store.TimelineEvent).Append(caseId, event.type, command.Actor, refId, event.payload.%ToJSON(), .stored, now))
        do result.Events.%Push(stored.Seq)
    }
}

ClassMethod QueueOutbox(case As SignalNoir.Application.Store.Case, command As SignalNoir.Core.TransitionCommand, decision As SignalNoir.Core.Decision, now As %String, result As SignalNoir.Application.CommandResult)
{
    set it = decision.Outbox.%GetIterator()
    while it.%GetNext(.i, .kind) {
        set entry = ##class(SignalNoir.Application.Store.OutboxEntry).%New()
        set entry.CommandId = $select(command.CommandId '= "": command.CommandId_"."_(result.OutboxCommandIds.%Size() + 1), 1: ##class(SignalNoir.Application.Store.OutboxEntry).NewCommandId())
        set entry.Kind = kind, entry.CaseId = case.CaseId, entry.CaseVersionAfter = case.CaseVersion, entry.CreatedAt = now
        $$$ThrowOnError(entry.%Save())
        do result.OutboxCommandIds.%Push(entry.CommandId)
    }
}

/// Records CommandDiscarded in its own short transaction; state and version stay as they are.
ClassMethod Refuse(case As SignalNoir.Application.Store.Case, command As SignalNoir.Core.TransitionCommand, decision As SignalNoir.Core.Decision, now As %String, result As SignalNoir.Application.CommandResult)
{
    tstart
    try {
        do ..AppendEvents(case.CaseId, command, decision, result, now)
        tcommit
        set result.Outcome = "Refused", result.RefusalCode = decision.RefusalCode
        set stored = ##class(SignalNoir.Application.Store.Case).%OpenId(case.CaseId, 0)
        set result.State = stored.State, result.CaseVersion = stored.CaseVersion
    } catch error {
        trollback:$tlevel 1
        do ..Fail(result, error.DisplayString())
    }
}

/// Opens a new Case for T01/T02. Returns 0 when the unique OpenOrderKey was taken by a
/// concurrent first Exception, so the caller retries as an attachment.
ClassMethod Open(orderId As %String, snapshot As SignalNoir.Core.CaseSnapshot, command As SignalNoir.Core.TransitionCommand, decision As SignalNoir.Core.Decision, now As %String, result As SignalNoir.Application.CommandResult) As %Boolean
{
    if decision.Kind '= "Accepted" {
        set result.Outcome = "Refused", result.RefusalCode = decision.RefusalCode
        quit 1
    }
    tstart
    try {
        set case = ##class(SignalNoir.Application.Store.Case).%New()
        set case.CaseId = ##class(SignalNoir.Application.Store.Case).NewId()
        set case.OrderId = orderId, case.State = decision.ToState, case.CaseVersion = 1
        set case.CreatedAt = now, case.LastEventAt = now
        if decision.TransitionId = "T02" set case.PreviousEpisodeCaseId = snapshot.PreviousEpisodeCaseId
        set sc = case.%Save()
        if $$$ERRORISTYPE(sc, $$$KeyNotUnique) || $$$ERRORISTYPE(sc, $$$IDKeyNotUnique) {
            trollback 1
            quit
        }
        $$$ThrowOnError(sc)
        do ..AppendEvents(case.CaseId, command, decision, result, now)
        do ..QueueOutbox(case, command, decision, now, result)
        if decision.TransitionId = "T02" do ..LinkPreviousEpisode(case, command, now, result)
        do result.Transitions.%Push(decision.TransitionId)
        tcommit
        set result.Outcome = "Applied", result.CaseId = case.CaseId, result.State = case.State, result.CaseVersion = case.CaseVersion
    } catch error {
        trollback:$tlevel 1
        do ..Fail(result, error.DisplayString())
    }
    quit result.Outcome '= ""
}

/// T02: the previous Case gains only a new_episode_opened annotation (no state or version change),
/// decided by the Core like any attachment. Runs inside the transaction that opens the new Case.
ClassMethod LinkPreviousEpisode(case As SignalNoir.Application.Store.Case, command As SignalNoir.Core.TransitionCommand, now As %String, result As SignalNoir.Application.CommandResult)
{
    set previous = ##class(SignalNoir.Application.Store.Case).%OpenId(case.PreviousEpisodeCaseId)
    if '$isobject(previous) $$$ThrowStatus($$$ERROR($$$GeneralError, "Previous episode "_case.PreviousEpisodeCaseId_" not found"))
    set snapshot = ..Snapshot(previous)
    set annotate = ..NewCommand("system", snapshot, "", {"kind": "new_episode_opened", "newCaseId": (case.CaseId)})
    set annotate.Kind = "Attach", annotate.AttachEvent = "Annotation"
    set decision = ##class(SignalNoir.Core.Decider).Decide(snapshot, annotate, now)
    if decision.Kind '= "Attach" $$$ThrowStatus($$$ERROR($$$GeneralError, "Annotation on "_previous.CaseId_" refused: "_decision.RefusalCode))
    set ignored = ##class(SignalNoir.Application.CommandResult).%New()
    do ..AppendEvents(previous.CaseId, annotate, decision, ignored, now)
    set previous.LastEventAt = now
    $$$ThrowOnError(previous.%Save())
}

// ---------- reading ----------

ClassMethod Snapshot(case As SignalNoir.Application.Store.Case) As SignalNoir.Core.CaseSnapshot
{
    set snapshot = ##class(SignalNoir.Core.CaseSnapshot).%New()
    set snapshot.CaseId = case.CaseId, snapshot.OrderId = case.OrderId, snapshot.State = case.State
    set snapshot.CaseVersion = case.CaseVersion, snapshot.DenialCount = case.DenialCount
    set snapshot.StepLeaseUntil = case.StepLeaseUntil, snapshot.CurrentProposalId = case.CurrentProposalId
    set snapshot.ProposerMode = case.ProposerMode, snapshot.BenchmarkRunId = case.BenchmarkRunId
    set snapshot.PendingReassessmentExceptions = case.PendingReassessmentExceptions
    set snapshot.PreviousEpisodeCaseId = case.PreviousEpisodeCaseId
    set approval = $select(case.CurrentApprovalId = "": "", 1: ##class(SignalNoir.Application.Store.Approval).%OpenId(case.CurrentApprovalId, 0))
    if $isobject(approval) {
        set snapshot.ApprovalId = approval.ApprovalId, snapshot.ApprovalProposalId = approval.ProposalId
        set snapshot.ApprovalDecision = approval.Decision, snapshot.ApprovalExpiresAt = approval.ExpiresAt
    }
    set execution = $select(case.CurrentExecutionId = "": "", 1: ##class(SignalNoir.Application.Store.Execution).%OpenId(case.CurrentExecutionId, 0))
    if $isobject(execution) {
        set snapshot.ExecutionId = execution.ExecutionId, snapshot.ExecutionApprovalId = execution.ApprovalId
        set snapshot.ExecutionOutcome = execution.Outcome, snapshot.ExecutionAttemptsSent = execution.AttemptsSent
        set snapshot.ExecutionInconclusiveReconciliations = execution.InconclusiveReconciliations
        set snapshot.ExecutionAuthorizationVoided = execution.AuthorizationVoided
    }
    quit snapshot
}

/// Snapshot for an Order with no non-terminal Case: whether a previous Case exists and is terminal.
ClassMethod CreationSnapshot(orderId As %String) As SignalNoir.Core.CaseSnapshot
{
    set snapshot = ##class(SignalNoir.Core.CaseSnapshot).%New()
    set snapshot.OrderId = orderId, snapshot.State = "", snapshot.CaseVersion = 0
    &sql(SELECT TOP 1 CaseId, State INTO :previousId, :previousState FROM SignalNoir_Application_Store.CaseRecord WHERE OrderId = :orderId ORDER BY CreatedAt DESC, CaseId DESC)
    if SQLCODE = 0 {
        set snapshot.PreviousCaseExists = 1, snapshot.PreviousEpisodeCaseId = previousId
        set snapshot.PreviousCaseTerminal = ##class(SignalNoir.Core.TransitionTable).IsTerminal(previousState)
    }
    quit snapshot
}

ClassMethod OpenCaseId(orderId As %String) As %String
{
    &sql(SELECT CaseId INTO :caseId FROM SignalNoir_Application_Store.CaseRecord WHERE OpenOrderKey = :orderId)
    quit $select(SQLCODE = 0: caseId, 1: "")
}

ClassMethod NewCommand(actor As %String, snapshot As SignalNoir.Core.CaseSnapshot, target As %String, facts As %DynamicObject) As SignalNoir.Core.TransitionCommand
{
    set command = ##class(SignalNoir.Core.TransitionCommand).%New()
    set command.Actor = actor, command.RequestedState = target
    set command.ExpectedState = snapshot.State, command.ExpectedCaseVersion = snapshot.CaseVersion
    set command.Facts = facts
    quit command
}

// ---------- helpers ----------

ClassMethod Fail(result As SignalNoir.Application.CommandResult, text As %String)
{
    set result.Outcome = "Failed", result.FailureText = text
}

/// The clock, read once per command and passed to the Core (specs/002 research R8).
ClassMethod Now() As %String
{
    quit $zdatetime($ztimestamp, 3, 7, 3)
}

ClassMethod AddSeconds(iso As %String, seconds As %Integer) As %String
{
    set h = $zdatetimeh(iso, 3, 7)
    set day = +h, time = $piece(h, ",", 2) + seconds
    set day = day + (time \ 86400), time = time # 86400
    quit $zdatetime(day_","_time, 3, 7, 3)
}

/// Seconds of an ISO-8601 duration with hours, minutes and seconds (e.g. PT15M, PT60S).
ClassMethod DurationSeconds(duration As %String) As %Integer
{
    set rest = $piece(duration, "T", 2), total = 0
    for unit = "H", "M", "S" {
        if rest [ unit { set total = total + ($piece(rest, unit) * $case(unit, "H": 3600, "M": 60, : 1))  set rest = $piece(rest, unit, 2) }
    }
    quit total
}

}
