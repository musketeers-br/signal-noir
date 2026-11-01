Class SignalNoir.Core.Benchmark.QuickCheck Extends %RegisteredObject
{

/// The comparison of the quick validation (feature 010, FR-033): a Case of the run against the
/// recorded reference result of the same reference case. Pure. A Case "matches the reference" when it
/// ended in the same state, with the same Action and the parameters the reference recorded (the
/// Case may carry more). Otherwise it "diverged", and the reason says what differs. A provider or
/// model other than the reference's does not make it diverge by itself: it is said alongside.
/// reference: {referenceCase, finalState, action, params} (finalState NoCase or null for a control
/// that raised nothing). actual: {finalState, action, actionParams} as in the report's Case row
/// (finalState null for no Case). runInfo: {mode, providerDiffers}.
/// Returns {status: matches_reference | diverged, reason: string | null}.
ClassMethod Compare(reference As %DynamicObject, actual As %DynamicObject, runInfo As %DynamicObject) As %DynamicObject
{
	Set want = ..FinalState(reference)
	Set got = ..FinalState(actual)
	Set note = $Select(runInfo.%Get("providerDiffers"): " (the provider or model differs from the reference's)", 1: "")
	If want '= got Return ..Result("diverged", "a different final state: the reference ended " _ want _ ", this Case ended " _ got _ note)
	Set wantAction = $Select(reference.%GetTypeOf("action") = "string": reference.action, 1: "")
	Set gotAction = $Select(actual.%GetTypeOf("action") = "string": actual.action, 1: "")
	If wantAction '= gotAction Return ..Result("diverged", "a different Action: the reference sent " _ $Select(wantAction = "": "none", 1: wantAction) _ ", this Case sent " _ $Select(gotAction = "": "none", 1: gotAction) _ note)
	If '..ParamsMatch(reference, actual) Return ..Result("diverged", "different parameters for " _ wantAction _ ": the reference recorded " _ ##class(SignalNoir.Core.EffectKey).Canonical($Select(reference.%GetTypeOf("params") = "object": reference.params, 1: {})) _ note)
	Return ..Result("matches_reference", $Select(note '= "": "matches" _ note, 1: ""))
}

/// The final state of a reference case or a report row; a control that opened no Case is written
/// NoCase in a reference result and null in the report, and both read as NoCase
ClassMethod FinalState(row As %DynamicObject) As %String
{
	Return $Select(row.%GetTypeOf("finalState") = "string": $Select(row.finalState = "": "NoCase", 1: row.finalState), 1: "NoCase")
}

/// Every parameter the reference recorded is in the Case with the same value (canonical, not text)
ClassMethod ParamsMatch(reference As %DynamicObject, actual As %DynamicObject) As %Boolean [ Private ]
{
	Set expected = $Select(reference.%GetTypeOf("params") = "object": reference.params, 1: {})
	Set found = $Select(actual.%GetTypeOf("actionParams") = "object": actual.actionParams, 1: {})
	Set subset = {}
	Set it = expected.%GetIterator()
	While it.%GetNext(.name) {
		If 'found.%IsDefined(name) Return 0
		Set type = found.%GetTypeOf(name)
		If (type = "object") || (type = "array") {
			Do subset.%Set(name, found.%Get(name))
		} Else {
			Do subset.%Set(name, found.%Get(name), type)
		}
	}
	Return (##class(SignalNoir.Core.EffectKey).Canonical(expected) = ##class(SignalNoir.Core.EffectKey).Canonical(subset))
}

ClassMethod Result(status As %String, reason As %String) As %DynamicObject [ Private ]
{
	Set r = {"status": (status)}
	Do r.%Set("reason", reason, $Select(reason = "": "null", 1: "string"))
	Return r
}

}
