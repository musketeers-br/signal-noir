Class SignalNoir.Proposers.AiHubRuntime Extends SignalNoir.Core.Port.AgentRuntime
{

/// The AI Hub adapter (build 154): one Agent call in a new session.
/// Reached only by dynamic dispatch, so the class compiles on an instance
/// without %AI.* and reports "provider unavailable" there.
/// NOT VERIFIED LIVE: the dev instance has no AI Hub (006 research R0); the
/// calls follow the 001 stack research and are verified by task T060.
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

/// Token usage when the response exposes it (property names unverified)
Method Usage(response, details As %DynamicObject) [ Private ]
{
	Try {
		Set usage = $Property(response, "Usage")
		If $IsObject(usage) {
			Set in = $Select(usage.%IsA("%DynamicObject"): usage.%Get("input_tokens"), 1: "")
			Set out = $Select(usage.%IsA("%DynamicObject"): usage.%Get("output_tokens"), 1: "")
			If in '= "" Do details.%Set("tokensIn", +in)
			If out '= "" Do details.%Set("tokensOut", +out)
		}
	}
	Catch {
	}
}

ClassMethod Env(name As %String) As %String [ Private ]
{
	Return $System.Util.GetEnviron(name)
}

}
