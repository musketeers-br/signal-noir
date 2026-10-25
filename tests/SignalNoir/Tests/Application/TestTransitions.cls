Class SignalNoir.Tests.Application.TestTransitions Extends %UnitTest.TestCase
{

/// 003 T030 - US3: one state machine, atomic commit, visible losers
Method TestTransitionWritesStateEventAndFollowUpTogether()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ##class(SignalNoir.Tests.Support).OpenCase(svc, ##class(SignalNoir.Tests.Support).Uid("tr"))
	Set before = svc.GetCase(caseId).obj
	Set t = svc.Transition(caseId, before.caseVersion, "Investigating", "system", ##class(SignalNoir.Tests.Support).Ev("routed"))
	Do $$$AssertTrue(t.ok, "allowed")
	Set after = svc.GetCase(caseId).obj
	Do $$$AssertEquals(after.caseVersion, before.caseVersion + 1, "caseVersion + 1")
	Set ev = svc.GetTimeline(caseId, before.lastEventSeq).list.GetAt(1)
	Do $$$AssertEquals(ev.type, "StateChanged", "StateChanged")
	Do $$$AssertEquals(ev.payload.from, "Open", "from")
	Do $$$AssertEquals(ev.payload.to, "Investigating", "to")
	Do $$$AssertEquals(ev.payload.reason, "routed", "reason")
	Do $$$AssertEquals(ev.payload.caseVersionAfter, after.caseVersion, "caseVersionAfter")
	Do $$$AssertEquals(ev.actor, "system", "actor")
	Do $$$AssertEquals(##class(SignalNoir.Tests.Support).Outbox(caseId, .rows), 1, "one follow-up")
	Do $$$AssertEquals($ListGet(rows(1), 2), "Investigate", "Investigate")
	Do $$$AssertEquals($ListGet(rows(1), 3), "pending", "pending")
	Do $$$AssertEquals($ListGet(rows(1), 4), after.caseVersion, "caseVersionAfter on the work")
}

Method TestForbiddenTransitionWritesNothing()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ##class(SignalNoir.Tests.Support).OpenCase(svc, ##class(SignalNoir.Tests.Support).Uid("forbid"))
	Set before = svc.GetCase(caseId).obj
	Set t = svc.Transition(caseId, before.caseVersion, "Executing", "system", ##class(SignalNoir.Tests.Support).Ev())
	Do $$$AssertEquals(t.code, "INVALID_TRANSITION", "Open -> Executing refused")
	Do $$$AssertEquals(t.details.state, "Open", "details carry the current state")
	Do ..AssertUnchanged(svc, caseId, before)
}

Method TestUnauthorizedActorWritesNothing()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ##class(SignalNoir.Tests.Support).OpenCase(svc, ##class(SignalNoir.Tests.Support).Uid("actor"))
	Do $$$AssertEquals(##class(SignalNoir.Tests.Support).DriveTo(svc, caseId, "PendingApproval"), "", "walked to PendingApproval")
	Set before = svc.GetCase(caseId).obj
	Set t = svc.Transition(caseId, before.caseVersion, "Approved", "agent", ##class(SignalNoir.Tests.Support).Ev())
	Do $$$AssertEquals(t.code, "INVALID_ACTOR", "agent cannot approve")
	Do ..AssertUnchanged(svc, caseId, before)
}

Method TestStaleVersionStateAndTarget()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ##class(SignalNoir.Tests.Support).OpenCase(svc, ##class(SignalNoir.Tests.Support).Uid("stale"))
	Set read = svc.GetCase(caseId).obj
	Do $$$AssertTrue(svc.Transition(caseId, read.caseVersion, "Investigating", "system", ##class(SignalNoir.Tests.Support).Ev()).ok, "first writer wins")
	Set before = svc.GetCase(caseId).obj
	Set t = svc.Transition(caseId, read.caseVersion, "ReviewRequired", "system", ##class(SignalNoir.Tests.Support).Ev())
	Do $$$AssertEquals(t.code, "STALE_VERSION", "stale version loses")
	Do $$$AssertEquals(t.details.expectedCaseVersion, read.caseVersion, "expected version echoed")
	Do $$$AssertEquals(t.details.caseVersion, before.caseVersion, "current version")
	Do $$$AssertEquals(t.details.lastEventSeq, before.lastEventSeq, "current lastEventSeq")
	Do $$$AssertEquals(t.details.state, "Investigating", "current state")
	Do $$$AssertTrue(t.details.serverTime '= "", "serverTime")
	Do ..AssertUnchanged(svc, caseId, before)
	Set t2 = svc.Transition(caseId, before.caseVersion, "ReviewRequired", "system", ##class(SignalNoir.Tests.Support).Ev(), "Open")
	Do $$$AssertEquals(t2.code, "STALE_VERSION", "expected state no longer holds")
	Set t3 = svc.Transition(caseId, before.caseVersion, "ReviewRequired", "system", ##class(SignalNoir.Tests.Support).Ev(), "", "prop_000001")
	Do $$$AssertEquals(t3.code, "STALE_VERSION", "expected target no longer holds")
	Do ..AssertUnchanged(svc, caseId, before)
}

Method TestTerminalAndHeldExits()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ##class(SignalNoir.Tests.Support).OpenCase(svc, ##class(SignalNoir.Tests.Support).Uid("term"))
	Do $$$AssertEquals(##class(SignalNoir.Tests.Support).DriveTo(svc, caseId, "Resolved"), "", "walked to Resolved")
	Set v = svc.GetCase(caseId).obj.caseVersion
	For to = "Open", "Investigating", "Executing", "ReviewRequired" {
		Do $$$AssertEquals(svc.Transition(caseId, v, to, "system", ##class(SignalNoir.Tests.Support).Ev()).code, "INVALID_TRANSITION", "Resolved -> " _ to)
	}
	Set held = ##class(SignalNoir.Tests.Support).OpenCase(svc, ##class(SignalNoir.Tests.Support).Uid("held"))
	Do $$$AssertEquals(##class(SignalNoir.Tests.Support).DriveTo(svc, held, "Held"), "", "walked to Held")
	Set v = svc.GetCase(held).obj.caseVersion
	For to = "PendingApproval", "Executing", "Resolved", "Approved" {
		Do $$$AssertEquals(svc.Transition(held, v, to, "system", ##class(SignalNoir.Tests.Support).Ev()).code, "INVALID_TRANSITION", "Held -> " _ to)
	}
	Do $$$AssertTrue(svc.Transition(held, v, "Investigating", "sweeper", ##class(SignalNoir.Tests.Support).Ev("reassessment")).ok, "Held -> Investigating by the sweeper")
}

Method TestAppendIsAnAttachment()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ##class(SignalNoir.Tests.Support).OpenCase(svc, ##class(SignalNoir.Tests.Support).Uid("app"))
	Set before = svc.GetCase(caseId).obj
	Set event = ##class(SignalNoir.Core.Dto.TimelineEvent).%New()
	Set event.type = "CaseTransition"
	Set event.actor = "system"
	Do $$$AssertEquals(svc.Append(caseId, event).code, "VALIDATION_FAILED", "type outside the contract refused")
	Set event.type = "StateChanged"
	Do $$$AssertEquals(svc.Append(caseId, event).code, "VALIDATION_FAILED", "StateChanged only through a transition")
	Set event.type = "Annotation"
	Set event.payload = {"note": "checked"}
	Set a = svc.Append(caseId, event)
	Do $$$AssertTrue(a.ok, "Annotation appended")
	Set after = svc.GetCase(caseId).obj
	Do $$$AssertEquals(a.obj.seq, before.lastEventSeq + 1, "next seq")
	Do $$$AssertEquals(after.lastEventSeq, before.lastEventSeq + 1, "watermark advanced")
	Do $$$AssertEquals(after.caseVersion, before.caseVersion, "caseVersion unchanged")
	Do $$$AssertEquals(after.state, before.state, "state unchanged")
}

Method TestFailureMidTransitionLeavesNothing()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ##class(SignalNoir.Tests.Support).OpenCase(svc, ##class(SignalNoir.Tests.Support).Uid("atomic"))
	Set before = svc.GetCase(caseId).obj
	Set broken = ##class(SignalNoir.Application.CaseService).Default()
	Set broken.Ids = ##class(SignalNoir.Tests.Fakes.BrokenCmdIds).%New()
	Set t = broken.Transition(caseId, before.caseVersion, "Investigating", "system", ##class(SignalNoir.Tests.Support).Ev())
	Do $$$AssertEquals(t.ok, 0, "the follow-up could not be saved")
	Do ..AssertUnchanged(svc, caseId, before)
	Do $$$AssertEquals(##class(SignalNoir.Application.Model.CaseEventRecord).%ExistsId(caseId _ "||" _ (before.lastEventSeq + 1)), 0, "no event row left behind")
	; the seq is not burnt: the next transition takes the next number
	Set t2 = svc.Transition(caseId, before.caseVersion, "Investigating", "system", ##class(SignalNoir.Tests.Support).Ev())
	Do $$$AssertTrue(t2.ok, "a later writer succeeds")
	Do $$$AssertEquals(svc.GetCase(caseId).obj.lastEventSeq, before.lastEventSeq + 1, "no gap in seq")
}

Method AssertUnchanged(svc, caseId, before)
{
	Set now = svc.GetCase(caseId).obj
	Do $$$AssertEquals(now.state, before.state, "state unchanged")
	Do $$$AssertEquals(now.caseVersion, before.caseVersion, "caseVersion unchanged")
	Do $$$AssertEquals(now.lastEventSeq, before.lastEventSeq, "Timeline unchanged")
	Set n = ##class(SignalNoir.Tests.Support).Outbox(caseId, .rows)
	Set pending = 0
	For i = 1 : 1 : n {
		If $ListGet(rows(i), 4) > before.caseVersion Set pending = pending + 1
	}
	Do $$$AssertEquals(pending, 0, "no follow-up from the refused command")
}

}
