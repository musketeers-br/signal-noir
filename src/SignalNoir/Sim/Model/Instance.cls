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

Storage Default
{
<Data name="InstanceDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>family</Value>
</Value>
<Value name="3">
<Value>subtype</Value>
</Value>
<Value name="4">
<Value>variant</Value>
</Value>
<Value name="5">
<Value>variantSet</Value>
</Value>
<Value name="6">
<Value>partnerId</Value>
</Value>
<Value name="7">
<Value>language</Value>
</Value>
<Value name="8">
<Value>seed</Value>
</Value>
<Value name="9">
<Value>runId</Value>
</Value>
<Value name="10">
<Value>repetition</Value>
</Value>
<Value name="11">
<Value>timeScale</Value>
</Value>
<Value name="12">
<Value>status</Value>
</Value>
<Value name="13">
<Value>phase</Value>
</Value>
<Value name="14">
<Value>appliedEventsJson</Value>
</Value>
<Value name="15">
<Value>emittedOrderIdsJson</Value>
</Value>
<Value name="16">
<Value>emissionJson</Value>
</Value>
<Value name="17">
<Value>healthJson</Value>
</Value>
<Value name="18">
<Value>createdAt</Value>
</Value>
</Data>
<DataLocation>^SignalNoir.Sim.Model.InstanceD</DataLocation>
<DefaultData>InstanceDefaultData</DefaultData>
<IdLocation>^SignalNoir.Sim.Model.InstanceD</IdLocation>
<IndexLocation>^SignalNoir.Sim.Model.InstanceI</IndexLocation>
<StreamLocation>^SignalNoir.Sim.Model.InstanceS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
