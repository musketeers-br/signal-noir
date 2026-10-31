Class SignalNoir.Tests.Core.Validator.TestPreconditions Extends %UnitTest.TestCase
{

Parameter INPUTS = "SignalNoir.Tests.Core.Validator.Inputs";

/// 004 T032 - US5: the five declared preconditions, checked again right before the send
/// (FR-020..FR-022, SC-007). The declaration only chooses which checks run; what each check
/// requires is fixed by the Validator. Only input.observed feeds them.
ClassMethod Validator() As SignalNoir.Core.Validator
{
	Return ##class(SignalNoir.Core.Validator).%New()
}

ClassMethod Checks() As %List
{
	Return $ListBuild("PARTNER_HEALTHY_WINDOW", "ORDER_ACTIVE_AT_ORIGIN", "APPROVAL_VALID", "POLICY_VERSION_UNCHANGED", "MAPPING_VERSION_UNCHANGED")
}

/// Everything as it was when the Proposal was approved
ClassMethod Observed() As %DynamicObject
{
	Return {
		"partnerHealth": {"status": "UP", "errorRate": 0.0, "evidenceId": "evid_9"},
		"partnerMaintenanceActive": false,
		"originStatus": "active",
		"approval": {"approvalId": "appr_1", "proposalId": "prop_000045", "deadline": "2026-10-29T13:17:11Z"},
		"proposalCurrent": true,
		"policyVersionInForce": "2026.10.1",
		"mappingVersionInForce": "2026.10.1",
		"mappingExists": true
	}
}

/// An approved RETRY that declares the checks named (comma list; all five by default) and the
/// observed values given (as they were approved by default)
ClassMethod InputOf(declared As %String = "", observed As %DynamicObject = "") As SignalNoir.Core.Dto.ValidationInput
{
	If declared = "" Set declared = $ListToString(..Checks(), ",")
	Set input = $ClassMethod(..#INPUTS, "Input", $ClassMethod(..#INPUTS, "Proposal", "RETRY"))
	Set pre = []
	For i = 1 : 1 : $Length(declared, ",") {
		Set check = $Piece(declared, ",", i)
		Do pre.%Push({"check": (check), "expected": true})
	}
	Set input.proposal.preconditions = pre
	Set input.observed = $Select($IsObject(observed): observed, 1: ..Observed())
	Return input
}

ClassMethod Revalidate(input, Output results As %ListOfObjects) As SignalNoir.Core.Dto.ValidatorVerdict
{
	Return ..Validator().Revalidate(input, .results)
}

ClassMethod Outcome(verdict As SignalNoir.Core.Dto.ValidatorVerdict) As %String
{
	Set out = ""
	For i = 1 : 1 : verdict.reasons.Count() Set out = out _ $Select(out = "": "", 1: ",") _ verdict.reasons.GetAt(i)
	Return verdict.verdict _ " " _ out
}

/// "CHECK:passed" for every result, in order
ClassMethod Summary(results As %ListOfObjects) As %String
{
	Set out = ""
	For i = 1 : 1 : results.Count() Set out = out _ $Select(out = "": "", 1: " ") _ results.GetAt(i).check _ ":" _ +results.GetAt(i).passed
	Return out
}

Method TestWhenEverythingMatchesEveryCheckPasses()
{
	Set v = ..Revalidate(..InputOf(), .results)
	Do $$$AssertEquals(..Outcome(v), "accepted ACTION_IN_CATALOG,RETRY_BUDGET_AVAILABLE,REQUIRED_EVIDENCE_PRESENT", "AS1: the verdict stays accepted")
	Do $$$AssertEquals(..Summary(results), "PARTNER_HEALTHY_WINDOW:1 ORDER_ACTIVE_AT_ORIGIN:1 APPROVAL_VALID:1 POLICY_VERSION_UNCHANGED:1 MAPPING_VERSION_UNCHANGED:1", "five results, all passed, in the vocabulary's order")
	Do $$$AssertEquals(..Validator().Validate(..InputOf()).ToJson().%ToJSON(), v.ToJson().%ToJSON(), "Validate and Revalidate agree when nothing changed")
}

Method TestEachResultStatesExpectedObservedAndPassed()
{
	Do ..Revalidate(..InputOf(), .results)
	Set json = results.GetAt(1).ToJson()
	Do $$$AssertEquals(json.%ToJSON(), "{""check"":""PARTNER_HEALTHY_WINDOW"",""expected"":true,""observed"":true,""passed"":true,""evidenceId"":""evid_9""}", "the partner check names the health Evidence it read")
	Set json = results.GetAt(2).ToJson()
	Do $$$AssertEquals(json.%ToJSON(), "{""check"":""ORDER_ACTIVE_AT_ORIGIN"",""expected"":true,""observed"":true,""passed"":true,""evidenceId"":null}", "no Evidence behind the Origin status")
	Set json = results.GetAt(4).ToJson()
	Do $$$AssertEquals(json.%ToJSON(), "{""check"":""POLICY_VERSION_UNCHANGED"",""expected"":""2026.10.1"",""observed"":""2026.10.1"",""passed"":true,""evidenceId"":null}", "versions are compared as text")
	Do $$$AssertEquals(json.%GetTypeOf("expected") _ ":" _ results.GetAt(1).ToJson().%GetTypeOf("expected"), "string:boolean", "a boolean stays a boolean")
}

Method TestEachObservedValueChangedAloneFailsExactlyItsCheck()
{
	Set cases = $ListBuild(
		$ListBuild("PARTNER_HEALTHY_WINDOW", "partner DEGRADED", "partnerHealth.status", "DEGRADED"),
		$ListBuild("PARTNER_HEALTHY_WINDOW", "partner DOWN", "partnerHealth.status", "DOWN"),
		$ListBuild("PARTNER_HEALTHY_WINDOW", "error rate above the threshold", "partnerHealth.errorRate", 0.5),
		$ListBuild("PARTNER_HEALTHY_WINDOW", "maintenance active", "partnerMaintenanceActive", "true"),
		$ListBuild("ORDER_ACTIVE_AT_ORIGIN", "cancelled at the Origin", "originStatus", "cancelled"),
		$ListBuild("ORDER_ACTIVE_AT_ORIGIN", "an Origin status that is not active", "originStatus", "closed"),
		$ListBuild("APPROVAL_VALID", "expired", "approval.deadline", "2026-10-29T13:02:10Z"),
		$ListBuild("APPROVAL_VALID", "for another Proposal", "approval.proposalId", "prop_000099"),
		$ListBuild("APPROVAL_VALID", "the Proposal is no longer current", "proposalCurrent", "false"),
		$ListBuild("POLICY_VERSION_UNCHANGED", "another policy version in force", "policyVersionInForce", "2026.10.2"),
		$ListBuild("MAPPING_VERSION_UNCHANGED", "another Mapping version in force", "mappingVersionInForce", "2026.10.2"),
		$ListBuild("MAPPING_VERSION_UNCHANGED", "the Mapping is gone", "mappingExists", "false"))
	For i = 1 : 1 : $ListLength(cases) {
		Set case = $List(cases, i), check = $List(case, 1), label = $List(case, 2)
		Set observed = ..Observed()
		Do ..Set(observed, $List(case, 3), $List(case, 4))
		Set v = ..Revalidate(..InputOf("", observed), .results)
		Do $$$AssertEquals(..Outcome(v), "blocked PRECONDITION_FAILED_" _ check, label _ ": blocked with that check's reason only")
		Set failed = ""
		For j = 1 : 1 : results.Count() If 'results.GetAt(j).passed Set failed = failed _ $Select(failed = "": "", 1: ",") _ results.GetAt(j).check
		Do $$$AssertEquals(failed, check, label _ ": exactly that check fails")
	}
}

/// Sets a dotted path of observed; "true" and "false" become booleans
ClassMethod Set(observed As %DynamicObject, path As %String, value)
{
	Set node = observed
	For i = 1 : 1 : $Length(path, ".") - 1 Set node = node.%Get($Piece(path, ".", i))
	Set key = $Piece(path, ".", $Length(path, "."))
	If (value = "true") || (value = "false") {
		Do node.%Set(key, (value = "true"), "boolean")
	} Else {
		Do node.%Set(key, value)
	}
}

Method TestTheThresholdAndTheDeadlineAreExact()
{
	Set observed = ..Observed()
	Set observed.partnerHealth.errorRate = 0.2
	Do ..Revalidate(..InputOf("PARTNER_HEALTHY_WINDOW", observed), .results)
	Do $$$AssertEquals(..Summary(results), "PARTNER_HEALTHY_WINDOW:1", "an error rate equal to the policy's maximum is within it")
	Set observed = ..Observed()
	Set observed.approval.deadline = "2026-10-29T13:02:11Z"
	Do ..Revalidate(..InputOf("APPROVAL_VALID", observed), .results)
	Do $$$AssertEquals(..Summary(results), "APPROVAL_VALID:0", "an Approval is valid only before its deadline, not at it")
	Set observed.approval.deadline = "2026-10-29T13:02:12Z"
	Do ..Revalidate(..InputOf("APPROVAL_VALID", observed), .results)
	Do $$$AssertEquals(..Summary(results), "APPROVAL_VALID:1", "a second before the deadline")
	Set observed.approval.deadline = "2026-10-29T10:30:00-03:00"
	Do ..Revalidate(..InputOf("APPROVAL_VALID", observed), .results)
	Do $$$AssertEquals(..Summary(results), "APPROVAL_VALID:1", "the deadline is an instant, offset included: 10:30-03:00 is 13:30Z, later than 13:02:11Z though it sorts earlier as text")
	Set observed.approval.deadline = "not a time"
	Do ..Revalidate(..InputOf("APPROVAL_VALID", observed), .results)
	Do $$$AssertEquals(..Summary(results), "APPROVAL_VALID:0", "a deadline that cannot be read is not a deadline in the future")
}

Method TestAPolicyMaintenanceWindowFailsThePartnerCheck()
{
	Set input = ..InputOf("PARTNER_HEALTHY_WINDOW")
	Set order = input.order
	Set order.partnerId = "PARTNER-A"
	Set input.reference.policies.maintenanceWindows = [{"partnerId": "PARTNER-A", "startsAt": "2026-10-29T13:00:00Z", "endsAt": "2026-10-29T14:00:00Z"}]
	Do ..Revalidate(input, .results)
	Do $$$AssertEquals(..Summary(results), "PARTNER_HEALTHY_WINDOW:0", "FR-021: a window of the policy is active now")
	Set input.reference.policies.maintenanceWindows = [{"partnerId": "PARTNER-B", "startsAt": "2026-10-29T13:00:00Z", "endsAt": "2026-10-29T14:00:00Z"}]
	Do ..Revalidate(input, .results)
	Do $$$AssertEquals(..Summary(results), "PARTNER_HEALTHY_WINDOW:1", "a window of another Partner does not count")
	Set input.reference.policies.maintenanceWindows = [{"partnerId": "PARTNER-A", "startsAt": "2026-10-29T14:00:00Z", "endsAt": "2026-10-29T15:00:00Z"}]
	Do ..Revalidate(input, .results)
	Do $$$AssertEquals(..Summary(results), "PARTNER_HEALTHY_WINDOW:1", "a window that has not started")
	Set input.reference.policies.maintenanceWindows = [{"partnerId": "PARTNER-A", "startsAt": "2026-10-29T12:00:00Z", "endsAt": "2026-10-29T13:02:11Z"}]
	Do ..Revalidate(input, .results)
	Do $$$AssertEquals(..Summary(results), "PARTNER_HEALTHY_WINDOW:1", "a window that ended at this instant is over")
}

Method TestAMissingObservedValueFails()
{
	For key = "partnerHealth", "originStatus", "approval", "proposalCurrent", "policyVersionInForce", "mappingVersionInForce" {
		Set observed = ..Observed()
		Do observed.%Remove(key)
		Do ..Revalidate(..InputOf("", observed), .results)
		Set failed = 0
		For j = 1 : 1 : results.Count() Set failed = failed + 'results.GetAt(j).passed
		Do $$$AssertTrue(failed >= 1, "without " _ key _ " some check fails: " _ ..Summary(results))
	}
	Set observed = ..Observed()
	Do observed.%Remove("mappingExists")
	Do ..Revalidate(..InputOf("MAPPING_VERSION_UNCHANGED", observed), .results)
	Do $$$AssertEquals(..Summary(results), "MAPPING_VERSION_UNCHANGED:0", "an unknown existence is not existence")

	Set input = ..InputOf()
	Set input.observed = ""
	Set v = ..Revalidate(input, .results)
	Do $$$AssertEquals(..Summary(results), "PARTNER_HEALTHY_WINDOW:0 ORDER_ACTIVE_AT_ORIGIN:0 APPROVAL_VALID:0 POLICY_VERSION_UNCHANGED:0 MAPPING_VERSION_UNCHANGED:0", "nothing observed, nothing passes")
	Do $$$AssertEquals(..Outcome(v), "blocked PRECONDITION_FAILED_PARTNER_HEALTHY_WINDOW,PRECONDITION_FAILED_ORDER_ACTIVE_AT_ORIGIN,PRECONDITION_FAILED_APPROVAL_VALID,PRECONDITION_FAILED_POLICY_VERSION_UNCHANGED,PRECONDITION_FAILED_MAPPING_VERSION_UNCHANGED", "every failure is listed, in the table's order")
}

Method TestOnlyDeclaredChecksAreEvaluated()
{
	Set observed = ..Observed()
	Set observed.policyVersionInForce = "2026.10.2"
	Set v = ..Revalidate(..InputOf("ORDER_ACTIVE_AT_ORIGIN", observed), .results)
	Do $$$AssertEquals(..Summary(results), "ORDER_ACTIVE_AT_ORIGIN:1", "one declared, one result")
	Do $$$AssertEquals(v.verdict, "accepted", "a change in what the Proposal did not declare does not block it")
	Set input = ..InputOf()
	Set input.proposal.preconditions = []
	Set v = ..Revalidate(input, .results)
	Do $$$AssertEquals(results.Count() _ " " _ v.verdict, "0 accepted", "none declared, none checked")
	Set results = ""
	Set v = ..Revalidate(..InputOf("APPROVAL_VALID,APPROVAL_VALID"), .results)
	Do $$$AssertEquals(results.Count(), 1, "a check declared twice is checked once")
}

Method TestTheDeclaredExpectedValueIsNotTrusted()
{
	Set observed = ..Observed()
	Set observed.originStatus = "cancelled"
	Set input = ..InputOf("ORDER_ACTIVE_AT_ORIGIN", observed)
	Set input.proposal.preconditions = [{"check": "ORDER_ACTIVE_AT_ORIGIN", "expected": false}]
	Do ..Revalidate(input, .results)
	Do $$$AssertEquals(..Summary(results) _ " " _ results.GetAt(1).expectedLiteral, "ORDER_ACTIVE_AT_ORIGIN:0 true", "declaring `expected: false` does not make a cancelled Order pass")
	Set observed = ..Observed()
	Set observed.policyVersionInForce = "2026.10.2"
	Set input = ..InputOf("POLICY_VERSION_UNCHANGED", observed)
	Set input.proposal.preconditions = [{"check": "POLICY_VERSION_UNCHANGED", "expected": "2026.10.2"}]
	Do ..Revalidate(input, .results)
	Do $$$AssertEquals(..Summary(results) _ " " _ results.GetAt(1).expectedLiteral, "POLICY_VERSION_UNCHANGED:0 ""2026.10.1""", "the expected version is the one the Proposal relied on, whatever it declares")
}

Method TestAnUnknownPreconditionIsBlocked()
{
	Set input = ..InputOf("SEND_FLOWERS")
	Do $$$AssertEquals(..Outcome(..Validator().Validate(input)), "blocked PRECONDITION_UNKNOWN", "AS7: in Validate")
	Set v = ..Revalidate(input, .results)
	Do $$$AssertEquals(..Outcome(v), "blocked PRECONDITION_UNKNOWN", "AS7: in Revalidate")
	Do $$$AssertEquals(results.Count(), 0, "an unknown check has no result")
	Set input.proposal.preconditions = [{"check": "ORDER_ACTIVE_AT_ORIGIN", "expected": true}, {"check": "order_active_at_origin"}, "ORDER_ACTIVE_AT_ORIGIN", {}]
	Do $$$AssertEquals(..Outcome(..Validator().Validate(input)), "blocked PRECONDITION_UNKNOWN", "a differently written name, a bare string and an empty entry are unknown")
	Set v = ..Revalidate(input, .results)
	Do $$$AssertEquals(..Summary(results), "ORDER_ACTIVE_AT_ORIGIN:1", "the known one is still checked")
	Set input = ..InputOf("")
	Set input.proposal = $ClassMethod(..#INPUTS, "Proposal", "REQUEST_REVIEW")
	Set input.proposal.preconditions = [{"check": "SEND_FLOWERS"}]
	Do $$$AssertEquals(..Validator().Validate(input).verdict, "accepted", "REQUEST_REVIEW is accepted after step 4: nothing is sent, nothing to check")
}

Method TestValidateNeverLooksAtTheObservedValues()
{
	Set observed = ..Observed()
	Set observed.originStatus = "cancelled"
	Set v = ..Validator().Validate(..InputOf("", observed))
	Do $$$AssertEquals(v.verdict, "accepted", "step 8 belongs to Revalidate")
}

Method TestNewEvidenceAloneChangesNothing()
{
	Do ..Revalidate(..InputOf(), .before)
	Set input = ..InputOf()
	Do input.evidence.Insert($ClassMethod(..#INPUTS, "Evidence", "evid_late", "tool.partner_health", {"partnerId": "labpartner-c", "status": "DOWN", "message": "outage"}))
	Do input.evidence.Insert($ClassMethod(..#INPUTS, "Evidence", "evid_orig", "tool.origin_order_status", {"status": "CANCELLED"}))
	Set v = ..Revalidate(input, .after)
	Do $$$AssertEquals(..Summary(after), ..Summary(before), "AS8: the same results")
	Do $$$AssertEquals(after.GetAt(1).ToJson().%ToJSON(), before.GetAt(1).ToJson().%ToJSON(), "down to the JSON")
	Do $$$AssertEquals(v.verdict, "accepted", "and the verdict")
}

Method TestRevalidateRunsTheWholePipeline()
{
	Set input = ..InputOf()
	Set input.proposal.action = "DELETE_ORDER"
	Set v = ..Revalidate(input, .results)
	Do $$$AssertEquals(..Outcome(v) _ " " _ results.Count(), "blocked ACTION_NOT_IN_CATALOG 0", "steps 1-4 stop it: no results")
	Set input = ..InputOf()
	Set input.proposal.confidence = "LOW"
	Do $$$AssertEquals(..Outcome(..Revalidate(input, .results)), "review CONFIDENCE_LOW", "a pass of step 8 does not hide a review")
	Do $$$AssertEquals(results.Count(), 5, "the results are still given")
	Set observed = ..Observed()
	Set observed.originStatus = "cancelled"
	Set input = ..InputOf("", observed)
	Set input.proposal.confidence = "LOW"
	Do $$$AssertEquals(..Outcome(..Revalidate(input, .results)), "blocked PRECONDITION_FAILED_ORDER_ACTIVE_AT_ORIGIN,CONFIDENCE_LOW", "a block and a review: both listed, blocked wins")
	Set input = ..InputOf()
	Set input.attemptCount = 3
	Do $$$AssertEquals(..Outcome(..Revalidate(input, .results)), "blocked RETRY_BUDGET_EXHAUSTED", "the retry budget is checked again")
}

Method TestTheOriginDoesNotChangeTheResults()
{
	Set expected = ""
	For origin = "agent", "rules", "operator:ana", "replay" {
		Set input = ..InputOf()
		Set input.proposal.origin = origin
		Set v = ..Revalidate(input, .results)
		Set json = v.ToJson().%ToJSON() _ ..Summary(results)
		If expected = "" Set expected = json
		Do $$$AssertEquals(json, expected, origin _ ": same verdict and results")
	}
}

}
