Class SignalNoir.Application.Model.BenchmarkRunRecord Extends %Persistent
{

/// One BenchmarkRun (feature 010, data-model.md). Written only by
/// Application.Benchmark.RunService, Runner and ReportBuilder; read by RunStore
/// (the Core's RunDirectory port).
Property runId As %String(MAXLEN = 64) [ Required ];

Index runKey On runId [ IdKey ];

/// rules, agent or replay
Property mode As %String(MAXLEN = 16) [ Required ];

/// benchmark, reference or quick_validation
Property purpose As %String(MAXLEN = 32) [ Required ];

/// created, running, completed or failed
Property status As %String(MAXLEN = 16) [ InitialExpression = "created" ];

Index statusIdx On status;

Property provider As %String(MAXLEN = 64);

Property model As %String(MAXLEN = 128);

Property repetitions As %Integer [ InitialExpression = 3 ];

Property seed As %Integer [ InitialExpression = 0 ];

/// Pinned at creation (FR-006)
Property policyVersion As %String(MAXLEN = 64);

Property mappingVersion As %String(MAXLEN = 64);

/// The selection after expansion to explicit variants
Property scenariosJson As %String(MAXLEN = "");

Property casesPlanned As %Integer [ InitialExpression = 0 ];

Property casesOpened As %Integer [ InitialExpression = 0 ];

Property casesTerminal As %Integer [ InitialExpression = 0 ];

/// True when the run cannot be published as the reference (never cleared)
Property development As %Boolean [ InitialExpression = 0 ];

Property developmentReasonsJson As %String(MAXLEN = "");

Property freezeId As %String(MAXLEN = 64);

Property freezeJson As %String(MAXLEN = "");

/// Digests of the frozen inputs read at creation and again at the first step
Property inputsDigestJson As %String(MAXLEN = "");

/// Written once, when the run completes; absent otherwise (FR-024)
Property reportJson As %String(MAXLEN = "");

Property label As %String(MAXLEN = 128);

/// deadline, simulator_unreachable, abandoned, ...
Property failureReason As %String(MAXLEN = 128);

Property createdAt As %String(MAXLEN = 64);

Property startedAt As %String(MAXLEN = 64);

Property completedAt As %String(MAXLEN = 64);

Property heartbeatAt As %String(MAXLEN = 64);

Storage Default
{
<Data name="BenchmarkRunRecordDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>mode</Value>
</Value>
<Value name="3">
<Value>purpose</Value>
</Value>
<Value name="4">
<Value>status</Value>
</Value>
<Value name="5">
<Value>provider</Value>
</Value>
<Value name="6">
<Value>model</Value>
</Value>
<Value name="7">
<Value>repetitions</Value>
</Value>
<Value name="8">
<Value>seed</Value>
</Value>
<Value name="9">
<Value>policyVersion</Value>
</Value>
<Value name="10">
<Value>mappingVersion</Value>
</Value>
<Value name="11">
<Value>scenariosJson</Value>
</Value>
<Value name="12">
<Value>casesPlanned</Value>
</Value>
<Value name="13">
<Value>casesOpened</Value>
</Value>
<Value name="14">
<Value>casesTerminal</Value>
</Value>
<Value name="15">
<Value>development</Value>
</Value>
<Value name="16">
<Value>developmentReasonsJson</Value>
</Value>
<Value name="17">
<Value>freezeId</Value>
</Value>
<Value name="18">
<Value>freezeJson</Value>
</Value>
<Value name="19">
<Value>inputsDigestJson</Value>
</Value>
<Value name="20">
<Value>reportJson</Value>
</Value>
<Value name="21">
<Value>label</Value>
</Value>
<Value name="22">
<Value>failureReason</Value>
</Value>
<Value name="23">
<Value>createdAt</Value>
</Value>
<Value name="24">
<Value>startedAt</Value>
</Value>
<Value name="25">
<Value>completedAt</Value>
</Value>
<Value name="26">
<Value>heartbeatAt</Value>
</Value>
</Data>
<DataLocation>^SignalNoir70AE.BenchmarkRu74B2D</DataLocation>
<DefaultData>BenchmarkRunRecordDefaultData</DefaultData>
<IdLocation>^SignalNoir70AE.BenchmarkRu74B2D</IdLocation>
<IndexLocation>^SignalNoir70AE.BenchmarkRu74B2I</IndexLocation>
<StreamLocation>^SignalNoir70AE.BenchmarkRu74B2S</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
