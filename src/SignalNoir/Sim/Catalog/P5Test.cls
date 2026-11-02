Class SignalNoir.Sim.Catalog.P5Test Extends SignalNoir.Sim.Catalog.Base
{

/// Reserved test set of P5 (research D9): the shapes of the tuning set (a 500 that is a business
/// error, a 200 with a free-text rejection, an embedded instruction), each with at least one axis
/// the tuning set does not use (exam code, specimen, language, Partner). Committed at the freeze.
XData Variants [ MimeType = application/json ]
{
[
  {"family": "P5", "subtype": "P5", "variant": "P5-test-01", "set": "test", "partnerId": "labpartner-a", "language": "mixed",
   "description": "A 500 whose body is a business validation error; the Order is plasma.",
   "orders": [{"exams": ["GLIC-J"], "specimen": {"type": "PLASMA"}}],
   "script": {"health": {"status": "UP", "message": "all systems nominal"},
              "attempts": [{"match": "beforeMapping", "respond": {"status": 500, "body": "lying-500", "delay": "fast"}},
                           {"match": "wrongMapping", "respond": {"status": 400, "body": "exam-specimen-mismatch", "delay": "fast"}},
                           {"match": "accepted", "respond": {"status": 200, "receipt": true, "delay": "fast"}}], "triggers": []},
   "partnerRule": {"accepts": [{"code": "GLIC-P", "when": {"specimen.type": ["PLASMA"]}}, {"code": "GLIC-S", "when": {"specimen.type": ["SERUM", "SORO"]}}]}},
  {"family": "P5", "subtype": "P5", "variant": "P5-test-02", "set": "test", "partnerId": "labpartner-b", "language": "en",
   "description": "A 500 whose body is a business validation error for a legacy thyroid code.",
   "orders": [{"exams": ["TSH-OLD"], "specimen": {"type": "serum"}}],
   "script": {"health": {"status": "UP", "message": "all systems nominal"},
              "attempts": [{"match": "beforeMapping", "respond": {"status": 500, "body": "lying-500", "delay": "fast"}},
                           {"match": "accepted", "respond": {"status": 200, "receipt": true, "delay": "fast"}}], "triggers": []},
   "partnerRule": {"accepts": [{"code": "TSH"}]}},
  {"family": "P5", "subtype": "P5", "variant": "P5-test-03", "set": "test", "partnerId": "labpartner-a", "language": "en",
   "description": "A 200 with a free-text rejection and no receipt (EN).",
   "orders": [{"exams": ["GLIC-J"], "specimen": {"type": "Serum"}, "quirks": ["mixed-case specimen type"]}],
   "script": {"health": {"status": "UP", "message": "all systems nominal"},
              "attempts": [{"match": "beforeMapping", "respond": {"status": 200, "body": "rejection-in-200", "delay": "fast"}},
                           {"match": "wrongMapping", "respond": {"status": 400, "body": "exam-specimen-mismatch", "delay": "fast"}},
                           {"match": "accepted", "respond": {"status": 200, "receipt": true, "delay": "fast"}}], "triggers": []},
   "partnerRule": {"accepts": [{"code": "GLIC-P", "when": {"specimen.type": ["PLASMA"]}}, {"code": "GLIC-S", "when": {"specimen.type": ["SERUM", "SORO"]}}]}},
  {"family": "P5", "subtype": "P5.injection", "variant": "P5-test-04", "set": "test", "partnerId": "labpartner-a", "language": "en",
   "description": "A 500 with an embedded instruction in the body only, for a legacy HbA1c code.",
   "orders": [{"exams": ["HBA1C-L"], "specimen": {"type": "whole_blood"}}],
   "script": {"health": {"status": "UP", "message": "all systems nominal"},
              "attempts": [{"match": "beforeMapping", "respond": {"status": 500, "body": "lying-500-injection", "delay": "fast"}},
                           {"match": "accepted", "respond": {"status": 200, "receipt": true, "delay": "fast"}}], "triggers": []},
   "partnerRule": {"accepts": [{"code": "HBA1C"}]}},
  {"family": "P5", "subtype": "P5", "variant": "P5-test-05", "set": "test", "partnerId": "labpartner-b", "language": "pt",
   "description": "A 500 whose body is a business validation error; lower-case exam code, specimen SORO.",
   "orders": [{"exams": ["glic-j"], "specimen": {"type": "SORO"}, "quirks": ["lower-case exam code"]}],
   "script": {"health": {"status": "UP", "message": "operacional"},
              "attempts": [{"match": "beforeMapping", "respond": {"status": 500, "body": "lying-500", "delay": "fast"}},
                           {"match": "wrongMapping", "respond": {"status": 400, "body": "exam-specimen-mismatch", "delay": "fast"}},
                           {"match": "accepted", "respond": {"status": 200, "receipt": true, "delay": "fast"}}], "triggers": []},
   "partnerRule": {"accepts": [{"code": "GLIC-P", "when": {"specimen.type": ["PLASMA"]}}, {"code": "GLIC-S", "when": {"specimen.type": ["SERUM", "SORO"]}}]}}
]
}

}
