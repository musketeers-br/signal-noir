/// Terminal Cases never reopen; a new episode opens a linked Case (specs/002 User Story 4).
Class SignalNoir.Tests.Application.Episodes Extends %UnitTest.TestCase
{

Parameter PREFIX = "TEST-EP-";

Parameter TERMINALS = "Resolved,ResolvedByPriorReceipt,Cancelled,Failed";

Method OnBeforeOneTest(testname As %String) As %Status
{
    quit ##class(SignalNoir.Tests.Application.Fixtures).Purge(..#PREFIX)
}

Method TestTerminalRefusesTransitions()
{
    set states = ##class(SignalNoir.Tests.Core.TableFixture).Load().states
    for k = 1:1:$length(..#TERMINALS, ",") {
        set terminal = $piece(..#TERMINALS, ",", k)
        set case = ##class(SignalNoir.Tests.Application.Fixtures).CreateCase(..#PREFIX_"T"_k, terminal, 9)
        set it = states.%GetIterator()
        while it.%GetNext(.i, .state) {
            set result = ##class(SignalNoir.Application.CaseCommands).Submit(case.CaseId, ##class(SignalNoir.Tests.Application.Fixtures).Command("system", case, state.name))
            do $$$AssertEquals(result.Outcome_"/"_result.RefusalCode_"/"_result.CaseVersion, "Refused/INVALID_TRANSITION/9", terminal_" -> "_state.name)
        }
    }
}

Method TestNewEpisodeAfterResolved()
{
    set old = ##class(SignalNoir.Tests.Application.Fixtures).CreateCase(..#PREFIX_"1", "Resolved", 9)
    set result = ##class(SignalNoir.Application.CaseCommands).RecordException(old.OrderId, {"httpStatus": 500}, "system")
    do $$$AssertEquals(result.Outcome_"/"_##class(SignalNoir.Tests.Core.Parity).Joined(result.Transitions), "Applied/T02", "new episode ("_result.FailureText_")")
    set new = ##class(SignalNoir.Application.Store.Case).%OpenId(result.CaseId)
    do $$$AssertTrue($isobject(new) && (new.CaseId '= old.CaseId), "a new Case")
    do $$$AssertEquals(new.State_"/"_new.PreviousEpisodeCaseId, "Open/"_old.CaseId, "linked to the previous episode")
    do old.%Reload()
    do $$$AssertEquals(old.State_"/"_old.CaseVersion, "Resolved/9", "the previous Case stays as it was")
    do $$$AssertEquals(##class(SignalNoir.Tests.Application.Fixtures).EventTypes(old.CaseId), "Annotation", "the previous Case gains only an annotation")
    set oldId = old.CaseId
    &sql(SELECT Payload INTO :payload FROM SignalNoir_Application_Store.TimelineEvent WHERE CaseId = :oldId)
    set annotation = ##class(%DynamicObject).%FromJSON(payload)
    do $$$AssertEquals(annotation.facts.kind_"/"_annotation.facts.newCaseId, "new_episode_opened/"_new.CaseId, "annotation names the new Case")
}

Method TestFailedWithPendingExceptionOpensEpisode()
{
    set case = ##class(SignalNoir.Tests.Application.Fixtures).CreateCase(..#PREFIX_"2", "Executing", 7, {"PendingReassessmentExceptions": 1, "execution": {"outcome": "in_progress", "attemptsSent": 3}})
    set command = ##class(SignalNoir.Tests.Application.Fixtures).Command("system", case, "Failed", {"attemptsExhausted": true, "noUncertainAttemptPending": true})
    set result = ##class(SignalNoir.Application.CaseCommands).Submit(case.CaseId, command)
    do $$$AssertEquals(result.Outcome_"/"_##class(SignalNoir.Tests.Core.Parity).Joined(result.Transitions), "Applied/T25,T02", "failed and new episode in one command ("_result.FailureText_")")
    do case.%Reload()
    do $$$AssertEquals(case.State_"/"_case.PendingReassessmentExceptions, "Failed/0", "the failed Case keeps no pending Exception")
    set orderId = case.OrderId, caseId = case.CaseId
    &sql(SELECT CaseId, State, PreviousEpisodeCaseId INTO :newId, :newState, :previous FROM SignalNoir_Application_Store.CaseRecord WHERE OrderId = :orderId AND CaseId <> :caseId)
    do $$$AssertEquals(SQLCODE, 0, "the new episode exists")
    do $$$AssertEquals(newState_"/"_previous, "Open/"_caseId, "new Case open and linked")
    do $$$AssertTrue(##class(SignalNoir.Tests.Application.Fixtures).EventTypes(newId) [ "ExceptionRecorded", "the reassessed Exception moved to the new Case")
}

Method TestTerminalAnnotationsOnly()
{
    set case = ##class(SignalNoir.Tests.Application.Fixtures).CreateCase(..#PREFIX_"3", "Resolved", 9)
    set command = ##class(SignalNoir.Tests.Application.Fixtures).Command("system", case, "", {"kind": "receipt_corrected", "previous": "RCP-1", "current": "RCP-2"})
    set command.Kind = "Attach", command.AttachEvent = "Annotation"
    set result = ##class(SignalNoir.Application.CaseCommands).Submit(case.CaseId, command)
    do $$$AssertEquals(result.Outcome_"/"_result.CaseVersion, "Attached/9", "receipt correction is an annotation, no version change")

    set command = ##class(SignalNoir.Tests.Application.Fixtures).Command("operator:Carla", case, "", {"kind": "note", "text": "free text"})
    set command.Kind = "Attach", command.AttachEvent = "Annotation"
    do $$$AssertEquals(##class(SignalNoir.Application.CaseCommands).Submit(case.CaseId, command).Outcome, "Refused", "free notes are not accepted on a terminal Case")

    set command = ##class(SignalNoir.Tests.Application.Fixtures).Command("system", case, "")
    set command.Kind = "Attach", command.AttachEvent = "ExceptionRecorded"
    do $$$AssertEquals(##class(SignalNoir.Application.CaseCommands).Submit(case.CaseId, command).Outcome, "Refused", "an Exception is never attached to a terminal Case")
}

Method TestOpenOrderKeyFreedOnTerminal()
{
    set case = ##class(SignalNoir.Tests.Application.Fixtures).CreateCase(..#PREFIX_"4", "ReviewRequired", 3)
    set result = ##class(SignalNoir.Application.CaseCommands).Submit(case.CaseId, ##class(SignalNoir.Tests.Application.Fixtures).Command("operator:Carla", case, "Cancelled", {"reason": "duplicate order"}))
    do $$$AssertEquals(result.Outcome_"/"_result.State, "Applied/Cancelled", "cancelled")
    set result = ##class(SignalNoir.Application.CaseCommands).RecordException(case.OrderId, {"httpStatus": 500}, "system")
    do $$$AssertEquals(##class(SignalNoir.Tests.Core.Parity).Joined(result.Transitions), "T02", "the Order can open a new episode ("_result.FailureText_")")
    set orderId = case.OrderId
    &sql(SELECT COUNT(*) INTO :cases FROM SignalNoir_Application_Store.CaseRecord WHERE OrderId = :orderId)
    do $$$AssertEquals(cases, 2, "two episodes")
}

}
