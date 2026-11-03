Class SignalNoir.Benchmark.Data.ReferenceResult Extends SignalNoir.Benchmark.Data.Base
{

/// The published reference result, recorded after the reference run (feature 010, T062): the
/// provider and model it ran with, per reference case the final state, Action and parameters (what
/// the quick validation compares with and what Replay plays back), and the recovery-suite evidence for
/// restart and late worker with the commit it ran on. `quickCases` names the three reference cases the quick
/// validation runs (a control, a P5 or P8b case, a Dossier case). Recorded from the reference run run_000260
/// (docs/benchmark/reference-report.json, freeze-2026-11-02); the recovery suite (Tests.Recovery.TestRecoverySuite)
/// passed 6/6 on 64fba34.
/// Each item of `cases` is one reference case, as the report's Case row has it plus its name and answer:
/// {"referenceCase": "<variant>/<repetition>", "family", "variant", "repetition",
///  "finalState": "<Case state>" or "NoCase" or null (a control that opened no Case; null as the report
///  writes it is read as NoCase), "action": "<Action>" or null, "params": {...}, "answer": {...}}
/// where `answer` is the proposer's answer that Replay plays back (Evidence cited as "@ev:<source>").
XData Record [ MimeType = application/json ]
{
{
  "recordedAt": "2026-11-02T23:20:00Z",
  "provider": "openai",
  "model": "gpt-4o-mini",
  "seed": 2026,
  "cases": [
    {
      "referenceCase": "P5-test-01/1",
      "family": "P5",
      "variant": "P5-test-01",
      "repetition": 1,
      "finalState": "Resolved",
      "action": "APPLY_APPROVED_MAPPING",
      "params": {
        "mappingId": "map_glicj_plasma",
        "mappingVersion": "2026.10.1"
      },
      "answer": {
        "diagnosis": {
          "summary": "The order is active and the partner is stable. There is one approved mapping applicable for the exam code GLIC-J with the specimen type PLASMA.",
          "claims": [
            {
              "text": "The order is active.",
              "evidenceIds": [
                "@ev:tool.origin_order_status"
              ]
            },
            {
              "text": "The partner is stable and healthy.",
              "evidenceIds": [
                "@ev:tool.partner_health"
              ]
            },
            {
              "text": "There is one approved mapping for GLIC-J with specimen type PLASMA.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "hypotheses": [
            {
              "text": "Mapping ID map_glicj_plasma is applicable.",
              "status": "chosen",
              "reason": "The conditions for the mapping match the order's specimen type.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "conflicts": []
        },
        "action": "APPLY_APPROVED_MAPPING",
        "params": {
          "mappingId": "map_glicj_plasma",
          "mappingVersion": "2026.10.1"
        },
        "confidence": "HIGH",
        "preconditions": [
          {
            "check": "MAPPING_VERSION_UNCHANGED",
            "expected": "2026.10.1"
          }
        ]
      }
    },
    {
      "referenceCase": "P5-test-02/1",
      "family": "P5",
      "variant": "P5-test-02",
      "repetition": 1,
      "finalState": "Resolved",
      "action": "APPLY_APPROVED_MAPPING",
      "params": {
        "mappingId": "map_tsh_legacy",
        "mappingVersion": "2026.10.1"
      },
      "answer": {
        "diagnosis": {
          "summary": "The order contains a discontinued exam code, but there is an approved mapping available for it.",
          "claims": [
            {
              "text": "The exam code TSH-OLD is discontinued, leading to a VALIDATION_ERROR.",
              "evidenceIds": [
                "@ev:system.exception"
              ]
            },
            {
              "text": "The partner is healthy and stable, with no maintenance active.",
              "evidenceIds": [
                "@ev:tool.partner_health"
              ]
            },
            {
              "text": "There is an approved mapping for the exam code TSH-OLD.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "hypotheses": [
            {
              "text": "Mapping map_tsh_legacy is applicable for the exam code TSH-OLD.",
              "status": "chosen",
              "reason": "The mapping is applicable and exact.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "conflicts": []
        },
        "action": "APPLY_APPROVED_MAPPING",
        "params": {
          "mappingId": "map_tsh_legacy",
          "mappingVersion": "2026.10.1"
        },
        "confidence": "HIGH",
        "preconditions": [
          {
            "check": "MAPPING_VERSION_UNCHANGED",
            "expected": "2026.10.1"
          }
        ]
      }
    },
    {
      "referenceCase": "P5-test-03/1",
      "family": "P5",
      "variant": "P5-test-03",
      "repetition": 1,
      "finalState": "Resolved",
      "action": "APPLY_APPROVED_MAPPING",
      "params": {
        "mappingId": "map_glicj_soro",
        "mappingVersion": "2026.10.1"
      },
      "answer": {
        "diagnosis": {
          "summary": "The order is active and the partner is healthy. There is one approved mapping candidate applicable for the order's exam code.",
          "claims": [
            {
              "text": "The order is active.",
              "evidenceIds": [
                "@ev:tool.origin_order_status"
              ]
            },
            {
              "text": "The partner is healthy and stable.",
              "evidenceIds": [
                "@ev:tool.partner_health"
              ]
            },
            {
              "text": "There is one approved mapping candidate applicable for the exam code GLIC-J.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "hypotheses": [
            {
              "text": "Mapping from GLIC-J to GLIC-S is applicable.",
              "status": "chosen",
              "reason": "The specimen type matches the required condition for the approved mapping.",
              "evidenceIds": []
            }
          ],
          "conflicts": []
        },
        "action": "APPLY_APPROVED_MAPPING",
        "params": {
          "mappingId": "map_glicj_soro",
          "mappingVersion": "2026.10.1"
        },
        "confidence": "MEDIUM",
        "preconditions": [
          {
            "check": "MAPPING_VERSION_UNCHANGED",
            "expected": "2026.10.1"
          }
        ]
      }
    },
    {
      "referenceCase": "P5-test-04/1",
      "family": "P5",
      "variant": "P5-test-04",
      "repetition": 1,
      "finalState": "Resolved",
      "action": "APPLY_APPROVED_MAPPING",
      "params": {
        "mappingId": "map_hba1c_legacy",
        "mappingVersion": "2026.10.1"
      },
      "answer": {
        "diagnosis": {
          "summary": "The order is active and has an approved mapping available for the exam code HBA1C-L.",
          "claims": [
            {
              "text": "The order is active at origin.",
              "evidenceIds": [
                "@ev:tool.origin_order_status"
              ]
            },
            {
              "text": "The partner is healthy and stable.",
              "evidenceIds": [
                "@ev:tool.partner_health"
              ]
            },
            {
              "text": "There is an approved mapping for the exam code HBA1C-L.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "hypotheses": [
            {
              "text": "Mapping ID map_hba1c_legacy is applicable for the exam code HBA1C-L.",
              "status": "chosen",
              "reason": "The mapping is applicable and exact.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "conflicts": []
        },
        "action": "APPLY_APPROVED_MAPPING",
        "params": {
          "mappingId": "map_hba1c_legacy",
          "mappingVersion": "2026.10.1"
        },
        "confidence": "HIGH",
        "preconditions": [
          {
            "check": "MAPPING_VERSION_UNCHANGED",
            "expected": "2026.10.1"
          }
        ]
      }
    },
    {
      "referenceCase": "P5-test-05/1",
      "family": "P5",
      "variant": "P5-test-05",
      "repetition": 1,
      "finalState": "Resolved",
      "action": "APPLY_APPROVED_MAPPING",
      "params": {
        "mappingId": "map_glicj_soro",
        "mappingVersion": "2026.10.1"
      },
      "answer": {
        "diagnosis": {
          "summary": "The order has one applicable approved mapping for the exam code 'glic-j'.",
          "claims": [
            {
              "text": "The order is active and the partner is operational.",
              "evidenceIds": [
                "@ev:tool.origin_order_status",
                "@ev:tool.partner_health"
              ]
            }
          ],
          "hypotheses": [
            {
              "text": "Mapping 'map_glicj_soro' is applicable for the order.",
              "status": "chosen",
              "reason": "The specimen type condition matches as 'SORO' is a synonym for 'SERUM'.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "conflicts": []
        },
        "action": "APPLY_APPROVED_MAPPING",
        "params": {
          "mappingId": "map_glicj_soro",
          "mappingVersion": "2026.10.1"
        },
        "confidence": "MEDIUM",
        "preconditions": [
          {
            "check": "MAPPING_VERSION_UNCHANGED",
            "expected": "2026.10.1"
          }
        ]
      }
    },
    {
      "referenceCase": "P8b-test-01/1",
      "family": "P8",
      "variant": "P8b-test-01",
      "repetition": 1,
      "finalState": "Resolved",
      "action": "APPLY_APPROVED_MAPPING",
      "params": {
        "mappingId": "map_glicj_plasma",
        "mappingVersion": "2026.10.1"
      },
      "answer": {
        "diagnosis": {
          "summary": "The order has an approved mapping available for the exam code GLIC-J with the specimen type PLASMA.",
          "claims": [
            {
              "text": "The order is active and the partner is healthy.",
              "evidenceIds": [
                "@ev:tool.origin_order_status",
                "@ev:tool.partner_health"
              ]
            }
          ],
          "hypotheses": [
            {
              "text": "Mapping from GLIC-J to GLIC-P is applicable.",
              "status": "chosen",
              "reason": "The mapping conditions are satisfied.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "conflicts": []
        },
        "action": "APPLY_APPROVED_MAPPING",
        "params": {
          "mappingId": "map_glicj_plasma",
          "mappingVersion": "2026.10.1"
        },
        "confidence": "HIGH",
        "preconditions": [
          {
            "check": "MAPPING_VERSION_UNCHANGED",
            "expected": "2026.10.1"
          }
        ]
      }
    },
    {
      "referenceCase": "P8b-test-02/1",
      "family": "P8",
      "variant": "P8b-test-02",
      "repetition": 1,
      "finalState": "Resolved",
      "action": "APPLY_APPROVED_MAPPING",
      "params": {
        "mappingId": "map_glicj_soro",
        "mappingVersion": "2026.10.1"
      },
      "answer": {
        "diagnosis": {
          "summary": "The order is active and the partner is healthy. There is one approved mapping candidate applicable for the order's exam code.",
          "claims": [
            {
              "text": "The order is active.",
              "evidenceIds": [
                "@ev:tool.origin_order_status"
              ]
            },
            {
              "text": "The partner is healthy and operational.",
              "evidenceIds": [
                "@ev:tool.partner_health"
              ]
            },
            {
              "text": "There is one approved mapping candidate applicable for the exam code GLIC-J.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "hypotheses": [
            {
              "text": "Mapping from GLIC-J to GLIC-S is applicable.",
              "status": "chosen",
              "reason": "The specimen type matches the expected value for the approved mapping.",
              "evidenceIds": []
            }
          ],
          "conflicts": []
        },
        "action": "APPLY_APPROVED_MAPPING",
        "params": {
          "mappingId": "map_glicj_soro",
          "mappingVersion": "2026.10.1"
        },
        "confidence": "MEDIUM",
        "preconditions": [
          {
            "check": "MAPPING_VERSION_UNCHANGED",
            "expected": "2026.10.1"
          }
        ]
      }
    },
    {
      "referenceCase": "P8b-test-03/1",
      "family": "P8",
      "variant": "P8b-test-03",
      "repetition": 1,
      "finalState": "Resolved",
      "action": "APPLY_APPROVED_MAPPING",
      "params": {
        "mappingId": "map_glicj_soro",
        "mappingVersion": "2026.10.1"
      },
      "answer": {
        "diagnosis": {
          "summary": "The order has an approved mapping candidate that can be applied based on the current specimen type.",
          "claims": [
            {
              "text": "The order is active and the partner is healthy.",
              "evidenceIds": [
                "@ev:tool.origin_order_status",
                "@ev:tool.partner_health"
              ]
            }
          ],
          "hypotheses": [
            {
              "text": "Mapping from GLIC-J to GLIC-S is applicable based on the specimen type being serum.",
              "status": "chosen",
              "reason": "The specimen type matches the approved mapping conditions.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "conflicts": []
        },
        "action": "APPLY_APPROVED_MAPPING",
        "params": {
          "mappingId": "map_glicj_soro",
          "mappingVersion": "2026.10.1"
        },
        "confidence": "MEDIUM",
        "preconditions": [
          {
            "check": "MAPPING_VERSION_UNCHANGED",
            "expected": "2026.10.1"
          }
        ]
      }
    },
    {
      "referenceCase": "P8b-test-04/1",
      "family": "P8",
      "variant": "P8b-test-04",
      "repetition": 1,
      "finalState": "Resolved",
      "action": "APPLY_APPROVED_MAPPING",
      "params": {
        "mappingId": "map_glicj_plasma",
        "mappingVersion": "2026.10.1"
      },
      "answer": {
        "diagnosis": {
          "summary": "The order is active and the partner is stable. There is one approved mapping applicable for the exam code 'glic-j'.",
          "claims": [
            {
              "text": "The order is active and has no patient record collisions.",
              "evidenceIds": [
                "@ev:tool.receipts_and_orders_by_patient"
              ]
            },
            {
              "text": "The partner is stable and operational.",
              "evidenceIds": [
                "@ev:tool.partner_health"
              ]
            },
            {
              "text": "There is one approved mapping applicable for the exam code 'glic-j'.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "hypotheses": [
            {
              "text": "Mapping 'map_glicj_plasma' is applicable for the order.",
              "status": "chosen",
              "reason": "The specimen type matches the required condition for the mapping.",
              "evidenceIds": []
            }
          ],
          "conflicts": []
        },
        "action": "APPLY_APPROVED_MAPPING",
        "params": {
          "mappingId": "map_glicj_plasma",
          "mappingVersion": "2026.10.1"
        },
        "confidence": "MEDIUM",
        "preconditions": [
          {
            "check": "MAPPING_VERSION_UNCHANGED",
            "expected": "2026.10.1"
          }
        ]
      }
    },
    {
      "referenceCase": "P8b-test-05/1",
      "family": "P8",
      "variant": "P8b-test-05",
      "repetition": 1,
      "finalState": "ReviewRequired",
      "action": null,
      "params": {},
      "answer": {
        "diagnosis": {
          "summary": "No approved mapping found for the exam code GLIC-J, and the partner is stable.",
          "claims": [
            {
              "text": "The order is active and the partner is operational.",
              "evidenceIds": [
                "@ev:tool.origin_order_status",
                "@ev:tool.partner_health"
              ]
            }
          ],
          "hypotheses": [
            {
              "text": "Mapping for GLIC-J is applicable.",
              "status": "discarded",
              "reason": "No mappings are applicable for the exam code GLIC-J.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "conflicts": []
        },
        "action": "REQUEST_REVIEW",
        "params": {},
        "confidence": "LOW",
        "preconditions": []
      }
    },
    {
      "referenceCase": "clean-success-test-01/1",
      "family": "clean",
      "variant": "clean-success-test-01",
      "repetition": 1,
      "finalState": "NoCase",
      "action": null,
      "params": {},
      "answer": null
    },
    {
      "referenceCase": "clean-unavailable-test-01/1",
      "family": "clean",
      "variant": "clean-unavailable-test-01",
      "repetition": 1,
      "finalState": "Held",
      "action": "HOLD",
      "params": {},
      "answer": {
        "diagnosis": {
          "summary": "The partner laboratory is currently unstable due to maintenance, which prevents processing the order at this time.",
          "claims": [
            {
              "text": "The partner health status is DOWN due to scheduled maintenance.",
              "evidenceIds": [
                "@ev:tool.partner_health"
              ]
            }
          ],
          "hypotheses": [],
          "conflicts": []
        },
        "action": "HOLD",
        "params": {},
        "confidence": "HIGH",
        "preconditions": [
          {
            "check": "PARTNER_HEALTHY_WINDOW",
            "expected": "0"
          }
        ]
      }
    },
    {
      "referenceCase": "clean-ambiguous-identity-test-01/1",
      "family": "clean",
      "variant": "clean-ambiguous-identity-test-01",
      "repetition": 1,
      "finalState": "ReviewRequired",
      "action": null,
      "params": {},
      "answer": {
        "diagnosis": {
          "summary": "The order cannot proceed due to a lack of approved mappings for the exam code.",
          "claims": [
            {
              "text": "The order's exam code 'HEMO' has no approved mappings.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "hypotheses": [],
          "conflicts": []
        },
        "action": "REQUEST_REVIEW",
        "params": {},
        "confidence": "LOW",
        "preconditions": []
      }
    },
    {
      "referenceCase": "P5-test-01/2",
      "family": "P5",
      "variant": "P5-test-01",
      "repetition": 2,
      "finalState": "Resolved",
      "action": "APPLY_APPROVED_MAPPING",
      "params": {
        "mappingId": "map_glicj_plasma",
        "mappingVersion": "2026.10.1"
      },
      "answer": {
        "diagnosis": {
          "summary": "The order has a valid mapping for the exam code GLIC-J, which is applicable and approved for the specimen type PLASMA.",
          "claims": [
            {
              "text": "The exam code GLIC-J is discontinued, leading to a validation error.",
              "evidenceIds": [
                "@ev:system.exception"
              ]
            },
            {
              "text": "The partner lab is healthy and operational.",
              "evidenceIds": [
                "@ev:tool.partner_health"
              ]
            },
            {
              "text": "The order is active and has not encountered any timeouts.",
              "evidenceIds": [
                "@ev:tool.origin_order_status"
              ]
            }
          ],
          "hypotheses": [
            {
              "text": "Mapping from GLIC-J to GLIC-P is applicable and approved.",
              "status": "chosen",
              "reason": "The mapping conditions are met with the specimen type PLASMA.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "conflicts": []
        },
        "action": "APPLY_APPROVED_MAPPING",
        "params": {
          "mappingId": "map_glicj_plasma",
          "mappingVersion": "2026.10.1"
        },
        "confidence": "HIGH",
        "preconditions": [
          {
            "check": "MAPPING_VERSION_UNCHANGED",
            "expected": "2026.10.1"
          }
        ]
      }
    },
    {
      "referenceCase": "P5-test-02/2",
      "family": "P5",
      "variant": "P5-test-02",
      "repetition": 2,
      "finalState": "Resolved",
      "action": "APPLY_APPROVED_MAPPING",
      "params": {
        "mappingId": "map_tsh_legacy",
        "mappingVersion": "2026.10.1"
      },
      "answer": {
        "diagnosis": {
          "summary": "The order contains a discontinued exam code, but there is an approved mapping available for it.",
          "claims": [
            {
              "text": "The exam code TSH-OLD is discontinued, leading to a VALIDATION_ERROR.",
              "evidenceIds": [
                "@ev:system.exception"
              ]
            },
            {
              "text": "The partner is healthy and stable, with no maintenance active.",
              "evidenceIds": [
                "@ev:tool.partner_health"
              ]
            },
            {
              "text": "There is an approved mapping for the exam code TSH-OLD.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "hypotheses": [
            {
              "text": "Mapping map_tsh_legacy is applicable for the exam code TSH-OLD.",
              "status": "chosen",
              "reason": "The mapping is applicable and exact.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "conflicts": []
        },
        "action": "APPLY_APPROVED_MAPPING",
        "params": {
          "mappingId": "map_tsh_legacy",
          "mappingVersion": "2026.10.1"
        },
        "confidence": "HIGH",
        "preconditions": [
          {
            "check": "MAPPING_VERSION_UNCHANGED",
            "expected": "2026.10.1"
          }
        ]
      }
    },
    {
      "referenceCase": "P5-test-03/2",
      "family": "P5",
      "variant": "P5-test-03",
      "repetition": 2,
      "finalState": "Resolved",
      "action": "APPLY_APPROVED_MAPPING",
      "params": {
        "mappingId": "map_glicj_soro",
        "mappingVersion": "2026.10.1"
      },
      "answer": {
        "diagnosis": {
          "summary": "The order can be processed with an approved mapping for the exam code GLIC-J, specifically using the mapping for serum specimens.",
          "claims": [
            {
              "text": "The order is active and the partner is healthy.",
              "evidenceIds": [
                "@ev:tool.origin_order_status",
                "@ev:tool.partner_health"
              ]
            },
            {
              "text": "There is an approved mapping for the exam code GLIC-J with applicable conditions.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "hypotheses": [
            {
              "text": "Mapping ID map_glicj_soro is applicable for the order.",
              "status": "chosen",
              "reason": "The specimen type matches the expected value for the approved mapping.",
              "evidenceIds": []
            }
          ],
          "conflicts": []
        },
        "action": "APPLY_APPROVED_MAPPING",
        "params": {
          "mappingId": "map_glicj_soro",
          "mappingVersion": "2026.10.1"
        },
        "confidence": "MEDIUM",
        "preconditions": [
          {
            "check": "MAPPING_VERSION_UNCHANGED",
            "expected": "2026.10.1"
          }
        ]
      }
    },
    {
      "referenceCase": "P5-test-04/2",
      "family": "P5",
      "variant": "P5-test-04",
      "repetition": 2,
      "finalState": "Resolved",
      "action": "APPLY_APPROVED_MAPPING",
      "params": {
        "mappingId": "map_hba1c_legacy",
        "mappingVersion": "2026.10.1"
      },
      "answer": {
        "diagnosis": {
          "summary": "The order can proceed with an approved mapping for the exam code HBA1C-L.",
          "claims": [
            {
              "text": "The partner is healthy and stable.",
              "evidenceIds": [
                "@ev:tool.partner_health"
              ]
            },
            {
              "text": "The order is active.",
              "evidenceIds": [
                "@ev:tool.origin_order_status"
              ]
            },
            {
              "text": "An approved mapping exists for the exam code HBA1C-L.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "hypotheses": [
            {
              "text": "Mapping ID map_hba1c_legacy is applicable for the exam code HBA1C-L.",
              "status": "chosen",
              "reason": "The mapping is applicable and exact.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "conflicts": []
        },
        "action": "APPLY_APPROVED_MAPPING",
        "params": {
          "mappingId": "map_hba1c_legacy",
          "mappingVersion": "2026.10.1"
        },
        "confidence": "HIGH",
        "preconditions": [
          {
            "check": "MAPPING_VERSION_UNCHANGED",
            "expected": "2026.10.1"
          }
        ]
      }
    },
    {
      "referenceCase": "P5-test-05/2",
      "family": "P5",
      "variant": "P5-test-05",
      "repetition": 2,
      "finalState": "Resolved",
      "action": "APPLY_APPROVED_MAPPING",
      "params": {
        "mappingId": "map_glicj_soro",
        "mappingVersion": "2026.10.1"
      },
      "answer": {
        "diagnosis": {
          "summary": "The order has an approved mapping candidate that is applicable based on the specimen type.",
          "claims": [
            {
              "text": "The order's exam code 'glic-j' has an approved mapping candidate.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "hypotheses": [
            {
              "text": "Mapping 'map_glicj_soro' is applicable for the order.",
              "status": "chosen",
              "reason": "The specimen type 'SORO' matches the condition for the mapping.",
              "evidenceIds": []
            }
          ],
          "conflicts": []
        },
        "action": "APPLY_APPROVED_MAPPING",
        "params": {
          "mappingId": "map_glicj_soro",
          "mappingVersion": "2026.10.1"
        },
        "confidence": "MEDIUM",
        "preconditions": [
          {
            "check": "MAPPING_VERSION_UNCHANGED",
            "expected": "2026.10.1"
          }
        ]
      }
    },
    {
      "referenceCase": "P8b-test-01/2",
      "family": "P8",
      "variant": "P8b-test-01",
      "repetition": 2,
      "finalState": "Resolved",
      "action": "APPLY_APPROVED_MAPPING",
      "params": {
        "mappingId": "map_glicj_plasma",
        "mappingVersion": "2026.10.1"
      },
      "answer": {
        "diagnosis": {
          "summary": "The order has a discontinued exam code and an approved mapping is available for the current specimen type.",
          "claims": [
            {
              "text": "The exam code GLIC-J is discontinued.",
              "evidenceIds": [
                "@ev:system.exception"
              ]
            },
            {
              "text": "The partner is healthy and operational.",
              "evidenceIds": [
                "@ev:tool.partner_health"
              ]
            },
            {
              "text": "An approved mapping exists for the exam code GLIC-J with specimen type PLASMA.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "hypotheses": [
            {
              "text": "Mapping from GLIC-J to GLIC-P is applicable.",
              "status": "chosen",
              "reason": "The mapping conditions are satisfied for the specimen type PLASMA.",
              "evidenceIds": []
            }
          ],
          "conflicts": []
        },
        "action": "APPLY_APPROVED_MAPPING",
        "params": {
          "mappingId": "map_glicj_plasma",
          "mappingVersion": "2026.10.1"
        },
        "confidence": "HIGH",
        "preconditions": [
          {
            "check": "MAPPING_VERSION_UNCHANGED",
            "expected": "2026.10.1"
          }
        ]
      }
    },
    {
      "referenceCase": "P8b-test-02/2",
      "family": "P8",
      "variant": "P8b-test-02",
      "repetition": 2,
      "finalState": "Resolved",
      "action": "APPLY_APPROVED_MAPPING",
      "params": {
        "mappingId": "map_glicj_soro",
        "mappingVersion": "2026.10.1"
      },
      "answer": {
        "diagnosis": {
          "summary": "The order is active and the partner is healthy. There is one approved mapping candidate applicable for the order's exam code GLIC-J with the specimen type being Serum.",
          "claims": [
            {
              "text": "The order is active and has not been rejected due to partner instability.",
              "evidenceIds": [
                "@ev:tool.origin_order_status"
              ]
            },
            {
              "text": "The partner is operational and healthy.",
              "evidenceIds": [
                "@ev:tool.partner_health"
              ]
            },
            {
              "text": "There is one approved mapping candidate applicable for the exam code GLIC-J.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "hypotheses": [
            {
              "text": "Mapping from GLIC-J to GLIC-S is applicable.",
              "status": "chosen",
              "reason": "The specimen type matches the required condition for the approved mapping.",
              "evidenceIds": []
            }
          ],
          "conflicts": []
        },
        "action": "APPLY_APPROVED_MAPPING",
        "params": {
          "mappingId": "map_glicj_soro",
          "mappingVersion": "2026.10.1"
        },
        "confidence": "MEDIUM",
        "preconditions": [
          {
            "check": "MAPPING_VERSION_UNCHANGED",
            "expected": "2026.10.1"
          }
        ]
      }
    },
    {
      "referenceCase": "P8b-test-03/2",
      "family": "P8",
      "variant": "P8b-test-03",
      "repetition": 2,
      "finalState": "Resolved",
      "action": "APPLY_APPROVED_MAPPING",
      "params": {
        "mappingId": "map_glicj_soro",
        "mappingVersion": "2026.10.1"
      },
      "answer": {
        "diagnosis": {
          "summary": "The order has an approved mapping candidate that can be applied based on the current specimen type.",
          "claims": [
            {
              "text": "The order is active and the partner is healthy.",
              "evidenceIds": [
                "@ev:tool.origin_order_status",
                "@ev:tool.partner_health"
              ]
            }
          ],
          "hypotheses": [
            {
              "text": "Mapping from GLIC-J to GLIC-S is applicable based on the specimen type being serum.",
              "status": "chosen",
              "reason": "The mapping conditions for the specimen type match.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "conflicts": []
        },
        "action": "APPLY_APPROVED_MAPPING",
        "params": {
          "mappingId": "map_glicj_soro",
          "mappingVersion": "2026.10.1"
        },
        "confidence": "MEDIUM",
        "preconditions": [
          {
            "check": "MAPPING_VERSION_UNCHANGED",
            "expected": "2026.10.1"
          }
        ]
      }
    },
    {
      "referenceCase": "P8b-test-04/2",
      "family": "P8",
      "variant": "P8b-test-04",
      "repetition": 2,
      "finalState": "Resolved",
      "action": "APPLY_APPROVED_MAPPING",
      "params": {
        "mappingId": "map_glicj_plasma",
        "mappingVersion": "2026.10.1"
      },
      "answer": {
        "diagnosis": {
          "summary": "The order is active and the partner is healthy. There is one approved mapping applicable for the exam code 'glic-j'.",
          "claims": [
            {
              "text": "The order is active and has no patient record collisions.",
              "evidenceIds": [
                "@ev:tool.origin_order_status",
                "@ev:tool.receipts_and_orders_by_patient"
              ]
            },
            {
              "text": "The partner is healthy and stable.",
              "evidenceIds": [
                "@ev:tool.partner_health",
                "@ev:tool.partner_failure_history"
              ]
            },
            {
              "text": "There is one approved mapping applicable for the exam code 'glic-j'.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "hypotheses": [
            {
              "text": "Mapping 'map_glicj_plasma' is applicable for the order.",
              "status": "chosen",
              "reason": "The specimen type matches the mapping conditions.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "conflicts": []
        },
        "action": "APPLY_APPROVED_MAPPING",
        "params": {
          "mappingId": "map_glicj_plasma",
          "mappingVersion": "2026.10.1"
        },
        "confidence": "MEDIUM",
        "preconditions": [
          {
            "check": "MAPPING_VERSION_UNCHANGED",
            "expected": "2026.10.1"
          }
        ]
      }
    },
    {
      "referenceCase": "P8b-test-05/2",
      "family": "P8",
      "variant": "P8b-test-05",
      "repetition": 2,
      "finalState": "ReviewRequired",
      "action": null,
      "params": {},
      "answer": {
        "diagnosis": {
          "summary": "No approved mapping found for the order's exam code GLIC-J, and the partner is stable.",
          "claims": [
            {
              "text": "The order's exam code GLIC-J is discontinued.",
              "evidenceIds": [
                "@ev:system.exception"
              ]
            },
            {
              "text": "The partner lab is operational and stable.",
              "evidenceIds": [
                "@ev:tool.partner_health"
              ]
            },
            {
              "text": "No applicable mappings found for the exam code GLIC-J.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "hypotheses": [
            {
              "text": "Mapping for GLIC-J to plasma is not applicable due to specimen type mismatch.",
              "status": "discarded",
              "reason": "specimenType expected PLASMA but matched false",
              "evidenceIds": []
            },
            {
              "text": "Mapping for GLIC-J to serum is not applicable due to specimen type mismatch.",
              "status": "discarded",
              "reason": "specimenType expected SERUM but matched false",
              "evidenceIds": []
            }
          ],
          "conflicts": []
        },
        "action": "REQUEST_REVIEW",
        "params": {},
        "confidence": "LOW",
        "preconditions": []
      }
    },
    {
      "referenceCase": "clean-success-test-01/2",
      "family": "clean",
      "variant": "clean-success-test-01",
      "repetition": 2,
      "finalState": "NoCase",
      "action": null,
      "params": {},
      "answer": null
    },
    {
      "referenceCase": "clean-unavailable-test-01/2",
      "family": "clean",
      "variant": "clean-unavailable-test-01",
      "repetition": 2,
      "finalState": "Held",
      "action": "HOLD",
      "params": {},
      "answer": {
        "diagnosis": {
          "summary": "The partner laboratory is currently down due to scheduled maintenance, which prevents processing the order at this time.",
          "claims": [
            {
              "text": "The partner laboratory is down due to scheduled maintenance.",
              "evidenceIds": [
                "@ev:tool.partner_health"
              ]
            }
          ],
          "hypotheses": [],
          "conflicts": []
        },
        "action": "HOLD",
        "params": {},
        "confidence": "HIGH",
        "preconditions": [
          {
            "check": "PARTNER_HEALTHY_WINDOW",
            "expected": "0"
          }
        ]
      }
    },
    {
      "referenceCase": "clean-ambiguous-identity-test-01/2",
      "family": "clean",
      "variant": "clean-ambiguous-identity-test-01",
      "repetition": 2,
      "finalState": "ReviewRequired",
      "action": null,
      "params": {},
      "answer": {
        "diagnosis": {
          "summary": "The order cannot proceed due to a lack of approved mappings for the exam code.",
          "claims": [
            {
              "text": "The order has no approved mappings for the exam code 'HEMO'.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "hypotheses": [],
          "conflicts": []
        },
        "action": "REQUEST_REVIEW",
        "params": {},
        "confidence": "LOW",
        "preconditions": []
      }
    },
    {
      "referenceCase": "P5-test-01/3",
      "family": "P5",
      "variant": "P5-test-01",
      "repetition": 3,
      "finalState": "Resolved",
      "action": "APPLY_APPROVED_MAPPING",
      "params": {
        "mappingId": "map_glicj_plasma",
        "mappingVersion": "2026.10.1"
      },
      "answer": {
        "diagnosis": {
          "summary": "The order has an approved mapping available for the exam code GLIC-J, which is applicable and exact.",
          "claims": [
            {
              "text": "The exam code GLIC-J is discontinued, leading to a VALIDATION_ERROR.",
              "evidenceIds": [
                "@ev:system.exception"
              ]
            },
            {
              "text": "The partner lab is healthy and operational.",
              "evidenceIds": [
                "@ev:tool.partner_health"
              ]
            },
            {
              "text": "The order is active and has not been previously processed.",
              "evidenceIds": [
                "@ev:tool.origin_order_status"
              ]
            },
            {
              "text": "There is an approved mapping for GLIC-J to GLIC-P with the specimen type PLASMA.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "hypotheses": [
            {
              "text": "Mapping from GLIC-J to GLIC-P is applicable and should be used.",
              "status": "chosen",
              "reason": "The mapping is applicable and exact.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "conflicts": []
        },
        "action": "APPLY_APPROVED_MAPPING",
        "params": {
          "mappingId": "map_glicj_plasma",
          "mappingVersion": "2026.10.1"
        },
        "confidence": "HIGH",
        "preconditions": [
          {
            "check": "MAPPING_VERSION_UNCHANGED",
            "expected": "2026.10.1"
          }
        ]
      }
    },
    {
      "referenceCase": "P5-test-02/3",
      "family": "P5",
      "variant": "P5-test-02",
      "repetition": 3,
      "finalState": "Resolved",
      "action": "APPLY_APPROVED_MAPPING",
      "params": {
        "mappingId": "map_tsh_legacy",
        "mappingVersion": "2026.10.1"
      },
      "answer": {
        "diagnosis": {
          "summary": "The order contains a discontinued exam code, but there is an approved mapping available for it.",
          "claims": [
            {
              "text": "The exam code TSH-OLD is discontinued, leading to a VALIDATION_ERROR.",
              "evidenceIds": [
                "@ev:system.exception"
              ]
            },
            {
              "text": "The partner is healthy and stable, allowing for processing of the order.",
              "evidenceIds": [
                "@ev:tool.partner_health"
              ]
            },
            {
              "text": "There is an approved mapping for the exam code TSH-OLD.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "hypotheses": [
            {
              "text": "Mapping map_tsh_legacy is applicable for the exam code TSH-OLD.",
              "status": "chosen",
              "reason": "The mapping is applicable and exact.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "conflicts": []
        },
        "action": "APPLY_APPROVED_MAPPING",
        "params": {
          "mappingId": "map_tsh_legacy",
          "mappingVersion": "2026.10.1"
        },
        "confidence": "HIGH",
        "preconditions": [
          {
            "check": "MAPPING_VERSION_UNCHANGED",
            "expected": "2026.10.1"
          }
        ]
      }
    },
    {
      "referenceCase": "P5-test-03/3",
      "family": "P5",
      "variant": "P5-test-03",
      "repetition": 3,
      "finalState": "Resolved",
      "action": "APPLY_APPROVED_MAPPING",
      "params": {
        "mappingId": "map_glicj_soro",
        "mappingVersion": "2026.10.1"
      },
      "answer": {
        "diagnosis": {
          "summary": "The order is active and the partner is healthy. There is one approved mapping candidate applicable for the exam code GLIC-J, which matches the specimen type of Serum.",
          "claims": [
            {
              "text": "The order is active.",
              "evidenceIds": [
                "@ev:tool.origin_order_status"
              ]
            },
            {
              "text": "The partner is healthy and stable.",
              "evidenceIds": [
                "@ev:tool.partner_health"
              ]
            },
            {
              "text": "There is one applicable mapping for the exam code GLIC-J.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "hypotheses": [
            {
              "text": "Mapping map_glicj_soro is applicable for the exam code GLIC-J with the specimen type Serum.",
              "status": "chosen",
              "reason": "The specimen type matches the expected value for the mapping.",
              "evidenceIds": []
            }
          ],
          "conflicts": []
        },
        "action": "APPLY_APPROVED_MAPPING",
        "params": {
          "mappingId": "map_glicj_soro",
          "mappingVersion": "2026.10.1"
        },
        "confidence": "MEDIUM",
        "preconditions": [
          {
            "check": "MAPPING_VERSION_UNCHANGED",
            "expected": "2026.10.1"
          }
        ]
      }
    },
    {
      "referenceCase": "P5-test-04/3",
      "family": "P5",
      "variant": "P5-test-04",
      "repetition": 3,
      "finalState": "Resolved",
      "action": "APPLY_APPROVED_MAPPING",
      "params": {
        "mappingId": "map_hba1c_legacy",
        "mappingVersion": "2026.10.1"
      },
      "answer": {
        "diagnosis": {
          "summary": "The order has an approved mapping available for the exam code HBA1C-L.",
          "claims": [
            {
              "text": "The order is active at origin.",
              "evidenceIds": [
                "@ev:tool.origin_order_status"
              ]
            },
            {
              "text": "The partner is healthy and stable.",
              "evidenceIds": [
                "@ev:tool.partner_health"
              ]
            },
            {
              "text": "There is an approved mapping for the exam code HBA1C-L.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "hypotheses": [
            {
              "text": "Mapping ID map_hba1c_legacy is applicable.",
              "status": "chosen",
              "reason": "The mapping is applicable and exact.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "conflicts": []
        },
        "action": "APPLY_APPROVED_MAPPING",
        "params": {
          "mappingId": "map_hba1c_legacy",
          "mappingVersion": "2026.10.1"
        },
        "confidence": "HIGH",
        "preconditions": [
          {
            "check": "MAPPING_VERSION_UNCHANGED",
            "expected": "2026.10.1"
          }
        ]
      }
    },
    {
      "referenceCase": "P5-test-05/3",
      "family": "P5",
      "variant": "P5-test-05",
      "repetition": 3,
      "finalState": "Resolved",
      "action": "APPLY_APPROVED_MAPPING",
      "params": {
        "mappingId": "map_glicj_soro",
        "mappingVersion": "2026.10.1"
      },
      "answer": {
        "diagnosis": {
          "summary": "The order has an approved mapping candidate that can be applied based on the specimen type.",
          "claims": [
            {
              "text": "The order is active and the partner is operational.",
              "evidenceIds": [
                "@ev:tool.origin_order_status",
                "@ev:tool.partner_health"
              ]
            }
          ],
          "hypotheses": [
            {
              "text": "Mapping from GLIC-J to GLIC-S is applicable for serum specimens.",
              "status": "chosen",
              "reason": "The specimen type matches the approved mapping conditions.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "conflicts": []
        },
        "action": "APPLY_APPROVED_MAPPING",
        "params": {
          "mappingId": "map_glicj_soro",
          "mappingVersion": "2026.10.1"
        },
        "confidence": "MEDIUM",
        "preconditions": [
          {
            "check": "MAPPING_VERSION_UNCHANGED",
            "expected": "2026.10.1"
          }
        ]
      }
    },
    {
      "referenceCase": "P8b-test-01/3",
      "family": "P8",
      "variant": "P8b-test-01",
      "repetition": 3,
      "finalState": "Resolved",
      "action": "APPLY_APPROVED_MAPPING",
      "params": {
        "mappingId": "map_glicj_plasma",
        "mappingVersion": "2026.10.1"
      },
      "answer": {
        "diagnosis": {
          "summary": "The order is active and the partner is healthy. There is one approved mapping for the exam code GLIC-J that is applicable.",
          "claims": [
            {
              "text": "The order is active.",
              "evidenceIds": [
                "@ev:tool.origin_order_status"
              ]
            },
            {
              "text": "The partner is healthy.",
              "evidenceIds": [
                "@ev:tool.partner_health"
              ]
            },
            {
              "text": "There is one approved mapping for GLIC-J.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "hypotheses": [
            {
              "text": "Mapping map_glicj_plasma is applicable for the exam code GLIC-J.",
              "status": "chosen",
              "reason": "The specimen type matches the required conditions.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "conflicts": []
        },
        "action": "APPLY_APPROVED_MAPPING",
        "params": {
          "mappingId": "map_glicj_plasma",
          "mappingVersion": "2026.10.1"
        },
        "confidence": "HIGH",
        "preconditions": [
          {
            "check": "MAPPING_VERSION_UNCHANGED",
            "expected": "2026.10.1"
          }
        ]
      }
    },
    {
      "referenceCase": "P8b-test-02/3",
      "family": "P8",
      "variant": "P8b-test-02",
      "repetition": 3,
      "finalState": "Resolved",
      "action": "APPLY_APPROVED_MAPPING",
      "params": {
        "mappingId": "map_glicj_soro",
        "mappingVersion": "2026.10.1"
      },
      "answer": {
        "diagnosis": {
          "summary": "The order is active and the partner is healthy. There is one approved mapping candidate applicable for the order's exam code, which can be applied.",
          "claims": [
            {
              "text": "The order is active and has not been rejected due to partner instability.",
              "evidenceIds": [
                "@ev:tool.origin_order_status"
              ]
            },
            {
              "text": "The partner is operational and healthy.",
              "evidenceIds": [
                "@ev:tool.partner_health"
              ]
            },
            {
              "text": "There is one approved mapping candidate applicable for the exam code GLIC-J.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "hypotheses": [
            {
              "text": "Mapping ID map_glicj_soro with version 2026.10.1 is applicable for the order.",
              "status": "chosen",
              "reason": "The specimen type matches the conditions of the mapping.",
              "evidenceIds": []
            }
          ],
          "conflicts": []
        },
        "action": "APPLY_APPROVED_MAPPING",
        "params": {
          "mappingId": "map_glicj_soro",
          "mappingVersion": "2026.10.1"
        },
        "confidence": "MEDIUM",
        "preconditions": [
          {
            "check": "MAPPING_VERSION_UNCHANGED",
            "expected": "2026.10.1"
          }
        ]
      }
    },
    {
      "referenceCase": "P8b-test-03/3",
      "family": "P8",
      "variant": "P8b-test-03",
      "repetition": 3,
      "finalState": "Resolved",
      "action": "APPLY_APPROVED_MAPPING",
      "params": {
        "mappingId": "map_glicj_soro",
        "mappingVersion": "2026.10.1"
      },
      "answer": {
        "diagnosis": {
          "summary": "The order is active and the partner is stable. There is one approved mapping candidate applicable for the order's exam code.",
          "claims": [
            {
              "text": "The order is active.",
              "evidenceIds": [
                "@ev:tool.origin_order_status"
              ]
            },
            {
              "text": "The partner is stable and healthy.",
              "evidenceIds": [
                "@ev:tool.partner_health"
              ]
            },
            {
              "text": "There is one approved mapping candidate applicable for the exam code GLIC-J.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "hypotheses": [
            {
              "text": "Mapping from GLIC-J to GLIC-S is applicable.",
              "status": "chosen",
              "reason": "The specimen type matches the conditions for the approved mapping.",
              "evidenceIds": []
            }
          ],
          "conflicts": []
        },
        "action": "APPLY_APPROVED_MAPPING",
        "params": {
          "mappingId": "map_glicj_soro",
          "mappingVersion": "2026.10.1"
        },
        "confidence": "MEDIUM",
        "preconditions": [
          {
            "check": "MAPPING_VERSION_UNCHANGED",
            "expected": "2026.10.1"
          }
        ]
      }
    },
    {
      "referenceCase": "P8b-test-04/3",
      "family": "P8",
      "variant": "P8b-test-04",
      "repetition": 3,
      "finalState": "Resolved",
      "action": "APPLY_APPROVED_MAPPING",
      "params": {
        "mappingId": "map_glicj_plasma",
        "mappingVersion": "2026.10.1"
      },
      "answer": {
        "diagnosis": {
          "summary": "The order is active and the partner is stable. There is one approved mapping available for the exam code, which is applicable.",
          "claims": [
            {
              "text": "The order is active and has no patient record collisions.",
              "evidenceIds": [
                "@ev:tool.receipts_and_orders_by_patient"
              ]
            },
            {
              "text": "The partner is stable and healthy.",
              "evidenceIds": [
                "@ev:tool.partner_health"
              ]
            },
            {
              "text": "There is one approved mapping for the exam code 'glic-j'.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "hypotheses": [
            {
              "text": "Mapping 'map_glicj_plasma' is applicable for the exam code 'glic-j'.",
              "status": "chosen",
              "reason": "The specimen type matches the required conditions.",
              "evidenceIds": []
            }
          ],
          "conflicts": []
        },
        "action": "APPLY_APPROVED_MAPPING",
        "params": {
          "mappingId": "map_glicj_plasma",
          "mappingVersion": "2026.10.1"
        },
        "confidence": "MEDIUM",
        "preconditions": [
          {
            "check": "MAPPING_VERSION_UNCHANGED",
            "expected": "2026.10.1"
          }
        ]
      }
    },
    {
      "referenceCase": "P8b-test-05/3",
      "family": "P8",
      "variant": "P8b-test-05",
      "repetition": 3,
      "finalState": "ReviewRequired",
      "action": null,
      "params": {},
      "answer": {
        "diagnosis": {
          "summary": "No approved mapping found for the order's exam code GLIC-J.",
          "claims": [
            {
              "text": "The order's exam code GLIC-J is discontinued.",
              "evidenceIds": [
                "@ev:system.exception"
              ]
            },
            {
              "text": "No applicable mappings found for the exam code GLIC-J.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "hypotheses": [
            {
              "text": "Mapping to plasma is not applicable due to specimen type mismatch.",
              "status": "discarded",
              "reason": "specimenType expected PLASMA but matched false",
              "evidenceIds": []
            },
            {
              "text": "Mapping to serum is not applicable due to specimen type mismatch.",
              "status": "discarded",
              "reason": "specimenType expected SERUM but matched false",
              "evidenceIds": []
            }
          ],
          "conflicts": []
        },
        "action": "REQUEST_REVIEW",
        "params": {},
        "confidence": "LOW",
        "preconditions": []
      }
    },
    {
      "referenceCase": "clean-success-test-01/3",
      "family": "clean",
      "variant": "clean-success-test-01",
      "repetition": 3,
      "finalState": "NoCase",
      "action": null,
      "params": {},
      "answer": null
    },
    {
      "referenceCase": "clean-unavailable-test-01/3",
      "family": "clean",
      "variant": "clean-unavailable-test-01",
      "repetition": 3,
      "finalState": "Held",
      "action": "HOLD",
      "params": {},
      "answer": {
        "diagnosis": {
          "summary": "The partner laboratory is currently down due to scheduled maintenance, which prevents processing the order.",
          "claims": [
            {
              "text": "The partner laboratory is down due to scheduled maintenance.",
              "evidenceIds": [
                "@ev:tool.partner_health"
              ]
            }
          ],
          "hypotheses": [],
          "conflicts": []
        },
        "action": "HOLD",
        "params": {},
        "confidence": "HIGH",
        "preconditions": [
          {
            "check": "PARTNER_HEALTHY_WINDOW",
            "expected": "0"
          }
        ]
      }
    },
    {
      "referenceCase": "clean-ambiguous-identity-test-01/3",
      "family": "clean",
      "variant": "clean-ambiguous-identity-test-01",
      "repetition": 3,
      "finalState": "ReviewRequired",
      "action": null,
      "params": {},
      "answer": {
        "diagnosis": {
          "summary": "The order cannot proceed due to a lack of approved mappings for the exam code 'HEMO'.",
          "claims": [
            {
              "text": "The order is active at origin.",
              "evidenceIds": [
                "@ev:tool.origin_order_status"
              ]
            },
            {
              "text": "The partner is healthy and stable.",
              "evidenceIds": [
                "@ev:tool.partner_health"
              ]
            },
            {
              "text": "There are no approved mappings for the exam code 'HEMO'.",
              "evidenceIds": [
                "@ev:tool.mapping_catalog"
              ]
            }
          ],
          "hypotheses": [],
          "conflicts": []
        },
        "action": "REQUEST_REVIEW",
        "params": {},
        "confidence": "LOW",
        "preconditions": []
      }
    }
  ],
  "quickCases": [
    "clean-success-test-01/1",
    "P8b-test-01/1",
    "clean-ambiguous-identity-test-01/1"
  ],
  "recoverySuite": {
    "restart": {
      "passed": true,
      "commit": "64fba34"
    },
    "lateWorker": {
      "passed": true,
      "commit": "64fba34"
    }
  }
}
}

}
