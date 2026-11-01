Class SignalNoir.Application.Benchmark.QuickValidation Extends %RegisteredObject
{

/// The quick validation (feature 010, FR-033, FR-034, plan D12): three recorded reference cases
/// are run again and each outcome is compared with the recorded reference result. It is a run of
/// its own purpose (quick_validation), never mixed into benchmark or reference results. The three
/// cases are named by the reference result itself (`quickCases`): one control that raises nothing
/// (P9 takes its place if P9 is part of the reference), one P5 or P8b case, and one that ends in a
/// Dossier. The mode is the Agent when a provider is configured, otherwise Replay (deterministic,
/// no key): both compare with the same recorded result.
ClassMethod Plan(record) As SignalNoir.Core.Result
{
	If '$IsObject(record) || (record.%GetTypeOf("quickCases") '= "array") || (record.%GetTypeOf("cases") '= "array") {
		Return ..Refuse("the reference result names no quick validation cases yet")
	}
	Set scenarios = [], control = 0, core = 0, dossier = 0
	For i = 0 : 1 : record.quickCases.%Size() - 1 {
		Set c = ..Find(record, record.quickCases.%Get(i))
		If '$IsObject(c) Return ..Refuse("the reference result has no case " _ record.quickCases.%Get(i))
		Set state = ##class(SignalNoir.Core.Benchmark.QuickCheck).FinalState(c)
		If state = "ReviewRequired" {
			Set dossier = dossier + 1
		} ElseIf (c.family = "P5") || (c.family = "P8") {
			Set core = core + 1
		} ElseIf (state = "NoCase") || (c.family = "P9") {
			Set control = control + 1
		} Else {
			Return ..Refuse("case " _ c.referenceCase _ " is none of: a control, a P5 or P8b case, a Dossier case")
		}
		Do scenarios.%Push({"family": (c.family), "variants": [(c.variant)]})
	}
	If (record.quickCases.%Size() '= 3) || (control '= 1) || (core '= 1) || (dossier '= 1) {
		Return ..Refuse("the quick validation needs exactly one control (or P9), one P5 or P8b case and one Dossier case")
	}
	Set seed = $Select(record.%GetTypeOf("seed") = "number": record.seed, 1: 2026)
	Return ##class(SignalNoir.Core.Result).OkObj({"purpose": "quick_validation", "repetitions": 1, "seed": (seed), "label": "quick validation", "scenarios": (scenarios)})
}

/// agent when a provider is configured, otherwise replay
ClassMethod ModeFor(agentReady As %Boolean) As %String
{
	Return $Select(agentReady: "agent", 1: "replay")
}

/// Creates the quick validation run from the committed reference result
ClassMethod Start(service As SignalNoir.Application.Benchmark.RunService = "", record = "") As SignalNoir.Core.Result
{
	If '$IsObject(service) Set service = ##class(SignalNoir.Application.Benchmark.RunService).%New()
	If '$IsObject(record) Set record = ##class(SignalNoir.Benchmark.Data.ReferenceResult).Load("Record")
	Set plan = ..Plan(record)
	If 'plan.ok Return plan
	Set request = plan.obj
	Set request.mode = ..ModeFor(##class(SignalNoir.Proposers.Factory).Ready("agent"))
	Return service.Create(request)
}

/// The report's quickValidation section: each Case of the run against the reference case of its variant.
/// run: the run record, cases: the report's Case rows, record: the reference result, differs: whether the
/// provider or model differs from the reference's.
ClassMethod Results(cases As %DynamicArray, record, differs As %Boolean) As %DynamicArray
{
	Set out = []
	For i = 0 : 1 : cases.%Size() - 1 {
		Set row = cases.%Get(i)
		Set ref = ..ByVariant(record, row.variant)
		If '$IsObject(ref) {
			Set item = {"referenceCase": (row.variant), "status": "diverged", "reason": "no reference result is recorded for this variant"}
			Do item.%Set("caseId", row.caseId, $Select(row.caseId = "": "null", 1: "string"))
			Do out.%Push(item)
			Continue
		}
		Set verdict = ##class(SignalNoir.Core.Benchmark.QuickCheck).Compare(ref, row, {"providerDiffers": (''differs)})
		Set item = {"referenceCase": (ref.referenceCase), "status": (verdict.status)}
		Do item.%Set("caseId", row.caseId, $Select(row.caseId = "": "null", 1: "string"))
		Do item.%Set("reason", verdict.reason, $Select(verdict.%GetTypeOf("reason") = "null": "null", 1: "string"))
		Do out.%Push(item)
	}
	Return out
}

ClassMethod Find(record, referenceCase As %String) As %DynamicObject [ Private ]
{
	For i = 0 : 1 : record.cases.%Size() - 1 {
		If record.cases.%Get(i).referenceCase = referenceCase Return record.cases.%Get(i)
	}
	Return ""
}

/// The reference case of a variant: the one quickCases names (variant/repetition) when it names one,
/// otherwise the variant's first recording
ClassMethod ByVariant(record, variant As %String) As %DynamicObject [ Private ]
{
	If '$IsObject(record) || (record.%GetTypeOf("cases") '= "array") Return ""
	If record.%GetTypeOf("quickCases") = "array" {
		For i = 0 : 1 : record.quickCases.%Size() - 1 {
			Set name = record.quickCases.%Get(i)
			If $Piece(name, "/", 1, $Length(name, "/") - 1) '= variant Continue
			Set named = ..Find(record, name)
			If $IsObject(named) Return named
		}
	}
	For i = 0 : 1 : record.cases.%Size() - 1 {
		If record.cases.%Get(i).variant = variant Return record.cases.%Get(i)
	}
	Return ""
}

ClassMethod Refuse(message As %String) As SignalNoir.Core.Result [ Private ]
{
	Return ##class(SignalNoir.Core.Result).ErrorWith("VALIDATION_FAILED", message, {"errors": [(message)]})
}

}
