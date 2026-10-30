Class SignalNoir.Tests.Application.Reference.Fixtures.Good.MappingsB Extends %RegisteredObject
{

/// Test-only Mapping Set, version B: 2026.10.1 without map_glicj_soro, so a Proposal for that
/// Mapping is valid under one version and not under the other.
Parameter VERSION = "2026.10.2";

XData Content [ MimeType = application/json ]
{
{
  "mappingVersion": "2026.10.2",
  "items": [
    { "mappingId": "map_glicj_plasma", "mappingVersion": "2026.10.2", "sourceCode": "GLIC-J", "targetCode": "GLIC-P", "conditions": { "specimenType": "PLASMA" } },
    { "mappingId": "map_hba1c_legacy", "mappingVersion": "2026.10.2", "sourceCode": "HBA1C-L", "targetCode": "HBA1C", "conditions": {} },
    { "mappingId": "map_tsh_legacy", "mappingVersion": "2026.10.2", "sourceCode": "TSH-OLD", "targetCode": "TSH", "conditions": {} }
  ],
  "synonyms": {
    "specimenType": { "PLASMA": ["PLASMA"], "SERUM": ["SERUM", "SORO"] }
  }
}
}

}
