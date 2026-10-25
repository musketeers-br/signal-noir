import { describe, expect, it } from 'vitest';
import { ALL_STATES, COPY, reasonText, stateCopy } from '../src/lib/copy';

// T008 / T023 - one copy per state; waiting, review and uncertainty never share wording
describe('state copy', () => {
	it('covers the 13 states with a glyph, a label and a banner', () => {
		expect(ALL_STATES).toHaveLength(13);
		for (const s of ALL_STATES) {
			const c = stateCopy(s);
			expect(c.glyph).not.toBe('');
			expect(c.label).not.toBe('');
			expect(c.banner.length).toBeGreaterThan(10);
		}
	});
	it('Executing + reconciling is its own condition', () => {
		const c = stateCopy('Executing', 'reconciling');
		expect(c.label).toBe('Outcome unknown');
		expect(c.banner).toContain('may already have this order');
		expect(c.banner).toContain('New sends are blocked');
		expect(stateCopy('Executing', 'in_progress').label).toBe('Executing');
	});
	it('waiting, review and uncertainty share no sentence', () => {
		const sentences = (t: string) => t.split('. ').map((s) => s.replace(/\.$/, '').trim());
		const a = sentences(stateCopy('PendingApproval').banner);
		const b = sentences(stateCopy('ReviewRequired').banner);
		const c = sentences(stateCopy('Executing', 'reconciling').banner);
		for (const s of a) {
			expect(b).not.toContain(s);
			expect(c).not.toContain(s);
		}
		for (const s of b) expect(c).not.toContain(s);
	});
	it('at most one primary action per state', () => {
		expect(stateCopy('PendingApproval').action).toBe('approve');
		expect(stateCopy('ReviewRequired').action).toBe('dossier');
		expect(ALL_STATES.filter((s) => stateCopy(s).action).length).toBe(2);
	});
	it('replay copy is not a success message and reason codes have meanings', () => {
		expect(COPY.replayToast('Carla')).toBe('Already approved by Carla. No new effect.');
		expect(reasonText('MAPPING_CONDITION_MISMATCH')).toContain('condition');
		expect(reasonText('UNKNOWN_CODE')).toContain('No plain-language');
	});
});
