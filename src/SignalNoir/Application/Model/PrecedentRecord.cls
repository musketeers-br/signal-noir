Class SignalNoir.Application.Model.PrecedentRecord Extends %Persistent
{

/// One closed Case seen as a precedent, for one embedding model (feature
/// 015). A projection of the Case, rebuilt from it: never Evidence, never
/// Validator input. The vector never leaves the server.
Property caseId As %String(MAXLEN = 64) [ Required ];

Property embeddingModel As %String(MAXLEN = 64) [ Required ];

/// Unique, not IdKey: an HNSW index needs the default integer row id
Index precedentKey On (caseId, embeddingModel) [ Unique ];

Index modelIdx On embeddingModel;

Property orderId As %String(MAXLEN = 128);

Property partnerId As %String(MAXLEN = 128);

/// The allow-listed structured facts (codes only)
Property factsJson As %String(MAXLEN = 4096);

/// Display text, built from the facts
Property description As %String(MAXLEN = 600);

/// The exact text the vector was built from
Property rawText As %String(MAXLEN = 600);

/// lexical or provider
Property mode As %String(MAXLEN = 16);

Property dimension As %Integer;

Property embedding As %Library.Vector(DATATYPE = "DOUBLE", LEN = 1536);

Index embeddingHnsw On (embedding) As %SQL.Index.HNSW(Distance = "Cosine");

Property finalState As %String(MAXLEN = 32);

Property action As %String(MAXLEN = 64);

Property closedAt As %String(MAXLEN = 64);

Property durationSeconds As %Integer;

Property synthetic As %Boolean [ InitialExpression = 1 ];

Property replay As %Boolean [ InitialExpression = 0 ];

Property indexedAt As %String(MAXLEN = 64);

}
