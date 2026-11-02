Class SignalNoir.Benchmark.Data.Freeze Extends SignalNoir.Benchmark.Data.Base
{

/// The freeze record: the prompt, model, baseline, policies, fixtures and evaluator fixed before
/// the reserved test runs (feature 010, FR-026). One record, written in one commit (T056) by
/// the holder of the reserved cases. A placeholder (freezeId empty) means nothing is frozen yet,
/// and a reference run is then development data. `files` lists the git blob id of each frozen
/// source file, which scripts/benchmark/check-freeze.sh compares in CI.
XData Record [ MimeType = application/json ]
{
{
  "freezeId": "",
  "commit": "",
  "frozenAt": "",
  "promptVersion": "",
  "model": "",
  "baselineVersion": "",
  "policyVersion": "",
  "mappingVersion": "",
  "policyDigest": "",
  "mappingDigest": "",
  "evaluatorVersion": "",
  "reservedCatalogDigest": "",
  "answerKeyDigest": "",
  "files": []
}
}

}
