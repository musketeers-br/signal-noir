Class SignalNoir.Core.DecisionAnswer Extends %RegisteredObject
{

/// Converts a Decisions API response into the raw Proposal answer every
/// proposer returns (feature 013, research R2), or into an error value when
/// the answer is not decisive. A probability is never treated as a decision:
/// below the threshold, a tie, the fallback "other" or a refusal leave no
/// Proposal and send the Case to a human. Claims come only from predicates
/// over Evidence ids the Case has. Pure; the thresholds are versioned with
/// the question set (DecisionQuestions.#VERSION).
Parameter MINTOP = 0.5;

Parameter TIEMARGIN = 0.1;

Parameter MINPREDICATE = 0.7;

/// evidence: [{evidenceId, source}] of the Case; candidates: the mappings
/// offered as choices. Result.obj = raw answer; failure codes: refused,
/// invalid_response, uncertain (message = the review reason).
/// A refusal's message is the bare provider reason; the Investigation
/// prefixes it ("proposer refused: ").
ClassMethod Convert(response As %DynamicObject, evidence As %DynamicArray, candidates As %DynamicArray) As SignalNoir.Core.Result
{
	If '$IsObject(response) || '$IsObject(response.answers) || (response.answers.%Size() = 0) Return ..Fail("refused", "no answer")
	Set choice = "", seen = ""
	Set it = response.answers.%GetIterator()
	While it.%GetNext(, .a) {
		If '$IsObject(a) Return ..Fail("invalid_response", "answer is not an object")
		If a.type = "refusal" Return ..Fail("refused", "refusal on " _ $Select(a.name '= "": a.name, 1: "the answer"))
		If $ListFind(seen, a.name) Return ..Fail("invalid_response", "duplicate answer name: " _ a.name)
		Set seen = seen _ $ListBuild(a.name)
		If a.name = "action" Set choice = a
	}
	If '$IsObject(choice) || (choice.type '= "choice") Return ..Fail("invalid_response", "no action choice in the answer")
	Set value = choice.choice
	If value = "other" Return ..Fail("uncertain", "proposer uncertain: other")
	; the chosen value must be one of the options this request offered
	Set action = $Piece(value, ":", 1), mapping = ""
	If action = "APPLY_APPROVED_MAPPING" {
		Set mapping = ..Candidate(candidates, $Piece(value, ":", 2, *))
		If '$IsObject(mapping) Return ..Fail("invalid_response", "choice is not an offered mapping: " _ value)
	} ElseIf '$ListFind($ListBuild("RETRY", "HOLD", "REQUEST_REVIEW"), value) {
		Return ..Fail("invalid_response", "choice outside the catalog: " _ value)
	}
	Set top = 0, second = 0, chosen = ""
	If $IsObject(choice.probabilities) {
		Set it = choice.probabilities.%GetIterator()
		While it.%GetNext(, .p) {
			Set prob = +p.probability
			If p.value = value Set chosen = prob
			If prob > top {
				Set second = top, top = prob
			} ElseIf prob > second {
				Set second = prob
			}
		}
	}
	If chosen = "" Set chosen = top
	If chosen < ..#MINTOP Return ..Fail("uncertain", "proposer uncertain: below threshold")
	If (top - second) < ..#TIEMARGIN Return ..Fail("uncertain", "proposer uncertain: tie")
	Set confidence = +choice.confidence
	Set claims = ..Claims(response.answers, evidence)
	Set summary = "Decisions API chose " _ value _ " with probability " _ $FNumber(chosen, "", 2) _ " (confidence " _ $FNumber(confidence, "", 2) _ ")."
	Set answer = {"diagnosis": {"summary": (summary), "claims": (claims), "hypotheses": [{"text": (summary), "status": "chosen"}]}, "action": (action), "params": (..Params(action, mapping)), "confidence": (..Level(confidence)), "preconditions": (..Preconditions(action, mapping))}
	Set r = ##class(SignalNoir.Core.Result).OkObj(answer)
	Set r.details = {"choice": (value), "probability": (chosen), "confidence": (confidence), "probabilities": (choice.probabilities)}
	Return r
}

/// One claim per predicate at or above the threshold over a known Evidence
/// id; with none, the system Exception (when recorded) is the only citation
ClassMethod Claims(answers As %DynamicArray, evidence As %DynamicArray) As %DynamicArray
{
	Set claims = [], exceptionId = ""
	Set it = evidence.%GetIterator()
	While it.%GetNext(, .ev) {
		Set source(ev.evidenceId) = ev.source
		If (ev.source = "system.exception") && (exceptionId = "") Set exceptionId = ev.evidenceId
	}
	Set it = answers.%GetIterator()
	While it.%GetNext(, .a) {
		If (a.type '= "predicate") || ($Extract(a.name, 1, 3) '= "ev:") Continue
		Set id = $Extract(a.name, 4, *)
		If (id = "") || '$Data(source(id)) Continue
		If +a.probability < ..#MINPREDICATE Continue
		Do claims.%Push({"text": (source(id) _ " supports the decision (p = " _ $FNumber(+a.probability, "", 2) _ ")"), "evidenceIds": [(id)]})
	}
	If (claims.%Size() = 0) && (exceptionId '= "") Do claims.%Push({"text": "The recorded failure is the basis of the decision", "evidenceIds": [(exceptionId)]})
	Return claims
}

ClassMethod Level(confidence As %Numeric) As %String
{
	If confidence >= 0.8 Return "HIGH"
	If confidence >= 0.5 Return "MEDIUM"
	Return "LOW"
}

ClassMethod Params(action As %String, mapping As %DynamicObject) As %DynamicObject
{
	If action = "APPLY_APPROVED_MAPPING" Return {"mappingId": (mapping.mappingId), "mappingVersion": (mapping.mappingVersion)}
	If action = "HOLD" Return {"reason": "decisions chose hold"}
	If action = "REQUEST_REVIEW" Return {"reason": "decisions chose review"}
	Return {}
}

ClassMethod Preconditions(action As %String, mapping As %DynamicObject) As %DynamicArray
{
	If action = "APPLY_APPROVED_MAPPING" Return [{"check": "MAPPING_VERSION_UNCHANGED", "expected": (mapping.mappingVersion)}]
	If action = "HOLD" Return [{"check": "PARTNER_HEALTHY_WINDOW", "expected": false}]
	If action = "RETRY" Return [{"check": "PARTNER_HEALTHY_WINDOW", "expected": true}, {"check": "ORDER_ACTIVE_AT_ORIGIN", "expected": true}]
	Return []
}

ClassMethod Candidate(candidates As %DynamicArray, mappingId As %String) As %DynamicObject [ Private ]
{
	If '$IsObject(candidates) || (mappingId = "") Return ""
	Set it = candidates.%GetIterator()
	While it.%GetNext(, .m) {
		If m.mappingId = mappingId Return m
	}
	Return ""
}

ClassMethod Fail(code As %String, message As %String) As SignalNoir.Core.Result [ Private ]
{
	Return ##class(SignalNoir.Core.Result).Error(code, message)
}

}
