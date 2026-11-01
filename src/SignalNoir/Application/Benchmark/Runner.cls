Class SignalNoir.Application.Benchmark.Runner Extends %RegisteredObject
{

/// Drives a BenchmarkRun and only observes it (feature 010, plan D4, FR-007). One Step
/// does the next missing thing, from the persisted items, so it can be repeated or
/// resumed after a restart: it creates the scenario instance in the Simulator over its
/// HTTP contract, lets the product's own intake open the Case, and reads the Case. It
/// never approves, never changes a Case and never writes a Proposal: the Approval
/// inside a run is emitted by the process that drives the Case (007). The two product
/// processes it triggers early (the Origin feed read and a sweep scoped to the item's
/// own Case) are the ones that would otherwise run on their schedule.
Property Clock As SignalNoir.Core.Port.Clock;

Property Service As SignalNoir.Application.Benchmark.RunService;

/// Run a sweep scoped to the item's Case at each observation (the scheduled task does
/// it for the product); tests turn it off
Property Sweep As %Boolean [ InitialExpression = 1 ];

/// Seconds a Case may take to decide before the item is "not decided" (plan Q1); empty =
/// 180 for an agent run and 60 otherwise
Property ItemSeconds As %Integer;

/// Seconds a request must have been pending before the sweep redelivers it
Parameter SWEEPGRACE = 3;

Parameter RUNEXTRA = 120;

Method %OnNew() As %Status
{
	Set ..Clock = ##class(SignalNoir.Application.SystemClock).%New()
	Set ..Service = ##class(SignalNoir.Application.Benchmark.RunService).%New()
	Return $$$OK
}

/// Runs a run to its end (one process per run, started by RunService.Create)
ClassMethod Drive(runId As %String)
{
	Set lockName = "^SignalNoir.BenchmarkDrive"
	Lock +@lockName@(runId):0
	If '$Test Quit
	Set runner = ..%New(), failures = 0
	For {
		Try {
			Set r = runner.Step(runId)
			Set failures = 0
			Quit:'r.ok
			Quit:r.details.done
		}
		Catch ex {
			Set failures = failures + 1
			If failures > 20 {
				Do runner.Service.Move(runId, "fail", "runner_error")
				Quit
			}
		}
		Hang 1
	}
	Lock -@lockName@(runId)
}

/// Picks up the runs whose driver is gone (the scheduled task): every running run whose
/// heartbeat is older than graceSeconds is driven again, in a background process (async)
/// or by one inline step (tests). A second driver for the same run exits at once, because
/// Drive holds a lock per run. Returns {redriven}.
ClassMethod Resume(graceSeconds As %Integer = 90, async As %Boolean = 1) As %DynamicObject
{
	Set now = ##class(SignalNoir.Application.SystemClock).%New().NowUtc()
	Set limit = ##class(SignalNoir.Core.ApprovalPolicy).Seconds(now) - graceSeconds
	Set redriven = 0
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT runId, heartbeatAt FROM SignalNoir_Application_Model.BenchmarkRunRecord WHERE status = 'running'")
	While rs.%Next() {
		Set beat = rs.%Get("heartbeatAt")
		If (beat '= "") && (##class(SignalNoir.Core.ApprovalPolicy).Seconds(beat) > limit) Continue
		Set redriven = redriven + 1
		If async {
			Job ..Drive(rs.%Get("runId"))
		} Else {
			Do ..%New().Step(rs.%Get("runId"))
		}
	}
	Return {"redriven": (redriven)}
}

/// One idempotent step. details: {done, status}
Method Step(runId As %String) As SignalNoir.Core.Result
{
	Set rec = ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%OpenId(runId)
	If '$IsObject(rec) Return ##class(SignalNoir.Core.Result).Error("NOT_FOUND", "no such BenchmarkRun: " _ runId)
	If rec.status '= "running" Return ..Result(1, rec.status)
	Set now = ..Clock.NowUtc()
	Set total = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS n FROM SignalNoir_Application_Model.BenchmarkItemRecord WHERE runId = ?", runId)
	Do total.%Next()
	Set budget = (total.%Get("n") * ..SecondsFor(rec)) + ..#RUNEXTRA
	If ##class(SignalNoir.Core.ApprovalPolicy).Seconds(now) > ##class(SignalNoir.Core.ApprovalPolicy).Seconds(##class(SignalNoir.Core.ApprovalPolicy).Plus(rec.createdAt, budget)) {
		Do ..Service.Move(runId, "fail", "deadline")
		Return ..Result(1, "failed")
	}
	Set pending = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 itemNo FROM SignalNoir_Application_Model.BenchmarkItemRecord WHERE runId = ? AND status IN ('planned','opened') ORDER BY itemNo", runId)
	If 'pending.%Next() Return ..Finish(rec)
	Set item = ##class(SignalNoir.Application.Model.BenchmarkItemRecord).%OpenId(runId _ "||" _ pending.%Get("itemNo"))
	If item.status = "planned" {
		Do ..Open(rec, item, now)
	} Else {
		Do ..Observe(rec, item, now)
	}
	Set rec.heartbeatAt = ..Clock.NowUtc()
	$$$ThrowOnError(rec.%Save())
	Return ..Result(0, rec.status)
}

/// Creates the instance (once), emits its Orders, lets the intake read the feed, and
/// finds the Case the Order opened. A scenario that raises no exception opens no Case:
/// the item ends at once (a control).
Method Open(rec As SignalNoir.Application.Model.BenchmarkRunRecord, item As SignalNoir.Application.Model.BenchmarkItemRecord, now As %String) [ Private ]
{
	If item.scenarioInstanceId = "" {
		Set body = {"family": (item.family), "variant": (item.variant), "seed": (item.seed), "runId": (rec.runId), "repetition": (item.repetition)}
		Set created = ##class(SignalNoir.Interop.SimulatorHttp).Call("", "POST", "/scenarios", body, 15)
		If 'created.answered Quit
		If (created.status '= 201) || '$IsObject(created.json) || (created.json.scenarioInstanceId = "") {
			If (created.status >= 400) && (created.status < 500) Do ..Undecided(item, "run_failed")
			Quit
		}
		Set item.scenarioInstanceId = created.json.scenarioInstanceId
		$$$ThrowOnError(item.%Save())
	}
	Set emitted = ##class(SignalNoir.Interop.SimulatorHttp).Call("", "POST", "/scenarios/" _ item.scenarioInstanceId _ "/emissions", {}, 30)
	If 'emitted.answered || '$IsObject(emitted.json) || (emitted.json.%GetTypeOf("emitted") '= "array") Quit
	Do ##class(SignalNoir.Interop.Service.OriginFeed).%New().Poll()
	Set caseId = "", accepted = 0
	For i = 0 : 1 : emitted.json.emitted.%Size() - 1 {
		Set orderId = emitted.json.emitted.%Get(i).order.orderId
		If ##class(SignalNoir.Application.Model.OrderRecord).%ExistsId(orderId) Set accepted = 1
		Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 caseId FROM SignalNoir_Application_Model.CaseRecord WHERE orderId = ? ORDER BY createdAt DESC", orderId)
		If rs.%Next() Set caseId = rs.%Get("caseId")
	}
	If caseId '= "" {
		Set item.caseId = caseId, item.status = "opened"
		; counted from the moment the Case exists, not from the start of the step: the intake
		; may have spent a while on the feed before it
		Set item.deadlineAt = ##class(SignalNoir.Core.ApprovalPolicy).Plus(..Clock.NowUtc(), ..SecondsFor(rec))
	} ElseIf accepted {
		Set item.status = "ended"
	} Else {
		Quit
	}
	$$$ThrowOnError(item.%Save())
}

/// Reads the Case: ended when the automation is over (terminal, Held or ReviewRequired);
/// "not decided" when it has not decided by the deadline
Method Observe(rec As SignalNoir.Application.Model.BenchmarkRunRecord, item As SignalNoir.Application.Model.BenchmarkItemRecord, now As %String) [ Private ]
{
	If ..Sweep {
		Try {
			Do ##class(SignalNoir.Tasks.Sweeper).Run("", $ListBuild(item.caseId), 1, ..#SWEEPGRACE)
		}
		Catch {
		}
	}
	Set case = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(item.caseId)
	If $IsObject(case) && (##class(SignalNoir.Core.Vocab).IsTerminal(case.state) || (case.state = "ReviewRequired") || (case.state = "Held")) {
		Set item.status = "ended"
		$$$ThrowOnError(item.%Save())
		Quit
	}
	If ##class(SignalNoir.Core.ApprovalPolicy).Seconds(now) > ##class(SignalNoir.Core.ApprovalPolicy).Seconds(item.deadlineAt) Do ..Undecided(item, "deadline")
}

Method Undecided(item As SignalNoir.Application.Model.BenchmarkItemRecord, reason As %String) [ Private ]
{
	Set item.status = "not_decided", item.notDecidedReason = reason
	$$$ThrowOnError(item.%Save())
}

/// Every item ended: the run completes
Method Finish(rec As SignalNoir.Application.Model.BenchmarkRunRecord) As SignalNoir.Core.Result [ Private ]
{
	Do ..Service.Move(rec.runId, "complete")
	Return ..Result(1, "completed")
}

Method SecondsFor(rec As SignalNoir.Application.Model.BenchmarkRunRecord) As %Integer [ Private ]
{
	If ..ItemSeconds '= "" Return ..ItemSeconds
	Return $Select(rec.mode = "agent": 180, 1: 60)
}

ClassMethod Result(done As %Boolean, status As %String) As SignalNoir.Core.Result [ Private ]
{
	Set r = ##class(SignalNoir.Core.Result).OkRef(status)
	Set r.details = {"done": (''done), "status": (status)}
	Do r.details.%Set("done", done, "boolean")
	Return r
}

}
