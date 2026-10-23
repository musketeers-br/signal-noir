Class SignalNoir.Core.CaseMachine Extends %RegisteredObject
{

/// The state machine and the transition -> actor table (data-model.md section States).
/// Only the three transitions of this slice are live; everything else is
/// rejected with INVALID_TRANSITION. An unlisted actor is rejected with
/// INVALID_ACTOR.

ClassMethod CanTransition(from As %String, to As %String) As %Boolean
{
	If (from = "") && (to = "Open") Return 1
	If (from = "Open") && (to = "ReviewRequired") Return 1
	If (from = "Open") && (to = "Investigating") Return 1
	Return 0
}

/// Comma-separated actors allowed for a live transition; empty when the
/// transition itself does not exist.
ClassMethod AllowedActors(from As %String, to As %String) As %String
{
	If (from = "") && (to = "Open") Return "system"
	If (from = "Open") && (to = "ReviewRequired") Return "system"
	If (from = "Open") && (to = "Investigating") Return "system"
	Return ""
}

/// Returns "" when the transition is allowed for this actor, else the closed
/// error code INVALID_TRANSITION or INVALID_ACTOR.
ClassMethod Check(from As %String, to As %String, actor As %String) As %String
{
	If '##class(SignalNoir.Core.CaseMachine).CanTransition(from, to) Return "INVALID_TRANSITION"
	If '##class(SignalNoir.Core.Vocab).IsActor(actor) Return "INVALID_ACTOR"
	If $ListFind($ListFromString(##class(SignalNoir.Core.CaseMachine).AllowedActors(from, to), ","), actor) = 0 Return "INVALID_ACTOR"
	Return ""
}

}
