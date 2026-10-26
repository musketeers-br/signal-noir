Class SignalNoir.Core.Port.AgentRuntime Extends %RegisteredObject [ Abstract ]
{

/// Internal port of feature 006: one model call in a new session.
/// Result.details: content, provider, model, tokensIn, tokensOut,
/// estCostUsd, sessionTag. Failure codes: provider_unavailable, refused.
Method Complete(systemPrompt As %String, input As %String, sessionTag As %String) As SignalNoir.Core.Result
{
	Return ##class(SignalNoir.Core.Result).Error("provider_unavailable", "Abstract port method - override in adapter or fake")
}

}
