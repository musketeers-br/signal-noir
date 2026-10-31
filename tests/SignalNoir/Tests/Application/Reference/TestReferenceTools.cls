Class SignalNoir.Tests.Application.Reference.TestReferenceTools Extends %UnitTest.TestCase
{

Parameter SOURCE = "SignalNoir.Tools.LocalSource";

Parameter STORE = "SignalNoir.Application.Reference.Store";

Parameter S = "SignalNoir.Tests.Support";

/// 004 T035 - the read-only Tools that serve reference data (US6 AS6, research D15): the
/// proposer receives the policies and the Mapping catalog of the version in force, in the
/// shapes of contracts/validation-input.md; with nothing loaded the Tools report an absence.
/// The Store's globals are saved and emptied around each test, so the dev database keeps its own.
Method OnBeforeOneTest() As %Status
{
	Kill ^||SaveRef
	Merge ^||SaveRef = ^SignalNoir.Reference
	Kill ^SignalNoir.Reference
	Return $$$OK
}

Method OnAfterOneTest() As %Status
{
	Kill ^SignalNoir.Reference
	Merge ^SignalNoir.Reference = ^||SaveRef
	Kill ^||SaveRef
	Return $$$OK
}

ClassMethod Read(tool As %String, caseId As %String = "") As SignalNoir.Core.Result
{
	Return ##class(SignalNoir.Tools.LocalSource).%New().Read(tool, {"caseId": (caseId)})
}

ClassMethod NewCase() As %String
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Return $ClassMethod(..#S, "OpenCase", svc, $ClassMethod(..#S, "Uid", "rtools"))
}

Method TestThePoliciesOfTheVersionInForceAreServed()
{
	Set r = ..Read("tool.policies", ..NewCase())
	Do $$$AssertTrue(r.ok && r.obj.available, "available: " _ r.message)
	Set result = r.obj.result
	Do $$$AssertEquals(result.policyVersion, "2026.10.1", "with its version")
	Do $$$AssertEquals(result.attempt.maxAttempts, 3, "attempt policy")
	Do $$$AssertEquals(result.substitution.enabled, 1, "substitution policy")
	Do $$$AssertEquals(result.%GetTypeOf("maintenanceWindows"), "array", "maintenance windows")
	Do $$$AssertEquals(result.partnerHealth.windowSeconds _ ":" _ result.partnerHealth.maxErrorRate, "300:.2", "partner health policy")
	Do $$$AssertEquals(result.approval.deadlineSeconds, 900, "approval deadline")
	Set expected = $ClassMethod("SignalNoir.Tests.Core.Validator.Inputs", "PoliciesResult")
	Do $$$AssertEquals(result.attempt.%ToJSON() _ result.substitution.%ToJSON() _ result.partnerHealth.%ToJSON() _ result.approval.%ToJSON(), expected.attempt.%ToJSON() _ expected.substitution.%ToJSON() _ expected.partnerHealth.%ToJSON() _ expected.approval.%ToJSON(), "the shape the Validator reads")
}

Method TestTheMappingCatalogOfTheVersionInForceIsServedWithItsSynonyms()
{
	Set r = ..Read("tool.mapping_catalog", ..NewCase())
	Do $$$AssertTrue(r.ok && r.obj.available, "available: " _ r.message)
	Set result = r.obj.result
	Do $$$AssertEquals(result.mappingVersion, "2026.10.1", "with its version")
	Do $$$AssertEquals(result.items.%Size(), 4, "every Mapping")
	Set first = result.items.%Get(0)
	For field = "mappingId", "mappingVersion", "sourceCode", "targetCode" Do $$$AssertTrue(first.%GetTypeOf(field) = "string", "item " _ field)
	Do $$$AssertEquals(first.%GetTypeOf("conditions"), "object", "item conditions")
	Do $$$AssertEquals(result.synonyms.specimenType.SERUM.%Get(1), "SORO", "the synonyms, so a proposer reads `soro` as SERUM")
}

Method TestThePolicyAndCatalogAreTheValidatorsSnapshot()
{
	Set caseId = ..NewCase()
	Set snapshot = $ClassMethod(..#STORE, "InForce").obj
	Set policies = ..Read("tool.policies", caseId).obj.result
	Set catalog = ..Read("tool.mapping_catalog", caseId).obj.result
	Do $$$AssertEquals(policies.policyVersion _ ":" _ catalog.mappingVersion, snapshot.policyVersion _ ":" _ snapshot.mappingVersion, "same versions")
	Do $$$AssertEquals(catalog.items.%ToJSON(), snapshot.mappings.%ToJSON(), "same Mappings")
	Do $$$AssertEquals(catalog.synonyms.%ToJSON(), snapshot.synonyms.%ToJSON(), "same synonyms")
}

Method TestAnotherVersionInForceIsWhatTheToolsServe()
{
	Do $ClassMethod(..#STORE, "Load", "SignalNoir.Application.Reference")
	Do $ClassMethod(..#STORE, "Load", "SignalNoir.Tests.Application.Reference.Fixtures.Good")
	Do $ClassMethod(..#STORE, "SetInForce", "2026.10.2", "2026.10.2")
	Set caseId = ..NewCase()
	Do $$$AssertEquals(..Read("tool.policies", caseId).obj.result.policyVersion, "2026.10.2", "policies")
	Set catalog = ..Read("tool.mapping_catalog", caseId).obj.result
	Do $$$AssertEquals(catalog.mappingVersion _ ":" _ catalog.items.%Size(), "2026.10.2:3", "mapping catalog: version B has one Mapping less")
}

Method TestWithNothingLoadedTheToolsReportAnAbsence()
{
	Set ^SignalNoir.Reference("defaultPackage") = "No.Such.Package"
	For tool = "tool.policies", "tool.mapping_catalog" {
		Set r = ..Read(tool, ..NewCase())
		Do $$$AssertTrue(r.ok && 'r.obj.available, tool _ ": not available")
		Do $$$AssertTrue(r.obj.reason [ "reference data", tool _ ": says why: " _ r.obj.reason)
		Do $$$AssertEquals(r.obj.%IsDefined("result"), 0, tool _ ": nothing invented")
	}
}

Method TestACaseThatDoesNotExistGetsTheVersionInForce()
{
	Set r = ..Read("tool.policies", "case_unknown")
	Do $$$AssertTrue(r.ok && r.obj.available, "the reference data is not the Case's")
	Do $$$AssertEquals(r.obj.result.policyVersion, "2026.10.1", "the version in force")
}

Method TestOtherToolsAreStillNotServedHere()
{
	Set r = ..Read("tool.partner_health", ..NewCase())
	Do $$$AssertTrue(r.ok && 'r.obj.available, "no local source for the Partner")
}

Method TestAnInvestigationTakesTheVersionsFromTheTools()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(..#S, "InvestigatingCase", svc, "rtver", "agent", .cmd, "soro")
	Set policies = $ClassMethod("SignalNoir.Tests.Core.Validator.Inputs", "PoliciesResult")
	Set ^SignalNoir.TestScript(caseId, "source", "tool.policies") = policies.%ToJSON()
	Do $ClassMethod(..#S, "Script", caseId, "answer", $ClassMethod(..#S, "P8bAnswer"))
	Set r = $ClassMethod(..#S, "Investigate", cmd)
	Do $$$AssertEquals(r.details.status, "proposed", "proposed: " _ r.details.reason)
	Set p = svc.GetCase(caseId).obj.proposals.GetAt(1)
	Do $$$AssertEquals(p.versions.policy, "2026.10.1", "the policy version comes from `policyVersion` of the Tool's result")
	Do $$$AssertEquals(p.versions.mapping, "2026.10.1", "the mapping version")
	Kill ^SignalNoir.TestScript(caseId, "source")
	Do $ClassMethod(..#S, "ClearScript", caseId)
}

}
