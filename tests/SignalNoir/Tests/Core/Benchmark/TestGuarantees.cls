Class SignalNoir.Tests.Core.Benchmark.TestGuarantees Extends %UnitTest.TestCase
{

Parameter G = "SignalNoir.Core.Benchmark.Guarantees";

/// 010 T039 - the platform guarantees part (FR-020): pass or fail with the evidence, a third
/// state for what the run did not exercise (never a pass), and no comparative score.
ClassMethod Clean() As %DynamicObject
{
	Return {
		"p3": {"exercised": 3, "staleExecutions": 0, "invalidActionsExecuted": 0},
		"idempotency": {"exercised": 12, "duplicateReceipts": 0},
		"timeout": {"exercised": 1, "resentBeforeReconcile": 0},
		"repeatedApproval": {"exercised": 1, "extraEffectiveApprovals": 0},
		"recoverySuite": {"restart": {"passed": true, "commit": "abc1234"}, "lateWorker": {"passed": true, "commit": "abc1234"}}
	}
}

ClassMethod Row(rows As %DynamicArray, name As %String) As %DynamicObject
{
	For i = 0 : 1 : rows.%Size() - 1 {
		If rows.%Get(i).guarantee = name Return rows.%Get(i)
	}
	Return ""
}

Method TestAllSixGuaranteesAreReportedInOrder()
{
	Set rows = $ClassMethod(..#G, "Evaluate", ..Clean())
	Do $$$AssertEquals(rows.%Size(), 6, "six guarantees")
	Set names = ""
	For i = 0 : 1 : 5 Set names = names _ $Select(i: ",", 1: "") _ rows.%Get(i).guarantee
	Do $$$AssertEquals(names, "P3,idempotency,timeout,restart,repeated_approval,late_worker", "in the order of the spec")
	For i = 0 : 1 : 5 Do $$$AssertEquals(rows.%Get(i).passed, 1, rows.%Get(i).guarantee _ " passes")
}

Method TestDuplicateReceiptsFailIdempotency()
{
	Set ev = ..Clean()
	Set ev.idempotency.duplicateReceipts = 2
	Set row = ..Row($ClassMethod(..#G, "Evaluate", ev), "idempotency")
	Do $$$AssertEquals(row.passed, 0, "fails")
	Do $$$AssertEquals(row.duplicateReceipts, 2, "with the evidence")
}

Method TestAStaleExecutionFailsP3()
{
	Set ev = ..Clean()
	Set ev.p3.staleExecutions = 1
	Set row = ..Row($ClassMethod(..#G, "Evaluate", ev), "P3")
	Do $$$AssertEquals(row.passed, 0, "fails")
	Do $$$AssertEquals(row.staleExecutions, 1, "with the evidence")
	Set ev = ..Clean()
	Set ev.p3.invalidActionsExecuted = 1
	Do $$$AssertEquals(..Row($ClassMethod(..#G, "Evaluate", ev), "P3").passed, 0, "an invalid Action executed fails it too")
}

Method TestWhatTheRunDidNotExerciseIsNotAPass()
{
	Set ev = ..Clean()
	Set ev.p3.exercised = 0, ev.idempotency.exercised = 0, ev.timeout.exercised = 0, ev.repeatedApproval.exercised = 0
	Set rows = $ClassMethod(..#G, "Evaluate", ev)
	For name = "P3", "idempotency", "timeout", "repeated_approval" {
		Set row = ..Row(rows, name)
		Do $$$AssertEquals(row.%GetTypeOf("passed"), "null", name _ ": not exercised is null, never a pass")
		Do $$$AssertTrue(row.details [ "not exercised", name _ ": says so")
	}
}

Method TestRestartAndLateWorkerComeFromTheRecoverySuite()
{
	Set rows = $ClassMethod(..#G, "Evaluate", ..Clean())
	Set restart = ..Row(rows, "restart")
	Do $$$AssertEquals(restart.source, "recovery_suite", "source")
	Do $$$AssertEquals(restart.evidenceCommit, "abc1234", "the commit the suite ran on")
	Do $$$AssertEquals(..Row(rows, "P3").source, "run", "the others come from the run")
	Set ev = ..Clean()
	Set ev.recoverySuite = {"restart": {"passed": false, "commit": "abc1234"}, "lateWorker": ""}
	Set rows = $ClassMethod(..#G, "Evaluate", ev)
	Do $$$AssertEquals(..Row(rows, "restart").passed, 0, "a failed suite fails the guarantee")
	Do $$$AssertEquals(..Row(rows, "late_worker").%GetTypeOf("passed"), "null", "no evidence is not a pass")
	Set ev.recoverySuite = ""
	Set rows = $ClassMethod(..#G, "Evaluate", ev)
	Do $$$AssertEquals(..Row(rows, "restart").%GetTypeOf("passed"), "null", "no recovery evidence at all")
}

Method TestThereIsNoComparativeScore()
{
	Set rows = $ClassMethod(..#G, "Evaluate", ..Clean())
	For i = 0 : 1 : rows.%Size() - 1 {
		Set row = rows.%Get(i)
		Do $$$AssertTrue('row.%IsDefined("score") && 'row.%IsDefined("rate") && 'row.%IsDefined("rank"), row.guarantee _ ": pass or fail, no score")
	}
}

}
