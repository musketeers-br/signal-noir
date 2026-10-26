Class SignalNoir.Application.Model.IntakeRefusalRecord Extends %Persistent
{

/// An Order refused at intake. Never becomes an Order record or a Case.
Property orderId As %String(MAXLEN = 128);

Index orderIdIdx On orderId;

Property transactionId As %String(MAXLEN = 128);

/// Ordered reasons from Core.OrderShape
Property reasons As list Of %String(MAXLEN = 256);

Property refusedAt As %String(MAXLEN = 64);

Storage Default
{
<Data name="IntakeRefusalRecordDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>orderId</Value>
</Value>
<Value name="3">
<Value>transactionId</Value>
</Value>
<Value name="4">
<Value>reasons</Value>
</Value>
<Value name="5">
<Value>refusedAt</Value>
</Value>
</Data>
<DataLocation>^SignalNoir70AE.IntakeRefus1B9FD</DataLocation>
<DefaultData>IntakeRefusalRecordDefaultData</DefaultData>
<IdLocation>^SignalNoir70AE.IntakeRefus1B9FD</IdLocation>
<IndexLocation>^SignalNoir70AE.IntakeRefus1B9FI</IndexLocation>
<StreamLocation>^SignalNoir70AE.IntakeRefus1B9FS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
