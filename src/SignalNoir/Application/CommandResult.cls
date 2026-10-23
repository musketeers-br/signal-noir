/// What every caller of the command path receives, as a value (contracts/command-path.md).
Class SignalNoir.Application.CommandResult Extends %RegisteredObject
{

/// Applied, Attached, Refused, IdempotentReplay or Failed.
Property Outcome As %String;

Property CaseId As %String;

Property State As %String;

Property CaseVersion As %Integer;

Property RefusalCode As %String;

/// Timeline seq numbers written.
Property Events As %DynamicArray;

/// Outbox command ids queued.
Property OutboxCommandIds As %DynamicArray;

/// Transitions applied, in order (the chain included).
Property Transitions As %DynamicArray;

/// Infrastructure error text when Outcome = Failed; nothing was recorded.
Property FailureText As %String(MAXLEN = "");

Method %OnNew() As %Status [ Private ]
{
    set ..Events = [], ..OutboxCommandIds = [], ..Transitions = []
    quit $$$OK
}

}
