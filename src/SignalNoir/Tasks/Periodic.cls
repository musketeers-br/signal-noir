Class SignalNoir.Tasks.Periodic Extends %SYS.Task.Definition [ Abstract ]
{

/// A task that runs every minute in the namespace that registered it. Each
/// subclass is one schedule: Ensure() registers it once, Count() and
/// Remove() let tests leave no schedule behind. In %SYS the SignalNoir
/// classes are not visible: everything is read before the switch and
/// nothing of this package is called after it.
Parameter TaskName;

Parameter TaskDescription;

/// The user the Task Manager runs it as
Parameter RunAsUser = "_SYSTEM";

/// Registers the task (every minute, in this namespace), or repairs the
/// existing one: it runs as RunAsUser and is not suspended. A task created
/// by the start-up hook would run as %System, which the Task Manager
/// suspends without running (012 research R4).
ClassMethod Ensure() As %Status
{
	Set ns = $NAMESPACE
	Set cls = $ClassName()
	Set name = $Parameter(cls, "TaskName"), description = $Parameter(cls, "TaskDescription"), user = $Parameter(cls, "RunAsUser")
	Set sc = $$$OK
	Try {
		Set $NAMESPACE = "%SYS"
		Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM %SYS.Task WHERE TaskClass = ? AND NameSpace = ?", cls, ns)
		If rs.%Next() {
			Set id = rs.%Get("ID"), task = ##class(%SYS.Task).%OpenId(id)
			If task.RunAsUser '= user Set task.RunAsUser = user, sc = task.%Save()
			If $$$ISOK(sc) && task.Suspended Set sc = ##class(%SYS.Task).Resume(id)
			Quit
		}
		Set task = ##class(%SYS.Task).%New()
		Set task.Name = name
		Set task.Description = description
		Set task.NameSpace = ns
		Set task.TaskClass = cls
		Set task.RunAsUser = user
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
	Set cls = $ClassName()
	Set $NAMESPACE = "%SYS"
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM %SYS.Task WHERE TaskClass = ? AND NameSpace = ?", cls, ns)
	Set n = $Select(rs.%Next(): +rs.%GetData(1), 1: -1)
	Set $NAMESPACE = ns
	Return n
}

ClassMethod Remove() As %Status
{
	Set ns = $NAMESPACE
	Set cls = $ClassName()
	Set sc = $$$OK
	Try {
		Set $NAMESPACE = "%SYS"
		Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM %SYS.Task WHERE TaskClass = ? AND NameSpace = ?", cls, ns)
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

}
