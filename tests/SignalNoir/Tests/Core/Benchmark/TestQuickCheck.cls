Class SignalNoir.Tests.Core.Benchmark.TestQuickCheck Extends %UnitTest.TestCase
{

Parameter Q = "SignalNoir.Core.Benchmark.QuickCheck";

/// 010 T066 (the Core of it) - "matches the reference" or "diverged", with the reason (FR-033)
ClassMethod Reference() As %DynamicObject
{
	Return {"referenceCase": "P5-test-01/1", "finalState": "Resolved", "action": "APPLY_APPROVED_MAPPING", "params": {"mappingId": "map_glicj_soro"}}
}

ClassMethod Run(finalState, action, params) As %DynamicObject
{
	Set a = {}
	If finalState = "" {
		Do a.%Set("finalState", "", "null")
	} Else {
		Set a.finalState = finalState
	}
	If action = "" {
		Do a.%Set("action", "", "null")
		Do a.%Set("actionParams", "", "null")
	} Else {
		Set a.action = action, a.actionParams = params
	}
	Return a
}

Method TestTheSameOutcomeMatches()
{
	Set r = $ClassMethod(..#Q, "Compare", ..Reference(), ..Run("Resolved", "APPLY_APPROVED_MAPPING", {"mappingId": "map_glicj_soro"}), {"providerDiffers": false})
	Do $$$AssertEquals(r.status, "matches_reference", "matches")
	Do $$$AssertEquals(r.%GetTypeOf("reason"), "null", "no reason needed")
}

Method TestTheCaseMayCarryMoreParameters()
{
	Set r = $ClassMethod(..#Q, "Compare", ..Reference(), ..Run("Resolved", "APPLY_APPROVED_MAPPING", {"note": "x", "mappingId": "map_glicj_soro"}), {})
	Do $$$AssertEquals(r.status, "matches_reference", "extra keys do not matter")
}

Method TestADifferentFinalStateDiverges()
{
	Set r = $ClassMethod(..#Q, "Compare", ..Reference(), ..Run("ReviewRequired", "", ""), {})
	Do $$$AssertEquals(r.status, "diverged", "diverged")
	Do $$$AssertTrue(r.reason [ "final state", "the reason names the state")
	Do $$$AssertTrue((r.reason [ "Resolved") && (r.reason [ "ReviewRequired"), "both states")
}

Method TestADifferentActionDiverges()
{
	Set r = $ClassMethod(..#Q, "Compare", ..Reference(), ..Run("Resolved", "RETRY", {}), {})
	Do $$$AssertEquals(r.status, "diverged", "diverged")
	Do $$$AssertTrue((r.reason [ "Action") && (r.reason [ "RETRY") && (r.reason [ "APPLY_APPROVED_MAPPING"), "the reason names both Actions")
}

Method TestDifferentParametersDiverge()
{
	Set r = $ClassMethod(..#Q, "Compare", ..Reference(), ..Run("Resolved", "APPLY_APPROVED_MAPPING", {"mappingId": "map_glicj_plasma"}), {})
	Do $$$AssertEquals(r.status, "diverged", "diverged")
	Do $$$AssertTrue(r.reason [ "parameters", "the reason says parameters")
}

Method TestAControlThatRaisesNothingMatchesAControl()
{
	Set ref = {"referenceCase": "clean-success-test-01/1", "finalState": "NoCase", "action": null, "params": {}}
	Do $$$AssertEquals($ClassMethod(..#Q, "Compare", ref, ..Run("", "", ""), {}).status, "matches_reference", "no Case, as the reference")
	Do $$$AssertEquals($ClassMethod(..#Q, "Compare", ref, ..Run("Resolved", "RETRY", {}), {}).status, "diverged", "a Case where the reference had none")
}

Method TestADifferentProviderIsSaidButDoesNotDivergeByItself()
{
	Set same = $ClassMethod(..#Q, "Compare", ..Reference(), ..Run("Resolved", "APPLY_APPROVED_MAPPING", {"mappingId": "map_glicj_soro"}), {"providerDiffers": true})
	Do $$$AssertEquals(same.status, "matches_reference", "the outcome is the reference's")
	Do $$$AssertTrue(same.reason [ "provider or model differs", "and the report says the provider differs")
	Set other = $ClassMethod(..#Q, "Compare", ..Reference(), ..Run("ReviewRequired", "", ""), {"providerDiffers": true})
	Do $$$AssertEquals(other.status, "diverged", "a different outcome with another provider diverges")
	Do $$$AssertTrue(other.reason [ "provider or model differs", "and says the provider differs, as the likely cause")
}

}
