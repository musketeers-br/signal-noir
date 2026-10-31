Class SignalNoir.Tests.Core.Validator.TestFixtureVerdicts Extends %UnitTest.TestCase
{

Parameter DIR = "contracts/fixtures/";

Parameter INPUTS = "SignalNoir.Tests.Core.Validator.Inputs";

/// 004 T041 - the verdicts recorded in contracts/fixtures/*.json against the rules of 004.
/// For each, the ValidationInput is rebuilt from the fixture's Case: the Proposal as it is, the
/// Order, the Evidence that existed when the Proposal was made. The fixtures come from the
/// prototype mock and write Evidence in an older shape (patient.id, catalogVersion, orders and
/// receipts); the translation below only changes the shape to the one of
/// contracts/validation-input.md, never what was or was not observed. The reference data is the
/// Mapping catalog the Case's own Evidence shows, else the 2026.10.1 set.
/// Twelve of the thirteen verdicts agree. resolution.201.action.json is the known divergence
/// (research D3): an Operator's conditional Mapping with its Evidence in, whose reasons lack
/// MAPPING_CONDITION_MATCHES and REQUIRED_EVIDENCE_PRESENT. Principle III forbids a lighter rule
/// for the Operator, so the fixture is wrong (the mock is to be fixed and the fixtures
/// regenerated). This test then fails on purpose once the fixture is regenerated: flip it.
ClassMethod Load(file As %String) As %DynamicObject
{
	Set stream = ##class(%Stream.FileCharacter).%New()
	Do stream.LinkToFile(##class(SignalNoir.Tests.Core.Validator.Repo).Path(..#DIR _ file))
	Return {}.%FromJSON(stream)
}

/// The Order snapshot in the shape the Core reads
ClassMethod Snapshot(case As %DynamicObject) As %DynamicObject
{
	Set snap = {}.%FromJSON(case.order.snapshot.%ToJSON())
	If snap.patient.%GetTypeOf("id") = "string" Set snap.patient.patientId = snap.patient.id
	If snap.specimen.%GetTypeOf("id") = "string" Set snap.specimen.specimenId = snap.specimen.id
	If snap.%GetTypeOf("collectedAt") = "string" Set snap.specimen.collectedAt = snap.collectedAt
	Return snap
}

/// tool.receipts_and_orders_by_patient in the shape the Core reads: items with order snapshots
ClassMethod Receipts(result As %DynamicObject, patient As %DynamicObject) As %DynamicObject
{
	Set items = []
	If result.%GetTypeOf("receipts") = "array" {
		Set each = result.receipts.%GetIterator()
		While each.%GetNext(.i, .receipt) {
			Set snapshot = {"patient": (patient)}
			Set orders = result.orders.%GetIterator()
			While orders.%GetNext(.j, .order) {
				If order.orderId '= receipt.orderId Continue
				Set codes = []
				Set c = order.examCodes.%GetIterator()
				While c.%GetNext(.k, .code) {
					Do codes.%Push({"code": (code)})
				}
				Set snapshot = {"patient": (patient), "exams": (codes), "specimen": {"specimenId": (order.specimenId), "collectedAt": (order.collectedAt)}}
			}
			Do items.%Push({"receiptId": (receipt.receiptId), "orderId": (receipt.orderId), "orderSnapshot": (snapshot)})
		}
	}
	If result.%GetTypeOf("matches") = "array" {
		Set each = result.matches.%GetIterator()
		While each.%GetNext(.i, .match) {
			Do items.%Push({"receiptId": ("match-" _ i), "orderId": ("ORD-" _ i), "orderSnapshot": {"patient": {"patientId": (match.mrn), "name": (match.name), "birthDate": (match.birthDate)}}})
		}
	}
	Return {"items": (items)}
}

/// The Evidence of the Case as the Validator receives it for this Proposal: what was observed
/// by the time the Proposal was made, in the shapes of contracts/validation-input.md
ClassMethod Evidence(case As %DynamicObject, proposal As %DynamicObject, snapshot As %DynamicObject) As %ListOfObjects
{
	Set list = ##class(%ListOfObjects).%New()
	Kill kept
	Set each = case.evidence.%GetIterator()
	While each.%GetNext(.i, .e) {
		If e.observedAt ] proposal.createdAt Continue
		Set kept(e.evidenceId) = 1
	}
	Set each = case.evidence.%GetIterator()
	While each.%GetNext(.i, .e) {
		If '$Data(kept(e.evidenceId)) Continue
		Set ev = ##class(SignalNoir.Core.Dto.Evidence).%New()
		Set ev.evidenceId = e.evidenceId, ev.caseId = case.caseId, ev.kind = "fact", ev.source = e.source, ev.observedAt = e.observedAt
		Set ev.suspicious = +e.suspicious
		If (e.obsoletedBy '= "") && $Data(kept(e.obsoletedBy)) Set ev.obsoletedBy = e.obsoletedBy
		Set ev.result = e.result
		If e.source = "tool.policies" Set ev.result = $ClassMethod(..#INPUTS, "PoliciesResult")
		If e.source = "tool.mapping_catalog" Set ev.result = {"mappingVersion": (e.result.catalogVersion), "items": (e.result.mappings), "synonyms": ($ClassMethod(..#INPUTS, "Reference").synonyms)}
		If e.source = "tool.receipts_and_orders_by_patient" Set ev.result = ..Receipts(e.result, snapshot.patient)
		Do list.Insert(ev)
	}
	Return list
}

/// The reference data: the 2026.10.1 set, with the Mappings of the Case's current catalog Evidence
/// when it has one
ClassMethod Reference(evidence As %ListOfObjects) As SignalNoir.Core.Dto.ReferenceData
{
	Set reference = $ClassMethod(..#INPUTS, "Reference")
	For i = 1 : 1 : evidence.Count() {
		Set ev = evidence.GetAt(i)
		If (ev.source '= "tool.mapping_catalog") || (ev.obsoletedBy '= "") Continue
		Set reference.mappingVersion = ev.result.mappingVersion
		Set reference.mappings = ev.result.items
	}
	Return reference
}

ClassMethod ProposalOf(case As %DynamicObject, p As %DynamicObject) As SignalNoir.Core.Dto.Proposal
{
	Set proposal = ##class(SignalNoir.Core.Dto.Proposal).%New()
	Set proposal.proposalId = p.proposalId, proposal.caseId = case.caseId, proposal.origin = p.author, proposal.createdAt = p.createdAt
	Set proposal.action = p.action, proposal.params = p.params, proposal.scope = p.scope, proposal.confidence = p.confidence
	Set proposal.preconditions = p.preconditions
	Set proposal.versions = {"policy": (p.versions.policy), "mapping": (p.versions.mapping)}
	If p.%GetTypeOf("priorReceiptCandidate") = "object" Set proposal.priorReceiptCandidate = p.priorReceiptCandidate
	Return proposal
}

ClassMethod InputFor(case As %DynamicObject, p As %DynamicObject, at As %String) As SignalNoir.Core.Dto.ValidationInput
{
	Set proposal = ..ProposalOf(case, p)
	Set snapshot = ..Snapshot(case)
	Set evidence = ..Evidence(case, proposal, snapshot)
	Set input = ##class(SignalNoir.Core.Dto.ValidationInput).%New()
	Set input.proposal = proposal
	For i = 1 : 1 : evidence.Count() Do input.evidence.Insert(evidence.GetAt(i))
	Set input.order = snapshot
	Set input.priorReceiptOrder = ##class(SignalNoir.Application.ResolutionValidator).PriorReceiptOrder(evidence, proposal)
	Set input.attemptCount = 0
	Set input.run = {"inRun": false, "runId": null, "policyVersion": null, "mappingVersion": null}
	Set input.reference = ..Reference(evidence)
	Set input.now = at
	Return input
}

ClassMethod Outcome(verdict As SignalNoir.Core.Dto.ValidatorVerdict) As %String
{
	Set out = ""
	For i = 1 : 1 : verdict.reasons.Count() Set out = out _ $Select(out = "": "", 1: ",") _ verdict.reasons.GetAt(i)
	Return verdict.verdict _ " " _ out _ " approval=" _ +verdict.requiresApproval
}

/// "verdict reasons approval=n" as the fixture recorded it
ClassMethod Recorded(v As %DynamicObject) As %String
{
	Set out = ""
	Set each = v.reasons.%GetIterator()
	While each.%GetNext(.i, .reason) {
		Set out = out _ $Select(out = "": "", 1: ",") _ reason
	}
	Return v.verdict _ " " _ out _ " approval=" _ +v.requiresApproval
}

/// The verdict 004 gives to proposal number `n` (0-based) of a Case fixture, and the recorded one
Method Agree(file As %String, n As %Integer = 0)
{
	Set case = ..Load(file)
	Set p = case.proposals.%Get(n)
	Set recorded = ..Recorded(p.validatorVerdict)
	Set verdict = ##class(SignalNoir.Core.Validator).%New().Validate(..InputFor(case, p, p.validatorVerdict.at))
	Do $$$AssertEquals(..Outcome(verdict), recorded, file _ " " _ p.proposalId _ " (" _ p.action _ ")")
}

Method TestExecutingOutcomeUnknown()
{
	Do ..Agree("case.executing.outcome-unknown.json")
}

Method TestHeld()
{
	Do ..Agree("case.held.p3.json")
}

Method TestPendingApprovalMapping()
{
	Do ..Agree("case.pending-approval.p5-p8b.json")
}

Method TestSupersededFirstAndSecondProposal()
{
	Do ..Agree("case.pending-approval.superseded.json", 0)
	Do ..Agree("case.pending-approval.superseded.json", 1)
}

Method TestResolvedByPriorReceipt()
{
	Do ..Agree("case.resolved-by-prior-receipt.p9.json")
}

Method TestResolvedByReconciliation()
{
	Do ..Agree("case.resolved.by-reconciliation.json")
}

Method TestResolvedMapping()
{
	Do ..Agree("case.resolved.p5-p8b.json")
}

Method TestReviewAfterDenial()
{
	Do ..Agree("case.review.after-denial.json", 0)
	Do ..Agree("case.review.after-denial.json", 1)
}

Method TestReviewAmbiguousIdentity()
{
	Do ..Agree("case.review.ambiguous-identity.json")
}

/// The Operator's conditional Mapping of resolution.201.action.json. KNOWN DIVERGENCE: with the
/// Case's Evidence in, 004 gives the conditions and the Evidence their reasons; the fixture
/// lacks them. When the mock is fixed and the fixture regenerated, this assertion fails: change
/// `divergent` to the fixture's value and call Agree-style equality.
Method TestResolution201IsTheKnownDivergence()
{
	Set resolution = ..Load("resolution.201.action.json")
	Set case = ..Load("case.review.provider-unavailable.json")
	Set p = resolution.proposal
	Set verdict = ##class(SignalNoir.Core.Validator).%New().Validate(..InputFor(case, p, p.validatorVerdict.at))
	Do $$$AssertEquals(..Outcome(verdict), "accepted ACTION_IN_CATALOG,PARAMS_VALID,MAPPING_CONDITION_MATCHES,REQUIRED_EVIDENCE_PRESENT approval=1", "what the rules of 004 say")
	Do $$$AssertEquals(..Recorded(p.validatorVerdict), "accepted ACTION_IN_CATALOG,PARAMS_VALID approval=1", "what the fixture records: it lacks the condition and the Evidence reasons")
	Do $$$AssertTrue(..Outcome(verdict) '= ..Recorded(p.validatorVerdict), "the divergence is still there")
}

/// resolution.422: the serum Mapping on the Case's plasma Order
Method TestResolution422Blocked()
{
	Set resolution = ..Load("resolution.422.validator-blocked.json")
	Set case = ..Load("case.review.provider-unavailable.json")
	Set p = ..Load("resolution.201.action.json").proposal
	Set p.params = {"mappingId": "map_glicj_soro", "mappingVersion": "2026.10.1"}
	Set verdict = ##class(SignalNoir.Core.Validator).%New().Validate(..InputFor(case, p, resolution.error.details.verdict.at))
	Do $$$AssertEquals(..Outcome(verdict), ..Recorded(resolution.error.details.verdict), "resolution.422.validator-blocked.json")
}

}
