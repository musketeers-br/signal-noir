Class SignalNoir.Tests.Core.Benchmark.TestCoreHasNoIo Extends %UnitTest.TestCase
{

/// 010 T003 - the evaluator is a function of its input (Constitution I, plan D1):
/// (a) no method of SignalNoir.Core.Benchmark reads or writes anything outside its
/// arguments; (b) the runner and the report builder never approve or change a Case
/// (FR-007). Both pass while the classes do not exist yet and fail on any later violation.
/// The scan helpers are those of the Validator's own determinism test.
ClassMethod Scan() As %String
{
	Return "SignalNoir.Tests.Core.Validator.TestDeterminismNoIo"
}

/// What no method of the pure Core may contain. $System.Encryption is allowed: a hash
/// is a function of its input (Core.EffectKey does the same).
ClassMethod Forbidden() As %List
{
	Return $ListBuild("^", "$ZF(", "$HOROLOG", "$ZTIMESTAMP", "$ZTS", "$NOW", "$RANDOM", "$ZUTIL(", "$SYSTEM.UTIL", "$SYSTEM.OBJ", "$SYSTEM.SQL", "$SYSTEM.PROCESS", "$SYSTEM.INFO", "%PERSISTENT", "%SQL.", "%NET.", "%FILE", "%STREAM.", "%STATEMENT", "%RESULTSET", "%ZEN")
}

ClassMethod ClassesStartingWith(prefix As %String) As %List
{
	Set list = ""
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.CompiledClass WHERE Name %STARTSWITH ? ORDER BY Name", prefix)
	While rs.%Next() {
		Set list = list _ $ListBuild(rs.%Get("Name"))
	}
	Return list
}

Method TestCoreBenchmarkHasNoIo()
{
	Set classes = ..ClassesStartingWith("SignalNoir.Core.Benchmark."), scanned = 0
	For c = 1 : 1 : $ListLength(classes) {
		Set class = $List(classes, c)
		Set bodies = $ClassMethod(..Scan(), "Sources", class)
		For b = 1 : 1 : $ListLength(bodies) {
			Set name = $List($List(bodies, b), 1)
			Set code = $ZConvert($ClassMethod(..Scan(), "Code", $List($List(bodies, b), 2)), "U")
			Set scanned = scanned + 1
			For f = 1 : 1 : $ListLength(..Forbidden()) {
				Set token = $List(..Forbidden(), f)
				If code [ token Do $$$AssertTrue(0, class _ "." _ name _ " contains " _ token)
			}
			Set padded = " " _ $Translate(code, $Char(9, 10, 13, 123, 125), "    ")
			Set commands = $ClassMethod(..Scan(), "IoCommands")
			For k = 1 : 1 : $ListLength(commands) {
				Set command = $List(commands, k)
				If padded [ (" " _ command _ " ") Do $$$AssertTrue(0, class _ "." _ name _ " uses the command " _ command)
			}
		}
	}
	Do $$$LogMessage("scanned " _ scanned _ " methods of " _ $ListLength(classes) _ " classes")
}

Method TestRunnerAndReportNeverApprove()
{
	Set tokens = $ListBuild("RECORDAPPROVAL", "DECIDE(", "APPLYTRANSITION")
	For each = "SignalNoir.Application.Benchmark.Runner", "SignalNoir.Application.Benchmark.ReportBuilder" {
		If '##class(%Dictionary.CompiledClass).%ExistsId(each) Continue
		Set bodies = $ClassMethod(..Scan(), "Sources", each)
		For b = 1 : 1 : $ListLength(bodies) {
			Set name = $List($List(bodies, b), 1)
			Set code = $ZConvert($ClassMethod(..Scan(), "Code", $List($List(bodies, b), 2)), "U")
			For t = 1 : 1 : $ListLength(tokens) {
				If code [ $List(tokens, t) Do $$$AssertTrue(0, each _ "." _ name _ " reaches " _ $List(tokens, t))
			}
		}
	}
}

Method TestTheScanFindsWhatItLooksFor()
{
	Set code = $ZConvert($ClassMethod(..Scan(), "Code", "Set x = $Get(^Global)"), "U")
	Do $$$AssertTrue(code [ "^", "a global reference is seen")
	Set code = $ZConvert($ClassMethod(..Scan(), "Code", "Set h = $System.Encryption.SHAHash(256, x)"), "U")
	Do $$$AssertTrue(code '[ "$SYSTEM.UTIL", "a hash is not I/O")
	Set code = $ZConvert($ClassMethod(..Scan(), "Code", "Set u = $System.Util.GetEnviron(""X"")"), "U")
	Do $$$AssertTrue(code [ "$SYSTEM.UTIL", "an environment read is seen")
}

}
