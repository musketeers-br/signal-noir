Class SignalNoir.Core.Dto.Receipt Extends %RegisteredObject
{

/// Declared in this slice so the seam does not change shape later
Property receiptId As %String(MAXLEN=128);
Property orderId As %String(MAXLEN=128);
Property outcome As %String(MAXLEN=64);
Property receivedAt As %String(MAXLEN=64);
Property raw As %DynamicObject;

}
