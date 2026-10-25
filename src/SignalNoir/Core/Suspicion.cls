Class SignalNoir.Core.Suspicion Extends %RegisteredObject
{

/// Embedded-instruction scan (FR-013 of the PRD, spec 006 FR-010). Content
/// of Orders, Partner responses and logs is data; a match only marks the
/// Evidence and records the attempt. Nothing downstream reads the marker to
/// decide a path. Pure: no I/O.
/// Case-insensitive phrases, EN and PT, separated by |
Parameter PHRASES = "ignore previous|ignore all previous|ignore the previous|disregard|you are now|system:|assistant:|approve|execute|set state|change the action|override|ignore as instruções|ignore as instrucoes|aprove|execute agora|desconsidere";

/// Excerpts (up to 160 chars around each match) found anywhere in value
/// (string, %DynamicObject or %DynamicArray, walked recursively)
ClassMethod Scan(value) As %ListOfDataTypes
{
	Set out = ##class(%ListOfDataTypes).%New()
	Do ..Walk(value, out, 0)
	Return out
}

ClassMethod Walk(value, out As %ListOfDataTypes, depth As %Integer) [ Private ]
{
	If depth > 20 Return
	If $IsObject(value) {
		If 'value.%IsA("%DynamicAbstractObject") Return
		Set it = value.%GetIterator()
		While it.%GetNext(.key, .item) {
			Do ..Walk(item, out, depth + 1)
		}
		Return
	}
	Set text = $Get(value)
	If text = "" Return
	Set lower = $ZConvert(text, "L")
	For i = 1 : 1 : $Length(..#PHRASES, "|") {
		Set phrase = $Piece(..#PHRASES, "|", i)
		Set at = $Find(lower, phrase)
		If at = 0 Continue
		Set start = at - $Length(phrase) - 40
		If start < 1 Set start = 1
		Set excerpt = $Extract(text, start, start + 159)
		If out.Find(excerpt) = "" Do out.Insert(excerpt)
	}
}

}
