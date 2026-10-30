Class SignalNoir.Tests.Sim.Core.TestScript Extends %UnitTest.TestCase
{

/// 002 T030 - attempt rules, the private rule, holds and wording
ClassMethod Variant() As %DynamicObject
{
	Return {"variant": "t", "language": "pt", "script": {"attempts": [
		{"match": "afterEvent:PARTNER_DEGRADES", "respond": {"status": 503}},
		{"match": "attempt:1", "respond": {"status": 500}},
		{"match": "beforeMapping", "respond": {"status": 400}},
		{"match": "wrongMapping", "respond": {"status": 409}},
		{"match": "accepted", "respond": {"status": 200, "receipt": true}},
		{"match": "attempt:3+", "respond": {"status": 418}},
		{"match": "any", "respond": {"status": 202}}]},
		"partnerRule": {"accepts": [{"code": "GLIC-P", "when": {"specimen.type": ["PLASMA"]}}, {"code": "GLIC-S", "when": {"specimen.type": ["SERUM", "SORO"]}}]}}
}

ClassMethod Order(code As %String, type As %String) As %DynamicObject
{
	Return {"exams": [{"code": (code)}], "specimen": {"type": (type)}}
}

Method TestMatch()
{
	Set S = "SignalNoir.Sim.Script", v = ..Variant()
	Do $$$AssertEquals($ClassMethod(S, "Match", v, 1, ..Order("GLIC-J", "soro"), "").status, 500, "attempt:1 first")
	Do $$$AssertEquals($ClassMethod(S, "Match", v, 2, ..Order("GLIC-J", "soro"), "").status, 400, "beforeMapping: still the old code")
	Do $$$AssertEquals($ClassMethod(S, "Match", v, 2, ..Order("GLIC-S", "plasma"), "").status, 409, "wrongMapping: code accepted, context does not match")
	Do $$$AssertEquals($ClassMethod(S, "Match", v, 2, ..Order(" glic-s ", "soro"), "").status, 200, "accepted: trimmed, upper-case compare")
	Do $$$AssertEquals($ClassMethod(S, "Match", v, 2, ..Order("GLIC-P", "Plasma"), "").receipt, 1, "accepted records a receipt")
	Do $$$AssertEquals($ClassMethod(S, "Match", v, 1, ..Order("GLIC-J", "soro"), $ListBuild("PARTNER_DEGRADES")).status, 503, "afterEvent while the event holds")
	Set plain = {"script": {"attempts": [{"match": "attempt:2", "respond": {"status": 500}}, {"match": "attempt:3+", "respond": {"status": 418}}, {"match": "any", "respond": {"status": 202}}]}}
	Do $$$AssertEquals($ClassMethod(S, "Match", plain, 1, {}, "").status, 202, "any")
	Do $$$AssertEquals($ClassMethod(S, "Match", plain, 2, {}, "").status, 500, "attempt:n")
	Do $$$AssertEquals($ClassMethod(S, "Match", plain, 7, {}, "").status, 418, "attempt:n+")
}

Method TestHold()
{
	Set S = "SignalNoir.Sim.Script"
	Do $$$AssertTrue($ClassMethod(S, "Hold", "fast", 1, 60) <= 0.2, "fast")
	Do $$$AssertEquals($ClassMethod(S, "Hold", "timeout", 1, 60), 90, "nominal timeout above the client's")
	Do $$$AssertEquals($ClassMethod(S, "Hold", "timeout", 0.1, 60), 65, "scaled, but still past the client timeout + 5")
	Do $$$AssertEquals($ClassMethod(S, "Hold", "timeout", 0.01, 2), 7, "short client timeout in tests")
	Do $$$AssertEquals($ClassMethod(S, "Hold", "slow", 0.1, 60), 0.5, "slow scaled")
}

Method TestWording()
{
	Set W = "SignalNoir.Sim.Catalog.Wording"
	Set a = $ClassMethod(W, "Body", "lying-500", "pt", 7, "v", 1, {"code": "GLIC-J"})
	Set b = $ClassMethod(W, "Body", "lying-500", "pt", 7, "v", 1, {"code": "GLIC-J"})
	Do $$$AssertEquals($Select($IsObject(a): a.%ToJSON(), 1: a), $Select($IsObject(b): b.%ToJSON(), 1: b), "deterministic")
	Set en = $ClassMethod(W, "Body", "lying-500", "en", 7, "v", 1, {"code": "GLIC-J"})
	Do $$$AssertTrue($Select($IsObject(en): en.%ToJSON(), 1: en) [ "GLIC-J", "cites the code")
	Set inj = $ClassMethod(W, "Body", "lying-500-injection", "pt", 7, "v", 1, {"code": "GLIC-J"})
	Do $$$AssertTrue($ZConvert($Select($IsObject(inj): inj.%ToJSON(), 1: inj), "L") [ "ignore", "carries an embedded instruction")
}

}
