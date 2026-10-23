/// A recorded authorization to execute (FR-21), a record of its own linked to the Case and its
/// Approval (Constitution Principle V). A voided authorization is never accepted again.
Class SignalNoir.Application.Store.Execution Extends %Persistent
{

Property ExecutionId As %String(MAXLEN = 80) [ Required ];

Property CaseId As %String(MAXLEN = 80) [ Required ];

/// Empty for HOLD, which needs no Approval.
Property ApprovalId As %String(MAXLEN = 80);

Property ProposalId As %String(MAXLEN = 80);

/// in_progress, reconciling, resolved, held, cancelled or failed.
Property Outcome As %String(MAXLEN = 20) [ InitialExpression = "in_progress" ];

Property AttemptsSent As %Integer [ InitialExpression = 0 ];

Property InconclusiveReconciliations As %Integer [ InitialExpression = 0 ];

Property AuthorizationVoided As %Boolean [ InitialExpression = 0 ];

Property AuthorizedAt As %String(MAXLEN = 40);

Index ExecutionIdIdx On ExecutionId [ IdKey, Unique ];

Index CaseIdx On CaseId;

ClassMethod NewId() As %String
{
    quit "exec_"_$zconvert($extract($translate($system.Util.CreateGUID(), "-"), 1, 16), "L")
}

Storage Default
{
<Data name="ExecutionDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>CaseId</Value>
</Value>
<Value name="3">
<Value>ApprovalId</Value>
</Value>
<Value name="4">
<Value>ProposalId</Value>
</Value>
<Value name="5">
<Value>Outcome</Value>
</Value>
<Value name="6">
<Value>AttemptsSent</Value>
</Value>
<Value name="7">
<Value>InconclusiveReconciliations</Value>
</Value>
<Value name="8">
<Value>AuthorizationVoided</Value>
</Value>
<Value name="9">
<Value>AuthorizedAt</Value>
</Value>
</Data>
<DataLocation>^SignalNoir.App.ExecutionD</DataLocation>
<DefaultData>ExecutionDefaultData</DefaultData>
<IdLocation>^SignalNoir.App.ExecutionD</IdLocation>
<IndexLocation>^SignalNoir.App.ExecutionI</IndexLocation>
<StreamLocation>^SignalNoir.App.ExecutionS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
