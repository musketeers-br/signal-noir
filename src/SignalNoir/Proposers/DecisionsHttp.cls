Class SignalNoir.Proposers.DecisionsHttp Extends SignalNoir.Core.Port.DecisionsRuntime
{

/// The OpenAI Decisions API over HTTP (feature 013). A direct client, by
/// Henry's decision of 2026-10-31, because AI Hub build 154 has no decisions
/// route (docs/verification/013-decisions-spike.md). The key is read from the
/// runtime environment at call time and never stored, logged or echoed; the
/// provider's error text is dropped because the 401 message repeats part of
/// the key. Verified live on build 154 (research R0).
/// The request goes out through Embedded Python (httpx, shipped with build 154):
/// TLS uses the certifi bundle, so no SSL configuration is created in %SYS, and
/// the body is encoded as UTF-8 by Python (a Latin-1 "código" made the API answer 400).
Parameter URL = "https://api.openai.com/v1/decisions";

Parameter MODEL = "gpt-6-luna";

/// A key is available: SN_DECISIONS_API_KEY, or the Agent's key when the
/// Agent's provider is OpenAI
ClassMethod Configured() As %Boolean
{
	Return (..Key() '= "")
}

ClassMethod Model() As %String
{
	Set model = $System.Util.GetEnviron("SN_DECISIONS_MODEL")
	Return $Select(model '= "": model, 1: ..#MODEL)
}

Method Decide(body As %DynamicObject, timeoutSeconds As %Integer) As SignalNoir.Core.Result
{
	If '..Configured() Return ##class(SignalNoir.Core.Result).Error("provider_unavailable", "decisions (no API key configured)")
	Set result = ""
	Try {
		Set request = {}.%FromJSON(body.%ToJSON())
		Set request.model = ..Model()
		Set timeout = $Select(+timeoutSeconds > 0: +timeoutSeconds, 1: 20)
		Set sent = {}.%FromJSON(..Post(..#URL, ..Key(), request.%ToJSON(), timeout))
		If sent.error '= "" {
			Set result = ##class(SignalNoir.Core.Result).Error("provider_unavailable", "decisions call failed: " _ sent.error)
			Quit
		}
		Set status = sent.status
		Set answer = ""
		Try {
			Set answer = {}.%FromJSON(sent.data)
		}
		Catch {
		}
		If status '= 200 {
			Set code = ""
			If $IsObject(answer) && $IsObject(answer.error) Set code = answer.error.code
			Set result = ##class(SignalNoir.Core.Result).Error("provider_unavailable", "decisions HTTP " _ status _ $Select(code '= "": " " _ code, 1: ""))
			Quit
		}
		If '$IsObject(answer) {
			Set result = ##class(SignalNoir.Core.Result).Error("invalid_response", "decisions answer is not JSON")
			Quit
		}
		Set result = ##class(SignalNoir.Core.Result).OkRef("")
		Set result.details = {"answer": (answer), "status": (status), "model": (request.model)}
	}
	Catch ex {
		; the exception never carries the key: only its name is kept
		Set result = ##class(SignalNoir.Core.Result).Error("provider_unavailable", "decisions call failed: " _ ex.Name)
	}
	Return result
}

/// The request, built without sending it: the body as UTF-8 bytes, the key only
/// in the Authorization header
ClassMethod Request(url As %String, key As %String, json As %String) As %SYS.Python [ Language = python ]
{
	import httpx
	return httpx.Request("POST", url, content=json.encode("utf-8"), headers={"Authorization": "Bearer " + key, "Content-Type": "application/json; charset=utf-8"})
}

/// Sends the request; returns {"status", "data"} or {"error": <exception name>}.
/// An exception is reduced to its class name, so its text (which may echo the
/// request) never leaves this method.
ClassMethod Post(url As %String, key As %String, json As %String, timeoutSeconds As %Integer) As %String [ Language = python ]
{
	import json as js
	import httpx
	import iris
	try:
		request = iris.cls("SignalNoir.Proposers.DecisionsHttp").Request(url, key, json)
		with httpx.Client(timeout=float(timeoutSeconds)) as client:
			response = client.send(request)
		return js.dumps({"status": response.status_code, "data": response.text})
	except Exception as ex:
		return js.dumps({"error": type(ex).__name__})
}

/// Live smoke check (labelled live): one synthetic request through the
/// whole proposer path except the Investigation. Never part of the suites.
ClassMethod Smoke() As %DynamicObject
{
	Set evidence = [{"evidenceId": "evid_smoke_1", "source": "tool.partner_health", "kind": "fact", "suspicious": false, "result": {"status": "DOWN"}}, {"evidenceId": "evid_smoke_2", "source": "system.exception", "kind": "fact", "suspicious": false, "result": {"kind": "timeout"}}]
	Set body = ##class(SignalNoir.Core.DecisionQuestions).Build({"caseId": "case_smoke", "orderId": "ORD-SMOKE-1", "partnerId": "PARTNER-A"}, {"orderId": "ORD-SMOKE-1", "synthetic": true}, evidence, [])
	Set started = $ZHorolog
	Set call = ..%New().Decide(body, 20)
	Set out = {"live": true, "ok": (call.ok), "ms": (($ZHorolog - started) * 1000 \ 1)}
	If 'call.ok Return out.%Set("error", call.message)
	Set converted = ##class(SignalNoir.Core.DecisionAnswer).Convert(call.details.answer, [{"evidenceId": "evid_smoke_1", "source": "tool.partner_health"}, {"evidenceId": "evid_smoke_2", "source": "system.exception"}], [])
	Do out.%Set("model", call.details.model)
	Do out.%Set("answers", call.details.answer.answers)
	Do out.%Set("converted", $Select(converted.ok: converted.obj, 1: {"code": (converted.code), "reason": (converted.message)}))
	Return out
}

ClassMethod Key() As %String [ Private ]
{
	Set key = $System.Util.GetEnviron("SN_DECISIONS_API_KEY")
	If (key = "") && ($System.Util.GetEnviron("SN_AI_PROVIDER") = "openai") Set key = $System.Util.GetEnviron("SN_AI_API_KEY")
	Return key
}

}
