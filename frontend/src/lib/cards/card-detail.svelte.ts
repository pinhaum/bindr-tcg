import { ApiError } from '../api/errors';
import type { ApiClient } from '../api/client';
import { createLoader } from '../api/loader.svelte';
import type { CardDetailPayload } from '../api/types';
import { cardApiPath } from './url';

export type CardDetailState = {
	readonly result: CardDetailPayload | null;
	readonly error: ApiError | null;
	readonly notFound: string | null;
	readonly pending: boolean;
	readonly skeleton: boolean;
	readonly seq: number;
};

const isMissing = (error: ApiError | null): error is ApiError =>
	error?.status === 404 && error.code === 'not_found';

export function createCardDetailLoader(client: Pick<ApiClient, 'get'>, skeletonDelayMs = 200) {
	const base = createLoader((path) => client.get<CardDetailPayload>(path), skeletonDelayMs);

	const state: CardDetailState = {
		get result() {
			return base.state.result;
		},
		get error() {
			return isMissing(base.state.error) ? null : base.state.error;
		},
		get notFound() {
			const error = base.state.error;
			return isMissing(error) ? error.message : null;
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

	const load = (cardNumber: string, variant: string | undefined): void =>
		base.load(cardApiPath(cardNumber, variant));

	return { state, load, retry: base.retry };
}
