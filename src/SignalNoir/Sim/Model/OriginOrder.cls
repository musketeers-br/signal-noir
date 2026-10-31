Class SignalNoir.Sim.Model.OriginOrder Extends %Persistent
{

/// The Order as the Origin emitted it, and its status (data-model OriginOrder)
Property orderId As %String(MAXLEN = 128) [ Required ];

Index idKey On orderId [ IdKey ];

Property scenarioInstanceId As %String(MAXLEN = 80);

Index instanceIdx On scenarioInstanceId;

Property patientId As %String(MAXLEN = 128);

Index patientIdx On (scenarioInstanceId, patientId);

Property transactionId As %String(MAXLEN = 128);

Property ordinal As %Integer;

/// The raw SyntheticOrder, immutable
Property orderJson As %String(MAXLEN = 32000);

/// False for a P9 original (seeded, not published)
Property inFeed As %Boolean [ InitialExpression = 1 ];

/// active or cancelled
Property status As %String(MAXLEN = 16) [ InitialExpression = "active" ];

Property statusChangedAt As %String(MAXLEN = 40);

Property reason As %String(MAXLEN = 1000);

Property emittedAt As %String(MAXLEN = 40);

Storage Default
{
<Data name="OriginOrderDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>scenarioInstanceId</Value>
</Value>
<Value name="3">
<Value>patientId</Value>
</Value>
<Value name="4">
<Value>transactionId</Value>
</Value>
<Value name="5">
<Value>ordinal</Value>
</Value>
<Value name="6">
<Value>orderJson</Value>
</Value>
<Value name="7">
<Value>inFeed</Value>
</Value>
<Value name="8">
<Value>status</Value>
</Value>
<Value name="9">
<Value>statusChangedAt</Value>
</Value>
<Value name="10">
<Value>reason</Value>
</Value>
<Value name="11">
<Value>emittedAt</Value>
</Value>
</Data>
<DataLocation>^SignalNoir.Sim63E6.OriginOrderD</DataLocation>
<DefaultData>OriginOrderDefaultData</DefaultData>
<IdLocation>^SignalNoir.Sim63E6.OriginOrderD</IdLocation>
<IndexLocation>^SignalNoir.Sim63E6.OriginOrderI</IndexLocation>
<StreamLocation>^SignalNoir.Sim63E6.OriginOrderS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
