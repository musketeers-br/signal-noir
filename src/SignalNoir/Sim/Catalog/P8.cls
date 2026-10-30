Class SignalNoir.Sim.Catalog.P8 Extends SignalNoir.Sim.Catalog.Base
{

/// P8a: health says UP while every call times out. P8b: two approved
/// mappings for one discontinued code, told apart only by specimen type.
XData Variants [ MimeType = application/json ]
{
[
  {"family": "P8", "subtype": "P8a", "variant": "P8a-tune-01", "set": "tuning", "partnerId": "labpartner-c", "language": "en",
   "description": "Health is UP; every delivery times out.",
   "orders": [{"exams": ["HEMO"], "specimen": {"type": "whole_blood"}}],
   "script": {"health": {"status": "UP", "message": "all systems nominal"},
              "attempts": [{"match": "any", "respond": {"status": "none", "delay": "timeout"}}], "triggers": []}},
  {"family": "P8", "subtype": "P8b", "variant": "P8b-tune-01", "set": "tuning", "partnerId": "labpartner-a", "language": "mixed",
   "description": "Discontinued glucose code; the Order is plasma.",
   "orders": [{"exams": ["GLIC-J"], "specimen": {"type": "plasma"}, "quirks": ["lower-case specimen type"]}],
   "script": {"health": {"status": "UP", "message": "all systems nominal"},
              "attempts": [{"match": "beforeMapping", "respond": {"status": 400, "body": "discontinued-code", "delay": "fast"}},
                           {"match": "wrongMapping", "respond": {"status": 400, "body": "exam-specimen-mismatch", "delay": "fast"}},
                           {"match": "accepted", "respond": {"status": 200, "receipt": true, "delay": "fast"}}], "triggers": []},
   "partnerRule": {"accepts": [{"code": "GLIC-P", "when": {"specimen.type": ["PLASMA"]}}, {"code": "GLIC-S", "when": {"specimen.type": ["SERUM", "SORO"]}}]}},
  {"family": "P8", "subtype": "P8b", "variant": "P8b-tune-02", "set": "tuning", "partnerId": "labpartner-a", "language": "pt",
   "description": "Discontinued glucose code; the Order is serum (soro).",
   "orders": [{"exams": ["GLIC-J"], "specimen": {"type": "soro"}}],
   "script": {"health": {"status": "UP", "message": "operacional"},
              "attempts": [{"match": "beforeMapping", "respond": {"status": 500, "body": "discontinued-code", "delay": "fast"}},
                           {"match": "wrongMapping", "respond": {"status": 400, "body": "exam-specimen-mismatch", "delay": "fast"}},
                           {"match": "accepted", "respond": {"status": 200, "receipt": true, "delay": "fast"}}], "triggers": []},
   "partnerRule": {"accepts": [{"code": "GLIC-P", "when": {"specimen.type": ["PLASMA"]}}, {"code": "GLIC-S", "when": {"specimen.type": ["SERUM", "SORO"]}}]}}
]
}

}
