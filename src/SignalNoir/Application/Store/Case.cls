/// The persisted Case (AD-4: the source of truth). Changed only through
/// SignalNoir.Application.CaseCommands (AD-2). Approvals and Executions are separate records.
Class SignalNoir.Application.Store.Case Extends %Persistent [ SqlTableName = CaseRecord ]
{

Property CaseId As %String(MAXLEN = 80) [ Required ];

Property OrderId As %String(MAXLEN = 200) [ Required ];

Property State As %String(MAXLEN = 40) [ Required ];

Property CaseVersion As %Integer [ InitialExpression = 1, Required ];

Property DenialCount As %Integer [ InitialExpression = 0 ];

Property StepLeaseUntil As %String(MAXLEN = 40);

Property CurrentProposalId As %String(MAXLEN = 80);

Property ProposerMode As %String(MAXLEN = 10) [ InitialExpression = "agent" ];

Property BenchmarkRunId As %String(MAXLEN = 80);

Property PendingReassessmentExceptions As %Integer [ InitialExpression = 0 ];

/// The latest Approval and Execution records of this Case.
Property CurrentApprovalId As %String(MAXLEN = 80);

Property CurrentExecutionId As %String(MAXLEN = 80);

Property PreviousEpisodeCaseId As %String(MAXLEN = 80);

Property CreatedAt As %String(MAXLEN = 40);

Property LastEventAt As %String(MAXLEN = 40);

/// Synthetic data label (FR-38); always true.
Property LabelSynthetic As %Boolean [ InitialExpression = 1 ];

Property LabelReplay As %Boolean [ InitialExpression = 0 ];

/// OrderId while the Case is not terminal, "closed:"_CaseId once it is; unique, so at most one
/// non-terminal Case exists per Order (AD-25, specs/002 research R7).
Property OpenOrderKey As %String(MAXLEN = 200) [ SqlComputeCode = { set {*} = ##class(SignalNoir.Application.Store.Case).ComputeOpenOrderKey({State}, {OrderId}, {CaseId})}, SqlComputed, SqlComputeOnChange = (State, OrderId, CaseId) ];

Index CaseIdIdx On CaseId [ IdKey, Unique ];

Index OpenOrderKeyIdx On OpenOrderKey [ Unique ];

Index OrderIdx On OrderId;

ClassMethod ComputeOpenOrderKey(state As %String, orderId As %String, caseId As %String) As %String
{
    quit $select(##class(SignalNoir.Core.TransitionTable).IsTerminal(state): "closed:"_caseId, 1: orderId)
}

ClassMethod NewId() As %String
{
    quit "case_"_$zconvert($extract($translate($system.Util.CreateGUID(), "-"), 1, 16), "L")
}

Storage Default
{
<Data name="CaseDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>OrderId</Value>
</Value>
<Value name="3">
<Value>State</Value>
</Value>
<Value name="4">
<Value>CaseVersion</Value>
</Value>
<Value name="5">
<Value>DenialCount</Value>
</Value>
<Value name="6">
<Value>StepLeaseUntil</Value>
</Value>
<Value name="7">
<Value>CurrentProposalId</Value>
</Value>
<Value name="8">
<Value>ProposerMode</Value>
</Value>
<Value name="9">
<Value>BenchmarkRunId</Value>
</Value>
<Value name="10">
<Value>PendingReassessmentExceptions</Value>
</Value>
<Value name="11">
<Value>PreviousEpisodeCaseId</Value>
</Value>
<Value name="12">
<Value>CreatedAt</Value>
</Value>
<Value name="13">
<Value>LastEventAt</Value>
</Value>
<Value name="14">
<Value>LabelSynthetic</Value>
</Value>
<Value name="15">
<Value>LabelReplay</Value>
</Value>
<Value name="16">
<Value>OpenOrderKey</Value>
</Value>
<Value name="17">
<Value>CurrentApprovalId</Value>
</Value>
<Value name="18">
<Value>CurrentExecutionId</Value>
</Value>
</Data>
<DataLocation>^SignalNoir.App.CaseD</DataLocation>
<DefaultData>CaseDefaultData</DefaultData>
<IdLocation>^SignalNoir.App.CaseD</IdLocation>
<IndexLocation>^SignalNoir.App.CaseI</IndexLocation>
<StreamLocation>^SignalNoir.App.CaseS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
