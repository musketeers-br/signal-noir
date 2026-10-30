import { describe, expect, it } from 'vitest';
import { FixtureServer } from '../src/lib/api/fixtures';

// 009b T006 - US3: the offline catalog reports the same Approval policy as the service
describe('offline action catalog', () => {
	it('needs Approval exactly when an Action has an external effect', async () => {
		const answer = await new FixtureServer().request('GET', '/reference/action-catalog');
		const items = (answer as { body: { items: { action: string; externalEffect: boolean; requiresApproval: boolean }[] } }).body.items;
		expect(items.map((i) => i.action).sort()).toEqual(['APPLY_APPROVED_MAPPING', 'HOLD', 'REQUEST_REVIEW', 'RETRY']);
		for (const i of items) expect(i.requiresApproval, i.action).toBe(i.externalEffect);
	});
});
