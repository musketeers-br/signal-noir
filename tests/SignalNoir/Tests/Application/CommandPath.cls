/// The single command path records each decision atomically (specs/002 FR-003 to FR-006).
Class SignalNoir.Tests.Application.CommandPath Extends %UnitTest.TestCase
{

Parameter PREFIX = "TEST-CMD-";

Method OnBeforeOneTest(testname As %String) As %Status
{
    quit ##class(SignalNoir.Tests.Application.Fixtures).Purge(..#PREFIX)
}

Method TestAppliedIsAtomic()
{
    set case = ##class(SignalNoir.Tests.Application.Fixtures).CreateCase(..#PREFIX_"1", "PendingApproval", 5, {"CurrentProposalId": "prop_1"})
    set command = ##class(SignalNoir.Tests.Application.Fixtures).Command("operator:Carla", case, "Approved", {"decision": "approved"})
    set command.TargetId = "prop_1"
    set result = ##class(SignalNoir.Application.CaseCommands).Submit(case.CaseId, command)
    do $$$AssertEquals(result.Outcome, "Applied", "applied ("_result.RefusalCode_result.FailureText_")")
    set stored = ##class(SignalNoir.Application.Store.Case).%OpenId(case.CaseId)
    do stored.%Reload()
    do $$$AssertEquals(stored.State, "Approved")
    do $$$AssertEquals(stored.CaseVersion, 6)
    do $$$AssertEquals(##class(SignalNoir.Tests.Application.Fixtures).EventTypes(case.CaseId), "StateChanged,ApprovalRecorded")
    do $$$AssertEquals(##class(SignalNoir.Tests.Application.Fixtures).OutboxKinds(case.CaseId), "Execute")
    &sql(SELECT ExpiresAt, ByActor INTO :expiresAt, :by FROM SignalNoir_Application_Store.Approval WHERE CaseId = :case.CaseId AND Decision = 'approved')
    do $$$AssertEquals(SQLCODE, 0, "Approval record written")
    do $$$AssertEquals(by, "operator:Carla")
    do $$$AssertTrue(expiresAt ] $zdatetime($ztimestamp, 3, 7, 3), "Approval has a future deadline")
}

Method TestSameStepChain()
{
    set case = ##class(SignalNoir.Tests.Application.Fixtures).CreateCase(..#PREFIX_"2", "ReviewRequired", 3)
    set facts = {"resolutionAction": "RETRY", "verdict": "accepted", "requiresApproval": true, "proposalId": "prop_op1"}
    set result = ##class(SignalNoir.Application.CaseCommands).Submit(case.CaseId, ##class(SignalNoir.Tests.Application.Fixtures).Command("operator:Carla", case, "DecisionProposed", facts))
    do $$$AssertEquals(result.Outcome, "Applied", "applied ("_result.RefusalCode_result.FailureText_")")
    do $$$AssertEquals(##class(SignalNoir.Tests.Core.Parity).Joined(result.Transitions), "T28,T07,T11", "chain")
    set stored = ##class(SignalNoir.Application.Store.Case).%OpenId(case.CaseId)
    do stored.%Reload()
    do $$$AssertEquals(stored.State, "Approved")
    do $$$AssertEquals(stored.CaseVersion, 6, "one version per chained transition")
    do $$$AssertEquals(stored.CurrentProposalId, "prop_op1")
    do $$$AssertEquals(##class(SignalNoir.Tests.Application.Fixtures).EventTypes(case.CaseId), "StateChanged,OperatorResolution,ProposalCreated,StateChanged,ValidatorVerdict,StateChanged,ApprovalRecorded")
    do $$$AssertEquals(##class(SignalNoir.Tests.Application.Fixtures).OutboxKinds(case.CaseId), "Execute")
}

Method TestAttachKeepsVersion()
{
    set case = ##class(SignalNoir.Tests.Application.Fixtures).CreateCase(..#PREFIX_"3", "Executing", 7, {"execution": {"outcome": "in_progress"}})
    set result = ##class(SignalNoir.Application.CaseCommands).RecordException(case.OrderId, {"httpStatus": 500}, "system")
    do $$$AssertEquals(result.Outcome, "Attached", "attached ("_result.RefusalCode_result.FailureText_")")
    set stored = ##class(SignalNoir.Application.Store.Case).%OpenId(case.CaseId)
    do stored.%Reload()
    do $$$AssertEquals(stored.State, "Executing")
    do $$$AssertEquals(stored.CaseVersion, 7, "attachment does not change the version")
    do $$$AssertEquals(stored.PendingReassessmentExceptions, 1, "kept for reassessment")
    do $$$AssertEquals(##class(SignalNoir.Tests.Application.Fixtures).EventTypes(case.CaseId), "ExceptionRecorded")
}

Method TestFailureRecordsNothing()
{
    set case = ##class(SignalNoir.Tests.Application.Fixtures).CreateCase(..#PREFIX_"4", "PendingApproval", 5, {"CurrentProposalId": "prop_1"})
    set taken = ##class(SignalNoir.Application.Store.OutboxEntry).%New()
    set taken.CommandId = "cmd_taken.1", taken.Kind = "Execute", taken.CaseId = "case_other", taken.CaseVersionAfter = 1
    do $$$AssertStatusOK(taken.%Save())
    set command = ##class(SignalNoir.Tests.Application.Fixtures).Command("operator:Carla", case, "Approved", {"decision": "approved"})
    set command.TargetId = "prop_1", command.CommandId = "cmd_taken"
    set result = ##class(SignalNoir.Application.CaseCommands).Submit(case.CaseId, command)
    do taken.%DeleteId(taken.%Id())
    do $$$AssertEquals(result.Outcome, "Failed", "outbox collision fails the command")
    set stored = ##class(SignalNoir.Application.Store.Case).%OpenId(case.CaseId)
    do stored.%Reload()
    do $$$AssertEquals(stored.State_"/"_stored.CaseVersion, "PendingApproval/5", "state and version unchanged")
    do $$$AssertEquals(##class(SignalNoir.Tests.Application.Fixtures).EventTypes(case.CaseId), "", "no event recorded")
    &sql(SELECT COUNT(*) INTO :approvals FROM SignalNoir_Application_Store.Approval WHERE CaseId = :case.CaseId)
    do $$$AssertEquals(approvals, 0, "no Approval recorded")
}

Method TestRecordExceptionPaths()
{
    set result = ##class(SignalNoir.Application.CaseCommands).RecordException(..#PREFIX_"5", {"httpStatus": 500}, "system")
    do $$$AssertEquals(result.Outcome, "Applied", "first Exception opens a Case ("_result.RefusalCode_result.FailureText_")")
    do $$$AssertEquals(##class(SignalNoir.Tests.Core.Parity).Joined(result.Transitions), "T01")
    set stored = ##class(SignalNoir.Application.Store.Case).%OpenId(result.CaseId)
    do $$$AssertEquals(stored.State_"/"_stored.CaseVersion, "Open/1")
    do $$$AssertEquals(##class(SignalNoir.Tests.Application.Fixtures).EventTypes(result.CaseId), "StateChanged,CaseOpened,ExceptionRecorded")
    do $$$AssertEquals(##class(SignalNoir.Tests.Application.Fixtures).OutboxKinds(result.CaseId), "Investigate")

    set pending = ##class(SignalNoir.Tests.Application.Fixtures).CreateCase(..#PREFIX_"6", "PendingApproval", 5, {"CurrentProposalId": "prop_1"})
    set result = ##class(SignalNoir.Application.CaseCommands).RecordException(pending.OrderId, {"httpStatus": 500}, "system")
    do $$$AssertEquals(##class(SignalNoir.Tests.Core.Parity).Joined(result.Transitions), "T16", "new Exception in PendingApproval")
    set stored = ##class(SignalNoir.Application.Store.Case).%OpenId(pending.CaseId)
    do stored.%Reload()
    do $$$AssertEquals(stored.State_"/"_stored.CurrentProposalId, "Investigating/", "Proposal no longer current")
}

Method TestRefusalRecordsCommandDiscarded()
{
    set past = "2026-01-01T00:00:00.000Z"
    set cases = [
        {"state": "Open", "target": "Executing", "actor": "system", "code": "INVALID_TRANSITION", "props": {}},
        {"state": "PendingApproval", "target": "Approved", "actor": "benchmark", "code": "INVALID_ACTOR", "props": {"CurrentProposalId": "prop_1"}, "facts": {"sameStepAsValidation": true}},
        {"state": "PendingApproval", "target": "Approved", "actor": "operator:Carla", "code": "STALE_VERSION", "props": {"CurrentProposalId": "prop_1"}, "facts": {"decision": "approved"}, "stale": true},
        {"state": "Approved", "target": "Executing", "actor": "system", "code": "APPROVAL_EXPIRED", "props": {"CurrentProposalId": "prop_1", "approval": {"proposalId": "prop_1", "decision": "approved", "expiresAt": (past)}}}
    ]
    set it = cases.%GetIterator()
    while it.%GetNext(.i, .spec) {
        set case = ##class(SignalNoir.Tests.Application.Fixtures).CreateCase(..#PREFIX_"R"_i, spec.state, 4, spec.props)
        set command = ##class(SignalNoir.Tests.Application.Fixtures).Command(spec.actor, case, spec.target, $select(spec.%IsDefined("facts"): spec.facts, 1: {}))
        set:spec.state="PendingApproval" command.TargetId = "prop_1"
        set:spec.stale command.ExpectedCaseVersion = 3
        set result = ##class(SignalNoir.Application.CaseCommands).Submit(case.CaseId, command)
        do $$$AssertEquals(result.Outcome_"/"_result.RefusalCode, "Refused/"_spec.code, spec.code)
        set stored = ##class(SignalNoir.Application.Store.Case).%OpenId(case.CaseId)
        do stored.%Reload()
        do $$$AssertEquals(stored.State_"/"_stored.CaseVersion, spec.state_"/4", spec.code_": state and version unchanged")
        do $$$AssertEquals(##class(SignalNoir.Tests.Application.Fixtures).EventTypes(case.CaseId), "CommandDiscarded", spec.code_": one CommandDiscarded")
        &sql(SELECT Payload INTO :payload FROM SignalNoir_Application_Store.TimelineEvent WHERE CaseId = :case.CaseId)
        set discarded = ##class(%DynamicObject).%FromJSON(payload)
        do $$$AssertEquals(discarded.code_"/"_discarded.actor_"/"_discarded.currentState_"/"_discarded.requestedState, spec.code_"/"_spec.actor_"/"_spec.state_"/"_spec.target, spec.code_": payload")
    }
}

Method TestCasLostAtWrite()
{
    set case = ##class(SignalNoir.Tests.Application.Fixtures).CreateCase(..#PREFIX_"CAS", "PendingApproval", 5, {"CurrentProposalId": "prop_1"})
    set snapshot = ##class(SignalNoir.Application.CaseCommands).Snapshot(case)
    set command = ##class(SignalNoir.Tests.Application.Fixtures).Command("operator:Carla", case, "Approved", {"decision": "approved"})
    set command.TargetId = "prop_1"
    set decision = ##class(SignalNoir.Core.Decider).Decide(snapshot, command, ##class(SignalNoir.Application.CaseCommands).Now())
    // Another writer commits between the read and the write.
    set caseId = case.CaseId
    &sql(UPDATE SignalNoir_Application_Store.CaseRecord SET CaseVersion = 6 WHERE CaseId = :caseId)
    set result = ##class(SignalNoir.Application.CommandResult).%New()
    do ##class(SignalNoir.Application.CaseCommands).Record(case, snapshot, command, decision, ##class(SignalNoir.Application.CaseCommands).Now(), result)
    do $$$AssertEquals(result.Outcome_"/"_result.RefusalCode, "Refused/STALE_VERSION", "lost compare-and-swap")
    do $$$AssertEquals(##class(SignalNoir.Tests.Application.Fixtures).EventTypes(caseId), "CommandDiscarded", "recorded")
    &sql(SELECT COUNT(*) INTO :approvals FROM SignalNoir_Application_Store.Approval WHERE CaseId = :caseId)
    do $$$AssertEquals(approvals, 0, "no Approval kept")
}

Method TestIdempotentReplayReturnsExisting()
{
    set case = ##class(SignalNoir.Tests.Application.Fixtures).CreateCase(..#PREFIX_"REPLAY", "PendingApproval", 5, {"CurrentProposalId": "prop_1"})
    set first = ##class(SignalNoir.Tests.Application.Fixtures).Command("operator:Carla", case, "Approved", {"decision": "approved"})
    set first.TargetId = "prop_1"
    do $$$AssertEquals(##class(SignalNoir.Application.CaseCommands).Submit(case.CaseId, first).Outcome, "Applied")
    set again = ##class(SignalNoir.Core.TransitionCommand).%New()
    set again.Actor = "operator:Carla", again.RequestedState = "Approved", again.TargetId = "prop_1"
    set again.ExpectedState = "PendingApproval", again.ExpectedCaseVersion = 5, again.Facts = {"decision": "approved"}
    set result = ##class(SignalNoir.Application.CaseCommands).Submit(case.CaseId, again)
    do $$$AssertEquals(result.Outcome, "IdempotentReplay", "second click from an old screen")
    set caseId = case.CaseId
    &sql(SELECT COUNT(*) INTO :approvals FROM SignalNoir_Application_Store.Approval WHERE CaseId = :caseId)
    do $$$AssertEquals(approvals, 1, "one Approval")
    do $$$AssertEquals(##class(SignalNoir.Tests.Application.Fixtures).OutboxKinds(caseId), "Execute", "one Execute")
}

}
