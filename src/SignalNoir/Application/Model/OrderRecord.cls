Class SignalNoir.Application.Model.OrderRecord Extends %Persistent
{

/// The synthetic external request: read-only input to the system.
/// The ID is the partner-issued orderId, so the record is addressed directly.

Property orderId As %String(MAXLEN=128) [ Required ];

Index orderIdKey On orderId [ Idkey ];

/// Raw snapshot as received, stored as JSON and never mutated
Property snapshotJson As %String(MAXLEN=4096);

/// Equivalence key, canonized by the Core only
Property equivalenceKey As %String(MAXLEN=512);

/// ISO-8601 UTC timestamp from the Clock port
Property receivedAt As %String(MAXLEN=64);

/// Always true in this slice
Property synthetic As %Boolean [ InitialExpression = 1 ];

/// The Case opened for this Order, if any
Property caseId As %String(MAXLEN=64);

}
