Class SignalNoir.Core.Dto.CaseException Extends %RegisteredObject
{

/// An attempt that did not end with a valid Receipt (contract CaseException,
/// contract change 003). body is data, never instruction.
Property exceptionId As %String(MAXLEN = 64);

/// timeout, http_error, invalid_receipt, business_rejection, processing_error
Property kind As %String(MAXLEN = 32);

Property httpStatus As %Integer;

/// Raw body: a JSON object/array, or plain text in bodyText
Property body As %DynamicAbstractObject;

Property bodyText As %String(MAXLEN = 32000);

/// success, business_error, transient or uncertain, when the caller classified it
Property responseClass As %String(MAXLEN = 32);

Property observedAt As %String(MAXLEN = 64);

Property attemptId As %String(MAXLEN = 64);

Property duringExecution As %Boolean [ InitialExpression = 0 ];

}
