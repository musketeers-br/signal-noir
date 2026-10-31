Class SignalNoir.Precedents.ProviderEmbedder Extends SignalNoir.Core.Port.Embedder
{

/// The embedding provider adapter (feature 015, research R3): OpenAI through
/// %Embedding.OpenAI, reached by dynamic dispatch so the class compiles
/// without it. The configuration, key included, is built at call time from
/// the runtime environment and never stored, logged or echoed (no
/// %Embedding.Config row). Verified on build 154: Embedding(input,
/// configuration) and the required keys modelName, apiKey, sslConfig. A live
/// call with a real key is not verified yet (research R3).
Property Provider As %String;

Property ModelName As %String;

/// TLS configuration name used for the provider (created if missing)
Parameter SSLCONFIG = "SignalNoirTLS";

/// An embedding provider, model and key are configured and the class exists
ClassMethod Configured() As %Boolean
{
	If ..Env("SN_EMBED_PROVIDER") '= "openai" Return 0
	If (..Env("SN_EMBED_MODEL") = "") || (..Env("SN_EMBED_API_KEY") = "") Return 0
	Return ##class(%Dictionary.CompiledClass).%ExistsId("%Embedding.OpenAI")
}

Method %OnNew() As %Status
{
	Set ..Provider = ..Env("SN_EMBED_PROVIDER")
	Set ..ModelName = ..Env("SN_EMBED_MODEL")
	Return $$$OK
}

Method Embed(text As %String) As SignalNoir.Core.Result
{
	If '..Configured() Return ##class(SignalNoir.Core.Result).Error("provider_unavailable", "no embedding provider configured")
	Set result = ""
	Try {
		Set config = {"modelName": (..ModelName), "apiKey": (..Env("SN_EMBED_API_KEY")), "sslConfig": (..EnsureTls())}
		Set raw = $ClassMethod("%Embedding.OpenAI", "Embedding", text, config.%ToJSON())
		Set csv = ..ToCsv(raw)
		Set n = $Select(csv = "": 0, 1: $Length(csv, ","))
		If n '= ..#DIMENSION {
			Set result = ##class(SignalNoir.Core.Result).Error("unsupported_dimension", ..ModelName _ " returned " _ n _ " dimensions, " _ ..#DIMENSION _ " required")
			Quit
		}
		Set result = ##class(SignalNoir.Core.Result).OkRef(csv)
		Set result.details = {"model": (..Model()), "mode": (..Mode()), "dimension": (n)}
	}
	Catch ex {
		; the exception text may carry the request: only its name is kept
		Set result = ##class(SignalNoir.Core.Result).Error("provider_unavailable", ..Provider _ " embedding call failed: " _ ex.Name)
	}
	Return result
}

Method Model() As %String
{
	Return ..ModelName
}

Method Mode() As %String
{
	Return "provider"
}

/// The vector as a comma list, whatever form the provider class returns
ClassMethod ToCsv(raw) As %String [ Private ]
{
	If $IsObject(raw) && raw.%IsA("%DynamicArray") {
		Set out = ""
		Set it = raw.%GetIterator()
		While it.%GetNext(, .v) { Set out = out _ $Select(out = "": "", 1: ",") _ v }
		Return out
	}
	If $ListValid(raw) && (raw '= "") Return $ListToString(raw, ",")
	Return $Translate(raw, "[] ")
}

/// A client TLS configuration in %SYS, created once; holds no secret
ClassMethod EnsureTls() As %String [ Private ]
{
	Set name = ..#SSLCONFIG
	New $Namespace
	Set $Namespace = "%SYS"
	If '##class(Security.SSLConfigs).Exists(name) Do ##class(Security.SSLConfigs).Create(name)
	Return name
}

ClassMethod Env(name As %String) As %String [ Private ]
{
	Return $System.Util.GetEnviron(name)
}

}
