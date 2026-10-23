Class SignalNoir.Application.Model.CaseEventRecord Extends %Persistent
{

/// Append-only timeline row: one row per fact, never updated or deleted.
/// seq is monotonic per Case and never reused. The ID is the compound
/// caseId + seq, so a timeline row is addressed directly.

Property caseId As %String(MAXLEN=64) [ Required ];

Property seq As %Integer [ Required ];

Index eventKey On (caseId, seq) [ Idkey ];

/// ISO-8601 UTC timestamp
Property at As %String(MAXLEN=64);

Property type As %String(MAXLEN=64);

Property actor As %String(MAXLEN=128);

Property refId As %String(MAXLEN=128);

/// Fact payload as JSON; never carries secrets
Property payloadJson As %String(MAXLEN=4096);

}
