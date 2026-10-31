Class SignalNoir.Core.Validator Extends SignalNoir.Core.Port.Validator
{

/// Deterministic, origin-blind (Constitution III), no I/O: the verdict is a function of the
/// ValidationInput alone. Pipeline frame of 004 research D3. Steps 1-4 stop on the first failure
/// (the later steps need a well-formed Proposal); steps 5-12 all run. Every failed check is in
/// the reasons, in step order; any block makes the verdict `blocked`, otherwise any review makes
/// it `review`, otherwise it is `accepted` with the pass codes of the steps that apply.
ClassMethod Preconditions() As %ListOfDataTypes
{
	Return ##class(SignalNoir.Core.Vocab).Preconditions()
}

Method Validate(input As SignalNoir.Core.Dto.ValidationInput) As SignalNoir.Core.Dto.ValidatorVerdict
{
	Set verdict = ##class(SignalNoir.Core.Dto.ValidatorVerdict).%New()
	Set proposal = "", reference = ""
	If $IsObject(input) {
		Set proposal = input.proposal, reference = input.reference
		Set verdict.at = input.now
	}
	Set action = $Select($IsObject(proposal): proposal.action, 1: "")
	Set verdict.requiresApproval = ##class(SignalNoir.Core.ActionCatalog).RequiresApproval(action)

	; 1 reference data in force
	If '..HasReference(reference) Return ..Block(verdict, "REFERENCE_DATA_UNAVAILABLE")
	Set verdict.versions = {"policy": (reference.policyVersion), "mapping": (reference.mappingVersion)}
	; 2 Action in the closed catalog
	If '##class(SignalNoir.Core.Vocab).IsAction(action) Return ..Block(verdict, "ACTION_NOT_IN_CATALOG")
	; 3 scope
	If proposal.scope '= "single_case" Return ..Block(verdict, "SCOPE_INVALID")
	; 4 parameters, confidence and the versions the Proposal relied on
	If '..ParamsValid(proposal) Return ..Block(verdict, "PARAMS_INVALID")

	; REQUEST_REVIEW is always accepted; an ambiguous identity is only reported with it
	If action = "REQUEST_REVIEW" {
		Set verdict.verdict = "accepted"
		Do verdict.reasons.Insert("REVIEW_ALWAYS_ACCEPTED")
		If ..IdentityAmbiguous(input) Do verdict.reasons.Insert("IDENTITY_AMBIGUOUS_NO_AUTOMATIC_ACTION")
		Return verdict
	}

	Set fails = "", passes = $ListBuild("ACTION_IN_CATALOG"), item = ""
	If action = "APPLY_APPROVED_MAPPING" {
		Set passes = passes _ $ListBuild("PARAMS_VALID")
		; 6 the Mapping exists, its source code is in the Order, its conditions match
		Set fail = ..MappingCheck(input, .item, .pass)
		If fail '= "" Set fails = fails _ $ListBuild(fail)
		If pass '= "" Set passes = passes _ $ListBuild(pass)
	}
	; 7 retry budget
	If action = "RETRY" {
		If ..BudgetExhausted(input) {
			Set fails = fails _ $ListBuild("RETRY_BUDGET_EXHAUSTED")
		} Else {
			Set passes = passes _ $ListBuild("RETRY_BUDGET_AVAILABLE")
		}
	}
	; 9 identity
	If ..IdentityAmbiguous(input) Set fails = fails _ $ListBuild("IDENTITY_AMBIGUOUS_NO_AUTOMATIC_ACTION")
	; 10 minimum Evidence
	Set missing = ..MissingEvidence(input, item)
	If missing = "" {
		Set passes = passes _ $ListBuild("REQUIRED_EVIDENCE_PRESENT")
	} Else {
		Set fails = fails _ missing
	}
	; 11 confidence
	If proposal.confidence = "LOW" Set fails = fails _ $ListBuild("CONFIDENCE_LOW")

	Set codes = passes, verdict.verdict = "accepted"
	If fails '= "" {
		Set codes = fails, verdict.verdict = "review"
		For i = 1 : 1 : $ListLength(fails) {
			If ##class(SignalNoir.Core.Reasons).Kind($List(fails, i)) = "block" Set verdict.verdict = "blocked"
		}
	}
	For i = 1 : 1 : $ListLength(codes) Do verdict.reasons.Insert($List(codes, i))
	Return verdict
}

/// Whether an Approval by `actor` is admissible within `run` (FR-012). `benchmark` approves only
/// inside a BenchmarkRun (labelled automatic); an operator always (labelled human); anyone else
/// never. The run is read as given: a run with no run id, or with `inRun` that is not a boolean
/// true, is not a run.
Method Admit(actor As %String, run As %DynamicObject) As SignalNoir.Core.Dto.Admission
{
	Set admission = ##class(SignalNoir.Core.Dto.Admission).%New()
	If actor = "benchmark" {
		If ..InsideRun(run) {
			Set admission.admissible = 1, admission.label = "automatic"
		} Else {
			Set admission.reason = "ACTOR_BENCHMARK_OUTSIDE_RUN"
		}
	} ElseIf ..IsOperator(actor) {
		Set admission.admissible = 1, admission.label = "human"
	} Else {
		Set admission.reason = "ACTOR_NOT_ALLOWED_TO_APPROVE"
	}
	Return admission
}

Method InsideRun(run) As %Boolean [ Private ]
{
	If '$IsObject(run) || 'run.%IsA("%Library.DynamicObject") Return 0
	Return (run.%GetTypeOf("inRun") = "boolean") && run.inRun && (run.%GetTypeOf("runId") = "string") && (run.runId '= "")
}

/// operator:<name>, as the contract's Actor pattern: 1 to 64 characters, no colon
Method IsOperator(actor As %String) As %Boolean [ Private ]
{
	If $Extract(actor, 1, 9) '= "operator:" Return 0
	Set name = $Extract(actor, 10, *)
	Return ($Length(name) >= 1) && ($Length(name) <= 64) && (name '[ ":")
}

/// A blocked verdict carries only the code of the step that failed
Method Block(verdict As SignalNoir.Core.Dto.ValidatorVerdict, code As %String) As SignalNoir.Core.Dto.ValidatorVerdict [ Private ]
{
	Set verdict.verdict = "blocked"
	Do verdict.reasons.Clear()
	Do verdict.reasons.Insert(code)
	Return verdict
}

Method HasReference(reference) As %Boolean [ Private ]
{
	Return $IsObject(reference) && (reference.policyVersion '= "") && (reference.mappingVersion '= "")
}

/// Step 4: a valid confidence, both versions named, and exactly the parameters the Action
/// declares, all strings; the mandatory ones non-empty
Method ParamsValid(proposal As SignalNoir.Core.Dto.Proposal) As %Boolean [ Private ]
{
	If $ListFind($ListBuild("HIGH", "MEDIUM", "LOW"), proposal.confidence) = 0 Return 0
	Set versions = proposal.versions
	If '$IsObject(versions) Return 0
	For key = "policy", "mapping" {
		If (versions.%GetTypeOf(key) '= "string") || (versions.%Get(key) = "") Return 0
	}
	Set action = proposal.action, params = proposal.params
	Set allowed = ##class(SignalNoir.Core.ActionCatalog).AllowedParams(action)
	If $IsObject(params) {
		Set iterator = params.%GetIterator()
		While iterator.%GetNext(.key, .value) {
			If (allowed = "") || ($ListFind(allowed, key) = 0) || (params.%GetTypeOf(key) '= "string") Return 0
		}
	}
	If action = "APPLY_APPROVED_MAPPING" {
		For key = "mappingId", "mappingVersion" {
			If '$IsObject(params) || (params.%Get(key) = "") Return 0
		}
	}
	Return 1
}

/// Step 6. Returns the failing code ("" when the Mapping applies); item is the Mapping of the
/// snapshot when it exists; pass is MAPPING_CONDITION_MATCHES when the Mapping has conditions
/// and they match.
Method MappingCheck(input As SignalNoir.Core.Dto.ValidationInput, Output item, Output pass As %String) As %String [ Private ]
{
	Set pass = "", item = ""
	Set params = input.proposal.params
	Set item = ..FindMapping(input.reference, params.mappingId, params.mappingVersion)
	If '$IsObject(item) Return "MAPPING_NOT_FOUND"
	If '##class(SignalNoir.Core.Conditions).HasSourceCode(input.order, item.sourceCode) Return "MAPPING_SOURCE_CODE_ABSENT"
	If '##class(SignalNoir.Core.Conditions).Matches(item.conditions, input.order, input.reference.synonyms) Return "MAPPING_CONDITION_MISMATCH"
	If ##class(SignalNoir.Core.Conditions).Count(item.conditions) > 0 Set pass = "MAPPING_CONDITION_MATCHES"
	Return ""
}

/// The Mapping of the snapshot with exactly this id and version
Method FindMapping(reference As SignalNoir.Core.Dto.ReferenceData, mappingId As %String, mappingVersion As %String) As %DynamicObject [ Private ]
{
	Set each = reference.mappings.%GetIterator()
	While each.%GetNext(.index, .item) {
		If $IsObject(item) && (item.%Get("mappingId") = mappingId) && (item.%Get("mappingVersion") = mappingVersion) Return item
	}
	Return ""
}

/// Step 7: the attempts made have reached the policy's maximum. A snapshot without an attempt
/// policy has no budget to spend.
Method BudgetExhausted(input As SignalNoir.Core.Dto.ValidationInput) As %Boolean [ Private ]
{
	Set policies = input.reference.policies
	If '$IsObject(policies) || (policies.%GetTypeOf("attempt") '= "object") Return 1
	Set attempt = policies.attempt
	If attempt.%GetTypeOf("maxAttempts") '= "number" Return 1
	Return (+input.attemptCount >= attempt.maxAttempts)
}

/// Step 9: another patient record with the same name but a different identity, in this Case's
/// Evidence or against the Order. The one identity rule of the Core decides; no field of the
/// input can clear it. Evidence marked suspicious or obsolete still counts here: hiding a
/// collision is the unsafe direction. A result the rule cannot read is treated as ambiguous.
Method IdentityAmbiguous(input As SignalNoir.Core.Dto.ValidationInput) As %Boolean [ Private ]
{
	Set recorded = ##class(%ListOfObjects).%New()
	For i = 1 : 1 : input.evidence.Count() {
		Set ev = input.evidence.GetAt(i)
		If $IsObject(ev) && (ev.caseId = input.proposal.caseId) Do recorded.Insert(ev)
	}
	Try {
		Set collisions = ##class(SignalNoir.Core.Identity).Collisions(recorded, input.order)
		Return (collisions.%Size() > 0)
	} Catch {
		Return 1
	}
}

/// Step 10: the codes of the mandatory Evidence the Case does not have, in the catalog's
/// order. Only Evidence that counts is looked at (see CountsAsEvidence).
Method MissingEvidence(input As SignalNoir.Core.Dto.ValidationInput, item) As %List [ Private ]
{
	Set action = input.proposal.action, missing = ""
	If action = "RETRY" {
		If '..HasItem(input, "tool.policies", "attempt") Set missing = missing _ $ListBuild("EVIDENCE_MISSING_POLICY")
		If '..HasItem(input, "tool.partner_failure_history") Set missing = missing _ $ListBuild("EVIDENCE_MISSING_ATTEMPT_HISTORY")
		If '..HasItem(input, "tool.partner_health") Set missing = missing _ $ListBuild("EVIDENCE_MISSING_PARTNER_HEALTH")
	} ElseIf action = "APPLY_APPROVED_MAPPING" {
		If '..HasItem(input, "tool.policies", "substitution") Set missing = missing _ $ListBuild("EVIDENCE_MISSING_POLICY")
		; the Mapping and its Order field are only asked of a Mapping that exists
		If $IsObject(item) {
			If '..HasMappingItem(input) Set missing = missing _ $ListBuild("EVIDENCE_MISSING_MAPPING")
			If '..OrderHasConditionFields(input, item) Set missing = missing _ $ListBuild("EVIDENCE_MISSING_ORDER_FIELD")
		}
	} ElseIf action = "HOLD" {
		If '..HasItem(input, "tool.partner_health") && '..HasItem(input, "tool.policies", "maintenanceWindows") Set missing = $ListBuild("EVIDENCE_MISSING_HEALTH_OR_WINDOW")
	}
	Return missing
}

/// Evidence counts toward the minimum only if it is a fact of this Case, not obsoleted, not
/// suspicious. An absence never counts (Principle VII).
Method CountsAsEvidence(ev, caseId As %String) As %Boolean [ Private ]
{
	Return $IsObject(ev) && (ev.caseId = caseId) && (ev.kind = "fact") && (ev.obsoletedBy = "") && ('ev.suspicious)
}

/// True when a counted Evidence comes from `source` and, when `key` is given, its result
/// defines that key
Method HasItem(input As SignalNoir.Core.Dto.ValidationInput, source As %String, key As %String = "") As %Boolean [ Private ]
{
	For i = 1 : 1 : input.evidence.Count() {
		Set ev = input.evidence.GetAt(i)
		If '..CountsAsEvidence(ev, input.proposal.caseId) || (ev.source '= source) Continue
		If key = "" Return 1
		If $IsObject(ev.result) && ev.result.%IsA("%Library.DynamicObject") {
			Set type = ev.result.%GetTypeOf(key)
			If (type '= "unassigned") && (type '= "null") Return 1
		}
	}
	Return 0
}

/// A counted tool.mapping_catalog result that lists this Proposal's id and version
Method HasMappingItem(input As SignalNoir.Core.Dto.ValidationInput) As %Boolean [ Private ]
{
	Set params = input.proposal.params
	For i = 1 : 1 : input.evidence.Count() {
		Set ev = input.evidence.GetAt(i)
		If '..CountsAsEvidence(ev, input.proposal.caseId) || (ev.source '= "tool.mapping_catalog") Continue
		If '$IsObject(ev.result) || 'ev.result.%IsA("%Library.DynamicObject") || (ev.result.%GetTypeOf("items") '= "array") Continue
		Set each = ev.result.items.%GetIterator()
		While each.%GetNext(.index, .listed) {
			If $IsObject(listed) && listed.%IsA("%Library.DynamicObject") && (listed.%Get("mappingId") = params.mappingId) && (listed.%Get("mappingVersion") = params.mappingVersion) Return 1
		}
	}
	Return 0
}

/// The Order the Case holds has the field of every condition of the Mapping (no Tool call)
Method OrderHasConditionFields(input As SignalNoir.Core.Dto.ValidationInput, item) As %Boolean [ Private ]
{
	If item.%GetTypeOf("conditions") '= "object" Return 1
	Set each = item.conditions.%GetIterator()
	While each.%GetNext(.field, .expected) {
		If ##class(SignalNoir.Core.Conditions).OrderValue(input.order, field) = "" Return 0
	}
	Return 1
}

}
