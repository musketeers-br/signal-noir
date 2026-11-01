Class SignalNoir.Tests.Fakes.FakeRunDirectory Extends SignalNoir.Core.Port.RunDirectory
{

Property Runs [ MultiDimensional ];

/// Registers a run summary {runId, mode, status, purpose, policyVersion, mappingVersion}
Method Add(summary As %DynamicObject)
{
	Set ..Runs(summary.runId) = summary.%ToJSON()
}

Method Find(runId As %String) As %DynamicObject
{
	If (runId = "") || '$Data(..Runs(runId)) Return ""
	Return {}.%FromJSON(..Runs(runId))
}

}
