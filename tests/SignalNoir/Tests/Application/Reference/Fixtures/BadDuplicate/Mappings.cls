Class SignalNoir.Tests.Application.Reference.Fixtures.BadDuplicate.Mappings Extends %RegisteredObject
{

/// Test-only malformed Mapping Set: the same mappingId twice in one version.
Parameter VERSION = "2026.10.3";

XData Content [ MimeType = application/json ]
{
{
  "mappingVersion": "2026.10.3",
  "items": [
    { "mappingId": "map_dup", "mappingVersion": "2026.10.3", "sourceCode": "GLIC-J", "targetCode": "GLIC-P", "conditions": {} },
    { "mappingId": "map_dup", "mappingVersion": "2026.10.3", "sourceCode": "TSH-OLD", "targetCode": "TSH", "conditions": {} }
  ],
  "synonyms": {}
}
}

}
