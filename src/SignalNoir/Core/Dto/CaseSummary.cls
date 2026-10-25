Class SignalNoir.Core.Dto.CaseSummary Extends %RegisteredObject
{

/// Fully populated in this slice (seam contract)
Property caseId As %String(MAXLEN = 64);

Property state As %String(MAXLEN = 32);

Property caseVersion As %Integer;

Property lastEventAt As %String(MAXLEN = 64);

Property synthetic As %Boolean;

/// Contract change 003 (additive)
Property orderId As %String(MAXLEN = 128);

Property partnerId As %String(MAXLEN = 128);

Property createdAt As %String(MAXLEN = 64);

Property lastEventSeq As %Integer;

Property replay As %Boolean [ InitialExpression = 0 ];

Property exceptionCount As %Integer [ InitialExpression = 0 ];

Property lastExceptionSummary As %String(MAXLEN = 256);

Property executionOutcome As %String(MAXLEN = 32);

Property currentProposalId As %String(MAXLEN = 64);

Property runId As %String(MAXLEN = 64);

Property proposerMode As %String(MAXLEN = 16);

}
