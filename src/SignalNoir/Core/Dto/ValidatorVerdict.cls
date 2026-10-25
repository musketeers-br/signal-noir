Class SignalNoir.Core.Dto.ValidatorVerdict Extends %RegisteredObject
{

/// Declared in this slice: verdict is valid / invalid (seam contract)
Property verdict As %String(MAXLEN = 32);

Property reason As %String(MAXLEN = 256);

Property failedPreconditions As %ListOfDataTypes;

}
