Class SignalNoir.Sim.Catalog.Idempotency Extends SignalNoir.Sim.Catalog.Base
{

/// Recovery variants (research, spec "Recovery variants"): a lost response,
/// a slow accept to restart during, and a plain accept for repeated approval.
XData Variants [ MimeType = application/json ]
{
[
  {"family": "idempotency", "subtype": "idempotency.lost_receipt", "variant": "idempotency-lost-receipt-tune-01", "set": "tuning", "partnerId": "labpartner-a", "language": "en",
   "description": "The Partner records the receipt and the response is lost.",
   "orders": [{"exams": ["HEMO"], "specimen": {"type": "whole_blood"}}],
   "script": {"health": {"status": "UP", "message": "all systems nominal"},
              "attempts": [{"match": "attempt:1", "respond": {"status": 200, "receipt": true, "lose": true, "delay": "timeout"}},
                           {"match": "any", "respond": {"status": 200, "receipt": true, "delay": "fast"}}], "triggers": []}},
  {"family": "idempotency", "subtype": "idempotency.restart_during_executing", "variant": "idempotency-restart-tune-01", "set": "tuning", "partnerId": "labpartner-a", "language": "en",
   "description": "A slow accept, so the product can restart in the middle of the call.",
   "orders": [{"exams": ["HEMO"], "specimen": {"type": "whole_blood"}}],
   "script": {"health": {"status": "UP", "message": "all systems nominal"},
              "attempts": [{"match": "any", "respond": {"status": 200, "receipt": true, "delay": "slow"}}], "triggers": []}},
  {"family": "idempotency", "subtype": "idempotency.repeated_approval", "variant": "idempotency-repeated-approval-tune-01", "set": "tuning", "partnerId": "labpartner-a", "language": "en",
   "description": "Accepts once; a repeated delivery replays the original receipt.",
   "orders": [{"exams": ["HEMO"], "specimen": {"type": "whole_blood"}}],
   "script": {"health": {"status": "UP", "message": "all systems nominal"},
              "attempts": [{"match": "any", "respond": {"status": 200, "receipt": true, "delay": "fast"}}], "triggers": []}}
]
}

}
