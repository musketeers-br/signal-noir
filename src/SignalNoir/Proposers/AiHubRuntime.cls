Class SignalNoir.Proposers.AiHubRuntime Extends SignalNoir.Core.Port.AgentRuntime
{

/// The AI Hub adapter (build 154): one Agent call in a new session.
/// Reached only by dynamic dispatch, so the class compiles on an instance
/// without %AI.* and reports "provider unavailable" there.
/// Verified live on build 154 (006 task T060, 2026-10-26): Provider.Create,
/// Agent.%New(provider), Model, SystemPrompt, CreateSession, Chat, Content
/// and Usage behave as used here.
/// The key is read from the runtime environment at call time and never
/// stored, logged or echoed.
/// AI Hub is present and a provider, model and key are configured
ClassMethod Configured() As %Boolean
{
	If '##class(%Dictionary.CompiledClass).%ExistsId("%AI.Agent") Return 0
	If '##class(%Dictionary.CompiledClass).%ExistsId("%AI.Provider") Return 0
	Return ((..Env("SN_AI_PROVIDER") '= "") && (..Env("SN_AI_MODEL") '= "") && (..Env("SN_AI_API_KEY") '= ""))
}

Method Complete(systemPrompt As %String, input As %String, sessionTag As %String) As SignalNoir.Core.Result
{
	If '##class(%Dictionary.CompiledClass).%ExistsId("%AI.Agent") Return ##class(SignalNoir.Core.Result).Error("provider_unavailable", "AI Hub is not available on this instance")
	Set providerName = ..Env("SN_AI_PROVIDER"), model = ..Env("SN_AI_MODEL")
	If (providerName = "") || (model = "") Return ##class(SignalNoir.Core.Result).Error("provider_unavailable", "no provider or model configured")
	If ..Env("SN_AI_API_KEY") = "" Return ##class(SignalNoir.Core.Result).Error("provider_unavailable", providerName _ " (no API key configured)")
	Set result = ""
	Try {
		Set provider = $ClassMethod("%AI.Provider", "Create", providerName, {"api_key": (..Env("SN_AI_API_KEY"))})
		Set agent = $ClassMethod("%AI.Agent", "%New", provider)
		Set $Property(agent, "Model") = model
		Set $Property(agent, "SystemPrompt") = systemPrompt
		; the same evidence should lead to the same proposal (006 T060)
		Set $Property(agent, "Temperature") = 0
		; a new session for this Investigation only
		Set session = $Method(agent, "CreateSession")
		Set response = $Method(agent, "Chat", session, input)
		Set content = $Property(response, "Content")
		Set details = {"content": (content), "provider": (providerName), "model": (model), "sessionTag": (sessionTag)}
		Do ..Usage(response, details)
		Set result = ##class(SignalNoir.Core.Result).OkRef("")
		Set result.details = details
	}
	Catch ex {
		; the exception text never carries the key: only its name is kept
		Set result = ##class(SignalNoir.Core.Result).Error("provider_unavailable", providerName _ " call failed: " _ ex.Name)
	}
	Return result
}

/// Token usage from %AI.LLM.Response.Usage (verified on build 154, T060:
/// prompt_tokens, completion_tokens, total_tokens, cache_read_tokens,
/// reasoning_tokens)
Method Usage(response, details As %DynamicObject) [ Private ]
{
	Try {
		Set usage = $Property(response, "Usage")
		If '$IsObject(usage) Quit
		; %Get: in ObjectScript "_" is the concatenation operator, so usage.prompt_tokens
		; would not read the key
		If usage.%Get("prompt_tokens") '= "" Do details.%Set("tokensIn", +usage.%Get("prompt_tokens"))
		If usage.%Get("completion_tokens") '= "" Do details.%Set("tokensOut", +usage.%Get("completion_tokens"))
	}
	Catch {
	}
}

ClassMethod Env(name As %String) As %String [ Private ]
{
	Return $System.Util.GetEnviron(name)
}

}
