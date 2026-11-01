Class SignalNoir.Core.Benchmark.Seed Extends %RegisteredObject
{

/// The seed of one (family, variant, repetition) of a run, derived from the run's
/// base seed (FR-004, plan D3): the first 31 bits of SHA-256 over
/// "base|family|variant|repetition". Pure: the same four inputs always give the same
/// integer, and a change of any one of them changes it. With the Simulator's own
/// determinism ((family, variant, seed) gives the same responses) the same run
/// request replays the same sequence of Simulator answers.
ClassMethod For(baseSeed As %Integer, family As %String, variant As %String, repetition As %Integer) As %Integer
{
	Set h = $System.Encryption.SHAHash(256, $ZConvert(baseSeed _ "|" _ family _ "|" _ variant _ "|" _ repetition, "O", "UTF8"))
	Set n = ($Ascii(h, 1) * 16777216) + ($Ascii(h, 2) * 65536) + ($Ascii(h, 3) * 256) + $Ascii(h, 4)
	Return n # 2147483648
}

}
