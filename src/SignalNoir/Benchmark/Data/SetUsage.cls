Class SignalNoir.Benchmark.Data.SetUsage Extends SignalNoir.Benchmark.Data.Base
{

/// Test sets declared used (feature 010, FR-027, plan Q3): when the prompt, the rules or the
/// policies were adjusted on the results of a test set, that set is development data and a new
/// reserved test is required. Declared by a commit that adds a line, so it is auditable and cannot
/// be undone silently: {set: "P5/test", by, at, why}. Append only.
XData Records [ MimeType = application/json ]
{
[]
}

}
