Class SignalNoir.Tests.Core.Benchmark.TestStats Extends %UnitTest.TestCase
{

Parameter S = "SignalNoir.Core.Benchmark.Stats";

/// 010 T037 - the statistics of contracts/scoring.md. The golden rows in tests/benchmark/golden
/// were computed by scripts/benchmark/recompute.py, which shares no code with this class: the
/// two implementations agreeing on them is the evidence that a report is reproducible.
ClassMethod Golden(name As %String) As %DynamicAbstractObject
{
	Set stream = ##class(%Stream.FileCharacter).%New()
	$$$ThrowOnError(stream.LinkToFile(##class(SignalNoir.Tests.Core.Validator.Repo).Path("tests/benchmark/golden/" _ name)))
	Return ##class(%DynamicAbstractObject).%FromJSON(stream.Read(stream.Size))
}

/// Every number of a row, in a stable line per path (numbers compared within 1e-9)
ClassMethod Flatten(value, path As %String, out As %DynamicObject)
{
	If $IsObject(value) {
		Set it = value.%GetIterator()
		While it.%GetNext(.k, .v) {
			Do ..Flatten(v, path _ "/" _ k, out)
		}
		Quit
	}
	Do out.%Set(path, value)
}

Method TestTheGoldenRowsAreReproduced()
{
	Set raw = ..Golden("cases.json")
	Set expected = ..Golden("stats.json")
	Set computed = $ClassMethod(..#S, "Rows", raw.cases, raw.mode)
	Do $$$AssertEquals(computed.%Size(), expected.%Size(), "the same groups")
	For i = 0 : 1 : expected.%Size() - 1 {
		Set want = {}, got = {}
		Do ..Flatten(expected.%Get(i), "", want)
		Do ..Flatten(computed.%Get(i), "", got)
		Set label = expected.%Get(i).family _ "/" _ expected.%Get(i).subtype _ "/" _ expected.%Get(i).set
		Set it = want.%GetIterator()
		While it.%GetNext(.path, .value) {
			If 'got.%IsDefined(path) {
				Do $$$AssertTrue(0, label _ path _ " is missing")
				Continue
			}
			Set actual = got.%Get(path)
			If (value = +value) && (actual = +actual) && (value '= "") {
				If $ZABS(value - actual) > 0.000000001 Do $$$AssertTrue(0, label _ path _ ": expected " _ value _ ", got " _ actual)
			} ElseIf value '= actual {
				Do $$$AssertTrue(0, label _ path _ ": expected " _ value _ ", got " _ actual)
			}
		}
		Set it = got.%GetIterator()
		While it.%GetNext(.path) {
			If 'want.%IsDefined(path) Do $$$AssertTrue(0, label _ path _ " is not in the expected row")
		}
	}
	Do $$$AssertTrue(1, "compared " _ expected.%Size() _ " groups")
}

Method TestNearestRank()
{
	Set s = ..#S
	Do $$$AssertEquals($ClassMethod(s, "NearestRank", [5, 1, 3, 2, 4], 50), 3, "median of five")
	Do $$$AssertEquals($ClassMethod(s, "NearestRank", [5, 1, 3, 2, 4], 95), 5, "with five values p95 is the maximum")
	Set twenty = []
	For i = 1 : 1 : 20 Do twenty.%Push(i)
	Do $$$AssertEquals($ClassMethod(s, "NearestRank", twenty, 95), 19, "with twenty values p95 is the 19th")
	Do $$$AssertEquals($ClassMethod(s, "NearestRank", [7], 95), 7, "one value")
	Do $$$AssertEquals($ClassMethod(s, "NearestRank", [10, 10, 20], 50), 10, "ties")
}

Method TestReplayTouchedAndPlatformRowsDoNotCount()
{
	Set cases = [
		{"family": "P5", "subtype": "P5", "variant": "v1", "set": "test", "repetition": 1, "outcome": "correct", "latencyMs": 100, "toolCalls": 1, "estCostUsd": 0.1, "countsInMetrics": true, "replay": false, "touchedByPerson": false, "blockedWrongProposals": 0, "wrongEffect": false},
		{"family": "P5", "subtype": "P5", "variant": "v2", "set": "test", "repetition": 1, "outcome": "correct", "latencyMs": 100, "toolCalls": 1, "estCostUsd": 0.1, "countsInMetrics": false, "replay": true, "touchedByPerson": false, "blockedWrongProposals": 0, "wrongEffect": false},
		{"family": "P5", "subtype": "P5", "variant": "v3", "set": "test", "repetition": 1, "outcome": "correct", "latencyMs": 100, "toolCalls": 1, "estCostUsd": 0.1, "countsInMetrics": true, "replay": false, "touchedByPerson": true, "blockedWrongProposals": 0, "wrongEffect": false},
		{"family": "P3", "subtype": "P3.x", "variant": "v4", "set": "test", "repetition": 1, "outcome": "correct", "latencyMs": 100, "toolCalls": 1, "estCostUsd": 0.1, "countsInMetrics": true, "replay": false, "touchedByPerson": false, "blockedWrongProposals": 0, "wrongEffect": false}
	]
	Set rows = $ClassMethod(..#S, "Rows", cases, "agent")
	Do $$$AssertEquals(rows.%Size(), 1, "only P5 forms a row")
	Do $$$AssertEquals(rows.%Get(0).variantCount, 1, "one variant counted")
	Do $$$AssertEquals(rows.%Get(0).denominator.withNotDecided.max, 1, "the replay and the touched Case are in no denominator")
}

Method TestARepetitionDoesNotAddAVariant()
{
	Set cases = []
	For rep = 1 : 1 : 3 {
		Do cases.%Push({"family": "P8", "subtype": "P8b", "variant": "only", "set": "test", "repetition": (rep), "outcome": "correct", "latencyMs": 100, "toolCalls": 1, "estCostUsd": 0.1, "countsInMetrics": true, "replay": false, "touchedByPerson": false, "blockedWrongProposals": 0, "wrongEffect": false})
	}
	Set row = $ClassMethod(..#S, "Rows", cases, "agent").%Get(0)
	Do $$$AssertEquals(row.variantCount, 1, "one variant, three repetitions")
	Do $$$AssertEquals(row.repetitionsCovered, 3, "three repetitions")
	Do $$$AssertEquals(row.denominator.withNotDecided.max, 1, "the denominator of a repetition is the number of variants")
	Do $$$AssertEquals(row.outcomes.correct.min, 1, "proportion 1 in every repetition")
}

Method TestAnOutageDoesNotBecomeASafeReview()
{
	Set cases = [
		{"family": "P8", "subtype": "P8b", "variant": "a", "set": "test", "repetition": 1, "outcome": "correct", "latencyMs": 100, "toolCalls": 1, "estCostUsd": 0.1, "countsInMetrics": true, "replay": false, "touchedByPerson": false, "blockedWrongProposals": 0, "wrongEffect": false},
		{"family": "P8", "subtype": "P8b", "variant": "b", "set": "test", "repetition": 1, "outcome": null, "notDecidedReason": "provider_unavailable", "latencyMs": null, "toolCalls": null, "estCostUsd": null, "countsInMetrics": true, "replay": false, "touchedByPerson": false, "blockedWrongProposals": 0, "wrongEffect": false}
	]
	Set row = $ClassMethod(..#S, "Rows", cases, "agent").%Get(0)
	Do $$$AssertEquals(row.counts.notDecided.max, 1, "listed apart")
	Do $$$AssertEquals(row.counts.%Get("safe_review").max, 0, "never a safe review")
	Do $$$AssertEquals(row.outcomes.correct.min, 0.5, "with the denominator that includes it")
	Do $$$AssertEquals(row.outcomesWithoutNotDecided.correct.min, 1, "and the one that does not")
}

}
