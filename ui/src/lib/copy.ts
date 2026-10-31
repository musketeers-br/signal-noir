// All operator-facing copy for states and server outcomes, from the UX spine (EXPERIENCE.md).
// One place, so waiting, review and uncertainty can be checked to never share wording.
import type { CaseState, ExecutionOutcome } from './api/types';

export type Tone = 'fact' | 'attention' | 'interpretation' | 'hold' | 'success' | 'danger' | 'muted';

export interface StateCopy {
	label: string;
	glyph: string;
	tone: Tone;
	banner: string;
	action?: 'approve' | 'dossier';
}

const STATES: Record<CaseState, StateCopy> = {
	Open: { label: 'Open', glyph: '○', tone: 'fact', banner: 'Exception recorded. The investigation starts shortly.' },
	Investigating: { label: 'Investigating', glyph: '◔', tone: 'fact', banner: 'The agent investigates with read-only tools. Nothing is sent.' },
	DecisionProposed: { label: 'Decision proposed', glyph: '◑', tone: 'fact', banner: 'The validator is checking a proposal.' },
	PendingApproval: {
		label: 'Needs approval',
		glyph: '!',
		tone: 'attention',
		banner: 'Waiting for your approval. Nothing is sent until you approve this exact version.',
		action: 'approve'
	},
	Approved: { label: 'Approved', glyph: '✓', tone: 'fact', banner: 'Preconditions are re-checked right before sending.' },
	Rejected: { label: 'Denied', glyph: '✕', tone: 'attention', banner: 'One more investigation runs with your reason as evidence.' },
	Executing: { label: 'Executing', glyph: '▶', tone: 'fact', banner: 'Sending to the partner with an idempotency key.' },
	Held: {
		label: 'On hold',
		glyph: '⏸',
		tone: 'hold',
		banner: 'A precondition failed before sending, so nothing was sent. The case is re-investigated when the condition clears, and any new action needs a new approval.'
	},
	ReviewRequired: { label: 'Review required', glyph: '⚑', tone: 'attention', banner: 'Automation stopped. The dossier explains why and what you can do.', action: 'dossier' },
	Resolved: { label: 'Resolved', glyph: '✔', tone: 'success', banner: 'The partner receipt confirms delivery.' },
	ResolvedByPriorReceipt: { label: 'Already delivered', glyph: '⧉', tone: 'success', banner: 'The validator confirmed an earlier receipt. Nothing was resent.' },
	Cancelled: { label: 'Cancelled', glyph: '⊘', tone: 'muted', banner: 'No effect was sent.' },
	Failed: { label: 'Failed', glyph: '✖', tone: 'danger', banner: 'No further automatic action follows.' }
};

const OUTCOME_UNKNOWN: StateCopy = {
	label: 'Outcome unknown',
	glyph: '?',
	tone: 'interpretation',
	banner:
		'The outcome is unknown. The partner may already have this order. New sends are blocked, even from a new proposal, until reconciliation finds or rules out a receipt.'
};

/** Chip and banner for a state, with `Executing` + `reconciling` as its own condition. */
export function stateCopy(state: CaseState, outcome?: ExecutionOutcome | null): StateCopy {
	if (state === 'Executing' && outcome === 'reconciling') return OUTCOME_UNKNOWN;
	return STATES[state] ?? { label: state, glyph: '•', tone: 'fact', banner: state };
}

export const ALL_STATES = Object.keys(STATES) as CaseState[];

export const COPY = {
	synthetic: 'SYNTHETIC',
	syntheticData: 'SYNTHETIC DATA',
	themeToDark: 'Switch to dark theme',
	themeToLight: 'Switch to light theme',
	replay: 'REPLAY',
	emptyNeedsYou: 'No case needs a decision from you right now.',
	emptyList: 'No cases match this filter.',
	notYet: 'Not yet. The case has not reached this step.',
	noDiagnosis: 'No interpretation exists. The agent has not produced one.',
	nothingFlagged: 'Nothing flagged.',
	unknownsNote: 'Missing information is listed here. It is not a negative conclusion.',
	caseNotFound: 'Case not found.',
	backToCases: 'Back to cases',
	connectionLost: 'Connection lost, retrying. Data on screen may be stale.',
	possiblyStale: 'Possibly stale',
	nameRequired: 'Type the name you act under before deciding.',
	nameNoColon: 'The name cannot contain ":".',
	reasonRequiredDeny: 'A denial needs a reason. It becomes evidence for the next investigation.',
	reasonRequiredCancel: 'Cancelling needs a reason.',
	approvedToast: 'Approved. Preconditions are re-checked before anything is sent.',
	deniedToast: 'Denied. A new investigation runs with your reason as evidence.',
	replayToast: (by: string) => `Already approved by ${by}. No new effect.`,
	stale: 'This proposal or case changed while you were reviewing it. Nothing was recorded.',
	reviewNewVersion: 'Review the new version',
	invalidTransition: (state: string) => `This case is now ${state}. Nothing was recorded.`,
	invalidActor: 'This name is not allowed to make this decision. Nothing was recorded.',
	network: 'The request may not have reached the server. Nothing is assumed: wait for the next refresh to see whether the case changed.',
	server: 'The server could not handle the request. Nothing is assumed.',
	blocked: 'The validator blocked this. Nothing was executed.',
	resolvedToast: 'Resolution recorded. The case follows the normal checks before any effect.',
	cancelledToast: 'Case cancelled. No effect was sent.'
};

/** Plain-language meaning of validator reason codes (local map until the closed enum lands, F-6). */
const REASONS: Record<string, string> = {
	MAPPING_CONDITION_MISMATCH: "The mapping's condition does not match this order.",
	IDENTITY_UNRESOLVED: 'Confirm the patient identity at the origin first.',
	ACTION_NOT_IN_CATALOG: 'The action is not in the closed catalog.',
	MISSING_EVIDENCE: 'The minimum evidence for this action is missing.',
	PARTNER_UNHEALTHY: 'The partner is not healthy enough to send now.',
	ORDER_NOT_ACTIVE: 'The order is no longer active at the origin.'
};

export function reasonText(code: string): string {
	return REASONS[code] ?? 'No plain-language description for this code yet.';
}
