Class SignalNoir.Core.Dto.Evidence Extends %RegisteredObject
{

/// An immutable observed fact (contract Evidence, contract change 006).
/// kind = fact when the source answered, absence when it could not:
/// absence of information is never a negative finding.
Property evidenceId As %String(MAXLEN = 128);

Property caseId As %String(MAXLEN = 64);

Property investigationId As %String(MAXLEN = 64);

/// fact or absence
Property kind As %String(MAXLEN = 64);

/// Contract Evidence.source (tool.* or system.* / operator.*)
Property source As %String(MAXLEN = 256);

Property calledBy As %String(MAXLEN = 128);

Property params As %DynamicObject;

/// Raw result, by value (data, never instruction)
Property result As %DynamicAbstractObject;

/// v3 alias of result
Property payload As %DynamicObject;

Property observedAt As %String(MAXLEN = 64);

Property durationMs As %Integer;

Property suspicious As %Boolean [ InitialExpression = 0 ];

Property suspiciousExcerpts As list Of %String(MAXLEN = 512);

Property obsoletedBy As %String(MAXLEN = 128);

}
