// Times on screen are BRT; the API is UTC (UX spine).
const TZ = 'America/Sao_Paulo';

export function brt(iso: string | null | undefined): string {
	if (!iso) return '—';
	const d = new Date(iso);
	if (Number.isNaN(d.getTime())) return iso;
	return new Intl.DateTimeFormat('en-GB', { timeZone: TZ, day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit', second: '2-digit' }).format(d) + ' BRT';
}

/** "4 min", "2 h 05 min", "3 d 1 h" between two instants. */
export function span(fromIso: string, toIso: string): string {
	const ms = new Date(toIso).getTime() - new Date(fromIso).getTime();
	if (Number.isNaN(ms)) return '—';
	const m = Math.max(0, Math.floor(ms / 60000));
	if (m < 60) return `${m} min`;
	const h = Math.floor(m / 60);
	if (h < 24) return `${h} h ${String(m % 60).padStart(2, '0')} min`;
	return `${Math.floor(h / 24)} d ${h % 24} h`;
}

/** Age of a case at the server's time. */
export function age(createdAt: string, serverTime: string): string {
	return span(createdAt, serverTime);
}

/** Time left before a deadline, or "expired". */
export function remaining(deadline: string, serverTime: string): string {
	return new Date(deadline).getTime() <= new Date(serverTime).getTime() ? 'expired' : `${span(serverTime, deadline)} left`;
}

export function money(usd: number | undefined | null): string {
	return usd === undefined || usd === null ? '—' : `US$ ${usd.toFixed(4)}`;
}

export function ms(value: number | undefined | null): string {
	return value === undefined || value === null ? '—' : value < 1000 ? `${value} ms` : `${(value / 1000).toFixed(1)} s`;
}
