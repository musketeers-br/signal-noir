Class SignalNoir.Sim.Prng Extends %RegisteredObject
{

/// Deterministic draws in counter mode (research D3): the first 7 bytes of
/// SHA-256(seed|variant|stream|n) as an unsigned integer. 7 bytes stay exact
/// in ObjectScript (V1); no $RANDOM, no clock.
ClassMethod Draw(seed As %Integer, variant As %String, stream As %String, n As %Integer) As %Integer
{
	Set h = $System.Encryption.SHAHash(256, seed _ "|" _ variant _ "|" _ stream _ "|" _ n)
	Set value = 0
	For i = 1 : 1 : 7 Set value = value * 256 + $Ascii(h, i)
	Return value
}

/// One element of a non-empty array
ClassMethod Pick(list As %DynamicArray, seed As %Integer, variant As %String, stream As %String, n As %Integer)
{
	Return list.%Get(..Draw(seed, variant, stream, n) # list.%Size())
}

/// An integer in [lo, hi]
ClassMethod Range(lo As %Integer, hi As %Integer, seed As %Integer, variant As %String, stream As %String, n As %Integer) As %Integer
{
	Return lo + (..Draw(seed, variant, stream, n) # (hi - lo + 1))
}

}
