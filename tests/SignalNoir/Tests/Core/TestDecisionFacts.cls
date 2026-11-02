Class SignalNoir.Tests.Core.TestDecisionFacts Extends %UnitTest.TestCase
{

/// 017 agent-v4 - the CHECKS the Agent reads, on the shapes of the run_000146
/// Cases where agent-v3 compared values itself and got them wrong
ClassMethod Catalog() As %DynamicObject
{
	Return {"mappingVersion": "2026.10.1", "items": [{"mappingId": "map_glicj_plasma", "mappingVersion": "2026.10.1", "sourceCode": "GLIC-J", "targetCode": "GLIC-P", "conditions": {"specimenType": "PLASMA"}}, {"mappingId": "map_glicj_soro", "mappingVersion": "2026.10.1", "sourceCode": "GLIC-J", "targetCode": "GLIC-S", "conditions": {"specimenType": "SERUM"}}, {"mappingId": "map_hba1c_legacy", "mappingVersion": "2026.10.1", "sourceCode": "HBA1C-L", "targetCode": "HBA1C", "conditions": {}}, {"mappingId": "map_tsh_legacy", "mappingVersion": "2026.10.1", "sourceCode": "TSH-OLD", "targetCode": "TSH", "conditions": {}}], "synonyms": {"specimenType": {"PLASMA": ["PLASMA"], "SERUM": ["SERUM", "SORO"]}}}
}

ClassMethod Ev(id As %String, source As %String, result As %DynamicObject, kind As %String = "fact") As SignalNoir.Core.Dto.Evidence
{
	Set ev = ##class(SignalNoir.Core.Dto.Evidence).%New()
	Set ev.evidenceId = id, ev.source = source, ev.kind = kind, ev.result = result
	Return ev
}

ClassMethod Facts(order As %DynamicObject, health As %DynamicObject = "", history As %DynamicObject = "", policies As %DynamicObject = "", now As %String = "2026-11-02T10:05:00Z") As %DynamicObject
{
	Set list = ##class(%ListOfObjects).%New()
	Do list.Insert(..Ev("evid_cat", "tool.mapping_catalog", ..Catalog()))
	Do list.Insert(..Ev("evid_health", "tool.partner_health", $Select($IsObject(health): health, 1: {"status": "UP", "maintenance": null})))
	Do list.Insert(..Ev("evid_hist", "tool.partner_failure_history", $Select($IsObject(history): history, 1: {"window": {"total": 1, "errors": 1, "timeouts": 0, "errorRate": 1}})))
	Do list.Insert(..Ev("evid_pol", "tool.policies", $Select($IsObject(policies): policies, 1: {"maintenanceWindows": []})))
	Do list.Insert(..Ev("evid_rec", "tool.receipts_and_orders_by_patient", {"items": []}))
	Return ##class(SignalNoir.Core.DecisionFacts).Compute(list, order, "labpartner-a", now)
}

ClassMethod Order(code As %String, specimen As %String) As %DynamicObject
{
	Return {"exams": [{"code": (code)}], "specimen": {"type": (specimen)}, "patient": {"patientId": "p1", "name": "Ana"}}
}

/// "expected PLASMA, found plasma" (P8b): plasma is PLASMA, but not written as it
Method TestLetterCase()
{
	Set m = ..Facts(..Order("GLIC-J", "plasma")).mapping
	Do $$$AssertEquals(m.candidates.%Size(), 2, "both GLIC-J mappings are candidates")
	Do $$$AssertEquals(m.applicableCount, 1, "one applies")
	Set c = m.candidates.%Get(0)
	Do $$$AssertEquals(c.mappingId, "map_glicj_plasma", "the plasma mapping")
	Do $$$AssertEquals(c.applicable, 1, "applicable")
	Do $$$AssertEquals(c.exact, 0, "not exact: letter case differs")
	Do $$$AssertEquals(c.conditions.%Get(0).orderValue, "plasma", "the Order's value as written")
	Do $$$AssertEquals(m.candidates.%Get(1).applicable, 0, "the serum mapping does not apply")
	Do $$$AssertEquals(m.candidates.%Get(1).conditions.%Get(0).matched, 0, "the failed condition")
	Do $$$AssertEquals(m.catalogEvidenceId, "evid_cat", "names the catalog Evidence")
}

/// "order specifies SORO" (P5): a synonym applies, not exact; SERUM as written is exact
Method TestSynonymAndExact()
{
	Set m = ..Facts(..Order("glic-j", "SORO")).mapping
	Do $$$AssertEquals(m.applicableCount, 1, "SORO is SERUM")
	Do $$$AssertEquals(m.candidates.%Get(1).mappingId, "map_glicj_soro", "the serum mapping")
	Do $$$AssertEquals(m.candidates.%Get(1).exact, 0, "a synonym is not exact")
	Set m = ..Facts(..Order("GLIC-J", "SERUM")).mapping
	Do $$$AssertEquals(m.candidates.%Get(1).applicable, 1, "SERUM applies")
	Do $$$AssertEquals(m.candidates.%Get(1).exact, 1, "SERUM as written is exact")
	Set m = ..Facts(..Order("HBA1C-L", "")).mapping
	Do $$$AssertEquals(m.applicableCount, 1, "no conditions always apply")
	Do $$$AssertEquals(m.candidates.%Get(0).exact, 1, "no conditions is exact")
}

/// already-processed: a TSH Order has no candidate, so no GLIC-J mapping can be proposed
Method TestNoCandidateForOtherExam()
{
	Set m = ..Facts(..Order("TSH", "SERUM")).mapping
	Do $$$AssertEquals(m.candidates.%Size(), 0, "TSH is not TSH-OLD")
	Do $$$AssertEquals(m.applicableCount, 0, "nothing applies")
	Do $$$AssertEquals(m.orderExamCodes.%ToJSON(), "[""TSH""]", "the Order's own codes")
}

/// P8a: one attempt that timed out is unstable; one answered error is not
Method TestInstability()
{
	Set order = ..Order("HEMO", "SERUM")
	Set p = ..Facts(order, , {"window": {"total": 1, "errors": 0, "timeouts": 1, "errorRate": 1}}).partner
	Do $$$AssertEquals(p.unstable, 1, "one timeout of one attempt")
	Do $$$AssertEquals(p.timeoutsAtLeastHalf, 1, "half or more")
	Do $$$AssertEquals(p.downOrMaintenance, 0, "not DOWN: MEDIUM, not HIGH")
	Do $$$AssertEquals(p.historyEvidenceId, "evid_hist", "names the history Evidence")
	Set p = ..Facts(order).partner
	Do $$$AssertEquals(p.unstable, 0, "an answered error is the failure, not instability")
	Set p = ..Facts(order, , {"window": {"total": 3, "errors": 2, "timeouts": 1, "errorRate": 1}}).partner
	Do $$$AssertEquals(p.unstable, 0, "one timeout of three")
	Set p = ..Facts(order, {"status": "DOWN", "maintenance": null}).partner
	Do $$$AssertEquals(p.downOrMaintenance, 1, "DOWN")
	Do $$$AssertEquals(p.unstable, 1, "DOWN is unstable")
	Set p = ..Facts(order, {"status": "UP", "maintenance": {"active": true}}).partner
	Do $$$AssertEquals(p.maintenanceActive, 1, "maintenance reported by the Partner")
	Do $$$AssertEquals(p.downOrMaintenance, 1, "maintenance is HIGH")
}

/// A policy window covers now for this Partner or for every Partner; another Partner's does not
Method TestMaintenanceWindow()
{
	Set order = ..Order("HEMO", "SERUM")
	Set w = {"maintenanceWindows": [{"partnerId": "labpartner-a", "startsAt": "2026-11-02T10:00:00Z", "endsAt": "2026-11-02T11:00:00Z"}]}
	Set p = ..Facts(order, , , w).partner
	Do $$$AssertEquals(p.maintenanceWindowNow, 1, "covers now")
	Do $$$AssertEquals(p.unstable, 1, "a window is instability")
	Do $$$AssertEquals(p.downOrMaintenance, 0, "a policy window is not HIGH")
	Do $$$AssertEquals(..Facts(order, , , w, "2026-11-02T12:00:00Z").partner.maintenanceWindowNow, 0, "after the window")
	Set w = {"maintenanceWindows": [{"partnerId": "labpartner-b", "startsAt": "2026-11-02T10:00:00Z", "endsAt": "2026-11-02T11:00:00Z"}]}
	Do $$$AssertEquals(..Facts(order, , , w).partner.maintenanceWindowNow, 0, "another Partner")
}

/// Identity: a recorded record with the Order's name and another patientId collides
Method TestIdentity()
{
	Set order = ..Order("HEMO", "SERUM")
	Do $$$AssertEquals(..Facts(order).identity.patientRecordCollisions, 0, "no records")
	Set list = ##class(%ListOfObjects).%New()
	Do list.Insert(..Ev("evid_rec", "tool.receipts_and_orders_by_patient", {"items": [{"orderSnapshot": {"patient": {"patientId": "p2", "name": "Ana"}}}]}))
	Set facts = ##class(SignalNoir.Core.DecisionFacts).Compute(list, order)
	Do $$$AssertTrue(facts.identity.patientRecordCollisions > 0, "same name, other identity")
	Do $$$AssertEquals(facts.identity.evidenceId, "evid_rec", "names the receipts Evidence")
}

/// Only facts count, and missing Evidence gives empty checks, never an error
Method TestOnlyFacts()
{
	Set list = ##class(%ListOfObjects).%New()
	Do list.Insert(..Ev("evid_cat", "tool.mapping_catalog", ..Catalog(), "error"))
	Set facts = ##class(SignalNoir.Core.DecisionFacts).Compute(list, ..Order("GLIC-J", "SERUM"))
	Do $$$AssertEquals(facts.mapping.candidates.%Size(), 0, "a catalog that is not a fact is ignored")
	Do $$$AssertEquals(facts.mapping.catalogEvidenceId, "", "nothing to cite")
	Do $$$AssertEquals(facts.partner.unstable, 0, "no health, no history")
	Set facts = ##class(SignalNoir.Core.DecisionFacts).Compute(##class(%ListOfObjects).%New(), "")
	Do $$$AssertEquals(facts.mapping.orderExamCodes.%Size(), 0, "no Order")
}

}
