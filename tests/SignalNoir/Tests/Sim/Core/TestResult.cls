Class SignalNoir.Tests.Sim.Core.TestResult Extends %UnitTest.TestCase
{

/// 002 T009 - the Simulator's own result value
Method TestResult()
{
	Set r = ##class(SignalNoir.Sim.Result).Ok({"a": 1}, 201)
	Do $$$AssertEquals(r.ok _ ":" _ r.status _ ":" _ r.obj.a, "1:201:1", "ok with object and status")
	Do $$$AssertEquals(##class(SignalNoir.Sim.Result).Ok({}).status, 200, "default 200")
	Set e = ##class(SignalNoir.Sim.Result).Error("NOT_FOUND", "no such thing", {"id": "x"})
	Do $$$AssertEquals(e.ok _ ":" _ e.code _ ":" _ e.message _ ":" _ e.details.id, "0:NOT_FOUND:no such thing:x", "error keeps details")
	Do $$$AssertEquals(##class(SignalNoir.Sim.Result).Error("INVALID_REQUEST", "bad").details.%Size(), 0, "empty details")
}

}
