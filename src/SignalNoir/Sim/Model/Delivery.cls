Class SignalNoir.Sim.Model.Delivery Extends %Persistent
{

/// One Partner log entry (data-model Delivery / PartnerLogEntry): an
/// Attempt that passed request validation, or third-party traffic written by
/// an event (no order fields)
Property scenarioInstanceId As %String(MAXLEN = 80);

Index instanceIdx On (scenarioInstanceId, loggedAt);

Property partnerId As %String(MAXLEN = 64);

Property orderId As %String(MAXLEN = 128);

Property transactionId As %String(MAXLEN = 128);

Property idempotencyKey As %String(MAXLEN = 128);

Property attempt As %Integer;

/// "" on a timeout
Property httpStatus As %String(MAXLEN = 8);

/// delivered, duplicate, rejected, error, timeout, unavailable
Property outcome As %String(MAXLEN = 16);

Property latencyMs As %Integer;

Property message As %String(MAXLEN = 4000);

Property loggedAt As %String(MAXLEN = 40);

Storage Default
{
<Data name="DeliveryDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>scenarioInstanceId</Value>
</Value>
<Value name="3">
<Value>partnerId</Value>
</Value>
<Value name="4">
<Value>orderId</Value>
</Value>
<Value name="5">
<Value>transactionId</Value>
</Value>
<Value name="6">
<Value>idempotencyKey</Value>
</Value>
<Value name="7">
<Value>attempt</Value>
</Value>
<Value name="8">
<Value>httpStatus</Value>
</Value>
<Value name="9">
<Value>outcome</Value>
</Value>
<Value name="10">
<Value>latencyMs</Value>
</Value>
<Value name="11">
<Value>message</Value>
</Value>
<Value name="12">
<Value>loggedAt</Value>
</Value>
</Data>
<DataLocation>^SignalNoir.Sim.Model.DeliveryD</DataLocation>
<DefaultData>DeliveryDefaultData</DefaultData>
<IdLocation>^SignalNoir.Sim.Model.DeliveryD</IdLocation>
<IndexLocation>^SignalNoir.Sim.Model.DeliveryI</IndexLocation>
<StreamLocation>^SignalNoir.Sim.Model.DeliveryS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
