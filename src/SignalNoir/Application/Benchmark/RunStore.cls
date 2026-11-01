Class SignalNoir.Application.Benchmark.RunStore Extends SignalNoir.Core.Port.RunDirectory
{

/// The application's answer to the Core's RunDirectory port: a read of the run
/// record, as a plain summary. "" for an empty or unknown id (plan D2).
Method Find(runId As %String) As %DynamicObject
{
	If runId = "" Return ""
	Set rec = ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%OpenId(runId)
	If '$IsObject(rec) Return ""
	Return {"runId": (rec.runId), "mode": (rec.mode), "status": (rec.status), "purpose": (rec.purpose), "policyVersion": (rec.policyVersion), "mappingVersion": (rec.mappingVersion)}
}

}
