Class SignalNoir.Tests.Core.Validator.TestDeterminismNoIo Extends %UnitTest.TestCase
{

Parameter INPUTS = "SignalNoir.Tests.Core.Validator.Inputs";

/// 004 T042 - the Validator is a function of its input (FR-016, SC-003, SC-005; research D13, D14):
/// (a) no compiled method of the Core classes it uses reads or writes anything outside its
/// arguments, (b) every input validated twice, and in a fresh process, gives the same JSON,
/// (c) a validation takes well under the budget.
/// The classes whose methods are scanned: the Validator, its vocabularies and the DTOs of the input.
ClassMethod Classes() As %List
{
	Return $ListBuild("SignalNoir.Core.Validator", "SignalNoir.Core.Reasons", "SignalNoir.Core.Conditions", "SignalNoir.Core.Canon", "SignalNoir.Core.Identity", "SignalNoir.Core.ActionCatalog", "SignalNoir.Core.Vocab", "SignalNoir.Core.Dto.ValidationInput", "SignalNoir.Core.Dto.PreconditionResult", "SignalNoir.Core.Dto.Admission", "SignalNoir.Core.Dto.ReferenceData", "SignalNoir.Core.Dto.ValidatorVerdict")
}

/// A method body without its string literals and its comments
ClassMethod Code(text As %String) As %String
{
	Set out = "", inString = 0, i = 1, n = $Length(text)
	While i <= n {
		Set c = $Extract(text, i)
		If inString {
			If c = """" {
				If $Extract(text, i + 1) = """" {
					Set i = i + 1
				} Else {
					Set inString = 0
				}
			}
		} ElseIf c = """" {
			Set inString = 1
		} ElseIf (c = ";") || ((c = "/") && ($Extract(text, i + 1) = "/")) {
			While (i <= n) && ($Extract(text, i) '= $Char(10)) {
				Set i = i + 1
			}
			Set out = out _ $Char(10)
		} Else {
			Set out = out _ c
		}
		Set i = i + 1
	}
	Return out
}

/// What no method of these classes may contain
ClassMethod Forbidden() As %List
{
	Return $ListBuild("^", "$ZF(", "$HOROLOG", "$ZTIMESTAMP", "$ZTS", "$NOW", "$RANDOM", "$ZUTIL(", "$SYSTEM.", "%PERSISTENT", "%SQL.", "%NET.", "%FILE", "%STREAM.", "%STATEMENT", "%RESULTSET", "%ZEN")
}

/// The ObjectScript commands of I/O, as a command: after a line start, a brace or a space
ClassMethod IoCommands() As %List
{
	Return $ListBuild("OPEN", "USE", "READ", "WRITE", "CLOSE", "JOB", "LOCK", "TSTART", "TCOMMIT")
}

ClassMethod Sources(class As %String) As %List
{
	Set bodies = ""
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.CompiledMethod WHERE parent = ? AND Origin = ?", class, class)
	While rs.%Next() {
		Set method = ##class(%Dictionary.CompiledMethod).%OpenId(class _ "||" _ rs.%Get("Name"))
		If '$IsObject(method) || 'method.Implementation.Size Continue
		Set bodies = bodies _ $ListBuild($ListBuild(rs.%Get("Name"), method.Implementation.Read(method.Implementation.Size)))
	}
	Return bodies
}

Method TestNoMethodOfTheCoreValidatorReachesOutside()
{
	Set classes = ..Classes(), scanned = 0
	For c = 1 : 1 : $ListLength(classes) {
		Set class = $List(classes, c)
		Set bodies = ..Sources(class)
		For b = 1 : 1 : $ListLength(bodies) {
			Set name = $List($List(bodies, b), 1), code = $ZConvert(..Code($List($List(bodies, b), 2)), "U")
			Set scanned = scanned + 1
			For f = 1 : 1 : $ListLength(..Forbidden()) {
				Set token = $List(..Forbidden(), f)
				If code [ token Do $$$AssertTrue(0, class _ "." _ name _ " contains " _ token)
			}
			Set padded = " " _ $Translate(code, $Char(9, 10, 13, 123, 125), "    ")
			For k = 1 : 1 : $ListLength(..IoCommands()) {
				Set command = $List(..IoCommands(), k)
				If padded [ (" " _ command _ " ") Do $$$AssertTrue(0, class _ "." _ name _ " uses the command " _ command)
			}
		}
	}
	Do $$$AssertTrue(scanned > 60, "the scan looked at " _ scanned _ " methods")
	Do $$$LogMessage("scanned " _ scanned _ " methods of " _ $ListLength(classes) _ " classes")
}

Method TestTheScanFindsWhatItLooksFor()
{
	Set code = $ZConvert(..Code("Set x = $Get(^Global)" _ $Char(10) _ "Write ""a"""), "U")
	Do $$$AssertTrue(code [ "^", "a global reference is seen")
	Do $$$AssertTrue((" " _ $Translate(code, $Char(10), " ")) [ " WRITE ", "a command is seen")
	Set code = $ZConvert(..Code("Set x = ""^not a global"" ; ^nor this" _ $Char(10) _ "// Write nor this"), "U")
	Do $$$AssertTrue(code '[ "^", "a string and a comment are not code")
	Do $$$AssertTrue(code '[ "WRITE", "a comment is not a command")
}

/// A set of inputs that exercises every branch of the pipeline
ClassMethod Count() As %Integer
{
	Return 14
}

ClassMethod InputNumber(n As %Integer) As SignalNoir.Core.Dto.ValidationInput
{
	Set I = ..#INPUTS
	Set mapping = $ClassMethod(I, "MappingParams")
	If n = 1 Return $ClassMethod(I, "Input", $ClassMethod(I, "Proposal", "RETRY"))
	If n = 2 Return $ClassMethod(I, "Input", $ClassMethod(I, "Proposal", "HOLD", {"reason": "partner"}))
	If n = 3 Return $ClassMethod(I, "Input", $ClassMethod(I, "Proposal", "REQUEST_REVIEW"))
	If n = 4 Return $ClassMethod(I, "Input", $ClassMethod(I, "Proposal", "APPLY_APPROVED_MAPPING", mapping))
	If n = 5 Return $ClassMethod(I, "Input", $ClassMethod(I, "Proposal", "APPLY_APPROVED_MAPPING", $ClassMethod(I, "MappingParams", "map_glicj_soro")))
	If n = 6 Return $ClassMethod(I, "Input", $ClassMethod(I, "Proposal", "APPLY_APPROVED_MAPPING", $ClassMethod(I, "MappingParams", "map_tsh_legacy")), "", $ClassMethod(I, "LegacyTshOrder"))
	If n = 7 Return $ClassMethod(I, "Input", $ClassMethod(I, "Proposal", "DELETE_ORDER"))
	If n = 8 Return $ClassMethod(I, "Input", $ClassMethod(I, "Proposal", "RETRY", "", "LOW"))
	If n = 9 {
		Set input = $ClassMethod(I, "Input", $ClassMethod(I, "Proposal", "RETRY"))
		Do input.evidence.Insert($ClassMethod(I, "CollidingEvidence"))
		Return input
	}
	If n = 10 Return $ClassMethod(I, "Input", $ClassMethod(I, "Proposal", "RETRY"), "", "", 3)
	If n = 11 Return $ClassMethod(I, "Input", $ClassMethod(I, "Proposal", "RETRY"), ##class(%ListOfObjects).%New())
	If n = 12 {
		Set input = $ClassMethod(I, "Input", $ClassMethod(I, "Proposal", "RETRY"))
		Set input.reference = ""
		Return input
	}
	If n = 13 {
		Set input = $ClassMethod(I, "Input", $ClassMethod(I, "Proposal", "REQUEST_REVIEW"), "", $ClassMethod("SignalNoir.Tests.Core.Validator.TestPriorReceipt", "Current"))
		Set input.proposal.priorReceiptCandidate = {"receiptId": "RCP-1", "orderId": "ORD-9"}
		Set input.priorReceiptOrder = $ClassMethod("SignalNoir.Tests.Core.Validator.TestPriorReceipt", "Prior")
		Return input
	}
	Set input = $ClassMethod(I, "Input", $ClassMethod(I, "Proposal", "RETRY"))
	Set input.proposal.preconditions = [{"check": "ORDER_ACTIVE_AT_ORIGIN"}, {"check": "APPROVAL_VALID"}, {"check": "MAPPING_VERSION_UNCHANGED"}]
	Set input.observed = $ClassMethod("SignalNoir.Tests.Core.Validator.TestPreconditions", "Observed")
	Return input
}

/// The verdict and the preconditions of an input, as one JSON text
ClassMethod Answer(n As %Integer) As %String
{
	Set validator = ##class(SignalNoir.Core.Validator).%New()
	Set verdict = validator.Revalidate(..InputNumber(n), .results)
	Set all = []
	For i = 1 : 1 : results.Count() Do all.%Push(results.GetAt(i).ToJson())
	Return verdict.ToJson().%ToJSON() _ all.%ToJSON() _ validator.Admit("benchmark", {"inRun": true, "runId": "run_1"}).ToJson().%ToJSON()
}

/// Runs in a fresh process: leaves its answers where the test can read them
ClassMethod Child(key As %String)
{
	For n = 1 : 1 : ..Count() Set ^SignalNoir.TestSeq("determinism", key, n) = ..Answer(n)
	Set ^SignalNoir.TestSeq("determinism", key, "done") = 1
}

Method TestEveryInputGivesTheSameJsonTwiceAndInAFreshProcess()
{
	Set key = $Job _ "-" _ $ZHorolog
	Kill ^SignalNoir.TestSeq("determinism", key)
	Job ##class(SignalNoir.Tests.Core.Validator.TestDeterminismNoIo).Child(key)
	For n = 1 : 1 : ..Count() {
		Set first = ..Answer(n)
		Do $$$AssertEquals(..Answer(n), first, "input " _ n _ ": twice, in this process")
	}
	For i = 1 : 1 : 100 {
		Quit:$Data(^SignalNoir.TestSeq("determinism", key, "done"))
		Hang 0.1
	}
	Do $$$AssertTrue($Data(^SignalNoir.TestSeq("determinism", key, "done")), "the fresh process finished")
	For n = 1 : 1 : ..Count() {
		Do $$$AssertEquals($Get(^SignalNoir.TestSeq("determinism", key, n)), ..Answer(n), "input " _ n _ ": the same in a fresh process")
	}
	Kill ^SignalNoir.TestSeq("determinism", key)
}

Method TestTheClockIsTheOnlyThingThatMovesAVerdict()
{
	Set a = ..InputNumber(4), b = ..InputNumber(4)
	Set b.now = "2026-12-31T23:59:59Z"
	Set va = ##class(SignalNoir.Core.Validator).%New().Validate(a).ToJson()
	Set vb = ##class(SignalNoir.Core.Validator).%New().Validate(b).ToJson()
	Do $$$AssertEquals(va.at _ "|" _ vb.at, "2026-10-29T13:02:11Z|2026-12-31T23:59:59Z", "at is the caller's clock")
	Set va.at = "", vb.at = ""
	Do $$$AssertEquals(va.%ToJSON(), vb.%ToJSON(), "and nothing else differs")
}

Method TestAThousandValidationsAreWellUnderTheBudget()
{
	Set validator = ##class(SignalNoir.Core.Validator).%New()
	Set input = ..InputNumber(4)
	Set start = $ZHorolog
	For i = 1 : 1 : 1000 Do validator.Validate(input)
	Set mean = ($ZHorolog - start) / 1000 * 1000
	Do $$$LogMessage("mean " _ $FNumber(mean, "", 3) _ " ms per validation")
	Do $$$AssertTrue(mean <= 50, "SC-005: the mean of 1000 validations is " _ $FNumber(mean, "", 3) _ " ms, at most 50")
}

}
