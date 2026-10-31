Class SignalNoir.Application.Model.InvestigationRecord Extends %Persistent
{

/// One bounded Investigation, identified by its Investigate request
/// (cmd_ id). status: open -> proposed | review | discarded. The budget
/// counters here are the server-side authority (6 calls, budgetMs).
Property investigationId As %String(MAXLEN = 64) [ Required ];

Index investigationKey On investigationId [ IdKey ];

Property caseId As %String(MAXLEN = 64) [ Required ];

Index caseIdx On caseId;

Property caseVersionAtStart As %Integer;

/// agent, rules or replay
Property mode As %String(MAXLEN = 16);

Property proposerClass As %String(MAXLEN = 256);

Property sourceClass As %String(MAXLEN = 256);

Property status As %String(MAXLEN = 16) [ InitialExpression = "open" ];

Property startedAt As %String(MAXLEN = 64);

/// $ZHOROLOG-free start instant in milliseconds since 1970 (UTC)
Property startedMs As %Integer;

Property closedAt As %String(MAXLEN = 64);

Property budgetMs As %Integer [ InitialExpression = 20000 ];

Property toolCalls As %Integer [ InitialExpression = 0 ];

Property provider As %String(MAXLEN = 64);

Property model As %String(MAXLEN = 128);

Property promptVersion As %String(MAXLEN = 64);

Property policyVersion As %String(MAXLEN = 64);

Property mappingVersion As %String(MAXLEN = 64);

Property durationMs As %Integer;

Property tokensIn As %Integer;

Property tokensOut As %Integer;

/// Cached input tokens, when the provider reports them (013 FR-010)
Property tokensCached As %Integer;

Property estCostUsd As %Numeric(SCALE = 6);

Property outcomeReason As %String(MAXLEN = 256);

Property proposalId As %String(MAXLEN = 64);

Storage Default
{
<Data name="InvestigationRecordDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>caseId</Value>
</Value>
<Value name="3">
<Value>caseVersionAtStart</Value>
</Value>
<Value name="4">
<Value>mode</Value>
</Value>
<Value name="5">
<Value>proposerClass</Value>
</Value>
<Value name="6">
<Value>sourceClass</Value>
</Value>
<Value name="7">
<Value>status</Value>
</Value>
<Value name="8">
<Value>startedAt</Value>
</Value>
<Value name="9">
<Value>startedMs</Value>
</Value>
<Value name="10">
<Value>closedAt</Value>
</Value>
<Value name="11">
<Value>budgetMs</Value>
</Value>
<Value name="12">
<Value>toolCalls</Value>
</Value>
<Value name="13">
<Value>provider</Value>
</Value>
<Value name="14">
<Value>model</Value>
</Value>
<Value name="15">
<Value>promptVersion</Value>
</Value>
<Value name="16">
<Value>policyVersion</Value>
</Value>
<Value name="17">
<Value>mappingVersion</Value>
</Value>
<Value name="18">
<Value>durationMs</Value>
</Value>
<Value name="19">
<Value>tokensIn</Value>
</Value>
<Value name="20">
<Value>tokensOut</Value>
</Value>
<Value name="21">
<Value>estCostUsd</Value>
</Value>
<Value name="22">
<Value>outcomeReason</Value>
</Value>
<Value name="23">
<Value>proposalId</Value>
</Value>
<Value name="24">
<Value>tokensCached</Value>
</Value>
</Data>
<DataLocation>^SignalNoir70AE.Investigati82CDD</DataLocation>
<DefaultData>InvestigationRecordDefaultData</DefaultData>
<IdLocation>^SignalNoir70AE.Investigati82CDD</IdLocation>
<IndexLocation>^SignalNoir70AE.Investigati82CDI</IndexLocation>
<StreamLocation>^SignalNoir70AE.Investigati82CDS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
