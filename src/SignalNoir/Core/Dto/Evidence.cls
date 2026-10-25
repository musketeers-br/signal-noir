Class SignalNoir.Core.Dto.Evidence Extends %RegisteredObject
{

/// Declared in this slice so the seam does not change shape later
Property evidenceId As %String(MAXLEN = 128);

Property caseId As %String(MAXLEN = 64);

Property kind As %String(MAXLEN = 64);

Property source As %String(MAXLEN = 256);

Property observedAt As %String(MAXLEN = 64);

Property payload As %DynamicObject;

}
