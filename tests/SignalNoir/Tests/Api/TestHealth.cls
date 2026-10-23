Class SignalNoir.Tests.Api.TestHealth Extends %UnitTest.TestCase
{

/// T020 - GET /health payload matches the frozen contract.
/// liveness=alive always; status=ready with key, degraded without; missing key never yields 5xx.
/// The container has no SN_AI_API_KEY, so the expected path is degraded.

Method TestHealthPayloadShape()
{
	Set payload = ##class(SignalNoir.Api.Health).Payload()
	Do $$$AssertTrue($IsObject(payload), "payload is an object")
	Do $$$AssertEquals(payload.liveness, "alive", "liveness is always alive")
	Do $$$AssertTrue($IsObject(payload.provider), "provider object present")
	Set configured = +payload.provider.configured
	Do $$$AssertTrue((configured = 0) || (configured = 1), "provider.configured is boolean")
	Do $$$AssertTrue((payload.status = "ready") || (payload.status = "degraded"), "status is ready or degraded")
	Do $$$AssertTrue(payload.serverTime '= "", "serverTime present and ISO-8601")
	Do $$$AssertTrue(payload.serverTime [ "T", "serverTime is ISO-8601 with a T separator")
	If configured = 1 {
		Do $$$AssertEquals(payload.status, "ready", "status ready when configured")
	} Else {
		Do $$$AssertEquals(payload.status, "degraded", "status degraded when not configured")
		Do $$$AssertTrue(payload.provider.reason '= "", "reason present when not configured")
		Do $$$AssertTrue($Find(payload.provider.reason, "provider unavailable") = 1, "reason names the unavailable provider")
	}
}

/// The Health endpoint never throws (never 5xx for missing key).

Method TestHealthNeverThrows()
{
	Set r = ##class(SignalNoir.Api.Health).Payload()
	Do $$$AssertTrue($IsObject(r), "Payload() never throws")
}

}