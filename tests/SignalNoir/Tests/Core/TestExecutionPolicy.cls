Class SignalNoir.Tests.Core.TestExecutionPolicy Extends %UnitTest.TestCase
{

/// 008 T004 - the default revalidation rule and limits until 004
Method TestPasses()
{
	Set r = ..Run(..Input())
	Do $$$AssertTrue(r.passed, "all satisfied")
	Do $$$AssertEquals(r.destination, "Executing", "authorize")
	Do $$$AssertEquals(r.checks.%Size(), 5, "the five checks of AD-26")
	Do $$$AssertEquals(..Failed(r), "", "none failed")
}

Method TestHolds()
{
	For status = "DEGRADED", "DOWN" {
		Set in = ..Input(), in.health.status = status
		Set r = ..Run(in)
		Do $$$AssertEquals(r.destination _ "|" _ ..Failed(r), "Held|PARTNER_HEALTHY_WINDOW", status)
	}
	Set in = ..Input(), in.health.maintenance = {"active": true, "startsAt": "2026-10-28T09:00:00Z", "endsAt": "2026-10-28T11:00:00Z"}
	Do $$$AssertEquals(..Run(in).destination, "Held", "announced maintenance")
	Set in = ..Input()
	Do in.%Set("health", "", "null")
	Set r = ..Run(in)
	Do $$$AssertEquals(r.destination _ "|" _ ..Failed(r), "Held|PARTNER_HEALTHY_WINDOW", "unreadable health is not satisfied")
	Do $$$AssertEquals(r.checks.%Get(0).observed, "unreadable", "and says so")
	Set in = ..Input()
	Do in.%Set("origin", "", "null")
	Do $$$AssertEquals(..Run(in).destination, "Held", "unreadable Origin status holds, never cancels")
	Set in = ..Input(), in.current.policy = "pol-v2"
	Set r = ..Run(in)
	Do $$$AssertEquals(r.destination _ "|" _ ..Failed(r), "Held|POLICY_VERSION_UNCHANGED", "policy changed")
	Do $$$AssertTrue(r.versionHold, "a version hold")
	Set in = ..Input(), in.current.mapping = "map-v9"
	Do $$$AssertEquals(..Failed(..Run(in)), "MAPPING_VERSION_UNCHANGED", "mapping changed")
	Set in = ..Input(), in.payloadError = "mapping unavailable"
	Set r = ..Run(in)
	Do $$$AssertEquals(r.destination _ "|" _ r.reason, "Held|mapping unavailable", "no payload, no send")
}

Method TestCancelsAndApproval()
{
	Set in = ..Input(), in.origin.status = "cancelled", in.health.status = "DOWN"
	Set r = ..Run(in)
	Do $$$AssertEquals(r.destination, "Cancelled", "cancel wins over hold")
	Set in = ..Input(), in.approval.expiresAt = "2026-10-28T09:59:59Z"
	Set r = ..Run(in)
	Do $$$AssertEquals(r.destination _ "|" _ ..Failed(r), "|APPROVAL_VALID", "expired approval: no state change")
	Do $$$AssertNotTrue(r.passed, "and no send")
	Set in = ..Input(), in.approval.status = "superseded"
	Do $$$AssertEquals(..Run(in).destination, "", "a superseded approval authorizes nothing")
	Set in = ..Input(), in.approval.required = 0
	Set r = ..Run(in)
	Do $$$AssertEquals(r.checks.%Size(), 4, "HOLD needs no approval check")
}

Method TestLimitsAndPayload()
{
	Set p = ##class(SignalNoir.Core.ExecutionPolicy).%New()
	Do $$$AssertEquals(p.MaxAttempts(), 3, "three attempts")
	Do $$$AssertEquals(p.MinHoldSeconds(), 300, "five minutes held")
	Do $$$AssertEquals(p.LeaseSeconds(), 300, "the AD-22 step lease")
	Do $$$AssertTrue(p.LeaseSeconds() > ##class(SignalNoir.Interop.Bootstrap).#PARTNERTIMEOUTSECONDS, "outlasts the Partner client timeout (FR-019)")
	Set snap = {"orderId": "ORD-1"}
	Set r = p.EffectPayload("RETRY", {}, snap)
	Do $$$AssertEquals(r.obj.orderId, "ORD-1", "RETRY sends the snapshot")
	Set r = p.EffectPayload("APPLY_APPROVED_MAPPING", {"mappingId": "m1", "mappingVersion": "v1"}, snap)
	Do $$$AssertNotTrue(r.ok, "no mapping catalog until 004")
	Do $$$AssertTrue(r.message [ "mapping unavailable", r.message)
}

Method Input() As %DynamicObject [ Private ]
{
	Return {"now": "2026-10-28T10:00:00Z", "health": {"status": "UP", "maintenance": null}, "origin": {"status": "active"},
		"approval": {"required": true, "status": "valid", "expiresAt": "2026-10-28T10:15:00Z"},
		"versions": {"policy": "pol-v1", "mapping": "map-v1"}, "current": {"policy": "", "mapping": ""}, "payloadError": ""}
}

Method Run(input As %DynamicObject) As %DynamicObject [ Private ]
{
	Return ##class(SignalNoir.Core.ExecutionPolicy).%New().Revalidate(input)
}

/// Comma list of the failed checks
Method Failed(r As %DynamicObject) As %String [ Private ]
{
	Set out = ""
	For i = 0 : 1 : r.checks.%Size() - 1 {
		If 'r.checks.%Get(i).passed Set out = out _ $Select(out = "": "", 1: ",") _ r.checks.%Get(i).check
	}
	Return out
}

}
