Class SignalNoir.Application.Model.ProposalRecord Extends %Persistent
{

/// The immutable Proposal. contentHash is fixed at insert; a later save that
/// changes the content is refused. Only current and supersededBy change.
Property proposalId As %String(MAXLEN = 64) [ Required ];

Index proposalKey On proposalId [ IdKey ];

Property caseId As %String(MAXLEN = 64) [ Required ];

Index caseIdx On caseId;

Property investigationId As %String(MAXLEN = 64);

/// agent, rules, replay or operator:<name>
Property author As %String(MAXLEN = 128) [ Required ];

Property createdAt As %String(MAXLEN = 64);

Property current As %Boolean [ InitialExpression = 1 ];

Property supersededBy As %String(MAXLEN = 64);

Property diagnosisJson As %String(MAXLEN = 32000);

Property action As %String(MAXLEN = 64) [ Required ];

Property paramsJson As %String(MAXLEN = 4096);

Property scope As %String(MAXLEN = 32) [ InitialExpression = "single_case" ];

Property confidence As %String(MAXLEN = 16);

Property preconditionsJson As %String(MAXLEN = 4096);

Property versionsJson As %String(MAXLEN = 4096);

Property metricsJson As %String(MAXLEN = 4096);

Property priorReceiptCandidateJson As %String(MAXLEN = 1024);

Property contentHash As %String(MAXLEN = 128);

/// The Validator's verdict on this exact Proposal (contract ValidatorVerdict),
/// recorded with it; not part of the immutable content
Property verdictJson As %String(MAXLEN = 4096);

/// The content the hash covers (everything but current/supersededBy)
Method Content() As %String
{
	Return $ListToString($ListBuild(..proposalId, ..caseId, ..investigationId, ..author, ..createdAt, ..diagnosisJson, ..action, ..paramsJson, ..scope, ..confidence, ..preconditionsJson, ..versionsJson, ..metricsJson, ..priorReceiptCandidateJson), $Char(30))
}

Method Hash() As %String
{
	Return $System.Encryption.Base64Encode($System.Encryption.SHAHash(256, $ZConvert(..Content(), "O", "UTF8")), 1)
}

Method %OnBeforeSave(insert As %Boolean) As %Status [ Private, ServerOnly = 1 ]
{
	If insert {
		Set ..contentHash = ..Hash()
		Return $$$OK
	}
	If ..Hash() '= ..contentHash Return $$$ERROR($$$GeneralError, "a Proposal is immutable: " _ ..proposalId)
	Return $$$OK
}

Storage Default
{
<Data name="ProposalRecordDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>caseId</Value>
</Value>
<Value name="3">
<Value>investigationId</Value>
</Value>
<Value name="4">
<Value>author</Value>
</Value>
<Value name="5">
<Value>createdAt</Value>
</Value>
<Value name="6">
<Value>current</Value>
</Value>
<Value name="7">
<Value>supersededBy</Value>
</Value>
<Value name="8">
<Value>diagnosisJson</Value>
</Value>
<Value name="9">
<Value>action</Value>
</Value>
<Value name="10">
<Value>paramsJson</Value>
</Value>
<Value name="11">
<Value>scope</Value>
</Value>
<Value name="12">
<Value>confidence</Value>
</Value>
<Value name="13">
<Value>preconditionsJson</Value>
</Value>
<Value name="14">
<Value>versionsJson</Value>
</Value>
<Value name="15">
<Value>metricsJson</Value>
</Value>
<Value name="16">
<Value>priorReceiptCandidateJson</Value>
</Value>
<Value name="17">
<Value>contentHash</Value>
</Value>
</Data>
<DataLocation>^SignalNoir70AE.ProposalRecordD</DataLocation>
<DefaultData>ProposalRecordDefaultData</DefaultData>
<IdLocation>^SignalNoir70AE.ProposalRecordD</IdLocation>
<IndexLocation>^SignalNoir70AE.ProposalRecordI</IndexLocation>
<StreamLocation>^SignalNoir70AE.ProposalRecordS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
