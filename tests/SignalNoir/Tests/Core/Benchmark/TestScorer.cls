Class SignalNoir.Tests.Core.Benchmark.TestScorer Extends %UnitTest.TestCase
{

Parameter S = "SignalNoir.Core.Benchmark.Scorer";

/// 010 T028 - one test per row of contracts/scoring.md (Steps 0 to 3). The evaluator is
/// a function of the answer key and the facts of a Case; it reads nothing else.
ClassMethod Serum() As %DynamicObject
{
	Return {"action": "APPLY_APPROVED_MAPPING", "params": {"mappingId": "map_glicj_serum"}}
}

ClassMethod Plasma() As %DynamicObject
{
	Return {"action": "APPLY_APPROVED_MAPPING", "params": {"mappingId": "map_glicj_plasma"}}
}

/// The key of a variant whose right answer is the serum Mapping
ClassMethod SerumKey() As %DynamicObject
{
	Return {"variant": "P5-tune-01", "acceptable": [(..Serum())], "reviewIsAcceptable": false}
}

ClassMethod Facts(state As %String, effect, proposals As %DynamicArray = "") As %DynamicObject
{
	Set facts = {"replay": false, "touchedByPerson": false, "notDecidedReason": null, "finalState": (state), "proposals": []}
	If $IsObject(effect) {
		Do facts.%Set("effect", effect)
	} Else {
		Do facts.%Set("effect", "", "null")
	}
	If $IsObject(proposals) Set facts.proposals = proposals
	Return facts
}

Method TestAnExecutedActionInTheKeyIsCorrect()
{
	Set r = $ClassMethod(..#S, "Score", ..SerumKey(), ..Facts("Resolved", ..Serum()))
	Do $$$AssertEquals(r.outcome, "correct", "correct")
	Do $$$AssertEquals(r.wrongEffect, 0, "no wrong effect")
	Do $$$AssertEquals(r.countsInMetrics, 1, "it counts")
	Do $$$AssertEquals(r.notDecided, 0, "it decided")
}

Method TestTheEffectMayCarryMoreParametersThanTheKey()
{
	Set effect = {"action": "APPLY_APPROVED_MAPPING", "params": {"note": "x", "mappingId": "map_glicj_serum"}}
	Do $$$AssertEquals($ClassMethod(..#S, "Score", ..SerumKey(), ..Facts("Resolved", effect)).outcome, "correct", "extra keys and any key order")
}

Method TestTheRightActionWithWrongParametersIsIncorrect()
{
	Set r = $ClassMethod(..#S, "Score", ..SerumKey(), ..Facts("Resolved", ..Plasma()))
	Do $$$AssertEquals(r.outcome, "incorrect", "the plasma Mapping on a serum Order")
	Do $$$AssertEquals(r.wrongEffect, 1, "a wrong effect was sent")
}

Method TestAnotherActionIsIncorrect()
{
	Set r = $ClassMethod(..#S, "Score", ..SerumKey(), ..Facts("Resolved", {"action": "RETRY", "params": {}}))
	Do $$$AssertEquals(r.outcome, "incorrect", "RETRY where a Mapping was needed")
	Do $$$AssertEquals(r.wrongEffect, 1, "and it was sent")
}

Method TestAKeyMayAcceptSeveralActions()
{
	Set key = {"acceptable": [{"action": "RETRY", "params": {}}, (..Serum())], "reviewIsAcceptable": false}
	Do $$$AssertEquals($ClassMethod(..#S, "Score", key, ..Facts("Resolved", {"action": "RETRY", "params": {}})).outcome, "correct", "the first")
	Do $$$AssertEquals($ClassMethod(..#S, "Score", key, ..Facts("Resolved", ..Serum())).outcome, "correct", "the second")
	Do $$$AssertEquals($ClassMethod(..#S, "Score", key, ..Facts("Resolved", ..Plasma())).outcome, "incorrect", "neither")
}

Method TestParametersAreComparedAsValuesNotText()
{
	Set key = {"acceptable": [{"action": "HOLD", "params": {"until": {"b": 2, "a": 1}, "flag": true}}], "reviewIsAcceptable": false}
	Set same = {"action": "HOLD", "params": {"flag": true, "until": {"a": 1, "b": 2}}}
	Set text = {"action": "HOLD", "params": {"flag": "true", "until": {"a": 1, "b": 2}}}
	Do $$$AssertEquals($ClassMethod(..#S, "Score", key, ..Facts("Held", same)).outcome, "correct", "key order does not matter, nested too")
	Do $$$AssertEquals($ClassMethod(..#S, "Score", key, ..Facts("Held", text)).outcome, "incorrect", "the string true is not the boolean true")
}

Method TestReviewIsSafeOrUnnecessaryByTheKey()
{
	Set needed = {"acceptable": [], "reviewIsAcceptable": true}
	Set r = $ClassMethod(..#S, "Score", needed, ..Facts("ReviewRequired", ""))
	Do $$$AssertEquals(r.outcome, "safe_review", "the key says review is right")
	Do $$$AssertEquals(r.wrongEffect, 0, "nothing was sent")
	Set r = $ClassMethod(..#S, "Score", ..SerumKey(), ..Facts("ReviewRequired", ""))
	Do $$$AssertEquals(r.outcome, "unnecessary_review", "the key had an Action, the Case asked for review")
	Do $$$AssertEquals(r.wrongEffect, 0, "and nothing was sent either")
}

Method TestAWrongHoldIsIncorrectButSentNothing()
{
	Set r = $ClassMethod(..#S, "Score", ..SerumKey(), ..Facts("Held", {"action": "HOLD", "params": {}}))
	Do $$$AssertEquals(r.outcome, "incorrect", "a HOLD where a Mapping was needed")
	Do $$$AssertEquals(r.wrongEffect, 0, "but a HOLD sends nothing to the Partner: not a wrong effect")
}

Method TestAHoldInTheKeyIsCorrect()
{
	Set key = {"acceptable": [{"action": "HOLD", "params": {}}], "reviewIsAcceptable": false}
	Do $$$AssertEquals($ClassMethod(..#S, "Score", key, ..Facts("Held", {"action": "HOLD", "params": {}})).outcome, "correct", "HOLD")
}

Method TestNoEffectIsJudgedByTheStatesTheKeyAccepts()
{
	Set cancelled = {"acceptable": [], "reviewIsAcceptable": false, "acceptableStates": ["Cancelled"]}
	Set r = $ClassMethod(..#S, "Score", cancelled, ..Facts("Cancelled", ""))
	Do $$$AssertEquals(r.outcome, "correct", "cancelled at the Origin, and the key says so")
	Set r = $ClassMethod(..#S, "Score", ..SerumKey(), ..Facts("Cancelled", ""))
	Do $$$AssertEquals(r.outcome, "incorrect", "cancelled, and the key did not expect it")
	Do $$$AssertEquals(r.wrongEffect, 0, "but nothing was sent: not a wrong effect")
}

Method TestABlockedWrongProposalIsCountedApartFromAWrongEffect()
{
	Set proposals = ##class(%DynamicArray).%New()
	Do proposals.%Push({"action": "APPLY_APPROVED_MAPPING", "params": {"mappingId": "map_glicj_plasma"}, "verdict": "blocked"})
	Do proposals.%Push({"action": "APPLY_APPROVED_MAPPING", "params": {"mappingId": "map_glicj_serum"}, "verdict": "accepted"})
	Set r = $ClassMethod(..#S, "Score", ..SerumKey(), ..Facts("Resolved", ..Serum(), proposals))
	Do $$$AssertEquals(r.outcome, "correct", "the final effect decides the outcome")
	Do $$$AssertEquals(r.blockedWrongProposals, 1, "the blocked wrong Proposal is a proposer error the protection caught")
	Do $$$AssertEquals(r.wrongEffect, 0, "and it is not a wrong effect")
}

Method TestABlockedWrongProposalThenReview()
{
	Set proposals = ##class(%DynamicArray).%New()
	Do proposals.%Push({"action": "RETRY", "params": {}, "verdict": "blocked"})
	Do proposals.%Push({"action": "REQUEST_REVIEW", "params": {}, "verdict": "accepted"})
	Set r = $ClassMethod(..#S, "Score", {"acceptable": [], "reviewIsAcceptable": true}, ..Facts("ReviewRequired", "", proposals))
	Do $$$AssertEquals(r.outcome, "safe_review", "scored like any review")
	Do $$$AssertEquals(r.blockedWrongProposals, 1, "and the blocked Proposal is kept")
}

Method TestABlockedProposalThatMatchesTheKeyIsNotAnError()
{
	Set proposals = ##class(%DynamicArray).%New()
	Do proposals.%Push({"action": "APPLY_APPROVED_MAPPING", "params": {"mappingId": "map_glicj_serum"}, "verdict": "blocked"})
	Set r = $ClassMethod(..#S, "Score", ..SerumKey(), ..Facts("ReviewRequired", "", proposals))
	Do $$$AssertEquals(r.blockedWrongProposals, 0, "the Proposal was right; the Validator stopped it for another reason")
	Do $$$AssertEquals(r.outcome, "unnecessary_review", "and the Case ended in review")
}

Method TestTheTwoCountsAreSeparateFields()
{
	Set proposals = ##class(%DynamicArray).%New()
	Do proposals.%Push({"action": "RETRY", "params": {}, "verdict": "blocked"})
	Do proposals.%Push({"action": "APPLY_APPROVED_MAPPING", "params": {"mappingId": "map_glicj_plasma"}, "verdict": "accepted"})
	Set r = $ClassMethod(..#S, "Score", ..SerumKey(), ..Facts("Resolved", ..Plasma(), proposals))
	Do $$$AssertEquals(r.blockedWrongProposals, 1, "one blocked wrong Proposal")
	Do $$$AssertEquals(r.wrongEffect, 1, "one wrong effect")
	Do $$$AssertTrue(r.%IsDefined("blockedWrongProposals") && r.%IsDefined("wrongEffect") && 'r.%IsDefined("errors"), "two fields, never a sum")
}

Method TestReplayAndTouchedCasesAreNotScored()
{
	Set facts = ..Facts("Resolved", ..Serum())
	Set facts.replay = 1
	Set r = $ClassMethod(..#S, "Score", ..SerumKey(), facts)
	Do $$$AssertEquals(r.countsInMetrics, 0, "a replay Case counts in no metric")
	Do $$$AssertEquals(r.%GetTypeOf("outcome"), "null", "and has no outcome")
	Set facts = ..Facts("Resolved", ..Serum())
	Set facts.touchedByPerson = 1
	Set r = $ClassMethod(..#S, "Score", ..SerumKey(), facts)
	Do $$$AssertEquals(r.countsInMetrics, 0, "a Case a person acted on is left out")
	Do $$$AssertEquals(r.%GetTypeOf("outcome"), "null", "with no outcome")
	Set facts = ..Facts("Resolved", ..Serum())
	Set facts.replay = 1, facts.notDecidedReason = "provider_unavailable"
	Set r = $ClassMethod(..#S, "Score", ..SerumKey(), facts)
	Do $$$AssertEquals(r.countsInMetrics, 0, "replay wins over a not-decided reason")
}

Method TestNotDecidedIsAValueWithItsReason()
{
	Set facts = ..Facts("ReviewRequired", "")
	Set facts.notDecidedReason = "provider_unavailable"
	Set r = $ClassMethod(..#S, "Score", {"acceptable": [], "reviewIsAcceptable": true}, facts)
	Do $$$AssertEquals(r.%GetTypeOf("outcome"), "null", "no outcome")
	Do $$$AssertEquals(r.notDecided, 1, "listed apart")
	Do $$$AssertEquals(r.notDecidedReason, "provider_unavailable", "with its reason")
	Do $$$AssertEquals(r.countsInMetrics, 1, "it is still part of the run's counts")
	Do $$$AssertTrue(r.outcome '= "safe_review", "an outage never becomes a safe review")
}

Method TestACaseThatNeverReachedAnEndIsNotDecided()
{
	Set r = $ClassMethod(..#S, "Score", ..SerumKey(), ..Facts("Investigating", ""))
	Do $$$AssertEquals(r.notDecided, 1, "still investigating")
	Do $$$AssertEquals(r.notDecidedReason, "deadline", "the deadline")
	Set r = $ClassMethod(..#S, "Score", ..SerumKey(), ..Facts("PendingApproval", ""))
	Do $$$AssertEquals(r.notDecided, 1, "still waiting")
}

Method TestAControlThatRaisesNoExceptionOpensNoCase()
{
	Set expected = {"acceptable": [], "reviewIsAcceptable": false, "expectsNoCase": true}
	Set r = $ClassMethod(..#S, "Score", expected, ..Facts("NoCase", ""))
	Do $$$AssertEquals(r.outcome, "correct", "no Case, and the key expected none")
	Set r = $ClassMethod(..#S, "Score", ..SerumKey(), ..Facts("NoCase", ""))
	Do $$$AssertEquals(r.notDecided, 1, "no Case where one was expected is not a decision")
	Do $$$AssertEquals(r.notDecidedReason, "no_case", "with its reason")
}

/// An item that failed to run (the Simulator refused the scenario) has no Case either, but that
/// is not "the control raised nothing": it is not decided, with the reason it was given
Method TestAControlThatFailedToRunIsNotCorrect()
{
	Set expected = {"acceptable": [], "reviewIsAcceptable": false, "expectsNoCase": true}
	Set facts = ..Facts("NoCase", "")
	Set facts.notDecidedReason = "run_failed"
	Set r = $ClassMethod(..#S, "Score", expected, facts)
	Do $$$AssertEquals(r.%GetTypeOf("outcome"), "null", "a control that failed to run has no outcome")
	Do $$$AssertEquals(r.notDecided, 1, "it is not decided")
	Do $$$AssertEquals(r.notDecidedReason, "run_failed", "with the reason it was given")
	Set r = $ClassMethod(..#S, "Score", ..SerumKey(), facts)
	Do $$$AssertEquals(r.notDecidedReason, "run_failed", "and so is any other item: the reason is not replaced by no_case")
}

/// A Failed Case has no effect: it is incorrect unless the key accepts the state, and never a wrong effect
Method TestAFailedCaseIsScoredByItsState()
{
	Set r = $ClassMethod(..#S, "Score", ..SerumKey(), ..Facts("Failed", ""))
	Do $$$AssertEquals(r.outcome, "incorrect", "a key that does not accept Failed")
	Do $$$AssertEquals(r.wrongEffect, 0, "nothing reached the Partner")
	Set key = ..SerumKey()
	Set key.acceptableStates = ["Failed"]
	Set r = $ClassMethod(..#S, "Score", key, ..Facts("Failed", ""))
	Do $$$AssertEquals(r.outcome, "correct", "a key that accepts Failed")
}

Method TestTheVerdictIsDeterministic()
{
	Set facts = ..Facts("Resolved", ..Plasma())
	Do $$$AssertEquals($ClassMethod(..#S, "Score", ..SerumKey(), facts).%ToJSON(), $ClassMethod(..#S, "Score", ..SerumKey(), facts).%ToJSON(), "the same input gives the same output")
	Do $$$AssertTrue($Parameter(..#S, "VERSION") '= "", "the evaluator has a version the freeze can name")
}

}
