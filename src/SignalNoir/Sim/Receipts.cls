Class SignalNoir.Sim.Receipts Extends %RegisteredObject
{

/// Receipt search and read (US3, FR-022..024). Items carry the raw Order
/// snapshot and never an equivalence key.
ClassMethod Search(key As %String, orderId As %String, patientId As %String, sci As %String, receivedAfter As %String, limit As %Integer) As SignalNoir.Sim.Result
{
	If (key = "") && (orderId = "") && (patientId = "") Return ##class(SignalNoir.Sim.Result).Error("INVALID_REQUEST", "give at least one of idempotencyKey, orderId or patientId")
	If (patientId '= "") && (sci = "") Return ##class(SignalNoir.Sim.Result).Error("INVALID_REQUEST", "a search by patientId needs scenarioInstanceId")
	Set where = "1 = 1", n = 0
	If key '= "" Set where = where _ " AND idempotencyKey = ?", n = n + 1, args(n) = key
	If orderId '= "" Set where = where _ " AND orderId = ?", n = n + 1, args(n) = orderId
	If patientId '= "" Set where = where _ " AND patientId = ?", n = n + 1, args(n) = $ZStrip(patientId, "<>W")
	If sci '= "" Set where = where _ " AND scenarioInstanceId = ?", n = n + 1, args(n) = sci
	Set args = n
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT receiptId FROM SignalNoir_Sim_Model.Receipt WHERE " _ where _ " ORDER BY receivedAt DESC, receiptId DESC", args...)
	Set items = []
	While rs.%Next() && (items.%Size() < limit) {
		Set r = ##class(SignalNoir.Sim.Model.Receipt).%OpenId(rs.%Get("receiptId"))
		If (receivedAfter '= "") && (##class(SignalNoir.Sim.Clock).Seconds(r.receivedAt) <= ##class(SignalNoir.Sim.Clock).Seconds(receivedAfter)) Continue
		Do items.%Push(..Json(r, 1))
	}
	Return ##class(SignalNoir.Sim.Result).Ok({"items": (items), "serverTime": (##class(SignalNoir.Sim.Clock).NowUtc())})
}

ClassMethod Get(receiptId As %String) As SignalNoir.Sim.Result
{
	If (receiptId = "") || '##class(SignalNoir.Sim.Model.Receipt).%ExistsId(receiptId) Return ##class(SignalNoir.Sim.Result).Error("NOT_FOUND", "receipt not found: " _ receiptId)
	Return ##class(SignalNoir.Sim.Result).Ok(..Json(##class(SignalNoir.Sim.Model.Receipt).%OpenId(receiptId), 1))
}

/// Receipt (full = 0) or ReceiptRecord (full = 1)
ClassMethod Json(r As SignalNoir.Sim.Model.Receipt, full As %Boolean) As %DynamicObject
{
	Set out = {"receiptId": (r.receiptId), "orderId": (r.orderId), "idempotencyKey": (r.idempotencyKey), "receivedAt": (r.receivedAt), "partnerId": (r.partnerId)}
	If full {
		Set out.scenarioInstanceId = r.scenarioInstanceId, out.transactionId = r.transactionId
		Set out.orderSnapshot = {}.%FromJSON(r.orderSnapshotJson)
		Set out.externalRef = "/sim/api/v1/receipts/" _ r.receiptId
	}
	Return out
}

}
