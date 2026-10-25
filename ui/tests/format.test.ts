import { describe, expect, it } from 'vitest';
import { age, brt, money, remaining } from '../src/lib/format';

// T009 - BRT on screen, UTC from the API
describe('format', () => {
	it('shows BRT', () => {
		expect(brt('2026-10-29T13:00:00Z')).toContain('10:00:00');
		expect(brt('2026-10-29T13:00:00Z')).toContain('BRT');
	});
	it('ages and deadlines tick from server time', () => {
		expect(age('2026-10-29T12:58:00Z', '2026-10-29T13:00:00Z')).toBe('2 min');
		expect(age('2026-10-29T10:00:00Z', '2026-10-29T13:05:00Z')).toBe('3 h 05 min');
		expect(remaining('2026-10-29T13:15:00Z', '2026-10-29T13:00:00Z')).toBe('15 min left');
		expect(remaining('2026-10-29T12:00:00Z', '2026-10-29T13:00:00Z')).toBe('expired');
		expect(money(0.011)).toBe('US$ 0.0110');
	});
});
