Class SignalNoir.Application.Benchmark.FreezeDraft Extends %RegisteredObject
{

/// The inputs half of the freeze record (feature 010, T056, plan D8), computed the way a reference
/// run computes them (`Inputs.Current` over the Simulator's catalog and the pinned reference data),
/// so the record cannot disagree with what `FreezeCheck` will compare. The files half (git blob
/// ids) is added by scripts/benchmark/freeze_record.py, which writes the record into Freeze.cls.
/// Refuses while the reserved set is not ready: no test variant, a test variant without an answer
/// key, or a placeholder (`-test-00`) still in the catalog. `service` (its catalog) and `keys` (the
/// reserved answer keys) are injectable for tests.
ClassMethod Inputs(model As %String, service As SignalNoir.Application.Benchmark.RunService = "", keys As %DynamicArray = "") As SignalNoir.Core.Result
{
	If model = "" Return ##class(SignalNoir.Core.Result).Error("", "the model of the reference run is needed (it is a frozen input)")
	If '$IsObject(service) Set service = ##class(SignalNoir.Application.Benchmark.RunService).%New()
	Set catalog = service.LoadCatalog()
	If 'catalog.ok Return catalog
	If '$IsObject(keys) Set keys = ##class(SignalNoir.Benchmark.Data.Base).Read("SignalNoir.Benchmark.Data.AnswerKeyTest", "Keys")
	Set problems = [], reserved = 0
	For i = 0 : 1 : catalog.obj.%Size() - 1 {
		Set v = catalog.obj.%Get(i)
		If v.set '= "test" Continue
		Set reserved = reserved + 1
		If v.variant [ "-test-00" Do problems.%Push(v.variant _ " is a placeholder") Continue
		If '..Keyed(keys, v.variant) Do problems.%Push(v.variant _ " has no answer key in AnswerKeyTest")
	}
	If 'reserved Do problems.%Push("the catalog has no test variant")
	If problems.%Size() Return ##class(SignalNoir.Core.Result).Error("", "the reserved set is not ready: " _ ..Join(problems))
	Set snapshot = ##class(SignalNoir.Application.Reference.Store).For({"inRun": true, "policyVersion": "", "mappingVersion": ""})
	If 'snapshot.ok Return ##class(SignalNoir.Core.Result).Error("", snapshot.message)
	Return ##class(SignalNoir.Core.Result).OkObj(##class(SignalNoir.Application.Benchmark.Inputs).Current(model, snapshot.obj.policyVersion, snapshot.obj.mappingVersion, catalog.obj))
}

/// Writes the inputs as one line of JSON, or the refusal, for the freeze script to read:
/// Do ##class(SignalNoir.Application.Benchmark.FreezeDraft).Print("gpt-4o-mini")
ClassMethod Print(model As %String)
{
	Set r = ..Inputs(model)
	If 'r.ok Write "FREEZE-REFUSED ", r.message, ! Quit
	Write "FREEZE-INPUTS ", r.obj.%ToJSON(), !
}

ClassMethod Keyed(keys, variant As %String) As %Boolean [ Private ]
{
	If '$IsObject(keys) Return 0
	For i = 0 : 1 : keys.%Size() - 1 {
		If keys.%Get(i).variant = variant Return 1
	}
	Return 0
}

ClassMethod Join(list As %DynamicArray) As %String [ Private ]
{
	Set out = ""
	For i = 0 : 1 : list.%Size() - 1 Set out = out _ $Select(i: "; ", 1: "") _ list.%Get(i)
	Return out
}

}
