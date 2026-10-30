Class SignalNoir.Tests.Application.Reference.Fixtures.BadPolicyKey.Policies Extends %RegisteredObject
{

/// Test-only malformed Policy Set: a key the policy contract does not define.
Parameter VERSION = "2026.10.3";

XData Content [ MimeType = application/json ]
{
{
  "version": "2026.10.3",
  "attempt": { "maxAttempts": 3 },
  "substitution": { "enabled": true },
  "maintenanceWindows": [],
  "partnerHealth": { "windowSeconds": 300, "maxErrorRate": 0.2 },
  "approval": { "deadlineSeconds": 900 },
  "retryBackoff": { "seconds": 30 }
}
}

}
