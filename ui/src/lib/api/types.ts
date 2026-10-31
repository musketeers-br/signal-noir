// Types of contracts/openapi-signalnoir.yaml used by the console (no field is invented here).

export type CaseState =
	| 'Open'
	| 'Investigating'
	| 'DecisionProposed'
	| 'PendingApproval'
	| 'Approved'
	| 'Rejected'
	| 'Executing'
	| 'Held'
	| 'ReviewRequired'
	| 'Resolved'
	| 'ResolvedByPriorReceipt'
	| 'Cancelled'
	| 'Failed';

export type Action = 'RETRY' | 'APPLY_APPROVED_MAPPING' | 'REQUEST_REVIEW' | 'HOLD';
export const ACTIONS: Action[] = ['RETRY', 'APPLY_APPROVED_MAPPING', 'REQUEST_REVIEW', 'HOLD'];
export type Confidence = 'HIGH' | 'MEDIUM' | 'LOW';
export type ExecutionOutcome = 'in_progress' | 'reconciling' | 'resolved' | 'held' | 'cancelled' | 'failed';
export type ErrorCode = 'STALE_VERSION' | 'INVALID_TRANSITION' | 'INVALID_ACTOR' | 'VALIDATION_FAILED' | 'NOT_FOUND';

export interface Labels {
	synthetic: true;
	replay: boolean;
}

export interface CaseVersioning {
	caseVersion: number;
	lastEventSeq: number;
	serverTime: string;
}

export interface CaseHeader extends CaseVersioning {
	caseId: string;
	orderId: string;
	partnerId: string;
	state: CaseState;
	labels: Labels;
	proposerMode?: 'agent' | 'rules' | 'replay';
	benchmark?: { runId: string; mode: string } | null;
	createdAt: string;
	lastEventAt: string;
}

export interface CaseSummary extends CaseHeader {
	pendingApproval: boolean;
	approvalDeadline?: string | null;
	currentProposal?: { proposalId: string; action: Action; confidence: Confidence } | null;
	exceptionCount: number;
	lastExceptionSummary?: string;
	executionOutcome?: ExecutionOutcome | null;
}

export interface CaseListPage {
	items: CaseSummary[];
	nextCursor?: string | null;
	headCursor: string;
	serverTime: string;
}

export interface Evidence {
	evidenceId: string;
	source: string;
	calledBy?: string;
	params?: Record<string, unknown>;
	result: unknown;
	observedAt: string;
	durationMs?: number;
	suspicious: boolean;
	suspiciousExcerpts?: string[];
	obsoletedBy?: string | null;
}

export interface Claim {
	text: string;
	evidenceIds: string[];
}

export interface Hypothesis {
	text: string;
	status: 'chosen' | 'discarded';
	reason?: string;
	evidenceIds?: string[];
}

export interface EvidenceConflict {
	evidenceIds: string[];
	description: string;
}

export interface Diagnosis {
	summary: string;
	claims: Claim[];
	hypotheses: Hypothesis[];
	conflicts?: EvidenceConflict[];
}

export interface Precondition {
	check: string;
	expected: unknown;
}

export interface ValidatorVerdict {
	verdict: 'accepted' | 'blocked' | 'review' | 'prior_receipt_confirmed';
	reasons: string[];
	requiresApproval: boolean;
	at?: string;
}

export interface Proposal {
	proposalId: string;
	author: string;
	createdAt: string;
	current: boolean;
	supersededBy?: string | null;
	diagnosis: Diagnosis;
	action: Action;
	params: { mappingId?: string; mappingVersion?: string; reason?: string };
	scope: 'single_case';
	confidence: Confidence;
	preconditions: Precondition[];
	priorReceiptCandidate?: { receiptId: string; orderId: string } | null;
	versions: { policy: string; mapping: string; prompt?: string | null; model?: string | null; provider?: string | null };
	metrics?: { durationMs?: number; toolCalls?: number; tokensIn?: number; tokensOut?: number; estCostUsd?: number };
	validatorVerdict?: ValidatorVerdict | null;
}

export interface Approval {
	approvalId: string;
	proposalId: string;
	decision: 'approved' | 'denied';
	by: string;
	at: string;
	expiresAt?: string | null;
	status?: 'valid' | 'expired' | 'consumed' | 'superseded';
	reason?: string | null;
}

export interface PreconditionResult {
	check: string;
	expected?: unknown;
	observed?: unknown;
	passed: boolean;
	evidenceId?: string | null;
}

export interface Attempt {
	attemptId: string;
	n: number;
	transactionId?: string;
	sentAt: string;
	completedAt?: string | null;
	httpStatus?: number | null;
	responseClass?: string;
	bodyExcerpt?: string;
	receiptId?: string | null;
}

export interface Reconciliation {
	at: string;
	trigger: string;
	queriedBy?: string;
	found: boolean;
	receiptId?: string | null;
	evidenceId?: string | null;
}

export interface Execution {
	executionId: string;
	approvalId?: string | null;
	proposalId: string;
	action: Action;
	idempotencyKey: string;
	authorizedAt: string;
	leaseGeneration?: number;
	revalidation?: { passed: boolean; checks: PreconditionResult[]; at: string; resultingState?: CaseState } | null;
	reconciliations?: Reconciliation[];
	attempts: Attempt[];
	outcome: ExecutionOutcome;
	completedAt?: string | null;
}

export interface ReceiptCopy {
	receiptId: string;
	orderId: string;
	idempotencyKey: string;
	receivedAt: string;
	partnerId: string;
	source: 'delivery' | 'reconciliation' | 'prior_receipt';
	equivalenceConfirmed?: boolean | null;
}

export interface Dossier {
	reason: string;
	reasonText: string;
	createdAt: string;
	partialDiagnosis?: Diagnosis | null;
	hypotheses?: Hypothesis[];
	relevantEvidenceIds?: string[];
	conflicts?: EvidenceConflict[];
	collidingRecords?: { recordRef: string; source?: string; fields: Record<string, unknown>; divergentFields: string[] }[];
	unconfirmedCandidates?: { receiptId: string; orderId: string; mismatchedFields: string[] }[];
	unknowns?: { text: string; topic?: string; relatedEvidenceIds?: string[] }[];
	suggestedNextStep: string;
}

export interface CaseMetrics {
	provider?: string | null;
	model?: string | null;
	promptVersion?: string | null;
	policyVersion?: string;
	mappingVersion?: string;
	investigationDurationMs?: number;
	toolCalls?: number;
	tokensIn?: number;
	tokensOut?: number;
	estCostUsd?: number;
	attempts?: number;
}

export interface CaseException {
	exceptionId: string;
	kind: string;
	httpStatus?: number | null;
	body?: unknown;
	responseClass?: string;
	observedAt: string;
	attemptId?: string | null;
	duringExecution?: boolean;
}

export interface OrderView {
	orderId: string;
	correlationId: string;
	transactionIds: string[];
	snapshot: Record<string, unknown>;
	equivalenceKey: { patientId: string; examCodes: string[]; collectedAt: string; specimenId: string };
}

export interface CaseDetail extends CaseHeader {
	updatedAt: string;
	order: OrderView;
	visualTraceUrl?: string | null;
	exceptions: CaseException[];
	evidence: Evidence[];
	diagnosis?: Diagnosis | null;
	currentProposalId?: string | null;
	proposals: Proposal[];
	approvals: Approval[];
	denialCount?: number;
	executions: Execution[];
	receipt?: ReceiptCopy | null;
	dossier?: Dossier | null;
	metrics: CaseMetrics;
}

export interface TimelineEvent {
	seq: number;
	at: string;
	type: string;
	actor: string;
	refId?: string | null;
	payload?: Record<string, unknown>;
}

export interface TimelinePage extends CaseVersioning {
	caseId: string;
	state: CaseState;
	events: TimelineEvent[];
	hasMore: boolean;
	nextSinceSeq: number;
}

export interface ErrorEnvelope {
	error: { code: ErrorCode; message: string; details?: Record<string, unknown> };
}

export interface CommandAck extends CaseVersioning {
	caseId: string;
	state: CaseState;
	commandId?: string | null;
}

export interface ProposalDecisionResult {
	approval: Approval;
	idempotentReplay: boolean;
	case: CommandAck;
}

export interface ReviewResolutionResult {
	kind: 'action' | 'cancel';
	proposal?: Proposal | null;
	approval?: Approval | null;
	case: CommandAck;
}

export interface ApprovedMapping {
	mappingId: string;
	mappingVersion: string;
	sourceCode: string;
	targetCode: string;
	conditions: Record<string, unknown>;
}

export interface ActionCatalogEntry {
	action: Action;
	externalEffect: boolean;
	requiresApproval: boolean;
	paramsSchema: Record<string, unknown>;
	requiredEvidence: string[];
}

// Contract change 015: similar closed Cases (never Evidence).
export type PrecedentStatus = 'results' | 'no_precedents' | 'nothing_similar' | 'rebuilding' | 'needs_rebuild' | 'unavailable';

export interface PrecedentMatch {
	caseId: string;
	orderId: string;
	partnerId: string;
	description: string;
	action: Action | null;
	finalState: 'Resolved' | 'ResolvedByPriorReceipt' | 'Cancelled' | 'Failed';
	closedAt: string;
	durationSeconds: number;
	similarity: number;
	synthetic: boolean;
	replay: boolean;
}

export interface PrecedentSearch {
	caseId: string;
	status: PrecedentStatus;
	mode: 'lexical' | 'provider';
	model: string;
	dimension: number;
	k: number;
	minSimilarity: number;
	items: PrecedentMatch[];
	reason?: 'provider_unavailable' | 'unsupported_dimension' | 'index_error' | 'model_changed';
	recorded: boolean;
	notice: string;
}
