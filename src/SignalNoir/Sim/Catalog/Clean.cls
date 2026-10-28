Class SignalNoir.Sim.Catalog.Clean Extends SignalNoir.Sim.Catalog.Base
{

/// Clean controls (FR-031): success, sincere unavailability, unknown code
/// with a single approved mapping, already processed, ambiguous identity.
XData Variants [ MimeType = application/json ]
{
[
  {"family": "clean", "subtype": "clean.success", "variant": "clean-success-tune-01", "set": "tuning", "partnerId": "labpartner-a", "language": "en",
   "description": "The Partner accepts the Order on the first attempt.",
   "orders": [{"exams": ["HEMO"], "specimen": {"type": "whole_blood"}}],
   "script": {"health": {"status": "UP", "message": "all systems nominal"},
              "attempts": [{"match": "any", "respond": {"status": 200, "receipt": true, "delay": "fast"}}], "triggers": []}},
  {"family": "clean", "subtype": "clean.partner_unavailable", "variant": "clean-unavailable-tune-01", "set": "tuning", "partnerId": "labpartner-a", "language": "en",
   "description": "The Partner is sincerely unavailable for two attempts, then accepts.",
   "orders": [{"exams": ["HEMO"], "specimen": {"type": "whole_blood"}}],
   "script": {"health": {"status": "DOWN", "message": "scheduled outage, back shortly"},
              "attempts": [{"match": "attempt:1", "respond": {"status": 503, "body": "unavailable", "delay": "fast"}},
                           {"match": "attempt:2", "respond": {"status": 503, "body": "unavailable", "delay": "fast"}},
                           {"match": "attempt:3+", "respond": {"status": 200, "receipt": true, "delay": "fast"}}], "triggers": []}},
  {"family": "clean", "subtype": "clean.unknown_code_single_mapping", "variant": "clean-unknown-code-tune-01", "set": "tuning", "partnerId": "labpartner-a", "language": "pt",
   "description": "A legacy exam code with one approved mapping; the Partner rejects the legacy code.",
   "orders": [{"exams": ["HBA1C-L"], "specimen": {"type": "whole_blood"}}],
   "script": {"health": {"status": "UP", "message": "operacional"},
              "attempts": [{"match": "beforeMapping", "respond": {"status": 400, "body": "unknown-code", "delay": "fast"}},
                           {"match": "accepted", "respond": {"status": 200, "receipt": true, "delay": "fast"}}], "triggers": []},
   "partnerRule": {"accepts": [{"code": "HBA1C"}]}},
  {"family": "clean", "subtype": "clean.already_processed", "variant": "clean-already-processed-tune-01", "set": "tuning", "partnerId": "labpartner-b", "language": "en",
   "description": "The Partner says the Order was already processed and quotes an earlier receipt.",
   "orders": [{"exams": ["TSH"], "specimen": {"type": "serum"}}],
   "script": {"health": {"status": "UP", "message": "all systems nominal"},
              "attempts": [{"match": "any", "respond": {"status": 409, "body": "already-processed", "delay": "fast"}}], "triggers": []}},
  {"family": "clean", "subtype": "clean.ambiguous_identity", "variant": "clean-ambiguous-identity-tune-01", "set": "tuning", "partnerId": "labpartner-b", "language": "pt",
   "description": "The Partner rejects the Order citing a divergent patient record.",
   "orders": [{"exams": ["TSH"], "specimen": {"type": "serum"}}],
   "script": {"health": {"status": "UP", "message": "operacional"},
              "attempts": [{"match": "any", "respond": {"status": 400, "body": "divergent-patient", "delay": "fast"}}], "triggers": []}}
]
}

}
