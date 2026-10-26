import axe from 'axe-core';

/** WCAG 2.x A/AA violations in a container. Contrast is not computable without layout (jsdom);
 *  DESIGN.md's tokens are AA in both themes, and real-browser checks are in the quickstart. */
export async function violations(container: Element): Promise<string[]> {
	const result = await axe.run(container, {
		runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'] },
		rules: { 'color-contrast': { enabled: false } }
	});
	return result.violations.map((v) => `${v.id}: ${v.help} (${v.nodes.length})`);
}
