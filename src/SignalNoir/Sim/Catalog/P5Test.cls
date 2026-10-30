Class SignalNoir.Sim.Catalog.P5Test Extends SignalNoir.Sim.Catalog.Base
{

/// Reserved test set (research D9): shape only. The real reserved variants
/// are committed at the freeze by the holder of the reserved cases.
XData Variants [ MimeType = application/json ]
{
[
  {"family": "P5", "subtype": "P5", "variant": "P5-test-00", "set": "test", "partnerId": "labpartner-a", "language": "en",
   "description": "Placeholder of the reserved set (shape only).",
   "orders": [{"exams": ["HEMO"], "specimen": {"type": "whole_blood"}}],
   "script": {"health": {"status": "UP", "message": "all systems nominal"},
              "attempts": [{"match": "any", "respond": {"status": 200, "receipt": true, "delay": "fast"}}], "triggers": []}}
]
}

}
