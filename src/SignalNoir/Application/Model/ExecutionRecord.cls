Class SignalNoir.Application.Model.ExecutionRecord Extends %Persistent
{

/// One authorized execution of an Action (contract Execution, feature 008).
/// Three identities: the request (commandId, in the outbox), this execution
/// (executionId, lease, reconciliation) and the effect (idempotencyKey,
/// Core.EffectKey). Attempts and reconciliations are read only with their
/// execution, so they are kept as JSON arrays. Written only by CaseService.
Property executionId As %String(MAXLEN = 64) [ Required ];

Index executionKey On executionId [ IdKey ];

Property caseId As %String(MAXLEN = 64) [ Required ];

Index caseIdx On caseId;

Property orderId As %String(MAXLEN = 128) [ Required ];

/// "Uncertain blocks every new send" looks up the Order's reconciling executions
Index orderOutcomeIdx On (orderId, outcome);

Property partnerId As %String(MAXLEN = 128);

Property proposalId As %String(MAXLEN = 64) [ Required ];

/// Empty for HOLD, which needs no approval
Property approvalId As %String(MAXLEN = 64);

Property action As %String(MAXLEN = 64) [ Required ];

/// The effect key sent to the Partner
Property idempotencyKey As %String(MAXLEN = 128);

/// The canonical payload sent (snapshot, or the mapped Order)
Property payloadJson As %String(MAXLEN = 32000);

/// {mappingId, mappingVersion} for APPLY_APPROVED_MAPPING
Property mappingRefJson As %String(MAXLEN = 1024);

Property scenarioInstanceId As %String(MAXLEN = 128);

Property runId As %String(MAXLEN = 64);

Property authorizedAt As %String(MAXLEN = 64);

Property completedAt As %String(MAXLEN = 64);

Property leaseOwner As %String(MAXLEN = 128);

/// 1 at authorization, +1 on every take-over; a write under a lower one is refused
Property leaseGeneration As %Integer [ InitialExpression = 1 ];

Property stepLeaseUntil As %String(MAXLEN = 64);

Index leaseIdx On (outcome, stepLeaseUntil);

/// {passed, checks[], at, resultingState}
Property revalidationJson As %String(MAXLEN = 8000);

/// [Attempt]
Property attemptsJson As %String(MAXLEN = 32000) [ InitialExpression = "[]" ];

/// [Reconciliation]
Property reconciliationsJson As %String(MAXLEN = 16000) [ InitialExpression = "[]" ];

/// in_progress, reconciling, resolved, held, cancelled, failed
Property outcome As %String(MAXLEN = 32) [ InitialExpression = "in_progress" ];

/// Why it failed or was held
Property failureReason As %String(MAXLEN = 1024);

Storage Default
{
<Data name="ExecutionRecordDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>caseId</Value>
</Value>
<Value name="3">
<Value>orderId</Value>
</Value>
<Value name="4">
<Value>partnerId</Value>
</Value>
<Value name="5">
<Value>proposalId</Value>
</Value>
<Value name="6">
<Value>approvalId</Value>
</Value>
<Value name="7">
<Value>action</Value>
</Value>
<Value name="8">
<Value>idempotencyKey</Value>
</Value>
<Value name="9">
<Value>payloadJson</Value>
</Value>
<Value name="10">
<Value>mappingRefJson</Value>
</Value>
<Value name="11">
<Value>scenarioInstanceId</Value>
</Value>
<Value name="12">
<Value>runId</Value>
</Value>
<Value name="13">
<Value>authorizedAt</Value>
</Value>
<Value name="14">
<Value>completedAt</Value>
</Value>
<Value name="15">
<Value>leaseOwner</Value>
</Value>
<Value name="16">
<Value>leaseGeneration</Value>
</Value>
<Value name="17">
<Value>stepLeaseUntil</Value>
</Value>
<Value name="18">
<Value>revalidationJson</Value>
</Value>
<Value name="19">
<Value>attemptsJson</Value>
</Value>
<Value name="20">
<Value>reconciliationsJson</Value>
</Value>
<Value name="21">
<Value>outcome</Value>
</Value>
<Value name="22">
<Value>failureReason</Value>
</Value>
</Data>
<DataLocation>^SignalNoir70AE.ExecutionReCD4DD</DataLocation>
<DefaultData>ExecutionRecordDefaultData</DefaultData>
<IdLocation>^SignalNoir70AE.ExecutionReCD4DD</IdLocation>
<IndexLocation>^SignalNoir70AE.ExecutionReCD4DI</IndexLocation>
<StreamLocation>^SignalNoir70AE.ExecutionReCD4DS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
