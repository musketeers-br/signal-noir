Class SignalNoir.Application.Model.ReceiptCopyRecord Extends %Persistent
{

/// The Case's auditable copy of the Partner's canonical Receipt (AD-14,
/// contract ReceiptCopy). The Partner's record prevails on divergence.
Property caseId As %String(MAXLEN = 64) [ Required ];

Property receiptId As %String(MAXLEN = 128) [ Required ];

Index receiptKey On (caseId, receiptId) [ IdKey ];

Property executionId As %String(MAXLEN = 64);

Property orderId As %String(MAXLEN = 128);

Property idempotencyKey As %String(MAXLEN = 128);

Property receivedAt As %String(MAXLEN = 64);

Property partnerId As %String(MAXLEN = 128);

/// delivery or reconciliation (prior_receipt is 011's)
Property source As %String(MAXLEN = 32);

Property externalRef As %String(MAXLEN = 512);

Property orderSnapshotMinimalJson As %String(MAXLEN = 4096);

Property recordedAt As %String(MAXLEN = 64);

Storage Default
{
<Data name="ReceiptCopyRecordDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>executionId</Value>
</Value>
<Value name="3">
<Value>orderId</Value>
</Value>
<Value name="4">
<Value>idempotencyKey</Value>
</Value>
<Value name="5">
<Value>receivedAt</Value>
</Value>
<Value name="6">
<Value>partnerId</Value>
</Value>
<Value name="7">
<Value>source</Value>
</Value>
<Value name="8">
<Value>externalRef</Value>
</Value>
<Value name="9">
<Value>orderSnapshotMinimalJson</Value>
</Value>
<Value name="10">
<Value>recordedAt</Value>
</Value>
</Data>
<DataLocation>^SignalNoir70AE.ReceiptCopyC3ECD</DataLocation>
<DefaultData>ReceiptCopyRecordDefaultData</DefaultData>
<IdLocation>^SignalNoir70AE.ReceiptCopyC3ECD</IdLocation>
<IndexLocation>^SignalNoir70AE.ReceiptCopyC3ECI</IndexLocation>
<StreamLocation>^SignalNoir70AE.ReceiptCopyC3ECS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
