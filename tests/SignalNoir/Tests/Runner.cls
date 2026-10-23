/// Runs compiled %UnitTest suites and prints a compact summary. Used through iris-agentic-dev exec
/// because the iris_test tool does not find these classes (specs/002 research R10, fallback):
///   do ##class(SignalNoir.Tests.Runner).Run("SignalNoir/Tests/Core")
Class SignalNoir.Tests.Runner Extends %RegisteredObject
{

/// Runs the suite folder (relative to ^UnitTestRoot) and prints one line per test method, then
/// every failed assertion. Returns the number of failed methods.
ClassMethod Run(suite As %String) As %Integer
{
    do ##class(%UnitTest.Manager).RunTest(suite, "/noload/nodelete/nodisplay")
    write !
    set index = $order(^UnitTest.Result(""), -1)
    set failed = 0, passed = 0
    set sql = "SELECT TestCase->Name AS CaseName, Name, Status, ErrorDescription FROM %UnitTest_Result.TestMethod WHERE TestCase->TestSuite->TestInstance = ? ORDER BY TestCase->Name, Name"
    set rs = ##class(%SQL.Statement).%ExecDirect(, sql, index)
    while rs.%Next() {
        if rs.Status = 1 { set passed = passed + 1  continue }
        set failed = failed + 1
        write "FAIL ", rs.CaseName, ":", rs.Name, $select(rs.ErrorDescription '= "": "  "_rs.ErrorDescription, 1: ""), !
    }
    set sql = "SELECT TestMethod->TestCase->Name AS CaseName, TestMethod->Name AS MethodName, Description FROM %UnitTest_Result.TestAssert WHERE TestMethod->TestCase->TestSuite->TestInstance = ? AND Status = 0"
    set rs = ##class(%SQL.Statement).%ExecDirect(, sql, index)
    set shown = 0
    while rs.%Next() && (shown < 40) {
        set shown = shown + 1
        write "     ", rs.CaseName, ":", rs.MethodName, "  ", $extract(rs.Description, 1, 160), !
    }
    write "suite ", suite, ": ", passed, " passed, ", failed, " failed (result index ", index, ")", !
    quit failed
}

}
