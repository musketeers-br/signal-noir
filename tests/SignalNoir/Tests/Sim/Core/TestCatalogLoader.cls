Class SignalNoir.Tests.Sim.Core.TestCatalogLoader Extends %UnitTest.TestCase
{

/// 002 T008 - the catalog loader and its served form (contracts/scenario-script.md)
Method TestAll()
{
	Set L = "SignalNoir.Sim.Catalog.Loader"
	Set all = $ClassMethod(L, "All")
	Do $$$AssertTrue(all.ok, "loaded: " _ all.message)
	Do $$$AssertTrue(all.obj.%Size() >= 1, "at least one variant")
	Set v = $ClassMethod(L, "Find", "clean", "clean-success-tune-01")
	Do $$$AssertTrue($IsObject(v), "found by family and variant")
	Do $$$AssertEquals(v.subtype, "clean.success", "subtype")
	Do $$$AssertEquals($ClassMethod(L, "Find", "P5", "clean-success-tune-01"), "", "family must match")
}

Method TestDuplicateRefused()
{
	Set r = ##class(SignalNoir.Sim.Catalog.Loader).Check([{"variant": "x-1", "family": "clean"}, {"variant": "x-1", "family": "P5"}])
	Do $$$AssertNotTrue(r.ok, "duplicate variant id refused")
	Do $$$AssertTrue(r.message [ "x-1", "names it")
}

Method TestServedForm()
{
	Set L = "SignalNoir.Sim.Catalog.Loader"
	Set v = {"family": "P8", "subtype": "P8b", "variant": "t", "set": "tuning", "partnerId": "labpartner-a", "language": "mixed", "description": "d", "orders": [{"exams": ["GLIC-J"], "quirks": ["mixed-case codes"]}, {"exams": ["X"]}], "script": {"attempts": []}, "partnerRule": {"accepts": [{"code": "GLIC-S"}]}}
	Set s = $ClassMethod(L, "Served", v)
	Do $$$AssertNotTrue(s.%IsDefined("partnerRule"), "no partnerRule")
	Do $$$AssertNotTrue(s.%ToJSON() [ "GLIC-S", "no private value")
	Do $$$AssertEquals(s.%IsDefined("orders"), 0, "orders not served as such")
	Do $$$AssertEquals(s.script.emission.orders, 2, "order count")
	Do $$$AssertEquals(s.script.emission.quirks.%Get(0), "mixed-case codes", "declared quirks")
	For f = "family", "subtype", "variant", "set", "partnerId", "language" Do $$$AssertTrue(s.%IsDefined(f), "keeps " _ f)
}

Method TestFilters()
{
	Set L = "SignalNoir.Sim.Catalog.Loader"
	Set wrong = 0
	Set items = $ClassMethod(L, "List", "clean", "")
	Do $$$AssertTrue(items.%Size() > 0, "clean variants")
	For i = 0 : 1 : items.%Size() - 1 If items.%Get(i).family '= "clean" Set wrong = wrong + 1
	Set items = $ClassMethod(L, "List", "", "test")
	Do $$$AssertTrue(items.%Size() > 0, "test variants")
	For i = 0 : 1 : items.%Size() - 1 If items.%Get(i).set '= "test" Set wrong = wrong + 1
	Do $$$AssertEquals(wrong, 0, "filters hold")
}

}
