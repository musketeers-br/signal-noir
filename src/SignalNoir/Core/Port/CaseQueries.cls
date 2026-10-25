/// Read path (seam contract v3).
/// It extends CaseCommands because IRIS has single inheritance only: the
/// runtime adapter is one object that serves both ports, and extending the
/// command port here makes it assignable to CaseCommands and CaseQueries at
/// the same time.
Class SignalNoir.Core.Port.CaseQueries Extends SignalNoir.Core.Port.CaseCommands [ Abstract ]
{

/// Read path (seam contract)
Method GetCase(caseId As %String) As SignalNoir.Core.Result
{
	Return $$$ERROR($$$GeneralError, "Abstract port method - override in adapter or fake")
}

/// Events with seq > sinceSeq, ascending, at most limit. Result.details
/// carries hasMore and nextSinceSeq.
Method GetTimeline(caseId As %String, sinceSeq As %Integer = 0, limit As %Integer = 200) As SignalNoir.Core.Result
{
	Return $$$ERROR($$$GeneralError, "Abstract port method - override in adapter or fake")
}

/// direction older (default) or newer; filters: state[], status,
/// pendingApproval, runId, includeBenchmark. Result.details carries
/// nextCursor and headCursor.
Method ListCases(cursor As %String = "", direction As %String = "older", limit As %Integer = 50, filters As %DynamicObject = "") As SignalNoir.Core.Result
{
	Return $$$ERROR($$$GeneralError, "Abstract port method - override in adapter or fake")
}

}
