Class SignalNoir.Application.ResolutionValidator Extends %RegisteredObject
{

/// The one place a Proposal reaches the Validator (feature 009; 006's
/// routing joins at G2). It calls the injected Validator port and returns
/// the contract ValidatorVerdict. Today the port is seam v1 (Core.Validator:
/// valid / invalid + failedPreconditions); when 004's v2 lands, only this
/// method changes (coordination-004-007.md).
ClassMethod Verdict(validator As SignalNoir.Core.Port.Validator, proposal As SignalNoir.Core.Dto.Proposal, now As %String) As %DynamicObject
{
	Set v = validator.Validate(proposal)
	Set accepted = (v.verdict = "valid") || (v.verdict = "accepted")
	Set reasons = []
	If accepted {
		Do reasons.%Push("ACTION_IN_CATALOG")
		Do reasons.%Push("PARAMS_VALID")
	} Else {
		Set codes = v.failedPreconditions
		If $IsObject(codes) {
			For i = 1 : 1 : codes.Count() If codes.GetAt(i) '= "" Do reasons.%Push(codes.GetAt(i))
		} ElseIf $ListValid(codes) && (codes '= "") {
			For i = 1 : 1 : $ListLength(codes) If $ListGet(codes, i) '= "" Do reasons.%Push($ListGet(codes, i))
		}
		If reasons.%Size() = 0 Do reasons.%Push($Select(##class(SignalNoir.Core.Vocab).IsAction(proposal.action): "VALIDATOR_REFUSED", 1: "ACTION_NOT_IN_CATALOG"))
	}
	Set out = {"verdict": ($Select(accepted: "accepted", 1: "blocked")), "reasons": (reasons), "at": (now)}
	Do out.%Set("requiresApproval", ##class(SignalNoir.Core.ActionCatalog).RequiresApproval(proposal.action), "boolean")
	If 'accepted && (v.reason '= "") Do out.%Set("message", v.reason)
	Return out
}

}
