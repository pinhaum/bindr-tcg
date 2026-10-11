let marked = $state<string | null>(null);

export function markCard(cardNumber: string | null): void {
	marked = cardNumber;
}

export function isMarked(cardNumber: string): boolean {
	return marked === cardNumber;
}

export function morphName(cardNumber: string): string {
	const escaped = cardNumber.replace(
		/[^A-Za-z0-9-]/gu,
		(char) => `_${char.codePointAt(0)!.toString(16)}_`
	);
	return `carta-${escaped}`;
}
