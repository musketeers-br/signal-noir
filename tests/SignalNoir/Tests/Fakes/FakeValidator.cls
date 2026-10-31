Class SignalNoir.Tests.Fakes.FakeValidator Extends SignalNoir.Core.Port.Validator
{

/// Configurable verdict (seam v2). Usable with no live provider.
/// Defaults per docs/seams.md: accepted, requiresApproval = true, reasons [ACTION_IN_CATALOG].
Property Verdict As %String;

/// $List of reason codes
Property Reasons As %List;

Property RequiresApproval As %Boolean;

/// PreconditionResult DTOs returned by Revalidate
Property Results As list Of SignalNoir.Core.Dto.PreconditionResult;

Property Admission As SignalNoir.Core.Dto.Admission;

Method %OnNew() As %Status
{
	Set ..Verdict = "accepted"
	Set ..Reasons = $ListBuild("ACTION_IN_CATALOG")
	Set ..RequiresApproval = 1
	Set ..Admission = ##class(SignalNoir.Core.Dto.Admission).%New()
	Set ..Admission.admissible = 1
	Set ..Admission.label = "human"
	Return $$$OK
}

Method Validate(input As SignalNoir.Core.Dto.ValidationInput) As SignalNoir.Core.Dto.ValidatorVerdict
{
	Set v = ##class(SignalNoir.Core.Dto.ValidatorVerdict).%New()
	Set v.verdict = ..Verdict
	Set codes = ..Reasons, ptr = 0
	While $ListNext(codes, ptr, code) {
		Do v.reasons.Insert(code)
	}
	Set v.requiresApproval = ..RequiresApproval
	If $IsObject(input) {
		Set v.at = input.now
		If $IsObject(input.reference) Set v.versions = {"policy": (input.reference.policyVersion), "mapping": (input.reference.mappingVersion)}
	}
	Return v
}

Method Revalidate(input As SignalNoir.Core.Dto.ValidationInput, Output results As %ListOfObjects) As SignalNoir.Core.Dto.ValidatorVerdict
{
	Set results = ##class(%ListOfObjects).%New()
	For i = 1 : 1 : ..Results.Count() Do results.Insert(..Results.GetAt(i))
	Return ..Validate(input)
}

Method Admit(actor As %String, run As %DynamicObject) As SignalNoir.Core.Dto.Admission
{
	Return ..Admission
}

}
