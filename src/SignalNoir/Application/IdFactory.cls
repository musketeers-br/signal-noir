Class SignalNoir.Application.IdFactory Extends SignalNoir.Core.Port.IdGenerator
{

/// IdGenerator adapter: New(prefix) accepts only the agreed prefixes and
/// rejects anything else with an empty result. Ids are opaque, prefix plus an
/// IRIS-incremented counter.
Method New(prefix As %String) As %String
{
	If '##class(SignalNoir.Core.Vocab).IsIdPrefix(prefix) Return ""
	Set n = $INCREMENT(^SignalNoir.Ids(prefix))
	Return prefix _ $TRANSLATE($JUSTIFY(n, 6), " ", "0")
}

}
