Class SignalNoir.Tasks.SweeperTask Extends %SYS.Task.Definition
{

/// The scheduled task that runs the sweep every minute (AD-8). Ensure()
/// registers it once; the bootstrap call is wired at the integration gate
/// (research R6: the dev database still holds test requests).
Parameter TaskName = "Signal Noir sweeper";

Method OnTask() As %Status
{
	Do ##class(SignalNoir.Tasks.Sweeper).Run()
	Return $$$OK
}

/// Registers the task (every minute, in this namespace) unless it exists
ClassMethod Ensure() As %Status
{
	Set ns = $NAMESPACE
	Set sc = $$$OK
	Try {
		Set $NAMESPACE = "%SYS"
		If ..CountIn(ns) > 0 Quit
		Set task = ##class(%SYS.Task).%New()
		Set task.Name = ..#TaskName
		Set task.Description = "Redelivers pending requests and expires approvals (feature 007)"
		Set task.NameSpace = ns
		Set task.TaskClass = "SignalNoir.Tasks.SweeperTask"
		Set task.TimePeriod = 0
		Set task.DailyFrequency = 1
		Set task.DailyFrequencyTime = 0
		Set task.DailyIncrement = 1
		Set task.DailyStartTime = 0
		Set task.DailyEndTime = 86399
		Set task.StartDate = +$Horolog
		Set sc = task.%Save()
	}
	Catch ex {
		Set sc = ex.AsStatus()
	}
	Set $NAMESPACE = ns
	Return sc
}

ClassMethod Count() As %Integer
{
	Set ns = $NAMESPACE
	Set $NAMESPACE = "%SYS"
	Set n = ..CountIn(ns)
	Set $NAMESPACE = ns
	Return n
}

ClassMethod Remove() As %Status
{
	Set ns = $NAMESPACE
	Set sc = $$$OK
	Try {
		Set $NAMESPACE = "%SYS"
		Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM %SYS.Task WHERE TaskClass = ? AND NameSpace = ?", "SignalNoir.Tasks.SweeperTask", ns)
		While rs.%Next() {
			Set sc = ##class(%SYS.Task).%DeleteId(rs.%Get("ID"))
			Quit:$$$ISERR(sc)
		}
	}
	Catch ex {
		Set sc = ex.AsStatus()
	}
	Set $NAMESPACE = ns
	Return sc
}

/// Tasks of this class for a namespace (call from %SYS)
ClassMethod CountIn(ns As %String) As %Integer [ Private ]
{
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM %SYS.Task WHERE TaskClass = ? AND NameSpace = ?", "SignalNoir.Tasks.SweeperTask", ns)
	Return $Select(rs.%Next(): +rs.%GetData(1), 1: -1)
}

}
