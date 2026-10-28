Class SignalNoir.Sim.Ids Extends %RegisteredObject
{

/// Identifiers of the Simulator (research D4). The instance id comes from a
/// GUID (never from the seed), 128 bits in 26 base32 characters (V2); the
/// other ids are namespaced by the instance, so they never repeat across
/// instances or runs, even from the same seed.
Parameter ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";

ClassMethod NewInstanceId() As %String
{
	Set hex = $Translate($System.Util.CreateGUID(), "-")
	Set bits = ""
	For i = 1 : 1 : $Length(hex) {
		Set v = $ZHex($Extract(hex, i))
		For b = 3 : -1 : 0 Set bits = bits _ ((v \ (2 ** b)) # 2)
	}
	Set bits = bits _ "00"
	Set out = ""
	For i = 1 : 5 : $Length(bits) {
		Set v = 0
		For j = 0 : 1 : 4 Set v = v * 2 + $Extract(bits, i + j)
		Set out = out _ $Extract(..#ALPHABET, v + 1)
	}
	Return "sci_" _ out
}

ClassMethod OrderId(sci As %String, ordinal As %Integer) As %String
{
	Return "ORD-" _ sci _ "-" _ $Translate($Justify(ordinal, 4), " ", "0")
}

ClassMethod TransactionId(sci As %String, n As %Integer) As %String
{
	Return "txn_" _ $Extract(sci, 5, *) _ "_" _ n
}

ClassMethod ReceiptId(sci As %String, n As %Integer) As %String
{
	Return "rcp_" _ $Extract(sci, 5, *) _ "_" _ n
}

}
