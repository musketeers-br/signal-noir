Class SignalNoir.Tests.Fakes.SeqIdGenerator Extends SignalNoir.Core.Port.IdGenerator
{

/// Test double for the IdGenerator port: deterministic, prefix plus a
/// counter. Usable with no live provider.

Property counter As %Integer;

Method %OnNew() As %Status
{
	Set ..counter = 0
	Return $$$OK
}

Method New(prefix As %String) As %String
{
	If prefix = "" Return ""
	Set ..counter = ..counter + 1
	Return prefix _ ..counter
}

}
