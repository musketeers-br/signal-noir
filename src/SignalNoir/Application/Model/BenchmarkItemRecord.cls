Class SignalNoir.Application.Model.BenchmarkItemRecord Extends %Persistent
{

/// One planned (scenario, variant, repetition) of a BenchmarkRun (feature 010,
/// data-model.md). An item never changes a Case; the Case is read by caseId.
Property runId As %String(MAXLEN = 64) [ Required ];

Property itemNo As %Integer [ Required ];

Index itemKey On (runId, itemNo) [ IdKey ];

Property family As %String(MAXLEN = 32);

Property subtype As %String(MAXLEN = 64);

Property variant As %String(MAXLEN = 128);

/// tuning or test
Property set As %String(MAXLEN = 16);

Property repetition As %Integer [ InitialExpression = 1 ];

Property seed As %Integer;

Property scenarioInstanceId As %String(MAXLEN = 128);

Index instanceIdx On scenarioInstanceId;

Property caseId As %String(MAXLEN = 64);

Index caseIdx On caseId;

/// planned, opened, ended or not_decided
Property status As %String(MAXLEN = 16) [ InitialExpression = "planned" ];

/// provider_unavailable, run_failed or deadline
Property notDecidedReason As %String(MAXLEN = 64);

Property deadlineAt As %String(MAXLEN = 64);

Storage Default
{
<Data name="BenchmarkItemRecordDefaultData">
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
<Value>set</Value>
</Value>
<Value name="6">
<Value>repetition</Value>
</Value>
<Value name="7">
<Value>seed</Value>
</Value>
<Value name="8">
<Value>scenarioInstanceId</Value>
</Value>
<Value name="9">
<Value>caseId</Value>
</Value>
<Value name="10">
<Value>status</Value>
</Value>
<Value name="11">
<Value>notDecidedReason</Value>
</Value>
<Value name="12">
<Value>deadlineAt</Value>
</Value>
</Data>
<DataLocation>^SignalNoir70AE.BenchmarkItBF17D</DataLocation>
<DefaultData>BenchmarkItemRecordDefaultData</DefaultData>
<IdLocation>^SignalNoir70AE.BenchmarkItBF17D</IdLocation>
<IndexLocation>^SignalNoir70AE.BenchmarkItBF17I</IndexLocation>
<StreamLocation>^SignalNoir70AE.BenchmarkItBF17S</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
