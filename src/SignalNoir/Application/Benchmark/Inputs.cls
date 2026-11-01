Class SignalNoir.Application.Benchmark.Inputs Extends %RegisteredObject
{

/// The frozen inputs as they are now (feature 010, plan D8): the versions the freeze record names,
/// and the digests of what cannot be told by a version alone (the policy and Mapping fixtures, the
/// reserved variants of the Simulator's catalog, the reserved answer keys). Source files cannot be
/// hashed at run time; scripts/benchmark/check-freeze.sh covers them in CI.
ClassMethod Current(model As %String, policyVersion As %String, mappingVersion As %String, catalog As %DynamicArray) As %DynamicObject
{
	Set snapshot = ##class(SignalNoir.Application.Reference.Store).For({"inRun": true, "policyVersion": (policyVersion), "mappingVersion": (mappingVersion)})
	Set policyDigest = "", mappingDigest = ""
	If snapshot.ok {
		Set policyDigest = ..Digest(##class(SignalNoir.Core.EffectKey).Canonical(snapshot.obj.policies))
		Set mappingDigest = ..Digest(##class(SignalNoir.Core.EffectKey).Canonical({"mappings": (snapshot.obj.mappings), "synonyms": (snapshot.obj.synonyms)}))
	}
	Return {
		"promptVersion": ($Parameter("SignalNoir.Proposers.Agent", "PROMPTVERSION")),
		"model": (model),
		"baselineVersion": ($Parameter("SignalNoir.Proposers.Rules", "VERSION")),
		"policyVersion": (policyVersion),
		"mappingVersion": (mappingVersion),
		"policyDigest": (policyDigest),
		"mappingDigest": (mappingDigest),
		"evaluatorVersion": ($Parameter("SignalNoir.Core.Benchmark.Scorer", "VERSION")),
		"reservedCatalogDigest": (..CatalogDigest(catalog)),
		"answerKeyDigest": (..KeyDigest())
	}
}

/// The reserved (test) variants of the catalog, in variant order, as one digest
ClassMethod CatalogDigest(catalog As %DynamicArray) As %String
{
	If '$IsObject(catalog) Return ..Digest("")
	For i = 0 : 1 : catalog.%Size() - 1 {
		Set v = catalog.%Get(i)
		If v.set = "test" Set text(v.variant) = ##class(SignalNoir.Core.EffectKey).Canonical(v)
	}
	Set joined = "", name = ""
	For {
		Set name = $Order(text(name))
		Quit:name=""
		Set joined = joined _ name _ "=" _ text(name) _ ";"
	}
	Return ..Digest(joined)
}

/// The reserved answer keys, as one digest ("" digest when none exist yet)
ClassMethod KeyDigest() As %String
{
	Set keys = ##class(SignalNoir.Benchmark.Data.Base).Read("SignalNoir.Benchmark.Data.AnswerKeyTest", "Keys")
	Return ..Digest($Select($IsObject(keys): ##class(SignalNoir.Core.EffectKey).Canonical(keys), 1: ""))
}

ClassMethod Digest(text As %String) As %String
{
	Set h = $System.Encryption.SHAHash(256, $ZConvert(text, "O", "UTF8")), hex = ""
	For i = 1 : 1 : $Length(h) Set hex = hex _ $ZConvert($Translate($Justify($ZHex($Ascii(h, i)), 2), " ", "0"), "L")
	Return hex
}

}
