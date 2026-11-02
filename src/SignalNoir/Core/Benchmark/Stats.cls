Class SignalNoir.Core.Benchmark.Stats Extends %RegisteredObject
{

/// The statistics of a report (feature 010, contracts/scoring.md "Statistics"). Pure: rows
/// of Cases in, rows of the agent decision part out. Per repetition it counts the outcomes,
/// takes their proportion over the variants of that repetition (with and without the Cases
/// that did not decide), the nearest-rank p50 and p95 latency and the means of tool calls
/// and cost; the figure published is the minimum and maximum of that value over the
/// repetitions. A variant therefore enters every denominator once. scripts/benchmark/recompute.py
/// is an independent implementation of the same rules.
Parameter OUTCOMES = "correct,safe_review,unnecessary_review,incorrect";

Parameter SCORED = "clean,P5,P8,P9";

/// cases: array of {family, subtype, variant, set, repetition, outcome, latencyMs, toolCalls,
/// estCostUsd, countsInMetrics, replay, touchedByPerson, blockedWrongProposals, wrongEffect}.
/// Returns the rows, one per (family, subtype, set), in that order, for the given mode.
ClassMethod Rows(cases As %DynamicArray, mode As %String) As %DynamicArray
{
	Set sep = $Char(1)
	For i = 0 : 1 : cases.%Size() - 1 {
		Set c = cases.%Get(i)
		If '..Counted(c) Continue
		Set key = c.family _ sep _ c.subtype _ sep _ c.set
		Set n = $Increment(g(key, c.repetition))
		Set g(key, c.repetition, n) = i
		Set v(key, c.variant) = ""
	}
	Set out = []
	Set key = ""
	For {
		Set key = $Order(g(key))
		Quit:key=""
		Do out.%Push(..Row(cases, key, mode, .g, .v))
	}
	Return out
}

/// A row takes part in the agent decision metrics: it counts, is no replay, no person touched
/// it, and its family is one of the scored ones (P3 and idempotency feed the guarantees only)
ClassMethod Counted(c As %DynamicObject) As %Boolean
{
	If 'c.%Get("countsInMetrics") Return 0
	If c.%Get("replay") || c.%Get("touchedByPerson") Return 0
	Return ((","_..#SCORED_",") [ ("," _ c.family _ ","))
}

ClassMethod Row(cases As %DynamicArray, key As %String, mode As %String, ByRef g, ByRef v) As %DynamicObject [ Private ]
{
	Set sep = $Char(1)
	Set row = {"family": ($Piece(key, sep, 1)), "subtype": ($Piece(key, sep, 2)), "set": ($Piece(key, sep, 3)), "mode": (mode)}
	Set variants = 0, name = ""
	For {
		Set name = $Order(v(key, name))
		Quit:name=""
		Set variants = variants + 1
	}
	Set row.variantCount = variants
	Set reps = 0, rep = "", small = 0
	For {
		Set rep = $Order(g(key, rep))
		Quit:rep=""
		Set reps = reps + 1
		Kill one
		Do ..Repetition(cases, key, rep, .g, .one)
		Merge r(reps) = one
		If one("n") < 20 Set small = 1
	}
	Set row.repetitionsCovered = reps
	Set names = $ListFromString(..#OUTCOMES, ",")
	Set outcomes = {}, without = {}, counts = {}
	For k = 1 : 1 : $ListLength(names) {
		Set name = $List(names, k)
		Do outcomes.%Set(name, ..RangeOf(.r, reps, "with", name))
		Do without.%Set(name, ..RangeOf(.r, reps, "without", name))
		Do counts.%Set(name, ..RangeOf(.r, reps, "count", name))
	}
	Do counts.%Set("notDecided", ..RangeOf(.r, reps, "count", "notDecided"))
	Set row.outcomes = outcomes, row.outcomesWithoutNotDecided = without, row.counts = counts
	Set row.denominator = {"withNotDecided": (..RangeOf(.r, reps, "n", "")), "withoutNotDecided": (..RangeOf(.r, reps, "decided", ""))}
	Set row.latencyMsP50 = ..RangeOf(.r, reps, "p50", "")
	Set row.latencyMsP95 = ..RangeOf(.r, reps, "p95", "")
	Set row.toolCallsPerCase = ..RangeOf(.r, reps, "calls", "")
	Set row.estCostUsdPerCase = ..RangeOf(.r, reps, "cost", "")
	; a measure that no Case of a repetition had is null, never an empty string
	For key = "latencyMsP50", "latencyMsP95", "toolCallsPerCase", "estCostUsdPerCase" {
		If row.%GetTypeOf(key) '= "object" Do row.%Set(key, "", "null")
	}
	Set row.blockedWrongProposals = ..RangeOf(.r, reps, "blocked", "")
	Set row.wrongEffects = ..RangeOf(.r, reps, "wrong", "")
	If small {
		Set row.note = "p95 is the maximum of a repetition when it has fewer than 20 Cases"
	} Else {
		Do row.%Set("note", "", "null")
	}
	Return row
}

/// One repetition of one group, into one(...)
ClassMethod Repetition(cases As %DynamicArray, key As %String, rep As %Integer, ByRef g, ByRef one) [ Private ]
{
	Set n = g(key, rep)
	Set one("n") = n
	For k = 1 : 1 : $ListLength($ListFromString(..#OUTCOMES, ",")) Set one("count", $List($ListFromString(..#OUTCOMES, ","), k)) = 0
	Set one("count", "notDecided") = 0
	Set lat = [], calls = 0, callsN = 0, cost = 0, costN = 0, blocked = 0, wrong = 0
	For j = 1 : 1 : n {
		Set c = cases.%Get(g(key, rep, j))
		Set outcome = $Select(c.%GetTypeOf("outcome") = "string": c.outcome, 1: "")
		If (outcome '= "") && $Data(one("count", outcome)) {
			Set one("count", outcome) = one("count", outcome) + 1
		} Else {
			Set one("count", "notDecided") = one("count", "notDecided") + 1
		}
		If c.%GetTypeOf("latencyMs") = "number" Do lat.%Push(c.latencyMs)
		If c.%GetTypeOf("toolCalls") = "number" Set calls = calls + c.toolCalls, callsN = callsN + 1
		If c.%GetTypeOf("estCostUsd") = "number" Set cost = cost + c.estCostUsd, costN = costN + 1
		Set blocked = blocked + +c.%Get("blockedWrongProposals")
		If c.%Get("wrongEffect") Set wrong = wrong + 1
	}
	Set decided = n - one("count", "notDecided")
	Set one("decided") = decided
	For k = 1 : 1 : $ListLength($ListFromString(..#OUTCOMES, ",")) {
		Set name = $List($ListFromString(..#OUTCOMES, ","), k)
		Set one("with", name) = one("count", name) / n
		Set one("without", name) = $Select(decided: one("count", name) / decided, 1: "")
	}
	Set one("p50") = $Select(lat.%Size(): ..NearestRank(lat, 50), 1: "")
	Set one("p95") = $Select(lat.%Size(): ..NearestRank(lat, 95), 1: "")
	Set one("calls") = $Select(callsN: calls / callsN, 1: "")
	Set one("cost") = $Select(costN: cost / costN, 1: "")
	Set one("blocked") = blocked
	Set one("wrong") = wrong
}

/// {min, max} of a measure over the repetitions, or null when any repetition lacks it
ClassMethod RangeOf(ByRef r, reps As %Integer, kind As %String, name As %String) As %DynamicObject [ Private ]
{
	Set min = "", max = ""
	For i = 1 : 1 : reps {
		If kind = "with" {
			Set x = r(i, "with", name)
		} ElseIf kind = "without" {
			Set x = r(i, "without", name)
		} ElseIf kind = "count" {
			Set x = r(i, "count", name)
		} Else {
			Set x = r(i, kind)
		}
		If x = "" Return ""
		If (min = "") || (x < min) Set min = x
		If (max = "") || (x > max) Set max = x
	}
	Return {"min": (min), "max": (max)}
}

/// Nearest-rank percentile: sort ascending, take the value at index ceil(p/100 * n), 1-based
ClassMethod NearestRank(values As %DynamicArray, p As %Integer) As %Numeric
{
	Set n = values.%Size()
	For i = 0 : 1 : n - 1 {
		Set sorted($Increment(count)) = values.%Get(i)
	}
	For i = 2 : 1 : n {
		Set held = sorted(i), j = i - 1
		While (j >= 1) && (sorted(j) > held) {
			Set sorted(j + 1) = sorted(j), j = j - 1
		}
		Set sorted(j + 1) = held
	}
	Set rank = (p * n) / 100
	Set index = rank \ 1
	If rank > index Set index = index + 1
	If index < 1 Set index = 1
	Return sorted(index)
}

}
