Class SignalNoir.Tests.Sim.Core.TestCanon Extends %UnitTest.TestCase
{

/// 002 T006 - canonical payload for deduplication (research D5, FR-017)
Method TestCanon()
{
	Set C = "SignalNoir.Sim.Canon"
	Set a = {"orderId": "O1", "patient": {"name": "Ana", "patientId": "P1"}, "exams": [{"code": "A"}, {"code": "b"}], "synthetic": true, "n": 3}
	Set b = {"n": 3, "synthetic": true, "exams": [{"code": "A"}, {"code": "b"}], "patient": {"patientId": "P1", "name": "Ana"}, "orderId": "O1"}
	Do $$$AssertEquals($ClassMethod(C, "Payload", a), $ClassMethod(C, "Payload", b), "key order does not matter, nested too")
	Set c = {"orderId": "O1", "patient": {"name": "Ana", "patientId": "P1"}, "exams": [{"code": "b"}, {"code": "A"}], "synthetic": true, "n": 3}
	Do $$$AssertTrue($ClassMethod(C, "Payload", a) '= $ClassMethod(C, "Payload", c), "array order matters")
	Set d = {"orderId": "O1", "patient": {"name": "Ana", "patientId": "P1"}, "exams": [{"code": "A"}, {"code": "b"}], "synthetic": true, "n": "3"}
	Do $$$AssertTrue($ClassMethod(C, "Payload", a) '= $ClassMethod(C, "Payload", d), "a number is not a string")
	Set e = {"collectedAt": "2026-10-23T07:00:00-03:00", "code": "gLiC-j"}
	Set p = $ClassMethod(C, "Payload", e)
	Do $$$AssertTrue((p [ "-03:00") && (p [ "gLiC-j"), "raw case and offsets preserved: " _ p)
}

}
