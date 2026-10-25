Class SignalNoir.Tests.Core.TestCaseMachine Extends %UnitTest.TestCase
{

/// 003 T029 - the transition table of spec FR-015, encoded in the core.
/// Each row: from, to, allowed actors, follow-up.
ClassMethod Rows() As %DynamicArray
{
	Return [
		["", "Open", "system", ""],
		["Open", "Investigating", "system", "Investigate"],
		["Open", "ReviewRequired", "system", ""],
		["Investigating", "DecisionProposed", "agent,rules,replay", ""],
		["Investigating", "ReviewRequired", "system", ""],
		["Investigating", "ResolvedByPriorReceipt", "system", ""],
		["DecisionProposed", "ResolvedByPriorReceipt", "system", ""],
		["DecisionProposed", "PendingApproval", "system", ""],
		["DecisionProposed", "Executing", "system", "Execute"],
		["DecisionProposed", "ReviewRequired", "system", ""],
		["PendingApproval", "Approved", "operator:ana,benchmark", "Execute"],
		["PendingApproval", "Rejected", "operator:ana,benchmark", ""],
		["Rejected", "Investigating", "system", "Investigate"],
		["Rejected", "ReviewRequired", "system", ""],
		["Approved", "Executing", "system", ""],
		["Approved", "Held", "system", ""],
		["Approved", "Cancelled", "system", ""],
		["Approved", "PendingApproval", "sweeper", ""],
		["Executing", "Held", "system", ""],
		["Executing", "Resolved", "system", ""],
		["Executing", "Failed", "system", ""],
		["Held", "Investigating", "sweeper,system", "Investigate"],
		["ReviewRequired", "DecisionProposed", "operator:ana", ""],
		["ReviewRequired", "Cancelled", "operator:ana", ""],
		["Open", "Investigating", "system", "Investigate"],
		["DecisionProposed", "Investigating", "system", "Investigate"],
		["PendingApproval", "Investigating", "system", "Investigate"],
		["ReviewRequired", "Investigating", "system", "Investigate"]
	]
}

Method TestEveryRowAllowedForItsActors()
{
	Set rows = ..Rows()
	For i = 0 : 1 : rows.%Size() - 1 {
		Set row = rows.%Get(i)
		Set from = row.%Get(0), to = row.%Get(1), actors = row.%Get(2)
		For j = 1 : 1 : $Length(actors, ",") {
			Set actor = $Piece(actors, ",", j)
			Do $$$AssertEquals(##class(SignalNoir.Core.CaseMachine).Check(from, to, actor), "", from _ " -> " _ to _ " by " _ actor)
		}
		Do $$$AssertEquals(##class(SignalNoir.Core.CaseMachine).FollowUp(from, to), row.%Get(3), "follow-up " _ from _ " -> " _ to)
	}
}

Method TestUnlistedActorRefused()
{
	Do $$$AssertEquals(##class(SignalNoir.Core.CaseMachine).Check("PendingApproval", "Approved", "agent"), "INVALID_ACTOR", "agent cannot approve")
	Do $$$AssertEquals(##class(SignalNoir.Core.CaseMachine).Check("Approved", "PendingApproval", "system"), "INVALID_ACTOR", "only the sweeper expires")
	Do $$$AssertEquals(##class(SignalNoir.Core.CaseMachine).Check("Approved", "PendingApproval", "operator:ana"), "INVALID_ACTOR", "operator cannot expire")
	Do $$$AssertEquals(##class(SignalNoir.Core.CaseMachine).Check("Open", "Investigating", "robot"), "INVALID_ACTOR", "unknown actor")
	Do $$$AssertEquals(##class(SignalNoir.Core.CaseMachine).Check("Open", "Investigating", "operator:carla"), "INVALID_ACTOR", "operator not listed")
	Do $$$AssertEquals(##class(SignalNoir.Core.CaseMachine).Check("ReviewRequired", "Cancelled", "operator:"), "INVALID_ACTOR", "operator without a name")
	Do $$$AssertEquals(##class(SignalNoir.Core.CaseMachine).Check("", "Open", ""), "INVALID_ACTOR", "missing actor")
}

Method TestTransitionsOutsideTheTableRefused()
{
	For pair = "Open>Executing", "Open>PendingApproval", "Held>PendingApproval", "Held>Resolved", "ReviewRequired>Open", "Investigating>Approved", "Rejected>Approved" {
		Do $$$AssertEquals(##class(SignalNoir.Core.CaseMachine).Check($Piece(pair, ">", 1), $Piece(pair, ">", 2), "system"), "INVALID_TRANSITION", pair)
	}
}

Method TestTerminalStatesHaveNoExit()
{
	Set states = ##class(SignalNoir.Core.Vocab).States()
	For t = "Resolved", "ResolvedByPriorReceipt", "Cancelled", "Failed" {
		For i = 1 : 1 : $ListLength(states) {
			Do $$$AssertEquals(##class(SignalNoir.Core.CaseMachine).CanTransition(t, $ListGet(states, i)), 0, t _ " -> " _ $ListGet(states, i))
		}
	}
}

Method TestHeldLeavesOnlyToInvestigating()
{
	Set states = ##class(SignalNoir.Core.Vocab).States()
	For i = 1 : 1 : $ListLength(states) {
		Set to = $ListGet(states, i)
		Do $$$AssertEquals(##class(SignalNoir.Core.CaseMachine).CanTransition("Held", to), (to = "Investigating"), "Held -> " _ to)
	}
}

/// 003 T021 - where a new Exception goes
Method TestRouteException()
{
	Set m = "SignalNoir.Core.CaseMachine"
	Do $$$AssertEquals($ClassMethod(m, "RouteException", ""), "open", "no Case yet")
	For s = "Resolved", "ResolvedByPriorReceipt", "Cancelled", "Failed" {
		Do $$$AssertEquals($ClassMethod(m, "RouteException", s), "open", "after terminal " _ s)
	}
	For s = "Investigating", "Approved", "Executing" {
		Do $$$AssertEquals($ClassMethod(m, "RouteException", s), "attach", "attach only in " _ s)
	}
	For s = "Open", "DecisionProposed", "PendingApproval", "Rejected", "Held", "ReviewRequired" {
		Do $$$AssertEquals($ClassMethod(m, "RouteException", s), "attach_and_investigate", "reinvestigate from " _ s)
	}
}

/// 003 T047 - rejection has a limit
Method TestAfterRejection()
{
	Do $$$AssertEquals(##class(SignalNoir.Core.CaseMachine).AfterRejection(1), "Investigating", "first rejection")
	Do $$$AssertEquals(##class(SignalNoir.Core.CaseMachine).AfterRejection(2), "ReviewRequired", "second rejection")
}

}
