/// The normative Case state machine as compiled data (specs/002 research R4): the 29 rows of
/// contracts/case-state-machine.yaml with the Core's structured effects, the attachment matrix and
/// the parameters. Kept equal to the YAML by SignalNoir.Tests.Core.TableData; edit both together.
Class SignalNoir.Core.TransitionTable Extends %RegisteredObject
{

/// The whole table.
ClassMethod Table() As %DynamicObject
{
    set xdata = ##class(%Dictionary.CompiledXData).%OpenId("SignalNoir.Core.TransitionTable||Table")
    quit ##class(%DynamicObject).%FromJSON(xdata.Data)
}

ClassMethod AllRows() As %DynamicArray
{
    quit ..Table().transitions
}

/// The row with this id, or "" when there is none.
ClassMethod Row(id As %String) As %DynamicObject
{
    set it = ..AllRows().%GetIterator()
    while it.%GetNext(.i, .row) { if row.id = id return row }
    quit ""
}

/// Rows leaving fromState ("" for creation), optionally only those entering toState.
ClassMethod Rows(fromState As %String, toState As %String = "") As %DynamicArray
{
    set out = [], it = ..AllRows().%GetIterator()
    while it.%GetNext(.i, .row) {
        if ($select(row.%GetTypeOf("from") = "null": "", 1: row.from) = fromState) && ((toState = "") || (row.to = toState)) {
            do out.%Push(row)
        }
    }
    quit out
}

ClassMethod AttachmentAllowed(event As %String, state As %String) As %Boolean
{
    set attachment = ..Attachment(event)
    if attachment = "" quit 0
    set it = attachment.states.%GetIterator()
    while it.%GetNext(.i, .listed) { if (listed = "*") || (listed = state) return 1 }
    quit 0
}

/// Annotation kinds accepted on a terminal Case for this event; empty array when none are listed.
ClassMethod TerminalKinds(event As %String) As %DynamicArray
{
    set attachment = ..Attachment(event)
    if (attachment = "") || 'attachment.%IsDefined("terminalKinds") quit []
    quit attachment.terminalKinds
}

ClassMethod Attachment(event As %String) As %DynamicObject
{
    set it = ..Table().attachments.%GetIterator()
    while it.%GetNext(.i, .attachment) { if attachment.event = event return attachment }
    quit ""
}

ClassMethod Parameter(name As %String) As %String
{
    quit ..Table().parameters.%Get(name)
}

ClassMethod IsTerminal(state As %String) As %Boolean
{
    set it = ..Table().terminalStates.%GetIterator()
    while it.%GetNext(.i, .terminal) { if terminal = state return 1 }
    quit 0
}

XData Table [ MimeType = application/json ]
{
{
  "version": "1.0.0",
  "parameters": {
    "approvalTtl": "PT15M",
    "reassessInterval": "PT60S",
    "maxInconclusiveReconciliations": 3,
    "maxDenials": 2
  },
  "terminalStates": [
    "Resolved",
    "ResolvedByPriorReceipt",
    "Cancelled",
    "Failed"
  ],
  "transitions": [
    {
      "id": "T01",
      "from": null,
      "to": "Open",
      "command": null,
      "actors": [
        "system"
      ],
      "preconditions": [
        {
          "check": "orderSnapshotRecorded",
          "expected": true
        },
        {
          "check": "noOpenCaseForOrder",
          "expected": true
        },
        {
          "check": "previousCaseExists",
          "expected": false
        }
      ],
      "events": [
        "CaseOpened",
        "ExceptionRecorded"
      ],
      "outbox": [
        "Investigate"
      ],
      "sameStepAs": [],
      "effects": [
        "OpenCase"
      ],
      "reason": "1st Exception for an orderId"
    },
    {
      "id": "T02",
      "from": null,
      "to": "Open",
      "command": null,
      "actors": [
        "system"
      ],
      "preconditions": [
        {
          "check": "noOpenCaseForOrder",
          "expected": true
        },
        {
          "check": "previousCaseTerminal",
          "expected": true
        }
      ],
      "events": [
        "CaseOpened",
        "ExceptionRecorded",
        "Annotation"
      ],
      "outbox": [
        "Investigate"
      ],
      "sameStepAs": [],
      "effects": [
        "OpenCase",
        "LinkPreviousEpisode"
      ],
      "reason": "Exception for an orderId whose most recent Case is terminal, or Exception attached during the Execution of a Case that ends in Failed (T25)"
    },
    {
      "id": "T03",
      "from": "Open",
      "to": "Investigating",
      "command": "Investigate",
      "actors": [
        "system"
      ],
      "preconditions": [
        {
          "check": "state",
          "expected": "Open"
        },
        {
          "check": "caseVersionMatches",
          "expected": true
        }
      ],
      "events": [],
      "outbox": [],
      "sameStepAs": [],
      "effects": [
        "SetStepLease"
      ],
      "reason": "Investigate command"
    },
    {
      "id": "T04",
      "from": "Investigating",
      "to": "DecisionProposed",
      "command": null,
      "actors": [
        "agent",
        "rules",
        "replay"
      ],
      "preconditions": [
        {
          "check": "state",
          "expected": "Investigating"
        },
        {
          "check": "leaseValid",
          "expected": true
        },
        {
          "check": "proposerMatchesMode",
          "expected": true
        },
        {
          "check": "proposalDtoValid",
          "expected": true
        },
        {
          "check": "claimsCiteEvidence",
          "expected": true
        }
      ],
      "events": [
        "ProposalCreated"
      ],
      "outbox": [],
      "sameStepAs": [],
      "effects": [
        "SetCurrentProposal"
      ],
      "reason": "Proposer returns a valid Proposal within budget"
    },
    {
      "id": "T05",
      "from": "Investigating",
      "to": "ReviewRequired",
      "command": null,
      "actors": [
        "system"
      ],
      "preconditions": [
        {
          "check": "state",
          "expected": "Investigating"
        },
        {
          "check": "leaseValid",
          "expected": true
        },
        {
          "check": "investigationFailure",
          "expected": [
            "budget_exceeded",
            "invalid_agent_response",
            "agent_refusal",
            "provider_unavailable"
          ]
        }
      ],
      "events": [
        "DossierCreated"
      ],
      "outbox": [],
      "sameStepAs": [],
      "effects": [],
      "reason": "Budget exceeded, invalid response, Agent refusal or Provider unavailable (FR-4)"
    },
    {
      "id": "T06",
      "from": "Investigating",
      "to": "ReviewRequired",
      "command": null,
      "actors": [
        "sweeper"
      ],
      "preconditions": [
        {
          "check": "state",
          "expected": "Investigating"
        },
        {
          "check": "leaseExpired",
          "expected": true
        }
      ],
      "events": [
        "DossierCreated"
      ],
      "outbox": [],
      "sameStepAs": [],
      "effects": [
        "ClearStepLease"
      ],
      "reason": "Investigation interrupted (restart or lost work)"
    },
    {
      "id": "T07",
      "from": "DecisionProposed",
      "to": "PendingApproval",
      "command": null,
      "actors": [
        "system"
      ],
      "preconditions": [
        {
          "check": "proposalIsCurrent",
          "expected": true
        },
        {
          "check": "verdict",
          "expected": "accepted"
        },
        {
          "check": "requiresApproval",
          "expected": true
        }
      ],
      "events": [
        "ValidatorVerdict"
      ],
      "outbox": [],
      "sameStepAs": [
        "T11",
        "T12"
      ],
      "effects": [],
      "reason": "Verdict accepted with requiresApproval = true"
    },
    {
      "id": "T08",
      "from": "DecisionProposed",
      "to": "Executing",
      "command": null,
      "actors": [
        "system"
      ],
      "preconditions": [
        {
          "check": "action",
          "expected": "HOLD"
        },
        {
          "check": "verdict",
          "expected": "accepted"
        },
        {
          "check": "requiresApproval",
          "expected": false
        },
        {
          "check": "noExecutionInFlight",
          "expected": true
        }
      ],
      "events": [
        "ValidatorVerdict",
        "ExecutionAuthorized"
      ],
      "outbox": [
        "Execute"
      ],
      "sameStepAs": [],
      "effects": [
        "CreateExecution"
      ],
      "reason": "Verdict accepted with requiresApproval = false (HOLD only)"
    },
    {
      "id": "T09",
      "from": "DecisionProposed",
      "to": "ResolvedByPriorReceipt",
      "command": null,
      "actors": [
        "system"
      ],
      "preconditions": [
        {
          "check": "verdict",
          "expected": "prior_receipt_confirmed"
        },
        {
          "check": "priorReceiptEvidenceRecorded",
          "expected": true
        },
        {
          "check": "equivalenceKeysEqual",
          "expected": true
        }
      ],
      "events": [
        "ValidatorVerdict",
        "ReceiptRecorded"
      ],
      "outbox": [],
      "sameStepAs": [],
      "effects": [],
      "reason": "Verdict prior_receipt_confirmed (FR-47)"
    },
    {
      "id": "T10",
      "from": "DecisionProposed",
      "to": "ReviewRequired",
      "command": null,
      "actors": [
        "system"
      ],
      "preconditions": [
        {
          "check": "proposalIsCurrent",
          "expected": true
        },
        {
          "check": "verdict",
          "expected": [
            "blocked",
            "review"
          ]
        }
      ],
      "events": [
        "ValidatorVerdict",
        "DossierCreated"
      ],
      "outbox": [],
      "sameStepAs": [],
      "effects": [],
      "reason": "Verdict blocked or review"
    },
    {
      "id": "T11",
      "from": "PendingApproval",
      "to": "Approved",
      "command": "decideProposal",
      "actors": [
        "operator:*"
      ],
      "preconditions": [
        {
          "check": "state",
          "expected": "PendingApproval"
        },
        {
          "check": "proposalIsCurrent",
          "expected": true
        },
        {
          "check": "caseVersionMatches",
          "expected": true
        },
        {
          "check": "decision",
          "expected": "approved"
        }
      ],
      "events": [
        "ApprovalRecorded"
      ],
      "outbox": [
        "Execute"
      ],
      "sameStepAs": [],
      "effects": [
        "RecordApproval:approved"
      ],
      "reason": "Operator approves"
    },
    {
      "id": "T12",
      "from": "PendingApproval",
      "to": "Approved",
      "command": null,
      "actors": [
        "benchmark"
      ],
      "preconditions": [
        {
          "check": "benchmarkRun",
          "expected": true
        },
        {
          "check": "sameStepAsValidation",
          "expected": true
        }
      ],
      "events": [
        "ApprovalRecorded"
      ],
      "outbox": [
        "Execute"
      ],
      "sameStepAs": [],
      "effects": [
        "RecordApproval:approved"
      ],
      "reason": "Benchmark Automatic Approval"
    },
    {
      "id": "T13",
      "from": "PendingApproval",
      "to": "Rejected",
      "command": "decideProposal",
      "actors": [
        "operator:*"
      ],
      "preconditions": [
        {
          "check": "state",
          "expected": "PendingApproval"
        },
        {
          "check": "proposalIsCurrent",
          "expected": true
        },
        {
          "check": "caseVersionMatches",
          "expected": true
        },
        {
          "check": "decision",
          "expected": "denied"
        },
        {
          "check": "reasonPresent",
          "expected": true
        },
        {
          "check": "denialCountBelow",
          "expected": "maxDenials"
        }
      ],
      "events": [
        "ApprovalRecorded"
      ],
      "outbox": [
        "Investigate"
      ],
      "sameStepAs": [],
      "effects": [
        "RecordApproval:denied",
        "IncrementDenialCount"
      ],
      "reason": "Operator denies with a reason"
    },
    {
      "id": "T14",
      "from": "Rejected",
      "to": "Investigating",
      "command": "Investigate",
      "actors": [
        "system"
      ],
      "preconditions": [
        {
          "check": "state",
          "expected": "Rejected"
        },
        {
          "check": "caseVersionMatches",
          "expected": true
        },
        {
          "check": "denialCount",
          "expected": 1
        }
      ],
      "events": [],
      "outbox": [],
      "sameStepAs": [],
      "effects": [
        "SetStepLease"
      ],
      "reason": "Investigate command with denialCount = 1"
    },
    {
      "id": "T15",
      "from": "Rejected",
      "to": "ReviewRequired",
      "command": "Investigate",
      "actors": [
        "system"
      ],
      "preconditions": [
        {
          "check": "state",
          "expected": "Rejected"
        },
        {
          "check": "caseVersionMatches",
          "expected": true
        },
        {
          "check": "denialCount",
          "expected": "maxDenials"
        }
      ],
      "events": [
        "DossierCreated"
      ],
      "outbox": [],
      "sameStepAs": [],
      "effects": [],
      "reason": "Investigate command with denialCount = maxDenials"
    },
    {
      "id": "T16",
      "from": "PendingApproval",
      "to": "Investigating",
      "command": null,
      "actors": [
        "system"
      ],
      "preconditions": [
        {
          "check": "state",
          "expected": "PendingApproval"
        },
        {
          "check": "newException",
          "expected": true
        }
      ],
      "events": [
        "ExceptionRecorded"
      ],
      "outbox": [
        "Investigate"
      ],
      "sameStepAs": [],
      "effects": [
        "ClearCurrentProposal",
        "SetStepLease"
      ],
      "reason": "New Exception for the same Order (D1)"
    },
    {
      "id": "T17",
      "from": "Approved",
      "to": "Executing",
      "command": "Execute",
      "actors": [
        "system"
      ],
      "preconditions": [
        {
          "check": "state",
          "expected": "Approved"
        },
        {
          "check": "caseVersionMatches",
          "expected": true
        },
        {
          "check": "approvalForCurrentProposal",
          "expected": true
        },
        {
          "check": "approvalNotExpired",
          "expected": true
        },
        {
          "check": "noExecutionInFlight",
          "expected": true
        }
      ],
      "events": [
        "ExecutionAuthorized"
      ],
      "outbox": [],
      "sameStepAs": [],
      "effects": [
        "CreateExecution"
      ],
      "reason": "Execute command: authorization CAS"
    },
    {
      "id": "T18",
      "from": "Approved",
      "to": "PendingApproval",
      "command": "Expire",
      "actors": [
        "sweeper"
      ],
      "preconditions": [
        {
          "check": "state",
          "expected": "Approved"
        },
        {
          "check": "approvalExpired",
          "expected": true
        },
        {
          "check": "noAuthorization",
          "expected": true
        }
      ],
      "events": [
        "ApprovalExpired"
      ],
      "outbox": [],
      "sameStepAs": [],
      "effects": [],
      "reason": "Expire command (FR-18)"
    },
    {
      "id": "T19",
      "from": "Executing",
      "to": "Held",
      "command": null,
      "actors": [
        "system"
      ],
      "preconditions": [
        {
          "check": "executionOutcome",
          "expected": "in_progress"
        },
        {
          "check": "noAttemptSent",
          "expected": true
        },
        {
          "check": "revalidationFailed",
          "expected": "PARTNER_HEALTHY_WINDOW"
        }
      ],
      "events": [
        "RevalidationPerformed"
      ],
      "outbox": [],
      "sameStepAs": [],
      "effects": [
        "CloseExecution:held",
        "VoidAuthorization"
      ],
      "reason": "Revalidation: PARTNER_HEALTHY_WINDOW false"
    },
    {
      "id": "T20",
      "from": "Executing",
      "to": "Held",
      "command": "Execute",
      "actors": [
        "system"
      ],
      "preconditions": [
        {
          "check": "action",
          "expected": "HOLD"
        }
      ],
      "events": [
        "RevalidationPerformed"
      ],
      "outbox": [],
      "sameStepAs": [],
      "effects": [
        "CloseExecution:held"
      ],
      "reason": "Execution of HOLD"
    },
    {
      "id": "T21",
      "from": "Executing",
      "to": "Cancelled",
      "command": null,
      "actors": [
        "system"
      ],
      "preconditions": [
        {
          "check": "executionOutcome",
          "expected": "in_progress"
        },
        {
          "check": "noAttemptSent",
          "expected": true
        },
        {
          "check": "revalidationFailed",
          "expected": "ORDER_ACTIVE_AT_ORIGIN"
        }
      ],
      "events": [
        "RevalidationPerformed"
      ],
      "outbox": [],
      "sameStepAs": [],
      "effects": [
        "CloseExecution:cancelled",
        "VoidAuthorization"
      ],
      "reason": "Revalidation: ORDER_ACTIVE_AT_ORIGIN false"
    },
    {
      "id": "T22",
      "from": "Executing",
      "to": "Investigating",
      "command": null,
      "actors": [
        "system"
      ],
      "preconditions": [
        {
          "check": "executionOutcome",
          "expected": "in_progress"
        },
        {
          "check": "noAttemptSent",
          "expected": true
        },
        {
          "check": "revalidationFailed",
          "expected": [
            "POLICY_VERSION_UNCHANGED",
            "MAPPING_VERSION_UNCHANGED"
          ]
        }
      ],
      "events": [
        "RevalidationPerformed"
      ],
      "outbox": [
        "Investigate"
      ],
      "sameStepAs": [],
      "effects": [
        "CloseExecution:cancelled",
        "VoidAuthorization",
        "ClearCurrentProposal",
        "SetStepLease"
      ],
      "reason": "Revalidation: POLICY_VERSION_UNCHANGED or MAPPING_VERSION_UNCHANGED false"
    },
    {
      "id": "T23",
      "from": "Executing",
      "to": "Resolved",
      "command": null,
      "actors": [
        "system"
      ],
      "preconditions": [
        {
          "check": "responseClass",
          "expected": "success"
        },
        {
          "check": "receiptMatches",
          "expected": true
        }
      ],
      "events": [
        "AttemptRecorded",
        "ReceiptRecorded"
      ],
      "outbox": [],
      "sameStepAs": [],
      "effects": [
        "CloseExecution:resolved",
        "ClearPendingReassessment"
      ],
      "reason": "Partner response classified success with a valid Receipt"
    },
    {
      "id": "T24",
      "from": "Executing",
      "to": "Resolved",
      "command": "Reconcile",
      "actors": [
        "system"
      ],
      "preconditions": [
        {
          "check": "reconciliationResult",
          "expected": "receipt_found"
        },
        {
          "check": "receiptMatches",
          "expected": true
        }
      ],
      "events": [
        "ReconciliationPerformed",
        "ReceiptRecorded"
      ],
      "outbox": [],
      "sameStepAs": [],
      "effects": [
        "CloseExecution:resolved",
        "ClearPendingReassessment"
      ],
      "reason": "Prior Reconciliation or Reconciliation finds a Receipt (FR-23)"
    },
    {
      "id": "T25",
      "from": "Executing",
      "to": "Failed",
      "command": null,
      "actors": [
        "system"
      ],
      "preconditions": [
        {
          "check": "attemptsExhausted",
          "expected": true
        },
        {
          "check": "noUncertainAttemptPending",
          "expected": true
        }
      ],
      "events": [
        "AttemptRecorded"
      ],
      "outbox": [],
      "sameStepAs": [
        "T02"
      ],
      "effects": [
        "CloseExecution:failed",
        "OpenNewEpisodeIfPending"
      ],
      "reason": "Policy Attempts exhausted"
    },
    {
      "id": "T26",
      "from": "Executing",
      "to": "ReviewRequired",
      "command": "Reconcile",
      "actors": [
        "system"
      ],
      "preconditions": [
        {
          "check": "executionOutcome",
          "expected": "reconciling"
        },
        {
          "check": "inconclusiveReconciliations",
          "expected": "maxInconclusiveReconciliations"
        }
      ],
      "events": [
        "ReconciliationPerformed",
        "DossierCreated"
      ],
      "outbox": [],
      "sameStepAs": [],
      "effects": [],
      "reason": "Reconciliation inconclusive after the round limit (D4)"
    },
    {
      "id": "T27",
      "from": "Held",
      "to": "Investigating",
      "command": "Reassess",
      "actors": [
        "system"
      ],
      "preconditions": [
        {
          "check": "state",
          "expected": "Held"
        },
        {
          "check": "waitConditionEnded",
          "expected": true
        }
      ],
      "events": [
        "ReassessmentPerformed"
      ],
      "outbox": [
        "Investigate"
      ],
      "sameStepAs": [],
      "effects": [
        "SetStepLease"
      ],
      "reason": "Reassess command finds that the waiting condition is over (FR-51)"
    },
    {
      "id": "T28",
      "from": "ReviewRequired",
      "to": "DecisionProposed",
      "command": "resolveReview",
      "actors": [
        "operator:*"
      ],
      "preconditions": [
        {
          "check": "state",
          "expected": "ReviewRequired"
        },
        {
          "check": "caseVersionMatches",
          "expected": true
        },
        {
          "check": "resolutionAction",
          "expected": [
            "RETRY",
            "APPLY_APPROVED_MAPPING",
            "HOLD"
          ]
        },
        {
          "check": "verdict",
          "expected": "accepted"
        }
      ],
      "events": [
        "OperatorResolution",
        "ProposalCreated"
      ],
      "outbox": [],
      "sameStepAs": [
        "T07",
        "T11",
        "T08"
      ],
      "effects": [
        "SetCurrentProposal"
      ],
      "reason": "Operator resolution with a Catalog Action (FR-29)"
    },
    {
      "id": "T29",
      "from": "ReviewRequired",
      "to": "Cancelled",
      "command": "resolveReview",
      "actors": [
        "operator:*"
      ],
      "preconditions": [
        {
          "check": "state",
          "expected": "ReviewRequired"
        },
        {
          "check": "caseVersionMatches",
          "expected": true
        },
        {
          "check": "reasonPresent",
          "expected": true
        }
      ],
      "events": [
        "OperatorResolution"
      ],
      "outbox": [],
      "sameStepAs": [],
      "effects": [],
      "reason": "Operator resolution by cancellation"
    }
  ],
  "attachments": [
    {
      "event": "ExceptionRecorded",
      "states": [
        "Open",
        "Investigating",
        "DecisionProposed",
        "Rejected",
        "Approved",
        "Executing",
        "Held",
        "ReviewRequired"
      ]
    },
    {
      "event": "ToolCalled",
      "states": [
        "Investigating",
        "Held"
      ]
    },
    {
      "event": "EvidenceObsoleted",
      "states": [
        "Investigating",
        "Held"
      ]
    },
    {
      "event": "ValidatorVerdict",
      "states": [
        "ReviewRequired"
      ]
    },
    {
      "event": "ReassessmentPerformed",
      "states": [
        "Held"
      ]
    },
    {
      "event": "Annotation",
      "states": [
        "*"
      ],
      "terminalKinds": [
        "receipt_corrected",
        "receipt_missing",
        "new_episode_opened"
      ]
    },
    {
      "event": "CommandDiscarded",
      "states": [
        "*"
      ]
    },
    {
      "event": "RevalidationPerformed",
      "states": [
        "Executing"
      ]
    },
    {
      "event": "AttemptRecorded",
      "states": [
        "Executing"
      ]
    },
    {
      "event": "ReconciliationPerformed",
      "states": [
        "Executing",
        "ReviewRequired"
      ]
    }
  ]
}
}

}
