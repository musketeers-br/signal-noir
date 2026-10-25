Class SignalNoir.Tests.Core.TestCanon Extends %UnitTest.TestCase
{

/// 003 T014 - the equivalence key is computed only by the core and is the
/// same across exam order, letter case, duplicates and time-zone offsets
Method TestSameKeyAcrossVariants()
{
	Set a = ##class(SignalNoir.Tests.Core.TestOrderShape).ValidOrder()
	Set b = ##class(SignalNoir.Tests.Core.TestOrderShape).ValidOrder()
	Set b.exams = [{"code": "hb"}, {"code": "GLICJ"}, {"code": "Hb"}]
	Set b.specimen.collectedAt = "2026-10-23T10:00:00Z"
	Set ka = ##class(SignalNoir.Core.Canon).FromSnapshot(a)
	Set kb = ##class(SignalNoir.Core.Canon).FromSnapshot(b)
	Do $$$AssertEquals(ka, kb, "same key")
	Do $$$AssertEquals(ka, "P-1|GLICJ,HB|2026-10-23T10:00:00Z|SP-1", "canonical shape")
}

Method TestNormalizeUtcOffsets()
{
	Set c = "SignalNoir.Core.Canon"
	Do $$$AssertEquals($ClassMethod(c, "NormalizeUtc", "2026-10-23T07:00:00-03:00"), "2026-10-23T10:00:00Z", "-03:00")
	Do $$$AssertEquals($ClassMethod(c, "NormalizeUtc", "2026-10-23T07:00:00-0300"), "2026-10-23T10:00:00Z", "-0300")
	Do $$$AssertEquals($ClassMethod(c, "NormalizeUtc", "2026-10-23T12:30:00+02:00"), "2026-10-23T10:30:00Z", "+02:00")
	Do $$$AssertEquals($ClassMethod(c, "NormalizeUtc", "2026-10-23T10:00:00.250Z"), "2026-10-23T10:00:00Z", "fraction dropped")
	Do $$$AssertEquals($ClassMethod(c, "NormalizeUtc", "2026-10-23 10:00:00"), "2026-10-23T10:00:00Z", "space separator, no zone = UTC")
	Do $$$AssertEquals($ClassMethod(c, "NormalizeUtc", "2026-10-23T22:30:00-03:00"), "2026-10-24T01:30:00Z", "rollover to next day")
	Do $$$AssertEquals($ClassMethod(c, "NormalizeUtc", "2026-01-01T01:00:00+03:00"), "2025-12-31T22:00:00Z", "rollover to previous year")
	Do $$$AssertEquals($ClassMethod(c, "NormalizeUtc", "yesterday"), "", "unreadable")
	Do $$$AssertEquals($ClassMethod(c, "NormalizeUtc", "2026-13-40T10:00:00Z"), "", "invalid date")
}

Method TestPartsOfKey()
{
	Set parts = ##class(SignalNoir.Core.Canon).Parts("P-1|GLICJ,HB|2026-10-23T10:00:00Z|SP-1")
	Do $$$AssertEquals(parts.patientId, "P-1", "patientId")
	Do $$$AssertEquals(parts.examCodes.%Size(), 2, "two codes")
	Do $$$AssertEquals(parts.examCodes.%Get(1), "HB", "ordered codes")
	Do $$$AssertEquals(parts.collectedAt, "2026-10-23T10:00:00Z", "collectedAt")
	Do $$$AssertEquals(parts.specimenId, "SP-1", "specimenId")
}

}
