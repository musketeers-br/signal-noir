Class SignalNoir.Core.DecisionFacts Extends %RegisteredObject
{

/// The facts each decision step of the Agent needs (017, agent-v4), computed
/// from the Evidence already recorded with the comparisons the Validator and
/// Rules use (Core.Identity, Core.Conditions), so the model reads results it
/// would otherwise have to compute: the agent-v3 rehearsal (run_000146) showed
/// it comparing "plasma" with PLASMA literally and holding back on a single
/// timeout although the instructions said otherwise. Pure.
/// Each part names the evidenceId it comes from, so claims cite Evidence, not this.
ClassMethod Compute(evidence As %ListOfObjects, order As %DynamicObject, partnerId As %String = "", now As %String = "") As %DynamicObject
{
	Set (health, history, catalog, policies, receipts) = ""
	For i = 1 : 1 : evidence.Count() {
		Set ev = evidence.GetAt(i)
		If '..IsFact(ev) Continue
		If ev.source = "tool.partner_health" Set health = ev
		If ev.source = "tool.partner_failure_history" Set history = ev
		If ev.source = "tool.mapping_catalog" Set catalog = ev
		If ev.source = "tool.policies" Set policies = ev
		If ev.source = "tool.receipts_and_orders_by_patient" Set receipts = ev
	}
	Set order = $Select($IsObject(order): order, 1: {})
	Return {"identity": (..Identity(evidence, order, receipts)), "partner": (..Partner(health, history, policies, partnerId, now)), "mapping": (..Mapping(order, catalog))}
}

ClassMethod Identity(evidence As %ListOfObjects, order As %DynamicObject, receipts) As %DynamicObject [ Private ]
{
	Set n = ##class(SignalNoir.Core.Identity).Collisions(evidence, order).%Size()
	Return {"patientRecordCollisions": (n), "evidenceId": ($Select($IsObject(receipts): receipts.evidenceId, 1: ""))}
}

/// DOWN, an active maintenance (reported or in a policy window), or timeouts at
/// least half of the attempts in the window; answered errors never count
ClassMethod Partner(health, history, policies, partnerId As %String, now As %String) As %DynamicObject [ Private ]
{
	Set out = {}
	Set status = "", maintenance = 0
	If $IsObject(health) {
		Set status = health.result.status
		Set maintenance = $IsObject(health.result.%Get("maintenance")) && health.result.maintenance.active
	}
	Do out.%Set("healthStatus", status)
	Do out.%Set("maintenanceActive", maintenance, "boolean")
	Do out.%Set("healthEvidenceId", $Select($IsObject(health): health.evidenceId, 1: ""))
	Set window = $IsObject(policies) && ..WindowActive(policies.result, partnerId, now)
	Do out.%Set("maintenanceWindowNow", window, "boolean")
	Do out.%Set("policiesEvidenceId", $Select($IsObject(policies): policies.evidenceId, 1: ""))
	Set (timeouts, attempts) = 0
	If $IsObject(history) && $IsObject(history.result.window) {
		Set timeouts = +history.result.window.timeouts, attempts = +history.result.window.total
	}
	Set half = (attempts > 0) && ((timeouts * 2) >= attempts)
	Do out.%Set("timeouts", timeouts)
	Do out.%Set("attempts", attempts)
	Do out.%Set("timeoutsAtLeastHalf", half, "boolean")
	Do out.%Set("historyEvidenceId", $Select($IsObject(history): history.evidenceId, 1: ""))
	Do out.%Set("unstable", (status = "DOWN") || maintenance || window || half, "boolean")
	Do out.%Set("downOrMaintenance", (status = "DOWN") || maintenance, "boolean")
	Return out
}

/// The Validator's window rule (Core.Validator WindowActive): a window for this
/// Partner (or for every Partner) covers now; a clock or bound that cannot be read counts as inside
ClassMethod WindowActive(policies, partnerId As %String, now As %String) As %Boolean [ Private ]
{
	If '$IsObject(policies) || (policies.%GetTypeOf("maintenanceWindows") '= "array") Return 0
	Set now = ##class(SignalNoir.Core.Canon).NormalizeUtc(now)
	Set each = policies.maintenanceWindows.%GetIterator()
	While each.%GetNext(.index, .window) {
		If '$IsObject(window) || 'window.%IsA("%Library.DynamicObject") Continue
		If (window.%GetTypeOf("partnerId") = "string") && (window.partnerId '= "") && (window.partnerId '= partnerId) Continue
		If now = "" Return 1
		Set starts = ##class(SignalNoir.Core.Canon).NormalizeUtc(window.startsAt)
		Set ends = ##class(SignalNoir.Core.Canon).NormalizeUtc(window.endsAt)
		If (starts = "") || (ends = "") Return 1
		If '(starts ] now) && (ends ] now) Return 1
	}
	Return 0
}

/// Every approved mapping whose sourceCode is one of the Order's exam codes,
/// each condition checked with Core.Conditions (trim, upper-case, synonyms);
/// exact means every Order value was written as the condition value
ClassMethod Mapping(order As %DynamicObject, catalog) As %DynamicObject [ Private ]
{
	Set codes = []
	If order.%GetTypeOf("exams") = "array" {
		Set each = order.exams.%GetIterator()
		While each.%GetNext(.index, .exam) {
			If $IsObject(exam) && exam.%IsA("%Library.DynamicObject") && (exam.%GetTypeOf("code") = "string") Do codes.%Push(exam.code)
		}
	}
	Set out = {"orderExamCodes": (codes), "catalogEvidenceId": ($Select($IsObject(catalog): catalog.evidenceId, 1: "")), "candidates": [], "applicableCount": 0}
	If '$IsObject(catalog) || (catalog.result.%GetTypeOf("items") '= "array") Return out
	Set synonyms = $Select(catalog.result.%GetTypeOf("synonyms") = "object": catalog.result.synonyms, 1: {})
	Set n = 0
	For i = 0 : 1 : catalog.result.items.%Size() - 1 {
		Set m = catalog.result.items.%Get(i)
		If '$IsObject(m) || '##class(SignalNoir.Core.Conditions).HasSourceCode(order, m.sourceCode) Continue
		Set conditions = [], exact = 1
		If $IsObject(m.conditions) {
			Set each = m.conditions.%GetIterator()
			While each.%GetNext(.field, .expected) {
				Set actual = ##class(SignalNoir.Core.Conditions).OrderValue(order, field)
				Set one = {"field": (field), "expected": (expected)}
				Do one.%Set("orderValue", actual)
				Do one.%Set("matched", ##class(SignalNoir.Core.Conditions).Matches({}.%Set(field, expected), order, synonyms), "boolean")
				Set exact = exact && (actual '= "") && (actual = expected)
				Do conditions.%Push(one)
			}
		}
		Set applicable = ##class(SignalNoir.Core.Conditions).Matches(m.conditions, order, synonyms)
		Set n = n + applicable
		Set candidate = {"mappingId": (m.mappingId), "mappingVersion": (m.mappingVersion), "sourceCode": (m.sourceCode), "conditions": (conditions)}
		Do candidate.%Set("applicable", applicable, "boolean")
		Do candidate.%Set("exact", applicable && exact, "boolean")
		Do out.candidates.%Push(candidate)
	}
	Set out.applicableCount = n
	Return out
}

ClassMethod IsFact(ev) As %Boolean [ Private ]
{
	Return ($IsObject(ev) && (ev.kind = "fact") && $IsObject(ev.result) && ev.result.%IsA("%Library.DynamicObject"))
}

}
