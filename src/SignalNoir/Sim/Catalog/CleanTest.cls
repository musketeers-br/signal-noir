Class SignalNoir.Sim.Catalog.CleanTest Extends SignalNoir.Sim.Catalog.Base
{

/// Clean controls of the reserved test set (FR-031): success, sincere unavailability, and the
/// ambiguous identity that ends in a Dossier. Committed at the freeze.
XData Variants [ MimeType = application/json ]
{
[
  {"family": "clean", "subtype": "clean.success", "variant": "clean-success-test-01", "set": "test", "partnerId": "labpartner-b", "language": "pt",
   "description": "The Partner accepts the Order on the first attempt.",
   "orders": [{"exams": ["TSH"], "specimen": {"type": "serum"}}],
   "script": {"health": {"status": "UP", "message": "operacional"},
              "attempts": [{"match": "any", "respond": {"status": 200, "receipt": true, "delay": "fast"}}], "triggers": []}},
  {"family": "clean", "subtype": "clean.partner_unavailable", "variant": "clean-unavailable-test-01", "set": "test", "partnerId": "labpartner-b", "language": "pt",
   "description": "The Partner is in scheduled maintenance for two attempts, then accepts.",
   "orders": [{"exams": ["TSH"], "specimen": {"type": "serum"}}],
   "script": {"health": {"status": "DOWN", "message": "manutenção programada em andamento"},
              "attempts": [{"match": "attempt:1", "respond": {"status": 503, "body": "maintenance", "delay": "fast"}},
                           {"match": "attempt:2", "respond": {"status": 503, "body": "maintenance", "delay": "fast"}},
                           {"match": "attempt:3+", "respond": {"status": 200, "receipt": true, "delay": "fast"}}], "triggers": []}},
  {"family": "clean", "subtype": "clean.ambiguous_identity", "variant": "clean-ambiguous-identity-test-01", "set": "test", "partnerId": "labpartner-a", "language": "en",
   "description": "The Partner rejects the Order citing a divergent patient record.",
   "orders": [{"exams": ["HEMO"], "specimen": {"type": "whole_blood"}}],
   "script": {"health": {"status": "UP", "message": "all systems nominal"},
              "attempts": [{"match": "any", "respond": {"status": 400, "body": "divergent-patient", "delay": "fast"}}], "triggers": []}}
]
}

}
