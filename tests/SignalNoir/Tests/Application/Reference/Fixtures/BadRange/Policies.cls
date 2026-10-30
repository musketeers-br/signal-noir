Class SignalNoir.Tests.Application.Reference.Fixtures.BadRange.Policies Extends %RegisteredObject
{

/// Test-only malformed Policy Set: an error rate above 1 and zero attempts.
Parameter VERSION = "2026.10.3";

XData Content [ MimeType = application/json ]
{
{
  "version": "2026.10.3",
  "attempt": { "maxAttempts": 0 },
  "substitution": { "enabled": true },
  "maintenanceWindows": [],
  "partnerHealth": { "windowSeconds": 300, "maxErrorRate": 1.5 },
  "approval": { "deadlineSeconds": 900 }
}
}

}
