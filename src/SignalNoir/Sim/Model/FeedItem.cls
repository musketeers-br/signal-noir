Class SignalNoir.Sim.Model.FeedItem Extends %Persistent
{

/// An Origin feed item (OrderEnvelope), immutable after publication
Property feedSeq As %Integer [ Required ];

Index idKey On feedSeq [ IdKey ];

Property scenarioInstanceId As %String(MAXLEN = 80);

Property runId As %String(MAXLEN = 80);

Property repetition As %Integer;

Property transactionId As %String(MAXLEN = 128);

Property emittedAt As %String(MAXLEN = 40);

Property orderJson As %String(MAXLEN = 32000);

Storage Default
{
<Data name="FeedItemDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>scenarioInstanceId</Value>
</Value>
<Value name="3">
<Value>runId</Value>
</Value>
<Value name="4">
<Value>repetition</Value>
</Value>
<Value name="5">
<Value>transactionId</Value>
</Value>
<Value name="6">
<Value>emittedAt</Value>
</Value>
<Value name="7">
<Value>orderJson</Value>
</Value>
</Data>
<DataLocation>^SignalNoir.Sim.Model.FeedItemD</DataLocation>
<DefaultData>FeedItemDefaultData</DefaultData>
<IdLocation>^SignalNoir.Sim.Model.FeedItemD</IdLocation>
<IndexLocation>^SignalNoir.Sim.Model.FeedItemI</IndexLocation>
<StreamLocation>^SignalNoir.Sim.Model.FeedItemS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
