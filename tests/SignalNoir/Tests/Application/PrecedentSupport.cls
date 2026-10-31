Class SignalNoir.Tests.Application.PrecedentSupport Extends %RegisteredObject
{

/// 015 test helpers: Cases of known failure families under a partner of the
/// test's own, and a precedent service over a model of the test's own.
/// Families: tag -> exception kind, http status, exam code
ClassMethod Family(name As %String, ByRef kind, ByRef http, ByRef exam)
{
	Set kind = "timeout", http = "", exam = "HB"
	If name = "mapping" Set kind = "http_error", http = 422, exam = "GLICJ"
	If name = "partnerdown" Set kind = "http_error", http = 503, exam = "TSH"
	If name = "rejected" Set kind = "business_rejection", http = 409, exam = "CREAT"
}

/// A Case of a family for the partner, driven to target ("" = left Open)
ClassMethod FamilyCase(svc As SignalNoir.Application.CaseService, partner As %String, family As %String, target As %String = "Resolved", runId As %String = "") As %String
{
	Set orderId = ##class(SignalNoir.Tests.Support).Uid("prec-" _ family)
	Set order = ##class(SignalNoir.Tests.Support).Order(orderId, , runId)
	Do ..Family(family, .kind, .http, .exam)
	Set order.snapshot.partnerId = partner
	Set order.snapshot.exams = [{"code": (exam)}]
	If 'svc.AcceptOrder(order).ok Return ""
	Set r = svc.RecordException(orderId, ##class(SignalNoir.Tests.Support).Exception(kind, http))
	If 'r.ok Return ""
	If target '= "" {
		Set path = target
		If target = "Failed" Set path = "Executing"
		Set why = ##class(SignalNoir.Tests.Support).DriveTo(svc, r.ref, path)
		If why '= "" Return ""
		If target = "Failed" {
			Set t = svc.Transition(r.ref, svc.GetCase(r.ref).obj.caseVersion, "Failed", "system", ##class(SignalNoir.Tests.Support).Ev("test"))
			If 't.ok Return ""
		}
	}
	Return r.ref
}

ClassMethod Service(svc As SignalNoir.Application.CaseService, model As %String = "") As SignalNoir.Application.PrecedentService
{
	Set p = ##class(SignalNoir.Application.PrecedentService).%New()
	Set p.Service = svc
	Set p.Embedder = ##class(SignalNoir.Tests.Fakes.FakeEmbedder).%New()
	Set p.Embedder.ModelName = $Select(model = "": "test-" _ ##class(SignalNoir.Tests.Support).Uid("m"), 1: model)
	Set p.RecordSeconds = 0
	Return p
}

ClassMethod Cleanup(p As SignalNoir.Application.PrecedentService)
{
	Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM SignalNoir_Application_Model.PrecedentRecord WHERE embeddingModel LIKE 'test-%'")
	Set state = ##class(SignalNoir.Application.Model.PrecedentIndexState).Current()
	Set state.rebuilding = 0
	Do state.%Save()
}

ClassMethod Records(caseId As %String, model As %String) As %Integer
{
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS n FROM SignalNoir_Application_Model.PrecedentRecord WHERE caseId = ? AND embeddingModel = ?", caseId, model)
	Return $Select(rs.%Next(): +rs.%Get("n"), 1: 0)
}

}
