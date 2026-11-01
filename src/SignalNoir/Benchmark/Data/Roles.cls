Class SignalNoir.Benchmark.Data.Roles Extends SignalNoir.Benchmark.Data.Base
{

/// Who held which role, per family (feature 010, FR-029): who prepared the reserved cases and
/// the answer key, and who wrote the rules baseline. The report copies it into its metadata, and
/// a reference run whose answer key and baseline are held by one person is development data.
/// The board names the intended holders (docs/specify-prompts/PARALELISMO.md); this records
/// what actually happened. Empty until the roles are filled in at the freeze.
XData Record [ MimeType = application/json ]
{
{
  "families": {}
}
}

}
