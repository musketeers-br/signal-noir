Class SignalNoir.Application.Model.OrderRecord Extends %Persistent
{

/// The synthetic external request: read-only input to the system.
/// The ID is the partner-issued orderId, so the record is addressed directly.
/// The snapshot is written once and never changed; a repeated arrival only
/// adds its transaction id.
Property orderId As %String(MAXLEN = 128) [ Required ];

Index orderIdKey On orderId [ IdKey ];

Property partnerId As %String(MAXLEN = 128);

/// corr_ id assigned on the first acceptance
Property correlationId As %String(MAXLEN = 64);

/// Every Origin transaction id seen for this orderId, in arrival order
Property transactionIds As list Of %String(MAXLEN = 128);

/// BenchmarkRun id from the feed envelope; empty outside the Benchmark
Property runId As %String(MAXLEN = 64);

/// Raw snapshot as received, stored as JSON and never mutated
Property snapshotJson As %String(MAXLEN = 32000);

/// Equivalence key, canonized by the Core only
Property equivalenceKey As %String(MAXLEN = 512);

Index equivKeyIdx On equivalenceKey;

/// ISO-8601 UTC timestamp from the Clock port
Property receivedAt As %String(MAXLEN = 64);

Property synthetic As %Boolean [ InitialExpression = 1 ];

/// The latest Case opened for this Order, if any
Property caseId As %String(MAXLEN = 64);

}
