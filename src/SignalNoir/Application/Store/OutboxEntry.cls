/// A work item written in the same transaction as the transition that needs it (AD-20).
/// Dispatching and sweeper redispatch are outside this feature.
Class SignalNoir.Application.Store.OutboxEntry Extends %Persistent
{

Property CommandId As %String(MAXLEN = 80) [ Required ];

/// Investigate, Execute, Reconcile, Expire, Reassess or Resume.
Property Kind As %String(MAXLEN = 20) [ Required ];

Property CaseId As %String(MAXLEN = 80) [ Required ];

Property CaseVersionAfter As %Integer [ Required ];

/// pending, dispatched or done.
Property Status As %String(MAXLEN = 20) [ InitialExpression = "pending" ];

Property CreatedAt As %String(MAXLEN = 40);

Index CommandIdIdx On CommandId [ Unique ];

Index CaseIdx On CaseId;

ClassMethod NewCommandId() As %String
{
    quit "cmd_"_$zconvert($extract($translate($system.Util.CreateGUID(), "-"), 1, 16), "L")
}

Storage Default
{
<Data name="OutboxEntryDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>CommandId</Value>
</Value>
<Value name="3">
<Value>Kind</Value>
</Value>
<Value name="4">
<Value>CaseId</Value>
</Value>
<Value name="5">
<Value>CaseVersionAfter</Value>
</Value>
<Value name="6">
<Value>Status</Value>
</Value>
<Value name="7">
<Value>CreatedAt</Value>
</Value>
</Data>
<DataLocation>^SignalNoir.App.OutboxD</DataLocation>
<DefaultData>OutboxEntryDefaultData</DefaultData>
<IdLocation>^SignalNoir.App.OutboxD</IdLocation>
<IndexLocation>^SignalNoir.App.OutboxI</IndexLocation>
<StreamLocation>^SignalNoir.App.OutboxS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
