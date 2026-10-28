Class SignalNoir.Tests.Application.TestCommandBus Extends %UnitTest.TestCase
{

/// 007 T012 - the single entry point handles each request once
ClassMethod Bus() As SignalNoir.Application.CommandBus
{
	Set bus = ##class(SignalNoir.Application.CommandBus).Default()
	Set bus.Investigations = "none"
	Return bus
}

ClassMethod Last(caseId As %String, type As %String) As %String
{
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 commandId FROM SignalNoir_Application_Model.OutboxRecord WHERE caseId = ? AND type = ? ORDER BY createdAt DESC, commandId DESC", caseId, type)
	Return $Select(rs.%Next(): rs.%Get("commandId"), 1: "")
}

ClassMethod Status(commandId As %String) As %String
{
	Set o = ##class(SignalNoir.Application.Model.OutboxRecord).%OpenId(commandId)
	Do o.%Reload()
	Return o.status
}

Method TestReassessAfterDenials()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(S, "PendingCase", svc, "bus-deny")
	Do $$$AssertTrue($ClassMethod(S, "Decide", svc, caseId, "denied", "Carla", "wrong mapping").ok, "first denial")
	Set cmd = ..Last(caseId, "Reassess")
	Set r = ..Bus().Deliver(cmd)
	Do $$$AssertTrue(r.ok, "delivered: " _ r.message)
	Do $$$AssertEquals(r.details.status, "done", "processed")
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "Investigating", "a new investigation")
	Set inv = ..Last(caseId, "Investigate")
	Set o = ##class(SignalNoir.Application.Model.OutboxRecord).%OpenId(inv)
	Do $$$AssertEquals({}.%FromJSON(o.payloadJson).rejectionReason, "wrong mapping", "the reason travels")
	Do $$$AssertEquals(..Status(cmd), "done", "request done")
	; second round ends in review
	For step = "DecisionProposed:agent", "PendingApproval:system" Do $ClassMethod(S, "Step", svc, caseId, step)
	Do $ClassMethod(S, "FixtureProposal", caseId)
	Do $$$AssertTrue($ClassMethod(S, "Decide", svc, caseId, "denied", "Carla", "still wrong").ok, "second denial")
	Set before = $ClassMethod(S, "Count", "SELECT COUNT(*) FROM SignalNoir_Application_Model.OutboxRecord WHERE caseId = ? AND type = 'Investigate'", caseId)
	Set r = ..Bus().Deliver(..Last(caseId, "Reassess"))
	Do $$$AssertEquals(r.details.status, "done", "processed")
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "ReviewRequired", "second denial -> review")
	Do $$$AssertEquals(c.dossier.reason, "second_denial", "with its Dossier")
	Do $$$AssertEquals($ClassMethod(S, "Count", "SELECT COUNT(*) FROM SignalNoir_Application_Model.OutboxRecord WHERE caseId = ? AND type = 'Investigate'", caseId), before, "no new investigation")
}

Method TestDeliveredOnce()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(S, "PendingCase", svc, "bus-once")
	Do $ClassMethod(S, "Decide", svc, caseId, "denied", "Carla", "no")
	Set cmd = ..Last(caseId, "Reassess")
	Set v = svc.GetCase(caseId).obj.caseVersion
	Do $$$AssertEquals(..Bus().Deliver(cmd).details.status, "done", "first delivery")
	Set again = ..Bus().Deliver(cmd)
	Do $$$AssertTrue(again.ok, "second delivery answers")
	Do $$$AssertEquals(again.details.status, "already done", "and does nothing")
	Do $$$AssertEquals(svc.GetCase(caseId).obj.caseVersion, v + 1, "one transition only")
}

Method TestConcurrentDeliveries()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(S, "PendingCase", svc, "bus-race")
	Do $ClassMethod(S, "Decide", svc, caseId, "denied", "Carla", "no")
	Set cmd = ..Last(caseId, "Reassess")
	Set v = svc.GetCase(caseId).obj.caseVersion
	Set key = $ClassMethod(S, "Uid", "busrace")
	Kill ^SignalNoir.TestBarrier(key)
	For i = 1 : 1 : 3 Job ##class(SignalNoir.Tests.Application.TestCommandBus).RaceDeliver(key, cmd)
	Hang 0.3
	Set ^SignalNoir.TestBarrier(key) = 1
	Do $$$AssertEquals($ClassMethod(S, "WaitResults", key, 3), 3, "three answers")
	Set done = 0, j = ""
	For {
		Set j = $Order(^SignalNoir.TestRace(key, j), 1, st)
		Quit:j=""
		If st = "done" Set done = done + 1
	}
	Do $$$AssertEquals(done, 1, "processed by exactly one delivery")
	Do $$$AssertEquals(svc.GetCase(caseId).obj.caseVersion, v + 1, "one transition")
	Kill ^SignalNoir.TestBarrier(key)
}

ClassMethod RaceDeliver(key As %String, commandId As %String)
{
	For i = 1 : 1 : 500 {
		Quit:$Get(^SignalNoir.TestBarrier(key))
		Hang 0.01
	}
	Set r = ..Bus().Deliver(commandId)
	Set ^SignalNoir.TestRace(key, $JOB) = $Select(r.ok: r.details.status, 1: "ERR:" _ r.code)
}

Method TestStaleRequestDiscarded()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(S, "PendingCase", svc, "bus-stale")
	Do $ClassMethod(S, "Decide", svc, caseId, "denied", "Carla", "no")
	Set cmd = ..Last(caseId, "Reassess")
	; the Case moves on before the request is processed (003's direct path)
	Do svc.ResolveRejection(caseId, svc.GetCase(caseId).obj.caseVersion, "no")
	Set v = svc.GetCase(caseId).obj.caseVersion
	Set r = ..Bus().Deliver(cmd)
	Do $$$AssertEquals(r.details.status, "discarded", "discarded")
	Do $$$AssertEquals(..Status(cmd), "discarded", "recorded as discarded")
	Do $$$AssertEquals(svc.GetCase(caseId).obj.caseVersion, v, "nothing else happened")
	Do $$$AssertTrue($ClassMethod(S, "Types", svc, caseId) [ "CommandDiscarded", "the Timeline says why")
}

Method TestRequestWithoutHandlerWaits()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(S, "PendingCase", svc, "bus-exec")
	Do $ClassMethod(S, "Decide", svc, caseId)
	Set cmd = ..Last(caseId, "Execute")
	Set r = ..Bus().Deliver(cmd)
	Do $$$AssertTrue(r.ok, "answers")
	Do $$$AssertEquals(r.details.status, "waiting", "waits for its handler (008)")
	Do $$$AssertEquals(..Status(cmd), "pending", "left pending")
	Do $$$AssertEquals(..Bus().Deliver("cmd_nope").code, "NOT_FOUND", "unknown request")
}

}
