// Every answer to a command maps to exactly one Outcome. Components switch on it and never read
// HTTP statuses themselves, so a refusal, a replay or a lost answer can never pass for success.
import type { Answer } from './transport';
import type { ErrorEnvelope } from './types';

export type Outcome<T> =
	| { kind: 'created'; body: T }
	| { kind: 'replay'; body: T }
	| { kind: 'stale'; message: string; details: Record<string, unknown> }
	| { kind: 'invalidTransition'; message: string; details: Record<string, unknown> }
	| { kind: 'invalidActor'; message: string }
	| { kind: 'badRequest'; message: string; details: Record<string, unknown> }
	| { kind: 'blocked'; message: string; reasons: string[]; details: Record<string, unknown> }
	| { kind: 'notFound'; message: string }
	| { kind: 'network' }
	| { kind: 'server'; status: number; message: string };

function envelope(body: unknown): ErrorEnvelope['error'] | null {
	if (body && typeof body === 'object' && 'error' in body) {
		const e = (body as ErrorEnvelope).error;
		if (e && typeof e.code === 'string') return e;
	}
	return null;
}

export function toOutcome<T>(answer: Answer | 'network'): Outcome<T> {
	if (answer === 'network') return { kind: 'network' };
	const { status, body } = answer;
	if (status === 201) return { kind: 'created', body: body as T };
	if (status === 200) {
		const replay = !!(body && typeof body === 'object' && (body as { idempotentReplay?: boolean }).idempotentReplay);
		// a 200 to a command is only ever an idempotent replay: never a new success
		return replay ? { kind: 'replay', body: body as T } : { kind: 'server', status, message: 'Unexpected answer: 200 without idempotentReplay' };
	}
	const e = envelope(body);
	const message = e?.message ?? `HTTP ${status}`;
	const details = (e?.details ?? {}) as Record<string, unknown>;
	if (status === 409 && e?.code === 'STALE_VERSION') return { kind: 'stale', message, details };
	if (status === 409 && e?.code === 'INVALID_TRANSITION') return { kind: 'invalidTransition', message, details };
	if (status === 403) return { kind: 'invalidActor', message };
	if (status === 400) return { kind: 'badRequest', message, details };
	if (status === 422) {
		const verdict = details.verdict as { reasons?: string[] } | undefined;
		return { kind: 'blocked', message, reasons: verdict?.reasons ?? [], details };
	}
	if (status === 404) return { kind: 'notFound', message };
	return { kind: 'server', status, message };
}

/** Outcomes after which nothing was recorded on the server. */
export function nothingRecorded(kind: Outcome<unknown>['kind']): boolean {
	return ['stale', 'invalidTransition', 'invalidActor', 'badRequest', 'blocked', 'notFound'].includes(kind);
}
