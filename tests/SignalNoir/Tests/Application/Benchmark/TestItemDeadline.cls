Class SignalNoir.Tests.Application.Benchmark.TestItemDeadline Extends %UnitTest.TestCase
{

/// 010 - the item deadline is for deciding (plan Q1). A Case that decided in time and is carrying
/// out its effect is given the execution time as well, so the Action it chose is scored: a RETRY
/// into timeouts that ends Failed after the deadline is incorrect, not "not decided". Found in the
/// agent rehearsal on tuning (P8a-tune-01). The run, item and Case are written directly.
Parameter E = "SignalNoir.Tests.Application.Benchmark.TestScoringEndToEnd";

Method OnBeforeOneTest(testname As %String) As %Status
{
	Do ##class(SignalNoir.Application.Model.BenchmarkItemRecord).%KillExtent()
	Do ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%KillExtent()
	Return $$$OK
}

Method OnAfterOneTest(testname As %String) As %Status
{
	Return ..OnBeforeOneTest(testname)
}

/// A running agent run with one opened item whose deadline passed 10 s ago, on a Case in state
ClassMethod Late(state As %String) As %String
{
	Do $ClassMethod(..#E, "Run", "run_deadline", "agent", "running", "benchmark", 1)
	Set run = ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%OpenId("run_deadline")
	Set run.createdAt = ##class(SignalNoir.Tests.Application.Benchmark.TestBenchmarkTask).Ago(200)
	Set run.startedAt = run.createdAt, run.heartbeatAt = run.createdAt
	$$$ThrowOnError(run.%Save())
	Set caseId = ##class(SignalNoir.Tests.Application.Benchmark.TestCaseFacts).NewCase(state)
	Do $ClassMethod(..#E, "Item", "run_deadline", 1, "P8", "P8a", "P8a-tune-01", caseId)
	Set item = ##class(SignalNoir.Application.Model.BenchmarkItemRecord).%OpenId("run_deadline||1")
	Set item.status = "opened", item.deadlineAt = ##class(SignalNoir.Tests.Application.Benchmark.TestBenchmarkTask).Ago(10)
	$$$ThrowOnError(item.%Save())
	Return caseId
}

ClassMethod Runner(executionSeconds As %Integer = "") As SignalNoir.Application.Benchmark.Runner
{
	Set runner = ##class(SignalNoir.Application.Benchmark.Runner).%New()
	Set runner.Sweep = 0, runner.ExecutionSeconds = executionSeconds
	Return runner
}

ClassMethod Item() As SignalNoir.Application.Model.BenchmarkItemRecord
{
	Return ##class(SignalNoir.Application.Model.BenchmarkItemRecord).%OpenId("run_deadline||1", , .sc)
}

Method TestACaseThatDecidedAndIsExecutingIsWaitedFor()
{
	Set caseId = ..Late("Executing")
	Do ..Runner(300).Step("run_deadline")
	Do $$$AssertEquals(..Item().status, "opened", "past the deadline, but executing what it decided: still waited for")
	Set rec = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(caseId)
	Set rec.state = "Failed"
	$$$ThrowOnError(rec.%Save())
	Do ..Runner(300).Step("run_deadline")
	Set item = ..Item()
	Do $$$AssertEquals(item.status, "ended", "the execution ended: the Case is scored")
	Do $$$AssertEquals(item.notDecidedReason, "", "and not as undecided")
}

Method TestAnApprovedCaseIsWaitedForToo()
{
	Do ..Late("Approved")
	Do ..Runner(300).Step("run_deadline")
	Do $$$AssertEquals(..Item().status, "opened", "approved, about to execute: still waited for")
}

Method TestTheExecutionTimeHasItsOwnLimit()
{
	Do ..Late("Executing")
	Do ..Runner(5).Step("run_deadline")
	Set item = ..Item()
	Do $$$AssertEquals(item.status _ ":" _ item.notDecidedReason, "not_decided:deadline", "past the deadline and the execution time: not decided")
}

Method TestACaseThatHasNotDecidedIsNotWaitedFor()
{
	Do ..Late("Investigating")
	Do ..Runner(300).Step("run_deadline")
	Set item = ..Item()
	Do $$$AssertEquals(item.status _ ":" _ item.notDecidedReason, "not_decided:deadline", "still investigating after the deadline: not decided")
}

}
