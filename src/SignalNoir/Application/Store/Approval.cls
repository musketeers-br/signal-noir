/// A decision on one exact Proposal (FR-17), a record of its own linked to the Case
/// (Constitution Principle V).
Class SignalNoir.Application.Store.Approval Extends %Persistent
{

Property ApprovalId As %String(MAXLEN = 80) [ Required ];

Property CaseId As %String(MAXLEN = 80) [ Required ];

Property ProposalId As %String(MAXLEN = 80) [ Required ];

/// approved or denied.
Property Decision As %String(MAXLEN = 10) [ Required ];

/// operator:<name> or benchmark.
Property ByActor As %String(MAXLEN = 80) [ Required ];

Property At As %String(MAXLEN = 40);

Property ExpiresAt As %String(MAXLEN = 40);

Property Reason As %String(MAXLEN = "");

Index ApprovalIdIdx On ApprovalId [ IdKey, Unique ];

Index CaseIdx On CaseId;

ClassMethod NewId() As %String
{
    quit "appr_"_$zconvert($extract($translate($system.Util.CreateGUID(), "-"), 1, 16), "L")
}

Storage Default
{
<Data name="ApprovalDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>CaseId</Value>
</Value>
<Value name="3">
<Value>ProposalId</Value>
</Value>
<Value name="4">
<Value>Decision</Value>
</Value>
<Value name="5">
<Value>ByActor</Value>
</Value>
<Value name="6">
<Value>At</Value>
</Value>
<Value name="7">
<Value>ExpiresAt</Value>
</Value>
<Value name="8">
<Value>Reason</Value>
</Value>
</Data>
<DataLocation>^SignalNoir.App.ApprovalD</DataLocation>
<DefaultData>ApprovalDefaultData</DefaultData>
<IdLocation>^SignalNoir.App.ApprovalD</IdLocation>
<IndexLocation>^SignalNoir.App.ApprovalI</IndexLocation>
<StreamLocation>^SignalNoir.App.ApprovalS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
