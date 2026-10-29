Class SignalNoir.Tests.Core.TestResponseClass Extends %UnitTest.TestCase
{

/// 008 T002 - the classifier of Partner answers (research R2, AD-13.1):
/// only a Receipt that matches the send is success; anything unknown is
/// uncertain and leads to reconciliation
Method TestClasses()
{
	Set k = "bek_0123456789abcdef", o = "ORD-1"
	Set t503 = "{""status"":""unavailable""}", t504 = "{""error"":{}}", t500 = "{""erro"":""GLIC-J descontinuado""}"
	Set t400 = "{""error"":""bad""}", t422 = "{""error"":{""code"":""IDEMPOTENCY_KEY_REUSED""}}"
	Set receipt = {"receiptId": "rcp_1", "orderId": (o), "idempotencyKey": (k), "receivedAt": "2026-10-28T10:00:00Z", "partnerId": "labpartner-a"}
	Do ..Check({"answered": 0}, o, k, "uncertain", "timeout", "no answer")
	Do ..Check({"answered": 1, "status": 200, "json": (receipt)}, o, k, "success", "", "a matching Receipt")
	Do ..Check({"answered": 1, "status": 200, "json": {"receiptId": "rcp_1", "orderId": "ORD-2", "idempotencyKey": (k)}}, o, k, "uncertain", "invalid_receipt", "another Order")
	Do ..Check({"answered": 1, "status": 200, "json": {"receiptId": "rcp_1", "orderId": (o), "idempotencyKey": "bek_other"}}, o, k, "uncertain", "invalid_receipt", "another key")
	Do ..Check({"answered": 1, "status": 200, "json": {"orderId": (o), "idempotencyKey": (k)}}, o, k, "uncertain", "invalid_receipt", "no receiptId")
	Do ..Check({"answered": 1, "status": 200, "text": "rejeitado: exame desconhecido"}, o, k, "uncertain", "invalid_receipt", "free text in a 200")
	Do ..Check({"answered": 1, "status": 503, "text": (t503)}, o, k, "transient", "http_error", "declared unavailability")
	Do ..Check({"answered": 1, "status": 429, "text": ""}, o, k, "transient", "http_error", "too many requests")
	Do ..Check({"answered": 1, "status": 504, "text": (t504)}, o, k, "uncertain", "timeout", "gateway timeout")
	Do ..Check({"answered": 1, "status": 500, "text": "  "}, o, k, "uncertain", "http_error", "5xx without a body")
	Do ..Check({"answered": 1, "status": 500, "text": (t500)}, o, k, "business_error", "http_error", "5xx with a body")
	Do ..Check({"answered": 1, "status": 400, "text": (t400)}, o, k, "business_error", "business_rejection", "400")
	Do ..Check({"answered": 1, "status": 404, "text": ""}, o, k, "business_error", "business_rejection", "404")
	Do ..Check({"answered": 1, "status": 409, "text": "already processed"}, o, k, "business_error", "business_rejection", "409")
	Do ..Check({"answered": 1, "status": 422, "text": (t422)}, o, k, "business_error", "business_rejection", "key reused")
	Do ..Check({"answered": 1, "status": 201, "json": (receipt)}, o, k, "uncertain", "invalid_receipt", "a Receipt on a non-200 is not success")
}

Method TestReceiptOf()
{
	Set r = ##class(SignalNoir.Core.ResponseClass).Classify({"answered": 1, "status": 200, "json": {"receiptId": "rcp_9", "orderId": "O", "idempotencyKey": "K"}}, "O", "K")
	Do $$$AssertEquals(r.receipt.receiptId, "rcp_9", "the Receipt travels with the class")
	Set long = $Translate($Justify("", 900), " ", "x")
	Set r = ##class(SignalNoir.Core.ResponseClass).Classify({"answered": 1, "status": 500, "text": (long)}, "O", "K")
	Do $$$AssertEquals($Length(r.excerpt), 500, "body excerpt capped at 500")
}

Method Check(answer As %DynamicObject, orderId As %String, key As %String, class As %String, kind As %String, label As %String) [ Private ]
{
	Set r = ##class(SignalNoir.Core.ResponseClass).Classify(answer, orderId, key)
	Do $$$AssertEquals(r.class _ "/" _ r.kind, class _ "/" _ kind, label)
}

}
