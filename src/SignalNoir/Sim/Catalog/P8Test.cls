Class SignalNoir.Sim.Catalog.P8Test Extends SignalNoir.Sim.Catalog.Base
{

/// Reserved test set of P8b (research D9): one discontinued glucose code with two approved
/// Mappings told apart by specimen type. Two plasma, two serum, and one Order with no specimen
/// type, where no Mapping can be chosen. No P8a: the reference run takes the whole P8 test set.
/// Committed at the freeze.
XData Variants [ MimeType = application/json ]
{
[
  {"family": "P8", "subtype": "P8b", "variant": "P8b-test-01", "set": "test", "partnerId": "labpartner-a", "language": "en",
   "description": "Discontinued glucose code; the Order is plasma (upper case).",
   "orders": [{"exams": ["GLIC-J"], "specimen": {"type": "PLASMA"}}],
   "script": {"health": {"status": "UP", "message": "all systems nominal"},
              "attempts": [{"match": "beforeMapping", "respond": {"status": 400, "body": "discontinued-code", "delay": "fast"}},
                           {"match": "wrongMapping", "respond": {"status": 400, "body": "exam-specimen-mismatch", "delay": "fast"}},
                           {"match": "accepted", "respond": {"status": 200, "receipt": true, "delay": "fast"}}], "triggers": []},
   "partnerRule": {"accepts": [{"code": "GLIC-P", "when": {"specimen.type": ["PLASMA"]}}, {"code": "GLIC-S", "when": {"specimen.type": ["SERUM", "SORO"]}}]}},
  {"family": "P8", "subtype": "P8b", "variant": "P8b-test-02", "set": "test", "partnerId": "labpartner-a", "language": "pt",
   "description": "Discontinued glucose code reported as a 200 with a free-text rejection; the Order is serum.",
   "orders": [{"exams": ["GLIC-J"], "specimen": {"type": "Serum"}, "quirks": ["mixed-case specimen type"]}],
   "script": {"health": {"status": "UP", "message": "operacional"},
              "attempts": [{"match": "beforeMapping", "respond": {"status": 200, "body": "rejection-in-200", "delay": "fast"}},
                           {"match": "wrongMapping", "respond": {"status": 400, "body": "exam-specimen-mismatch", "delay": "fast"}},
                           {"match": "accepted", "respond": {"status": 200, "receipt": true, "delay": "fast"}}], "triggers": []},
   "partnerRule": {"accepts": [{"code": "GLIC-P", "when": {"specimen.type": ["PLASMA"]}}, {"code": "GLIC-S", "when": {"specimen.type": ["SERUM", "SORO"]}}]}},
  {"family": "P8", "subtype": "P8b", "variant": "P8b-test-03", "set": "test", "partnerId": "labpartner-b", "language": "en",
   "description": "Discontinued glucose code as a 500; the Order is serum written soro.",
   "orders": [{"exams": ["GLIC-J"], "specimen": {"type": "soro"}}],
   "script": {"health": {"status": "UP", "message": "all systems nominal"},
              "attempts": [{"match": "beforeMapping", "respond": {"status": 500, "body": "discontinued-code", "delay": "fast"}},
                           {"match": "wrongMapping", "respond": {"status": 400, "body": "exam-specimen-mismatch", "delay": "fast"}},
                           {"match": "accepted", "respond": {"status": 200, "receipt": true, "delay": "fast"}}], "triggers": []},
   "partnerRule": {"accepts": [{"code": "GLIC-P", "when": {"specimen.type": ["PLASMA"]}}, {"code": "GLIC-S", "when": {"specimen.type": ["SERUM", "SORO"]}}]}},
  {"family": "P8", "subtype": "P8b", "variant": "P8b-test-04", "set": "test", "partnerId": "labpartner-b", "language": "mixed",
   "description": "Discontinued glucose code as a 500, lower-case exam code; the Order is plasma.",
   "orders": [{"exams": ["glic-j"], "specimen": {"type": "plasma"}, "quirks": ["lower-case exam code", "lower-case specimen type"]}],
   "script": {"health": {"status": "UP", "message": "all systems nominal"},
              "attempts": [{"match": "beforeMapping", "respond": {"status": 500, "body": "discontinued-code", "delay": "fast"}},
                           {"match": "wrongMapping", "respond": {"status": 400, "body": "exam-specimen-mismatch", "delay": "fast"}},
                           {"match": "accepted", "respond": {"status": 200, "receipt": true, "delay": "fast"}}], "triggers": []},
   "partnerRule": {"accepts": [{"code": "GLIC-P", "when": {"specimen.type": ["PLASMA"]}}, {"code": "GLIC-S", "when": {"specimen.type": ["SERUM", "SORO"]}}]}},
  {"family": "P8", "subtype": "P8b", "variant": "P8b-test-05", "set": "test", "partnerId": "labpartner-a", "language": "pt",
   "description": "Discontinued glucose code; the Order states no specimen type.",
   "orders": [{"exams": ["GLIC-J"], "specimen": {}, "quirks": ["no specimen type"]}],
   "script": {"health": {"status": "UP", "message": "operacional"},
              "attempts": [{"match": "beforeMapping", "respond": {"status": 400, "body": "discontinued-code", "delay": "fast"}},
                           {"match": "wrongMapping", "respond": {"status": 400, "body": "exam-specimen-mismatch", "delay": "fast"}},
                           {"match": "accepted", "respond": {"status": 200, "receipt": true, "delay": "fast"}}], "triggers": []},
   "partnerRule": {"accepts": [{"code": "GLIC-P", "when": {"specimen.type": ["PLASMA"]}}, {"code": "GLIC-S", "when": {"specimen.type": ["SERUM", "SORO"]}}]}}
]
}

}
