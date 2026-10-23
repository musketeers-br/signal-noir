Class SignalNoir.Core.Dto.Order Extends %RegisteredObject
{

/// Fully populated in this slice (seam contract)
Property orderId As %String(MAXLEN=128);
Property snapshot As %DynamicObject;
Property equivalenceKey As %String(MAXLEN=512);
Property receivedAt As %String(MAXLEN=64);
Property synthetic As %Boolean [ InitialExpression = 1 ];
Property caseId As %String(MAXLEN=64);

}
