Class SignalNoir.Sim.Model.Instance Extends %Persistent
{

/// One isolated scenario instance (data-model ScenarioInstance). Its
/// Partner state and applied events live here (research, implementation
/// deviations), always read and written under the instance lock.
Property scenarioInstanceId As %String(MAXLEN = 80) [ Required ];

Index idKey On scenarioInstanceId [ IdKey ];

Property family As %String(MAXLEN = 32);

Property subtype As %String(MAXLEN = 64);

Property variant As %String(MAXLEN = 80);

Property variantSet As %String(MAXLEN = 16);

Property partnerId As %String(MAXLEN = 64);

Property language As %String(MAXLEN = 8);

Property seed As %Integer;

Property runId As %String(MAXLEN = 80);

Property repetition As %Integer [ InitialExpression = 1 ];

Property timeScale As %Numeric(SCALE = 6) [ InitialExpression = 1 ];

/// created or emitted
Property status As %String(MAXLEN = 16) [ InitialExpression = "created" ];

Property phase As %String(MAXLEN = 32) [ InitialExpression = "initial" ];

/// [{type, at}]
Property appliedEventsJson As %String(MAXLEN = 8000) [ InitialExpression = "[]" ];

/// [orderId] of the Orders emitted to the feed
Property emittedOrderIdsJson As %String(MAXLEN = 8000) [ InitialExpression = "[]" ];

/// The EmissionResult returned by the first emission
Property emissionJson As %String(MAXLEN = 32000);

/// What the Partner declares (PartnerHealth without partner, instance, checkedAt)
Property healthJson As %String(MAXLEN = 4000);

Property createdAt As %String(MAXLEN = 40);

}
