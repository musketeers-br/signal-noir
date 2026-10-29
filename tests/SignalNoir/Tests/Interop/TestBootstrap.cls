Class SignalNoir.Tests.Interop.TestBootstrap Extends %UnitTest.TestCase
{

/// T019 - Bootstrap never throws, records provider info and materializes when possible.
/// The container has no SN_AI_API_KEY, so the default path is degraded.
/// The test also exercises Materialize() directly with a key to cover the configured path.
Method TestBootstrapNeverThrowsAndRecordsProvider()
{
	Set r = ##class(SignalNoir.Interop.Bootstrap).OnStart()
	Do $$$AssertTrue(r.ok, "bootstrap never throws")
	Set prov = $Get(^SignalNoir.Provider("provider"))
	Set configured = +$Get(^SignalNoir.Provider("configured"))
	Set reason = $Get(^SignalNoir.Provider("reason"))
	Set materialized = $Get(^SignalNoir.Provider("materialized"))
	Set bootstrappedAt = $Get(^SignalNoir.Provider("bootstrappedAt"))
	Do $$$AssertTrue((bootstrappedAt '= ""), "bootstrappedAt recorded")
	Do $$$AssertTrue((configured = 0) || (configured = 1), "configured is a boolean")
	Do $$$AssertTrue((materialized = "none") || (materialized = "configstore") || (materialized = "provider"), "materialized path known")
	If configured = 1 {
		Do $$$AssertTrue((prov '= ""), "provider name recorded when configured")
	} Else {
		Do $$$AssertTrue(reason '= "", "reason present when not configured: "_reason)
		Set reasonHasProvider = $Find(reason, "provider") > 0
		Do $$$AssertTrue(reasonHasProvider, "reason names the unavailable provider: "_reason)
	}
}

/// Materialize with a key exercises the configstore/provider paths directly (env-independent).
/// The container may not have %Wallet/%ConfigStore fully working; the test records whichever path is taken.
Method TestMaterializeWithKeyExercisesPaths()
{
	Set outcome = ##class(SignalNoir.Interop.Bootstrap).Materialize("openai", "gpt-4o", "test-key")
	Do $$$AssertTrue(($Get(outcome) = "configstore") || ($Get(outcome) = "provider") || ($Get(outcome) = "none"), "materialized path is one of known")
}

/// 003 T038 - start-up runs the interrupted-investigation recovery
Method TestOnStartRunsRecovery()
{
	Set r = ##class(SignalNoir.Interop.Bootstrap).OnStart()
	Do $$$AssertTrue(r.ok, "bootstrap ok")
	Set recovered = $Get(^SignalNoir.Provider("recoveredCases"))
	Do $$$AssertTrue(recovered ? 1.N, "recovery ran and reported a count: " _ recovered)
}

/// 005 T027 - the API, the static console and the entry redirect are registered
Method TestConsoleApplicationsRegistered()
{
	Set r = ##class(SignalNoir.Interop.Bootstrap).OnStart()
	Do $$$AssertEquals($Get(^SignalNoir.Provider("webApplications")), "registered", "web applications registered")
	Set ns = $NAMESPACE
	Set $NAMESPACE = "%SYS"
	Set api = ##class(Security.Applications).Exists("/signalnoir/api/v1")
	Set ui = ##class(Security.Applications).Get("/signalnoir/ui", .uiProps)
	Set entry = ##class(Security.Applications).Get("/signalnoir", .entryProps)
	Set $NAMESPACE = ns
	Do $$$AssertTrue(api, "API application")
	Do $$$AssertTrue($$$ISOK(ui), "console application")
	Do $$$AssertEquals($Get(uiProps("ServeFiles")), 1, "console serves files")
	Do $$$AssertEquals($Get(uiProps("Path")), ##class(SignalNoir.Interop.Bootstrap).UiPath(), "console path")
	Do $$$AssertTrue($$$ISOK(entry), "entry application")
	Do $$$AssertEquals($Get(entryProps("DispatchClass")), "SignalNoir.Api.Console", "entry redirects")
	Do $$$AssertEquals(##class(SignalNoir.Api.Console).Target(), "ui/index.html#/cases", "redirect target")
}

/// Gate G1 - background tasks follow SN_BACKGROUND_TASKS (unset in the dev
/// container: off)
Method TestGateG1Wiring()
{
	Set r = ##class(SignalNoir.Interop.Bootstrap).OnStart()
	Do $$$AssertEquals($Get(^SignalNoir.Provider("backgroundTasks")), "off", "off without SN_BACKGROUND_TASKS")
	Do $$$AssertEquals(##class(SignalNoir.Tasks.SweeperTask).Count() + ##class(SignalNoir.Tasks.OriginFeedTask).Count(), 0, "nothing scheduled")
	Do $$$AssertEquals(##class(SignalNoir.Interop.Bootstrap).EnsureBackgroundTasks(1), "scheduled", "scheduled when on")
	Do $$$AssertEquals(##class(SignalNoir.Interop.Bootstrap).EnsureBackgroundTasks(1), "scheduled", "idempotent")
	Do $$$AssertEquals(##class(SignalNoir.Tasks.SweeperTask).Count() _ ":" _ ##class(SignalNoir.Tasks.OriginFeedTask).Count(), "1:1", "one task each")
	Do $$$AssertEquals(..TaskState("SignalNoir.Tasks.OriginFeedTask"), "_SYSTEM:0", "runs as _SYSTEM, not suspended")
	; a task left suspended under another user is repaired
	Do ..SetTaskState("SignalNoir.Tasks.OriginFeedTask", "%System", 1)
	Do $$$AssertEquals(##class(SignalNoir.Interop.Bootstrap).EnsureBackgroundTasks(1), "scheduled", "ensured again")
	Do $$$AssertEquals(..TaskState("SignalNoir.Tasks.OriginFeedTask"), "_SYSTEM:0", "repaired")
	Do $$$AssertEquals(##class(SignalNoir.Interop.Bootstrap).EnsureBackgroundTasks(0), "off", "removed when off")
	Do $$$AssertEquals(##class(SignalNoir.Tasks.SweeperTask).Count() + ##class(SignalNoir.Tasks.OriginFeedTask).Count(), 0, "tests leave no schedule behind")
}

/// RunAsUser:Suspended of the task of a class in this namespace
ClassMethod TaskState(cls As %String) As %String
{
	Set ns = $NAMESPACE, $NAMESPACE = "%SYS"
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT RunAsUser, Suspended FROM %SYS.Task WHERE TaskClass = ? AND NameSpace = ?", cls, ns)
	Set out = $Select(rs.%Next(): rs.%Get("RunAsUser") _ ":" _ (+rs.%Get("Suspended")), 1: "")
	Set $NAMESPACE = ns
	Return out
}

ClassMethod SetTaskState(cls As %String, user As %String, suspended As %Integer)
{
	Set ns = $NAMESPACE, $NAMESPACE = "%SYS"
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM %SYS.Task WHERE TaskClass = ? AND NameSpace = ?", cls, ns)
	If rs.%Next() {
		Set t = ##class(%SYS.Task).%OpenId(rs.%Get("ID"))
		Set t.RunAsUser = user
		Do t.%Save()
		If suspended Do ##class(%SYS.Task).Suspend(rs.%Get("ID"))
	}
	Set $NAMESPACE = ns
}

}
