Class SignalNoir.Core.Dto.ValidationInput Extends %RegisteredObject
{

/// Everything a Validator call needs, including the clock and the reference data, so the
/// Validator is deterministic and does no I/O (004, contracts/validation-input.md). There is no
/// identity field: the Validator derives it with Core.Identity, so a caller cannot clear it.
Property proposal As SignalNoir.Core.Dto.Proposal;

/// Evidence as recorded by the Tools gateway (006): the DTOs Core.Identity reads
Property evidence As list Of SignalNoir.Core.Dto.Evidence;

/// Raw snapshot of the Case's Order
Property order As %DynamicObject;

Property priorReceiptOrder;

Property attemptCount As %Integer [ InitialExpression = 0 ];

/// inRun, runId, policyVersion, mappingVersion
Property run As %DynamicObject;

Property reference As SignalNoir.Core.Dto.ReferenceData;

/// Revalidate only: values observed right before the send
Property observed;

Property now As %String(MAXLEN = 40);

ClassMethod FromJson(json As %DynamicObject) As SignalNoir.Core.Dto.ValidationInput
{
	If '$IsObject(json) || 'json.%IsA("%Library.DynamicObject") Return ""
	Set in = ..%New()
	Set in.proposal = ..ProposalOf(json.%Get("proposal"))
	If json.%GetTypeOf("evidence") = "array" {
		For i = 0 : 1 : json.evidence.%Size() - 1 {
			If json.evidence.%GetTypeOf(i) = "object" Do in.evidence.Insert(..EvidenceOf(json.evidence.%Get(i)))
		}
	}
	Set in.order = $Select(json.%GetTypeOf("order") = "object": json.order, 1: {})
	Set in.priorReceiptOrder = $Select(json.%GetTypeOf("priorReceiptOrder") = "object": json.priorReceiptOrder, 1: "")
	Set in.attemptCount = +json.%Get("attemptCount")
	Set in.run = $Select(json.%GetTypeOf("run") = "object": json.run, 1: {"inRun": false, "runId": null, "policyVersion": null, "mappingVersion": null})
	Set in.reference = $Select(json.%GetTypeOf("reference") = "object": ##class(SignalNoir.Core.Dto.ReferenceData).FromJson(json.reference), 1: "")
	Set in.observed = $Select(json.%GetTypeOf("observed") = "object": json.observed, 1: "")
	Set in.now = json.%Get("now")
	Return in
}

Method ToJson() As %DynamicObject
{
	Set o = {}
	Set o.proposal = ..ProposalJson()
	Set o.evidence = ..EvidenceJson(), o.order = ..order
	Do ..PutOrNull(o, "priorReceiptOrder", ..priorReceiptOrder)
	Set o.attemptCount = ..attemptCount, o.run = ..run
	Do ..PutOrNull(o, "reference", $Select($IsObject(..reference): ..reference.ToJson(), 1: ""))
	Do ..PutOrNull(o, "observed", ..observed)
	Set o.now = ..now
	Return o
}

ClassMethod EvidenceOf(json As %DynamicObject) As SignalNoir.Core.Dto.Evidence [ Private ]
{
	Set e = ##class(SignalNoir.Core.Dto.Evidence).%New()
	For name = "evidenceId", "caseId", "kind", "source", "obsoletedBy", "observedAt" {
		If json.%GetTypeOf(name) = "string" Set $Property(e, name) = json.%Get(name)
	}
	Set e.suspicious = +json.%Get("suspicious")
	If json.%GetTypeOf("result") '= "unassigned" Set e.result = json.result
	Return e
}

Method EvidenceJson() As %DynamicArray [ Private ]
{
	Set out = []
	For i = 1 : 1 : ..evidence.Count() {
		Set e = ..evidence.GetAt(i)
		Set o = {"evidenceId": (e.evidenceId), "caseId": (e.caseId), "kind": (e.kind), "source": (e.source)}
		If $IsObject(e.result) {
			Set o.result = e.result
		} Else {
			Do o.%Set("result", "", "null")
		}
		Do o.%Set("suspicious", e.suspicious, "boolean")
		If e.obsoletedBy = "" {
			Do o.%Set("obsoletedBy", "", "null")
		} Else {
			Set o.obsoletedBy = e.obsoletedBy
		}
		Do out.%Push(o)
	}
	Return out
}

ClassMethod ProposalOf(json) As SignalNoir.Core.Dto.Proposal [ Private ]
{
	Set p = ##class(SignalNoir.Core.Dto.Proposal).%New()
	If '$IsObject(json) || 'json.%IsA("%Library.DynamicObject") Return p
	Set names = $ListBuild("proposalId", "caseId", "origin", "action", "scope", "confidence")
	Set ptr = 0
	While $ListNext(names, ptr, name) {
		If json.%GetTypeOf(name) = "string" Set $Property(p, name) = json.%Get(name)
	}
	If json.%GetTypeOf("params") = "object" Set p.params = json.params
	If json.%GetTypeOf("preconditions") = "array" Set p.preconditions = json.preconditions
	If json.%GetTypeOf("versions") = "object" Set p.versions = json.versions
	If json.%GetTypeOf("priorReceiptCandidate") = "object" Set p.priorReceiptCandidate = json.priorReceiptCandidate
	Return p
}

Method ProposalJson() As %DynamicObject [ Private ]
{
	Set p = ..proposal, o = {}
	If '$IsObject(p) Return o
	Set o.proposalId = p.proposalId, o.caseId = p.caseId, o.origin = p.origin, o.action = p.action
	Set o.params = $Select($IsObject(p.params): p.params, 1: {})
	Set o.scope = p.scope, o.confidence = p.confidence
	Set o.preconditions = $Select($IsObject(p.preconditions): p.preconditions, 1: [])
	Set o.versions = $Select($IsObject(p.versions): p.versions, 1: {})
	Do ..PutOrNull(o, "priorReceiptCandidate", p.priorReceiptCandidate)
	Return o
}

ClassMethod PutOrNull(o As %DynamicObject, key As %String, value) [ Private ]
{
	If $IsObject(value) {
		Do o.%Set(key, value)
	} Else {
		Do o.%Set(key, "", "null")
	}
}

}
