Class SignalNoir.Tests.Application.Benchmark.TestFreezeDraft Extends %UnitTest.TestCase
{

/// 010 T056 - the inputs of the freeze record are the ones a reference run will compare
/// (Inputs.Current over the same catalog and reference data), and they are refused while the
/// reserved set is not ready. A catalog and the keys are injected, so no Simulator is needed.
ClassMethod Service(catalog As %DynamicArray) As SignalNoir.Application.Benchmark.RunService
{
	Set svc = ##class(SignalNoir.Application.Benchmark.RunService).%New()
	Set svc.AutoStart = 0
	Set svc.Catalog = catalog
	Return svc
}

ClassMethod Ready() As %DynamicArray
{
	Return [
		{"family": "P5", "subtype": "P5", "variant": "P5-tune-01", "set": "tuning"},
		{"family": "P5", "subtype": "P5", "variant": "P5-test-01", "set": "test"},
		{"family": "P8", "subtype": "P8b", "variant": "P8b-test-01", "set": "test"}
	]
}

ClassMethod Keys() As %DynamicArray
{
	Return [{"variant": "P5-test-01", "acceptable": [], "reviewIsAcceptable": true}, {"variant": "P8b-test-01", "acceptable": [], "reviewIsAcceptable": true}]
}

Method TestTheInputsAreTheOnesARunCompares()
{
	Set r = ##class(SignalNoir.Application.Benchmark.FreezeDraft).Inputs("gpt-4o-mini", ..Service(..Ready()), ..Keys())
	Do $$$AssertTrue(r.ok, "ready: " _ r.message)
	If 'r.ok Quit
	Set snapshot = ##class(SignalNoir.Application.Reference.Store).For({"inRun": true, "policyVersion": "", "mappingVersion": ""})
	Set expected = ##class(SignalNoir.Application.Benchmark.Inputs).Current("gpt-4o-mini", snapshot.obj.policyVersion, snapshot.obj.mappingVersion, ..Ready())
	For field = "promptVersion", "model", "baselineVersion", "policyVersion", "mappingVersion", "policyDigest", "mappingDigest", "evaluatorVersion", "reservedCatalogDigest", "answerKeyDigest" {
		Do $$$AssertTrue(r.obj.%Get(field) '= "", field _ " is filled")
		Do $$$AssertEquals(r.obj.%Get(field), expected.%Get(field), field _ " is what FreezeCheck will compare")
	}
	Set fields = $ListFromString(##class(SignalNoir.Core.Benchmark.FreezeCheck).#FIELDS)
	For i = 1 : 1 : $ListLength(fields) Do $$$AssertTrue(r.obj.%IsDefined($List(fields, i)), $List(fields, i) _ " is one of FreezeCheck's fields")
}

Method TestNoModelIsRefused()
{
	Set r = ##class(SignalNoir.Application.Benchmark.FreezeDraft).Inputs("", ..Service(..Ready()), ..Keys())
	Do $$$AssertTrue('r.ok, "the model is a frozen input")
}

Method TestAPlaceholderIsRefused()
{
	Set catalog = ..Ready()
	Do catalog.%Push({"family": "P8", "subtype": "P8b", "variant": "P8b-test-00", "set": "test"})
	Set r = ##class(SignalNoir.Application.Benchmark.FreezeDraft).Inputs("gpt-4o-mini", ..Service(catalog), ..Keys())
	Do $$$AssertTrue('r.ok, "refused")
	Do $$$AssertTrue(r.message [ "P8b-test-00 is a placeholder", "names the placeholder: " _ r.message)
}

Method TestAVariantWithoutAKeyIsRefused()
{
	Set keys = ..Keys()
	Do keys.%Remove(1)
	Set r = ##class(SignalNoir.Application.Benchmark.FreezeDraft).Inputs("gpt-4o-mini", ..Service(..Ready()), keys)
	Do $$$AssertTrue('r.ok, "refused")
	Do $$$AssertTrue(r.message [ "P8b-test-01 has no answer key", "names the variant: " _ r.message)
}

Method TestACatalogWithoutTestVariantsIsRefused()
{
	Set r = ##class(SignalNoir.Application.Benchmark.FreezeDraft).Inputs("gpt-4o-mini", ..Service([{"family": "P5", "subtype": "P5", "variant": "P5-tune-01", "set": "tuning"}]), ..Keys())
	Do $$$AssertTrue('r.ok, "refused")
	Do $$$AssertTrue(r.message [ "no test variant", "says why: " _ r.message)
}

}
