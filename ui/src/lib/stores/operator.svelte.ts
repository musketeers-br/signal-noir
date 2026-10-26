// The name the Operator acts under (no authentication in v1). Kept in the browser and sent as
// `operator` in every command; always labelled as a declared name.
const KEY = 'signalnoir.operator';

function load(): string {
	try {
		return localStorage.getItem(KEY) ?? '';
	} catch {
		return '';
	}
}

class Operator {
	name = $state(load());

	set(value: string): void {
		this.name = value;
		try {
			localStorage.setItem(KEY, value);
		} catch {
			// private mode: the name lives for this page only
		}
	}
}

export const operator = new Operator();

/** '' when valid, else the problem with the name (contract OperatorName). */
export function nameProblem(name: string): 'required' | 'colon' | '' {
	const n = name.trim();
	if (!n) return 'required';
	if (n.includes(':')) return 'colon';
	return '';
}
