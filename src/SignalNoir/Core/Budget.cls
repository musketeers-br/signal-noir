Class SignalNoir.Core.Budget Extends %RegisteredObject
{

/// The server-enforced Investigation budget (spec 006 FR-003)
Parameter MAXTOOLCALLS = 6;

Parameter MAXMILLIS = 20000;

/// "" while within budget for one more call; else the limit reached:
/// "tool calls" or "time"
ClassMethod Breach(toolCalls As %Integer, elapsedMs As %Integer, budgetMs As %Integer = {..#MAXMILLIS}) As %String
{
	If elapsedMs >= budgetMs Return "time"
	If toolCalls >= ..#MAXTOOLCALLS Return "tool calls"
	Return ""
}

/// The reason recorded on the Case when a limit is reached
ClassMethod Reason(limit As %String) As %String
{
	Return "investigation budget exceeded: " _ limit
}

}
