// Polling health shared by the top bar: a failed poll marks data as possibly stale until the
// next successful poll (FR-015).
class Connection {
	stale = $state(false);
	failures = $state(0);

	ok(): void {
		this.stale = false;
		this.failures = 0;
	}

	failed(): void {
		this.stale = true;
		this.failures += 1;
	}
}

export const connection = new Connection();
