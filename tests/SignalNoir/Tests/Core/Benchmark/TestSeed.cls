Class SignalNoir.Tests.Core.Benchmark.TestSeed Extends %UnitTest.TestCase
{

/// 010 T012 - the per-item seed is a pure, deterministic function (FR-004).
/// The golden values were computed independently:
/// python: int.from_bytes(sha256("11|P5|P5-tune-01|1").digest()[:4], "big") & 0x7fffffff
Method TestGoldenValues()
{
	Set s = "SignalNoir.Core.Benchmark.Seed"
	Do $$$AssertEquals($ClassMethod(s, "For", 11, "P5", "P5-tune-01", 1), 1157120462, "base 11, P5, P5-tune-01, repetition 1")
	Do $$$AssertEquals($ClassMethod(s, "For", 11, "P5", "P5-tune-01", 2), 291581672, "repetition 2")
	Do $$$AssertEquals($ClassMethod(s, "For", 12, "P5", "P5-tune-01", 1), 843143347, "another base seed")
	Do $$$AssertEquals($ClassMethod(s, "For", 11, "P8", "P5-tune-01", 1), 400582325, "another family")
	Do $$$AssertEquals($ClassMethod(s, "For", 0, "P8", "P8b-tune-01", 3), 974639479, "base 0, P8b, repetition 3")
}

Method TestSameInputSameSeed()
{
	Set s = "SignalNoir.Core.Benchmark.Seed"
	Do $$$AssertEquals($ClassMethod(s, "For", 5, "P8", "P8b-tune-02", 2), $ClassMethod(s, "For", 5, "P8", "P8b-tune-02", 2), "twice")
}

Method TestEveryInputMatters()
{
	Set s = "SignalNoir.Core.Benchmark.Seed"
	Set base = $ClassMethod(s, "For", 5, "P8", "P8b-tune-02", 2)
	Do $$$AssertTrue(base '= $ClassMethod(s, "For", 6, "P8", "P8b-tune-02", 2), "base seed")
	Do $$$AssertTrue(base '= $ClassMethod(s, "For", 5, "P5", "P8b-tune-02", 2), "family")
	Do $$$AssertTrue(base '= $ClassMethod(s, "For", 5, "P8", "P8b-tune-01", 2), "variant")
	Do $$$AssertTrue(base '= $ClassMethod(s, "For", 5, "P8", "P8b-tune-02", 3), "repetition")
}

Method TestTheRangeIsThatOfTheSimulator()
{
	Set s = "SignalNoir.Core.Benchmark.Seed"
	For rep = 1 : 1 : 10 {
		Set v = $ClassMethod(s, "For", 7, "clean", "clean-success-tune-01", rep)
		Do $$$AssertTrue((v >= 0) && (v < 2147483648) && (v = (v \ 1)), "repetition " _ rep _ " is an integer in 0..2^31-1")
	}
}

}
