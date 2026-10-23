Class SignalNoir.Core.Dto.Dossier Extends %RegisteredObject
{

/// Declared in this slice so the seam does not change shape later
Property caseId As %String;
Property facts As %DynamicObject;
Property diagnosis As %DynamicObject;
Property missingInformation As %ListOfDataTypes;
Property options As %ListOfDataTypes;

}
