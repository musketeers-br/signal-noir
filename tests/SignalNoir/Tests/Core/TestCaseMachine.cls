Class SignalNoir.Tests.Core.TestCaseMachine Extends %UnitTest.TestCase
{

/// T007 - only the three live transitions of this slice; the actor table
/// rejects an unlisted actor with INVALID_ACTOR

Method TestInitialTransitionToOpen()
{
	Do $$$AssertTrue(##class(SignalNoir.Core.CaseMachine).CanTransition("", "Open"), "initial transition to Open is live")
	Do $$$AssertEquals(##class(SignalNoir.Core.CaseMachine).Check("", "Open", "system"), "", "system may open a Case")
}

Method TestOpenToReviewRequired()
{
	Do $$$AssertTrue(##class(SignalNoir.Core.CaseMachine).CanTransition("Open", "ReviewRequired"), "Open -> ReviewRequired is live")
	Do $$$AssertEquals(##class(SignalNoir.Core.CaseMachine).Check("Open", "ReviewRequired", "system"), "", "system may move Open -> ReviewRequired")
}

Method TestOpenToInvestigating()
{
	Do $$$AssertTrue(##class(SignalNoir.Core.CaseMachine).CanTransition("Open", "Investigating"), "Open -> Investigating is live")
	Do $$$AssertEquals(##class(SignalNoir.Core.CaseMachine).Check("Open", "Investigating", "system"), "", "system may move Open -> Investigating")
}

Method TestOtherTransitionsRejected()
{
	Do $$$AssertEquals(##class(SignalNoir.Core.CaseMachine).Check("Open", "PendingApproval", "system"), "INVALID_TRANSITION", "Open -> PendingApproval not in this slice")
	Do $$$AssertEquals(##class(SignalNoir.Core.CaseMachine).Check("ReviewRequired", "Open", "system"), "INVALID_TRANSITION", "no implicit reopen from ReviewRequired")
	Do $$$AssertEquals(##class(SignalNoir.Core.CaseMachine).Check("Resolved", "Open", "system"), "INVALID_TRANSITION", "terminal state does not reopen")
}

Method TestActorTableRejectsUnlistedActor()
{
	Do $$$AssertEquals(##class(SignalNoir.Core.CaseMachine).Check("Open", "Investigating", "robot"), "INVALID_ACTOR", "unlisted actor rejected with INVALID_ACTOR")
	Do $$$AssertEquals(##class(SignalNoir.Core.CaseMachine).Check("Open", "Investigating", "operator:carla"), "INVALID_ACTOR", "operator not in the actor table for this transition")
	Do $$$AssertEquals(##class(SignalNoir.Core.CaseMachine).Check("", "Open", ""), "INVALID_ACTOR", "missing actor rejected")
}

}
