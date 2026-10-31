Class SignalNoir.Core.Port.Embedder Extends %RegisteredObject [ Abstract ]
{

/// Internal port of feature 015 (seam v5): turns a precedent text into a
/// similarity vector. Embed returns Result.ref = the vector as a comma list
/// of DIMENSION numbers; Result.details: model, mode (lexical or provider),
/// dimension. Failures are values: provider_unavailable,
/// unsupported_dimension.
Parameter DIMENSION = 1536;

Method Embed(text As %String) As SignalNoir.Core.Result
{
	Return ##class(SignalNoir.Core.Result).Error("provider_unavailable", "Abstract port method - override in adapter or fake")
}

/// The model id this embedder writes and reads
Method Model() As %String
{
	Return ""
}

/// lexical or provider
Method Mode() As %String
{
	Return ""
}

}
