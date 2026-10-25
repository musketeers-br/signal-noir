Class SignalNoir.Tests.Core.TestCursor Extends %UnitTest.TestCase
{

/// 003 T040 - opaque (lastEventAt, caseId) cursor
Method TestRoundTrip()
{
	Set cur = ##class(SignalNoir.Core.Cursor).Encode("2026-10-25T10:00:00.123Z", "case_000042")
	Do $$$AssertTrue(cur '[ "case_", "opaque")
	Do $$$AssertTrue(##class(SignalNoir.Core.Cursor).Decode(cur, .at, .id), "decodes")
	Do $$$AssertEquals(at, "2026-10-25T10:00:00.123Z", "time")
	Do $$$AssertEquals(id, "case_000042", "caseId")
}

Method TestGarbageRefused()
{
	Do $$$AssertTrue('##class(SignalNoir.Core.Cursor).Decode("!!!not-base64!!!", .at, .id), "garbage")
	Do $$$AssertTrue('##class(SignalNoir.Core.Cursor).Decode(##class(SignalNoir.Core.Cursor).B64("only-one-part"), .at, .id), "one part")
	Do $$$AssertTrue('##class(SignalNoir.Core.Cursor).Decode(##class(SignalNoir.Core.Cursor).B64("yesterday|case_000001"), .at, .id), "not a UTC time")
	Do $$$AssertTrue('##class(SignalNoir.Core.Cursor).Decode(##class(SignalNoir.Core.Cursor).B64("2026-10-25T10:00:00Z|order_1"), .at, .id), "not a caseId")
}

}
