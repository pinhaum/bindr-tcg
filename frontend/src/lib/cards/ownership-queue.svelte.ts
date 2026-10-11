import type { OwnershipResult } from '../api/types';

export type OwnershipOp = 'increment' | 'decrement';

export type OwnershipQueueOptions = {
	confirmed: number;
	send: (op: OwnershipOp) => Promise<OwnershipResult>;
	onSettled: (quantity: number) => void;
	onError: (error: unknown) => void;
};

const delta = (op: OwnershipOp): number => (op === 'increment' ? 1 : -1);

export function createOwnershipQueue({ confirmed, send, onSettled, onError }: OwnershipQueueOptions) {
	const state = $state({
		confirmed,
		pending: [] as OwnershipOp[],
		inFlight: null as OwnershipOp | null
	});
	let generation = 0;

	const displayed = $derived(
		state.confirmed +
			state.pending.reduce((sum, op) => sum + delta(op), 0) +
			(state.inFlight ? delta(state.inFlight) : 0)
	);

	const pump = (): void => {
		const op = state.pending.shift();
		if (!op) return;
		state.inFlight = op;
		const mine = generation;

		new Promise<OwnershipResult>((resolve) => resolve(send(op))).then(
			(result) => {
				if (mine !== generation) return;
				state.confirmed = result.owned_quantity;
				state.inFlight = null;
				if (state.pending.length > 0) pump();
				else onSettled(state.confirmed);
			},
			(error: unknown) => {
				if (mine !== generation) return;
				state.pending = [];
				state.inFlight = null;
				onError(error);
			}
		);
	};

	const tap = (op: OwnershipOp): 'sent' | 'queued' | 'refused' => {
		if (op === 'decrement' && displayed <= 0) return 'refused';
		state.pending.push(op);
		if (state.inFlight) return 'queued';
		pump();
		return 'sent';
	};

	const discard = (): void => {
		generation++;
		state.pending = [];
		state.inFlight = null;
	};

	return {
		get displayed() {
			return displayed;
		},
		get confirmed() {
			return state.confirmed;
		},
		get settled() {
			return state.inFlight === null && state.pending.length === 0;
		},
		tap,
		discard
	};
}
