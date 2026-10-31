Class SignalNoir.Tests.Core.Validator.TestApprovalPolicy Extends %UnitTest.TestCase
{

Parameter INPUTS = "SignalNoir.Tests.Core.Validator.Inputs";

/// 004 T029 - US4: who must approve (FR-011, FR-012). requiresApproval is the Action
/// catalog's value, never configurable; Admit says whether an actor may approve within a run.
/// (`prior_receipt_confirmed` never requiring approval is asserted with US7, in TestPriorReceipt.)
ClassMethod Validator() As SignalNoir.Core.Validator
{
	Return ##class(SignalNoir.Core.Validator).%New()
}

ClassMethod InRun() As %DynamicObject
{
	Return {"inRun": true, "runId": "run_bench_01", "policyVersion": null, "mappingVersion": null}
}

ClassMethod OutsideRun() As %DynamicObject
{
	Return {"inRun": false, "runId": null, "policyVersion": null, "mappingVersion": null}
}

/// admissible, label and reason in one string
ClassMethod Answer(actor As %String, run) As %String
{
	Set a = ..Validator().Admit(actor, run)
	Return +a.admissible _ "|" _ a.label _ "|" _ a.reason
}

Method TestRetryAndMappingRequireApproval()
{
	For action = "RETRY", "APPLY_APPROVED_MAPPING" {
		Set params = $Select(action = "APPLY_APPROVED_MAPPING": $ClassMethod(..#INPUTS, "MappingParams"), 1: "")
		Set input = $ClassMethod(..#INPUTS, "Input", $ClassMethod(..#INPUTS, "Proposal", action, params))
		Set v = ..Validator().Validate(input)
		Do $$$AssertEquals(v.verdict _ ":" _ +v.requiresApproval, "accepted:1", "AS1: " _ action _ " outside a run")
	}
}

Method TestHoldAndReviewRequestNeedNoApproval()
{
	For action = "HOLD", "REQUEST_REVIEW" {
		Set input = $ClassMethod(..#INPUTS, "Input", $ClassMethod(..#INPUTS, "Proposal", action))
		Set v = ..Validator().Validate(input)
		Do $$$AssertEquals(v.verdict _ ":" _ +v.requiresApproval, "accepted:0", "AS2: " _ action)
	}
}

Method TestRequiresApprovalIsTheCatalogsForEveryVerdict()
{
	For action = "RETRY", "APPLY_APPROVED_MAPPING", "HOLD", "REQUEST_REVIEW" {
		Set params = $Select(action = "APPLY_APPROVED_MAPPING": $ClassMethod(..#INPUTS, "MappingParams"), 1: "")
		For case = "accepted", "review", "blocked" {
			Set input = $ClassMethod(..#INPUTS, "Input", $ClassMethod(..#INPUTS, "Proposal", action, params))
			If case = "review" Set input.proposal.confidence = "LOW"
			If case = "blocked" Set input.proposal.scope = "batch"
			Set v = ..Validator().Validate(input)
			Do $$$AssertEquals(+v.requiresApproval, +##class(SignalNoir.Core.ActionCatalog).RequiresApproval(action), action _ " " _ v.verdict _ ": the catalog's value")
		}
	}
}

Method TestTheRunDoesNotChangeTheVerdict()
{
	Set input = $ClassMethod(..#INPUTS, "Input", $ClassMethod(..#INPUTS, "Proposal", "RETRY"))
	Set outside = ..Validator().Validate(input).ToJson().%ToJSON()
	Set input.run = ..InRun()
	Set inside = ..Validator().Validate(input).ToJson().%ToJSON()
	Do $$$AssertEquals(inside, outside, "inside a BenchmarkRun the verdict still says an Approval is required: the automatic one is a different actor, not a different rule")
}

Method TestBenchmarkIsAdmissibleOnlyInsideARun()
{
	Do $$$AssertEquals(..Answer("benchmark", ..InRun()), "1|automatic|", "AS4: inside a run, labelled automatic")
	Do $$$AssertEquals(..Answer("benchmark", ..OutsideRun()), "0||ACTOR_BENCHMARK_OUTSIDE_RUN", "AS3: outside a run")
	Do $$$AssertEquals(..Answer("benchmark", {}), "0||ACTOR_BENCHMARK_OUTSIDE_RUN", "a run with no information is not a run")
	Do $$$AssertEquals(..Answer("benchmark", ""), "0||ACTOR_BENCHMARK_OUTSIDE_RUN", "no run at all")
	Do $$$AssertEquals(..Answer("benchmark", {"inRun": true, "runId": null}), "0||ACTOR_BENCHMARK_OUTSIDE_RUN", "inRun without a run id")
	Do $$$AssertEquals(..Answer("benchmark", {"inRun": true, "runId": ""}), "0||ACTOR_BENCHMARK_OUTSIDE_RUN", "inRun with an empty run id")
	Do $$$AssertEquals(..Answer("benchmark", {"inRun": false, "runId": "run_bench_01"}), "0||ACTOR_BENCHMARK_OUTSIDE_RUN", "a run id does not make a run if inRun is false")
	Do $$$AssertEquals(..Answer("benchmark", {"inRun": "true", "runId": "run_bench_01"}), "0||ACTOR_BENCHMARK_OUTSIDE_RUN", "inRun is a boolean, not text")
}

Method TestAnOperatorIsAdmissibleInOrOutsideARun()
{
	Do $$$AssertEquals(..Answer("operator:ana", ..OutsideRun()), "1|human|", "AS5: outside a run")
	Do $$$AssertEquals(..Answer("operator:ana", ..InRun()), "1|human|", "AS5: inside a run")
	Do $$$AssertEquals(..Answer("operator:Carla Souza", ""), "1|human|", "no run information")
	Do $$$AssertEquals(..Answer("operator:" _ $Translate($Justify("", 64), " ", "x"), ""), "1|human|", "a name of 64 characters")
}

Method TestAnyOtherActorIsRefused()
{
	For actor = "agent", "rules", "system", "sweeper", "replay", "", "operator:", "operator:a:b", "Benchmark", "BENCHMARK", "benchmark ", "admin", "operator", "OPERATOR:ana" {
		Do $$$AssertEquals(..Answer(actor, ..InRun()), "0||ACTOR_NOT_ALLOWED_TO_APPROVE", "'" _ actor _ "' inside a run")
		Do $$$AssertEquals(..Answer(actor, ..OutsideRun()), "0||ACTOR_NOT_ALLOWED_TO_APPROVE", "'" _ actor _ "' outside a run")
	}
	Do $$$AssertEquals(..Answer("operator:" _ $Translate($Justify("", 65), " ", "x"), ..OutsideRun()), "0||ACTOR_NOT_ALLOWED_TO_APPROVE", "a name over 64 characters is not an Actor of the contract")
}

Method TestTheAnswerIsAClosedReasonAndAContractShape()
{
	Set refused = ..Validator().Admit("benchmark", ..OutsideRun())
	Do $$$AssertTrue(##class(SignalNoir.Core.Reasons).IsReason(refused.reason), "the reason is in the closed list")
	Do $$$AssertEquals(##class(SignalNoir.Core.Reasons).Kind(refused.reason), "refuse", "of the refuse kind")
	Do $$$AssertEquals(refused.ToJson().%ToJSON(), "{""admissible"":false,""reason"":""ACTOR_BENCHMARK_OUTSIDE_RUN""}", "refusal: no label")
	Set admitted = ..Validator().Admit("benchmark", ..InRun())
	Do $$$AssertEquals(admitted.ToJson().%ToJSON(), "{""admissible"":true,""label"":""automatic""}", "admission: no reason")
	Do $$$AssertEquals(..Validator().Admit("benchmark", ..InRun()).ToJson().%ToJSON(), admitted.ToJson().%ToJSON(), "the same question, the same answer")
}

}
