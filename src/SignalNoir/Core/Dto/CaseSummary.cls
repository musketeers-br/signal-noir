Class SignalNoir.Core.Dto.CaseSummary Extends %RegisteredObject
{

/// Fully populated in this slice (seam contract)
Property caseId As %String(MAXLEN=64);
Property state As %String(MAXLEN=32);
Property caseVersion As %Integer;
Property lastEventAt As %String(MAXLEN=64);
Property synthetic As %Boolean;

}
