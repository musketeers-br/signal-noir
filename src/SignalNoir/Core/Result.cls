Class SignalNoir.Core.Result Extends %RegisteredObject
{

/// Realization of the seam's Result<T>: a method returns either the value or
/// an error from the closed vocabulary - never raises across the seam.
/// Failures carry code "" only for internal (non-contract) failures.

Property ok As %Boolean [ InitialExpression = 0 ];

/// Error code from the closed vocabulary (Vocab.ErrorCodes) or the
/// Dossier-reason value provider_unavailable; empty when ok or internal.
Property code As %String;

Property message As %String;

/// Value when the value is an opaque id (caseId, receiptId, ...)
Property ref As %String;

/// Value when the value is a DTO
Property obj As %RegisteredObject;

/// Value when the value is a list of DTOs
Property list As %ListOfObjects;

ClassMethod OkRef(ref As %String) As SignalNoir.Core.Result
{
	Set r = ..%New()
	Set r.ok = 1
	Set r.ref = ref
	Return r
}

ClassMethod OkObj(obj As %RegisteredObject) As SignalNoir.Core.Result
{
	Set r = ..%New()
	Set r.ok = 1
	Set r.obj = obj
	Return r
}

ClassMethod OkList(list As %ListOfObjects) As SignalNoir.Core.Result
{
	Set r = ..%New()
	Set r.ok = 1
	Set r.list = list
	Return r
}

ClassMethod Error(code As %String, message As %String) As SignalNoir.Core.Result
{
	Set r = ..%New()
	Set r.ok = 0
	Set r.code = code
	Set r.message = message
	Return r
}

}
