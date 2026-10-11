import { ApiError } from './errors';

export type LoaderState<T> = {
	result: T | null;
	error: ApiError | null;
	pending: boolean;
	slow: boolean;
	seq: number;
};

export function createLoader<T>(fetch: (key: string) => Promise<T>, slowMs = 200) {
	const state: LoaderState<T> = $state({
		result: null,
		error: null,
		pending: false,
		slow: false,
		seq: 0
	});
	let token = 0;
	let lastKey = '';
	let timer: ReturnType<typeof setTimeout> | undefined;

	const settle = () => {
		clearTimeout(timer);
		state.pending = false;
		state.slow = false;
	};

	const load = (key: string): void => {
		const mine = ++token;
		lastKey = key;
		clearTimeout(timer);
		state.pending = true;
		state.slow = false;
		timer = setTimeout(() => {
			state.slow = true;
		}, slowMs);

		fetch(key).then(
			(result) => {
				if (mine !== token) return;
				state.result = result;
				state.error = null;
				state.seq++;
				settle();
			},
			(error: unknown) => {
				if (!(error instanceof ApiError)) {
					if (mine === token) settle();
					throw error;
				}
				if (mine !== token) return;
				settle();
				state.error = error;
				state.seq++;
			}
		);
	};

	const retry = (): void => load(lastKey);

	return { state, load, retry };
}
