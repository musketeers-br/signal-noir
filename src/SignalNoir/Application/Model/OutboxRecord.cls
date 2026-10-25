Class SignalNoir.Application.Model.OutboxRecord Extends %Persistent
{

/// Follow-up work, written in the same transaction as the transition that
/// needs it. status: pending (not picked up) -> dispatched (in progress) ->
/// done. The consumer re-checks caseVersionAfter against the Case (AD-4).
Property commandId As %String(MAXLEN = 128) [ Required ];

Index commandKey On commandId [ IdKey ];

/// One of the closed command names (Investigate, Execute, Reconcile, ...)
Property type As %String(MAXLEN = 64);

Property caseId As %String(MAXLEN = 64);

Index caseIdx On caseId;

Index statusIdx On (caseId, type, status);

/// The post-commit version the consumer must match
Property caseVersionAfter As %Integer;

Property status As %String(MAXLEN = 32) [ InitialExpression = "pending" ];

/// Facts the consumer needs (e.g. rejectionReason); never secrets
Property payloadJson As %String(MAXLEN = 4096);

Property createdAt As %String(MAXLEN = 64);

Property dispatchedAt As %String(MAXLEN = 64);

}
