Class SignalNoir.Tests.Core.TestResolutionShape Extends %UnitTest.TestCase
{

/// 009 T008 - a resolution is a catalog Action with its allowed params, or a
/// cancellation with a reason; nothing else (no free payload)
ClassMethod Reasons(request) As %String
{
	Set r = ##class(SignalNoir.Core.ResolutionShape).Check(request)
	Set out = ""
	For i = 1 : 1 : r.Count() Set out = out _ r.GetAt(i) _ ";"
	Return out
}

Method TestValid()
{
	Do $$$AssertEquals(..Reasons({"kind": "action", "operator": "Carla", "expectedCaseVersion": 3, "action": "APPLY_APPROVED_MAPPING", "params": {"mappingId": "m", "mappingVersion": "1"}, "note": "phone"}), "", "mapping")
	Do $$$AssertEquals(..Reasons({"kind": "action", "operator": "Carla", "expectedCaseVersion": 3, "action": "RETRY"}), "", "retry without params")
	Do $$$AssertEquals(..Reasons({"kind": "action", "operator": "Carla", "expectedCaseVersion": 3, "action": "HOLD", "params": {"reason": "maintenance"}}), "", "hold with reason")
	Do $$$AssertEquals(..Reasons({"kind": "cancel", "operator": "Carla", "expectedCaseVersion": 3, "reason": "duplicate"}), "", "cancel")
}

Method TestNoFreePayload()
{
	Do $$$AssertEquals(..Reasons({"kind": "action", "operator": "Carla", "expectedCaseVersion": 3, "action": "RETRY", "payload": {"exams": []}}), "unknown_field:payload;", "payload refused")
	Do $$$AssertEquals(..Reasons({"kind": "action", "operator": "Carla", "expectedCaseVersion": 3, "action": "RETRY", "params": {"orderSnapshot": "{}"}}), "params.orderSnapshot:not_allowed;", "unknown param refused")
	Do $$$AssertEquals(..Reasons({"kind": "action", "operator": "Carla", "expectedCaseVersion": 3, "action": "APPLY_APPROVED_MAPPING", "params": {"mappingId": {"x": 1}, "mappingVersion": "1"}}), "params.mappingId:not_text;", "object param refused")
	Do $$$AssertEquals(..Reasons({"kind": "cancel", "operator": "Carla", "expectedCaseVersion": 3, "reason": "x", "action": "RETRY"}), "unknown_field:action;", "cancel takes no action")
}

Method TestFields()
{
	Do $$$AssertEquals(..Reasons({"kind": "edit", "operator": "Carla", "expectedCaseVersion": 3}), "kind:invalid;", "kind")
	Do $$$AssertEquals(..Reasons({"kind": "action", "operator": "", "expectedCaseVersion": 3, "action": "RETRY"}), "operator:missing;", "name required")
	Do $$$AssertEquals(..Reasons({"kind": "action", "operator": "op:x", "expectedCaseVersion": 3, "action": "RETRY"}), "operator:invalid;", "no colon")
	Do $$$AssertEquals(..Reasons({"kind": "action", "operator": "Carla", "expectedCaseVersion": "three", "action": "RETRY"}), "expectedCaseVersion:invalid;", "version")
	Do $$$AssertEquals(..Reasons({"kind": "action", "operator": "Carla", "expectedCaseVersion": 3, "action": "DELETE"}), "action:not_in_catalog;", "catalog")
	Do $$$AssertEquals(..Reasons({"kind": "action", "operator": "Carla", "expectedCaseVersion": 3, "action": "REQUEST_REVIEW"}), "action:already_in_review;", "no review loop")
	Do $$$AssertEquals(..Reasons({"kind": "cancel", "operator": "Carla", "expectedCaseVersion": 3, "reason": "  "}), "reason:missing;", "cancel reason")
	Do $$$AssertEquals(..Reasons(""), "body:not_an_object;", "no body")
}

}
