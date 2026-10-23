Class SignalNoir.Application.SystemClock Extends SignalNoir.Core.Port.Clock
{

/// Clock adapter: NowUtc() returns an ISO-8601 UTC timestamp with Z, the
/// format the seam uses everywhere.

Method NowUtc() As %String
{
	Set now = $ZDateTime($H, 3)
	Set now = $Replace(now, " ", "T")
	Return now _ "Z"
}

}
