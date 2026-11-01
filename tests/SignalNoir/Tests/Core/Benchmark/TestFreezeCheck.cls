Class SignalNoir.Tests.Core.Benchmark.TestFreezeCheck Extends %UnitTest.TestCase
{

Parameter F = "SignalNoir.Core.Benchmark.FreezeCheck";

/// 010 T046 - what makes a run development data (FR-026, FR-027, FR-029, plan D8): a frozen
/// input that differs from the freeze record, a test set declared used, roles that are not
/// held by different people, a missing review, no freeze at all. Pure: records in, reasons out.
ClassMethod Freeze() As %DynamicObject
{
	Return {"freezeId": "freeze_1", "commit": "abc1234", "promptVersion": "agent-v1", "model": "gpt-x", "baselineVersion": "rules-v2", "policyVersion": "2026.10.1", "mappingVersion": "2026.10.1", "policyDigest": "pd", "mappingDigest": "md", "evaluatorVersion": "scorer-v1", "reservedCatalogDigest": "rc", "answerKeyDigest": "ak"}
}

ClassMethod Current() As %DynamicObject
{
	Return {"promptVersion": "agent-v1", "model": "gpt-x", "baselineVersion": "rules-v2", "policyVersion": "2026.10.1", "mappingVersion": "2026.10.1", "policyDigest": "pd", "mappingDigest": "md", "evaluatorVersion": "scorer-v1", "reservedCatalogDigest": "rc", "answerKeyDigest": "ak"}
}

ClassMethod Roles() As %DynamicObject
{
	Return {"families": {"P5": {"answerKeyBy": "henrique", "baselineBy": "henry"}, "P8": {"answerKeyBy": "henrique", "baselineBy": "henry"}}}
}

ClassMethod Reviews() As %DynamicArray
{
	Return [
		{"kind": "baseline", "family": "P5", "author": "henry", "reviewer": "jose", "commit": "r1", "date": "2026-11-03"},
		{"kind": "baseline", "family": "P8", "author": "henry", "reviewer": "jose", "commit": "r1", "date": "2026-11-03"},
		{"kind": "evaluator", "family": "*", "author": "henrique", "reviewer": "jose", "commit": "r2", "date": "2026-11-03"}
	]
}

ClassMethod Selection() As %DynamicObject
{
	Return {"purpose": "reference", "variants": [{"family": "P5", "set": "test", "variant": "P5-test-01"}, {"family": "P8", "set": "test", "variant": "P8b-test-01"}]}
}

ClassMethod Run(freeze, current, roles, reviews, usage, selection) As %DynamicObject
{
	Return $ClassMethod(..#F, "Evaluate", freeze, current, roles, reviews, usage, selection)
}

Method TestEverythingInOrderIsNotDevelopment()
{
	Set r = ..Run(..Freeze(), ..Current(), ..Roles(), ..Reviews(), [], ..Selection())
	Do $$$AssertEquals(r.development, 0, "not development: " _ r.reasons.%ToJSON())
	Do $$$AssertEquals(r.reasons.%Size(), 0, "no reason")
}

Method TestEachFrozenInputThatDiffersIsNamed()
{
	For field = "promptVersion", "model", "baselineVersion", "policyVersion", "mappingVersion", "policyDigest", "mappingDigest", "evaluatorVersion", "reservedCatalogDigest", "answerKeyDigest" {
		Set current = ..Current()
		Do current.%Set(field, "changed")
		Set r = ..Run(..Freeze(), current, ..Roles(), ..Reviews(), [], ..Selection())
		Do $$$AssertEquals(r.development, 1, field _ " differs: development")
		Do $$$AssertTrue(r.reasons.%ToJSON() [ field, field _ " is named in the reason")
	}
}

Method TestNoFreezeRecordIsDevelopment()
{
	Set r = ..Run({"freezeId": ""}, ..Current(), ..Roles(), ..Reviews(), [], ..Selection())
	Do $$$AssertEquals(r.development, 1, "development")
	Do $$$AssertTrue(r.reasons.%ToJSON() [ "no freeze", "and says there is no freeze")
	Set r = ..Run("", ..Current(), ..Roles(), ..Reviews(), [], ..Selection())
	Do $$$AssertEquals(r.development, 1, "an absent record too")
}

Method TestATestSetDeclaredUsedMarksEveryRunOverIt()
{
	Set r = ..Run(..Freeze(), ..Current(), ..Roles(), ..Reviews(), [{"set": "P5/test", "by": "henrique", "at": "2026-11-04", "why": "tuned the prompt on it"}], ..Selection())
	Do $$$AssertEquals(r.development, 1, "development")
	Do $$$AssertTrue(r.reasons.%ToJSON() [ "P5", "the family is named")
	Set other = {"purpose": "benchmark", "variants": [{"family": "P8", "set": "test", "variant": "P8b-test-01"}]}
	Set r = ..Run(..Freeze(), ..Current(), ..Roles(), ..Reviews(), [{"set": "P5/test", "by": "x", "at": "y", "why": "z"}], other)
	Do $$$AssertEquals(r.development, 0, "a run over a set that was not used is not affected")
	Set mine = {"purpose": "benchmark", "variants": [{"family": "P5", "set": "test", "variant": "P5-test-01"}]}
	Set r = ..Run("", "", "", "", [{"set": "P5/test", "by": "x", "at": "y", "why": "z"}], mine)
	Do $$$AssertEquals(r.development, 1, "whatever the purpose, a used set is development data")
}

Method TestTheSamePersonInTwoRolesIsDevelopment()
{
	Set roles = ..Roles()
	Set roles.families.P5.baselineBy = "henrique"
	Set r = ..Run(..Freeze(), ..Current(), roles, ..Reviews(), [], ..Selection())
	Do $$$AssertEquals(r.development, 1, "key author and baseline author are the same")
	Do $$$AssertTrue(r.reasons.%ToJSON() [ "P5", "for P5")
	Set reviews = ..Reviews()
	Set reviews.%Get(1).reviewer = "henry"
	Set r = ..Run(..Freeze(), ..Current(), ..Roles(), reviews, [], ..Selection())
	Do $$$AssertEquals(r.development, 1, "the reviewer wrote the baseline")
	Set reviews = ..Reviews()
	Set reviews.%Get(0).reviewer = "henrique"
	Set r = ..Run(..Freeze(), ..Current(), ..Roles(), reviews, [], ..Selection())
	Do $$$AssertEquals(r.development, 1, "the reviewer prepared the answer key")
}

Method TestAMissingOrIncompleteReviewIsDevelopment()
{
	Set reviews = ..Reviews()
	Do reviews.%Remove(0)
	Set r = ..Run(..Freeze(), ..Current(), ..Roles(), reviews, [], ..Selection())
	Do $$$AssertEquals(r.development, 1, "no baseline review for P5")
	Do $$$AssertTrue(r.reasons.%ToJSON() [ "baseline review", "and the reason says so")
	Set reviews = ..Reviews()
	Do reviews.%Remove(2)
	Set r = ..Run(..Freeze(), ..Current(), ..Roles(), reviews, [], ..Selection())
	Do $$$AssertEquals(r.development, 1, "no evaluator review")
	Set reviews = ..Reviews()
	Set reviews.%Get(0).commit = ""
	Set r = ..Run(..Freeze(), ..Current(), ..Roles(), reviews, [], ..Selection())
	Do $$$AssertEquals(r.development, 1, "a review with no commit does not count")
	Set r = ..Run(..Freeze(), ..Current(), {"families": {}}, ..Reviews(), [], ..Selection())
	Do $$$AssertEquals(r.development, 1, "no roles recorded")
}

Method TestOnlyAReferenceRunNeedsTheFreezeAndTheRoles()
{
	Set tuning = {"purpose": "benchmark", "variants": [{"family": "P5", "set": "tuning", "variant": "P5-tune-01"}]}
	Set r = ..Run({"freezeId": ""}, ..Current(), {"families": {}}, [], [], tuning)
	Do $$$AssertEquals(r.development, 0, "a benchmark run over tuning variants is not judged against the freeze")
}

Method TestSeveralReasonsAreAllListed()
{
	Set current = ..Current()
	Set current.promptVersion = "other"
	Set roles = ..Roles()
	Set roles.families.P8.baselineBy = "henrique"
	Set r = ..Run(..Freeze(), current, roles, ..Reviews(), [], ..Selection())
	Do $$$AssertTrue(r.reasons.%Size() >= 2, "every reason, not the first: " _ r.reasons.%ToJSON())
}

Method TestTheDecisionIsDeterministic()
{
	Set a = ..Run(..Freeze(), ..Current(), ..Roles(), ..Reviews(), [], ..Selection()).%ToJSON()
	Set b = ..Run(..Freeze(), ..Current(), ..Roles(), ..Reviews(), [], ..Selection()).%ToJSON()
	Do $$$AssertEquals(a, b, "same input, same answer")
}

}
