Class SignalNoir.Tests.Application.Reference.TestStore Extends %UnitTest.TestCase
{

Parameter FIX = "SignalNoir.Tests.Application.Reference.Fixtures";

Parameter STORE = "SignalNoir.Application.Reference.Store";

/// 004 T012 - the Reference Store: discovery of fixture classes from a package, validation
/// before anything is registered, the versions in force, pinned runs and immutable snapshots.
/// The Store's globals are saved and emptied around each test, so the dev database keeps its
/// own state.
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

/// Loads the production fixtures and the valid test version B
ClassMethod LoadBoth()
{
	Do $ClassMethod(..#STORE, "Load", "SignalNoir.Application.Reference")
	Do $ClassMethod(..#STORE, "Load", ..#FIX _ ".Good")
}

ClassMethod Pinned(policy As %String, mapping As %String) As %DynamicObject
{
	Return {"inRun": true, "runId": "run_1", "policyVersion": (policy), "mappingVersion": (mapping)}
}

Method TestDefaultIsTheHighestVersionLoadedOnFirstUse()
{
	Set r = $ClassMethod(..#STORE, "InForce")
	Do $$$AssertTrue(r.ok, "something loads on first use: " _ r.message)
	Do $$$AssertEquals(r.obj.policyVersion _ ":" _ r.obj.mappingVersion, "2026.10.1:2026.10.1", "only the production fixtures exist")
	Do $$$AssertEquals(r.obj.ToJson().%ToJSON(), ##class(SignalNoir.Tests.Core.Validator.Inputs).Reference().ToJson().%ToJSON(), "the 2026.10.1 snapshot equals the test builder")
	Do ..LoadBoth()
	Set r = $ClassMethod(..#STORE, "InForce")
	Do $$$AssertEquals(r.obj.policyVersion _ ":" _ r.obj.mappingVersion, "2026.10.2:2026.10.2", "with no explicit choice, the highest of each")
}

Method TestSetInForceIsExplicitAndKept()
{
	Do ..LoadBoth()
	Set r = $ClassMethod(..#STORE, "SetInForce", "2026.10.1", "2026.10.1")
	Do $$$AssertTrue(r.ok, "set")
	Do $$$AssertEquals($Get(^SignalNoir.Reference("inForce", "policy")) _ ":" _ $Get(^SignalNoir.Reference("inForce", "mapping")), "2026.10.1:2026.10.1", "kept in ^SignalNoir.Reference(""inForce"")")
	Do $$$AssertEquals($ClassMethod(..#STORE, "InForce").obj.policyVersion, "2026.10.1", "a newer version does not replace the explicit choice")
	Set r = $ClassMethod(..#STORE, "SetInForce", "2026.10.1", "2099.1.1")
	Do $$$AssertTrue('r.ok && (r.code = "NOT_FOUND"), "an unknown version is refused")
	Do $$$AssertEquals($Get(^SignalNoir.Reference("inForce", "mapping")), "2026.10.1", "and nothing changed")
}

Method TestVersionsAreComparedNumerically()
{
	Do ..LoadBoth()
	Do $ClassMethod(..#STORE, "SetInForce", "2026.10.2", "2026.10.2")
	Do $$$AssertEquals($ClassMethod(..#STORE, "InForce").obj.policyVersion, "2026.10.2", "in force")
	Kill ^SignalNoir.Reference("inForce")
	Do $$$AssertEquals($ClassMethod(..#STORE, "Compare", "2026.10.9", "2026.10.10"), -1, "9 < 10")
	Do $$$AssertEquals($ClassMethod(..#STORE, "Compare", "2026.11.1", "2026.10.30"), 1, "11 > 10")
	Do $$$AssertEquals($ClassMethod(..#STORE, "Compare", "2026.10.1", "2026.10.1"), 0, "equal")
}

Method TestRefusedLoadsLeaveTheVersionsInForceUnchanged()
{
	Do ..LoadBoth()
	Do $ClassMethod(..#STORE, "SetInForce", "2026.10.1", "2026.10.1")
	Merge before = ^SignalNoir.Reference
	For sub = "BadCondition", "BadDuplicate", "BadPolicyKey", "BadRange" {
		Set r = $ClassMethod(..#STORE, "Load", ..#FIX _ "." _ sub)
		Do $$$AssertTrue('r.ok && (r.code = "VALIDATION_FAILED"), sub _ " is refused")
		Do $$$AssertTrue($IsObject(r.details) && (r.details.problems.%Size() > 0), sub _ " says why: " _ $Select($IsObject(r.details): r.details.problems.%ToJSON(), 1: ""))
	}
	Kill after
	Merge after = ^SignalNoir.Reference
	Do $$$AssertEquals($Get(after("inForce", "policy")) _ ":" _ $Get(after("inForce", "mapping")), "2026.10.1:2026.10.1", "inForce is unchanged")
	Do $$$AssertTrue('$Data(^SignalNoir.Reference("fixture", "policy", "2026.10.3")) && '$Data(^SignalNoir.Reference("fixture", "mapping", "2026.10.3")), "nothing of a refused package is registered")
	Set r = $ClassMethod(..#STORE, "For", ..Pinned("2026.10.3", "2026.10.3"))
	Do $$$AssertTrue('r.ok, "a refused version cannot be pinned")
}

Method TestValidateNamesTheProblems()
{
	Set bad = ##class(SignalNoir.Tests.Application.Reference.TestMappingsMatchContractFixture).Content(..#FIX _ ".BadCondition.Mappings")
	Set problems = $ClassMethod(..#STORE, "Validate", bad)
	Do $$$AssertTrue(problems.%ToJSON() [ "colour", "the unknown condition field is named: " _ problems.%ToJSON())
	Set dup = ##class(SignalNoir.Tests.Application.Reference.TestMappingsMatchContractFixture).Content(..#FIX _ ".BadDuplicate.Mappings")
	Do $$$AssertTrue($ClassMethod(..#STORE, "Validate", dup).%ToJSON() [ "map_dup", "the duplicate mappingId is named")
	Set key = ##class(SignalNoir.Tests.Application.Reference.TestMappingsMatchContractFixture).Content(..#FIX _ ".BadPolicyKey.Policies")
	Do $$$AssertTrue($ClassMethod(..#STORE, "Validate", key).%ToJSON() [ "retryBackoff", "the unknown policy key is named")
	Set range = ##class(SignalNoir.Tests.Application.Reference.TestMappingsMatchContractFixture).Content(..#FIX _ ".BadRange.Policies")
	Set rj = $ClassMethod(..#STORE, "Validate", range).%ToJSON()
	Do $$$AssertTrue((rj [ "maxAttempts") && (rj [ "maxErrorRate"), "both out-of-range values are named: " _ rj)
	Do $$$AssertEquals($ClassMethod(..#STORE, "Validate", ##class(SignalNoir.Tests.Application.Reference.TestMappingsMatchContractFixture).Content("SignalNoir.Application.Reference.Policies.V2026101")).%Size(), 0, "the shipped policy set is valid")
	Do $$$AssertEquals($ClassMethod(..#STORE, "Validate", ##class(SignalNoir.Tests.Application.Reference.TestMappingsMatchContractFixture).Content("SignalNoir.Application.Reference.Mappings.V2026101")).%Size(), 0, "the shipped mapping set is valid")
}

Method TestAPinnedRunUsesItsOwnVersions()
{
	Do ..LoadBoth()
	Do $ClassMethod(..#STORE, "SetInForce", "2026.10.1", "2026.10.1")
	Set r = $ClassMethod(..#STORE, "For", ..Pinned("2026.10.2", "2026.10.2"))
	Do $$$AssertTrue(r.ok, "pinned: " _ r.message)
	Do $$$AssertEquals(r.obj.policyVersion _ ":" _ r.obj.mappingVersion, "2026.10.2:2026.10.2", "the run's versions")
	Do $$$AssertEquals(r.obj.policies.attempt.maxAttempts, 2, "the run's policy")
	Do $$$AssertEquals(r.obj.mappings.%Size(), 3, "version B has no map_glicj_soro")
	Set free = $ClassMethod(..#STORE, "For", {"inRun": false, "runId": null, "policyVersion": null, "mappingVersion": null})
	Do $$$AssertEquals(free.obj.policyVersion, "2026.10.1", "outside a run, the version in force")
	Set odd = $ClassMethod(..#STORE, "For", ..Pinned("2026.10.1", "2026.10.2"))
	Do $$$AssertEquals(odd.obj.policyVersion _ ":" _ odd.obj.mappingVersion, "2026.10.1:2026.10.2", "policy and mapping are pinned independently")
	Set none = $ClassMethod(..#STORE, "For", ..Pinned("2099.1.1", "2026.10.1"))
	Do $$$AssertTrue('none.ok && (none.code = "NOT_FOUND"), "an unknown pinned version fails")
}

/// US6 AS1 and AS2 through the Validator: the same Proposal under each version, and a run that
/// pinned the older one while the newer is in force
Method TestTheSameProposalIsValidatedUnderEachVersion()
{
	Do ..LoadBoth()
	Set inputs = "SignalNoir.Tests.Core.Validator.Inputs"
	Set proposal = $ClassMethod(inputs, "Proposal", "APPLY_APPROVED_MAPPING", $ClassMethod(inputs, "MappingParams", "map_glicj_soro"))
	Set input = $ClassMethod(inputs, "Input", proposal, "", $ClassMethod(inputs, "SerumOrder"))
	Set validator = ##class(SignalNoir.Core.Validator).%New()

	Set input.reference = $ClassMethod(..#STORE, "For", ..Pinned("2026.10.1", "2026.10.1")).obj
	Set a = validator.Validate(input).ToJson()
	Do $$$AssertEquals(a.verdict _ " " _ a.versions.policy _ ":" _ a.versions.mapping, "accepted 2026.10.1:2026.10.1", "AS1: accepted under A, and it names A")

	Set input.reference = $ClassMethod(..#STORE, "For", ..Pinned("2026.10.2", "2026.10.2")).obj
	Set b = validator.Validate(input).ToJson()
	Do $$$AssertEquals(b.verdict _ " " _ b.reasons.%Get(0) _ " " _ b.versions.policy _ ":" _ b.versions.mapping, "blocked MAPPING_NOT_FOUND 2026.10.2:2026.10.2", "AS1: blocked under B, which no longer has the Mapping, and it names B")

	Do $ClassMethod(..#STORE, "SetInForce", "2026.10.2", "2026.10.2")
	Set run = {"inRun": true, "runId": "run_bench_01", "policyVersion": "2026.10.1", "mappingVersion": "2026.10.1"}
	Set input.reference = $ClassMethod(..#STORE, "For", run).obj
	Set pinned = validator.Validate(input).ToJson()
	Do $$$AssertEquals(pinned.verdict _ " " _ pinned.versions.mapping, "accepted 2026.10.1", "AS2: a Case of the run pinned to A is validated against A while B is in force")
	Set input.reference = $ClassMethod(..#STORE, "For", {"inRun": false, "runId": null, "policyVersion": null, "mappingVersion": null}).obj
	Set free = validator.Validate(input).ToJson()
	Do $$$AssertEquals(free.verdict _ " " _ free.versions.mapping, "blocked 2026.10.2", "and a Case outside any run is validated against B")
}

Method TestNothingLoadableMakesForFail()
{
	Set ^SignalNoir.Reference("defaultPackage") = "No.Such.Package"
	Set r = $ClassMethod(..#STORE, "For", {"inRun": false})
	Do $$$AssertTrue('r.ok && (r.code = "NOT_FOUND"), "no reference data: For fails, it does not guess")
	Do $$$AssertTrue(r.message [ "reference data", "and says so: " _ r.message)
	Do $$$AssertTrue('$ClassMethod(..#STORE, "InForce").ok, "InForce fails too")
}

Method TestSnapshotsAreImmutable()
{
	Set a = $ClassMethod(..#STORE, "InForce").obj
	Set a.policies.attempt.maxAttempts = 99
	Do a.mappings.%Push({"mappingId": "injected"})
	Set a.policyVersion = "tampered"
	Set b = $ClassMethod(..#STORE, "InForce").obj
	Do $$$AssertEquals(b.policies.attempt.maxAttempts, 3, "a caller changing a snapshot does not change the Store")
	Do $$$AssertEquals(b.mappings.%Size(), 4, "nor the mappings")
	Do $$$AssertEquals(b.policyVersion, "2026.10.1", "nor the version")
}

Method TestLoadIsIdempotent()
{
	Do ..LoadBoth()
	Set r = $ClassMethod(..#STORE, "Load", ..#FIX _ ".Good")
	Do $$$AssertTrue(r.ok, "loading the same package again is fine: " _ r.message)
	Do $$$AssertEquals($ClassMethod(..#STORE, "InForce").obj.policyVersion, "2026.10.2", "same result")
}

}
