Class SignalNoir.Core.Port.ExecutionPolicy Extends %RegisteredObject [ Abstract ]
{

/// What an execution checks and how far it goes (spec 008 FR-002, FR-011,
/// FR-019, FR-020). Feature 004 owns the real rules (Revalidate(input),
/// policies, the mapping catalog); Core.ExecutionPolicy is the default until
/// it lands (contracts/coordination.md).
/// input: {now, health, origin, approval, versions, current}; returns
/// {passed, checks[], destination ("", Held, Cancelled), reason}
Method Revalidate(input As %DynamicObject) As %DynamicObject
{
	Return {"passed": false, "checks": [], "destination": "Held", "reason": "no revalidation rule"}
}

/// Attempts per execution, the first included
Method MaxAttempts() As %Integer
{
	Return 1
}

/// Seconds a Case stays Held before it is reassessed
Method MinHoldSeconds() As %Integer
{
	Return 0
}

/// Seconds an execution step may hold its lease
Method LeaseSeconds() As %Integer
{
	Return 0
}

/// {policy, mapping}: the versions in force ("" = no reference data loaded)
Method CurrentVersions() As %DynamicObject
{
	Return {"policy": "", "mapping": ""}
}

/// The payload an Action sends (Result.obj) or why it cannot be built
Method EffectPayload(action As %String, params As %DynamicObject, snapshot As %DynamicObject) As SignalNoir.Core.Result
{
	Return ##class(SignalNoir.Core.Result).Error("", "no effect payload rule")
}

}
