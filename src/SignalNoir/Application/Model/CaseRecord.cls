Class SignalNoir.Application.Model.CaseRecord Extends %Persistent
{

/// The persisted source of truth for a resolution.
/// caseVersion is the domain version: +1 on every transition, never changed
/// by an attachment. Version is the VERSIONPROPERTY row version: IRIS bumps
/// it on every save and rejects a stale save (second guard).
Parameter VERSIONPROPERTY = "Version";

Property caseId As %String(MAXLEN = 64) [ Required ];

Index caseIdKey On caseId [ IdKey ];

Property orderId As %String(MAXLEN = 128) [ Required ];

Index orderIdIdx On orderId;

/// = orderId while the Case is non-terminal, empty once terminal: at most
/// one non-terminal Case per orderId
Property openOrderId As %String(MAXLEN = 128);

Index openOrderIdx On openOrderId [ Unique ];

/// Case of the previous episode of the same Order
Property previousCaseId As %String(MAXLEN = 64);

Property partnerId As %String(MAXLEN = 128);

Property state As %String(MAXLEN = 32) [ Required ];

Index stateIdx On state;

Property caseVersion As %Integer [ InitialExpression = 1 ];

/// Row version (managed by IRIS)
Property Version As %Integer;

/// Committed Timeline watermark: readers never see an event above it
Property lastEventSeq As %Integer [ InitialExpression = 0 ];

Property lastEventAt As %String(MAXLEN = 64);

Index activityIdx On (lastEventAt, caseId);

Property denialCount As %Integer [ InitialExpression = 0 ];

/// Set when the state is ReviewRequired
Property reviewReason As %String(MAXLEN = 256);

Property currentProposalId As %String(MAXLEN = 64);

Property currentApprovalId As %String(MAXLEN = 64);

Property currentExecutionId As %String(MAXLEN = 64);

/// Outcome of the latest Execution (feature 008); empty when none
Property executionOutcome As %String(MAXLEN = 32);

Property runId As %String(MAXLEN = 64);

Property proposerMode As %String(MAXLEN = 16) [ InitialExpression = "agent" ];

Property synthetic As %Boolean [ InitialExpression = 1 ];

Property replay As %Boolean [ InitialExpression = 0 ];

Property createdAt As %String(MAXLEN = 64);

Property updatedAt As %String(MAXLEN = 64);

}
