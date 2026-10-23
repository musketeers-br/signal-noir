Class SignalNoir.Core.Dto.Case Extends %RegisteredObject
{

/// Fully populated in this slice (seam contract)
Property caseId As %String(MAXLEN=64);
Property orderId As %String(MAXLEN=128);
Property state As %String(MAXLEN=32);
Property caseVersion As %Integer;
Property lastEventSeq As %Integer;
Property lastEventAt As %String(MAXLEN=64);
Property synthetic As %Boolean;
Property replay As %Boolean;
Property reviewReason As %String(MAXLEN=256);

/// Optional fields the product HTTP contract asks for; the seam only
/// requires the fields above, so these stay additive.
Property createdAt As %String(MAXLEN=64);
Property partnerId As %String(MAXLEN=128);

}
