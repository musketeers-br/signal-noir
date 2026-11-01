Class SignalNoir.Benchmark.Data.ReferenceResult Extends SignalNoir.Benchmark.Data.Base
{

/// The published reference result, recorded after the reference run (feature 010, T062): the
/// provider and model it ran with, per reference case the final state, Action and parameters (what
/// the quick validation compares with and what Replay plays back), and the recovery-suite evidence for
/// restart and late worker with the commit it ran on. `quickCases` names the three reference cases the quick
/// validation runs (a control, a P5 or P8b case, a Dossier case). Empty until the reference run exists.
XData Record [ MimeType = application/json ]
{
{
  "recordedAt": null,
  "provider": null,
  "model": null,
  "seed": null,
  "cases": [],
  "quickCases": [],
  "recoverySuite": null
}
}

}
