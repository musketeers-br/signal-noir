Class SignalNoir.Precedents.LexicalEmbedder Extends SignalNoir.Core.Port.Embedder
{

/// The embedder used when no embedding provider is configured: word overlap
/// by feature hashing (Core.LexicalVector). Never presented as semantic.
Method Embed(text As %String) As SignalNoir.Core.Result
{
	Set r = ##class(SignalNoir.Core.Result).OkRef(##class(SignalNoir.Core.LexicalVector).Csv(##class(SignalNoir.Core.LexicalVector).Of(text)))
	Set r.details = {"model": (..Model()), "mode": (..Mode()), "dimension": (..#DIMENSION)}
	Return r
}

Method Model() As %String
{
	Return ##class(SignalNoir.Core.LexicalVector).#MODEL
}

Method Mode() As %String
{
	Return "lexical"
}

}
