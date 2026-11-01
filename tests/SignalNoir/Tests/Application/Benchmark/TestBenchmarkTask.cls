Class SignalNoir.Tests.Application.Benchmark.TestBenchmarkTask Extends %UnitTest.TestCase
{

/// 010 T024 - a run whose driver died is picked up again by the scheduled task (plan D4),
/// a run with a live driver is left alone, and a run past its deadline fails with a reason.
/// The Simulator is not configured here, so a planned item cannot open and the run stays
/// running: what the test sees is the heartbeat and the status.
Method OnBeforeOneTest(testname As %String) As %Status
{
	Do ##class(SignalNoir.Application.Model.BenchmarkItemRecord).%KillExtent()
	Do ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%KillExtent()
	Return $$$OK
}

ClassMethod Run(runId As %String, createdAt As %String, heartbeatAt As %String)
{
	Set run = ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%New()
	Set run.runId = runId, run.mode = "rules", run.purpose = "benchmark", run.status = "running"
	Set run.createdAt = createdAt, run.startedAt = createdAt, run.heartbeatAt = heartbeatAt
	$$$ThrowOnError(run.%Save())
	Set item = ##class(SignalNoir.Application.Model.BenchmarkItemRecord).%New()
	Set item.runId = runId, item.itemNo = 1, item.family = "P8", item.variant = "P8b-tune-01", item.set = "tuning", item.repetition = 1, item.seed = 1
	$$$ThrowOnError(item.%Save())
}

ClassMethod Ago(seconds As %Integer) As %String
{
	Set ts = $ZTimeStamp, day = +$Piece(ts, ",", 1), secs = $Piece(ts, ",", 2) - seconds
	While secs < 0 {
		Set secs = secs + 86400, day = day - 1
	}
	Return $ZDate(day, 3) _ "T" _ $ZTime(secs, 1) _ "Z"
}

Method TestAStaleRunIsDrivenAgain()
{
	Do ..Run("run_task_stale", ..Ago(30), ..Ago(300))
	Set r = ##class(SignalNoir.Application.Benchmark.Runner).Resume(90, 0)
	Do $$$AssertEquals(r.redriven, 1, "the run with an old heartbeat was driven again")
	Set rec = ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%OpenId("run_task_stale")
	Do $$$AssertEquals(rec.status, "running", "and it is still running")
	Do $$$AssertTrue(##class(SignalNoir.Core.ApprovalPolicy).Seconds(rec.heartbeatAt) > ##class(SignalNoir.Core.ApprovalPolicy).Seconds(..Ago(60)), "its heartbeat is fresh again")
}

Method TestARunWithALiveDriverIsLeftAlone()
{
	Set beat = ..Ago(5)
	Do ..Run("run_task_live", ..Ago(30), beat)
	Set r = ##class(SignalNoir.Application.Benchmark.Runner).Resume(90, 0)
	Do $$$AssertEquals(r.redriven, 0, "a fresh heartbeat is not re-driven")
	Do $$$AssertEquals(##class(SignalNoir.Application.Model.BenchmarkRunRecord).%OpenId("run_task_live").heartbeatAt, beat, "and nothing changed")
}

Method TestARunPastItsDeadlineFails()
{
	Do ..Run("run_task_late", ..Ago(7200), ..Ago(7000))
	Set r = ##class(SignalNoir.Application.Benchmark.Runner).Resume(90, 0)
	Set rec = ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%OpenId("run_task_late")
	Do $$$AssertEquals(rec.status, "failed", "a run past its deadline fails")
	Do $$$AssertEquals(rec.failureReason, "deadline", "with the reason")
	Do $$$AssertTrue(rec.completedAt '= "", "and an end time")
}

Method TestOnlyRunningRunsAreConsidered()
{
	Do ..Run("run_task_done", ..Ago(30), ..Ago(300))
	Set rec = ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%OpenId("run_task_done")
	Set rec.status = "completed"
	$$$ThrowOnError(rec.%Save())
	Set r = ##class(SignalNoir.Application.Benchmark.Runner).Resume(90, 0)
	Do $$$AssertEquals(r.redriven, 0, "a completed run is not driven")
}

Method TestTheTaskIsRegisteredWithTheOthers()
{
	Do $$$AssertTrue($ClassMethod("SignalNoir.Tasks.BenchmarkTask", "%Extends", "SignalNoir.Tasks.Periodic"), "a periodic task")
	Do $$$AssertTrue(##class(SignalNoir.Interop.Bootstrap).TaskClasses() [ "SignalNoir.Tasks.BenchmarkTask", "the bootstrap schedules it with the sweeper and the feed reader")
}

}
