Class SignalNoir.Interop.Service.OrderIn Extends %RegisteredObject
{

/// The Business Service entry for synthetic Orders (AD-6, AD-25).
/// It owns no state and no rule: the shape check and the equivalence key are
/// the core's, the writes are CaseService's. The class stays portable: it
/// never references Ensemble classes.
/// Accepts one raw Origin Order (JSON) with the feed envelope's transaction
/// id, run id and scenario instance id. A malformed payload is refused with VALIDATION_FAILED and
/// recorded. Result.ref is the orderId.
ClassMethod Accept(json As %String, transactionId As %String = "", runId As %String = "", scenarioInstanceId As %String = "") As SignalNoir.Core.Result
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set order = ##class(SignalNoir.Core.Dto.Order).%New()
	Set order.transactionId = transactionId
	Set order.runId = runId
	Set order.scenarioInstanceId = scenarioInstanceId
	Set order.synthetic = 1
	Set snapshot = ""
	Try {
		Set snapshot = ##class(%DynamicAbstractObject).%FromJSON(json)
	}
	Catch {
		Set snapshot = ""
	}
	Set order.snapshot = snapshot
	Return svc.AcceptOrder(order)
}

/// Reports a delivery attempt that did not end with a valid Receipt
/// (FR-009). body may be JSON text or plain text. Result.ref is the caseId.
ClassMethod ReportException(orderId As %String, kind As %String, httpStatus As %String = "", body As %String = "", observedAt As %String = "", attemptId As %String = "") As SignalNoir.Core.Result
{
	Set exception = ##class(SignalNoir.Core.Dto.CaseException).%New()
	Set exception.kind = kind
	Set exception.httpStatus = httpStatus
	Set exception.observedAt = observedAt
	Set exception.attemptId = attemptId
	If body '= "" {
		Set parsed = ""
		Try {
			Set parsed = ##class(%DynamicAbstractObject).%FromJSON(body)
		}
		Catch {
			Set parsed = ""
		}
		If $IsObject(parsed) {
			Set exception.body = parsed
		} Else {
			Set exception.bodyText = body
		}
	}
	Return ##class(SignalNoir.Application.CaseService).Default().ProcessException(orderId, exception)
}

}
