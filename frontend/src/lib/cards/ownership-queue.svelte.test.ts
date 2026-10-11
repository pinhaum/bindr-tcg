import { describe, expect, it, vi } from 'vitest';
import { ApiError } from '../api/errors';
import type { OwnershipResult } from '../api/types';
import { createOwnershipQueue, type OwnershipOp } from './ownership-queue.svelte';

type Deferred = {
	op: OwnershipOp;
	resolve: (quantity: number) => void;
	reject: (error: unknown) => void;
};

function setup(confirmed = 0) {
	const calls: Deferred[] = [];
	const send = vi.fn(
		(op: OwnershipOp) =>
			new Promise<OwnershipResult>((resolve, reject) => {
				calls.push({
					op,
					resolve: (quantity) => resolve({ variant_code: 'tcgplayer:1', owned_quantity: quantity }),
					reject
				});
			})
	);
	const onSettled = vi.fn();
	const onError = vi.fn();
	const queue = createOwnershipQueue({ confirmed, send, onSettled, onError });
	return { queue, calls, send, onSettled, onError };
}

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

describe('createOwnershipQueue', () => {
	it('mostra o valor otimista na hora e envia uma só operação em voo por vez, em ordem (SCAR-27, SCAR-30)', async () => {
		const { queue, calls, send } = setup(0);

		const results = [1, 2, 3, 4, 5].map(() => queue.tap('increment'));

		expect(results).toEqual(['sent', 'queued', 'queued', 'queued', 'queued']);
		expect(queue.displayed).toBe(5);
		expect(queue.confirmed).toBe(0);
		expect(queue.settled).toBe(false);
		expect(send).toHaveBeenCalledTimes(1);

		for (let n = 1; n <= 5; n++) {
			expect(calls).toHaveLength(n);
			expect(calls[n - 1].op).toBe('increment');
			calls[n - 1].resolve(n);
			await flush();
			expect(queue.confirmed).toBe(n);
			expect(queue.displayed).toBe(5);
		}
		expect(send).toHaveBeenCalledTimes(5);
	});

	it('preserva a ordem dos toques misturados e subtrai antes da resposta (SCAR-28, SCAR-30)', async () => {
		const { queue, calls } = setup(2);

		queue.tap('decrement');
		expect(queue.displayed).toBe(1);
		queue.tap('increment');
		queue.tap('decrement');
		expect(queue.displayed).toBe(1);

		calls[0].resolve(1);
		await flush();
		calls[1].resolve(2);
		await flush();
		calls[2].resolve(1);
		await flush();

		expect(calls.map((c) => c.op)).toEqual(['decrement', 'increment', 'decrement']);
		expect(queue.displayed).toBe(1);
	});

	it('recusa decrement com valor exibido zero, sem enviar (SCAR-29)', () => {
		const { queue, send } = setup(0);

		expect(queue.tap('decrement')).toBe('refused');
		expect(queue.displayed).toBe(0);
		expect(send).not.toHaveBeenCalled();
		expect(queue.settled).toBe(true);
	});

	it('recusa decrement que passaria de zero contando os pendentes (SCAR-29)', () => {
		const { queue, send } = setup(1);

		expect(queue.tap('decrement')).toBe('sent');
		expect(queue.displayed).toBe(0);
		expect(queue.tap('decrement')).toBe('refused');
		expect(send).toHaveBeenCalledTimes(1);
	});

	it('ao esvaziar a fila exibe o owned_quantity da última resposta e avisa uma vez (SCAR-31, SCAR-33)', async () => {
		const { queue, calls, onSettled } = setup(0);

		queue.tap('increment');
		queue.tap('increment');

		calls[0].resolve(1);
		await flush();
		expect(onSettled).not.toHaveBeenCalled();

		calls[1].resolve(7);
		await flush();

		expect(queue.displayed).toBe(7);
		expect(queue.confirmed).toBe(7);
		expect(queue.settled).toBe(true);
		expect(onSettled).toHaveBeenCalledTimes(1);
		expect(onSettled).toHaveBeenCalledWith(7);
	});

	it('falha na 3ª de cinco: volta ao último confirmado, não envia 4ª e 5ª e repassa o erro (SCAR-32)', async () => {
		const { queue, calls, send, onError, onSettled } = setup(0);
		const error = new ApiError(500, 'internal_error', 'Algo deu errado.', {});

		for (let i = 0; i < 5; i++) queue.tap('increment');

		calls[0].resolve(1);
		await flush();
		calls[1].resolve(2);
		await flush();
		calls[2].reject(error);
		await flush();

		expect(queue.displayed).toBe(2);
		expect(queue.confirmed).toBe(2);
		expect(queue.settled).toBe(true);
		expect(send).toHaveBeenCalledTimes(3);
		expect(onError).toHaveBeenCalledTimes(1);
		expect(onError).toHaveBeenCalledWith(error);
		expect(onSettled).not.toHaveBeenCalled();
	});

	it('repassa também erros que não são ApiError, inclusive os lançados de forma síncrona', async () => {
		const boom = new Error('boom');
		const onError = vi.fn();
		const queue = createOwnershipQueue({
			confirmed: 3,
			send: () => {
				throw boom;
			},
			onSettled: vi.fn(),
			onError
		});

		queue.tap('increment');
		await flush();

		expect(onError).toHaveBeenCalledWith(boom);
		expect(queue.displayed).toBe(3);
	});

	it('aceita novos toques depois de um erro', async () => {
		const { queue, calls } = setup(0);

		queue.tap('increment');
		calls[0].reject(new Error('x'));
		await flush();

		expect(queue.tap('increment')).toBe('sent');
		expect(queue.displayed).toBe(1);
		expect(calls).toHaveLength(2);
	});

	it('discard() com operação em voo: não envia as pendentes e ignora a resposta em voo', async () => {
		const { queue, calls, send, onSettled, onError } = setup(2);

		queue.tap('increment');
		queue.tap('increment');
		queue.tap('increment');
		expect(queue.displayed).toBe(5);

		queue.discard();
		expect(queue.displayed).toBe(2);

		calls[0].resolve(3);
		await flush();

		expect(queue.displayed).toBe(2);
		expect(queue.confirmed).toBe(2);
		expect(send).toHaveBeenCalledTimes(1);
		expect(onSettled).not.toHaveBeenCalled();
		expect(onError).not.toHaveBeenCalled();
	});

	it('discard() com operação em voo ignora também a falha em voo', async () => {
		const { queue, calls, onError } = setup(0);

		queue.tap('increment');
		queue.discard();
		calls[0].reject(new Error('x'));
		await flush();

		expect(onError).not.toHaveBeenCalled();
		expect(queue.displayed).toBe(0);
	});

	it('depois de discard() a fila volta a enviar sem misturar com a resposta antiga', async () => {
		const { queue, calls, onSettled } = setup(0);

		queue.tap('increment');
		queue.discard();
		expect(queue.tap('increment')).toBe('sent');
		expect(calls).toHaveLength(2);

		calls[0].resolve(9);
		await flush();
		expect(queue.displayed).toBe(1);

		calls[1].resolve(1);
		await flush();
		expect(queue.displayed).toBe(1);
		expect(onSettled).toHaveBeenCalledTimes(1);
		expect(onSettled).toHaveBeenCalledWith(1);
	});

	it('discard() sem nada pendente não muda nada', () => {
		const { queue } = setup(4);

		queue.discard();

		expect(queue.displayed).toBe(4);
		expect(queue.settled).toBe(true);
	});
});
