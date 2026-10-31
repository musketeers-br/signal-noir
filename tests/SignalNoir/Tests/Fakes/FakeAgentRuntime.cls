Class SignalNoir.Tests.Fakes.FakeAgentRuntime Extends SignalNoir.Core.Port.AgentRuntime
{

/// Test-only AgentRuntime: answers from ^SignalNoir.TestScript("agent",
/// key): "content" (text returned as the model's answer; "@ev:<source>"
/// tokens resolved against the input), or "fail" (code:message). Records
/// each call's session tag and input so tests can inspect them.
Method Complete(systemPrompt As %String, input As %String, sessionTag As %String) As SignalNoir.Core.Result
{
	Set n = $Increment(^SignalNoir.TestScript("agent", "calls"))
	Set ^SignalNoir.TestScript("agent", "session", n) = sessionTag
	Set ^SignalNoir.TestScript("agent", "input", n) = $Extract(input, 1, 30000)
	Set ^SignalNoir.TestScript("agent", "prompt", n) = $Extract(systemPrompt, 1, 200)
	Set fail = $Get(^SignalNoir.TestScript("agent", "fail"))
	If fail '= "" Return ##class(SignalNoir.Core.Result).Error($Piece(fail, ":", 1), $Piece(fail, ":", 2, *))
	Set content = $Get(^SignalNoir.TestScript("agent", "content"))
	; resolve @ev:<source> against the evidence ids present in the input
	; line 4 is the EVIDENCE block (an optional PRECEDENTS block follows, 015)
	Set data = {}.%FromJSON($Piece(input, $Char(10), 4))
	For i = 0 : 1 : data.evidence.%Size() - 1 {
		Set ev = data.evidence.%Get(i)
		Set content = $Replace(content, """@ev:" _ ev.source _ """", """" _ ev.evidenceId _ """")
	}
	Set r = ##class(SignalNoir.Core.Result).OkRef("")
	Set r.details = {"content": (content), "provider": "fake-ai-hub", "model": "fake-model-1", "tokensIn": 900, "tokensOut": 150, "sessionTag": (sessionTag)}
	Return r
}

}
