Class SignalNoir.Tests.Application.TestRulesBaseline Extends %UnitTest.TestCase
{

/// 010 T053 - the rules baseline reads the mapping catalog with its synonyms,
/// the comparison the Validator uses (Core.Conditions)
Parameter CATALOG = "{""mappingVersion"": ""2026.10.1"", ""items"": [{""mappingId"": ""map_glicj_plasma"", ""mappingVersion"": ""2026.10.1"", ""sourceCode"": ""GLIC-J"", ""targetCode"": ""GLIC-P"", ""conditions"": {""specimenType"": ""PLASMA""}}, {""mappingId"": ""map_glicj_soro"", ""mappingVersion"": ""2026.10.1"", ""sourceCode"": ""GLIC-J"", ""targetCode"": ""GLIC-S"", ""conditions"": {""specimenType"": ""SERUM""}}], ""synonyms"": {""specimenType"": {""PLASMA"": [""PLASMA""], ""SERUM"": [""SERUM"", ""SORO""]}}}";

ClassMethod Context(specimenType As %String, catalog As %DynamicObject, window As %DynamicObject = "") As SignalNoir.Core.Dto.InvestigationContext
{
	Set ctx = ##class(SignalNoir.Core.Dto.InvestigationContext).%New()
	Set ctx.investigationId = "inv-rules-baseline"
	Set ctx.order = ##class(SignalNoir.Core.Dto.Order).%New()
	Set ctx.order.orderId = "ord-rules-baseline"
	Set ctx.order.snapshot = {"orderId": "ord-rules-baseline", "exams": [{"code": "GLIC-J"}], "specimen": {"type": (specimenType)}}
	Set ev = ##class(SignalNoir.Core.Dto.Evidence).%New()
	Set ev.evidenceId = "ev-catalog", ev.kind = "fact", ev.source = "tool.mapping_catalog", ev.result = catalog
	Do ctx.evidence.Insert(ev)
	If $IsObject(window) {
		Set ev = ##class(SignalNoir.Core.Dto.Evidence).%New()
		Set ev.evidenceId = "ev-history", ev.kind = "fact", ev.source = "tool.partner_failure_history", ev.result = {"window": (window)}
		Do ctx.evidence.Insert(ev)
	}
	Return ctx
}

/// The window is the Order's own attempts: its one answered failure is not instability
Method TestTheOrdersOwnErrorIsNotInstability()
{
	Set r = ##class(SignalNoir.Proposers.Rules).%New().Propose(..Context("soro", {}.%FromJSON(..#CATALOG), {"total": 1, "delivered": 0, "errors": 1, "timeouts": 0, "errorRate": 1}))
	Do $$$AssertEquals(r.obj.action _ " " _ r.obj.params.mappingId, "APPLY_APPROVED_MAPPING map_glicj_soro", "the 500 under investigation does not hold the Case")
}

Method TestTimeoutsHold()
{
	Set r = ##class(SignalNoir.Proposers.Rules).%New().Propose(..Context("soro", {}.%FromJSON(..#CATALOG), {"total": 2, "delivered": 0, "errors": 1, "timeouts": 1, "errorRate": 1}))
	Do $$$AssertEquals(r.obj.action, "HOLD", "half the attempts timed out")
	Do $$$AssertEquals(r.obj.diagnosis.claims.%Get(0).evidenceIds.%Get(0), "ev-history", "cites the history")
}

Method TestSoroFindsTheSerumMapping()
{
	Set r = ##class(SignalNoir.Proposers.Rules).%New().Propose(..Context("soro", {}.%FromJSON(..#CATALOG)))
	Do $$$AssertTrue(r.ok, "an answer")
	Do $$$AssertEquals(r.obj.action _ " " _ r.obj.params.mappingId, "APPLY_APPROVED_MAPPING map_glicj_soro", "soro is SERUM")
	Do $$$AssertEquals(r.obj.diagnosis.claims.%Get(0).evidenceIds.%Get(0), "ev-catalog", "cites the catalog")
	Do $$$AssertEquals(r.details.model, "rules-v2", "baseline version")
}

Method TestPlasmaStillFindsThePlasmaMapping()
{
	Set r = ##class(SignalNoir.Proposers.Rules).%New().Propose(..Context(" plasma ", {}.%FromJSON(..#CATALOG)))
	Do $$$AssertEquals(r.obj.action _ " " _ r.obj.params.mappingId, "APPLY_APPROVED_MAPPING map_glicj_plasma", "trim and case")
}

Method TestUnknownSpecimenAsksForReview()
{
	Set r = ##class(SignalNoir.Proposers.Rules).%New().Propose(..Context("urina", {}.%FromJSON(..#CATALOG)))
	Do $$$AssertEquals(r.obj.action, "REQUEST_REVIEW", "no mapping fits")
}

Method TestWithoutSynonymsSoroAsksForReview()
{
	Set catalog = {}.%FromJSON(..#CATALOG)
	Do catalog.%Remove("synonyms")
	Set r = ##class(SignalNoir.Proposers.Rules).%New().Propose(..Context("soro", catalog))
	Do $$$AssertEquals(r.obj.action, "REQUEST_REVIEW", "no synonyms in the catalog: exact comparison, never a guess")
}

}
