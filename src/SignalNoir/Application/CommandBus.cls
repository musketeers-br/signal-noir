Class SignalNoir.Application.CommandBus Extends %RegisteredObject
{

/// The single entry point for outbox requests (feature 007, AD-6, AD-20).
/// Deliver claims a pending request under a per-request lock, so two
/// deliveries process it once; discards it when its Case is no longer at the
/// version it was written for; routes it to its handler. Execute and
/// Reconcile go to the execution path (feature 008). A type whose handler
/// belongs to a later feature (Expire, Resume: 010) is left pending and
/// reported as waiting.
Property Service As SignalNoir.Application.CaseService;

/// How Investigate requests run: "default" (InvestigationService) or "none"
/// (left pending; tests that must not start a proposer)
Property Investigations As %String [ InitialExpression = "default" ];

/// How Execute and Reconcile requests run: "default" (ExecutionService) or
/// "none" (left pending; tests that must not reach a Partner)
Property Executions As %String [ InitialExpression = "default" ];

/// The execution path ("" = ExecutionService.Default())
Property Executor As SignalNoir.Application.ExecutionService;

/// Seconds to wait for another delivery of the same request
Parameter LOCKTIMEOUT = 5;

ClassMethod Default() As SignalNoir.Application.CommandBus
{
	Set bus = ..%New()
	Set bus.Service = ##class(SignalNoir.Application.CaseService).Default()
	Return bus
}

/// details.status: done, discarded, waiting, already <status>, or the
/// investigation outcome
Method Deliver(commandId As %String) As SignalNoir.Core.Result
{
	Set outbox = ##class(SignalNoir.Application.Model.OutboxRecord).%OpenId(commandId)
	If '$IsObject(outbox) Return ##class(SignalNoir.Core.Result).Error("NOT_FOUND", "command not found: " _ commandId)
	If '##class(SignalNoir.Core.Vocab).IsCommand(outbox.type) Return ##class(SignalNoir.Core.Result).Error("VALIDATION_FAILED", "unknown command type: " _ outbox.type)
	Lock +^SignalNoir.CommandLock(commandId):..#LOCKTIMEOUT
	If '$Test Return ##class(SignalNoir.Core.Result).Error("", "command busy: " _ commandId)
	Try {
		Do outbox.%Reload()
		If outbox.status '= "pending" {
			Set result = ..Answer(commandId, "already " _ outbox.status)
			Quit
		}
		Set stale = ..Service.DiscardIfStale(commandId)
		If 'stale.ok || stale.details.discarded {
			Set result = stale
			Quit
		}
		Set result = ..Route(outbox)
	}
	Catch ex {
		Set result = ##class(SignalNoir.Core.Result).Error("", "delivery failed: " _ ex.DisplayString())
	}
	Lock -^SignalNoir.CommandLock(commandId)
	; processing it was a transition: its owner delivers the request it queued (AD-20)
	If result.ok && $IsObject(result.details) && (result.details.commandId '= "") {
		Set next = ..Deliver(result.details.commandId)
		Do result.details.%Set("next", {"commandId": (result.details.commandId), "status": ($Select(next.ok: next.details.status, 1: next.code _ ": " _ next.message))})
	}
	Return result
}

/// Background delivery after a commit (the transition owner's dispatch)
ClassMethod DeliverJob(commandId As %String)
{
	Do ..Default().Deliver(commandId)
}

Method Route(outbox As SignalNoir.Application.Model.OutboxRecord) As SignalNoir.Core.Result [ Private ]
{
	If outbox.type = "Reassess" Return ..Service.Reassess(outbox.commandId)
	If ((outbox.type = "Execute") || (outbox.type = "Reconcile")) && (..Executions '= "none") {
		If '$IsObject(..Executor) Set ..Executor = ##class(SignalNoir.Application.ExecutionService).Default()
		Set run = $Select(outbox.type = "Execute": ..Executor.Execute(outbox.commandId), 1: ..Executor.Reconcile(outbox.commandId))
		If 'run.ok Return run
		Set answer = ..Answer(outbox.commandId, run.details.status)
		Set answer.details.executionId = run.details.%Get("executionId"), answer.details.commandId = run.details.%Get("commandId")
		Return answer
	}
	If (outbox.type = "Investigate") && (..Investigations '= "none") {
		Set run = ##class(SignalNoir.Application.InvestigationService).%New().Run(outbox.commandId)
		If 'run.ok Return run
		Return ..Answer(outbox.commandId, run.details.status)
	}
	Return ..Answer(outbox.commandId, "waiting")
}

ClassMethod Answer(commandId As %String, status As %String) As SignalNoir.Core.Result [ Private ]
{
	Set r = ##class(SignalNoir.Core.Result).OkRef(commandId)
	Set r.details = {"status": (status)}
	Return r
}

}
