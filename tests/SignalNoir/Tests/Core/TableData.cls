/// The Core's compiled table holds the same rows, attachment matrix and parameters as
/// contracts/case-state-machine.yaml (via the generated TableFixture, specs/002 research R3).
Class SignalNoir.Tests.Core.TableData Extends %UnitTest.TestCase
{

Method TestSameTransitionRows()
{
    set fixture = ##class(SignalNoir.Tests.Core.TableFixture).Load().transitions
    set core = ##class(SignalNoir.Core.TransitionTable).AllRows()
    do $$$AssertEquals(core.%Size(), fixture.%Size(), "row count")
    set it = fixture.%GetIterator()
    while it.%GetNext(.i, .expected) {
        set row = ##class(SignalNoir.Core.TransitionTable).Row(expected.id)
        if '$$$AssertTrue($isobject(row), expected.id_" exists in the Core table") continue
        do $$$AssertEquals(row.from, expected.from, expected.id_" from")
        do $$$AssertEquals(row.to, expected.to, expected.id_" to")
        do $$$AssertEquals(..Sorted(row.actors), ..Sorted(expected.actors), expected.id_" actors")
        do $$$AssertEquals(..Joined(row.events), ..Joined(expected.events), expected.id_" events")
        do $$$AssertEquals(..Joined(row.outbox), ..Joined(expected.followUp.outbox), expected.id_" outbox")
        do $$$AssertEquals(..Joined(row.sameStepAs), ..Joined(expected.sameStepAs), expected.id_" sameStepAs")
        do $$$AssertEquals(..Preconditions(row.preconditions), ..Preconditions(expected.preconditions), expected.id_" preconditions")
    }
}

Method TestSameAttachmentMatrix()
{
    set fixture = ##class(SignalNoir.Tests.Core.TableFixture).Load()
    set states = fixture.states
    set it = fixture.attachments.%GetIterator()
    while it.%GetNext(.i, .attachment) {
        set sit = states.%GetIterator()
        while sit.%GetNext(.j, .state) {
            set expected = ..Listed(attachment.states, state.name)
            do $$$AssertEquals(##class(SignalNoir.Core.TransitionTable).AttachmentAllowed(attachment.event, state.name), expected, attachment.event_" in "_state.name)
        }
        if attachment.%IsDefined("terminalKinds") {
            do $$$AssertEquals(..Sorted(##class(SignalNoir.Core.TransitionTable).TerminalKinds(attachment.event)), ..Sorted(attachment.terminalKinds), attachment.event_" terminal kinds")
        }
    }
}

Method TestSameParameters()
{
    set parameters = ##class(SignalNoir.Tests.Core.TableFixture).Load().parameters
    set it = parameters.%GetIterator()
    while it.%GetNext(.name, .value) {
        do $$$AssertEquals(##class(SignalNoir.Core.TransitionTable).Parameter(name), value, "parameter "_name)
    }
}

ClassMethod Listed(states As %DynamicArray, name As %String) As %Boolean
{
    set found = 0, it = states.%GetIterator()
    while it.%GetNext(.i, .state) {
        if (state = "*") || (state = name) { set found = 1  quit }
    }
    quit found
}

ClassMethod Joined(array) As %String
{
    if '$isobject(array) quit ""
    set out = "", it = array.%GetIterator()
    while it.%GetNext(.i, .value) { set out = out_$select(out = "": "", 1: ",")_value }
    quit out
}

ClassMethod Sorted(array) As %String
{
    if '$isobject(array) quit ""
    set it = array.%GetIterator()
    while it.%GetNext(.i, .value) { set sorted(value) = "" }
    set out = "", key = ""
    for {
        set key = $order(sorted(key))
        quit:key=""
        set out = out_$select(out = "": "", 1: ",")_key
    }
    quit out
}

/// Preconditions as "check=expected" pairs, expected serialized as JSON.
ClassMethod Preconditions(array) As %String
{
    if '$isobject(array) quit ""
    set out = "", it = array.%GetIterator()
    while it.%GetNext(.i, .pre) {
        set holder = {}
        set type = pre.%GetTypeOf("expected")
        if (type = "array") || (type = "object") { do holder.%Set("v", pre.%Get("expected")) } else { do holder.%Set("v", pre.%Get("expected"), type) }
        set out = out_$select(out = "": "", 1: ";")_pre.check_"="_holder.%ToJSON()
    }
    quit out
}

}
