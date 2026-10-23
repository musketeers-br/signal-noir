/// The Core accepts exactly the 29 rows of contracts/case-state-machine.yaml and refuses every
/// (state, target) pair outside them (specs/002 FR-012, SC-001).
Class SignalNoir.Tests.Core.Parity Extends %UnitTest.TestCase
{

Method TestEveryRowAccepted()
{
    set rows = ##class(SignalNoir.Tests.Core.TableFixture).Load().transitions
    set it = rows.%GetIterator()
    while it.%GetNext(.i, .row) {
        do ##class(SignalNoir.Tests.Core.SnapshotBuilder).Build(row, .snapshot, .command)
        set decision = ##class(SignalNoir.Core.Decider).Decide(snapshot, command, ##class(SignalNoir.Tests.Core.SnapshotBuilder).#NOW)
        if '$$$AssertEquals(decision.Kind, "Accepted", row.id_" accepted ("_decision.RefusalCode_")") continue
        do $$$AssertEquals(decision.TransitionId, row.id, row.id_" chosen")
        do $$$AssertEquals(decision.ToState, row.to, row.id_" target")
        set first = decision.Events.%Get(0)
        do $$$AssertEquals(first.type, "StateChanged", row.id_" StateChanged first")
        do $$$AssertEquals(first.payload.caseVersionAfter, snapshot.CaseVersion + 1, row.id_" caseVersionAfter")
        do $$$AssertEquals(first.payload.from, snapshot.State, row.id_" StateChanged.from")
        do $$$AssertEquals(first.payload.to, row.to, row.id_" StateChanged.to")
        set others = []
        for k = 1:1:decision.Events.%Size() - 1 { do others.%Push(decision.Events.%Get(k).type) }
        do $$$AssertEquals(..Joined(others), ..Joined(row.events), row.id_" events")
        do $$$AssertEquals(..Joined(decision.Outbox), ..Joined(row.followUp.outbox), row.id_" outbox")
        do $$$AssertEquals(..Joined(decision.SameStep), ..Joined(row.sameStepAs), row.id_" same step")
    }
}

Method TestPairsOutsideTableRefused()
{
    set table = ##class(SignalNoir.Tests.Core.TableFixture).Load()
    set it = table.transitions.%GetIterator()
    while it.%GetNext(.i, .row) { set listed($select(row.%GetTypeOf("from") = "null": "-", 1: row.from), row.to) = "" }
    set sit = table.states.%GetIterator()
    while sit.%GetNext(.i, .from) {
        set tit = table.states.%GetIterator()
        while tit.%GetNext(.j, .to) {
            continue:$data(listed(from.name, to.name))
            set snapshot = ##class(SignalNoir.Core.CaseSnapshot).%New()
            set snapshot.CaseId = "case_pairs", snapshot.State = from.name, snapshot.CaseVersion = 3
            set command = ##class(SignalNoir.Core.TransitionCommand).%New()
            set command.RequestedState = to.name, command.Actor = "system"
            set command.ExpectedState = from.name, command.ExpectedCaseVersion = 3
            set decision = ##class(SignalNoir.Core.Decider).Decide(snapshot, command, ##class(SignalNoir.Tests.Core.SnapshotBuilder).#NOW)
            do $$$AssertEquals(decision.Kind_"/"_decision.RefusalCode, "Refused/INVALID_TRANSITION", from.name_" -> "_to.name_" refused")
        }
    }
}

ClassMethod Joined(array) As %String
{
    if '$isobject(array) quit ""
    set out = "", it = array.%GetIterator()
    while it.%GetNext(.i, .value) { set out = out_$select(out = "": "", 1: ",")_value }
    quit out
}

}
