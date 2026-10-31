Class SignalNoir.Tests.Core.TestLexicalVector Extends %UnitTest.TestCase
{

/// 015 T003 - deterministic hashed vectors, same family closer
Method TestShapeAndDeterminism()
{
	Set lv = "SignalNoir.Core.LexicalVector"
	Set v = $ClassMethod(lv, "Of", "partner=A exception=timeout final=Resolved")
	Do $$$AssertEquals($ListLength(v), 1536, "1536 dimensions")
	Do $$$AssertEquals(v, $ClassMethod(lv, "Of", "partner=A exception=timeout final=Resolved"), "deterministic")
	Set norm = 0
	For i = 1 : 1 : $ListLength(v) Set norm = norm + ($ListGet(v, i) ** 2)
	Do $$$AssertTrue($ZAbs(norm - 1) < 0.0001, "unit length")
	Set zero = $ClassMethod(lv, "Of", "")
	Do $$$AssertEquals($ListLength(zero), 1536, "empty text has the same length")
	Do $$$AssertEquals($ClassMethod(lv, "Cosine", zero, v), 0, "zero vector similarity")
	Do $$$AssertEquals($ClassMethod(lv, "Of", "Partner=A"), $ClassMethod(lv, "Of", "partner=a"), "case-insensitive")
}

Method TestSameFamilyCloser()
{
	Set lv = "SignalNoir.Core.LexicalVector"
	Set q = $ClassMethod(lv, "Of", "partner=A exam=HB exception=timeout")
	Set same = $ClassMethod(lv, "Of", "partner=A exam=HB exception=timeout action=RETRY final=Resolved close=lt5m")
	Set other = $ClassMethod(lv, "Of", "partner=A exam=HB exception=http_error http=422 response=business_rejection action=APPLY_APPROVED_MAPPING final=Resolved")
	Set s1 = $ClassMethod(lv, "Cosine", q, same), s2 = $ClassMethod(lv, "Cosine", q, other)
	Do $$$AssertTrue(s1 > s2, "same family closer: " _ s1 _ " > " _ s2)
	Do $$$AssertTrue(s1 >= 0.5, "same family above the default minimum: " _ s1)
}

}
