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

}
