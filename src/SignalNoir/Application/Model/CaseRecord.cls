Class SignalNoir.Application.Model.CaseRecord Extends %Persistent
{

/// The persisted source of truth for a resolution.
/// caseVersion is the VERSIONPROPERTY: IRIS increments it on every save and
/// rejects a save whose row version no longer matches (optimistic concurrency).

Parameter VERSIONPROPERTY = "Version";

Property caseId As %String(MAXLEN=64) [ Required ];

Index caseIdKey On caseId [ Idkey ];

Property orderId As %String(MAXLEN=128) [ Required ];

Index orderIdIdx On orderId;

/// Partner-issued identifier, when the Order snapshot carries one
Property partnerId As %String(MAXLEN=128);

Property state As %String(MAXLEN=32) [ Required ];

/// Optimistic concurrency version (managed by IRIS)
Property Version As %Integer;

Property lastEventSeq As %Integer;

Property lastEventAt As %String(MAXLEN=64);

Property synthetic As %Boolean [ InitialExpression = 1 ];

Property replay As %Boolean [ InitialExpression = 0 ];

/// Set when the state is ReviewRequired
Property reviewReason As %String(MAXLEN=256);

Property createdAt As %String(MAXLEN=64);

Property updatedAt As %String(MAXLEN=64);

}
