/// Test data helpers shared by the Application suites.
Class SignalNoir.Tests.Application.Fixtures Extends %RegisteredObject
{

/// Delete every Case whose OrderId starts with prefix, with its Timeline, outbox, Approvals and
/// Executions. Test-only: it bypasses the append-only rule by killing storage directly.
ClassMethod Purge(prefix As %String) As %Status
{
    set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT CaseId FROM SignalNoir_Application_Store.CaseRecord WHERE OrderId %STARTSWITH ?", prefix)
    while rs.%Next() {
        set caseId = rs.CaseId
        &sql(DELETE %NOTRIGGER FROM SignalNoir_Application_Store.OutboxEntry WHERE CaseId = :caseId)
        &sql(DELETE %NOTRIGGER FROM SignalNoir_Application_Store.Approval WHERE CaseId = :caseId)
        &sql(DELETE %NOTRIGGER FROM SignalNoir_Application_Store.Execution WHERE CaseId = :caseId)
        // Test data only: bypasses the Timeline's append-only trigger, which product code never does.
        &sql(DELETE %NOTRIGGER FROM SignalNoir_Application_Store.TimelineEvent WHERE CaseId = :caseId)
        kill ^SignalNoir.App.TimelineSeq(caseId)
        &sql(DELETE %NOTRIGGER FROM SignalNoir_Application_Store.CaseRecord WHERE CaseId = :caseId)
    }
    quit $$$OK
}

/// Test setup only: stores a Case directly in the given state (bypassing the command path, which
/// is what the suites exercise). props may set any Case field plus "approval" and "execution"
/// sub-objects, which are stored as their own records.
ClassMethod CreateCase(orderId As %String, state As %String, version As %Integer = 1, props As %DynamicObject = "") As SignalNoir.Application.Store.Case
{
    set:props="" props = {}
    set case = ##class(SignalNoir.Application.Store.Case).%New()
    set case.CaseId = ##class(SignalNoir.Application.Store.Case).NewId()
    set case.OrderId = orderId, case.State = state, case.CaseVersion = version
    set case.CreatedAt = $zdatetime($ztimestamp, 3, 7, 3), case.LastEventAt = case.CreatedAt
    set it = props.%GetIterator()
    while it.%GetNext(.name, .value) {
        continue:(name="approval")||(name="execution")
        set $property(case, name) = value
    }
    $$$ThrowOnError(case.%Save())
    if props.%IsDefined("approval") {
        set a = props.approval, approval = ##class(SignalNoir.Application.Store.Approval).%New()
        set approval.ApprovalId = $select(a.approvalId '= "": a.approvalId, 1: ##class(SignalNoir.Application.Store.Approval).NewId())
        set approval.CaseId = case.CaseId, approval.ProposalId = a.proposalId, approval.Decision = a.decision
        set approval.ByActor = $select(a.by '= "": a.by, 1: "operator:Test"), approval.At = case.CreatedAt, approval.ExpiresAt = a.expiresAt
        $$$ThrowOnError(approval.%Save())
        set case.CurrentApprovalId = approval.ApprovalId
        $$$ThrowOnError(case.%Save())
    }
    if props.%IsDefined("execution") {
        set e = props.execution, execution = ##class(SignalNoir.Application.Store.Execution).%New()
        set execution.ExecutionId = $select(e.executionId '= "": e.executionId, 1: ##class(SignalNoir.Application.Store.Execution).NewId())
        set execution.CaseId = case.CaseId, execution.ApprovalId = e.approvalId, execution.ProposalId = e.proposalId
        set execution.Outcome = $select(e.outcome '= "": e.outcome, 1: "in_progress"), execution.AttemptsSent = +e.attemptsSent
        set execution.InconclusiveReconciliations = +e.inconclusive, execution.AuthorizedAt = case.CreatedAt
        $$$ThrowOnError(execution.%Save())
        set case.CurrentExecutionId = execution.ExecutionId
        $$$ThrowOnError(case.%Save())
    }
    quit case
}

/// Event types of a Case's Timeline, in seq order, comma-separated.
ClassMethod EventTypes(caseId As %String) As %String
{
    set out = "", rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT Type FROM SignalNoir_Application_Store.TimelineEvent WHERE CaseId = ? ORDER BY Seq", caseId)
    while rs.%Next() { set out = out_$select(out = "": "", 1: ",")_rs.Type }
    quit out
}

/// Outbox kinds of a Case, comma-separated.
ClassMethod OutboxKinds(caseId As %String) As %String
{
    set out = "", rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT Kind FROM SignalNoir_Application_Store.OutboxEntry WHERE CaseId = ? ORDER BY ID", caseId)
    while rs.%Next() { set out = out_$select(out = "": "", 1: ",")_rs.Kind }
    quit out
}

ClassMethod Command(actor As %String, case As SignalNoir.Application.Store.Case, target As %String, facts As %DynamicObject = "") As SignalNoir.Core.TransitionCommand
{
    set:facts="" facts = {}
    set command = ##class(SignalNoir.Core.TransitionCommand).%New()
    set command.Actor = actor, command.RequestedState = target
    set command.ExpectedState = case.State, command.ExpectedCaseVersion = case.CaseVersion
    set command.Facts = facts
    quit command
}

}
