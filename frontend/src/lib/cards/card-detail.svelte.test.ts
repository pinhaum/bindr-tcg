import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiError } from '../api/errors';
import type { CardDetailPayload } from '../api/types';
import { createCardDetailLoader } from './card-detail.svelte';

const card = (cardNumber: string) => ({ card_number: cardNumber }) as CardDetailPayload;

const deferred = <T>() => {
	let resolve!: (value: T) => void;
	let reject!: (reason: unknown) => void;
	const promise = new Promise<T>((res, rej) => {
		resolve = res;
		reject = rej;
	});
	return { promise, resolve, reject };
};

const flush = () => vi.advanceTimersByTimeAsync(0);

const clientWith = (get: (path: string) => Promise<CardDetailPayload>) => ({
	get: get as <T>(path: string) => Promise<T>
});

describe('createCardDetailLoader', () => {
	beforeEach(() => {
		vi.useFakeTimers();
	});

	afterEach(() => {
		vi.useRealTimers();
	});

	it('chama a API com o card_number e a variante codificados', async () => {
		const get = vi.fn().mockResolvedValue(card('P-029'));
		const loader = createCardDetailLoader(clientWith(get));

		loader.load('P-029', 'tcgplayer:1');

		expect(get).toHaveBeenCalledWith('/api/cards/P-029?variant=tcgplayer%3A1');
		await flush();
	});

	it('omite a query quando não há variante', async () => {
		const get = vi.fn().mockResolvedValue(card('OP01-001'));
		const loader = createCardDetailLoader(clientWith(get));

		loader.load('OP01-001', undefined);

		expect(get).toHaveBeenCalledWith('/api/cards/OP01-001');
		await flush();
	});

	it('grava o resultado, zera pending e incrementa seq', async () => {
		const first = deferred<CardDetailPayload>();
		const loader = createCardDetailLoader(clientWith(() => first.promise));

		expect(loader.state.pending).toBe(false);
		loader.load('P-029', undefined);
		expect(loader.state.pending).toBe(true);

		first.resolve(card('P-029'));
		await flush();

		expect(loader.state.pending).toBe(false);
		expect(loader.state.result).toEqual(card('P-029'));
		expect(loader.state.error).toBeNull();
		expect(loader.state.notFound).toBeNull();
		expect(loader.state.seq).toBe(1);
	});

	it('só liga o skeleton depois de 200 ms e mantém o resultado anterior até lá', async () => {
		const get = vi.fn().mockResolvedValueOnce(card('P-029'));
		const loader = createCardDetailLoader(clientWith(get));
		loader.load('P-029', undefined);
		await flush();

		const second = deferred<CardDetailPayload>();
		get.mockReturnValueOnce(second.promise);
		loader.load('OP01-001', undefined);

		await vi.advanceTimersByTimeAsync(199);
		expect(loader.state.skeleton).toBe(false);
		expect(loader.state.result).toEqual(card('P-029'));

		await vi.advanceTimersByTimeAsync(1);
		expect(loader.state.skeleton).toBe(true);

		second.resolve(card('OP01-001'));
		await flush();
		expect(loader.state.skeleton).toBe(false);
		expect(loader.state.result).toEqual(card('OP01-001'));
	});

	it('respeita um atraso de skeleton customizado', async () => {
		const loader = createCardDetailLoader(clientWith(() => new Promise(() => {})), 50);
		loader.load('P-029', undefined);

		await vi.advanceTimersByTimeAsync(50);

		expect(loader.state.skeleton).toBe(true);
	});

	it('descarta a resposta superada por outro load', async () => {
		const first = deferred<CardDetailPayload>();
		const second = deferred<CardDetailPayload>();
		const get = vi.fn().mockReturnValueOnce(first.promise).mockReturnValueOnce(second.promise);
		const loader = createCardDetailLoader(clientWith(get));

		loader.load('P-029', undefined);
		loader.load('OP01-001', undefined);
		second.resolve(card('OP01-001'));
		await flush();
		first.resolve(card('P-029'));
		await flush();

		expect(loader.state.result).toEqual(card('OP01-001'));
		expect(loader.state.seq).toBe(1);
	});

	it('descarta o erro de uma consulta superada', async () => {
		const first = deferred<CardDetailPayload>();
		const second = deferred<CardDetailPayload>();
		const get = vi.fn().mockReturnValueOnce(first.promise).mockReturnValueOnce(second.promise);
		const loader = createCardDetailLoader(clientWith(get));

		loader.load('P-029', undefined);
		loader.load('OP01-001', undefined);
		first.reject(new ApiError(500, 'internal_error', 'Erro interno.'));
		await flush();

		expect(loader.state.error).toBeNull();
		expect(loader.state.pending).toBe(true);

		second.resolve(card('OP01-001'));
		await flush();
		expect(loader.state.result).toEqual(card('OP01-001'));
	});

	it('404 not_found vira notFound com a message, sem error', async () => {
		const get = vi.fn().mockRejectedValue(new ApiError(404, 'not_found', 'Carta não encontrada.'));
		const loader = createCardDetailLoader(clientWith(get));

		loader.load('X-999', undefined);
		await flush();

		expect(loader.state.notFound).toBe('Carta não encontrada.');
		expect(loader.state.error).toBeNull();
		expect(loader.state.pending).toBe(false);
		expect(loader.state.skeleton).toBe(false);
		expect(loader.state.seq).toBe(1);
	});

	it('outro ApiError vira error', async () => {
		const failure = new ApiError(500, 'internal_error', 'Algo deu errado.');
		const loader = createCardDetailLoader(clientWith(vi.fn().mockRejectedValue(failure)));

		loader.load('P-029', undefined);
		await flush();

		expect(loader.state.error).toBe(failure);
		expect(loader.state.notFound).toBeNull();
		expect(loader.state.pending).toBe(false);
	});

	it('um 404 com outro código é tratado como error', async () => {
		const failure = new ApiError(404, 'something_else', 'Outra coisa.');
		const loader = createCardDetailLoader(clientWith(vi.fn().mockRejectedValue(failure)));

		loader.load('P-029', undefined);
		await flush();

		expect(loader.state.error).toBe(failure);
		expect(loader.state.notFound).toBeNull();
	});

	it('um novo load bem-sucedido limpa error e notFound', async () => {
		const get = vi
			.fn()
			.mockRejectedValueOnce(new ApiError(404, 'not_found', 'Carta não encontrada.'))
			.mockResolvedValueOnce(card('P-029'));
		const loader = createCardDetailLoader(clientWith(get));

		loader.load('X-999', undefined);
		await flush();
		loader.load('P-029', undefined);
		await flush();

		expect(loader.state.notFound).toBeNull();
		expect(loader.state.error).toBeNull();
		expect(loader.state.result).toEqual(card('P-029'));
	});

	it('durante o retry o erro permanece até a resposta e o skeleton liga depois de 200 ms', async () => {
		const failure = new ApiError(0, 'network_error', 'Sem conexão.');
		const second = deferred<CardDetailPayload>();
		const get = vi.fn().mockRejectedValueOnce(failure).mockReturnValueOnce(second.promise);
		const loader = createCardDetailLoader(clientWith(get));
		loader.load('P-029', undefined);
		await flush();

		loader.retry();
		await vi.advanceTimersByTimeAsync(199);
		expect(loader.state.skeleton).toBe(false);
		expect(loader.state.error).toBe(failure);

		await vi.advanceTimersByTimeAsync(1);
		expect(loader.state.skeleton).toBe(true);
		expect(loader.state.pending).toBe(true);

		second.resolve(card('P-029'));
		await flush();
		expect(loader.state.skeleton).toBe(false);
		expect(loader.state.error).toBeNull();
		expect(loader.state.result).toEqual(card('P-029'));
	});

	it('ao trocar de carta vindo de notFound, o skeleton liga depois de 200 ms e notFound sai com a resposta', async () => {
		const second = deferred<CardDetailPayload>();
		const get = vi
			.fn()
			.mockRejectedValueOnce(new ApiError(404, 'not_found', 'Carta não encontrada.'))
			.mockReturnValueOnce(second.promise);
		const loader = createCardDetailLoader(clientWith(get));
		loader.load('X-999', undefined);
		await flush();

		loader.load('P-029', undefined);
		await vi.advanceTimersByTimeAsync(200);
		expect(loader.state.skeleton).toBe(true);
		expect(loader.state.notFound).toBe('Carta não encontrada.');

		second.resolve(card('P-029'));
		await flush();
		expect(loader.state.skeleton).toBe(false);
		expect(loader.state.notFound).toBeNull();
	});

	it('retry repete a última consulta', async () => {
		const get = vi
			.fn()
			.mockRejectedValueOnce(new ApiError(0, 'network_error', 'Sem conexão.'))
			.mockResolvedValueOnce(card('P-029'));
		const loader = createCardDetailLoader(clientWith(get));

		loader.load('P-029', 'tcgplayer:1');
		await flush();
		expect(loader.state.error?.code).toBe('network_error');

		loader.retry();
		await flush();

		expect(get).toHaveBeenNthCalledWith(2, '/api/cards/P-029?variant=tcgplayer%3A1');
		expect(loader.state.error).toBeNull();
		expect(loader.state.result).toEqual(card('P-029'));
	});

	it('relança o erro que não é ApiError e destrava o estado', async () => {
		const boom = new TypeError('bug');
		const loader = createCardDetailLoader(clientWith(vi.fn().mockRejectedValue(boom)));
		const saved = process.listeners('unhandledRejection');
		const unhandled: unknown[] = [];
		process.removeAllListeners('unhandledRejection');
		process.on('unhandledRejection', (reason) => unhandled.push(reason));

		try {
			loader.load('P-029', undefined);
			await flush();
			await vi.waitFor(() => expect(unhandled).toEqual([boom]));
		} finally {
			process.removeAllListeners('unhandledRejection');
			for (const listener of saved) process.on('unhandledRejection', listener);
		}

		expect(loader.state.error).toBeNull();
		expect(loader.state.pending).toBe(false);
		expect(loader.state.skeleton).toBe(false);
		expect(loader.state.seq).toBe(0);
	});
});
