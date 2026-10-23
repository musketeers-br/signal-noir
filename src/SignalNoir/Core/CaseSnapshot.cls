/// What the Core decision reads: the Case as it is now, with its latest Approval and Execution.
/// Built by the Application; carries no behavior (specs/002 data-model).
Class SignalNoir.Core.CaseSnapshot Extends %RegisteredObject
{

Property CaseId As %String;

Property OrderId As %String;

/// CaseState; empty when no Case exists yet (creation rows T01/T02).
Property State As %String;

Property CaseVersion As %Integer [ InitialExpression = 0 ];

Property DenialCount As %Integer [ InitialExpression = 0 ];

/// ISO-8601 UTC; empty when no step lease is held.
Property StepLeaseUntil As %String;

Property CurrentProposalId As %String;

/// agent, rules or replay.
Property ProposerMode As %String [ InitialExpression = "agent" ];

Property BenchmarkRunId As %String;

Property ApprovalId As %String;

Property ApprovalProposalId As %String;

/// approved or denied.
Property ApprovalDecision As %String;

Property ApprovalExpiresAt As %String;

Property ExecutionId As %String;

Property ExecutionApprovalId As %String;

/// in_progress, reconciling, resolved, held, cancelled or failed.
Property ExecutionOutcome As %String;

Property ExecutionAttemptsSent As %Integer [ InitialExpression = 0 ];

Property ExecutionInconclusiveReconciliations As %Integer [ InitialExpression = 0 ];

Property ExecutionAuthorizationVoided As %Boolean [ InitialExpression = 0 ];

/// Exceptions attached while Approved or Executing, reassessed when the Execution ends.
Property PendingReassessmentExceptions As %Integer [ InitialExpression = 0 ];

Property PreviousEpisodeCaseId As %String;

/// For creation: whether the Order's most recent Case exists and whether it is terminal.
Property PreviousCaseExists As %Boolean [ InitialExpression = 0 ];

Property PreviousCaseTerminal As %Boolean [ InitialExpression = 0 ];

}
