Class SignalNoir.Core.ResponseClass Extends %RegisteredObject
{

/// The single classifier of Partner answers (Constitution I, AD-13.1,
/// 008 research R2). Pure: answer is {answered, status, text, json}; the
/// result is {class, kind, receipt, excerpt}. Only a 200 whose Receipt
/// matches the send's Order and key is success; anything the system cannot
/// read as a refusal or as unavailability is uncertain.
Parameter EXCERPT = 500;

ClassMethod Classify(answer As %DynamicObject, orderId As %String, key As %String) As %DynamicObject
{
	Set text = $Select(answer.%IsDefined("text"): answer.text, 1: "")
	Set json = answer.%Get("json")
	If (text = "") && $IsObject(json) Set text = json.%ToJSON()
	Set out = {"receipt": null, "excerpt": ($Extract(text, 1, ..#EXCERPT))}
	If 'answer.answered Return ..Set(out, "uncertain", "timeout")
	Set status = +answer.status
	If status = 200 {
		If $IsObject(json) && (json.%Get("receiptId") '= "") && (json.%Get("orderId") = orderId) && (json.%Get("idempotencyKey") = key) {
			Set out.receipt = json
			Return ..Set(out, "success", "")
		}
		Return ..Set(out, "uncertain", "invalid_receipt")
	}
	If (status = 503) || (status = 429) Return ..Set(out, "transient", "http_error")
	If status = 504 Return ..Set(out, "uncertain", "timeout")
	If status >= 500 {
		If ##class(SignalNoir.Core.Canon).Trim(text) = "" Return ..Set(out, "uncertain", "http_error")
		Return ..Set(out, "business_error", "http_error")
	}
	If status >= 400 Return ..Set(out, "business_error", "business_rejection")
	Return ..Set(out, "uncertain", "invalid_receipt")
}

ClassMethod Set(out As %DynamicObject, class As %String, kind As %String) As %DynamicObject [ Private ]
{
	Set out.class = class, out.kind = kind
	Return out
}

}
