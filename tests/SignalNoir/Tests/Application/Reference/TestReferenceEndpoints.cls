Class SignalNoir.Tests.Application.Reference.TestReferenceEndpoints Extends %UnitTest.TestCase
{

Parameter DISPATCH = "SignalNoir.Api.Dispatch";

Parameter STORE = "SignalNoir.Application.Reference.Store";

Parameter INPUTS = "SignalNoir.Tests.Core.Validator.Inputs";

/// 004 T035 - the reference endpoints (US6 AS3, AS4, research D10): the Action catalog and the
/// Mappings in force, read through the payload methods of the Dispatch, which the routes write
/// out. The Store's globals are saved and emptied around each test.
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

Method TestTheMappingsInForceAreReturnedWithTheirVersion()
{
	Set p = $ClassMethod(..#DISPATCH, "MappingsPayload")
	Do $$$AssertEquals(p.mappingVersion, "2026.10.1", "AS4: the version in force, no longer `unloaded`")
	Do $$$AssertEquals(p.items.%Size(), 4, "every Mapping")
	Do $$$AssertTrue(p.%GetTypeOf("serverTime") = "string", "serverTime")
	Set item = p.items.%Get(0)
	For field = "mappingId", "mappingVersion", "sourceCode", "targetCode" Do $$$AssertEquals(item.%GetTypeOf(field), "string", "ApprovedMapping." _ field)
	Do $$$AssertEquals(item.%GetTypeOf("conditions"), "object", "ApprovedMapping.conditions")
	Do $$$AssertEquals(p.%IsDefined("synonyms"), 0, "the contract's response has no synonyms: those travel with the Tool")
}

Method TestTheMappingsCanBeFilteredBySourceCode()
{
	Set p = $ClassMethod(..#DISPATCH, "MappingsPayload", "GLIC-J")
	Do $$$AssertEquals(p.items.%Size(), 2, "the two Mappings of GLIC-J")
	Set ids = p.items.%Get(0).mappingId _ "," _ p.items.%Get(1).mappingId
	Do $$$AssertEquals(ids, "map_glicj_plasma,map_glicj_soro", "in the order of the fixture")
	Do $$$AssertEquals($ClassMethod(..#DISPATCH, "MappingsPayload", " glic-j ").items.%Size(), 2, "the code is compared like the Validator does: trimmed, any case")
	Set none = $ClassMethod(..#DISPATCH, "MappingsPayload", "NOPE")
	Do $$$AssertEquals(none.items.%Size() _ ":" _ none.mappingVersion, "0:2026.10.1", "an unknown code: no items, the version still named")
}

Method TestTheMappingsFollowTheVersionInForce()
{
	Do $ClassMethod(..#STORE, "Load", "SignalNoir.Application.Reference")
	Do $ClassMethod(..#STORE, "Load", "SignalNoir.Tests.Application.Reference.Fixtures.Good")
	Do $ClassMethod(..#STORE, "SetInForce", "2026.10.2", "2026.10.2")
	Set p = $ClassMethod(..#DISPATCH, "MappingsPayload")
	Do $$$AssertEquals(p.mappingVersion _ ":" _ p.items.%Size(), "2026.10.2:3", "version B: three Mappings")
}

Method TestWithNothingLoadedTheListSaysSo()
{
	Set ^SignalNoir.Reference("defaultPackage") = "No.Such.Package"
	Set p = $ClassMethod(..#DISPATCH, "MappingsPayload")
	Do $$$AssertEquals(p.mappingVersion _ ":" _ p.items.%Size(), "unloaded:0", "no Mapping is invented")
}

Method TestTheCatalogListsTheFourActionsWithTheirRequiredEvidence()
{
	Set p = $ClassMethod(..#DISPATCH, "ActionCatalogPayload")
	Do $$$AssertEquals(p.items.%Size(), 4, "AS3: exactly the four Actions")
	Set names = ""
	For i = 0 : 1 : 3 Set names = names _ $Select(i = 0: "", 1: ",") _ p.items.%Get(i).action
	Do $$$AssertEquals(names, "RETRY,APPLY_APPROVED_MAPPING,HOLD,REQUEST_REVIEW", "in the catalog's order")
	For i = 0 : 1 : 3 {
		Set e = p.items.%Get(i)
		For field = "paramsSchema", "externalEffect", "requiresApproval", "requiredEvidence" Do $$$AssertTrue(e.%IsDefined(field), e.action _ " has " _ field)
	}
	Do $$$AssertEquals(p.items.%Get(0).requiredEvidence.%ToJSON(), "[""tool.policies#attempt"",""tool.partner_failure_history"",""tool.partner_health""]", "RETRY: attempt policy, attempt history, partner health")
	Do $$$AssertEquals(p.items.%Get(1).requiredEvidence.%ToJSON(), "[""tool.policies#substitution"",""tool.mapping_catalog"",""order#<condition field>""]", "APPLY_APPROVED_MAPPING: substitution policy, the Mapping, the Order field")
	Do $$$AssertEquals(p.items.%Get(2).requiredEvidence.%ToJSON(), "[""tool.partner_health|tool.policies#maintenanceWindows""]", "HOLD: health or a window")
	Do $$$AssertEquals(p.items.%Get(3).requiredEvidence.%ToJSON(), "[]", "REQUEST_REVIEW: none")
	Do $$$AssertTrue(p.%GetTypeOf("serverTime") = "string", "serverTime")
}

Method TestTheCatalogAndTheVerdictAgreeOnRequiresApproval()
{
	Set p = $ClassMethod(..#DISPATCH, "ActionCatalogPayload")
	For i = 0 : 1 : 3 {
		Set entry = p.items.%Get(i), action = entry.action
		Set params = $Select(action = "APPLY_APPROVED_MAPPING": $ClassMethod(..#INPUTS, "MappingParams"), 1: "")
		Set verdict = ##class(SignalNoir.Core.Validator).%New().Validate($ClassMethod(..#INPUTS, "Input", $ClassMethod(..#INPUTS, "Proposal", action, params)))
		Do $$$AssertEquals(+entry.requiresApproval, +verdict.requiresApproval, action _ ": the endpoint and the verdict report the same requiresApproval")
	}
	Do $$$AssertEquals(p.items.%Get(3).requiresApproval, 0, "REQUEST_REVIEW needs no Approval (PRD FR-16)")
}

}
