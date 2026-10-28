Class SignalNoir.Core.ApprovalPolicy Extends SignalNoir.Core.Port.ApprovalPolicy
{

/// Default approval policy until feature 004 (research R4): 15 minutes, and
/// the benchmark actor only on a Case that carries a runId. Pure.
Parameter DEADLINESECONDS = 900;

Method DeadlineSeconds() As %Integer
{
	Return ..#DEADLINESECONDS
}

Method Admit(actor As %String, runId As %String) As %Boolean
{
	If actor = "benchmark" Return (runId '= "")
	Return 1
}

/// ISO-8601 UTC plus whole seconds, keeping the fraction
ClassMethod Plus(iso As %String, seconds As %Integer) As %String
{
	Set day = $ZDateH($Extract(iso, 1, 10), 3)
	Set secs = $ZTimeH($Extract(iso, 12, 19)) + seconds
	Set day = day + (secs \ 86400), secs = secs # 86400
	Set frac = $Piece($Piece(iso, ".", 2), "Z", 1)
	Return $ZDate(day, 3) _ "T" _ $ZTime(secs, 1) _ $Select(frac '= "": "." _ frac, 1: "") _ "Z"
}

/// Seconds since the IRIS epoch, with the fraction, for comparisons
ClassMethod Seconds(iso As %String) As %Numeric
{
	Set frac = $Piece($Piece(iso, ".", 2), "Z", 1)
	Return ($ZDateH($Extract(iso, 1, 10), 3) * 86400) + $ZTimeH($Extract(iso, 12, 19)) + $Select(frac '= "": +("." _ frac), 1: 0)
}

}
