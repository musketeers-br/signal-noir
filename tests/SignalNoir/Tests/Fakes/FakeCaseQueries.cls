Class SignalNoir.Tests.Fakes.FakeCaseQueries Extends SignalNoir.Core.Port.CaseQueries
{

/// In-memory reads (seam contract). Usable with no live provider and no
/// database.

Property cases As %ListOfObjects;

Property events As %ListOfObjects;

Method %OnNew() As %Status
{
	Set ..cases = ##class(%ListOfObjects).%New()
	Set ..events = ##class(%ListOfObjects).%New()
	Return $$$OK
}

Method GetCase(caseId As %String) As SignalNoir.Core.Result
{
	For i = 1 : 1 : ..cases.Count() {
		Set dto = ..cases.GetAt(i)
		If dto.caseId = caseId Return ##class(SignalNoir.Core.Result).OkObj(dto)
	}
	Return ##class(SignalNoir.Core.Result).Error("NOT_FOUND", "case not found: " _ caseId)
}

Method GetTimeline(caseId As %String, sinceSeq As %Integer = 0) As SignalNoir.Core.Result
{
	Set list = ##class(%ListOfObjects).%New()
	For i = 1 : 1 : ..events.Count() {
		Set event = ..events.GetAt(i)
		If event.seq > sinceSeq Do list.Insert(event)
	}
	Return ##class(SignalNoir.Core.Result).OkList(list)
}

Method ListCases(cursor As %String = "") As SignalNoir.Core.Result
{
	Set list = ##class(%ListOfObjects).%New()
	For i = 1 : 1 : ..cases.Count() {
		Set dto = ..cases.GetAt(i)
		Set summary = ##class(SignalNoir.Core.Dto.CaseSummary).%New()
		Set summary.caseId = dto.caseId
		Set summary.state = dto.state
		Set summary.caseVersion = dto.caseVersion
		Set summary.lastEventAt = dto.lastEventAt
		Set summary.synthetic = dto.synthetic
		Do list.Insert(summary)
	}
	Return ##class(SignalNoir.Core.Result).OkList(list)
}

}
