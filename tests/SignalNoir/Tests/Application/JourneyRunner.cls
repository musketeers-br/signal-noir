/// Replays a journey of the table's journeyTrace (UJ-1 to UJ-4) through the command path, step by
/// step, with the facts each transition needs (specs/002 User Story 3). Facts come from the recipe
/// below: what the Production, the Validator or the Partner would have recorded at that point.
Class SignalNoir.Tests.Application.JourneyRunner Extends %RegisteredObject
{

Property OrderId As %String;

Property CaseId As %String;

/// Every result, in order: [{ "step", "ref", "outcome", "state", "refusal" }].
Property Log As %DynamicArray;

/// Transitions applied so far by the current command chain, to skip refs a chain already applied.
Property Applied As %String;

Property Errors As %String(MAXLEN = "");

Method %OnNew(orderId As %String) As %Status
{
    set ..OrderId = orderId, ..Log = []
    quit $$$OK
}

/// Runs every step of the journey; returns the list of steps with their final state.
Method Run(journey As %String) As %DynamicArray
{
    set steps = [], trace = ##class(SignalNoir.Tests.Core.TableFixture).Load().journeyTrace
    set it = trace.%GetIterator()
    while it.%GetNext(.i, .step) {
        continue:step.journey'=journey
        set ..Applied = ""
        set rit = step.refs.%GetIterator()
        while rit.%GetNext(.j, .ref) {
            if j = 0 do ..Prepare(ref)
            do ..Fire(step.step, ref)
        }
        do steps.%Push({"step": (step.step), "state": (..State())})
    }
    quit steps
}

/// A step that starts from another state (a journey that begins mid-way, or a variant after a
/// terminal step) gets a fresh Case driven to that state along the table's main path.
Method Prepare(ref As %String)
{
    quit:$extract(ref, 1, 3)="FR-"
    set row = ##class(SignalNoir.Core.TransitionTable).Row(ref)
    set from = $select(row.%GetTypeOf("from") = "null": "", 1: row.from)
    quit:from=..State()
    set path = $case(from, "Investigating": "T01,T03", "PendingApproval": "T01,T03,T04,T07", : "")
    quit:path=""
    set ..OrderId = ..OrderId_"-v", ..CaseId = ""
    for k = 1:1:$length(path, ",") { do ..Fire("setup", $piece(path, ",", k)) }
}

Method Fire(step As %String, ref As %String)
{
    if (..Applied '= "") && ((","_..Applied_",") [ (","_ref_",")) quit
    if ref = "T01" {
        set result = ##class(SignalNoir.Application.CaseCommands).RecordException(..OrderId, {"httpStatus": 500}, "system")
        set ..CaseId = result.CaseId
    } else {
        set result = ##class(SignalNoir.Application.CaseCommands).Submit(..CaseId, ..Command(ref))
    }
    set ..Applied = ..Applied_$select(..Applied = "": "", 1: ",")_##class(SignalNoir.Tests.Core.Parity).Joined(result.Transitions)
    do ..Log.%Push({"step": (step), "ref": (ref), "outcome": (result.Outcome), "state": (..State()), "refusal": (result.RefusalCode), "failure": (result.FailureText)})
    if result.Outcome = "Failed" set ..Errors = ..Errors_ref_": "_result.FailureText_"; "
}

/// Builds the command for a ref from the current Case and the recipe of facts.
Method Command(ref As %String) As SignalNoir.Core.TransitionCommand
{
    set case = ##class(SignalNoir.Application.Store.Case).%OpenId(..CaseId, 0)
    do case.%Reload()
    set command = ##class(SignalNoir.Core.TransitionCommand).%New()
    set command.ExpectedState = case.State, command.ExpectedCaseVersion = case.CaseVersion
    set n = ..Log.%Size()
    if ref = "FR-014" {
        // The Operator approves the same Proposal again from another tab.
        set command.Actor = "operator:Carla", command.RequestedState = "Approved", command.TargetId = ..LastApprovedProposal()
        set command.ExpectedState = "PendingApproval", command.ExpectedCaseVersion = case.CaseVersion - 3
        set command.Facts = {"decision": "approved"}
        quit command
    }
    if ref = "FR-010" {
        // The Operator tries RETRY; the Validator blocks it, so only the verdict is recorded.
        set command.Actor = "operator:Carla", command.RequestedState = "DecisionProposed", command.Command = "resolveReview"
        set command.AttachEvent = "ValidatorVerdict"
        set command.Facts = {"resolutionAction": "RETRY", "verdict": "blocked", "reasons": ["IDENTITY_UNRESOLVED"]}
        quit command
    }
    set row = ##class(SignalNoir.Core.TransitionTable).Row(ref)
    set command.RequestedState = row.to
    set command.Actor = $replace(row.actors.%Get(0), "operator:*", "operator:Carla")
    set command.Command = $select(row.%GetTypeOf("command") = "null": "", 1: row.command)
    // Commands about the current Proposal name it (the Validator and the Operator know which one).
    set pit = row.preconditions.%GetIterator()
    while pit.%GetNext(.k, .pre) { set:pre.check="proposalIsCurrent" command.TargetId = case.CurrentProposalId }
    set facts = {}
    if ref = "T04" { set facts = {"proposalDtoValid": true, "claimsCiteEvidence": true, "proposalId": ("prop_j"_n)} }
    elseif ref = "T05" { set facts = {"investigationFailure": "provider_unavailable"} }
    elseif ref = "T07" { set facts = {"verdict": "accepted", "requiresApproval": true} }
    elseif ref = "T09" { set facts = {"verdict": "prior_receipt_confirmed", "priorReceiptEvidenceRecorded": true, "equivalenceKeysEqual": true} }
    elseif ref = "T10" { set facts = {"verdict": "review", "dossierReason": "ambiguous_identity"} }
    elseif (ref = "T11") || (ref = "T13") { set facts = {"decision": ($select(ref = "T11": "approved", 1: "denied"))}, command.TargetId = case.CurrentProposalId }
    elseif ref = "T19" { set facts = {"revalidationFailed": ["PARTNER_HEALTHY_WINDOW"]}, command.RequestedState = "" }
    elseif ref = "T21" { set facts = {"revalidationFailed": ["ORDER_ACTIVE_AT_ORIGIN"]}, command.RequestedState = "" }
    elseif ref = "T23" { set facts = {"responseClass": "success", "receiptMatches": true} }
    elseif ref = "T27" { set facts = {"waitConditionEnded": true} }
    elseif ref = "T28" { set facts = {"resolutionAction": "APPLY_APPROVED_MAPPING", "verdict": "accepted", "requiresApproval": true, "proposalId": ("prop_op"_n)} }
    elseif ref = "T29" { set facts = {"reason": "origin will resend with the confirmed patient"} }
    set command.Facts = facts
    quit command
}

Method State() As %String
{
    if ..CaseId = "" quit ""
    set case = ##class(SignalNoir.Application.Store.Case).%OpenId(..CaseId, 0)
    do case.%Reload()
    quit case.State
}

Method LastApprovedProposal() As %String
{
    set case = ##class(SignalNoir.Application.Store.Case).%OpenId(..CaseId, 0)
    set approval = ##class(SignalNoir.Application.Store.Approval).%OpenId(case.CurrentApprovalId, 0)
    quit $select($isobject(approval) && (approval.Decision = "approved"): approval.ProposalId, 1: "")
}

}
