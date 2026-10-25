Class SignalNoir.Core.Dto.Case Extends %RegisteredObject
{

/// Fully populated in this slice (seam contract)
Property caseId As %String(MAXLEN = 64);

Property orderId As %String(MAXLEN = 128);

Property state As %String(MAXLEN = 32);

Property caseVersion As %Integer;

Property lastEventSeq As %Integer;

Property lastEventAt As %String(MAXLEN = 64);

Property synthetic As %Boolean;

Property replay As %Boolean;

Property reviewReason As %String(MAXLEN = 256);

/// Optional fields the product HTTP contract asks for; the seam only
/// requires the fields above, so these stay additive.
Property createdAt As %String(MAXLEN = 64);

Property partnerId As %String(MAXLEN = 128);

/// Contract change 003 (additive)
Property denialCount As %Integer [ InitialExpression = 0 ];

Property previousCaseId As %String(MAXLEN = 64);

Property currentProposalId As %String(MAXLEN = 64);

Property currentApprovalId As %String(MAXLEN = 64);

Property currentExecutionId As %String(MAXLEN = 64);

Property executionOutcome As %String(MAXLEN = 32);

Property updatedAt As %String(MAXLEN = 64);

Property runId As %String(MAXLEN = 64);

Property proposerMode As %String(MAXLEN = 16);

/// Filled by GetCase: the Order view and the Exceptions of the Case
Property order As SignalNoir.Core.Dto.Order;

Property exceptions As list Of SignalNoir.Core.Dto.CaseException;

}
