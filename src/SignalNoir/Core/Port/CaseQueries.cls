/// Read path (seam contract).
/// It extends CaseCommands because IRIS has single inheritance only: the
/// runtime adapter is one object that serves both ports, and extending the
/// command port here makes it assignable to CaseCommands and CaseQueries at
/// the same time. The method signatures of both ports are unchanged.
Class SignalNoir.Core.Port.CaseQueries Extends SignalNoir.Core.Port.CaseCommands [ Abstract ]
{

/// Read path (seam contract)

Method GetCase(caseId As %String) As SignalNoir.Core.Result
{
	Return $$$ERROR($$$GeneralError, "Abstract port method - override in adapter or fake")
}

Method GetTimeline(caseId As %String, sinceSeq As %Integer = 0) As SignalNoir.Core.Result
{
	Return $$$ERROR($$$GeneralError, "Abstract port method - override in adapter or fake")
}

Method ListCases(cursor As %String = "") As SignalNoir.Core.Result
{
	Return $$$ERROR($$$GeneralError, "Abstract port method - override in adapter or fake")
}

}
