Class SignalNoir.Core.Reasons Extends %RegisteredObject
{

/// The closed vocabulary of Validator reason codes (004, contracts/reason-codes.md), in
/// pipeline order: a verdict lists its reasons in this order. Pure. Kinds: pass, block,
/// review (a verdict of review), refuse (returned by Admit, never in a verdict).
Parameter CODES = "REFERENCE_DATA_UNAVAILABLE,ACTION_IN_CATALOG,ACTION_NOT_IN_CATALOG,SCOPE_INVALID,PARAMS_VALID,PARAMS_INVALID,REVIEW_ALWAYS_ACCEPTED,PRECONDITION_UNKNOWN,MAPPING_CONDITION_MATCHES,MAPPING_NOT_FOUND,MAPPING_SOURCE_CODE_ABSENT,MAPPING_CONDITION_MISMATCH,RETRY_BUDGET_AVAILABLE,RETRY_BUDGET_EXHAUSTED,PRECONDITION_FAILED_PARTNER_HEALTHY_WINDOW,PRECONDITION_FAILED_ORDER_ACTIVE_AT_ORIGIN,PRECONDITION_FAILED_APPROVAL_VALID,PRECONDITION_FAILED_POLICY_VERSION_UNCHANGED,PRECONDITION_FAILED_MAPPING_VERSION_UNCHANGED,IDENTITY_AMBIGUOUS_NO_AUTOMATIC_ACTION,REQUIRED_EVIDENCE_PRESENT,EVIDENCE_MISSING_POLICY,EVIDENCE_MISSING_ATTEMPT_HISTORY,EVIDENCE_MISSING_PARTNER_HEALTH,EVIDENCE_MISSING_MAPPING,EVIDENCE_MISSING_ORDER_FIELD,EVIDENCE_MISSING_HEALTH_OR_WINDOW,CONFIDENCE_LOW,EQUIVALENCE_KEY_MATCH,EQUIVALENCE_KEY_MISMATCH,ACTOR_BENCHMARK_OUTSIDE_RUN,ACTOR_NOT_ALLOWED_TO_APPROVE";

/// The codes as a $List, in pipeline order
ClassMethod All() As %List
{
	Return $ListFromString(..#CODES)
}

ClassMethod IsReason(code As %String) As %Boolean
{
	Return (code '= "") && ($ListFind(..All(), code) > 0)
}

/// 1-based position in the pipeline order, 0 for anything else
ClassMethod Order(code As %String) As %Integer
{
	Return $ListFind(..All(), code)
}

/// pass, block, review or refuse; "" for anything else
ClassMethod Kind(code As %String) As %String
{
	If '..IsReason(code) Return ""
	If $Extract(code, 1, 6) = "ACTOR_" Return "refuse"
	Return $Case(code,
		"ACTION_IN_CATALOG": "pass", "PARAMS_VALID": "pass", "REVIEW_ALWAYS_ACCEPTED": "pass",
		"MAPPING_CONDITION_MATCHES": "pass", "RETRY_BUDGET_AVAILABLE": "pass",
		"REQUIRED_EVIDENCE_PRESENT": "pass", "EQUIVALENCE_KEY_MATCH": "pass",
		"IDENTITY_AMBIGUOUS_NO_AUTOMATIC_ACTION": "review", "CONFIDENCE_LOW": "review",
		"EQUIVALENCE_KEY_MISMATCH": "review",
		: $Select($Extract(code, 1, 17) = "EVIDENCE_MISSING_": "review", 1: "block"))
}

/// The English text shown to operators; "" for anything else
ClassMethod Text(code As %String) As %String
{
	Return $Case(code,
		"REFERENCE_DATA_UNAVAILABLE": "No policy or mapping version is in force.",
		"ACTION_IN_CATALOG": "The action is in the closed catalog.",
		"ACTION_NOT_IN_CATALOG": "The action is not in the closed catalog.",
		"SCOPE_INVALID": "Only single-case scope is allowed.",
		"PARAMS_VALID": "The parameters match the action.",
		"PARAMS_INVALID": "The parameters do not match the action.",
		"REVIEW_ALWAYS_ACCEPTED": "A review request is always accepted.",
		"PRECONDITION_UNKNOWN": "A declared precondition is not in the closed vocabulary.",
		"MAPPING_CONDITION_MATCHES": "The approved mapping applies to this order.",
		"MAPPING_NOT_FOUND": "No approved mapping with this id and version is in force.",
		"MAPPING_SOURCE_CODE_ABSENT": "The order does not contain the mapping's source code.",
		"MAPPING_CONDITION_MISMATCH": "The mapping conditions do not match the order.",
		"RETRY_BUDGET_AVAILABLE": "The attempt policy allows another attempt.",
		"RETRY_BUDGET_EXHAUSTED": "The attempt policy's maximum attempts was reached.",
		"PRECONDITION_FAILED_PARTNER_HEALTHY_WINDOW": "The partner is not healthy within the policy window.",
		"PRECONDITION_FAILED_ORDER_ACTIVE_AT_ORIGIN": "The order is no longer active at the origin.",
		"PRECONDITION_FAILED_APPROVAL_VALID": "The approval is missing, expired or for another proposal.",
		"PRECONDITION_FAILED_POLICY_VERSION_UNCHANGED": "The policy version changed since the proposal.",
		"PRECONDITION_FAILED_MAPPING_VERSION_UNCHANGED": "The mapping version changed or the mapping is gone.",
		"IDENTITY_AMBIGUOUS_NO_AUTOMATIC_ACTION": "The order identity is ambiguous; no automatic action.",
		"REQUIRED_EVIDENCE_PRESENT": "The minimum evidence for the action is present.",
		"EVIDENCE_MISSING_POLICY": "The required policy evidence is missing.",
		"EVIDENCE_MISSING_ATTEMPT_HISTORY": "The attempt history evidence is missing.",
		"EVIDENCE_MISSING_PARTNER_HEALTH": "Recent partner health evidence is missing.",
		"EVIDENCE_MISSING_MAPPING": "Evidence of the approved mapping is missing.",
		"EVIDENCE_MISSING_ORDER_FIELD": "Evidence of the order field the mapping depends on is missing.",
		"EVIDENCE_MISSING_HEALTH_OR_WINDOW": "Neither partner health nor a maintenance window is in evidence.",
		"CONFIDENCE_LOW": "The proposal's confidence is low.",
		"EQUIVALENCE_KEY_MATCH": "The prior receipt is for the same order.",
		"EQUIVALENCE_KEY_MISMATCH": "The prior receipt's order differs from this order.",
		"ACTOR_BENCHMARK_OUTSIDE_RUN": "The benchmark actor can approve only inside a benchmark run.",
		"ACTOR_NOT_ALLOWED_TO_APPROVE": "This actor cannot approve.",
		: "")
}

}
