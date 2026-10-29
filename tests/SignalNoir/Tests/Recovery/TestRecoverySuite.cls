Class SignalNoir.Tests.Recovery.TestRecoverySuite Extends %UnitTest.TestCase
{

/// 008 T027 - the recovery suite (Constitution VI, SC-001..SC-004), live
/// against the Simulator over HTTP. Each case ends by counting the
/// Partner's Receipts for the Order: 0 duplicates. These are platform
/// guarantees, not merit of the Agent (Principle VIII).
Parameter S = "SignalNoir.Tests.Support";

/// Client timeout of the product during the suite (the Simulator outlasts it)
Parameter TIMEOUT = 3;

Property Ready As %Boolean;

Method OnBeforeAllTests() As %Status
{
	Do ##class(SignalNoir.Tests.Sim.ClientTimeout).Set(..#TIMEOUT)
	Set ..Ready = ..Partner().SearchReceipts({"idempotencyKey": "bek_probe"}).ok
	Return $$$OK
}

Method OnAfterAllTests() As %Status
{
	Do ##class(SignalNoir.Tests.Sim.ClientTimeout).Clear()
	Return $$$OK
}

ClassMethod Partner() As SignalNoir.Interop.PartnerHttp
{
	Set p = ##class(SignalNoir.Interop.PartnerHttp).%New()
	Set p.Base = ##class(SignalNoir.Tests.Interop.TestOriginFeed).#SIM, p.TimeoutSeconds = ..#TIMEOUT
	Return p
}

ClassMethod Executor() As SignalNoir.Application.ExecutionService
{
	Return $ClassMethod(..#S, "Executor", ..Partner())
}

/// An emitted Order of a variant, accepted, with a Case approved for RETRY.
/// Returns the caseId; x holds {sci, order}.
ClassMethod ApprovedLive(family As %String, variant As %String, seed As %Integer, timeScale As %Numeric, Output x As %DynamicObject) As %String
{
	Set c = ##class(SignalNoir.Tests.Interop.TestOriginFeed).Post("/scenarios", {"family": (family), "variant": (variant), "seed": (seed), "timeScale": (timeScale)})
	Set e = ##class(SignalNoir.Tests.Interop.TestOriginFeed).Post("/scenarios/" _ c.scenarioInstanceId _ "/emissions", "")
	Set x = {"sci": (c.scenarioInstanceId), "order": (e.emitted.%Get(0).order)}
	Set order = x.order
	Do ##class(SignalNoir.Interop.Service.OrderIn).Accept(order.%ToJSON(), "tx-" _ order.orderId, "", x.sci)
	Set opened = ##class(SignalNoir.Interop.Service.OrderIn).ReportException(order.orderId, "timeout")
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = opened.ref
	Do $ClassMethod(..#S, "Step", svc, caseId, "DecisionProposed:agent")
	Do $ClassMethod(..#S, "FixtureProposal", caseId)
	Do $ClassMethod(..#S, "Step", svc, caseId, "PendingApproval:system")
	Do $ClassMethod(..#S, "Decide", svc, caseId, "approved", "ana")
	Return caseId
}

ClassMethod Receipts(orderId As %String) As %Integer
{
	Return ..Partner().SearchReceipts({"orderId": (orderId)}).obj.items.%Size()
}

ClassMethod Event(sci As %String, type As %String, orderId As %String = "")
{
	Set body = {"type": (type)}
	If orderId '= "" Set body.orderId = orderId
	Do ##class(SignalNoir.Tests.Interop.TestOriginFeed).Post("/scenarios/" _ sci _ "/events", body)
}

Method Skip() As %Boolean [ Private ]
{
	If ..Ready Return 0
	Do $$$LogMessage("skipped: the Simulator is not reachable")
	Return 1
}

Method TestClean()
{
	Quit:..Skip()
	Set caseId = ..ApprovedLive("clean", "clean-success-tune-01", 21, 0.01, .x)
	Do $ClassMethod(..#S, "DeliverLast", $ClassMethod(..#S, "ExecBus", ..Executor()), caseId)
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Do $$$AssertEquals(svc.GetCase(caseId).obj.state, "Resolved", "Resolved")
	Do $$$AssertEquals(..Receipts(x.order.orderId), 1, "1 Receipt")
}

Method TestLostResponse()
{
	Quit:..Skip()
	Set caseId = ..ApprovedLive("idempotency", "idempotency-lost-receipt-tune-01", 22, 0.01, .x)
	Set r = $ClassMethod(..#S, "DeliverLast", $ClassMethod(..#S, "ExecBus", ..Executor()), caseId)
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "Resolved", "Resolved: " _ r.details.%ToJSON())
	Do $$$AssertEquals(c.executions.%Get(0).attempts.%Get(0).responseClass, "uncertain", "the answer was lost")
	Do $$$AssertEquals(c.receipt.source, "reconciliation", "reconciliation found the Receipt")
	Do $$$AssertEquals(c.executions.%Get(0).attempts.%Size(), 1, "never resent")
	Do $$$AssertEquals(..Receipts(x.order.orderId), 1, "1 Receipt")
}

Method TestRepeatedClickAndCommand()
{
	Quit:..Skip()
	Set caseId = ..ApprovedLive("idempotency", "idempotency-repeated-approval-tune-01", 23, 0.01, .x)
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	; the second click on the same Proposal is a replay
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertTrue(svc.DecideProposal(caseId, c.currentProposalId, {"decision": "approved", "operator": "ana", "expectedCaseVersion": (c.caseVersion)}).details.replay, "repeated click")
	; the same command three times, two of them at once in other processes
	Set cmd = ##class(SignalNoir.Tests.Application.TestCommandBus).Last(caseId, "Execute")
	Set key = "rec-" _ $Job
	Kill ^SignalNoir.TestRace(key)
	For i = 1, 2 Job ##class(SignalNoir.Tests.Recovery.TestRecoverySuite).DeliverJob(key, cmd)
	Set bus = $ClassMethod(..#S, "ExecBus", ..Executor())
	Do bus.Deliver(cmd)
	Do $ClassMethod(..#S, "WaitResults", key, 2)
	Do $$$AssertEquals(svc.GetCase(caseId).obj.state, "Resolved", "Resolved")
	Do $$$AssertEquals(svc.GetCase(caseId).obj.executions.%Size(), 1, "1 execution")
	Do $$$AssertEquals(..Receipts(x.order.orderId), 1, "1 Receipt")
}

ClassMethod DeliverJob(key As %String, commandId As %String)
{
	Set r = $ClassMethod(..#S, "ExecBus", ..Executor()).Deliver(commandId)
	Set ^SignalNoir.TestRace(key, $Increment(^SignalNoir.TestRace(key))) = $Select(r.ok: r.details.status, 1: r.message)
}

Method TestRestartDuringExecuting()
{
	Quit:..Skip()
	; a slow accept (5 s): the worker is stopped in the middle of the call
	Set caseId = ..ApprovedLive("idempotency", "idempotency-restart-tune-01", 24, 1, .x)
	Set cmd = ##class(SignalNoir.Tests.Application.TestCommandBus).Last(caseId, "Execute")
	Job ##class(SignalNoir.Tests.Recovery.TestRecoverySuite).DeliverJob("restart-" _ $Job, cmd)
	Set pid = $ZChild
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	For i = 1 : 1 : 40 {
		Set c = svc.GetCase(caseId).obj
		If (c.state = "Executing") && (c.executions.%Size() > 0) && (c.executions.%Get(0).attempts.%Size() > 0) Quit
		Hang 0.1
	}
	Hang 0.5
	Do $System.Process.Terminate(pid)
	Hang 0.5
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "Executing", "stopped while Executing")
	; the Partner finishes the accept; then the lease passes and the sweeper steps in
	Hang 5
	Set lease = c.executions.%Get(0).stepLeaseUntil
	Set out = ##class(SignalNoir.Tasks.Sweeper).Run(##class(SignalNoir.Core.ApprovalPolicy).Plus(lease, 1), $ListBuild(caseId), 0, 30, "none", ..Executor())
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "Resolved", "resumed by reconciliation: " _ out.%ToJSON())
	Do $$$AssertEquals(c.executions.%Get(0).leaseGeneration, 2, "under generation 2")
	Do $$$AssertEquals(..Receipts(x.order.orderId), 1, "1 Receipt")
}

Method TestLateWorker()
{
	Quit:..Skip()
	Set caseId = ..ApprovedLive("clean", "clean-success-tune-01", 25, 0.01, .x)
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	; generation 1 authorizes and starts an attempt, then goes quiet
	Set c = svc.GetCase(caseId).obj
	Set order = x.order
	Set rv = ##class(SignalNoir.Core.ExecutionPolicy).%New().Revalidate({"now": (svc.Clock.NowUtc()), "health": {"status": "UP"}, "origin": {"status": "active"}, "approval": {"required": false}})
	Set snapshot = {}.%FromJSON(##class(SignalNoir.Application.Model.OrderRecord).%OpenId(order.orderId).snapshotJson)
	Set key = ##class(SignalNoir.Core.EffectKey).Derive(order.orderId, c.partnerId, snapshot)
	Set a = svc.AuthorizeExecution(##class(SignalNoir.Tests.Application.TestCommandBus).Last(caseId, "Execute"), {"revalidation": (rv), "owner": "job:old", "leaseSeconds": 300, "payload": (snapshot), "idempotencyKey": (key)})
	Set executionId = a.details.executionId
	Set s = svc.StartAttempt(executionId, 1, "job:old", 300)
	; the sweeper hands the execution to generation 2, which finishes it
	Set lease = svc.ExecutionJson(executionId).stepLeaseUntil
	Do ##class(SignalNoir.Tasks.Sweeper).Run(##class(SignalNoir.Core.ApprovalPolicy).Plus(lease, 1), $ListBuild(caseId), 0, 30, "none", ..Executor())
	Do $$$AssertEquals(svc.GetCase(caseId).obj.state, "Resolved", "generation 2 resolved it")
	; generation 1 comes back and sends its attempt: the Partner replays, the write is discarded
	Set answer = ..Partner().Deliver(c.partnerId, {"idempotencyKey": (key), "transactionId": (s.details.transactionId), "scenarioInstanceId": (x.sci), "order": (snapshot)})
	Set late = svc.FinishAttempt(executionId, 1, 1, answer, ##class(SignalNoir.Core.ResponseClass).Classify(answer, order.orderId, key), 3)
	Do $$$AssertEquals(late.details.status, "discarded", "the late worker cannot overwrite")
	Do $$$AssertTrue(answer.replayed, "the Partner returned the original Receipt")
	Do $$$AssertEquals(..Receipts(order.orderId), 1, "1 Receipt")
}

Method TestBlockingPreconditions()
{
	Quit:..Skip()
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	For spec = "P3-fails-tune-01:PARTNER_DEGRADES:Held", "P3-maintenance-tune-01:MAINTENANCE_STARTS:Held", "P3-cancelled-tune-01:ORDER_CANCELLED_AT_ORIGIN:Cancelled" {
		Set variant = $Piece(spec, ":", 1), event = $Piece(spec, ":", 2), expected = $Piece(spec, ":", 3)
		Set caseId = ..ApprovedLive("P3", variant, 26, 0.01, .x)
		; the world changes between the approval and the execution
		Do ..Event(x.sci, event, $Select(event = "ORDER_CANCELLED_AT_ORIGIN": x.order.orderId, 1: ""))
		Do $ClassMethod(..#S, "DeliverLast", $ClassMethod(..#S, "ExecBus", ..Executor()), caseId)
		Set c = svc.GetCase(caseId).obj
		Do $$$AssertEquals(c.state, expected, variant _ " -> " _ expected)
		Do $$$AssertEquals(c.executions.%Get(0).attempts.%Size(), 0, variant _ ": no attempt")
		Do $$$AssertEquals(..Receipts(x.order.orderId), 0, variant _ ": 0 Receipts")
	}
}

}
