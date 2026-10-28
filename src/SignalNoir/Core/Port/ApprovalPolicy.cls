Class SignalNoir.Core.Port.ApprovalPolicy Extends %RegisteredObject [ Abstract ]
{

/// The approval deadline and who may act as the benchmark (spec 007 FR-008,
/// FR-014). Feature 004 owns the real policy (policies.approval and
/// Admit(actor, run)); Core.ApprovalPolicy is the default until it lands.
Method DeadlineSeconds() As %Integer
{
	Return 0
}

/// True when this actor may decide on a Case of this run ("" = none)
Method Admit(actor As %String, runId As %String) As %Boolean
{
	Return 0
}

/// The deadline of an approval given at this instant
Method ExpiresAt(at As %String) As %String
{
	Return ##class(SignalNoir.Core.ApprovalPolicy).Plus(at, ..DeadlineSeconds())
}

/// True when now is past the deadline; an approval without one never expires
Method IsExpired(expiresAt As %String, now As %String) As %Boolean
{
	If expiresAt = "" Return 0
	Return ##class(SignalNoir.Core.ApprovalPolicy).Seconds(now) > ##class(SignalNoir.Core.ApprovalPolicy).Seconds(expiresAt)
}

}
