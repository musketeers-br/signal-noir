// Names the effect of a Proposal in plain words (UX spine: "Name the effect").
import type { ApprovedMapping, CaseDetail, Proposal } from './api/types';

export function effectText(p: Proposal, d: CaseDetail, mappings: ApprovedMapping[] = []): string {
	if (p.action === 'APPLY_APPROVED_MAPPING') {
		const m = mappings.find((x) => x.mappingId === p.params.mappingId && x.mappingVersion === p.params.mappingVersion);
		const change = m ? `Change exam code ${m.sourceCode} → ${m.targetCode}` : `Apply mapping ${p.params.mappingId} v${p.params.mappingVersion}`;
		return `${change}, then resend ${d.orderId} to ${d.partnerId}.`;
	}
	if (p.action === 'RETRY') return `Resend ${d.orderId} to ${d.partnerId} unchanged.`;
	if (p.action === 'HOLD') return `Hold ${d.orderId}. Nothing is sent.`;
	return `Send ${d.orderId} to review. Nothing is sent.`;
}
