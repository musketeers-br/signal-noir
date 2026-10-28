Class SignalNoir.Sim.Clock Extends %RegisteredObject
{

/// Simulator time: ISO-8601 UTC with milliseconds and Z (research D11),
/// the product's format, implemented here without referencing it.
ClassMethod NowUtc() As %String
{
	Return $Replace($ZDateTime($ZTimestamp, 3, 1, 3), " ", "T") _ "Z"
}

/// The instant plus (or minus) whole seconds, keeping the fraction
ClassMethod Shift(iso As %String, seconds As %Integer) As %String
{
	Set total = ($ZDateH($Extract(iso, 1, 10), 3) * 86400) + $ZTimeH($Extract(iso, 12, 19)) + seconds
	Set day = total \ 86400, secs = total # 86400
	Set frac = $Piece($Piece(iso, ".", 2), "Z", 1)
	Return $ZDate(day, 3) _ "T" _ $ZTime(secs, 1) _ $Select(frac '= "": "." _ frac, 1: "") _ "Z"
}

/// Seconds since the IRIS epoch, with the fraction, for comparisons
ClassMethod Seconds(iso As %String) As %Numeric
{
	Set frac = $Piece($Piece(iso, ".", 2), "Z", 1)
	Return ($ZDateH($Extract(iso, 1, 10), 3) * 86400) + $ZTimeH($Extract(iso, 12, 19)) + $Select(frac '= "": +("." _ frac), 1: 0)
}

/// True when the text is a UTC instant of the contract (UtcDateTime)
ClassMethod IsUtc(text As %String) As %Boolean
{
	Return $Match(text, "^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?Z$")
}

}
