Class SignalNoir.Application.Model.CaseEventRecord Extends %Persistent
{

/// Append-only timeline row: one row per fact, never updated or deleted.
/// seq is monotonic per Case and never reused. The ID is the compound
/// caseId + seq, so a timeline row is addressed directly.
Property caseId As %String(MAXLEN = 64) [ Required ];

Property seq As %Integer [ Required ];

Index eventKey On (caseId, seq) [ IdKey ];

/// ISO-8601 UTC timestamp
Property at As %String(MAXLEN = 64);

Property type As %String(MAXLEN = 64);

Property actor As %String(MAXLEN = 128);

Property refId As %String(MAXLEN = 128);

/// Fact payload as JSON; never carries secrets
Property payloadJson As %String(MAXLEN = 4096);

Storage Default
{
<Data name="CaseEventRecordDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>at</Value>
</Value>
<Value name="3">
<Value>type</Value>
</Value>
<Value name="4">
<Value>actor</Value>
</Value>
<Value name="5">
<Value>refId</Value>
</Value>
<Value name="6">
<Value>payloadJson</Value>
</Value>
</Data>
<DataLocation>^SignalNoir70AE.CaseEventRe8F9DD</DataLocation>
<DefaultData>CaseEventRecordDefaultData</DefaultData>
<IdLocation>^SignalNoir70AE.CaseEventRe8F9DD</IdLocation>
<IndexLocation>^SignalNoir70AE.CaseEventRe8F9DI</IndexLocation>
<StreamLocation>^SignalNoir70AE.CaseEventRe8F9DS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
