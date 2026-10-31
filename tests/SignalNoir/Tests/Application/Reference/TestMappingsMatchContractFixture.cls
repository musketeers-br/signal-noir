Class SignalNoir.Tests.Application.Reference.TestMappingsMatchContractFixture Extends %UnitTest.TestCase
{

Parameter FIXTURE = "contracts/fixtures/reference.mappings.json";

/// 004 T013 - the items of Mappings.V2026101 equal the items of the contract fixture. The
/// fixture is read here, never at runtime.
ClassMethod Fixture() As %DynamicObject
{
	Set stream = ##class(%Stream.FileCharacter).%New()
	Do stream.LinkToFile(##class(SignalNoir.Tests.Core.Validator.Repo).Path(..#FIXTURE))
	Return {}.%FromJSON(stream.Read(2000000))
}

ClassMethod Content(class As %String) As %DynamicObject
{
	Set x = ##class(%Dictionary.CompiledXData).%OpenId(class _ "||Content")
	If '$IsObject(x) Return ""
	Return {}.%FromJSON(x.Data)
}

Method TestItemsEqualTheContractFixture()
{
	Set fixture = ..Fixture(), set = ..Content("SignalNoir.Application.Reference.Mappings.V2026101")
	Do $$$AssertTrue($IsObject(set), "the Mapping Set 2026.10.1 fixture is compiled")
	Do $$$AssertEquals(set.items.%Size(), fixture.items.%Size(), "same number of mappings")
	Do $$$AssertEquals(set.items.%ToJSON(), fixture.items.%ToJSON(), "same items, same order")
	Do $$$AssertEquals(set.mappingVersion, fixture.mappingVersion, "same mappingVersion")
	Do $$$AssertEquals(##class(SignalNoir.Application.Reference.Mappings.V2026101).#VERSION, fixture.mappingVersion, "the VERSION parameter agrees")
}

Method TestSynonymsCoverTheConditionValues()
{
	Set set = ..Content("SignalNoir.Application.Reference.Mappings.V2026101"), missing = ""
	Set it = set.items.%GetIterator()
	While it.%GetNext(, .item) {
		Set c = item.conditions.%GetIterator()
		While c.%GetNext(.field, .value) {
			If '$IsObject(set.synonyms.%Get(field)) || (set.synonyms.%Get(field).%GetTypeOf(value) = "unassigned") Set missing = missing _ " " _ item.mappingId _ "." _ field
		}
	}
	Do $$$AssertEquals(missing, "", "every condition value has a synonym entry")
	Do $$$AssertEquals(set.synonyms.specimenType.SERUM.%Get(1), "SORO", "soro is a synonym of serum")
}

Method TestPolicySetHasTheDocumentedContent()
{
	Set p = ..Content("SignalNoir.Application.Reference.Policies.V2026101")
	Do $$$AssertTrue($IsObject(p), "the Policy Set 2026.10.1 fixture is compiled")
	Do $$$AssertEquals(p.version, "2026.10.1", "version")
	Do $$$AssertEquals(p.attempt.maxAttempts, 3, "maxAttempts")
	Do $$$AssertEquals(p.substitution.enabled, 1, "substitution enabled")
	Do $$$AssertEquals(p.maintenanceWindows.%Size(), 0, "no maintenance windows")
	Do $$$AssertEquals(p.partnerHealth.windowSeconds _ ":" _ p.partnerHealth.maxErrorRate, "300:.2", "partner health window")
	Do $$$AssertEquals(p.approval.deadlineSeconds, 900, "approval deadline")
}

}
