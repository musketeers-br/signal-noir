Class SignalNoir.Core.Dto.Order Extends %RegisteredObject
{

/// Fully populated in this slice (seam contract)
Property orderId As %String(MAXLEN = 128);

Property snapshot As %DynamicObject;

Property equivalenceKey As %String(MAXLEN = 512);

Property receivedAt As %String(MAXLEN = 64);

Property synthetic As %Boolean [ InitialExpression = 1 ];

Property caseId As %String(MAXLEN = 64);

/// Contract change 003: correlation and provenance
Property correlationId As %String(MAXLEN = 64);

/// Origin transaction id of this arrival (input)
Property transactionId As %String(MAXLEN = 128);

/// Every Origin transaction id seen for this orderId (output)
Property transactionIds As list Of %String(MAXLEN = 128);

Property partnerId As %String(MAXLEN = 128);

/// BenchmarkRun id from the feed envelope; empty outside the Benchmark
Property runId As %String(MAXLEN = 64);

}
