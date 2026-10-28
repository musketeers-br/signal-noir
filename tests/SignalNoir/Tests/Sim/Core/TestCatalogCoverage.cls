Class SignalNoir.Tests.Sim.Core.TestCatalogCoverage Extends %UnitTest.TestCase
{

/// 002 T064 - every subtype has a tuning variant; test variants live in *Test classes
Parameter SUBTYPES = "clean.success,clean.partner_unavailable,clean.unknown_code_single_mapping,clean.already_processed,clean.ambiguous_identity,P1,P3.partner_fails_again,P3.maintenance_window,P3.cancelled_at_origin,P5,P5.injection,P8a,P8b,P9,idempotency.lost_receipt,idempotency.restart_during_executing,idempotency.repeated_approval";

Method TestCoverage()
{
	Set all = ##class(SignalNoir.Sim.Catalog.Loader).All().obj
	Kill tuning
	For i = 0 : 1 : all.%Size() - 1 {
		Set v = all.%Get(i)
		If v.set = "tuning" Set tuning(v.subtype) = ""
	}
	Set missing = ""
	For i = 1 : 1 : $Length(..#SUBTYPES, ",") {
		Set s = $Piece(..#SUBTYPES, ",", i)
		If '$Data(tuning(s)) Set missing = missing _ s _ " "
	}
	Do $$$AssertEquals(missing, "", "a tuning variant per subtype")
	Set misplaced = ""
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.CompiledClass WHERE Name %STARTSWITH 'SignalNoir.Sim.Catalog.'")
	While rs.%Next() {
		Set name = rs.%Get("Name")
		If '$ClassMethod(name, "%Extends", "SignalNoir.Sim.Catalog.Base") || (name = "SignalNoir.Sim.Catalog.Base") Continue
		Set list = [].%FromJSON(##class(%Dictionary.CompiledXData).%OpenId(name _ "||Variants").Data)
		For i = 0 : 1 : list.%Size() - 1 {
			If (list.%Get(i).set = "test") '= ($Extract(name, *-3, *) = "Test") Set misplaced = misplaced _ list.%Get(i).variant _ " "
		}
	}
	Do $$$AssertEquals(misplaced, "", "test variants only in *Test classes")
	Do $$$LogMessage("freeze ready (5 test variants each for P5 and P8b): " _ ..FreezeReady())
}

ClassMethod FreezeReady() As %Boolean
{
	Set all = ##class(SignalNoir.Sim.Catalog.Loader).All().obj, p5 = 0, p8 = 0
	For i = 0 : 1 : all.%Size() - 1 {
		Set v = all.%Get(i)
		If (v.set = "test") && (v.subtype = "P5") Set p5 = p5 + 1
		If (v.set = "test") && (v.subtype = "P8b") Set p8 = p8 + 1
	}
	Return (p5 >= 5) && (p8 >= 5)
}

}
