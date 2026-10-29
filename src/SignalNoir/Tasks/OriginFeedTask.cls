Class SignalNoir.Tasks.OriginFeedTask Extends SignalNoir.Tasks.Periodic
{

/// The scheduled read of the Origin's feed (002 gate G1 note 4): every
/// minute, OriginFeed.Poll accepts the new Orders, makes their first
/// delivery and opens the Cases of the ones that fail. The portable
/// Production has no inbound polling of its own, so this task stands in
/// for it.
Parameter TaskName = "Signal Noir origin feed";

Parameter TaskDescription = "Reads the Origin feed and makes the first delivery of each new Order (feature 002)";

Method OnTask() As %Status
{
	Do ##class(SignalNoir.Interop.Service.OriginFeed).%New().Poll()
	Return $$$OK
}

}
