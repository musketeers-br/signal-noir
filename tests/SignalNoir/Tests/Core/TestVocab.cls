Class SignalNoir.Tests.Core.TestVocab Extends %UnitTest.TestCase
{

/// T006 - closed vocabularies are exactly as specified
Method TestStatesExactly()
{
	Set expected = $ListBuild("Open", "Investigating", "DecisionProposed", "PendingApproval", "Approved", "Rejected", "Executing", "Held", "ReviewRequired", "Resolved", "ResolvedByPriorReceipt", "Cancelled", "Failed")
	Set actual = ##class(SignalNoir.Core.Vocab).States()
	Do $$$AssertEquals($ListLength(actual), $ListLength(expected), "state count")
	For i = 1 : 1 : $ListLength(expected) {
		Do $$$AssertEquals($ListGet(actual, i), $ListGet(expected, i), "state position " _ i)
	}
}

Method TestActionsExactly()
{
	Set expected = $ListBuild("RETRY", "APPLY_APPROVED_MAPPING", "HOLD", "REQUEST_REVIEW")
	Set actual = ##class(SignalNoir.Core.Vocab).Actions()
	Do $$$AssertEquals($ListLength(actual), 4, "action count")
	For i = 1 : 1 : $ListLength(expected) {
		Do $$$AssertEquals($ListGet(actual, i), $ListGet(expected, i), "action position " _ i)
	}
}

Method TestCommandsExactly()
{
	Set expected = $ListBuild("Investigate", "Execute", "Reconcile", "Expire", "Reassess", "Resume")
	Set actual = ##class(SignalNoir.Core.Vocab).Commands()
	Do $$$AssertEquals($ListLength(actual), 6, "command count")
	For i = 1 : 1 : $ListLength(expected) {
		Do $$$AssertEquals($ListGet(actual, i), $ListGet(expected, i), "command position " _ i)
	}
}

Method TestErrorCodesFromFrozenContract()
{
	Set expected = $ListBuild("STALE_VERSION", "INVALID_TRANSITION", "INVALID_ACTOR", "VALIDATION_FAILED", "NOT_FOUND")
	Set actual = ##class(SignalNoir.Core.Vocab).ErrorCodes()
	Do $$$AssertEquals($ListLength(actual), 5, "error code count")
	For i = 1 : 1 : $ListLength(expected) {
		Do $$$AssertEquals($ListGet(actual, i), $ListGet(expected, i), "error code position " _ i)
	}
}

Method TestActors()
{
	Do $$$AssertTrue(##class(SignalNoir.Core.Vocab).IsActor("system"), "system actor")
	Do $$$AssertTrue(##class(SignalNoir.Core.Vocab).IsActor("sweeper"), "sweeper actor")
	Do $$$AssertTrue(##class(SignalNoir.Core.Vocab).IsActor("benchmark"), "benchmark actor")
	Do $$$AssertTrue(##class(SignalNoir.Core.Vocab).IsActor("agent"), "agent actor")
	Do $$$AssertTrue(##class(SignalNoir.Core.Vocab).IsActor("operator:carla"), "operator actor with name")
	Do $$$AssertTrue('(##class(SignalNoir.Core.Vocab).IsActor("robot")), "unlisted actor rejected")
	Do $$$AssertTrue('(##class(SignalNoir.Core.Vocab).IsActor("operator:")), "empty operator name rejected")
}

/// 003 T003 - actors of the contract, Exception kinds, Timeline event types,
/// new id prefixes
Method TestActorsOfTheContract()
{
	Do $$$AssertTrue(##class(SignalNoir.Core.Vocab).IsActor("rules"), "rules actor")
	Do $$$AssertTrue(##class(SignalNoir.Core.Vocab).IsActor("replay"), "replay actor")
}

Method TestExceptionKindsExactly()
{
	Set expected = $ListBuild("timeout", "http_error", "invalid_receipt", "business_rejection", "processing_error")
	Set actual = ##class(SignalNoir.Core.Vocab).ExceptionKinds()
	Do $$$AssertEquals($ListLength(actual), 5, "exception kind count")
	For i = 1 : 1 : $ListLength(expected) {
		Do $$$AssertEquals($ListGet(actual, i), $ListGet(expected, i), "exception kind position " _ i)
	}
	Do $$$AssertTrue('##class(SignalNoir.Core.Vocab).IsExceptionKind("crash"), "unknown kind refused")
}

Method TestEventTypesFromFrozenContract()
{
	Set expected = $ListBuild("CaseOpened", "ExceptionRecorded", "StateChanged", "ToolCalled", "EvidenceObsoleted", "ProposalCreated", "ValidatorVerdict", "ApprovalRecorded", "ApprovalExpired", "ExecutionAuthorized", "RevalidationPerformed", "AttemptRecorded", "ReconciliationPerformed", "ReceiptRecorded", "ReassessmentPerformed", "DossierCreated", "OperatorResolution", "CommandDiscarded", "Annotation")
	Set actual = ##class(SignalNoir.Core.Vocab).EventTypes()
	Do $$$AssertEquals($ListLength(actual), $ListLength(expected), "event type count")
	For i = 1 : 1 : $ListLength(expected) {
		Do $$$AssertEquals($ListGet(actual, i), $ListGet(expected, i), "event type position " _ i)
	}
	Do $$$AssertTrue('##class(SignalNoir.Core.Vocab).IsEventType("CaseTransition"), "event type outside the contract refused")
	Do $$$AssertTrue('##class(SignalNoir.Core.Vocab).IsEventType("OrderAccepted"), "OrderAccepted is not a contract event type")
}

Method TestNewIdPrefixes()
{
	Do $$$AssertTrue(##class(SignalNoir.Core.Vocab).IsIdPrefix("corr_"), "correlation prefix")
	Do $$$AssertTrue(##class(SignalNoir.Core.Vocab).IsIdPrefix("exc_"), "exception prefix")
}

/// 003 T006 - the clock speaks UTC with the contract UtcDateTime shape
Method TestClockIsUtcWithMilliseconds()
{
	Set now = ##class(SignalNoir.Application.SystemClock).%New().NowUtc()
	Do $$$AssertTrue(now ?4N1"-"2N1"-"2N1"T"2N1":"2N1":"2N1"."3N1"Z", "UtcDateTime with milliseconds: " _ now)
	Set utc = $ZDateTime($ZTimestamp, 3, 1)
	Do $$$AssertEquals($Extract(now, 1, 13), $Extract($Replace(utc, " ", "T"), 1, 13), "clock is UTC, not local time")
}

}
