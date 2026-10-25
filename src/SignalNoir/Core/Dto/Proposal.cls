Class SignalNoir.Core.Dto.Proposal Extends %RegisteredObject
{

/// Declared in this slice so the seam does not change shape later
Property proposalId As %String(MAXLEN = 128);

Property caseId As %String(MAXLEN = 64);

Property action As %String(MAXLEN = 64);

Property params As %DynamicObject;

Property basedOnVersions As %DynamicObject;

Property origin As %String(MAXLEN = 64);

}
