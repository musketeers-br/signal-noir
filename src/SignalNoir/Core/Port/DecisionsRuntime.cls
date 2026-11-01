Class SignalNoir.Core.Port.DecisionsRuntime Extends %RegisteredObject [ Abstract ]
{

/// Internal port of feature 013 (seam v6): one Decisions API request.
/// Result.details: answer (the parsed response), status (HTTP status),
/// model. Failure code: provider_unavailable, whose message holds only the
/// HTTP status and the provider's error code, never its error text.
Method Decide(body As %DynamicObject, timeoutSeconds As %Integer) As SignalNoir.Core.Result
{
	Return ##class(SignalNoir.Core.Result).Error("provider_unavailable", "Abstract port method - override in adapter or fake")
}

}
