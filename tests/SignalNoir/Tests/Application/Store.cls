/// Stored records: one non-terminal Case per Order (unique index on OpenOrderKey, specs/002
/// research R7) and an append-only Timeline.
Class SignalNoir.Tests.Application.Store Extends %UnitTest.TestCase
{

Method OnBeforeOneTest(testname As %String) As %Status
{
    quit ##class(SignalNoir.Tests.Application.Fixtures).Purge("TEST-STORE-")
}

Method TestOneNonTerminalCasePerOrder()
{
    set first = ..NewCase("TEST-STORE-1")
    do $$$AssertStatusOK(first.%Save(), "first open Case saved")
    set second = ..NewCase("TEST-STORE-1")
    do $$$AssertStatusNotOK(second.%Save(), "second open Case for the same Order refused")
    set first.State = "Resolved"
    do $$$AssertStatusOK(first.%Save(), "first Case closed")
    set third = ..NewCase("TEST-STORE-1")
    do $$$AssertStatusOK(third.%Save(), "new Case accepted once the previous one is terminal")
}

Method TestTimelineSeqIncreases()
{
    set case = ..NewCase("TEST-STORE-2")
    do $$$AssertStatusOK(case.%Save())
    set last = 0
    for i = 1:1:3 {
        set sc = ##class(SignalNoir.Application.Store.TimelineEvent).Append(case.CaseId, "Annotation", "system", "", "{}", .event)
        do $$$AssertStatusOK(sc, "event "_i_" appended")
        do $$$AssertTrue(event.Seq > last, "seq "_event.Seq_" > "_last)
        set last = event.Seq
    }
}

Method TestTimelineIsAppendOnly()
{
    set case = ..NewCase("TEST-STORE-3")
    do $$$AssertStatusOK(case.%Save())
    do $$$AssertStatusOK(##class(SignalNoir.Application.Store.TimelineEvent).Append(case.CaseId, "Annotation", "system", "", "{}", .event))
    set id = event.%Id()
    set reopened = ##class(SignalNoir.Application.Store.TimelineEvent).%OpenId(id)
    set reopened.Type = "StateChanged"
    do $$$AssertStatusNotOK(reopened.%Save(), "an existing event cannot be changed")
    do $$$AssertStatusNotOK(##class(SignalNoir.Application.Store.TimelineEvent).%DeleteId(id), "an event cannot be deleted")
}

ClassMethod NewCase(orderId As %String) As SignalNoir.Application.Store.Case
{
    set case = ##class(SignalNoir.Application.Store.Case).%New()
    set case.CaseId = ##class(SignalNoir.Application.Store.Case).NewId()
    set case.OrderId = orderId
    set case.State = "Open"
    set case.CaseVersion = 1
    quit case
}

}
