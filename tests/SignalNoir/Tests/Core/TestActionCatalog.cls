Class SignalNoir.Tests.Core.TestActionCatalog Extends %UnitTest.TestCase
{

/// 009 T002 - the closed catalog with its approval and parameter rules
Method TestEntries()
{
	Set items = ##class(SignalNoir.Core.ActionCatalog).Entries()
	Do $$$AssertEquals(items.%Size(), 4, "four Actions")
	Set seen = ""
	For i = 0 : 1 : items.%Size() - 1 {
		Set e = items.%Get(i)
		Set seen = seen _ e.action _ ","
		For f = "action", "externalEffect", "requiresApproval", "paramsSchema", "requiredEvidence" Do $$$AssertTrue(e.%IsDefined(f), e.action _ " has " _ f)
		Do $$$AssertEquals(e.requiresApproval, e.externalEffect, e.action _ ": Approval exactly when there is an external effect (009b)")
	}
	Do $$$AssertEquals(seen, "RETRY,APPLY_APPROVED_MAPPING,HOLD,REQUEST_REVIEW,", "catalog order")
}

Method TestRules()
{
	Set C = "SignalNoir.Core.ActionCatalog"
	Do $$$AssertEquals($ClassMethod(C, "RequiresApproval", "HOLD"), 0, "HOLD needs no approval")
	Do $$$AssertEquals($ClassMethod(C, "RequiresApproval", "RETRY"), 1, "RETRY needs approval")
	Do $$$AssertEquals($ClassMethod(C, "RequiresApproval", "APPLY_APPROVED_MAPPING"), 1, "mapping needs approval")
	Do $$$AssertEquals($ClassMethod(C, "RequiresApproval", "REQUEST_REVIEW"), 0, "review has no effect to approve (R19, FR-16)")
	Do $$$AssertEquals($ClassMethod(C, "AllowedParams", "APPLY_APPROVED_MAPPING"), $ListBuild("mappingId", "mappingVersion"), "mapping params")
	Do $$$AssertEquals($ClassMethod(C, "AllowedParams", "HOLD"), $ListBuild("reason"), "hold params")
	Do $$$AssertEquals($ClassMethod(C, "AllowedParams", "RETRY"), "", "retry has no params")
}

/// 004 T009 - requiredEvidence per data-model "Action catalog"; "|" joins alternatives
Method TestRequiredEvidence()
{
	Set items = ##class(SignalNoir.Core.ActionCatalog).Entries()
	Set expected("RETRY") = "[""tool.policies#attempt"",""tool.partner_failure_history"",""tool.partner_health""]"
	Set expected("APPLY_APPROVED_MAPPING") = "[""tool.policies#substitution"",""tool.mapping_catalog"",""order#<condition field>""]"
	Set expected("HOLD") = "[""tool.partner_health|tool.policies#maintenanceWindows""]"
	Set expected("REQUEST_REVIEW") = "[]"
	For i = 0 : 1 : items.%Size() - 1 {
		Set e = items.%Get(i)
		Do $$$AssertEquals(e.requiredEvidence.%ToJSON(), expected(e.action), e.action _ " requiredEvidence")
	}
}

/// 004 T009 - approval exactly when there is an external effect, in the rule and in the entries
Method TestApprovalFollowsEffect()
{
	Set C = "SignalNoir.Core.ActionCatalog"
	For action = "RETRY", "APPLY_APPROVED_MAPPING", "HOLD", "REQUEST_REVIEW" {
		Do $$$AssertEquals($ClassMethod(C, "RequiresApproval", action), $ClassMethod(C, "ExternalEffect", action), action _ ": RequiresApproval = ExternalEffect")
	}
	Set items = $ClassMethod(C, "Entries")
	For i = 0 : 1 : items.%Size() - 1 {
		Set e = items.%Get(i)
		If (e.action = "HOLD") || (e.action = "REQUEST_REVIEW") Do $$$AssertEquals(e.%GetTypeOf("requiresApproval") _ ":" _ e.requiresApproval, "boolean:0", e.action _ " reports requiresApproval false")
	}
}

}
