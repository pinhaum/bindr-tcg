import { ApiError } from '../api/errors';
import type { ApiClient } from '../api/client';
import type { CardDetailPayload } from '../api/types';
import { cardApiPath } from './url';

export type CardDetailState = {
	result: CardDetailPayload | null;
	error: ApiError | null;
	notFound: string | null;
	pending: boolean;
	skeleton: boolean;
	seq: number;
};

export function createCardDetailLoader(client: Pick<ApiClient, 'get'>, skeletonDelayMs = 200) {
	const state: CardDetailState = $state({
		result: null,
		error: null,
		notFound: null,
		pending: false,
		skeleton: false,
		seq: 0
	});
	let token = 0;
	let last: { cardNumber: string; variant: string | undefined } | null = null;
	let timer: ReturnType<typeof setTimeout> | undefined;

	const settle = () => {
		clearTimeout(timer);
		state.pending = false;
		state.skeleton = false;
	};

	const load = (cardNumber: string, variant: string | undefined): void => {
		const mine = ++token;
		last = { cardNumber, variant };
		clearTimeout(timer);
		state.pending = true;
		state.skeleton = false;
		timer = setTimeout(() => {
			state.skeleton = true;
		}, skeletonDelayMs);

		client.get<CardDetailPayload>(cardApiPath(cardNumber, variant)).then(
			(result) => {
				if (mine !== token) return;
				state.result = result;
				state.error = null;
				state.notFound = null;
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
				const missing = error.status === 404 && error.code === 'not_found';
				state.notFound = missing ? error.message : null;
				state.error = missing ? null : error;
				state.seq++;
			}
		);
	};

	const retry = (): void => {
		if (last) load(last.cardNumber, last.variant);
	};

	return { state, load, retry };
}
