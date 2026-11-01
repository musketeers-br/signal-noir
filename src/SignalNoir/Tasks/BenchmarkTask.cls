Class SignalNoir.Tasks.BenchmarkTask Extends SignalNoir.Tasks.Periodic
{

/// The scheduled task that picks up a BenchmarkRun whose driver stopped (a restart, a
/// crash): every minute, a running run with an old heartbeat is driven again. A run is
/// resumable because its plan and progress are persisted (feature 010, plan D4).
Parameter TaskName = "Signal Noir benchmark runs";

Parameter TaskDescription = "Drives again the BenchmarkRuns whose driver stopped (feature 010)";

Method OnTask() As %Status
{
	Do ##class(SignalNoir.Application.Benchmark.Runner).Resume()
	Return $$$OK
}

}
