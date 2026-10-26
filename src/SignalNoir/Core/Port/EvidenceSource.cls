Class SignalNoir.Core.Port.EvidenceSource Extends %RegisteredObject [ Abstract ]
{

/// Internal port of feature 006: reads one reading Tool's data from its
/// source. Result.obj = {"available": true, "result": ...} or
/// {"available": false, "reason": "..."}. Never writes.
Method Read(toolName As %String, args As %DynamicObject) As SignalNoir.Core.Result
{
	Return ##class(SignalNoir.Core.Result).Error("", "Abstract port method - override in adapter or fake")
}

}
