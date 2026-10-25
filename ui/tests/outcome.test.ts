import { describe, expect, it } from 'vitest';
import { nothingRecorded, toOutcome } from '../src/lib/api/outcome';
import { fixture } from '../src/lib/api/fixtures';

// T005 - every answer maps to exactly one Outcome; none of the refusals reads as success
describe('toOutcome', () => {
	it('201 is created', () => {
		expect(toOutcome({ status: 201, body: fixture('decision.201.approved.json') }).kind).toBe('created');
	});
	it('200 with idempotentReplay is a replay, never a new success', () => {
		expect(toOutcome({ status: 200, body: fixture('decision.200.idempotent-replay.json') }).kind).toBe('replay');
		expect(toOutcome({ status: 200, body: { idempotentReplay: false } }).kind).toBe('server');
	});
	it('409 tells stale version and invalid transition apart', () => {
		const stale = toOutcome({ status: 409, body: fixture('decision.409.stale-version.json') });
		expect(stale.kind).toBe('stale');
		const inv = toOutcome({ status: 409, body: fixture('decision.409.invalid-transition.json') });
		expect(inv.kind).toBe('invalidTransition');
		if (inv.kind === 'invalidTransition') expect(inv.details.state).toBe('ReviewRequired');
	});
	it('400, 403, 404, 422, network and 500', () => {
		expect(toOutcome({ status: 400, body: fixture('decision.400.denial-without-reason.json') }).kind).toBe('badRequest');
		expect(toOutcome({ status: 403, body: { error: { code: 'INVALID_ACTOR', message: 'x' } } }).kind).toBe('invalidActor');
		expect(toOutcome({ status: 404, body: fixture('case.404.json') }).kind).toBe('notFound');
		const blocked = toOutcome({ status: 422, body: fixture('resolution.422.validator-blocked.json') });
		expect(blocked.kind).toBe('blocked');
		if (blocked.kind === 'blocked') expect(blocked.reasons).toEqual(['MAPPING_CONDITION_MISMATCH']);
		expect(toOutcome('network').kind).toBe('network');
		expect(toOutcome({ status: 500, body: null }).kind).toBe('server');
	});
	it('refusals record nothing; network and server outcomes are not assumed either way', () => {
		for (const k of ['stale', 'invalidTransition', 'invalidActor', 'badRequest', 'blocked', 'notFound'] as const) expect(nothingRecorded(k)).toBe(true);
		expect(nothingRecorded('network')).toBe(false);
		expect(nothingRecorded('created')).toBe(false);
	});
});
