Class SignalNoir.Core.Dto.TimelineEvent Extends %RegisteredObject
{

/// Fully populated in this slice (seam contract). seq is monotonic per Case
/// and never reused; payload carries facts only, never secrets.
Property seq As %Integer;
Property at As %String(MAXLEN=64);
Property type As %String(MAXLEN=64);
Property actor As %String(MAXLEN=128);
Property refId As %String(MAXLEN=128);
Property payload As %DynamicObject;

}
