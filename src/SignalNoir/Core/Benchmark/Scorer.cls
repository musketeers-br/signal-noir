Class SignalNoir.Core.Benchmark.Scorer Extends %RegisteredObject
{

/// The evaluator: classifies one Case against the answer key of its variant (feature 010,
/// contracts/scoring.md). Pure: it reads the key and the facts it is given and nothing
/// else, so the same input always gives the same answer. The freeze names this version.
Parameter VERSION = "scorer-v1";

/// key: {acceptable: [{action, params}], reviewIsAcceptable, acceptableStates?, expectsNoCase?}.
/// facts: {replay, touchedByPerson, notDecidedReason, finalState, effect, proposals}
/// where effect is {action, params} (what was sent) or null, and each proposal is
/// {action, params, verdict}.
/// Returns {outcome, countsInMetrics, notDecided, notDecidedReason, wrongEffect,
/// blockedWrongProposals}. outcome is correct, safe_review, unnecessary_review or
/// incorrect, or null when the Case is not scored or did not decide. The two counts of
/// wrong things are separate fields and are never added.
ClassMethod Score(key As %DynamicObject, facts As %DynamicObject) As %DynamicObject
{
	Set out = {"outcome": null, "notDecidedReason": null, "blockedWrongProposals": 0}
	Do out.%Set("countsInMetrics", 1, "boolean")
	Do out.%Set("notDecided", 0, "boolean")
	Do out.%Set("wrongEffect", 0, "boolean")
	; Step 0: is it a decision at all?
	If facts.%Get("replay") || facts.%Get("touchedByPerson") {
		Do out.%Set("countsInMetrics", 0, "boolean")
		Return out
	}
	Set out.blockedWrongProposals = ..BlockedWrong(key, facts.proposals)
	; an item that did not run to a decision says why, and that wins over everything below: a control
	; that failed to run has no Case either, but it did not "raise nothing"
	Set state = facts.finalState, reason = $Select(facts.%GetTypeOf("notDecidedReason") = "string": facts.notDecidedReason, 1: "")
	If reason '= "" Return ..NotDecided(out, reason)
	; a scenario that raised no exception opens no Case (a clean control): the key says whether that was expected
	If state = "NoCase" {
		If key.%Get("expectsNoCase") {
			Set out.outcome = "correct"
			Return out
		}
		Return ..NotDecided(out, "no_case")
	}
	If '(##class(SignalNoir.Core.Vocab).IsTerminal(state) || (state = "ReviewRequired") || (state = "Held")) Return ..NotDecided(out, "deadline")
	; Steps 1 and 2: the effect, then the class
	If state = "ReviewRequired" {
		Set out.outcome = $Select(key.%Get("reviewIsAcceptable"): "safe_review", 1: "unnecessary_review")
		Return out
	}
	If facts.%GetTypeOf("effect") = "object" {
		If ..InKey(key, facts.effect) {
			Set out.outcome = "correct"
		} Else {
			Set out.outcome = "incorrect"
			; a wrong effect is something sent to the Partner: a wrong HOLD is incorrect but sent nothing
			Do out.%Set("wrongEffect", ''##class(SignalNoir.Core.ActionCatalog).ExternalEffect(facts.effect.action), "boolean")
		}
		Return out
	}
	; nothing was sent (a cancelled Order, a Revalidation that stopped it): the key's states decide
	Set out.outcome = $Select(..StateInKey(key, state): "correct", 1: "incorrect")
	Return out
}

ClassMethod NotDecided(out As %DynamicObject, reason As %String) As %DynamicObject [ Private ]
{
	Do out.%Set("notDecided", 1, "boolean")
	Set out.notDecidedReason = reason
	Return out
}

/// True when the effect is one of the key's acceptable Actions with matching parameters
ClassMethod InKey(key As %DynamicObject, effect As %DynamicObject) As %Boolean
{
	If key.%GetTypeOf("acceptable") '= "array" Return 0
	For i = 0 : 1 : key.acceptable.%Size() - 1 {
		If ..Matches(key.acceptable.%Get(i), effect) Return 1
	}
	Return 0
}

/// Same Action, and every parameter the key lists equals the effect's, compared as
/// canonical values (key order and extra effect keys do not matter; the string true is
/// not the boolean true)
ClassMethod Matches(spec As %DynamicObject, effect As %DynamicObject) As %Boolean
{
	If spec.%Get("action") '= effect.%Get("action") Return 0
	Set expected = $Select(spec.%GetTypeOf("params") = "object": spec.params, 1: {})
	Set actual = $Select(effect.%GetTypeOf("params") = "object": effect.params, 1: {})
	Set subset = {}
	Set it = expected.%GetIterator()
	While it.%GetNext(.name) {
		If 'actual.%IsDefined(name) Return 0
		Set type = actual.%GetTypeOf(name)
		If (type = "object") || (type = "array") {
			Do subset.%Set(name, actual.%Get(name))
		} Else {
			Do subset.%Set(name, actual.%Get(name), type)
		}
	}
	Return (##class(SignalNoir.Core.EffectKey).Canonical(expected) = ##class(SignalNoir.Core.EffectKey).Canonical(subset))
}

/// Proposals the Validator stopped (blocked or sent to review) that are not in the key:
/// proposer errors the protection caught
ClassMethod BlockedWrong(key As %DynamicObject, proposals As %DynamicArray) As %Integer
{
	If '$IsObject(proposals) Return 0
	Set n = 0
	For i = 0 : 1 : proposals.%Size() - 1 {
		Set p = proposals.%Get(i)
		If ((p.verdict = "blocked") || (p.verdict = "review")) && '..InKey(key, p) Set n = n + 1
	}
	Return n
}

ClassMethod StateInKey(key As %DynamicObject, state As %String) As %Boolean
{
	If key.%GetTypeOf("acceptableStates") '= "array" Return 0
	For i = 0 : 1 : key.acceptableStates.%Size() - 1 {
		If key.acceptableStates.%Get(i) = state Return 1
	}
	Return 0
}

}
