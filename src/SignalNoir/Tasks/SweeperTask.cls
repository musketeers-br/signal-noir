Class SignalNoir.Tasks.SweeperTask Extends SignalNoir.Tasks.Periodic
{

/// The scheduled task that runs the sweep every minute (AD-8). The bootstrap
/// registers it when background tasks are on (gate G1); the dev database
/// keeps them off because it still holds test requests (007 research R6).
Parameter TaskName = "Signal Noir sweeper";

Parameter TaskDescription = "Redelivers pending requests, expires approvals, reconciles expired executions and reassesses Held Cases (features 007 and 008)";

Method OnTask() As %Status
{
	Do ##class(SignalNoir.Tasks.Sweeper).Run()
	Return $$$OK
}

}
