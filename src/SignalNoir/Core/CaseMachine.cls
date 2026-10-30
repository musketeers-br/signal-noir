Class SignalNoir.Core.CaseMachine Extends %RegisteredObject
{

/// The Case state machine and the transition -> actor -> follow-up table
/// (spec 003 FR-015, AD-24). Pure data: one row per transition,
/// "from>to" = "actors;followUp". "operator" stands for any operator:<name>.
/// The rows marked (exception) are the system reinvestigation on a new
/// Exception of the same Order (FR-012).
ClassMethod Table() As %List [ Private ]
{
	Return $ListBuild(
		">Open", "system;",
		"Open>Investigating", "system;Investigate",
		"Open>ReviewRequired", "system;",
		"Investigating>DecisionProposed", "agent,rules,replay;",
		"Investigating>ReviewRequired", "system;",
		"Investigating>ResolvedByPriorReceipt", "system;",
		"DecisionProposed>ResolvedByPriorReceipt", "system;",
		"DecisionProposed>PendingApproval", "system;",
		"DecisionProposed>Executing", "system;Execute",
		"DecisionProposed>ReviewRequired", "system;",
		"DecisionProposed>Investigating", "system;Investigate",
		"PendingApproval>Approved", "operator,benchmark;Execute",
		"PendingApproval>Rejected", "operator,benchmark;Reassess",
		"PendingApproval>Investigating", "system;Investigate",
		"Rejected>Investigating", "system;Investigate",
		"Rejected>ReviewRequired", "system;",
		"Approved>Executing", "system;",
		"Approved>Held", "system;",
		"Approved>Cancelled", "system;",
		"Approved>PendingApproval", "sweeper;",
		"Executing>Held", "system;",
		"Executing>Resolved", "system;",
		"Executing>Failed", "system;",
		"Held>Investigating", "sweeper,system;Investigate",
		"ReviewRequired>DecisionProposed", "operator;",
		"ReviewRequired>Cancelled", "operator;",
		"ReviewRequired>Investigating", "system;Investigate")
}

/// The "actors;followUp" cell of a transition, "" when it does not exist
ClassMethod Row(from As %String, to As %String) As %String [ Private ]
{
	Set table = ..Table()
	Set key = from _ ">" _ to
	Set pos = $ListFind(table, key)
	While pos > 0 {
		If (pos # 2) = 1 Return $ListGet(table, pos + 1)
		Set pos = $ListFind(table, key, pos)
	}
	Return ""
}

ClassMethod CanTransition(from As %String, to As %String) As %Boolean
{
	Return (..Row(from, to) '= "")
}

/// Comma-separated actors allowed for a transition; empty when the
/// transition does not exist. "operator" means any operator:<name>.
ClassMethod AllowedActors(from As %String, to As %String) As %String
{
	Return $Piece(..Row(from, to), ";", 1)
}

/// The follow-up command a transition writes with it, "" when none
ClassMethod FollowUp(from As %String, to As %String) As %String
{
	Return $Piece(..Row(from, to), ";", 2)
}

/// Returns "" when the transition is allowed for this actor, else the closed
/// error code INVALID_TRANSITION or INVALID_ACTOR.
ClassMethod Check(from As %String, to As %String, actor As %String) As %String
{
	If '..CanTransition(from, to) Return "INVALID_TRANSITION"
	If '##class(SignalNoir.Core.Vocab).IsActor(actor) Return "INVALID_ACTOR"
	Set allowed = $ListFromString(..AllowedActors(from, to), ",")
	Set kind = $Select($Extract(actor, 1, 9) = "operator:": "operator", 1: actor)
	If $ListFind(allowed, kind) = 0 Return "INVALID_ACTOR"
	Return ""
}

/// Where a new Exception of the Order goes, given the state of its latest
/// Case ("" when none): open (new Case, related to a terminal one),
/// attach (no state change) or attach_and_investigate (FR-012, FR-013).
ClassMethod RouteException(latestState As %String) As %String
{
	If (latestState = "") || ##class(SignalNoir.Core.Vocab).IsTerminal(latestState) Return "open"
	If $ListFind($ListBuild("Investigating", "Approved", "Executing"), latestState) Return "attach"
	Return "attach_and_investigate"
}

/// Destination after a rejection, given the rejection count (FR-024)
ClassMethod AfterRejection(denialCount As %Integer) As %String
{
	Return $Select(denialCount >= 2: "ReviewRequired", 1: "Investigating")
}

}
