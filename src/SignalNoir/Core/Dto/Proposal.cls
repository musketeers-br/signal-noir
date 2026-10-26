Class SignalNoir.Core.Dto.Proposal Extends %RegisteredObject
{

/// The immutable decision proposal (contract Proposal, contract change 006).
/// Built only by Core.ProposalShape from a proposer's answer.
Property proposalId As %String(MAXLEN = 128);

Property caseId As %String(MAXLEN = 64);

/// agent, rules, replay or operator:<name> (contract Proposal.author)
Property origin As %String(MAXLEN = 64);

Property createdAt As %String(MAXLEN = 64);

Property current As %Boolean [ InitialExpression = 1 ];

Property supersededBy As %String(MAXLEN = 128);

/// summary, claims[] (text, evidenceIds[]), hypotheses[], conflicts[]
Property diagnosis As %DynamicObject;

Property action As %String(MAXLEN = 64);

/// mappingId, mappingVersion, reason only
Property params As %DynamicObject;

Property scope As %String(MAXLEN = 32) [ InitialExpression = "single_case" ];

/// HIGH, MEDIUM or LOW
Property confidence As %String(MAXLEN = 16);

/// [{check, expected}] from the closed precondition vocabulary
Property preconditions As %DynamicArray;

/// policy, mapping, prompt, model, provider
Property versions As %DynamicObject;

/// durationMs, toolCalls, tokensIn, tokensOut, estCostUsd
Property metrics As %DynamicObject;

/// {receiptId, orderId} or empty
Property priorReceiptCandidate As %DynamicObject;

}
