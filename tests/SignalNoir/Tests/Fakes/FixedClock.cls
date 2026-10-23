Class SignalNoir.Tests.Fakes.FixedClock Extends SignalNoir.Core.Port.Clock
{

/// Test double for the Clock port: returns a fixed instant so timestamps
/// are comparable. Usable with no live provider.

Property Value As %String;

Method %OnNew() As %Status
{
	Set ..Value = "2026-01-01T00:00:00Z"
	Return $$$OK
}

Method NowUtc() As %String
{
	Return ..Value
}

}
