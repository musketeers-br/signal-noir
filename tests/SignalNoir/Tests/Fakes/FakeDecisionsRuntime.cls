Class SignalNoir.Tests.Fakes.FakeDecisionsRuntime Extends SignalNoir.Core.Port.DecisionsRuntime
{

/// 013 test double: answers from ^SignalNoir.TestScript("decisions", key):
/// "answer" (JSON of the response; "@ev:<source>" tokens resolved against
/// the request's Evidence), "fail" (code:message), "hang" (seconds to wait
/// first). Records each request body under "request", n.
Method Decide(body As %DynamicObject, timeoutSeconds As %Integer) As SignalNoir.Core.Result
{
	Set n = $Increment(^SignalNoir.TestScript("decisions", "calls"))
	Set ^SignalNoir.TestScript("decisions", "request", n) = $Extract(body.%ToJSON(), 1, 30000)
	If $Get(^SignalNoir.TestScript("decisions", "hang")) Hang ^SignalNoir.TestScript("decisions", "hang")
	Set fail = $Get(^SignalNoir.TestScript("decisions", "fail"))
	If fail '= "" Return ##class(SignalNoir.Core.Result).Error($Piece(fail, ":", 1), $Piece(fail, ":", 2, *))
	Set text = $Get(^SignalNoir.TestScript("decisions", "answer"))
	Set evidence = body.input.%Get(0).content.%Get(0).data.evidence
	Set it = evidence.%GetIterator()
	While it.%GetNext(, .ev) {
		Set text = $Replace(text, "@ev:" _ ev.source, ev.evidenceId)
	}
	Set r = ##class(SignalNoir.Core.Result).OkRef("")
	Set r.details = {"answer": ({}.%FromJSON(text)), "status": 200, "model": "gpt-6-luna"}
	Return r
}

/// A response choosing value with the given probabilities, plus predicates
/// "source:probability" for Evidence sources
ClassMethod Answer(value As %String, top As %Numeric = 0.9, second As %Numeric = 0.05, confidence As %Numeric = 0.85, predicates As %String = "") As %String
{
	Set probs = [{"value": (value), "probability": (top)}]
	For other = "RETRY", "HOLD", "REQUEST_REVIEW", "other" {
		If other = value Continue
		Do probs.%Push({"value": (other), "probability": (second)})
		Set second = 0
	}
	Set answers = [{"type": "choice", "name": "action", "choice": (value), "probabilities": (probs), "confidence": (confidence)}]
	For i = 1 : 1 : $Length(predicates, ",") {
		Set p = $Piece(predicates, ",", i)
		If p = "" Continue
		Do answers.%Push({"type": "predicate", "name": ("ev:@ev:" _ $Piece(p, ":", 1, *-1)), "probability": (+$Piece(p, ":", *))})
	}
	Return {"model": "gpt-6-luna", "answers": (answers), "usage": {"input_tokens": 1200, "input_tokens_details": {"cached_tokens": 1024, "cache_write_tokens": 0}, "output_tokens": 0, "total_tokens": 1200}}.%ToJSON()
}

}
