Class SignalNoir.Sim.Catalog.P3 Extends SignalNoir.Sim.Catalog.Base
{

/// P3: the world changes between Approval and Execution. Each variant fires
/// its change on the 2nd read of health or Origin status (research D12):
/// the 1st read is the Investigation's evidence, the 2nd is Revalidation.
XData Variants [ MimeType = application/json ]
{
[
  {"family": "P3", "subtype": "P3.partner_fails_again", "variant": "P3-fails-tune-01", "set": "tuning", "partnerId": "labpartner-a", "language": "en",
   "description": "The Partner degrades after the evidence was read.",
   "orders": [{"exams": ["HEMO"], "specimen": {"type": "whole_blood"}}],
   "script": {"health": {"status": "UP", "message": "all systems nominal"},
              "attempts": [{"match": "afterEvent:PARTNER_DEGRADES", "respond": {"status": 503, "body": "unavailable", "delay": "fast"}},
                           {"match": "any", "respond": {"status": 200, "receipt": true, "delay": "fast"}}],
              "afterEvent": {"PARTNER_DEGRADES": {"health": {"status": "DEGRADED", "message": "elevated error rate"},
                                                  "history": [{"outcome": "timeout", "httpStatus": null, "latencyMs": 90000, "message": "degraded-log"},
                                                              {"outcome": "unavailable", "httpStatus": 503, "latencyMs": 40, "message": "degraded-log"}]}},
              "triggers": [{"on": "read:health", "nth": 2, "event": "PARTNER_DEGRADES"}]}},
  {"family": "P3", "subtype": "P3.maintenance_window", "variant": "P3-maintenance-tune-01", "set": "tuning", "partnerId": "labpartner-a", "language": "pt",
   "description": "A maintenance window starts after the evidence was read.",
   "orders": [{"exams": ["HEMO"], "specimen": {"type": "whole_blood"}}],
   "script": {"health": {"status": "UP", "message": "operacional"},
              "attempts": [{"match": "afterEvent:MAINTENANCE_STARTS", "respond": {"status": 503, "body": "maintenance", "delay": "fast"}},
                           {"match": "any", "respond": {"status": 200, "receipt": true, "delay": "fast"}}],
              "afterEvent": {"MAINTENANCE_STARTS": {"health": {"status": "DOWN", "message": "janela de manutenção"},
                                                    "history": [{"outcome": "unavailable", "httpStatus": 503, "latencyMs": 30, "message": "maintenance-log"}]}},
              "triggers": [{"on": "read:health", "nth": 2, "event": "MAINTENANCE_STARTS"}]}},
  {"family": "P3", "subtype": "P3.cancelled_at_origin", "variant": "P3-cancelled-tune-01", "set": "tuning", "partnerId": "labpartner-a", "language": "en",
   "description": "The Order is cancelled at the Origin after the evidence was read.",
   "orders": [{"exams": ["HEMO"], "specimen": {"type": "whole_blood"}}],
   "script": {"health": {"status": "UP", "message": "all systems nominal"},
              "attempts": [{"match": "any", "respond": {"status": 200, "receipt": true, "delay": "fast"}}],
              "triggers": [{"on": "read:originStatus", "nth": 2, "event": "ORDER_CANCELLED_AT_ORIGIN", "orderOrdinal": 1}]}}
]
}

}
