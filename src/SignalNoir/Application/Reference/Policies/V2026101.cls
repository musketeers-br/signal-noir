Class SignalNoir.Application.Reference.Policies.V2026101 Extends %RegisteredObject
{

/// Policy Set 2026.10.1 (004 data-model, research D6). Changing a value is a new version, a
/// new class. Loaded and checked by Application.Reference.Store.
Parameter VERSION = "2026.10.1";

XData Content [ MimeType = application/json ]
{
{
  "version": "2026.10.1",
  "attempt": { "maxAttempts": 3 },
  "substitution": { "enabled": true },
  "maintenanceWindows": [],
  "partnerHealth": { "windowSeconds": 300, "maxErrorRate": 0.2 },
  "approval": { "deadlineSeconds": 900 }
}
}

}
