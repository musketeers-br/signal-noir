Class SignalNoir.Tests.Core.Validator.TestReasons Extends %UnitTest.TestCase
{

Parameter CONTRACT = "/home/irisowner/dev/specs/004-validation-and-reference-data/contracts/reason-codes.md";

Parameter FIXTURES = "/home/irisowner/dev/contracts/fixtures";

/// 004 T007 - the closed list of reason codes equals the table of
/// contracts/reason-codes.md, in table order. The table is read here, never at runtime.
/// Returns a list of $ListBuild(step, code, usedByFixtures, kind, text)
ClassMethod Table() As %List
{
	Set rows = "", stream = ##class(%Stream.FileCharacter).%New()
	Do stream.LinkToFile(..#CONTRACT)
	While 'stream.AtEnd {
		Set line = stream.ReadLine()
		If $Extract(line) '= "|" Continue
		Set code = $ZStrip($Piece(line, "|", 3), "<>W")
		If $Extract(code) '= "`" Continue
		Set marked = ($Extract(code, *) = "*")
		Set code = $ZStrip($Translate(code, "`*", ""), "<>W")
		Set rows = rows _ $ListBuild($ListBuild($ZStrip($Piece(line, "|", 2), "<>W"), code, marked, $ZStrip($Piece(line, "|", 4), "<>W"), $ZStrip($Piece(line, "|", 5), "<>W")))
	}
	Return rows
}

Method TestTableParsedFromTheContract()
{
	Set rows = ..Table()
	Do $$$AssertEquals($ListLength(rows), 32, "the contract lists 32 codes")
	Do $$$AssertEquals($List($List(rows, 1), 2), "REFERENCE_DATA_UNAVAILABLE", "first row")
	Do $$$AssertEquals($List($List(rows, 32), 2), "ACTOR_NOT_ALLOWED_TO_APPROVE", "last row")
}

Method TestListEqualsTheContract()
{
	Set rows = ..Table(), expected = ""
	For i = 1 : 1 : $ListLength(rows) Set expected = expected _ $ListBuild($List($List(rows, i), 2))
	Do $$$AssertEquals($ListToString(##class(SignalNoir.Core.Reasons).All()), $ListToString(expected), "same codes in the same order")
	Do $$$AssertEquals($ListLength(##class(SignalNoir.Core.Reasons).All()), 32, "32 codes")
	Do $$$AssertEquals(##class(SignalNoir.Core.Reasons).#CODES, $ListToString(expected), "the CODES parameter is the same list")
}

Method TestTextKindAndOrderMatchTheContract()
{
	Set rows = ..Table(), bad = 0
	For i = 1 : 1 : $ListLength(rows) {
		Set row = $List(rows, i), code = $List(row, 2)
		If ##class(SignalNoir.Core.Reasons).Text(code) '= $List(row, 5) Set bad = bad _ " text:" _ code
		If ##class(SignalNoir.Core.Reasons).Kind(code) '= $List(row, 4) Set bad = bad _ " kind:" _ code
		If ##class(SignalNoir.Core.Reasons).Order(code) '= i Set bad = bad _ " order:" _ code
	}
	Do $$$AssertEquals(bad, 0, "every code has the contract's text, kind and position" _ $Select(bad = 0: "", 1: ":" _ bad))
}

Method TestEveryCodeHasANonEmptyEnglishText()
{
	Set codes = ##class(SignalNoir.Core.Reasons).All(), empty = ""
	For i = 1 : 1 : $ListLength(codes) {
		If $ZStrip(##class(SignalNoir.Core.Reasons).Text($List(codes, i)), "<>W") = "" Set empty = empty _ " " _ $List(codes, i)
	}
	Do $$$AssertEquals(empty, "", "no empty text")
}

Method TestIsReasonRejectsAnythingElse()
{
	Do $$$AssertTrue(##class(SignalNoir.Core.Reasons).IsReason("ACTION_IN_CATALOG"), "a code")
	Do $$$AssertTrue('##class(SignalNoir.Core.Reasons).IsReason("action_in_catalog"), "case matters")
	Do $$$AssertTrue('##class(SignalNoir.Core.Reasons).IsReason("SOMETHING_ELSE"), "unknown")
	Do $$$AssertTrue('##class(SignalNoir.Core.Reasons).IsReason(""), "empty")
	Do $$$AssertTrue('##class(SignalNoir.Core.Reasons).IsReason("ACTION_IN_CATALOG,PARAMS_VALID"), "a list is not a code")
	Do $$$AssertEquals(##class(SignalNoir.Core.Reasons).Order("SOMETHING_ELSE"), 0, "unknown has no position")
	Do $$$AssertEquals(##class(SignalNoir.Core.Reasons).Text("SOMETHING_ELSE"), "", "unknown has no text")
	Do $$$AssertEquals(##class(SignalNoir.Core.Reasons).Kind("SOMETHING_ELSE"), "", "unknown has no kind")
}

/// The codes the contract fixtures already use (marked * in the table) are present
Method TestTheFixtureCodesArePresent()
{
	Set rows = ..Table(), marked = 0, missing = ""
	For i = 1 : 1 : $ListLength(rows) {
		Set row = $List(rows, i)
		If $List(row, 3) {
			Set marked = marked + 1
			If '##class(SignalNoir.Core.Reasons).IsReason($List(row, 2)) Set missing = missing _ " " _ $List(row, 2)
		}
	}
	Do $$$AssertEquals(marked, 9, "the contract marks 9 fixture codes")
	Do $$$AssertEquals(missing, "", "all present")
}

/// Every reason in a contract fixture is in the closed list
Method TestFixtureReasonsAreInTheList()
{
	Set rs = ##class(%File).FileSetFunc(..#FIXTURES, "*.json")
	Set seen = 0, unknown = ""
	While rs.%Next() {
		Set stream = ##class(%Stream.FileCharacter).%New()
		Do stream.LinkToFile(rs.Name)
		Set text = stream.Read(2000000)
		Set json = {}.%FromJSON(text)
		Do ..Scan(json, .seen, .unknown)
	}
	Do $$$AssertTrue(seen > 0, "the fixtures carry reasons: " _ seen)
	Do $$$AssertEquals(unknown, "", "no code outside the closed list")
}

/// Collects the members named reasons[] that hold text (verdict reasons)
ClassMethod Scan(node, ByRef seen, ByRef unknown) [ Private ]
{
	If '$IsObject(node) Return
	If node.%IsA("%Library.DynamicArray") {
		For i = 0 : 1 : node.%Size() - 1 Do ..Scan(node.%Get(i), .seen, .unknown)
		Return
	}
	Set it = node.%GetIterator()
	While it.%GetNext(.key, .value) {
		If (key = "reasons") && $IsObject(value) && value.%IsA("%Library.DynamicArray") {
			For i = 0 : 1 : value.%Size() - 1 {
				If value.%GetTypeOf(i) '= "string" Continue
				Set seen = seen + 1
				If '##class(SignalNoir.Core.Reasons).IsReason(value.%Get(i)) Set unknown = unknown _ " " _ value.%Get(i)
			}
		} ElseIf $IsObject(value) {
			Do ..Scan(value, .seen, .unknown)
		}
	}
}

}
