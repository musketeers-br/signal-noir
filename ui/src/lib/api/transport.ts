// The only way the console reaches the server. A transport answers with the HTTP status and the
// parsed body, or throws NetworkError when no answer arrived (the request may or may not have
// reached the server).

export interface Answer {
	status: number;
	body: unknown;
}

export interface Transport {
	request(method: 'GET' | 'POST', path: string, body?: unknown): Promise<Answer>;
}

export class NetworkError extends Error {
	constructor(message = 'no answer from the server') {
		super(message);
		this.name = 'NetworkError';
	}
}

/** Real transport. The console is served at /signalnoir/ui/, the API at /signalnoir/api/v1. */
export function fetchTransport(base = '../api/v1', timeoutMs = 10000): Transport {
	return {
		async request(method, path, body) {
			const controller = new AbortController();
			const timer = setTimeout(() => controller.abort(), timeoutMs);
			try {
				const res = await fetch(`${base}${path}`, {
					method,
					headers: body === undefined ? { Accept: 'application/json' } : { Accept: 'application/json', 'Content-Type': 'application/json' },
					body: body === undefined ? undefined : JSON.stringify(body),
					signal: controller.signal
				});
				const text = await res.text();
				let parsed: unknown = null;
				try {
					parsed = text ? JSON.parse(text) : null;
				} catch {
					parsed = null;
				}
				return { status: res.status, body: parsed };
			} catch {
				throw new NetworkError();
			} finally {
				clearTimeout(timer);
			}
		}
	};
}
