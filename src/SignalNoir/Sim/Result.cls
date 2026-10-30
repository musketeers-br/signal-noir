Class SignalNoir.Sim.Result Extends %RegisteredObject
{

/// The Simulator's own result value (Principle VII, research D11). It does
/// not reference SignalNoir.Core: the Simulator is an external system (D10).
/// Only Api.Dispatch turns results into HTTP status codes.
Property ok As %Boolean [ InitialExpression = 0 ];

/// INVALID_REQUEST, NOT_FOUND or IDEMPOTENCY_KEY_REUSED when not ok
Property code As %String;

Property message As %String(MAXLEN = 2000);

Property details As %DynamicObject;

/// The answer (a contract shape) when ok
Property obj As %DynamicAbstractObject;

/// HTTP status of a successful answer (200, 201, 202)
Property status As %Integer [ InitialExpression = 200 ];

ClassMethod Ok(obj As %DynamicAbstractObject, status As %Integer = 200) As SignalNoir.Sim.Result
{
	Set r = ..%New()
	Set r.ok = 1, r.obj = obj, r.status = status
	Return r
}

ClassMethod Error(code As %String, message As %String, details As %DynamicObject = "") As SignalNoir.Sim.Result
{
	Set r = ..%New()
	Set r.code = code, r.message = message
	Set r.details = $Select($IsObject(details): details, 1: {})
	Return r
}

}
