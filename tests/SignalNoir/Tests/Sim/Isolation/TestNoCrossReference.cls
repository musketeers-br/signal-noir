Class SignalNoir.Tests.Sim.Isolation.TestNoCrossReference Extends %UnitTest.TestCase
{

/// 002 T007 - the Simulator is reached only over HTTP (research D10):
/// nothing outside SignalNoir.Sim references it, and it references no product package
Method TestBoundary()
{
	Set bad = ""
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.ClassDefinition WHERE Name %STARTSWITH 'SignalNoir.'")
	While rs.%Next() {
		Set name = rs.%Get("Name")
		Set inSim = ($Extract(name, 1, 15) = "SignalNoir.Sim.")
		If $Extract(name, 1, 21) = "SignalNoir.Tests.Sim." Continue
		Set text = ..Text(name)
		If 'inSim && (text [ "SignalNoir.Sim.") Set bad = bad _ name _ " references SignalNoir.Sim; "
		If inSim && $Locate(text, "SignalNoir\.(?!Sim\.)") Set bad = bad _ name _ " references a product package; "
	}
	Do $$$AssertEquals(bad, "", "no reference across the boundary")
}

/// Super, property types, method signatures and implementations of a class
ClassMethod Text(name As %String) As %String
{
	Set def = ##class(%Dictionary.ClassDefinition).%OpenId(name)
	If '$IsObject(def) Return ""
	Set text = def.Super _ " "
	For i = 1 : 1 : def.Properties.Count() Set text = text _ def.Properties.GetAt(i).Type _ " "
	For i = 1 : 1 : def.Methods.Count() {
		Set m = def.Methods.GetAt(i)
		Set text = text _ m.FormalSpec _ " " _ m.ReturnType _ " "
		Do m.Implementation.Rewind()
		While 'm.Implementation.AtEnd {
			Set text = text _ m.Implementation.ReadLine() _ " "
		}
	}
	Return text
}

}
