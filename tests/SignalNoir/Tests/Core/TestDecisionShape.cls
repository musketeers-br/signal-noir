Class SignalNoir.Tests.Core.TestDecisionShape Extends %UnitTest.TestCase
{

/// 007 T002 - the Operator's decision on a Proposal (contract
/// ProposalDecisionRequest): approved or denied, a name, the version seen,
/// and a reason when denying; nothing else
ClassMethod Reasons(request) As %String
{
	Set r = ##class(SignalNoir.Core.DecisionShape).Check(request)
	Set out = ""
	For i = 1 : 1 : r.Count() Set out = out _ r.GetAt(i) _ ";"
	Return out
}

Method TestValid()
{
	Do $$$AssertEquals(..Reasons({"decision": "approved", "operator": "Carla", "expectedCaseVersion": 7}), "", "approve")
	Do $$$AssertEquals(..Reasons({"decision": "approved", "operator": "Carla", "expectedCaseVersion": 0, "reason": "looks right"}), "", "approve with a note")
	Do $$$AssertEquals(..Reasons({"decision": "denied", "operator": "Carla", "expectedCaseVersion": 7, "reason": "plasma, not serum"}), "", "deny with reason")
}

Method TestRefused()
{
	Do $$$AssertEquals(..Reasons(""), "body:not_an_object;", "no body")
	Do $$$AssertEquals(..Reasons({"decision": "maybe", "operator": "Carla", "expectedCaseVersion": 7}), "decision:invalid;", "decision")
	Do $$$AssertEquals(..Reasons({"decision": "denied", "operator": "Carla", "expectedCaseVersion": 7}), "reason:required_on_denial;", "denial needs a reason")
	Do $$$AssertEquals(..Reasons({"decision": "denied", "operator": "Carla", "expectedCaseVersion": 7, "reason": "   "}), "reason:required_on_denial;", "blank reason")
	Do $$$AssertEquals(..Reasons({"decision": "approved", "operator": "", "expectedCaseVersion": 7}), "operator:missing;", "name")
	Do $$$AssertEquals(..Reasons({"decision": "approved", "operator": "op:x", "expectedCaseVersion": 7}), "operator:invalid;", "no colon")
	Do $$$AssertEquals(..Reasons({"decision": "approved", "operator": 42, "expectedCaseVersion": 7}), "operator:invalid;", "name is text")
	Do $$$AssertEquals(..Reasons({"decision": "approved", "operator": "Carla", "expectedCaseVersion": "7"}), "expectedCaseVersion:invalid;", "version is a number")
	Do $$$AssertEquals(..Reasons({"decision": "approved", "operator": "Carla", "expectedCaseVersion": 1.5}), "expectedCaseVersion:invalid;", "whole number")
	Do $$$AssertEquals(..Reasons({"decision": "approved", "operator": "Carla", "expectedCaseVersion": 7, "reason": 3}), "reason:not_text;", "reason is text")
	Do $$$AssertEquals(..Reasons({"decision": "approved", "operator": "Carla", "expectedCaseVersion": 7, "actor": "benchmark"}), "unknown_field:actor;", "no actor field")
}

}
