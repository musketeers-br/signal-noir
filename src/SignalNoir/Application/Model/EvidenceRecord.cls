Class SignalNoir.Application.Model.EvidenceRecord Extends %Persistent
{

/// An immutable observed fact. Insert-only; obsolescence is a new event.
Property evidenceId As %String(MAXLEN = 64) [ Required ];

Index evidenceKey On evidenceId [ IdKey ];

Property caseId As %String(MAXLEN = 64) [ Required ];

Index caseIdx On caseId;

Property investigationId As %String(MAXLEN = 64);

Index investigationIdx On investigationId;

/// Contract Evidence.source
Property source As %String(MAXLEN = 64) [ Required ];

/// fact or absence
Property kind As %String(MAXLEN = 16) [ InitialExpression = "fact" ];

Property calledBy As %String(MAXLEN = 128);

Property paramsJson As %String(MAXLEN = 4096);

/// Raw result by value, as JSON
Property resultJson As %String(MAXLEN = 32000);

Property observedAt As %String(MAXLEN = 64) [ Required ];

Property durationMs As %Integer;

Property suspicious As %Boolean [ InitialExpression = 0 ];

Property suspiciousExcerpts As list Of %String(MAXLEN = 512);

Property obsoletedBy As %String(MAXLEN = 64);

Storage Default
{
<Data name="EvidenceRecordDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>caseId</Value>
</Value>
<Value name="3">
<Value>investigationId</Value>
</Value>
<Value name="4">
<Value>source</Value>
</Value>
<Value name="5">
<Value>kind</Value>
</Value>
<Value name="6">
<Value>calledBy</Value>
</Value>
<Value name="7">
<Value>paramsJson</Value>
</Value>
<Value name="8">
<Value>resultJson</Value>
</Value>
<Value name="9">
<Value>observedAt</Value>
</Value>
<Value name="10">
<Value>durationMs</Value>
</Value>
<Value name="11">
<Value>suspicious</Value>
</Value>
<Value name="12">
<Value>suspiciousExcerpts</Value>
</Value>
<Value name="13">
<Value>obsoletedBy</Value>
</Value>
</Data>
<DataLocation>^SignalNoir70AE.EvidenceRecordD</DataLocation>
<DefaultData>EvidenceRecordDefaultData</DefaultData>
<IdLocation>^SignalNoir70AE.EvidenceRecordD</IdLocation>
<IndexLocation>^SignalNoir70AE.EvidenceRecordI</IndexLocation>
<StreamLocation>^SignalNoir70AE.EvidenceRecordS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
