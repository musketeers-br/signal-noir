Class SignalNoir.Benchmark.Data.Freeze Extends SignalNoir.Benchmark.Data.Base
{

/// The freeze record: the prompt, model, baseline, policies, fixtures and evaluator fixed before
/// the reserved test runs (feature 010, FR-026). One record, written in one commit (T056) by
/// the holder of the reserved cases. A placeholder (freezeId empty) means nothing is frozen yet,
/// and a reference run is then development data. `files` lists the git blob id of each frozen
/// source file, which scripts/benchmark/check-freeze.sh compares in CI.
XData Record [ MimeType = application/json ]
{
{
  "freezeId": "freeze-2026-11-02",
  "commit": "dfd2b0d987c1f6b0fe9e704d02288c4aeaee2405",
  "frozenAt": "2026-11-02T20:33:28Z",
  "promptVersion": "agent-v5",
  "model": "gpt-4o-mini",
  "baselineVersion": "rules-v2",
  "policyVersion": "2026.10.1",
  "mappingVersion": "2026.10.1",
  "policyDigest": "f09e13ec7568ae1d431ba3955c6491283453ade646c24bca2937f67c19de7c73",
  "mappingDigest": "84c8c1d5b5d5c12f638971c019ab0bbb0aaccbf13b5adc84a60f6c57d9283920",
  "evaluatorVersion": "scorer-v1",
  "reservedCatalogDigest": "3b322ef7ee06403c7facaf4637a3dbcf475448f201455c7f299305828d3ab5a4",
  "answerKeyDigest": "0c2868a7a68f4fc7185263cb90b7db259c22557cf97654b06ea208215e1dd209",
  "files": [
    {"path": "src/SignalNoir/Proposers/Agent.cls", "blob": "30dabad3f3194b632e25539562c49ff30c2cc10f"},
    {"path": "src/SignalNoir/Proposers/Rules.cls", "blob": "16c80f82bbb8942548f28ec4f0c03b1488e9b29e"},
    {"path": "src/SignalNoir/Core/DecisionFacts.cls", "blob": "ecfad3b1779ff0a6b85b4e2dda0c91fe82b919f3"},
    {"path": "src/SignalNoir/Core/MappingMatch.cls", "blob": "044198e78f68a5a10017abe1f63c0c5882fe7cbb"},
    {"path": "src/SignalNoir/Core/Conditions.cls", "blob": "9fa43e7e5a60e05435838f906fd8e58001ef212a"},
    {"path": "src/SignalNoir/Core/Identity.cls", "blob": "34879a7531de4e0bdd6cb28384843744f5457e73"},
    {"path": "src/SignalNoir/Core/Benchmark/Scorer.cls", "blob": "e096303a7841764c2877fe01416e5e4caf7d5d34"},
    {"path": "src/SignalNoir/Core/Benchmark/Stats.cls", "blob": "fa2bb7ea3e41011774ff0fb6319702d079fed54f"},
    {"path": "src/SignalNoir/Application/Benchmark/CaseFacts.cls", "blob": "2c5bcd390b9d56936a6855b141339ed11a6f3f5f"},
    {"path": "src/SignalNoir/Application/Reference/Policies/V2026101.cls", "blob": "b6a3ae8294dc6ec5a89f58a3c7a1a1de65ac5104"},
    {"path": "src/SignalNoir/Application/Reference/Mappings/V2026101.cls", "blob": "9bf7db885f9da09036465a66aef0521f7a295821"},
    {"path": "src/SignalNoir/Sim/Catalog/P5Test.cls", "blob": "6fb767296b02e0f7861859bf93c286609db80e85"},
    {"path": "src/SignalNoir/Sim/Catalog/P8Test.cls", "blob": "b7e0548a2a3ea10c5af7d154e1afb3beb3bfdb27"},
    {"path": "src/SignalNoir/Sim/Catalog/CleanTest.cls", "blob": "31a2e78f6201cea39476d794edb65d984f6dd3fa"},
    {"path": "src/SignalNoir/Sim/Catalog/Wording.cls", "blob": "c0e6c743db8fcbb475825292ff1cc8bee2747487"},
    {"path": "src/SignalNoir/Benchmark/Data/AnswerKeyTest.cls", "blob": "7bd8b3ea816acef2d7639130fde99fc1ce406dbc"}
  ]
}
}

}
