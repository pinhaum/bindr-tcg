import { api } from '../api/index';
import { ApiError } from '../api/errors';
import type { FilterOptions } from '../api/types';

export type FilterOptionsState = {
	value: FilterOptions | null;
	error: ApiError | null;
	loading: boolean;
};

export const filterOptions: FilterOptionsState = $state({ value: null, error: null, loading: false });

function load(): void {
	if (filterOptions.loading) return;
	filterOptions.loading = true;

	api.get<FilterOptions>('/api/catalog/filters').then(
		(value) => {
			filterOptions.value = value;
			filterOptions.error = null;
			filterOptions.loading = false;
		},
		(error: unknown) => {
			filterOptions.loading = false;
			if (!(error instanceof ApiError)) throw error;
			filterOptions.error = error;
		}
	);
}

export function ensureFilterOptions(): void {
	if (filterOptions.value) return;
	load();
}

export function retryFilterOptions(): void {
	load();
}
