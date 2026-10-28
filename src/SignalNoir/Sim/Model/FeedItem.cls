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

}
