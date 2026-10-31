Class SignalNoir.Application.Reference.Mappings.V2026101 Extends %RegisteredObject
{

/// Mapping Set 2026.10.1 (004 data-model): the items of contracts/fixtures/reference.mappings.json
/// plus the condition-field synonyms. A test asserts the items equal the contract fixture. A new
/// set is a new class. Loaded and checked by Application.Reference.Store.
Parameter VERSION = "2026.10.1";

XData Content [ MimeType = application/json ]
{
{
  "mappingVersion": "2026.10.1",
  "items": [
    { "mappingId": "map_glicj_plasma", "mappingVersion": "2026.10.1", "sourceCode": "GLIC-J", "targetCode": "GLIC-P", "conditions": { "specimenType": "PLASMA" } },
    { "mappingId": "map_glicj_soro", "mappingVersion": "2026.10.1", "sourceCode": "GLIC-J", "targetCode": "GLIC-S", "conditions": { "specimenType": "SERUM" } },
    { "mappingId": "map_hba1c_legacy", "mappingVersion": "2026.10.1", "sourceCode": "HBA1C-L", "targetCode": "HBA1C", "conditions": {} },
    { "mappingId": "map_tsh_legacy", "mappingVersion": "2026.10.1", "sourceCode": "TSH-OLD", "targetCode": "TSH", "conditions": {} }
  ],
  "synonyms": {
    "specimenType": { "PLASMA": ["PLASMA"], "SERUM": ["SERUM", "SORO"] }
  }
}
}

}
