Class SignalNoir.Core.Validator Extends SignalNoir.Core.Port.Validator
{

/// Deterministic, origin-blind (Constitution III), no I/O: the verdict is a function of the
/// ValidationInput alone. Pipeline frame of 004 research D3. Steps 1-4 stop on the first failure
/// (the later steps need a well-formed Proposal); the steps that follow are added by the stories
/// that need them.
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

	Set verdict.verdict = "accepted"
	If action = "REQUEST_REVIEW" {
		Do verdict.reasons.Insert("REVIEW_ALWAYS_ACCEPTED")
		Return verdict
	}
	Do verdict.reasons.Insert("ACTION_IN_CATALOG")
	If action = "APPLY_APPROVED_MAPPING" Do verdict.reasons.Insert("PARAMS_VALID")
	Return verdict
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

}
