import type { ApiError } from '../api/errors';
import { createLoader } from '../api/loader.svelte';
import type { CatalogPage } from '../api/types';

export type CatalogState = {
	readonly result: CatalogPage | null;
	readonly error: ApiError | null;
	readonly pending: boolean;
	readonly skeleton: boolean;
	readonly seq: number;
};

export function createCatalogLoader(
	get: (path: string) => Promise<CatalogPage>,
	skeletonDelayMs = 200
) {
	const base = createLoader((search) => get('/api/catalog' + search), skeletonDelayMs);

	const state: CatalogState = {
		get result() {
			return base.state.result;
		},
		get error() {
			return base.state.error;
		},
		get pending() {
			return base.state.pending;
		},
		get skeleton() {
			return base.state.slow;
		},
		get seq() {
			return base.state.seq;
		}
	};

	return { state, load: base.load, retry: base.retry };
}
