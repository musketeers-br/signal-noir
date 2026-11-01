Class SignalNoir.Core.Benchmark.FreezeCheck Extends %RegisteredObject
{

/// Whether a run may be published as the reference result (feature 010, FR-026 to FR-029,
/// plan D8). Pure: the freeze record, the inputs as they are now, the recorded roles and
/// reviews, the declarations of used sets and the run's selection in; whether the run is
/// development data, and every reason why, out. A development run still runs and still
/// reports; its report says why it cannot be the reference.
Parameter FIELDS = "promptVersion,model,baselineVersion,policyVersion,mappingVersion,policyDigest,mappingDigest,evaluatorVersion,reservedCatalogDigest,answerKeyDigest";

/// The families whose answer key, baseline and review must be held by different people
Parameter CORE = "P5,P8,P9";

/// freeze: the committed freeze record ({freezeId, ...} or "" or {freezeId: ""} for none).
/// current: the same fields as the inputs are now. roles: {families: {P5: {answerKeyBy, baselineBy}}}.
/// reviews: [{kind, family, author, reviewer, commit, date}]. usage: [{set: "P5/test", by, at, why}].
/// selection: {purpose, variants: [{family, set, variant}]}.
/// Returns {development, reasons[]}. A set declared used marks every run over it; the freeze,
/// the roles and the reviews are required of a run for the reference purpose only.
ClassMethod Evaluate(freeze, current, roles, reviews, usage, selection As %DynamicObject) As %DynamicObject
{
	Set reasons = []
	Do ..Families(selection, .families)
	; a test set whose results were used to adjust the solution is development data (any purpose)
	Set f = ""
	For {
		Set f = $Order(families(f))
		Quit:f=""
		If ..Used(usage, f) '= "" Do reasons.%Push("the test set of " _ f _ " was declared used (" _ ..Used(usage, f) _ "): a new reserved test is required")
	}
	If selection.%Get("purpose") = "reference" {
		Do ..CheckFreeze(freeze, current, reasons)
		Set f = ""
		For {
			Set f = $Order(families(f))
			Quit:f=""
			If (","_..#CORE_",") [ ("," _ f _ ",") Do ..CheckIndependence(f, roles, reviews, reasons)
		}
		Do ..CheckEvaluatorReview(roles, reviews, reasons)
	}
	Set out = {"reasons": (reasons)}
	Do out.%Set("development", ''reasons.%Size(), "boolean")
	Return out
}

/// The families of the selection that hold a test variant, as families(name)
ClassMethod Families(selection As %DynamicObject, ByRef families) [ Private ]
{
	Kill families
	If selection.%GetTypeOf("variants") '= "array" Quit
	For i = 0 : 1 : selection.variants.%Size() - 1 {
		Set v = selection.variants.%Get(i)
		If v.set = "test" Set families(v.family) = ""
	}
}

ClassMethod Used(usage, family As %String) As %String [ Private ]
{
	If '$IsObject(usage) Return ""
	For i = 0 : 1 : usage.%Size() - 1 {
		Set u = usage.%Get(i)
		If u.set = (family _ "/test") Return u.by _ ", " _ u.at
	}
	Return ""
}

ClassMethod CheckFreeze(freeze, current, reasons As %DynamicArray) [ Private ]
{
	If '$IsObject(freeze) || (freeze.%Get("freezeId") = "") {
		Do reasons.%Push("no freeze record: the prompt, model, baseline, policies, fixtures and evaluator were not frozen")
		Quit
	}
	For i = 1 : 1 : $Length(..#FIELDS, ",") {
		Set field = $Piece(..#FIELDS, ",", i)
		If '$IsObject(current) || (freeze.%Get(field) '= current.%Get(field)) Do reasons.%Push("a frozen input differs from the freeze record: " _ field)
	}
}

ClassMethod CheckIndependence(family As %String, roles, reviews, reasons As %DynamicArray) [ Private ]
{
	Set r = $Select($IsObject(roles) && (roles.%GetTypeOf("families") = "object") && (roles.families.%GetTypeOf(family) = "object"): roles.families.%Get(family), 1: "")
	If '$IsObject(r) {
		Do reasons.%Push("no roles recorded for family " _ family)
		Quit
	}
	Set key = r.answerKeyBy, base = r.baselineBy
	If (key = "") || (base = "") || (key = base) Do reasons.%Push("family " _ family _ ": the answer key and the baseline are not held by two different people")
	Set review = ..FindReview(reviews, "baseline", family)
	If '$IsObject(review) {
		Do reasons.%Push("no baseline review for family " _ family)
		Quit
	}
	If '..Complete(review) {
		Do reasons.%Push("the baseline review of family " _ family _ " is incomplete: it needs author, reviewer, commit and date")
		Quit
	}
	If (review.reviewer = key) || (review.reviewer = base) Do reasons.%Push("family " _ family _ ": the reviewer of the baseline also held another role (" _ review.reviewer _ ")")
}

ClassMethod CheckEvaluatorReview(roles, reviews, reasons As %DynamicArray) [ Private ]
{
	Set review = ..FindReview(reviews, "evaluator", "*")
	If '$IsObject(review) {
		Do reasons.%Push("no evaluator review")
		Quit
	}
	If '..Complete(review) {
		Do reasons.%Push("the evaluator review is incomplete: it needs author, reviewer, commit and date")
		Quit
	}
	If '$IsObject(roles) || (roles.%GetTypeOf("families") '= "object") Quit
	Set it = roles.families.%GetIterator()
	While it.%GetNext(.family, .r) {
		If $IsObject(r) && ((r.answerKeyBy = review.reviewer) || (r.baselineBy = review.reviewer)) Do reasons.%Push("the reviewer of the evaluator also held another role in family " _ family _ " (" _ review.reviewer _ ")")
	}
}

/// The review of a kind for a family; an evaluator review may be recorded for "*" or for any family
ClassMethod FindReview(reviews, kind As %String, family As %String) As %DynamicObject [ Private ]
{
	If '$IsObject(reviews) Return ""
	For i = 0 : 1 : reviews.%Size() - 1 {
		Set r = reviews.%Get(i)
		If r.kind '= kind Continue
		If (kind = "evaluator") || (r.family = family) Return r
	}
	Return ""
}

ClassMethod Complete(review As %DynamicObject) As %Boolean [ Private ]
{
	Return ((review.%Get("author") '= "") && (review.%Get("reviewer") '= "") && (review.%Get("commit") '= "") && (review.%Get("date") '= ""))
}

}
