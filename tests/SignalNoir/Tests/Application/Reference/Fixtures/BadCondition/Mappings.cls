Class SignalNoir.Tests.Application.Reference.Fixtures.BadCondition.Mappings Extends %RegisteredObject
{

/// Test-only malformed Mapping Set: a condition on a field the Order contract does not define.
Parameter VERSION = "2026.10.3";

XData Content [ MimeType = application/json ]
{
{
  "mappingVersion": "2026.10.3",
  "items": [
    { "mappingId": "map_bad", "mappingVersion": "2026.10.3", "sourceCode": "GLIC-J", "targetCode": "GLIC-P", "conditions": { "colour": "RED" } }
  ],
  "synonyms": {}
}
}

}
