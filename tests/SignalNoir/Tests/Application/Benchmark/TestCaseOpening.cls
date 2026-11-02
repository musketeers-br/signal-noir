Class SignalNoir.Tests.Application.Benchmark.TestCaseOpening Extends %UnitTest.TestCase
{

/// 010 T016 - a Case copies its run's mode when it opens, and only when the run is
/// running (FR-003, plan D2). Without a valid run it is the Agent's and carries no
/// benchmark mark.
ClassMethod Service(directory As SignalNoir.Core.Port.RunDirectory) As SignalNoir.Application.CaseService
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set svc.Runs = directory
	Return svc
}

ClassMethod Run(id As %String, mode As %String, status As %String = "running") As %DynamicObject
{
	Return {"runId": (id), "mode": (mode), "status": (status), "purpose": "benchmark", "policyVersion": "", "mappingVersion": ""}
}

Method TestARunningRulesRunMakesRulesCases()
{
	Set dir = ##class(SignalNoir.Tests.Fakes.FakeRunDirectory).%New()
	Do dir.Add(..Run("run_open_rules", "rules"))
	Set svc = ..Service(dir)
	Set caseId = ##class(SignalNoir.Tests.Support).OpenCase(svc, ##class(SignalNoir.Tests.Support).Uid("co-rules"), "run_open_rules")
	Set rec = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(caseId)
	Do $$$AssertEquals(rec.runId, "run_open_rules", "the Case carries the run")
	Do $$$AssertEquals(rec.proposerMode, "rules", "and its mode")
	Do $$$AssertEquals(rec.replay, 0, "a rules run is not a replay")
}

Method TestARunningAgentRunMakesAgentCases()
{
	Set dir = ##class(SignalNoir.Tests.Fakes.FakeRunDirectory).%New()
	Do dir.Add(..Run("run_open_agent", "agent"))
	Set caseId = ##class(SignalNoir.Tests.Support).OpenCase(..Service(dir), ##class(SignalNoir.Tests.Support).Uid("co-agent"), "run_open_agent")
	Set rec = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(caseId)
	Do $$$AssertEquals(rec.runId, "run_open_agent", "run")
	Do $$$AssertEquals(rec.proposerMode, "agent", "mode")
}

Method TestAReplayRunMakesReplayCases()
{
	Set dir = ##class(SignalNoir.Tests.Fakes.FakeRunDirectory).%New()
	Do dir.Add(..Run("run_open_replay", "replay"))
	Set caseId = ##class(SignalNoir.Tests.Support).OpenCase(..Service(dir), ##class(SignalNoir.Tests.Support).Uid("co-replay"), "run_open_replay")
	Set rec = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(caseId)
	Do $$$AssertEquals(rec.proposerMode, "replay", "mode")
	Do $$$AssertEquals(rec.replay, 1, "labelled as replay")
}

Method TestWithoutAValidRunTheCaseIsTheAgentsAndUnmarked()
{
	Set dir = ##class(SignalNoir.Tests.Fakes.FakeRunDirectory).%New()
	Do dir.Add(..Run("run_open_done", "rules", "completed"))
	Do dir.Add(..Run("run_open_failed", "rules", "failed"))
	Do dir.Add(..Run("run_open_created", "rules", "created"))
	Set svc = ..Service(dir)
	For id = "", "run_open_unknown", "run_open_done", "run_open_failed", "run_open_created" {
		Set orderId = ##class(SignalNoir.Tests.Support).Uid("co-none")
		Set caseId = ##class(SignalNoir.Tests.Support).OpenCase(svc, orderId, id)
		Set rec = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(caseId)
		Set label = $Select(id = "": "no run id", 1: id)
		Do $$$AssertEquals(rec.runId, "", label _ ": no run on the Case")
		Do $$$AssertEquals(rec.proposerMode, "agent", label _ ": mode agent")
		Do $$$AssertEquals(rec.replay, 0, label _ ": not a replay")
		Set order = ##class(SignalNoir.Application.Model.OrderRecord).%OpenId(orderId)
		Do $$$AssertEquals(order.runId, id, label _ ": the raw id stays on the Order")
	}
}

}
