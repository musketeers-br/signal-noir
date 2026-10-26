Class SignalNoir.Core.OrderShape Extends %RegisteredObject
{

/// Structural check of the Origin SyntheticOrder before any delivery attempt
/// (FR-002). Pure: the snapshot is an in-memory value. Returns the ordered
/// reasons; an empty list means the Order is well formed.
/// Reasons: missing:<path>, unreadable:<path>, not_synthetic, malformed (not
/// a JSON object, or an empty one).
ClassMethod Check(snapshot) As %ListOfDataTypes
{
	Set reasons = ##class(%ListOfDataTypes).%New()
	If '$IsObject(snapshot) || 'snapshot.%IsA("%DynamicObject") || (snapshot.%Size() = 0) {
		Do reasons.Insert("malformed")
		Return reasons
	}
	For field = "orderId", "partnerId" {
		If ..Text(snapshot.%Get(field)) = "" Do reasons.Insert("missing:" _ field)
	}
	Set patient = snapshot.%Get("patient")
	If '..IsObj(patient) || (..Text(patient.%Get("patientId")) = "") Do reasons.Insert("missing:patient.patientId")
	Set exams = snapshot.%Get("exams")
	Set examsOk = 0
	If $IsObject(exams) && exams.%IsA("%DynamicArray") && (exams.%Size() > 0) {
		Set examsOk = 1
		For i = 0 : 1 : exams.%Size() - 1 {
			Set exam = exams.%Get(i)
			If '..IsObj(exam) || (..Text(exam.%Get("code")) = "") {
				Set examsOk = 0
				Quit
			}
		}
	}
	If 'examsOk Do reasons.Insert("missing:exams[0].code")
	Set specimen = snapshot.%Get("specimen")
	If '..IsObj(specimen) Set specimen = {}
	If ..Text(specimen.%Get("specimenId")) = "" Do reasons.Insert("missing:specimen.specimenId")
	Set collectedAt = ..Text(specimen.%Get("collectedAt"))
	If collectedAt = "" {
		Do reasons.Insert("missing:specimen.collectedAt")
	} ElseIf ##class(SignalNoir.Core.Canon).NormalizeUtc(collectedAt) = "" {
		Do reasons.Insert("unreadable:specimen.collectedAt")
	}
	If ..Text(snapshot.%Get("requestedAt")) = "" Do reasons.Insert("missing:requestedAt")
	If (snapshot.%GetTypeOf("synthetic") '= "boolean") || (snapshot.%Get("synthetic") '= 1) Do reasons.Insert("not_synthetic")
	Return reasons
}

ClassMethod IsObj(value) As %Boolean [ Private ]
{
	Return ($IsObject(value) && value.%IsA("%DynamicObject"))
}

/// Scalar text of a value; objects and arrays are not text
ClassMethod Text(value) As %String [ Private ]
{
	If $IsObject(value) Return ""
	Return ##class(SignalNoir.Core.Canon).Trim($Get(value))
}

}
