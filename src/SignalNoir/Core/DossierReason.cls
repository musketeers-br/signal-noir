Class SignalNoir.Core.DossierReason Extends %RegisteredObject
{

/// Maps the review reason recorded on the Case to the contract's closed
/// Dossier reason, with its explanation and the suggested next human step
/// (spec 009 FR-002). Pure.
ClassMethod From(reviewReason As %String) As %String
{
	Set r = $ZConvert(##class(SignalNoir.Core.Canon).Trim(reviewReason), "L")
	If $Extract(r, 1, 20) = "provider unavailable" Return "provider_unavailable"
	If r = "invalid proposer response" Return "invalid_agent_response"
	If $Extract(r, 1, 29) = "investigation budget exceeded" Return "budget_exceeded"
	If r = "investigation interrupted" Return "investigation_interrupted"
	If r = "second rejection" Return "second_denial"
	If $Extract(r, 1, 17) = "validator blocked" Return "validator_blocked"
	Return "review_requested"
}

/// Why automation stopped, quoting the recorded reason
ClassMethod Text(reason As %String, reviewReason As %String) As %String
{
	Set why = $Case(reason,
		"provider_unavailable": "The AI provider could not be used, so automation stopped before any proposal.",
		"invalid_agent_response": "The proposer's answer could not be turned into a valid proposal, so it was discarded.",
		"budget_exceeded": "The investigation reached its server-enforced budget before a proposal.",
		"investigation_interrupted": "The investigation was interrupted by a restart before it finished.",
		"second_denial": "The proposal was denied twice; the system does not try a third time on its own.",
		"validator_blocked": "The validator blocked the proposal.",
		"ambiguous_identity": "More than one synthetic patient record matches this order. The system never acts automatically on ambiguous identity.",
		: "Automation stopped and asked for a human decision.")
	Return why _ " Recorded reason: " _ reviewReason _ "."
}

ClassMethod NextStep(reason As %String) As %String
{
	Return $Case(reason,
		"provider_unavailable": "Check the provider configuration. To resolve now, choose a catalog action the evidence supports, or cancel the case.",
		"invalid_agent_response": "Read the evidence collected so far and choose a catalog action it supports, or cancel the case.",
		"budget_exceeded": "Read the evidence collected before the limit and choose a catalog action, or cancel the case.",
		"investigation_interrupted": "Read the evidence collected before the restart and choose a catalog action, or cancel the case.",
		"second_denial": "Decide with the denial reasons in view: choose a different catalog action, or cancel the case.",
		"validator_blocked": "Check the validator's reason codes, then choose another catalog action or cancel the case.",
		"ambiguous_identity": "Confirm the patient with the origin unit, then choose a catalog action or cancel the case.",
		: "Choose a catalog action below, or cancel the case.")
}

}
