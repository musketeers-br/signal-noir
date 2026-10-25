Class SignalNoir.Application.Model.ExceptionRecord Extends %Persistent
{

/// An attempt that did not end with a valid Receipt. Insert-only.
Property exceptionId As %String(MAXLEN = 64) [ Required ];

Index exceptionKey On exceptionId [ IdKey ];

Property caseId As %String(MAXLEN = 64) [ Required ];

Index caseIdx On caseId;

Property orderId As %String(MAXLEN = 128);

/// timeout, http_error, invalid_receipt, business_rejection, processing_error
Property kind As %String(MAXLEN = 32) [ Required ];

Property httpStatus As %Integer;

/// Raw body as JSON (object, array or string); data, never instruction
Property bodyJson As %String(MAXLEN = 32000);

Property responseClass As %String(MAXLEN = 32);

Property observedAt As %String(MAXLEN = 64) [ Required ];

Property attemptId As %String(MAXLEN = 64);

/// Recorded with the Case in Approved or Executing (attachment only)
Property duringExecution As %Boolean [ InitialExpression = 0 ];

Storage Default
{
<Data name="ExceptionRecordDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>caseId</Value>
</Value>
<Value name="3">
<Value>orderId</Value>
</Value>
<Value name="4">
<Value>kind</Value>
</Value>
<Value name="5">
<Value>httpStatus</Value>
</Value>
<Value name="6">
<Value>bodyJson</Value>
</Value>
<Value name="7">
<Value>responseClass</Value>
</Value>
<Value name="8">
<Value>observedAt</Value>
</Value>
<Value name="9">
<Value>attemptId</Value>
</Value>
<Value name="10">
<Value>duringExecution</Value>
</Value>
</Data>
<DataLocation>^SignalNoir70AE.ExceptionReCF5DD</DataLocation>
<DefaultData>ExceptionRecordDefaultData</DefaultData>
<IdLocation>^SignalNoir70AE.ExceptionReCF5DD</IdLocation>
<IndexLocation>^SignalNoir70AE.ExceptionReCF5DI</IndexLocation>
<StreamLocation>^SignalNoir70AE.ExceptionReCF5DS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
