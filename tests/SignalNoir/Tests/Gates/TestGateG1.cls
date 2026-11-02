Class SignalNoir.Tests.Gates.TestGateG1 Extends %UnitTest.TestCase
{

/// Gate G1 (002 + 003 + 004): an Order of the Simulator becomes a Case with a validated Proposal.
/// Live against the Simulator over HTTP: the Order is accepted (003), delivered once to the
/// Partner, whose answer opens the Case; the investigation reads the real Tools (the Simulator's
/// and the reference data of 004) and a Proposal is made; the Validator (004) records its verdict
/// with the versions of the reference data, and the Case waits for an Operator.
/// The Case is routed to the rules proposer, as a BenchmarkRun would (010): a new Case defaults to
/// the agent, which needs a provider the gate must not depend on.
Parameter S = "SignalNoir.Tests.Support";

Parameter SIM = "SignalNoir.Tests.Interop.TestOriginFeed";

Property Ready As %Boolean;

Property SavedBase As %String;

/// The gate expects the Mapping of the reference data alone: with the Simulator's base URL set, the
/// Simulator Tools take part in the investigation and the expected Mapping no longer comes out (010
/// research, baseline). The URL is emptied for this class and put back after it.
Method OnBeforeAllTests() As %Status
{
	Set ..SavedBase = $Get(^SignalNoir.Config("simBaseUrl"))
	Set ^SignalNoir.Config("simBaseUrl") = ""
	Set ..Ready = ##class(SignalNoir.Tests.Recovery.TestRecoverySuite).Partner().SearchReceipts({"idempotencyKey": "bek_probe"}).ok
	Return $$$OK
}

Method OnAfterAllTests() As %Status
{
	Set ^SignalNoir.Config("simBaseUrl") = ..SavedBase
	Return $$$OK
}

ClassMethod BodyOf(text As %String) As %DynamicObject
{
	Try {
		Set body = {}.%FromJSON(text)
	} Catch {
		Set body = {"text": (text)}
	}
	Return body
}

/// An Order of a Simulator variant, accepted, delivered once to the Partner; the Partner's answer
/// opens the Case. Returns the caseId; x holds {sci, order, attempt}.
ClassMethod OpenLiveCase(variant As %String, seed As %Integer, Output x As %DynamicObject) As %String
{
	Set sim = ..#SIM
	Set c = $ClassMethod(sim, "Post", "/scenarios", {"family": "P8", "variant": (variant), "seed": (seed), "timeScale": 0.01})
	Set e = $ClassMethod(sim, "Post", "/scenarios/" _ c.scenarioInstanceId _ "/emissions", "")
	Set order = e.emitted.%Get(0).order
	Do ##class(SignalNoir.Interop.Service.OrderIn).Accept(order.%ToJSON(), "tx-" _ order.orderId, "", c.scenarioInstanceId)
	Set reader = ##class(SignalNoir.Interop.Service.OriginFeed).%New()
	Set reader.Base = $Parameter(sim, "SIM"), reader.TimeoutSeconds = 10
	Set attempt = reader.Deliver({"order": (order), "transactionId": ("tx-" _ order.orderId), "scenarioInstanceId": (c.scenarioInstanceId), "runId": null})
	Set x = {"sci": (c.scenarioInstanceId), "order": (order), "attempt": (attempt)}
	Set ex = $ClassMethod(..#S, "Exception", attempt.kind, attempt.httpStatus)
	Set ex.body = ..BodyOf(attempt.body)
	Set ex.attemptId = attempt.attemptId
	Return ##class(SignalNoir.Application.CaseService).Default().RecordException(order.orderId, ex).ref
}

/// Routes the Case to the rules proposer and runs its investigation with the real Tools
ClassMethod Investigate(caseId As %String) As SignalNoir.Core.Result
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set rec = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(caseId)
	Set rec.proposerMode = "rules"
	Do rec.%Save()
	Kill rec
	Do svc.Transition(caseId, 1, "Investigating", "system", $ClassMethod(..#S, "Ev", "routed"))
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT commandId FROM SignalNoir_Application_Model.OutboxRecord WHERE caseId = ? AND type = 'Investigate' AND status = 'pending'", caseId)
	Set commandId = $Select(rs.%Next(): rs.%Get("commandId"), 1: "")
	Set inv = ##class(SignalNoir.Application.InvestigationService).%New()
	Set inv.ProposerClass = "SignalNoir.Proposers.Rules"
	Set inv.BudgetMs = 30000
	Return inv.Run(commandId)
}

ClassMethod VerdictOf(proposalId As %String) As %DynamicObject
{
	Return {}.%FromJSON(##class(SignalNoir.Application.Model.ProposalRecord).%OpenId(proposalId).verdictJson)
}

ClassMethod Reasons(verdict As %DynamicObject) As %String
{
	Set out = ""
	Set each = verdict.reasons.%GetIterator()
	While each.%GetNext(.i, .reason) {
		Set out = out _ $Select(out = "": "", 1: ",") _ reason
	}
	Return out
}

Method TestAPlasmaOrderBecomesACaseWithAValidatedProposal()
{
	If '..Ready Do $$$LogMessage("skipped: the Simulator is not reachable") Quit
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ..OpenLiveCase("P8b-tune-01", 51, .x)
	Do $$$AssertTrue(caseId '= "", "the Partner's answer opened a Case")
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.orderId, x.order.orderId, "of that Order")
	Do $$$AssertEquals(c.exceptions.GetAt(1).kind _ ":" _ c.exceptions.GetAt(1).httpStatus, "http_error:" _ x.attempt.httpStatus, "with the Partner's own answer")

	Set r = ..Investigate(caseId)
	Do $$$AssertEquals(r.details.status, "proposed", "the investigation proposed: " _ r.details.reason)
	Set c = svc.GetCase(caseId).obj
	Set p = c.proposals.GetAt(1)
	Do $$$AssertEquals(p.action _ " " _ p.params.mappingId, "APPLY_APPROVED_MAPPING map_glicj_plasma", "the one Mapping that fits the plasma Order")
	Do $$$AssertEquals(p.versions.policy _ ":" _ p.versions.mapping, "2026.10.1:2026.10.1", "relying on the reference data in force")

	Set verdict = ..VerdictOf(p.proposalId)
	Do $$$AssertEquals(verdict.verdict _ " " _ ..Reasons(verdict), "accepted ACTION_IN_CATALOG,PARAMS_VALID,MAPPING_CONDITION_MATCHES,REQUIRED_EVIDENCE_PRESENT", "the Validator accepted it, with every reason")
	Do $$$AssertTrue(verdict.requiresApproval, "an Approval is required")
	Do $$$AssertEquals(verdict.versions.policy _ ":" _ verdict.versions.mapping, "2026.10.1:2026.10.1", "and the verdict names the versions it used")
	Do $$$AssertEquals(c.state, "PendingApproval", "the Case waits for an Operator")

	Set sources = ""
	For i = 1 : 1 : c.evidence.Count() Set sources = sources _ "," _ c.evidence.GetAt(i).source
	For tool = "tool.policies", "tool.mapping_catalog", "tool.partner_health", "tool.partner_failure_history" Do $$$AssertTrue(sources [ tool, "Evidence from " _ tool)
	Set timeline = svc.GetTimeline(caseId, 0, 500).list
	Set recorded = 0
	For i = 1 : 1 : timeline.Count() {
		If (timeline.GetAt(i).type = "ValidatorVerdict") && (timeline.GetAt(i).payload.versions.mapping = "2026.10.1") Set recorded = 1
	}
	Do $$$AssertTrue(recorded, "the verdict is on the timeline, with its versions")
}

/// A serum Order written `soro`. The Validator reads it as SERUM through the synonyms of the
/// reference data, and since rules-v2 (010 T053) so does the rules baseline: both use
/// Core.Conditions.Matches, so the Rules propose the serum Mapping and the Validator accepts it.
Method TestASoroOrderEndsWithTheSerumMappingValidated()
{
	If '..Ready Do $$$LogMessage("skipped: the Simulator is not reachable") Quit
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ..OpenLiveCase("P8b-tune-02", 52, .x)
	Do $$$AssertEquals(x.order.specimen.type, "soro", "the Order is written soro")
	Set r = ..Investigate(caseId)
	Do $$$AssertEquals(r.details.status, "proposed", "the investigation proposed: " _ r.details.reason)
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "PendingApproval", "the Rules proposed the Mapping; the Case waits for an Operator")
	Set p = c.proposals.GetAt(c.proposals.Count())
	Do $$$AssertEquals(p.action _ " " _ p.params.mappingId, "APPLY_APPROVED_MAPPING map_glicj_soro", "the serum Mapping")
	Set verdict = ..VerdictOf(p.proposalId)
	Do $$$AssertEquals(verdict.verdict _ " " _ ..Reasons(verdict), "accepted ACTION_IN_CATALOG,PARAMS_VALID,MAPPING_CONDITION_MATCHES,REQUIRED_EVIDENCE_PRESENT", "validated: soro is SERUM")
}

}
