Class SignalNoir.Sim.Model.Delivery Extends %Persistent
{

/// One Partner log entry (data-model Delivery / PartnerLogEntry): an
/// Attempt that passed request validation, or third-party traffic written by
/// an event (no order fields)
Property scenarioInstanceId As %String(MAXLEN = 80);

Index instanceIdx On (scenarioInstanceId, loggedAt);

Property partnerId As %String(MAXLEN = 64);

Property orderId As %String(MAXLEN = 128);

Property transactionId As %String(MAXLEN = 128);

Property idempotencyKey As %String(MAXLEN = 128);

Property attempt As %Integer;

/// "" on a timeout
Property httpStatus As %String(MAXLEN = 8);

/// delivered, duplicate, rejected, error, timeout, unavailable
Property outcome As %String(MAXLEN = 16);

Property latencyMs As %Integer;

Property message As %String(MAXLEN = 4000);

Property loggedAt As %String(MAXLEN = 40);

}
