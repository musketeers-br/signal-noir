Class SignalNoir.Core.Port.CaseCommands Extends %RegisteredObject [ Abstract ]
{

/// The only mutation path (seam contract). Transitions use compare-and-swap
/// on caseVersion; a losing writer gets a visible conflict result. State,
/// event and outbox entry commit together.

Method AcceptOrder(order As SignalNoir.Core.Dto.Order) As SignalNoir.Core.Result
{
	Return $$$ERROR($$$GeneralError, "Abstract port method - override in adapter or fake")
}

Method OpenCase(orderId As %String) As SignalNoir.Core.Result
{
	Return $$$ERROR($$$GeneralError, "Abstract port method - override in adapter or fake")
}

Method Transition(caseId As %String, expectedVersion As %Integer, toState As %String, actor As %String, event As SignalNoir.Core.Dto.TimelineEvent) As SignalNoir.Core.Result
{
	Return $$$ERROR($$$GeneralError, "Abstract port method - override in adapter or fake")
}

/// Attachment: does not bump caseVersion
Method Append(caseId As %String, event As SignalNoir.Core.Dto.TimelineEvent) As SignalNoir.Core.Result
{
	Return $$$ERROR($$$GeneralError, "Abstract port method - override in adapter or fake")
}

Method MarkReviewRequired(caseId As %String, expectedVersion As %Integer, actor As %String, reason As %String) As SignalNoir.Core.Result
{
	Return $$$ERROR($$$GeneralError, "Abstract port method - override in adapter or fake")
}

}
