Class SignalNoir.Tests.Core.Validator.TestPriorReceipt Extends %UnitTest.TestCase
{

Parameter INPUTS = "SignalNoir.Tests.Core.Validator.Inputs";

/// 004 T038 - US7: a Proposal that names a prior Receipt candidate (FR-028, PRD P9). The
/// canonical equivalence keys of the current Order and of the candidate's Order snapshot are
/// compared with Core.Canon, never by the ids the Proposal states. The verdict is
/// `prior_receipt_confirmed` only when nothing else is wrong and the keys are equal.
ClassMethod Validate(input) As SignalNoir.Core.Dto.ValidatorVerdict
{
	Return ##class(SignalNoir.Core.Validator).%New().Validate(input)
}

ClassMethod Outcome(input) As %String
{
	Set v = ..Validate(input)
	Set out = ""
	For i = 1 : 1 : v.reasons.Count() Set out = out _ $Select(out = "": "", 1: ",") _ v.reasons.GetAt(i)
	Return v.verdict _ " " _ out
}

/// The current Order, written the way an Origin may write it
ClassMethod Current() As %DynamicObject
{
	Return {"orderId": "ORD-1", "patient": {"patientId": "SYN-PAT-0107", "name": "Ana Souza", "birthDate": "1980-01-02"}, "exams": [{"code": "GLIC-J"}, {"code": "TSH"}], "specimen": {"specimenId": "SP-1", "collectedAt": "2026-10-23T10:00:00Z", "type": "plasma"}}
}

/// The Order of the prior Receipt: the same one, with the spelling of another system
ClassMethod Prior() As %DynamicObject
{
	Return {"orderId": "ORD-9", "patient": {"patientId": "SYN-PAT-0107", "name": "Ana Souza"}, "exams": [{"code": "tsh"}, {"code": " glic-j "}], "specimen": {"specimenId": "SP-1", "collectedAt": "2026-10-23T07:00:00-03:00"}}
}

/// An input with a candidate (REQUEST_REVIEW by default, as in the fixture of PRD P9)
ClassMethod InputOf(prior, action As %String = "REQUEST_REVIEW", params As %DynamicObject = "") As SignalNoir.Core.Dto.ValidationInput
{
	Set input = $ClassMethod(..#INPUTS, "Input", $ClassMethod(..#INPUTS, "Proposal", action, params), "", ..Current())
	Set input.proposal.priorReceiptCandidate = {"receiptId": "RCP-88120", "orderId": "ORD-9"}
	Set input.priorReceiptOrder = prior
	Return input
}

Method TestEqualCanonicalKeysConfirmThePriorReceipt()
{
	Set input = ..InputOf(..Prior())
	Set v = ..Validate(input)
	Do $$$AssertEquals(..Outcome(input), "prior_receipt_confirmed EQUIVALENCE_KEY_MATCH", "AS1: confirmed, with that one reason")
	Do $$$AssertTrue('v.requiresApproval, "AS1: no Approval is required")
	Do $$$AssertEquals(v.ToJson().%ToJSON(), ..Validate(..InputOf(..Prior())).ToJson().%ToJSON(), "the same question, the same answer")
}

Method TestTheKeyIsCanonicalNotTextual()
{
	Do $$$AssertEquals(..Outcome(..InputOf(..Current())), "prior_receipt_confirmed EQUIVALENCE_KEY_MATCH", "the very same Order")
	Set prior = ..Prior()
	Set prior.exams = [{"code": "GLIC-J"}, {"code": "TSH"}, {"code": "glic-j"}]
	Do $$$AssertEquals(..Outcome(..InputOf(prior)), "prior_receipt_confirmed EQUIVALENCE_KEY_MATCH", "a repeated code counts once")
	Set prior = ..Prior()
	Set prior.specimen.collectedAt = "2026-10-23 10:00:00"
	Do $$$AssertEquals(..Outcome(..InputOf(prior)), "prior_receipt_confirmed EQUIVALENCE_KEY_MATCH", "no zone means UTC")
	Set prior.specimen.collectedAt = "2026-10-23T10:00:00.750Z"
	Do $$$AssertEquals(..Outcome(..InputOf(prior)), "prior_receipt_confirmed EQUIVALENCE_KEY_MATCH", "fractions of a second are dropped")
	Set prior = ..Prior()
	Set prior.patient.patientId = "  SYN-PAT-0107 "
	Do $$$AssertEquals(..Outcome(..InputOf(prior)), "prior_receipt_confirmed EQUIVALENCE_KEY_MATCH", "spaces around the patient id")
	Set prior = ..Prior()
	Set prior.patient.name = "Another Name"
	Set prior.orderId = "ORD-777"
	Do $$$AssertEquals(..Outcome(..InputOf(prior)), "prior_receipt_confirmed EQUIVALENCE_KEY_MATCH", "name and order id are not part of the key")
}

Method TestOneDifferentKeyFieldIsAMismatch()
{
	Set prior = ..Prior()
	Set prior.patient.patientId = "SYN-PAT-0108"
	Do $$$AssertEquals(..Outcome(..InputOf(prior)), "review EQUIVALENCE_KEY_MISMATCH", "AS2: another patient")
	Set prior = ..Prior()
	Set prior.exams = [{"code": "TSH"}]
	Do $$$AssertEquals(..Outcome(..InputOf(prior)), "review EQUIVALENCE_KEY_MISMATCH", "AS2: fewer exams")
	Set prior = ..Prior()
	Set prior.exams = [{"code": "TSH"}, {"code": "GLIC-S"}]
	Do $$$AssertEquals(..Outcome(..InputOf(prior)), "review EQUIVALENCE_KEY_MISMATCH", "AS2: another exam")
	Set prior = ..Prior()
	Set prior.specimen.collectedAt = "2026-10-23T10:00:01Z"
	Do $$$AssertEquals(..Outcome(..InputOf(prior)), "review EQUIVALENCE_KEY_MISMATCH", "AS2: a second later")
	Set prior = ..Prior()
	Set prior.specimen.specimenId = "SP-2"
	Do $$$AssertEquals(..Outcome(..InputOf(prior)), "review EQUIVALENCE_KEY_MISMATCH", "AS2: another specimen")
	Do $$$AssertTrue('..Validate(..InputOf(prior)).requiresApproval, "a REQUEST_REVIEW still needs no Approval")
}

Method TestNothingIsConfirmedByInference()
{
	Do $$$AssertEquals(..Outcome(..InputOf("")), "review EQUIVALENCE_KEY_MISMATCH", "a candidate whose Order snapshot is not given")
	Do $$$AssertEquals(..Outcome(..InputOf({})), "review EQUIVALENCE_KEY_MISMATCH", "an empty snapshot")
	Set prior = ..Prior()
	Set prior.specimen.collectedAt = "yesterday"
	Do $$$AssertEquals(..Outcome(..InputOf(prior)), "review EQUIVALENCE_KEY_MISMATCH", "a collection time that cannot be read")
	Set input = ..InputOf(..Prior())
	Set input.order = {}
	Do $$$AssertEquals(..Outcome(input), "review EQUIVALENCE_KEY_MISMATCH", "two Orders that both have no key are not equal")
	Set input.priorReceiptOrder = {}
	Do $$$AssertEquals(..Outcome(input), "review EQUIVALENCE_KEY_MISMATCH", "an empty key never equals an empty key")
}

Method TestAnAmbiguousIdentityIsNeverConfirmed()
{
	Set input = ..InputOf(..Prior())
	Do input.evidence.Insert($ClassMethod(..#INPUTS, "CollidingEvidence", ..Current()))
	Do $$$AssertEquals(..Outcome(input), "review IDENTITY_AMBIGUOUS_NO_AUTOMATIC_ACTION", "AS3: equal keys, ambiguous identity")
	Set prior = ..Prior()
	Set prior.specimen.specimenId = "SP-2"
	Set input.priorReceiptOrder = prior
	Do $$$AssertEquals(..Outcome(input), "review IDENTITY_AMBIGUOUS_NO_AUTOMATIC_ACTION,EQUIVALENCE_KEY_MISMATCH", "both reasons, in pipeline order")
}

Method TestWithoutACandidateNothingChanges()
{
	Set input = ..InputOf(..Prior())
	Set input.proposal.priorReceiptCandidate = ""
	Do $$$AssertEquals(..Outcome(input), "accepted REVIEW_ALWAYS_ACCEPTED", "no candidate: an ordinary REQUEST_REVIEW")
	Set input.proposal.priorReceiptCandidate = {}
	Do $$$AssertEquals(..Outcome(input), "accepted REVIEW_ALWAYS_ACCEPTED", "an empty candidate names nothing")
	Set input.proposal.priorReceiptCandidate = {"receiptId": "", "orderId": ""}
	Do $$$AssertEquals(..Outcome(input), "accepted REVIEW_ALWAYS_ACCEPTED", "empty ids name nothing")
}

Method TestACandidateOnAnEffectfulActionIsConfirmedOnlyWhenNothingElseIsWrong()
{
	Set input = ..InputOf(..Prior(), "RETRY")
	Set v = ..Validate(input)
	Do $$$AssertEquals(..Outcome(input), "prior_receipt_confirmed EQUIVALENCE_KEY_MATCH", "a RETRY whose Order was already delivered: confirmed")
	Do $$$AssertTrue('v.requiresApproval, "the confirmation needs no Approval, whatever the Action (FR-011)")

	Set input.attemptCount = 3
	Do $$$AssertEquals(..Outcome(input), "blocked RETRY_BUDGET_EXHAUSTED", "a block wins over the confirmation")
	Set input.attemptCount = 0
	Set input.proposal.confidence = "LOW"
	Do $$$AssertEquals(..Outcome(input), "review CONFIDENCE_LOW", "so does a review")
	Set input.proposal.confidence = "HIGH"
	Set prior = ..Prior()
	Set prior.patient.patientId = "SYN-PAT-0999"
	Set input.priorReceiptOrder = prior
	Do $$$AssertEquals(..Outcome(input), "review EQUIVALENCE_KEY_MISMATCH", "a different key: review, with its reason")
	Do $$$AssertTrue(..Validate(input).requiresApproval, "and the Action's own requiresApproval")

	Set mapping = ..InputOf(..Prior(), "APPLY_APPROVED_MAPPING", $ClassMethod(..#INPUTS, "MappingParams"))
	Do $$$AssertEquals(..Outcome(mapping), "prior_receipt_confirmed EQUIVALENCE_KEY_MATCH", "an APPLY_APPROVED_MAPPING is confirmed the same way")
	Do $$$AssertTrue('..Validate(mapping).requiresApproval, "prior_receipt_confirmed never requires Approval")
}

Method TestMissingEvidenceStillSendsAConfirmedCandidateToReview()
{
	Set input = ..InputOf(..Prior(), "RETRY")
	Do input.evidence.Clear()
	Do $$$AssertEquals(..Outcome(input), "review EVIDENCE_MISSING_POLICY,EVIDENCE_MISSING_ATTEMPT_HISTORY,EVIDENCE_MISSING_PARTNER_HEALTH", "no Evidence: review, as for any RETRY")
}

}
