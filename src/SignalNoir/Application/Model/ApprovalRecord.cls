Class SignalNoir.Application.Model.ApprovalRecord Extends %Persistent
{

/// The decision on one exact Proposal (contract Approval). Written by the
/// operator resolution (009); the approval command, replays and expiry are
/// feature 007's, over this same record (coordination-004-007.md).
Property approvalId As %String(MAXLEN = 64) [ Required ];

Index approvalKey On approvalId [ IdKey ];

Property caseId As %String(MAXLEN = 64) [ Required ];

Index caseIdx On caseId;

Property proposalId As %String(MAXLEN = 64) [ Required ];

Index proposalIdx On proposalId;

/// approved or denied
Property decision As %String(MAXLEN = 16) [ Required ];

/// operator:<name> or benchmark
Property by As %String(MAXLEN = 128) [ Required ];

Property at As %String(MAXLEN = 64);

Property expiresAt As %String(MAXLEN = 64);

/// valid, expired, consumed or superseded
Property status As %String(MAXLEN = 16) [ InitialExpression = "valid" ];

Property reason As %String(MAXLEN = 1024);

Storage Default
{
<Data name="ApprovalRecordDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>caseId</Value>
</Value>
<Value name="3">
<Value>proposalId</Value>
</Value>
<Value name="4">
<Value>decision</Value>
</Value>
<Value name="5">
<Value>by</Value>
</Value>
<Value name="6">
<Value>at</Value>
</Value>
<Value name="7">
<Value>expiresAt</Value>
</Value>
<Value name="8">
<Value>status</Value>
</Value>
<Value name="9">
<Value>reason</Value>
</Value>
</Data>
<DataLocation>^SignalNoir70AE.ApprovalRecordD</DataLocation>
<DefaultData>ApprovalRecordDefaultData</DefaultData>
<IdLocation>^SignalNoir70AE.ApprovalRecordD</IdLocation>
<IndexLocation>^SignalNoir70AE.ApprovalRecordI</IndexLocation>
<StreamLocation>^SignalNoir70AE.ApprovalRecordS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
