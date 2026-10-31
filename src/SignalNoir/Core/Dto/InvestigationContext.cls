Class SignalNoir.Core.Dto.InvestigationContext Extends %RegisteredObject
{

/// What a proposer receives (contract change 006): the Case, its Order, the
/// Evidence collected so far, and the read-only Tools gateway that enforces
/// the budget and records every call. Nothing else is reachable.
Property investigationId As %String(MAXLEN = 64);

Property case As SignalNoir.Core.Dto.Case;

Property order As SignalNoir.Core.Dto.Order;

Property evidence As list Of SignalNoir.Core.Dto.Evidence;

Property tools As SignalNoir.Core.Port.Tools;

Property maxToolCalls As %Integer;

Property budgetMs As %Integer;

Property startedAt As %String(MAXLEN = 64);

/// Seam v5 (contract change 015), optional: similar closed Cases as
/// PrecedentMatch objects, only when SN_PRECEDENTS_AGENT=1. Similarity
/// results, never Evidence: a proposer cannot cite them.
Property precedents As %Library.DynamicArray;

}
