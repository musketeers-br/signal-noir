Class SignalNoir.Core.Dto.Approval Extends %RegisteredObject
{

/// Declared in this slice so the seam does not change shape later
Property approvalId As %String(MAXLEN = 128);

Property proposalId As %String(MAXLEN = 128);

Property decidedBy As %String(MAXLEN = 128);

Property decidedAt As %String(MAXLEN = 64);

Property deadline As %String(MAXLEN = 64);

Property immutableProposalRef As %String(MAXLEN = 256);

}
