import { ApiError } from '../api/errors';
import type { CatalogPage } from '../api/types';

export type CatalogState = {
	result: CatalogPage | null;
	error: ApiError | null;
	pending: boolean;
	skeleton: boolean;
	seq: number;
};

export function createCatalogLoader(
	get: (path: string) => Promise<CatalogPage>,
	skeletonDelayMs = 200
) {
	const state: CatalogState = $state({
		result: null,
		error: null,
		pending: false,
		skeleton: false,
		seq: 0
	});
	let token = 0;
	let lastSearch = '';
	let timer: ReturnType<typeof setTimeout> | undefined;

	const settle = () => {
		clearTimeout(timer);
		state.pending = false;
		state.skeleton = false;
	};

	const load = (search: string): void => {
		const mine = ++token;
		lastSearch = search;
		clearTimeout(timer);
		state.pending = true;
		state.skeleton = false;
		timer = setTimeout(() => {
			state.skeleton = true;
		}, skeletonDelayMs);

		get('/api/catalog' + search).then(
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

	const retry = (): void => load(lastSearch);

	return { state, load, retry };
}
