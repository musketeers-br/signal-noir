Class SignalNoir.Sim.Catalog.P1 Extends SignalNoir.Sim.Catalog.Base
{

/// P1: the first attempt times out, the second reveals a semantic cause
XData Variants [ MimeType = application/json ]
{
[
  {"family": "P1", "subtype": "P1", "variant": "P1-tune-01", "set": "tuning", "partnerId": "labpartner-a", "language": "pt",
   "description": "No answer on the first attempt; a semantic validation error on the second.",
   "orders": [{"exams": ["GLIC-J"], "specimen": {"type": "soro"}}],
   "script": {"health": {"status": "UP", "message": "operacional"},
              "attempts": [{"match": "attempt:1", "respond": {"status": "none", "delay": "timeout"}},
                           {"match": "attempt:2+", "respond": {"status": 500, "body": "semantic-validation", "delay": "fast"}}], "triggers": []}}
]
}

}
