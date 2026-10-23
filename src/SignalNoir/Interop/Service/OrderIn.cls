Class SignalNoir.Interop.Service.OrderIn Extends %RegisteredObject
{

/// The Business Service that receives one synthetic Order (AD-6, D6).
/// It owns no state: it validates nothing of its own and calls the single
/// command path (CaseService), which persists the Order and opens the Case.
/// The class stays portable: it never references Ensemble classes.

ClassMethod ProcessOrder(order As SignalNoir.Core.Dto.Order) As SignalNoir.Core.Result
{
	If '$IsObject(order) Return ##class(SignalNoir.Core.Result).Error("VALIDATION_FAILED", "order is required")
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Return svc.ProcessOrder(order)
}

ClassMethod ProcessOrderJson(json As %String) As SignalNoir.Core.Result
{
	If json = "" Return ##class(SignalNoir.Core.Result).Error("VALIDATION_FAILED", "empty order payload")
	Set snapshot = ""
	Try {
		Set snapshot = ##class(%DynamicObject).%FromJSON(json)
	}
	Catch ex {
		Return ##class(SignalNoir.Core.Result).Error("VALIDATION_FAILED", "malformed order payload")
	}
	If '$IsObject(snapshot) Return ##class(SignalNoir.Core.Result).Error("VALIDATION_FAILED", "malformed order payload")
	Set order = ##class(SignalNoir.Core.Dto.Order).%New()
	Set order.orderId = snapshot.orderId
	Set order.equivalenceKey = snapshot.equivalenceKey
	Set order.receivedAt = snapshot.receivedAt
	Set order.snapshot = snapshot
	Set order.synthetic = 1
	Return ##class(SignalNoir.Interop.Service.OrderIn).ProcessOrder(order)
}

/// The intake entry point used by the production consumer and by the tests:
/// accepts the Order and returns the caseId.
ClassMethod Accept(json As %String) As SignalNoir.Core.Result
{
	Return ##class(SignalNoir.Interop.Service.OrderIn).ProcessOrderJson(json)
}

}
