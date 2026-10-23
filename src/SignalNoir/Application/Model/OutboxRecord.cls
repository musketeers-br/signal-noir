Class SignalNoir.Application.Model.OutboxRecord Extends %Persistent
{

/// Written in the same transaction as a transition that needs Production work.
/// In this slice the entry is created and left pending: the consumer and the
/// sweeper arrive in later slices, so no schema reset is needed.

Property commandId As %String(MAXLEN=128) [ Required ];

Index commandKey On commandId [ Idkey ];

/// One of the closed command names (Investigate, Execute, Reconcile, ...)
Property type As %String(MAXLEN=64);

Property caseId As %String(MAXLEN=64);

Index caseIdx On caseId;

/// The post-commit version the consumer must match
Property caseVersionAfter As %Integer;

/// pending, dispatched or done
Property status As %String(MAXLEN=32) [ InitialExpression = "pending" ];

Property createdAt As %String(MAXLEN=64);

}
