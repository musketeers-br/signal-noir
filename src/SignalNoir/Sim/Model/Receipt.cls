Class SignalNoir.Sim.Model.Receipt Extends %Persistent
{

/// The Partner's canonical receipt (data-model Receipt). The unique index on
/// the idempotency key is the second guard of the deduplication (D5, V3).
Property receiptId As %String(MAXLEN = 128) [ Required ];

Index idKey On receiptId [ IdKey ];

Property idempotencyKey As %String(MAXLEN = 128) [ Required ];

Index keyIdx On idempotencyKey [ Unique ];

Property orderId As %String(MAXLEN = 128);

Index orderIdx On orderId;

Property scenarioInstanceId As %String(MAXLEN = 80);

Property patientId As %String(MAXLEN = 128);

Index patientIdx On (scenarioInstanceId, patientId);

Property partnerId As %String(MAXLEN = 64);

Property transactionId As %String(MAXLEN = 128);

Property receivedAt As %String(MAXLEN = 40);

/// The delivered Order, raw
Property orderSnapshotJson As %String(MAXLEN = 32000);

/// Canonical payload for the duplicate comparison; never served
Property payloadCanon As %String(MAXLEN = 32000);

ClassMethod CountByKey(key As %String) As %Integer
{
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM SignalNoir_Sim_Model.Receipt WHERE idempotencyKey = ?", key)
	Return $Select(rs.%Next(): +rs.%GetData(1), 1: -1)
}

}
