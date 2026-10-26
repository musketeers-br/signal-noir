// Toasts only report the outcome of the Operator's own action, never as the only place an error
// is shown (UX spine).
export interface Toast {
	id: number;
	text: string;
	tone: 'success' | 'fact' | 'muted';
}

class Toasts {
	items = $state<Toast[]>([]);
	private seq = 0;

	push(text: string, tone: Toast['tone'] = 'success', ttlMs = 6000): void {
		const id = ++this.seq;
		this.items = [...this.items, { id, text, tone }];
		setTimeout(() => this.dismiss(id), ttlMs);
	}

	dismiss(id: number): void {
		this.items = this.items.filter((t) => t.id !== id);
	}

	clear(): void {
		this.items = [];
	}
}

export const toasts = new Toasts();
