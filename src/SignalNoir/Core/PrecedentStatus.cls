Class SignalNoir.Core.PrecedentStatus Extends %RegisteredObject
{

/// The honest status of a precedent search (feature 015, FR-011, research
/// R5), decided in a fixed order so two situations never share a message.
Parameter STATUSES = "results,no_precedents,nothing_similar,rebuilding,needs_rebuild,unavailable";

/// rebuilding: a rebuild is running; embedError: the embedder failed;
/// configured / other: precedents built with the configured model / any
/// other model; matches: results at or above the minimum similarity
ClassMethod Decide(rebuilding As %Boolean, embedError As %Boolean, configured As %Integer, other As %Integer, matches As %Integer) As %String
{
	If rebuilding Return "rebuilding"
	If embedError Return "unavailable"
	If (configured = 0) && (other > 0) Return "needs_rebuild"
	If configured = 0 Return "no_precedents"
	If matches = 0 Return "nothing_similar"
	Return "results"
}

}
