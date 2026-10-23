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

}
