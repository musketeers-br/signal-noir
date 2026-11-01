Class SignalNoir.Tests.Application.TestMappingExecution Extends %UnitTest.TestCase
{

Parameter S = "SignalNoir.Tests.Support";

/// 004/008 - an approved Mapping reaches the Partner: the execution policy of the product reads the
/// Mapping from the set the Proposal names and sends the Order with its target code. It revalidates
/// against the versions in force, or those a BenchmarkRun pinned for its Cases.
/// The Store's globals and the benchmark runs are saved and restored around each test.
Method OnBeforeOneTest(testname As %String) As %Status
{
	Kill ^||SaveRef
	Merge ^||SaveRef = ^SignalNoir.Reference
	Return $$$OK
}

Method OnAfterOneTest(testname As %String) As %Status
{
	Kill ^SignalNoir.Reference
	Merge ^SignalNoir.Reference = ^||SaveRef
	Kill ^||SaveRef
	&sql(DELETE FROM SignalNoir_Application_Model.BenchmarkRunRecord WHERE runId %STARTSWITH 'run_mapexec_')
	Return $$$OK
}

/// The versions in force, as a Proposal made now records them
ClassMethod InForce() As %DynamicObject
{
	Set ref = ##class(SignalNoir.Application.Reference.Store).InForce().obj
	Return {"policy": (ref.policyVersion), "mapping": (ref.mappingVersion)}
}

ClassMethod Executor(partner) As SignalNoir.Application.ExecutionService
{
	Set ex = $ClassMethod(..#S, "Executor", partner)
	Set ex.Policy = ##class(SignalNoir.Application.ReferenceExecutionPolicy).%New()
	Return ex
}

/// An approved APPLY_APPROVED_MAPPING Case for a GLIC-J Order, with these params, made under these
/// versions (those in force when not given) and, when runId is given, part of that run
ClassMethod ApprovedMapping(svc, tag As %String, params As %DynamicObject, versions As %DynamicObject = "", runId As %String = "") As %String
{
	Set caseId = $ClassMethod(..#S, "OpenCase", svc, $ClassMethod(..#S, "Uid", tag), "", "GLIC-J")
	If runId '= "" {
		Set rec = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(caseId)
		Set rec.runId = runId
		$$$ThrowOnError(rec.%Save())
	}
	Do $ClassMethod(..#S, "DriveTo", svc, caseId, "DecisionProposed")
	; a Proposal is immutable: its params and versions are set when it is created
	Do $ClassMethod(..#S, "FixtureProposal", caseId, "APPLY_APPROVED_MAPPING", params, $Select($IsObject(versions): versions, 1: ..InForce()))
	Set g = svc.GetCase(caseId).obj
	Do svc.Transition(caseId, g.caseVersion, "PendingApproval", "system", $ClassMethod(..#S, "Ev", "test walk"))
	Do $ClassMethod(..#S, "Decide", svc, caseId, "approved", "ana")
	Return caseId
}

Method TestAnApprovedMappingIsSentWithItsTargetCode()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ..ApprovedMapping(svc, "map-exec-ok", {"mappingId": "map_glicj_soro", "mappingVersion": "2026.10.1"})
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Set r = $ClassMethod(..#S, "DeliverLast", $ClassMethod(..#S, "ExecBus", ..Executor(partner)), caseId)
	Do $$$AssertTrue(r.ok, "delivered: " _ r.message)
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "Resolved", "the Case is resolved")
	Do $$$AssertEquals(partner.Deliveries, 1, "one delivery")
	If partner.Sent.%Size() = 0 Quit
	Do $$$AssertEquals(partner.Sent.%Get(0).order.exams.%Get(0).code, "GLIC-S", "the Partner receives the target code")
	Do $$$AssertEquals(partner.Sent.%Get(0).order.orderId, c.orderId, "for the same Order")
	Set ref = partner.Sent.%Get(0).mappingRef
	Do $$$AssertEquals($Select($IsObject(ref): ref.mappingId _ " " _ ref.mappingVersion, 1: ""), "map_glicj_soro 2026.10.1", "the request names the Mapping")
}

Method TestAnUnknownMappingIsHeldNotSent()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ..ApprovedMapping(svc, "map-exec-unknown", {"mappingId": "map_none", "mappingVersion": "2026.10.1"})
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Do $ClassMethod(..#S, "DeliverLast", $ClassMethod(..#S, "ExecBus", ..Executor(partner)), caseId)
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state _ ":" _ partner.Calls.deliver, "Held:0", "held, nothing sent")
	Do $$$AssertTrue(##class(SignalNoir.Application.Model.ExecutionRecord).%OpenId(c.executions.%Get(0).executionId).failureReason [ "map_none is not in Mapping set 2026.10.1", "says why")
}

Method TestAMappingVersionThatMovedOnIsHeld()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set made = ..InForce(), made.mapping = "2026.09.0"
	Set caseId = ..ApprovedMapping(svc, "map-exec-moved", {"mappingId": "map_glicj_soro", "mappingVersion": "2026.10.1"}, made)
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Do $ClassMethod(..#S, "DeliverLast", $ClassMethod(..#S, "ExecBus", ..Executor(partner)), caseId)
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state _ ":" _ partner.Calls.deliver, "Held:0", "made under another Mapping version than the one in force: held, nothing sent")
}

Method TestACaseOfAPinnedRunIsHeldToThePinnedVersions()
{
	Set inForce = ..InForce()
	Set run = ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%New()
	Set run.runId = "run_mapexec_" _ $Job, run.mode = "rules", run.purpose = "benchmark", run.status = "running"
	Set run.policyVersion = inForce.policy, run.mappingVersion = inForce.mapping
	$$$ThrowOnError(run.%Save())
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ..ApprovedMapping(svc, "map-exec-pinned", {"mappingId": "map_glicj_soro", "mappingVersion": (inForce.mapping)}, inForce, run.runId)
	; the versions in force move on after the run pinned its own
	Set store = "SignalNoir.Application.Reference.Store"
	Do $ClassMethod(store, "Load", "SignalNoir.Tests.Application.Reference.Fixtures.Good")
	Do $$$AssertTrue($ClassMethod(store, "SetInForce", "2026.10.2", "2026.10.2").ok, "2026.10.2 is now in force")
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Do $ClassMethod(..#S, "DeliverLast", $ClassMethod(..#S, "ExecBus", ..Executor(partner)), caseId)
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state _ ":" _ partner.Calls.deliver, "Resolved:1", "the run pinned the versions the Proposal was made under: sent")
}

Method TestTheProductUsesThePolicyWithReferenceData()
{
	Do $$$AssertEquals($ClassName(##class(SignalNoir.Application.ExecutionService).Default().Policy), "SignalNoir.Application.ReferenceExecutionPolicy", "Default() sends approved Mappings")
}

}
