Class SignalNoir.Tests.Application.Benchmark.TestAnswerKeys Extends %UnitTest.TestCase
{

Property SavedBase As %String;

/// 010 T030 - every variant that is scored has an answer key, declared before it runs, made
/// of the closed catalog's Actions (FR-014). The Simulator's catalog is read over HTTP.
Method OnBeforeAllTests() As %Status
{
	Set ..SavedBase = $Get(^SignalNoir.Config("simBaseUrl"))
	Set ^SignalNoir.Config("simBaseUrl") = "http://localhost:52773/sim/api/v1"
	Return $$$OK
}

Method OnAfterAllTests() As %Status
{
	Set ^SignalNoir.Config("simBaseUrl") = ..SavedBase
	Return $$$OK
}

/// The scored families: P3 and idempotency feed the platform guarantees only, and P1 and P9
/// are not scored in this feature
ClassMethod Scored(family As %String) As %Boolean
{
	Return ((family = "P5") || (family = "P8") || (family = "clean"))
}

Method TestEveryScoredVariantHasAKey()
{
	Set catalog = ##class(SignalNoir.Application.Benchmark.RunService).%New().LoadCatalog()
	If 'catalog.ok Do $$$LogMessage("Simulator not reachable: skipped") Quit
	Set keys = ##class(SignalNoir.Benchmark.Data.Base).Keys()
	Set checked = 0
	For i = 0 : 1 : catalog.obj.%Size() - 1 {
		Set v = catalog.obj.%Get(i)
		If '..Scored(v.family) Continue
		Set checked = checked + 1
		Do $$$AssertTrue(keys.%IsDefined(v.variant), v.variant _ " has an answer key")
	}
	Do $$$AssertTrue(checked > 10, "the check looked at " _ checked _ " variants")
}

Method TestNoKeyNamesAVariantThatDoesNotExist()
{
	Set catalog = ##class(SignalNoir.Application.Benchmark.RunService).%New().LoadCatalog()
	If 'catalog.ok Do $$$LogMessage("Simulator not reachable: skipped") Quit
	Set names = {}
	For i = 0 : 1 : catalog.obj.%Size() - 1 Do names.%Set(catalog.obj.%Get(i).variant, 1)
	Set it = ##class(SignalNoir.Benchmark.Data.Base).Keys().%GetIterator()
	While it.%GetNext(.variant) {
		Do $$$AssertTrue(names.%IsDefined(variant), variant _ " is a variant of the Simulator's catalog")
	}
}

Method TestEveryKeyIsWellFormed()
{
	Set it = ##class(SignalNoir.Benchmark.Data.Base).Keys().%GetIterator()
	While it.%GetNext(.variant, .key) {
		Do $$$AssertEquals(key.%GetTypeOf("acceptable"), "array", variant _ ": acceptable is a list")
		Do $$$AssertTrue(key.%IsDefined("reviewIsAcceptable"), variant _ ": says whether review is acceptable")
		If key.%GetTypeOf("acceptable") '= "array" Continue
		Set accepts = key.acceptable.%Size()
		For j = 0 : 1 : accepts - 1 {
			Set spec = key.acceptable.%Get(j)
			Do $$$AssertTrue(##class(SignalNoir.Core.Vocab).IsAction(spec.action), variant _ ": " _ spec.action _ " is in the closed catalog")
			Do $$$AssertTrue((spec.%GetTypeOf("params") = "object") || (spec.%GetTypeOf("params") = "unassigned"), variant _ ": params is an object")
		}
		Do $$$AssertTrue(accepts || key.reviewIsAcceptable || key.%Get("expectsNoCase") || (key.%GetTypeOf("acceptableStates") = "array"), variant _ ": the key accepts something")
	}
}

Method TestNoVariantHasTwoKeys()
{
	Do $$$AssertEquals(##class(SignalNoir.Benchmark.Data.Base).Duplicates().%Size(), 0, "no variant is keyed twice")
}

}
