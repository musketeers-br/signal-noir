Class SignalNoir.Core.MappingMatch Extends %RegisteredObject
{

/// The approved mappings that could apply to an Order (features 006 and
/// 013): the mapping's source code is one of the Order's exam codes (case
/// insensitive) and its specimen-type condition, when present, matches the
/// Order's specimen. Shared by Rules and Decisions so both see the same
/// candidates; the Validator still checks applicability. Pure.
ClassMethod Candidates(snapshot As %DynamicObject, items As %DynamicArray) As %DynamicArray
{
	Set out = []
	If '$IsObject(snapshot) || '$IsObject(items) Return out
	Set specimenType = $ZConvert($Select($IsObject(snapshot.specimen): snapshot.specimen.type, 1: ""), "U")
	For i = 0 : 1 : items.%Size() - 1 {
		Set m = items.%Get(i)
		If '$IsObject(m) || '..ExamHas(snapshot, m.sourceCode) Continue
		Set want = $Select($IsObject(m.conditions): $ZConvert(m.conditions.specimenType, "U"), 1: "")
		If (want '= "") && (want '= specimenType) Continue
		Do out.%Push(m)
	}
	Return out
}

ClassMethod ExamHas(snapshot As %DynamicObject, code As %String) As %Boolean
{
	If '$IsObject(snapshot.exams) || (code = "") Return 0
	For i = 0 : 1 : snapshot.exams.%Size() - 1 {
		Set exam = snapshot.exams.%Get(i)
		If $IsObject(exam) && ($ZConvert(exam.code, "U") = $ZConvert(code, "U")) Return 1
	}
	Return 0
}

}
