/// A request to change a Case: a transition (target named, or chosen by the table when
/// RequestedState is empty) or an attachment (specs/002 data-model, contracts/core-port.md).
Class SignalNoir.Core.TransitionCommand Extends %RegisteredObject
{

Property CommandId As %String;

/// Transition or Attach.
Property Kind As %String [ InitialExpression = "Transition" ];

/// Target CaseState; empty lets the table pick the only row whose actor and preconditions match.
Property RequestedState As %String;

/// Work item or API command that carries this request (Investigate, Execute, Reconcile, Expire,
/// Reassess, Resume, decideProposal, resolveReview); informational.
Property Command As %String;

/// For Kind = Attach: the event to attach. For a transition with no matching row: the event to
/// attach instead (e.g. ReconciliationPerformed when the round is inconclusive but not the last).
Property AttachEvent As %String;

/// system, agent, rules, replay, benchmark, sweeper or operator:<name>.
Property Actor As %String;

Property ExpectedState As %String;

Property ExpectedCaseVersion As %Integer;

/// proposalId or executionId the command is about.
Property TargetId As %String;

/// Facts already recorded as Evidence or verdicts (verdict, requiresApproval, decision, reason,
/// revalidationFailed, responseClass, reconciliationResult, newException, kind, ...).
Property Facts As %DynamicObject;

Method %OnNew() As %Status [ Private ]
{
    set ..Facts = {}
    quit $$$OK
}

}
