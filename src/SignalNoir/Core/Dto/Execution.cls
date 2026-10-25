Class SignalNoir.Core.Dto.Execution Extends %RegisteredObject
{

/// Declared in this slice so the seam does not change shape later
Property executionId As %String(MAXLEN = 128);

Property caseId As %String(MAXLEN = 64);

Property proposalId As %String(MAXLEN = 128);

Property idempotencyKey As %String(MAXLEN = 128);

Property leaseOwner As %String(MAXLEN = 128);

Property leaseGeneration As %Integer;

Property state As %String(MAXLEN = 32);

}
