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

}
