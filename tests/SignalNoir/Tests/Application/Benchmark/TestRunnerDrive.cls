Class SignalNoir.Tests.Application.Benchmark.TestRunnerDrive Extends %UnitTest.TestCase
{

/// 010 - the process that drives a run ends when the run is over and lets go of its lock.
/// A Quit inside a Try leaves only the Try, so a driver that quit there looped for ever,
/// one process left behind for each run started through the API.
Parameter R = "SignalNoir.Application.Benchmark.Runner";

Property Pids As %List;

Method OnBeforeOneTest(testname As %String) As %Status
{
	Do ##class(SignalNoir.Application.Model.BenchmarkItemRecord).%KillExtent()
	Do ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%KillExtent()
	Return $$$OK
}

Method OnAfterOneTest(testname As %String) As %Status
{
	; a driver that did not end must not outlive the test
	For i = 1 : 1 : $ListLength(..Pids) {
		Do ##class(%SYSTEM.Process).Terminate($List(..Pids, i))
	}
	Set ..Pids = ""
	Return $$$OK
}

/// Starts the driver of the run in a process of its own and waits for it to end (at most seconds).
/// A new process is not listed at once, so it gets two seconds to start before it is looked for.
Method DriveInBackground(runId As %String, seconds As %Integer) As %Boolean
{
	Job ##class(SignalNoir.Application.Benchmark.Runner).Drive(runId)
	Set pid = $ZChild
	Set ..Pids = ..Pids _ $ListBuild(pid)
	Hang 2
	For i = 1 : 1 : seconds * 2 {
		Hang 0.5
		If '$Data(^$JOB(pid)) Return 1
	}
	Return 0
}

Method LockIsFree(runId As %String) As %Boolean
{
	Set lockName = "^SignalNoir.BenchmarkDrive"
	Lock +@lockName@(runId):2
	Set free = $Test
	Lock -@lockName@(runId)
	Return free
}

Method TestTheDriverOfACompletedRunEnds()
{
	Do ##class(SignalNoir.Tests.Application.Benchmark.TestScoringEndToEnd).Run("run_drive_done", "rules", "completed", "benchmark", 1)
	Do $$$AssertTrue(..DriveInBackground("run_drive_done", 10), "the process ended by itself")
	Do $$$AssertTrue(..LockIsFree("run_drive_done"), "and let go of the run's lock")
}

Method TestTheDriverEndsWhenItCompletesTheRun()
{
	Do ##class(SignalNoir.Tests.Application.Benchmark.TestScoringEndToEnd).Run("run_drive_live", "rules", "running", "benchmark", 1)
	Set run = ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%OpenId("run_drive_live")
	Set run.createdAt = ##class(SignalNoir.Tests.Application.Benchmark.TestBenchmarkTask).Ago(5)
	Set run.startedAt = run.createdAt, run.heartbeatAt = run.createdAt
	$$$ThrowOnError(run.%Save())
	; the driver changes the record in another process: read it again from the database, not from this object
	Kill run
	Do ##class(SignalNoir.Tests.Application.Benchmark.TestScoringEndToEnd).Item("run_drive_live", 1, "clean", "clean.success", "clean-success-tune-01", "")
	Do $$$AssertTrue(..DriveInBackground("run_drive_live", 20), "the process ended by itself")
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT status, failureReason FROM SignalNoir_Application_Model.BenchmarkRunRecord WHERE runId = ?", "run_drive_live")
	Do rs.%Next()
	Do $$$AssertEquals(rs.%Get("status"), "completed", "after completing the run: " _ rs.%Get("failureReason"))
	Do $$$AssertTrue(..LockIsFree("run_drive_live"), "and let go of the run's lock")
}

}
