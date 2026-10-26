Class SignalNoir.Tests.Application.TestConcurrency Extends %UnitTest.TestCase
{

/// 003 T023, T031 - concurrent writers on separate processes
Parameter TRIALS = 100;

/// SC-003: two writers on the same version, exactly one wins, 100 times
Method TestTwoWritersOneWins()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set wins = 0, losses = 0, other = 0
	For trial = 1 : 1 : ..#TRIALS {
		Set caseId = ##class(SignalNoir.Tests.Support).OpenCase(svc, ##class(SignalNoir.Tests.Support).Uid("race"))
		Set before = svc.GetCase(caseId).obj
		Set key = "race-" _ $JOB _ "-" _ trial
		Job ##class(SignalNoir.Tests.Support).RaceTransition(key, caseId, before.caseVersion, "Investigating")
		Job ##class(SignalNoir.Tests.Support).RaceTransition(key, caseId, before.caseVersion, "ReviewRequired")
		Set ^SignalNoir.TestBarrier(key) = 1
		Do ##class(SignalNoir.Tests.Support).WaitResults(key, 2)
		Set (ok, stale) = 0
		Set j = ""
		For {
			Set j = $Order(^SignalNoir.TestRace(key, j), 1, v)
			Quit:j=""
			If v = "ok" { Set ok = ok + 1 } ElseIf v = "STALE_VERSION" { Set stale = stale + 1 } Else { Set other = other + 1 }
		}
		If (ok = 1) && (stale = 1) { Set wins = wins + 1 } Else { Set losses = losses + 1 }
		Set after = svc.GetCase(caseId).obj
		If after.caseVersion '= (before.caseVersion + 1) Set losses = losses + 1
		Set changed = 0
		Set tl = svc.GetTimeline(caseId, before.lastEventSeq)
		For i = 1 : 1 : tl.list.Count() {
			If tl.list.GetAt(i).type = "StateChanged" Set changed = changed + 1
		}
		If changed '= 1 Set losses = losses + 1
		Kill ^SignalNoir.TestRace(key), ^SignalNoir.TestBarrier(key)
	}
	Do $$$AssertEquals(wins, ..#TRIALS, "exactly one winner in every trial")
	Do $$$AssertEquals(losses, 0, "no trial with two winners, no winner, or a double write")
	Do $$$AssertEquals(other, 0, "the loser always gets STALE_VERSION")
}

/// FR-011: concurrent first Exceptions of one orderId -> one Case with both
Method TestConcurrentFirstExceptions()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	For trial = 1 : 1 : 10 {
		Set orderId = ##class(SignalNoir.Tests.Support).Uid("dup")
		Do svc.AcceptOrder(##class(SignalNoir.Tests.Support).Order(orderId))
		Set key = "dup-" _ $JOB _ "-" _ trial
		Job ##class(SignalNoir.Tests.Support).RaceException(key, orderId)
		Job ##class(SignalNoir.Tests.Support).RaceException(key, orderId)
		Set ^SignalNoir.TestBarrier(key) = 1
		Do ##class(SignalNoir.Tests.Support).WaitResults(key, 2)
		Set a = $Order(^SignalNoir.TestRace(key, ""), 1, va)
		Set b = $Order(^SignalNoir.TestRace(key, a), 1, vb)
		Do $$$AssertTrue((va = vb) && ($Extract(va, 1, 5) = "case_"), "both joined one Case: " _ va _ " / " _ vb)
		Do $$$AssertEquals(##class(SignalNoir.Tests.Support).Count("SELECT COUNT(*) FROM SignalNoir_Application_Model.CaseRecord WHERE orderId = ?", orderId), 1, "one Case")
		Do $$$AssertEquals(##class(SignalNoir.Tests.Support).Count("SELECT COUNT(*) FROM SignalNoir_Application_Model.ExceptionRecord WHERE orderId = ?", orderId), 2, "both Exceptions")
		Kill ^SignalNoir.TestRace(key), ^SignalNoir.TestBarrier(key)
	}
}

}
