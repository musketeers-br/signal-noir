Class SignalNoir.Core.ExecutionPolicy Extends SignalNoir.Core.Port.ExecutionPolicy
{

/// Default execution policy until feature 004 (008 coordination): healthy
/// means UP with no active maintenance; the Order must be active; the
/// approval valid and within its deadline; the policy and mapping the
/// Proposal relied on still current. 3 attempts, 5 minutes of minimum hold,
/// the step lease of AD-22 (SN_AI_LEASE_SECONDS, 300 s, which the bootstrap
/// keeps above the Partner timeout + the investigation budget). Pure: the
/// caller observes.
Parameter MAXATTEMPTS = 3;

Parameter MINHOLDSECONDS = 300;

/// The step lease in seconds, set by the owner from the environment (no I/O here)
Property Lease As %Integer [ InitialExpression = 300 ];

/// input: {now, health: {status, maintenance} | null, origin: {status} | null,
/// approval: {required, status, expiresAt} , versions: {policy, mapping}
/// (the Proposal's), current: {policy, mapping}, payloadError}
Method Revalidate(input As %DynamicObject) As %DynamicObject
{
	Set checks = []
	Set health = input.%Get("health"), origin = input.%Get("origin"), approval = input.%Get("approval")
	; PARTNER_HEALTHY_WINDOW: an unreadable health counts as not satisfied (FR-002)
	Set observed = $Select($IsObject(health): health.status, 1: "unreadable")
	Set inMaintenance = $IsObject(health) && $IsObject(health.%Get("maintenance")) && health.maintenance.active
	If inMaintenance Set observed = observed _ ", maintenance active"
	Set healthy = $IsObject(health) && (health.status = "UP") && 'inMaintenance
	Do checks.%Push(..Check("PARTNER_HEALTHY_WINDOW", "UP, no maintenance", observed, healthy))
	; ORDER_ACTIVE_AT_ORIGIN
	Set status = $Select($IsObject(origin): origin.status, 1: "unreadable")
	Set cancelled = (status = "cancelled")
	Do checks.%Push(..Check("ORDER_ACTIVE_AT_ORIGIN", "active", status, (status = "active")))
	; APPROVAL_VALID (only for an Action that needs one)
	Set approvalOk = 1
	If $IsObject(approval) && approval.required {
		Set approvalOk = (approval.status = "valid") && '##class(SignalNoir.Core.ApprovalPolicy).%New().IsExpired(approval.expiresAt, input.now)
		Do checks.%Push(..Check("APPROVAL_VALID", "valid until " _ approval.expiresAt, approval.status, approvalOk))
	}
	; POLICY_VERSION_UNCHANGED, MAPPING_VERSION_UNCHANGED ("" current = nothing loaded)
	Set versionsOk = 1
	For pair = "POLICY_VERSION_UNCHANGED:policy", "MAPPING_VERSION_UNCHANGED:mapping" {
		Set name = $Piece(pair, ":", 1), field = $Piece(pair, ":", 2)
		Set expected = $Select($IsObject(input.%Get("versions")): input.versions.%Get(field), 1: "")
		Set current = $Select($IsObject(input.%Get("current")): input.current.%Get(field), 1: "")
		Set ok = (current = "") || (current = expected)
		If (field = "mapping") && (input.%Get("payloadError") '= "") Set ok = 0, current = input.payloadError
		Do checks.%Push(..Check(name, expected, $Select(current = "": expected, 1: current), ok))
		Set versionsOk = versionsOk && ok
	}
	Set out = {"checks": (checks)}
	If cancelled {
		Set out.destination = "Cancelled", out.reason = "order cancelled at the origin"
	} ElseIf 'approvalOk {
		Set out.destination = "", out.reason = "approval no longer valid"
	} ElseIf 'healthy {
		Set out.destination = "Held", out.reason = "partner not in a healthy window: " _ observed
	} ElseIf status '= "active" {
		Set out.destination = "Held", out.reason = "order status at the origin: " _ status
	} ElseIf 'versionsOk {
		Set out.destination = "Held", out.reason = $Select(input.%Get("payloadError") '= "": input.payloadError, 1: "policy or mapping version changed")
	} Else {
		Set out.destination = "Executing", out.reason = "revalidation passed"
	}
	Do out.%Set("passed", (out.destination = "Executing"), "boolean")
	Do out.%Set("versionHold", ('versionsOk && healthy && (status = "active") && approvalOk), "boolean")
	Return out
}

Method MaxAttempts() As %Integer
{
	Return ..#MAXATTEMPTS
}

Method MinHoldSeconds() As %Integer
{
	Return ..#MINHOLDSECONDS
}

Method LeaseSeconds() As %Integer
{
	Return ..Lease
}

/// RETRY sends the Order as received; a mapping needs 004's catalog
Method EffectPayload(action As %String, params As %DynamicObject, snapshot As %DynamicObject) As SignalNoir.Core.Result
{
	If action = "RETRY" Return ##class(SignalNoir.Core.Result).OkObj(snapshot)
	If action = "APPLY_APPROVED_MAPPING" Return ##class(SignalNoir.Core.Result).Error("", "mapping unavailable: no mapping catalog loaded")
	Return ##class(SignalNoir.Core.Result).Error("", "no effect for " _ action)
}

ClassMethod Check(name As %String, expected, observed, passed As %Boolean) As %DynamicObject [ Private ]
{
	Set c = {"check": (name), "expected": (expected), "observed": (observed)}
	Do c.%Set("passed", ''passed, "boolean")
	Return c
}

}
