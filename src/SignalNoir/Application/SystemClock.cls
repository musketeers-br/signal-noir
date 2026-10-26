Class SignalNoir.Application.SystemClock Extends SignalNoir.Core.Port.Clock
{

/// Clock adapter: NowUtc() returns an ISO-8601 UTC timestamp with
/// milliseconds and Z, the format the seam uses everywhere. $ZTIMESTAMP is
/// UTC ($H is local time).
Method NowUtc() As %String
{
	Set now = $ZDateTime($ZTimestamp, 3, 1, 3)
	Return $Replace(now, " ", "T") _ "Z"
}

}
