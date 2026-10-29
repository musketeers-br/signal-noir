Class SignalNoir.Application.Model.ReceiptCopyRecord Extends %Persistent
{

/// The Case's auditable copy of the Partner's canonical Receipt (AD-14,
/// contract ReceiptCopy). The Partner's record prevails on divergence.
Property caseId As %String(MAXLEN = 64) [ Required ];

Property receiptId As %String(MAXLEN = 128) [ Required ];

Index receiptKey On (caseId, receiptId) [ IdKey ];

Property executionId As %String(MAXLEN = 64);

Property orderId As %String(MAXLEN = 128);

Property idempotencyKey As %String(MAXLEN = 128);

Property receivedAt As %String(MAXLEN = 64);

Property partnerId As %String(MAXLEN = 128);

/// delivery or reconciliation (prior_receipt is 011's)
Property source As %String(MAXLEN = 32);

Property externalRef As %String(MAXLEN = 512);

Property orderSnapshotMinimalJson As %String(MAXLEN = 4096);

Property recordedAt As %String(MAXLEN = 64);

}
