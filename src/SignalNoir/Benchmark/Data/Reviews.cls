Class SignalNoir.Benchmark.Data.Reviews Extends SignalNoir.Benchmark.Data.Base
{

/// The reviews of the baseline (one per family) and of the evaluator (feature 010, FR-013, T055):
/// kind (baseline or evaluator), family (* for the evaluator), author, reviewer, commit reviewed
/// and date, and automated (true) when an automated reviewer did it. A review never blocks a run
/// (Constitution 2.0.0): the report shows how each was done, and one without all of them as incomplete.
XData Records [ MimeType = application/json ]
{
[
  {"kind": "baseline", "family": "P5", "author": "henry", "reviewer": "jose", "commit": "dfd2b0d", "date": "2026-11-02"},
  {"kind": "baseline", "family": "P8", "author": "henry", "reviewer": "jose", "commit": "dfd2b0d", "date": "2026-11-02"},
  {"kind": "baseline", "family": "clean", "author": "henry", "reviewer": "jose", "commit": "dfd2b0d", "date": "2026-11-02"},
  {"kind": "evaluator", "family": "*", "author": "henrique", "reviewer": "jose", "commit": "dfd2b0d", "date": "2026-11-02"}
]
}

}
