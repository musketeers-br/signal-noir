Class SignalNoir.Core.Port.RunDirectory Extends %RegisteredObject [ Abstract ]
{

/// Which BenchmarkRun a run id names (feature 010, plan D2). Read-only: the
/// Core owns the question, the application layer answers it from its records.
/// Returns {runId, mode, status, purpose, policyVersion, mappingVersion}, or
/// "" when there is no such run (absent, empty or unknown id).
Method Find(runId As %String) As %DynamicObject
{
	Return ""
}

}
