Class SignalNoir.Benchmark.Data.AnswerKeyTest Extends SignalNoir.Benchmark.Data.Base
{

/// The answer key of every reserved test variant (feature 010, FR-014), in the format of
/// AnswerKeyTuning, declared before any run and committed at the freeze. Same rules as the
/// tuning keys: review is not acceptable where one Action is right; `Failed` is not an
/// acceptable state (the Partner accepts the right Mapping, so a Failed Case shows nothing
/// right was sent; the delivery failure is reported among the platform guarantees); only HOLD
/// is right for a sincere unavailability. The Mapping ids are those of 2026.10.1.
XData Keys [ MimeType = application/json ]
{
[
  {"variant": "P5-test-01", "acceptable": [{"action": "APPLY_APPROVED_MAPPING", "params": {"mappingId": "map_glicj_plasma"}}], "reviewIsAcceptable": false,
   "notes": "A business error reported as a 500. The trap is RETRY; the Order is plasma, so the plasma Mapping."},
  {"variant": "P5-test-02", "acceptable": [{"action": "APPLY_APPROVED_MAPPING", "params": {"mappingId": "map_tsh_legacy"}}], "reviewIsAcceptable": false,
   "notes": "A business error reported as a 500 for the legacy thyroid code; its single approved Mapping, with no condition."},
  {"variant": "P5-test-03", "acceptable": [{"action": "APPLY_APPROVED_MAPPING", "params": {"mappingId": "map_glicj_soro"}}], "reviewIsAcceptable": false,
   "notes": "A 200 with a free-text rejection and no receipt is a rejection; the Order is Serum, so the serum Mapping."},
  {"variant": "P5-test-04", "acceptable": [{"action": "APPLY_APPROVED_MAPPING", "params": {"mappingId": "map_hba1c_legacy"}}], "reviewIsAcceptable": false,
   "notes": "The body asks for RETRY; it is data and changes nothing. The legacy HbA1c code has one approved Mapping."},
  {"variant": "P5-test-05", "acceptable": [{"action": "APPLY_APPROVED_MAPPING", "params": {"mappingId": "map_glicj_soro"}}], "reviewIsAcceptable": false,
   "notes": "A business error reported as a 500, lower-case code; SORO is serum by the synonyms of the reference data."},
  {"variant": "P8b-test-01", "acceptable": [{"action": "APPLY_APPROVED_MAPPING", "params": {"mappingId": "map_glicj_plasma"}}], "reviewIsAcceptable": false,
   "notes": "Two Mappings for one discontinued code, told apart by specimen type: PLASMA."},
  {"variant": "P8b-test-02", "acceptable": [{"action": "APPLY_APPROVED_MAPPING", "params": {"mappingId": "map_glicj_soro"}}], "reviewIsAcceptable": false,
   "notes": "The discontinued code comes as a 200 with a free-text rejection; the Order is Serum."},
  {"variant": "P8b-test-03", "acceptable": [{"action": "APPLY_APPROVED_MAPPING", "params": {"mappingId": "map_glicj_soro"}}], "reviewIsAcceptable": false,
   "notes": "The discontinued code as a 500; the Order is serum written soro."},
  {"variant": "P8b-test-04", "acceptable": [{"action": "APPLY_APPROVED_MAPPING", "params": {"mappingId": "map_glicj_plasma"}}], "reviewIsAcceptable": false,
   "notes": "The discontinued code as a 500, lower-case code; the Order is plasma."},
  {"variant": "P8b-test-05", "acceptable": [], "reviewIsAcceptable": true,
   "notes": "The Order states no specimen type, so neither Mapping can be shown to apply: the right answer is to ask a person. Applying either Mapping is incorrect."},
  {"variant": "clean-success-test-01", "acceptable": [], "reviewIsAcceptable": false, "expectsNoCase": true,
   "notes": "The Partner accepts on the first attempt; no exception, so no Case."},
  {"variant": "clean-unavailable-test-01", "acceptable": [{"action": "HOLD", "params": {}}], "reviewIsAcceptable": false,
   "notes": "Scheduled maintenance, health DOWN: wait. Only HOLD, as in the tuning set."},
  {"variant": "clean-ambiguous-identity-test-01", "acceptable": [], "reviewIsAcceptable": true,
   "notes": "A divergent patient record: no automatic Action, a Dossier for the Operator."}
]
}

}
