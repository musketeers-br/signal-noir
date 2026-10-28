Class SignalNoir.Tests.Sim.Core.TestPrng Extends %UnitTest.TestCase
{

/// 002 T004 - counter-mode SHA-256 draws (research D3, 7 bytes after V1)
Method TestDraw()
{
	Set P = "SignalNoir.Sim.Prng"
	Set a = $ClassMethod(P, "Draw", 7, "P5-tune-01", "order", 1)
	Do $$$AssertEquals($ClassMethod(P, "Draw", 7, "P5-tune-01", "order", 1), a, "same inputs, same draw")
	Do $$$AssertTrue(a '= $ClassMethod(P, "Draw", 7, "P5-tune-01", "wording", 1), "stream changes it")
	Do $$$AssertTrue(a '= $ClassMethod(P, "Draw", 7, "P5-tune-01", "order", 2), "n changes it")
	Do $$$AssertTrue(a '= $ClassMethod(P, "Draw", 8, "P5-tune-01", "order", 1), "seed changes it")
	Do $$$AssertTrue((a >= 0) && (a < (2 ** 56)), "56-bit unsigned")
	; exact value (same as Python hashlib, first 7 bytes of SHA-256("7|P5-tune-01|order|1"))
	Do $$$AssertEquals(a, ..Expected("7|P5-tune-01|order|1"), "exact 56-bit value")
}

Method TestPickAndRange()
{
	Set P = "SignalNoir.Sim.Prng"
	Set list = ["a", "b", "c"]
	Set out = 0
	For n = 1 : 1 : 50 {
		Set v = $ClassMethod(P, "Pick", list, 3, "v", "s", n)
		If (v '= "a") && (v '= "b") && (v '= "c") Set out = out + 1
		Set x = $ClassMethod(P, "Range", 10, 12, 3, "v", "s", n)
		If (x < 10) || (x > 12) Set out = out + 1
	}
	Do $$$AssertEquals(out, 0, "picks and ranges stay in bounds")
}

Method TestNoRandomNoClock()
{
	Set code = ##class(%Dictionary.CompiledMethod).%OpenId("SignalNoir.Sim.Prng||Draw").Implementation.Read(32000)
	Do $$$AssertNotTrue($ZConvert(code, "U") [ "$RANDOM", "no $RANDOM")
	Do $$$AssertNotTrue($ZConvert(code, "U") [ "$H", "no clock")
}

/// Reference value computed independently of Prng (byte by byte)
ClassMethod Expected(s As %String) As %Integer
{
	Set h = $System.Encryption.SHAHash(256, s), n = 0
	For i = 1 : 1 : 7 Set n = n * 256 + $Ascii(h, i)
	Return n
}

}
