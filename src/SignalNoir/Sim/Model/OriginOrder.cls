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

}
