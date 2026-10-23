/// The Operator journeys UJ-1 to UJ-4 replayed end to end through the command path, with the
/// actors of the table's journeyTrace (specs/002 User Story 3, SC-003).
Class SignalNoir.Tests.Application.Journeys Extends %UnitTest.TestCase
{

Parameter PREFIX = "TEST-UJ-";

Method OnBeforeOneTest(testname As %String) As %Status
{
    quit ##class(SignalNoir.Tests.Application.Fixtures).Purge(..#PREFIX)
}

Method TestUJ1()
{
    set runner = ..Run("UJ-1", .steps)
    do $$$AssertEquals(..StateAfter(steps, "step 5"), "Approved", "Carla approves")
    do $$$AssertEquals(..StateAfter(steps, "step 6"), "Resolved", "executed and resolved")
    do $$$AssertEquals(..Outcome(runner, "FR-014"), "IdempotentReplay", "the second approval is an idempotent replay")
    do $$$AssertEquals(..Count("Execution", runner.CaseId), 1, "one Execution")
    do $$$AssertTrue(##class(SignalNoir.Tests.Application.Fixtures).EventTypes(runner.CaseId) [ "ExecutionAuthorized", "authorization recorded")
}

Method TestUJ2()
{
    set runner = ..Run("UJ-2", .steps)
    do $$$AssertEquals(..StateAfter(steps, "steps 2–3"), "Held", "revalidation holds")
    do $$$AssertEquals(..StateAfter(steps, "step 4"), "Approved", "new Proposal approved again")
    do $$$AssertEquals(..Count("Approval", runner.CaseId), 2, "a second Approval, the first never reused")
    do $$$AssertEquals(..StateAfter(steps, "step 5 (variant)"), "Cancelled", "Order cancelled at the origin")
    set caseId = runner.CaseId
    &sql(SELECT SUM(AttemptsSent) INTO :attempts FROM SignalNoir_Application_Store.Execution WHERE CaseId = :caseId)
    do $$$AssertEquals(+attempts, 0, "nothing was sent")
    &sql(SELECT COUNT(*) INTO :voided FROM SignalNoir_Application_Store.Execution WHERE CaseId = :caseId AND AuthorizationVoided = 1)
    do $$$AssertEquals(voided, 2, "both recorded authorizations voided")
}

Method TestUJ3()
{
    set runner = ..Run("UJ-3", .steps)
    do $$$AssertEquals(..StateAfter(steps, "steps 1–3"), "ResolvedByPriorReceipt", "already delivered")
    do $$$AssertEquals(..Count("Execution", runner.CaseId), 0, "the execution layer stays empty")
}

Method TestUJ4()
{
    set runner = ..Run("UJ-4", .steps)
    do $$$AssertEquals(..StateAfter(steps, "step 1"), "ReviewRequired", "ambiguous identity goes to review")
    do $$$AssertEquals(..StateAfter(steps, "step 2"), "ReviewRequired", "RETRY blocked: still in review")
    do $$$AssertEquals(..Outcome(runner, "FR-010"), "Attached", "only the verdict recorded")
    do $$$AssertEquals(..StateAfter(steps, "step 3"), "Cancelled", "cancelled by Carla")
    do $$$AssertEquals(..StateAfter(steps, "step 4 (variant)"), "Resolved", "provider unavailable, mapping chosen, resolved")
}

Method Run(journey As %String, Output steps As %DynamicArray) As SignalNoir.Tests.Application.JourneyRunner
{
    set runner = ##class(SignalNoir.Tests.Application.JourneyRunner).%New(..#PREFIX_journey)
    set steps = runner.Run(journey)
    do $$$AssertEquals(runner.Errors, "", journey_" ran without failures")
    quit runner
}

ClassMethod StateAfter(steps As %DynamicArray, name As %String) As %String
{
    set it = steps.%GetIterator()
    while it.%GetNext(.i, .step) { if step.step = name return step.state }
    quit "(no step "_name_")"
}

ClassMethod Outcome(runner As SignalNoir.Tests.Application.JourneyRunner, ref As %String) As %String
{
    set it = runner.Log.%GetIterator()
    while it.%GetNext(.i, .entry) { if entry.ref = ref return entry.outcome_$select(entry.refusal '= "": ":"_entry.refusal, 1: "") }
    quit "(no ref "_ref_")"
}

ClassMethod Count(table As %String, caseId As %String) As %Integer
{
    set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM SignalNoir_Application_Store."_table_" WHERE CaseId = ?", caseId)
    do rs.%Next()
    quit rs.N
}

}
