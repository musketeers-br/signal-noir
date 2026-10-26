Class SignalNoir.Core.Port.CaseCommands Extends %RegisteredObject [ Abstract ]
{

/// The only mutation path (seam contract v3, contract change 003).
/// Transitions use compare-and-swap on caseVersion and, when given, on the
/// expected state and target; a losing writer gets a visible conflict
/// result. State, event and outbox entry commit together.
/// Stores and correlates the Order; opens no Case. Result.ref is the orderId.
Method AcceptOrder(order As SignalNoir.Core.Dto.Order) As SignalNoir.Core.Result
{
	Return $$$ERROR($$$GeneralError, "Abstract port method - override in adapter or fake")
}

/// Records an Exception: opens the Case on the first one, joins the
/// non-terminal Case, or opens a related Case after a terminal one.
/// Result.ref is the caseId.
Method RecordException(orderId As %String, exception As SignalNoir.Core.Dto.CaseException) As SignalNoir.Core.Result
{
	Return $$$ERROR($$$GeneralError, "Abstract port method - override in adapter or fake")
}

/// Returns the non-terminal Case of the Order; never creates one
Method OpenCase(orderId As %String) As SignalNoir.Core.Result
{
	Return $$$ERROR($$$GeneralError, "Abstract port method - override in adapter or fake")
}

/// expectedState and expectedTarget are not checked when empty
Method Transition(caseId As %String, expectedVersion As %Integer, toState As %String, actor As %String, event As SignalNoir.Core.Dto.TimelineEvent, expectedState As %String = "", expectedTarget As %String = "") As SignalNoir.Core.Result
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

/// Rejected -> Investigating (first rejection) or -> ReviewRequired (second)
Method ResolveRejection(caseId As %String, expectedVersion As %Integer, reason As %String) As SignalNoir.Core.Result
{
	Return $$$ERROR($$$GeneralError, "Abstract port method - override in adapter or fake")
}

}
