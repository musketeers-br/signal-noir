Class SignalNoir.Tests.Application.Reference.Fixtures.Good.PoliciesB Extends %RegisteredObject
{

/// Test-only Policy Set, version B: a second valid version, used to prove a pinned run keeps
/// its own versions while another is in force.
Parameter VERSION = "2026.10.2";

XData Content [ MimeType = application/json ]
{
{
  "version": "2026.10.2",
  "attempt": { "maxAttempts": 2 },
  "substitution": { "enabled": true },
  "maintenanceWindows": [],
  "partnerHealth": { "windowSeconds": 600, "maxErrorRate": 0.1 },
  "approval": { "deadlineSeconds": 600 }
}
}

}
