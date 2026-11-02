Class SignalNoir.Tests.Core.Benchmark.TestRunPolicy Extends %UnitTest.TestCase
{

Parameter P = "SignalNoir.Core.Benchmark.RunPolicy";

/// A small catalog in the shape of the Simulator's GET /scenario-catalog items
ClassMethod Catalog() As %DynamicArray
{
	Return [
		{"family": "P5", "subtype": "P5", "variant": "P5-tune-01", "set": "tuning"},
		{"family": "P5", "subtype": "P5.injection", "variant": "P5-injection-tune-01", "set": "tuning"},
		{"family": "P5", "subtype": "P5", "variant": "P5-test-01", "set": "test"},
		{"family": "P8", "subtype": "P8a", "variant": "P8a-tune-01", "set": "tuning"},
		{"family": "P8", "subtype": "P8b", "variant": "P8b-tune-01", "set": "tuning"},
		{"family": "P8", "subtype": "P8b", "variant": "P8b-test-01", "set": "test"},
		{"family": "clean", "subtype": "clean.success", "variant": "clean-success-tune-01", "set": "tuning"}
	]
}

ClassMethod Request() As %DynamicObject
{
	Return {"mode": "rules", "purpose": "benchmark", "repetitions": 2, "seed": 11, "scenarios": [{"family": "P5", "set": "tuning"}]}
}

Method TestAValidRequestIsExpandedToExplicitVariants()
{
	Set r = $ClassMethod(..#P, "Validate", ..Request(), ..Catalog())
	Do $$$AssertTrue(r.ok, "a valid request is accepted")
	Set plan = r.obj
	Do $$$AssertEquals(plan.mode, "rules", "mode")
	Do $$$AssertEquals(plan.repetitions, 2, "repetitions")
	Do $$$AssertEquals(plan.seed, 11, "seed")
	Do $$$AssertEquals(plan.variants.%Size(), 2, "family P5 tuning has two variants")
	Do $$$AssertEquals(plan.variants.%Get(0).variant, "P5-tune-01", "in catalog order")
	Do $$$AssertEquals(plan.variants.%Get(1).subtype, "P5.injection", "the subtype is carried")
}

Method TestDefaults()
{
	Set req = {"mode": "agent", "purpose": "benchmark", "scenarios": [{"family": "P8", "variants": ["P8b-tune-01"]}]}
	Set plan = $ClassMethod(..#P, "Validate", req, ..Catalog()).obj
	Do $$$AssertEquals(plan.repetitions, 3, "k defaults to 3")
	Do $$$AssertEquals(plan.seed, 0, "base seed defaults to 0")
	Do $$$AssertEquals(plan.variants.%Size(), 1, "explicit variant only")
}

Method TestAnOmittedSetIsTheTuningSetUnlessTheReference()
{
	Set req = {"mode": "rules", "purpose": "benchmark", "scenarios": [{"family": "P5"}]}
	Set plan = $ClassMethod(..#P, "Validate", req, ..Catalog()).obj
	Do $$$AssertEquals(plan.variants.%Size(), 2, "tuning variants, never the reserved ones, by default")
	Set req = {"mode": "agent", "purpose": "reference", "provider": "openai", "model": "m", "scenarios": [{"family": "P5"}]}
	Set plan = $ClassMethod(..#P, "Validate", req, ..Catalog()).obj
	Do $$$AssertEquals(plan.variants.%Size(), 1, "the reference takes the test set")
	Do $$$AssertEquals(plan.variants.%Get(0).variant, "P5-test-01", "the test variant")
}

Method TestRefusals()
{
	Set cat = ..Catalog()
	Set bad = ##class(%DynamicArray).%New()
	Do bad.%Push({"why": "no scenarios", "req": {"mode": "rules", "purpose": "benchmark", "scenarios": []}})
	Do bad.%Push({"why": "scenarios missing", "req": {"mode": "rules", "purpose": "benchmark"}})
	Do bad.%Push({"why": "unknown family", "req": {"mode": "rules", "purpose": "benchmark", "scenarios": [{"family": "P7"}]}})
	Do bad.%Push({"why": "unknown variant", "req": {"mode": "rules", "purpose": "benchmark", "scenarios": [{"family": "P5", "variants": ["P5-nope"]}]}})
	Do bad.%Push({"why": "variant of another family", "req": {"mode": "rules", "purpose": "benchmark", "scenarios": [{"family": "P5", "variants": ["P8b-tune-01"]}]}})
	Do bad.%Push({"why": "variant outside the requested set", "req": {"mode": "rules", "purpose": "benchmark", "scenarios": [{"family": "P5", "set": "test", "variants": ["P5-tune-01"]}]}})
	Do bad.%Push({"why": "no variant in the set", "req": {"mode": "rules", "purpose": "benchmark", "scenarios": [{"family": "clean", "set": "test"}]}})
	Do bad.%Push({"why": "repetitions 0", "req": {"mode": "rules", "purpose": "benchmark", "repetitions": 0, "scenarios": [{"family": "P5"}]}})
	Do bad.%Push({"why": "repetitions 11", "req": {"mode": "rules", "purpose": "benchmark", "repetitions": 11, "scenarios": [{"family": "P5"}]}})
	Do bad.%Push({"why": "repetitions 1.5", "req": {"mode": "rules", "purpose": "benchmark", "repetitions": 1.5, "scenarios": [{"family": "P5"}]}})
	Do bad.%Push({"why": "negative seed", "req": {"mode": "rules", "purpose": "benchmark", "seed": -1, "scenarios": [{"family": "P5"}]}})
	Do bad.%Push({"why": "bad mode", "req": {"mode": "oracle", "purpose": "benchmark", "scenarios": [{"family": "P5"}]}})
	Do bad.%Push({"why": "missing mode", "req": {"purpose": "benchmark", "scenarios": [{"family": "P5"}]}})
	Do bad.%Push({"why": "bad purpose", "req": {"mode": "rules", "purpose": "demo", "scenarios": [{"family": "P5"}]}})
	Do bad.%Push({"why": "bad set", "req": {"mode": "rules", "purpose": "benchmark", "scenarios": [{"family": "P5", "set": "dev"}]}})
	For i = 0 : 1 : bad.%Size() - 1 {
		Set item = bad.%Get(i)
		Set r = $ClassMethod(..#P, "Validate", item.req, cat)
		Do $$$AssertNotTrue(r.ok, item.why _ " is refused")
		Do $$$AssertEquals(r.code, "VALIDATION_FAILED", item.why _ ": the code")
	}
}

Method TestTheReferenceTakesTestVariantsOnly()
{
	Set cat = ..Catalog()
	Set tuning = {"mode": "agent", "purpose": "reference", "provider": "openai", "model": "m", "scenarios": [{"family": "P5", "set": "tuning"}]}
	Do $$$AssertNotTrue($ClassMethod(..#P, "Validate", tuning, cat).ok, "tuning variants in a reference are refused")
	Set mixed = {"mode": "agent", "purpose": "reference", "provider": "openai", "model": "m", "scenarios": [{"family": "P5", "set": "test"}, {"family": "P8", "set": "tuning"}]}
	Do $$$AssertNotTrue($ClassMethod(..#P, "Validate", mixed, cat).ok, "a mix is refused")
	Set explicit = {"mode": "agent", "purpose": "reference", "provider": "openai", "model": "m", "scenarios": [{"family": "P5", "variants": ["P5-tune-01"]}]}
	Do $$$AssertNotTrue($ClassMethod(..#P, "Validate", explicit, cat).ok, "an explicit tuning variant is refused")
	Set ok = {"mode": "agent", "purpose": "reference", "provider": "openai", "model": "m", "scenarios": [{"family": "P5", "set": "test"}, {"family": "P8", "set": "test"}]}
	Do $$$AssertTrue($ClassMethod(..#P, "Validate", ok, cat).ok, "test variants are accepted")
}

Method TestTheAgentReferenceNeedsAProviderAndAModel()
{
	Set req = {"mode": "agent", "purpose": "reference", "scenarios": [{"family": "P5", "set": "test"}]}
	Do $$$AssertNotTrue($ClassMethod(..#P, "Validate", req, ..Catalog()).ok, "no provider and model")
}

Method TestRulesModeIgnoresProviderAndModel()
{
	Set req = ..Request()
	Set req.provider = "openai", req.model = "gpt"
	Set plan = $ClassMethod(..#P, "Validate", req, ..Catalog()).obj
	Do $$$AssertEquals(plan.provider, "", "provider is dropped in rules mode")
	Do $$$AssertEquals(plan.model, "", "model is dropped in rules mode")
}

Method TestTheStateMachine()
{
	Do $$$AssertEquals($ClassMethod(..#P, "Next", "created", "start"), "running", "created > running")
	Do $$$AssertEquals($ClassMethod(..#P, "Next", "running", "complete"), "completed", "running > completed")
	Do $$$AssertEquals($ClassMethod(..#P, "Next", "created", "fail"), "failed", "created > failed")
	Do $$$AssertEquals($ClassMethod(..#P, "Next", "running", "fail"), "failed", "running > failed")
	Do $$$AssertEquals($ClassMethod(..#P, "Next", "created", "complete"), "", "created cannot complete")
	Do $$$AssertEquals($ClassMethod(..#P, "Next", "completed", "start"), "", "completed is final")
	Do $$$AssertEquals($ClassMethod(..#P, "Next", "completed", "fail"), "", "completed cannot fail")
	Do $$$AssertEquals($ClassMethod(..#P, "Next", "failed", "start"), "", "failed is final")
	Do $$$AssertEquals($ClassMethod(..#P, "Next", "running", "start"), "", "no restart of a running run")
	Do $$$AssertEquals($ClassMethod(..#P, "Next", "running", "bogus"), "", "unknown event")
}

Method TestOneRunAtATime()
{
	Do $$$AssertTrue($ClassMethod(..#P, "StartAllowed", 0), "none active: allowed")
	Do $$$AssertNotTrue($ClassMethod(..#P, "StartAllowed", 1), "one active: refused")
	Do $$$AssertNotTrue($ClassMethod(..#P, "StartAllowed", 3), "several active: refused")
}

}
