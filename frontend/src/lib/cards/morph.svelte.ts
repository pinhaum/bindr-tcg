import { tick } from 'svelte';

let marked = $state<string | null>(null);

export function markCard(cardNumber: string | null): void {
	marked = cardNumber;
}

export function hasMark(): boolean {
	return marked !== null;
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

// Rendezvous de chegada: a View Transition só captura o estado novo depois que a tela de destino,
// que carrega por fetch dentro do componente, tem a arte no DOM. A tela sinaliza; a transição espera.
let arrived = false;
let release: (() => void) | null = null;
let waiting: Promise<void> | null = null;

export function armArrival(): void {
	arrived = false;
}

export function signalArrival(): void {
	arrived = true;
	release?.();
}

// Chamar na inicialização do componente: sinaliza a chegada quando `isReady` vira verdadeiro, já
// com o DOM da tela atualizado.
export function signalArrivalWhen(isReady: () => boolean): void {
	$effect(() => {
		if (!isReady()) return;
		let current = true;
		tick().then(() => {
			if (current) signalArrival();
		});
		return () => {
			current = false;
		};
	});
}

export function awaitArrival(timeoutMs: number): Promise<void> {
	if (arrived) return Promise.resolve();
	waiting ??= new Promise<void>((resolve) => {
		const timer = setTimeout(done, timeoutMs);
		function done() {
			clearTimeout(timer);
			waiting = release = null;
			resolve();
		}
		release = done;
	});
	return waiting;
}
