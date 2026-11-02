Class SignalNoir.Tests.Application.Benchmark.TestFreezeData Extends %UnitTest.TestCase
{

/// 010 T048 - the committed records of the freeze, the roles, the reviews, the used sets and the
/// reference result load as JSON, carry only the keys they are meant to carry, and a review names
/// everything a review must (feature 010, plan D8).
Parameter D = "SignalNoir.Benchmark.Data.";

Method OnlyKeys(object, allowed As %String, label As %String) As %Boolean
{
	Set ok = 1, it = object.%GetIterator()
	While it.%GetNext(.key) {
		If (","_allowed_",") '[ ("," _ key _ ",") {
			Set ok = 0
			Do $$$AssertTrue(0, label _ ": unknown key " _ key)
		}
	}
	Return ok
}

Method TestTheFreezeRecordHasOnlyItsFields()
{
	Set freeze = $ClassMethod(..#D _ "Freeze", "Load", "Record")
	Do $$$AssertTrue($IsObject(freeze), "the record loads")
	Do $$$AssertTrue(..OnlyKeys(freeze, "freezeId,commit,frozenAt,promptVersion,model,baselineVersion,policyVersion,mappingVersion,policyDigest,mappingDigest,evaluatorVersion,reservedCatalogDigest,answerKeyDigest,files", "Freeze"), "no unknown key")
	Do $$$AssertEquals(freeze.%GetTypeOf("files"), "array", "files is a list")
	For i = 0 : 1 : freeze.files.%Size() - 1 {
		Do $$$AssertTrue(..OnlyKeys(freeze.files.%Get(i), "path,blob", "Freeze.files"), "a file entry names a path and a blob")
	}
}

Method TestTheRolesNameTwoHoldersPerFamily()
{
	Set roles = $ClassMethod(..#D _ "Roles", "Load", "Record")
	Do $$$AssertEquals(roles.%GetTypeOf("families"), "object", "families")
	Set it = roles.families.%GetIterator()
	While it.%GetNext(.family, .holders) {
		Do $$$AssertTrue(..OnlyKeys(holders, "answerKeyBy,baselineBy", "Roles." _ family), family _ ": no unknown key")
	}
}

Method TestEveryReviewNamesWhatAReviewMust()
{
	Set reviews = $ClassMethod(..#D _ "Reviews", "Load", "Records")
	Do $$$AssertTrue($IsObject(reviews) && reviews.%IsA("%Library.DynamicArray"), "a list")
	For i = 0 : 1 : reviews.%Size() - 1 {
		Set r = reviews.%Get(i)
		Do $$$AssertTrue(..OnlyKeys(r, "kind,family,author,reviewer,commit,date", "Reviews"), "no unknown key")
		Do $$$AssertTrue((r.kind = "baseline") || (r.kind = "evaluator"), "kind is baseline or evaluator")
		For key = "family", "author", "reviewer", "commit", "date" Do $$$AssertTrue(r.%Get(key) '= "", "review " _ i _ " has " _ key)
	}
}

Method TestEveryUsedSetNamesWhoWhenAndWhy()
{
	Set usage = $ClassMethod(..#D _ "SetUsage", "Load", "Records")
	Do $$$AssertTrue($IsObject(usage) && usage.%IsA("%Library.DynamicArray"), "a list")
	For i = 0 : 1 : usage.%Size() - 1 {
		Set u = usage.%Get(i)
		Do $$$AssertTrue(..OnlyKeys(u, "set,by,at,why", "SetUsage"), "no unknown key")
		Do $$$AssertTrue($Piece(u.set, "/", 2) = "test", "only a test set is declared used: " _ u.set)
		For key = "by", "at", "why" Do $$$AssertTrue(u.%Get(key) '= "", "entry " _ i _ " has " _ key)
	}
}

Method TestTheReferenceResultHasOnlyItsFields()
{
	Set ref = $ClassMethod(..#D _ "ReferenceResult", "Load", "Record")
	Do $$$AssertTrue(..OnlyKeys(ref, "recordedAt,provider,model,seed,cases,quickCases,recoverySuite", "ReferenceResult"), "no unknown key")
	Do $$$AssertEquals(ref.%GetTypeOf("cases"), "array", "cases is a list")
}

Method TestThePlaceholdersFreezeNothing()
{
	Set freeze = $ClassMethod(..#D _ "Freeze", "Load", "Record")
	If freeze.freezeId = "" Do $$$AssertEquals(freeze.commit, "", "a placeholder freeze names no commit")
}

}
