Class SignalNoir.Tests.Fakes.FakeEmbedder Extends SignalNoir.Precedents.LexicalEmbedder
{

/// 015 test double: the lexical vectors under a model name of the test's
/// own, so each test sees only its records; Fail makes every call fail as a
/// provider would
Property ModelName As %String [ InitialExpression = "test-lexical" ];

Property Fail As %Boolean [ InitialExpression = 0 ];

Method Embed(text As %String) As SignalNoir.Core.Result
{
	If ..Fail Return ##class(SignalNoir.Core.Result).Error("provider_unavailable", "fake embedding provider is down")
	Set r = ##super(text)
	Set r.details.model = ..ModelName
	Return r
}

Method Model() As %String
{
	Return ..ModelName
}

}
