/// Concurrent writers on one Case: exactly one wins, every loser leaves a recorded refusal or
/// attachment, nothing is applied twice (specs/002 SC-004, research R9). Each scenario runs RUNS
/// times with two background processes released by a shared barrier.
Class SignalNoir.Tests.Application.Concurrency Extends %UnitTest.TestCase
{

Parameter PREFIX = "TEST-CONC-";

Parameter RUNS = 100;

Method OnBeforeOneTest(testname As %String) As %Status
{
    kill ^SignalNoir.Test.Conc
    quit ##class(SignalNoir.Tests.Application.Fixtures).Purge(..#PREFIX)
}

Method OnAfterOneTest(testname As %String) As %Status
{
    kill ^SignalNoir.Test.Conc
    quit ##class(SignalNoir.Tests.Application.Fixtures).Purge(..#PREFIX)
}

Method TestTwoApprovals()
{
    for run = 1:1:..#RUNS {
        set case = ##class(SignalNoir.Tests.Application.Fixtures).CreateCase(..#PREFIX_"A"_run, "PendingApproval", 5, {"CurrentProposalId": "prop_1"})
        set outcomes = ..Race("approve", case.CaseId, case.OrderId)
        set caseId = case.CaseId
        &sql(SELECT COUNT(*) INTO :approvals FROM SignalNoir_Application_Store.Approval WHERE CaseId = :caseId)
        &sql(SELECT CaseVersion INTO :version FROM SignalNoir_Application_Store.CaseRecord WHERE CaseId = :caseId)
        set ok = (approvals = 1) && (version = 6) && ($length(outcomes, "Applied") = 2) && ..LosersRecorded(caseId, outcomes)
        if '$$$AssertTrue(ok, "run "_run_": one Approval, one transition, loser recorded ("_outcomes_", approvals "_approvals_", version "_version_")") quit
    }
}

Method TestApprovalVersusException()
{
    for run = 1:1:..#RUNS {
        set case = ##class(SignalNoir.Tests.Application.Fixtures).CreateCase(..#PREFIX_"E"_run, "PendingApproval", 5, {"CurrentProposalId": "prop_1"})
        set outcomes = ..Race("approve,exception", case.CaseId, case.OrderId)
        set caseId = case.CaseId
        &sql(SELECT CaseVersion, State INTO :version, :state FROM SignalNoir_Application_Store.CaseRecord WHERE CaseId = :caseId)
        set types = ##class(SignalNoir.Tests.Application.Fixtures).EventTypes(caseId)
        set exceptions = $length(types, "ExceptionRecorded") - 1
        set ok = (version = 6) && ((state = "Approved") || (state = "Investigating")) && (exceptions = 1)
        if '$$$AssertTrue(ok, "run "_run_": one transition, the Exception recorded once ("_outcomes_", "_state_" v"_version_", "_types_")") quit
    }
}

Method TestTwoFirstExceptions()
{
    for run = 1:1:..#RUNS {
        set orderId = ..#PREFIX_"F"_run
        set outcomes = ..Race("exception,exception", "", orderId)
        &sql(SELECT COUNT(*), MAX(CaseId) INTO :cases, :caseId FROM SignalNoir_Application_Store.CaseRecord WHERE OrderId = :orderId)
        set types = ##class(SignalNoir.Tests.Application.Fixtures).EventTypes(caseId)
        set ok = (cases = 1) && (($length(types, "ExceptionRecorded") - 1) = 2)
        if '$$$AssertTrue(ok, "run "_run_": one Case, both Exceptions recorded ("_outcomes_", cases "_cases_", "_types_")") quit
    }
}

/// Starts one process per comma-separated action (one action means two of it), releases them
/// together and returns their outcomes, comma-separated.
Method Race(actions As %String, caseId As %String, orderId As %String) As %String
{
    if $length(actions, ",") = 1 set actions = actions_","_actions
    set key = $increment(^SignalNoir.Test.Conc)
    for slot = 1, 2 {
        set action = $piece(actions, ",", slot)
        job ##class(SignalNoir.Tests.Application.Concurrency).Worker(key, slot, action, caseId, orderId)
    }
    set ^SignalNoir.Test.Conc(key, "go") = 1
    for i = 1:1:1000 { quit:$data(^SignalNoir.Test.Conc(key, "result", 1))&&$data(^SignalNoir.Test.Conc(key, "result", 2))  hang 0.01 }
    quit $get(^SignalNoir.Test.Conc(key, "result", 1), "timeout")_","_$get(^SignalNoir.Test.Conc(key, "result", 2), "timeout")
}

ClassMethod Worker(key As %Integer, slot As %Integer, action As %String, caseId As %String, orderId As %String)
{
    try {
        for i = 1:1:2000 { quit:$get(^SignalNoir.Test.Conc(key, "go"))  hang 0.001 }
        if action = "exception" {
            set result = ##class(SignalNoir.Application.CaseCommands).RecordException(orderId, {"httpStatus": 500, "slot": (slot)}, "system")
        } else {
            set command = ##class(SignalNoir.Core.TransitionCommand).%New()
            set command.Actor = "operator:Op"_slot, command.RequestedState = "Approved", command.TargetId = "prop_1"
            set command.ExpectedState = "PendingApproval", command.ExpectedCaseVersion = 5, command.Facts = {"decision": "approved"}
            set result = ##class(SignalNoir.Application.CaseCommands).Submit(caseId, command)
        }
        set ^SignalNoir.Test.Conc(key, "result", slot) = result.Outcome_$select(result.RefusalCode '= "": ":"_result.RefusalCode, 1: "")_$select(result.FailureText '= "": ":"_result.FailureText, 1: "")
    } catch error {
        set ^SignalNoir.Test.Conc(key, "result", slot) = "error:"_error.DisplayString()
    }
}

/// A refused loser must have left its CommandDiscarded on the Timeline.
ClassMethod LosersRecorded(caseId As %String, outcomes As %String) As %Boolean
{
    set refused = $length(outcomes, "Refused") - 1
    set discarded = $length(##class(SignalNoir.Tests.Application.Fixtures).EventTypes(caseId), "CommandDiscarded") - 1
    quit refused = discarded
}

}
