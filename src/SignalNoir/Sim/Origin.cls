Class SignalNoir.Sim.Origin Extends %RegisteredObject
{

/// The simulated Origin: feed, Order status and Orders by patient (US1, US4)
/// GET /origin/feed: items after afterSeq, ordered by feedSeq (FR-012)
ClassMethod Feed(afterSeq As %Integer, limit As %Integer) As SignalNoir.Sim.Result
{
	Set items = [], last = afterSeq
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP " _ (+limit) _ " feedSeq FROM SignalNoir_Sim_Model.FeedItem WHERE feedSeq > ? ORDER BY feedSeq", afterSeq)
	While rs.%Next() {
		Set item = ##class(SignalNoir.Sim.Model.FeedItem).%OpenId(rs.%Get("feedSeq"))
		Do items.%Push(..Envelope(item))
		Set last = item.feedSeq
	}
	Return ##class(SignalNoir.Sim.Result).Ok({"items": (items), "lastSeq": (+last), "serverTime": (##class(SignalNoir.Sim.Clock).NowUtc())})
}

/// GET /origin/orders/{orderId}: OriginOrderStatus or 404 (FR-013). The read
/// counts for the instance's triggers (research D12).
ClassMethod Status(orderId As %String) As SignalNoir.Sim.Result
{
	If (orderId = "") || '##class(SignalNoir.Sim.Model.OriginOrder).%ExistsId(orderId) Return ##class(SignalNoir.Sim.Result).Error("NOT_FOUND", "order not found at the origin: " _ orderId)
	Set row = ##class(SignalNoir.Sim.Model.OriginOrder).%OpenId(orderId)
	Do ##class(SignalNoir.Sim.Scenarios).Touch(row.scenarioInstanceId, "read:originStatus")
	Do row.%Reload()
	Set out = {"orderId": (row.orderId), "scenarioInstanceId": (row.scenarioInstanceId), "transactionId": (row.transactionId), "status": (row.status)}
	Set out.statusChangedAt = $Select(row.statusChangedAt '= "": row.statusChangedAt, 1: row.emittedAt)
	If row.reason '= "" Set out.reason = row.reason
	Return ##class(SignalNoir.Sim.Result).Ok(out)
}

/// GET /origin/orders?patientId&scenarioInstanceId: raw snapshots, newest first (FR-014)
ClassMethod ByPatient(sci As %String, patientId As %String, emittedAfter As %String, limit As %Integer) As SignalNoir.Sim.Result
{
	Set items = []
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP " _ (+limit) _ " orderId FROM SignalNoir_Sim_Model.OriginOrder WHERE scenarioInstanceId = ? AND patientId = ? ORDER BY emittedAt DESC, orderId DESC", sci, $ZStrip(patientId, "<>W"))
	While rs.%Next() {
		Set row = ##class(SignalNoir.Sim.Model.OriginOrder).%OpenId(rs.%Get("orderId"))
		If (emittedAfter '= "") && (##class(SignalNoir.Sim.Clock).Seconds(row.emittedAt) <= ##class(SignalNoir.Sim.Clock).Seconds(emittedAfter)) Continue
		Do items.%Push({"orderId": (row.orderId), "transactionId": (row.transactionId), "status": (row.status), "emittedAt": (row.emittedAt), "order": ({}.%FromJSON(row.orderJson))})
	}
	Return ##class(SignalNoir.Sim.Result).Ok({"items": (items), "serverTime": (##class(SignalNoir.Sim.Clock).NowUtc())})
}

/// The contract's OrderEnvelope for a feed item
ClassMethod Envelope(item As SignalNoir.Sim.Model.FeedItem) As %DynamicObject
{
	Set env = {"feedSeq": (+item.feedSeq), "scenarioInstanceId": (item.scenarioInstanceId)}
	Do env.%Set("runId", item.runId, $Select(item.runId = "": "null", 1: "string"))
	Do env.%Set("repetition", item.repetition, "number")
	Set env.transactionId = item.transactionId, env.emittedAt = item.emittedAt, env.order = {}.%FromJSON(item.orderJson)
	Return env
}

}
