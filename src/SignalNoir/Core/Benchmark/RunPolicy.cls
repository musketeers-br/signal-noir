Class SignalNoir.Core.Benchmark.RunPolicy Extends %RegisteredObject
{

/// The rules of a BenchmarkRun that need no I/O (feature 010, plan D1, D8): what a
/// create request may ask for, how a selection expands to explicit variants, the
/// run's state machine and the one-run-at-a-time rule. Pure.
Parameter MODES = "rules,agent,replay";

Parameter PURPOSES = "benchmark,reference,quick_validation";

Parameter FAMILIES = "clean,P1,P3,P5,P8,P9,idempotency";

/// Validates a create request against the Simulator's catalog (an array of
/// {family, subtype, variant, set}) and expands it. Returns a Result whose obj is
/// {mode, purpose, provider, model, repetitions, seed, label, fixtureSet, variants}
/// with the variants listed explicitly, in catalog order; or VALIDATION_FAILED with
/// details.errors. A selection that names no set takes the tuning set, never the
/// reserved one, except for the reference purpose, which takes the test set.
ClassMethod Validate(request As %DynamicObject, catalog As %DynamicArray) As SignalNoir.Core.Result
{
	Set errors = []
	If '$IsObject(request) Return ..Refuse("the request is not an object", errors)
	Set mode = ..Text(request, "mode"), purpose = ..Text(request, "purpose")
	If (mode = "") || ((","_..#MODES_",") '[ (","_mode_",")) Do errors.%Push("mode must be one of " _ ..#MODES)
	If (purpose = "") || ((","_..#PURPOSES_",") '[ (","_purpose_",")) Do errors.%Push("purpose must be one of " _ ..#PURPOSES)
	Set repetitions = 3
	If request.%IsDefined("repetitions") {
		Set repetitions = request.repetitions
		If (request.%GetTypeOf("repetitions") '= "number") || (repetitions '= (repetitions \ 1)) || (repetitions < 1) || (repetitions > 10) {
			Do errors.%Push("repetitions must be an integer from 1 to 10")
			Set repetitions = 3
		}
	}
	Set seed = 0
	If request.%IsDefined("seed") {
		Set seed = request.seed
		If (request.%GetTypeOf("seed") '= "number") || (seed '= (seed \ 1)) || (seed < 0) {
			Do errors.%Push("seed must be an integer from 0")
			Set seed = 0
		}
	}
	Set provider = ..Text(request, "provider"), model = ..Text(request, "model")
	If mode = "rules" Set provider = "", model = ""
	If (mode = "agent") && (purpose = "reference") && ((provider = "") || (model = "")) Do errors.%Push("an agent reference run needs a provider and a model")
	Set variants = []
	If request.%GetTypeOf("scenarios") '= "array" {
		Do errors.%Push("scenarios must be a non-empty list")
	} ElseIf 'request.scenarios.%Size() {
		Do errors.%Push("scenarios must be a non-empty list")
	} Else {
		For i = 0 : 1 : request.scenarios.%Size() - 1 {
			Do ..Expand(request.scenarios.%Get(i), purpose, catalog, variants, errors)
		}
	}
	If errors.%Size() Return ..Refuse("the request is refused", errors)
	Set plan = {"mode": (mode), "purpose": (purpose), "provider": (provider), "model": (model), "repetitions": (repetitions), "seed": (seed), "label": (..Text(request, "label")), "variants": (variants)}
	If request.%GetTypeOf("fixtureSet") = "object" Do plan.%Set("fixtureSet", request.fixtureSet)
	Return ##class(SignalNoir.Core.Result).OkObj(plan)
}

/// One scenario selection {family, variants?, set?}: appends the explicit variants it names
ClassMethod Expand(selection As %DynamicObject, purpose As %String, catalog As %DynamicArray, variants As %DynamicArray, errors As %DynamicArray) [ Private ]
{
	If '$IsObject(selection) || (selection.%GetTypeOf("family") '= "string") {
		Do errors.%Push("a scenario needs a family")
		Quit
	}
	Set family = selection.family
	If (","_..#FAMILIES_",") '[ (","_family_",") {
		Do errors.%Push("unknown family " _ family)
		Quit
	}
	Set set = $Select(selection.%GetTypeOf("set") = "string": selection.set, 1: $Select(purpose = "reference": "test", 1: "tuning"))
	If (set '= "tuning") && (set '= "test") {
		Do errors.%Push("set must be tuning or test")
		Quit
	}
	If (purpose = "reference") && (set '= "test") {
		Do errors.%Push("a reference run takes test variants only (family " _ family _ ")")
		Quit
	}
	Set before = variants.%Size()
	If selection.%GetTypeOf("variants") = "array" {
		For i = 0 : 1 : selection.variants.%Size() - 1 {
			Set name = selection.variants.%Get(i), found = ""
			For j = 0 : 1 : catalog.%Size() - 1 {
				If catalog.%Get(j).variant = name Set found = catalog.%Get(j)
			}
			If found = "" {
				Do errors.%Push("unknown variant " _ name)
			} ElseIf found.family '= family {
				Do errors.%Push("variant " _ name _ " belongs to family " _ found.family _ ", not " _ family)
			} ElseIf (selection.%GetTypeOf("set") = "string") && (found.set '= set) {
				Do errors.%Push("variant " _ name _ " is in the " _ found.set _ " set, not " _ set)
			} ElseIf (purpose = "reference") && (found.set '= "test") {
				Do errors.%Push("a reference run takes test variants only (" _ name _ ")")
			} Else {
				Do variants.%Push({"family": (found.family), "subtype": (found.subtype), "variant": (found.variant), "set": (found.set)})
			}
		}
	} Else {
		For j = 0 : 1 : catalog.%Size() - 1 {
			Set v = catalog.%Get(j)
			If (v.family = family) && (v.set = set) Do variants.%Push({"family": (v.family), "subtype": (v.subtype), "variant": (v.variant), "set": (v.set)})
		}
	}
	If (variants.%Size() = before) && (errors.%Size() = 0) Do errors.%Push("no variant of family " _ family _ " in the " _ set _ " set")
}

/// The run's state machine (data-model.md): returns the next status, or "" when the
/// event is not allowed in this status. completed and failed are final.
ClassMethod Next(status As %String, event As %String) As %String
{
	If (status = "created") && (event = "start") Return "running"
	If (status = "running") && (event = "complete") Return "completed"
	If ((status = "created") || (status = "running")) && (event = "fail") Return "failed"
	Return ""
}

/// One run at a time (FR-005, API-Q10): allowed only when no run is created or running
ClassMethod StartAllowed(activeRuns As %Integer) As %Boolean
{
	Return (+activeRuns = 0)
}

ClassMethod Text(o As %DynamicObject, key As %String) As %String [ Private ]
{
	Return $Select(o.%GetTypeOf(key) = "string": o.%Get(key), 1: "")
}

ClassMethod Refuse(message As %String, errors As %DynamicArray) As SignalNoir.Core.Result [ Private ]
{
	Set text = message
	If errors.%Size() {
		Set text = ""
		For i = 0 : 1 : errors.%Size() - 1 Set text = text _ $Select(i = 0: "", 1: "; ") _ errors.%Get(i)
	}
	Return ##class(SignalNoir.Core.Result).ErrorWith("VALIDATION_FAILED", text, {"errors": (errors)})
}

}
