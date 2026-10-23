/// The closed vocabulary of precondition checks of the normative table (specs/001 data-model).
/// Each check reads only the snapshot, the command, the injected clock and the expected value.
Class SignalNoir.Core.Preconditions Extends %RegisteredObject
{

/// Checks answered by a fact the caller already recorded (Evidence, verdict, response class...).
Parameter FACTCHECKS = ",orderSnapshotRecorded,proposalDtoValid,claimsCiteEvidence,investigationFailure,verdict,requiresApproval,action,priorReceiptEvidenceRecorded,equivalenceKeysEqual,decision,sameStepAsValidation,newException,responseClass,receiptMatches,reconciliationResult,attemptsExhausted,noUncertainAttemptPending,waitConditionEnded,resolutionAction,";

/// True when the check holds. An unknown check never holds, so a row using it is never chosen
/// (the parity test then fails, which is how a vocabulary gap surfaces).
ClassMethod Holds(check As %String, expected, snapshot As SignalNoir.Core.CaseSnapshot, command As SignalNoir.Core.TransitionCommand, now As %String) As %Boolean
{
    set value = ..Resolve(expected)
    if ..#FACTCHECKS [ (","_check_",") quit ..FactMatches(command.Facts, check, value)
    if check = "state" quit snapshot.State = value
    if check = "caseVersionMatches" quit (command.ExpectedCaseVersion = snapshot.CaseVersion) = value
    if check = "noOpenCaseForOrder" quit (snapshot.State = "") = value
    if check = "previousCaseExists" quit snapshot.PreviousCaseExists = value
    if check = "previousCaseTerminal" quit (snapshot.PreviousCaseExists && snapshot.PreviousCaseTerminal) = value
    if check = "leaseValid" quit ((snapshot.StepLeaseUntil '= "") && (snapshot.StepLeaseUntil ] now)) = value
    if check = "leaseExpired" quit ((snapshot.StepLeaseUntil '= "") && '(snapshot.StepLeaseUntil ] now)) = value
    if check = "proposerMatchesMode" quit (command.Actor = snapshot.ProposerMode) = value
    if check = "proposalIsCurrent" quit ((snapshot.CurrentProposalId '= "") && (command.TargetId = snapshot.CurrentProposalId)) = value
    if check = "noExecutionInFlight" quit '..InFlight(snapshot) = value
    if check = "benchmarkRun" quit (snapshot.BenchmarkRunId '= "") = value
    if check = "denialCountBelow" quit snapshot.DenialCount < value
    if check = "denialCount" quit snapshot.DenialCount = value
    if check = "reasonPresent" quit ($zstrip(command.Facts.%Get("reason"), "<>W") '= "") = value
    if check = "approvalForCurrentProposal" quit ..ApprovedCurrent(snapshot) = value
    if check = "approvalNotExpired" quit (..ApprovedCurrent(snapshot) && (snapshot.ApprovalExpiresAt ] now)) = value
    if check = "approvalExpired" quit (..ApprovedCurrent(snapshot) && '(snapshot.ApprovalExpiresAt ] now)) = value
    if check = "noAuthorization" quit ((snapshot.ExecutionId = "") || (snapshot.ExecutionApprovalId '= snapshot.ApprovalId)) = value
    if check = "executionOutcome" quit (snapshot.ExecutionId '= "") && (snapshot.ExecutionOutcome = value)
    if check = "noAttemptSent" quit (snapshot.ExecutionAttemptsSent = 0) = value
    if check = "revalidationFailed" quit ..AnyFailed(command.Facts.%Get("revalidationFailed"), value)
    if check = "inconclusiveReconciliations" {
        set rounds = snapshot.ExecutionInconclusiveReconciliations + (command.Facts.%Get("reconciliationResult") = "inconclusive")
        quit rounds >= value
    }
    quit 0
}

/// Precondition values may name a table parameter (e.g. maxDenials).
ClassMethod Resolve(expected)
{
    if $isobject(expected) quit expected
    set parameter = ##class(SignalNoir.Core.TransitionTable).Parameter(expected)
    quit $select(parameter '= "": parameter, 1: expected)
}

ClassMethod FactMatches(facts As %DynamicObject, name As %String, expected) As %Boolean
{
    if '$isobject(facts) || 'facts.%IsDefined(name) quit 0
    set actual = facts.%Get(name)
    if '$isobject(expected) quit actual = expected
    set it = expected.%GetIterator()
    while it.%GetNext(.i, .option) { if actual = option return 1 }
    quit 0
}

/// True when any failed Revalidation check is one of the expected ones.
ClassMethod AnyFailed(failed, expected) As %Boolean
{
    if '$isobject(failed) quit 0
    set it = failed.%GetIterator()
    while it.%GetNext(.i, .check) {
        if '$isobject(expected) {
            if check = expected return 1
        } else {
            set eit = expected.%GetIterator()
            while eit.%GetNext(.j, .option) { if check = option return 1 }
        }
    }
    quit 0
}

ClassMethod InFlight(snapshot As SignalNoir.Core.CaseSnapshot) As %Boolean
{
    quit (snapshot.ExecutionOutcome = "in_progress") || (snapshot.ExecutionOutcome = "reconciling")
}

ClassMethod ApprovedCurrent(snapshot As SignalNoir.Core.CaseSnapshot) As %Boolean
{
    quit (snapshot.ApprovalDecision = "approved") && (snapshot.CurrentProposalId '= "") && (snapshot.ApprovalProposalId = snapshot.CurrentProposalId)
}

}
