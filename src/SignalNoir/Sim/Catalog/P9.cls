Class SignalNoir.Sim.Catalog.P9 Extends SignalNoir.Sim.Catalog.Base
{

/// P9 data (SIM-Q8): the original Order was delivered under another
/// transaction and orderId about 3 minutes before the resend; only the
/// resend enters the feed.
XData Variants [ MimeType = application/json ]
{
[
  {"family": "P9", "subtype": "P9", "variant": "P9-tune-01", "set": "tuning", "partnerId": "labpartner-a", "language": "en",
   "description": "A resend of an Order whose original was already received.",
   "orders": [{"exams": ["GLIC-S"], "specimen": {"type": "serum"}},
              {"priorOf": 1, "receivedAtOffsetSeconds": -180}],
   "script": {"health": {"status": "UP", "message": "all systems nominal"},
              "attempts": [{"match": "any", "respond": {"status": 200, "receipt": true, "delay": "fast"}}], "triggers": []}}
]
}

}
