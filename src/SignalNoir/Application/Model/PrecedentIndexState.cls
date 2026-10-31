Class SignalNoir.Application.Model.PrecedentIndexState Extends %Persistent
{

/// The single row of the precedent index state (feature 015): whether a
/// rebuild is running and the last indexing outcome. Model, mode and
/// dimension come from the configured embedder, counts from the records.
Property name As %String [ InitialExpression = "default", Required ];

Index nameKey On name [ IdKey ];

Property rebuilding As %Boolean [ InitialExpression = 0 ];

Property rebuildStartedAt As %String(MAXLEN = 64);

Property lastIndexedAt As %String(MAXLEN = 64);

/// Reason of the last failed embedding: no key, no text
Property lastError As %String(MAXLEN = 256);

ClassMethod Current() As SignalNoir.Application.Model.PrecedentIndexState
{
	Set state = ..%OpenId("default")
	If '$IsObject(state) Set state = ..%New()
	Return state
}

}
