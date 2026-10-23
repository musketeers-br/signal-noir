/// The Core's answer to a command, as a value (Constitution Principle VII): an accepted
/// transition, a refusal, or an attachment. Never thrown.
Class SignalNoir.Core.Decision Extends %RegisteredObject
{

/// Accepted, Refused or Attach.
Property Kind As %String;

Property TransitionId As %String;

Property FromState As %String;

Property ToState As %String;

/// Timeline events to record, in order: [{ "type", "payload" }]; StateChanged first.
Property Events As %DynamicArray;

/// Named effects on the Case's records, e.g. "IncrementDenialCount", "CloseExecution:held".
Property RecordEffects As %DynamicArray;

/// Work items to queue in the same transaction.
Property Outbox As %DynamicArray;

/// Transitions the table chains in the same step; the Application decides which apply.
Property SameStep As %DynamicArray;

/// INVALID_TRANSITION, INVALID_ACTOR, STALE_VERSION or APPROVAL_EXPIRED.
Property RefusalCode As %String;

/// Repeated approval of an approved Proposal: nothing to record (specs/001 FR-014).
Property IdempotentReplay As %Boolean [ InitialExpression = 0 ];

/// More than one row matched: a defect of the table, refused and to be logged by the caller.
Property TableDefect As %Boolean [ InitialExpression = 0 ];

Method %OnNew() As %Status [ Private ]
{
    set ..Events = [], ..RecordEffects = [], ..Outbox = [], ..SameStep = []
    quit $$$OK
}

ClassMethod Refused(code As %String, snapshot As SignalNoir.Core.CaseSnapshot, command As SignalNoir.Core.TransitionCommand) As SignalNoir.Core.Decision
{
    set decision = ..%New()
    set decision.Kind = "Refused", decision.RefusalCode = code
    set decision.FromState = snapshot.State, decision.ToState = command.RequestedState
    set payload = {"command": (command.Command), "actor": (command.Actor), "currentState": (snapshot.State), "requestedState": (command.RequestedState), "code": (code)}
    do decision.Events.%Push({"type": "CommandDiscarded", "payload": (payload)})
    quit decision
}

}
