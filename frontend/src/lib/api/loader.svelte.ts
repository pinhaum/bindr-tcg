import { ApiError } from './errors';

export type LoaderState<T> = {
	readonly result: T | null;
	readonly error: ApiError | null;
	readonly pending: boolean;
	readonly slow: boolean;
	readonly seq: number;
};

export function createLoader<T>(fetch: (key: string) => Promise<T>, slowMs = 200) {
	// A resposta só é trocada inteira, nunca alterada: `raw` evita o proxy profundo.
	let result = $state.raw<T | null>(null);
	let error = $state.raw<ApiError | null>(null);
	let pending = $state(false);
	let slow = $state(false);
	let seq = $state(0);
	let token = 0;
	let lastKey: string | null = null;
	let timer: ReturnType<typeof setTimeout> | undefined;

	const state: LoaderState<T> = {
		get result() {
			return result;
		},
		get error() {
			return error;
		},
		get pending() {
			return pending;
		},
		get slow() {
			return slow;
		},
		get seq() {
			return seq;
		}
	};

	const settle = () => {
		clearTimeout(timer);
		pending = false;
		slow = false;
	};

	const load = (key: string): void => {
		const mine = ++token;
		lastKey = key;
		clearTimeout(timer);
		pending = true;
		slow = false;
		timer = setTimeout(() => {
			slow = true;
		}, slowMs);

		fetch(key).then(
			(value) => {
				if (mine !== token) return;
				result = value;
				error = null;
				seq++;
				settle();
			},
			(cause: unknown) => {
				if (!(cause instanceof ApiError)) {
					if (mine === token) settle();
					throw cause;
				}
				if (mine !== token) return;
				settle();
				error = cause;
				seq++;
			}
		);
	};

	const retry = (): void => {
		if (lastKey !== null) load(lastKey);
	};

	return { state, load, retry };
}
