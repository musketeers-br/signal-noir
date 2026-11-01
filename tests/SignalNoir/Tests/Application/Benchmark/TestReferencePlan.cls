Class SignalNoir.Tests.Application.Benchmark.TestReferencePlan Extends %UnitTest.TestCase
{

/// 010 T057 - the reference run (FR-030): five test variants in each of P5 and P8b, three
/// repetitions (thirty Agent investigations), plus the clean controls and the Dossier case, with a
/// provider and model fixed. Built from the request committed in docs/benchmark, over a catalog that
/// holds the reserved variants the freeze will bring.
Method OnBeforeOneTest(testname As %String) As %Status
{
	Do ##class(SignalNoir.Application.Model.BenchmarkItemRecord).%KillExtent()
	Do ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%KillExtent()
	Return $$$OK
}

ClassMethod Catalog() As %DynamicArray
{
	Set cat = []
	For i = 1 : 1 : 5 {
		Do cat.%Push({"family": "P5", "subtype": "P5", "variant": ("P5-test-0" _ i), "set": "test"})
		Do cat.%Push({"family": "P8", "subtype": "P8b", "variant": ("P8b-test-0" _ i), "set": "test"})
	}
	Do cat.%Push({"family": "clean", "subtype": "clean.success", "variant": "clean-success-test-01", "set": "test"})
	Do cat.%Push({"family": "clean", "subtype": "clean.partner_unavailable", "variant": "clean-unavailable-test-01", "set": "test"})
	Do cat.%Push({"family": "clean", "subtype": "clean.ambiguous_identity", "variant": "clean-ambiguous-identity-test-01", "set": "test"})
	Do cat.%Push({"family": "P5", "subtype": "P5", "variant": "P5-tune-01", "set": "tuning"})
	Return cat
}

ClassMethod Request() As %DynamicObject
{
	Set stream = ##class(%Stream.FileCharacter).%New()
	$$$ThrowOnError(stream.LinkToFile(##class(SignalNoir.Tests.Core.Validator.Repo).Path("docs/benchmark/reference-request.json")))
	Return ##class(%DynamicAbstractObject).%FromJSON(stream.Read(stream.Size))
}

ClassMethod Service() As SignalNoir.Application.Benchmark.RunService
{
	Set svc = ##class(SignalNoir.Application.Benchmark.RunService).%New()
	Set svc.AutoStart = 0
	Set svc.Catalog = ..Catalog()
	Return svc
}

ClassMethod Count(runId As %String, family As %String) As %Integer
{
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS n FROM SignalNoir_Application_Model.BenchmarkItemRecord WHERE runId = ? AND family = ?", runId, family)
	Do rs.%Next()
	Return rs.%Get("n")
}

Method TestTheCommittedRequestPlansThirtyInvestigationsAndTheControls()
{
	Set request = ..Request()
	Do $$$AssertEquals(request.purpose, "reference", "a reference run")
	Do $$$AssertEquals(request.repetitions, 3, "k = 3")
	Do $$$AssertTrue((request.provider '= "") && (request.model '= ""), "a provider and a model are fixed")
	; planning does not need a provider: the same request is created in rules mode here
	Set request.mode = "rules"
	Set r = ..Service().Create(request)
	Do $$$AssertTrue(r.ok, "created: " _ r.message)
	Quit:'r.ok
	Set runId = r.obj.runId
	Do $$$AssertEquals(..Count(runId, "P5") + ..Count(runId, "P8"), 30, "5 variants x 2 families x 3 repetitions = 30 investigations")
	Do $$$AssertEquals(..Count(runId, "P5"), 15, "15 of P5")
	Do $$$AssertEquals(..Count(runId, "P8"), 15, "15 of P8b")
	Do $$$AssertEquals(..Count(runId, "clean"), 9, "the clean controls and the Dossier case: 3 variants x 3 repetitions")
	Do $$$AssertEquals(r.obj.progress.casesPlanned, 39, "39 items in all")
}

Method TestOnlyTestVariantsAreInIt()
{
	Set request = ..Request()
	Set request.mode = "rules"
	Set r = ..Service().Create(request)
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT variant FROM SignalNoir_Application_Model.BenchmarkItemRecord WHERE runId = ?", r.obj.runId)
	Set n = 0, tuning = 0
	While rs.%Next() {
		Set n = n + 1
		If rs.%Get("variant") [ "-tune-" Set tuning = tuning + 1
	}
	Do $$$AssertTrue(n > 0, "items exist")
	Do $$$AssertEquals(tuning, 0, "no tuning variant")
}

Method TestAVariantCountsOnceInTheDenominators()
{
	Set request = ..Request()
	Set request.mode = "rules"
	Set r = ..Service().Create(request)
	Set rec = ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%OpenId(r.obj.runId)
	Set rec.status = "completed"
	$$$ThrowOnError(rec.%Save())
	Set report = ##class(SignalNoir.Application.Benchmark.ReportBuilder).Report(r.obj.runId).obj
	For i = 0 : 1 : report.agentDecision.%Size() - 1 {
		Set row = report.agentDecision.%Get(i)
		If row.family = "P5" {
			Do $$$AssertEquals(row.variantCount, 5, "P5: five variants")
			Do $$$AssertEquals(row.repetitionsCovered, 3, "three repetitions")
			Do $$$AssertEquals(row.denominator.withNotDecided.max, 5, "the denominator of a repetition is the variants, not 15")
		}
	}
}

Method TestAnAgentReferenceNeedsAProviderAndAModel()
{
	Set request = ..Request()
	Do request.%Remove("model")
	Set r = ..Service().Create(request)
	Do $$$AssertNotTrue(r.ok, "refused without a model")
	Do $$$AssertEquals(r.code, "VALIDATION_FAILED", "400")
}

}
