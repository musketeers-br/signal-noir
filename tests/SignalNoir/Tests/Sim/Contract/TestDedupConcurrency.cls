Class SignalNoir.Tests.Sim.Contract.TestDedupConcurrency Extends %UnitTest.TestCase
{

/// 002 T032 - 10 concurrent identical deliveries, one receipt (SC-004)
Method OnBeforeAllTests() As %Status
{
	Return ##class(SignalNoir.Sim.Setup).EnsureWebApplication()
}

Method TestTenRacers()
{
	Set C = "SignalNoir.Tests.Sim.Contract.Client"
	Set x = $ClassMethod(C, "Emitted", "clean", "clean-success-tune-01", 21)
	Set key = "idk_race_" _ $Extract(x.sci, 5, 20)
	Set ^SignalNoir.Tests.Sim.Race(key, "request") = $ClassMethod(C, "Delivery", x.sci, x.orders.%Get(0), key).%ToJSON()
	Set ^SignalNoir.Tests.Sim.Race(key, "path") = "/partners/" _ x.partnerId _ "/orders"
	For i = 1 : 1 : 10 Job ##class(SignalNoir.Tests.Sim.Contract.TestDedupConcurrency).Racer(key)
	Hang 0.5
	Set ^SignalNoir.Tests.Sim.Race(key, "go") = 1
	For i = 1 : 1 : 300 {
		Quit:($Get(^SignalNoir.Tests.Sim.Race(key, "done")) >= 10)
		Hang 0.1
	}
	Do $$$AssertEquals($Get(^SignalNoir.Tests.Sim.Race(key, "done")), 10, "ten answers")
	Kill ids
	Set j = ""
	For {
		Set j = $Order(^SignalNoir.Tests.Sim.Race(key, "receipt", j), 1, rid)
		Quit:j=""
		Set ids(rid) = ""
	}
	Set distinct = 0, r = ""
	For {
		Set r = $Order(ids(r))
		Quit:r=""
		Set distinct = distinct + 1
	}
	Do $$$AssertEquals(distinct, 1, "every caller got the same receipt")
	Set n = ##class(SignalNoir.Sim.Model.Receipt).CountByKey(key)
	Do $$$AssertEquals(n, 1, "exactly one receipt row")
	Kill ^SignalNoir.Tests.Sim.Race(key)
}

ClassMethod Racer(key As %String)
{
	For i = 1 : 1 : 500 {
		Quit:$Get(^SignalNoir.Tests.Sim.Race(key, "go"))
		Hang 0.01
	}
	Set r = ##class(SignalNoir.Tests.Sim.Contract.Client).Call("POST", ^SignalNoir.Tests.Sim.Race(key, "path"), {}.%FromJSON(^SignalNoir.Tests.Sim.Race(key, "request")))
	Set ^SignalNoir.Tests.Sim.Race(key, "receipt", $Job) = $Select($IsObject(r.body): r.body.receiptId, 1: "status " _ r.status)
	If $Increment(^SignalNoir.Tests.Sim.Race(key, "done"))
}

}
