/// One event of a Case's Timeline. Append-only (Constitution Principle V): rows are inserted by
/// Append and never updated or deleted.
Class SignalNoir.Application.Store.TimelineEvent Extends %Persistent
{

Property CaseId As %String(MAXLEN = 80) [ Required ];

/// Monotonic per Case (from $INCREMENT; gaps are possible after a rollback, order never breaks).
Property Seq As %Integer [ Required ];

Property At As %String(MAXLEN = 40) [ Required ];

Property Type As %String(MAXLEN = 40) [ Required ];

Property Actor As %String(MAXLEN = 80) [ Required ];

Property RefId As %String(MAXLEN = 80);

/// JSON payload.
Property Payload As %String(MAXLEN = "");

Index CaseSeqIdx On (CaseId, Seq) [ Unique ];

/// Appends an event and returns it in event.
ClassMethod Append(caseId As %String, type As %String, actor As %String, refId As %String, payload As %String, Output event As SignalNoir.Application.Store.TimelineEvent, at As %String = "") As %Status
{
    set event = ..%New()
    set event.CaseId = caseId
    set event.Seq = $increment(^SignalNoir.App.TimelineSeq(caseId))
    set event.At = $select(at '= "": at, 1: $zdatetime($ztimestamp, 3, 7, 3))
    set event.Type = type, event.Actor = actor, event.RefId = refId, event.Payload = payload
    quit event.%Save()
}

Trigger AppendOnly [ Event = UPDATE/DELETE, Foreach = row/object ]
{
    set %ok = 0, %msg = "The Timeline is append-only"
}

Storage Default
{
<Data name="TimelineEventDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>CaseId</Value>
</Value>
<Value name="3">
<Value>Seq</Value>
</Value>
<Value name="4">
<Value>At</Value>
</Value>
<Value name="5">
<Value>Type</Value>
</Value>
<Value name="6">
<Value>Actor</Value>
</Value>
<Value name="7">
<Value>RefId</Value>
</Value>
<Value name="8">
<Value>Payload</Value>
</Value>
</Data>
<DataLocation>^SignalNoir.App.TimelineD</DataLocation>
<DefaultData>TimelineEventDefaultData</DefaultData>
<IdLocation>^SignalNoir.App.TimelineD</IdLocation>
<IndexLocation>^SignalNoir.App.TimelineI</IndexLocation>
<StreamLocation>^SignalNoir.App.TimelineS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
