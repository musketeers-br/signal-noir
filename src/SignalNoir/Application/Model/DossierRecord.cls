Class SignalNoir.Application.Model.DossierRecord Extends %Persistent
{

/// A Review Dossier, recorded with the transition that moved the Case to
/// ReviewRequired (feature 009). Insert-only; the latest per Case is shown.
Property caseId As %String(MAXLEN = 64) [ Required ];

Index caseIdx On (caseId, createdAt);

Property createdAt As %String(MAXLEN = 64) [ Required ];

/// Contract Dossier.reason
Property reason As %String(MAXLEN = 64);

/// The contract Dossier, built by Core.DossierBuilder
Property dossierJson As %String(MAXLEN = 32000);

Storage Default
{
<Data name="DossierRecordDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>caseId</Value>
</Value>
<Value name="3">
<Value>createdAt</Value>
</Value>
<Value name="4">
<Value>reason</Value>
</Value>
<Value name="5">
<Value>dossierJson</Value>
</Value>
</Data>
<DataLocation>^SignalNoir.A70AE.DossierRecordD</DataLocation>
<DefaultData>DossierRecordDefaultData</DefaultData>
<IdLocation>^SignalNoir.A70AE.DossierRecordD</IdLocation>
<IndexLocation>^SignalNoir.A70AE.DossierRecordI</IndexLocation>
<StreamLocation>^SignalNoir.A70AE.DossierRecordS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
