import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiError } from '../api/errors';
import type { CatalogPage } from '../api/types';
import { createCatalogLoader } from './catalog.svelte';

const page = (total: number): CatalogPage => ({
	data: [],
	meta: { page: 1, per_page: 24, total_count: total, total_pages: 1, active_filters: {} }
});

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

describe('createCatalogLoader', () => {
	beforeEach(() => {
		vi.useFakeTimers();
	});

	afterEach(() => {
		vi.useRealTimers();
	});

	it('repassa a query crua para /api/catalog', async () => {
		const get = vi.fn().mockResolvedValue(page(1));
		const loader = createCatalogLoader(get);

		loader.load('?colors%5B%5D=Red');
		loader.load('');

		expect(get).toHaveBeenNthCalledWith(1, '/api/catalog?colors%5B%5D=Red');
		expect(get).toHaveBeenNthCalledWith(2, '/api/catalog');
		await flush();
	});

	it('marca pending ao carregar e zera ao receber a resposta', async () => {
		const first = deferred<CatalogPage>();
		const loader = createCatalogLoader(() => first.promise);

		expect(loader.state.pending).toBe(false);
		loader.load('');
		expect(loader.state.pending).toBe(true);

		first.resolve(page(1));
		await flush();

		expect(loader.state.pending).toBe(false);
		expect(loader.state.result).toEqual(page(1));
		expect(loader.state.seq).toBe(1);
	});

	it('descarta a resposta antiga que chega depois da atual', async () => {
		const first = deferred<CatalogPage>();
		const second = deferred<CatalogPage>();
		const get = vi.fn().mockReturnValueOnce(first.promise).mockReturnValueOnce(second.promise);
		const loader = createCatalogLoader(get);

		loader.load('?q=a');
		loader.load('?q=b');
		second.resolve(page(2));
		await flush();
		first.resolve(page(1));
		await flush();

		expect(loader.state.result).toEqual(page(2));
		expect(loader.state.seq).toBe(1);
		expect(loader.state.pending).toBe(false);
	});

	it('descarta a falha antiga sem tocar no estado', async () => {
		const first = deferred<CatalogPage>();
		const second = deferred<CatalogPage>();
		const get = vi.fn().mockReturnValueOnce(first.promise).mockReturnValueOnce(second.promise);
		const loader = createCatalogLoader(get);

		loader.load('?q=a');
		loader.load('?q=b');
		second.resolve(page(2));
		await flush();
		first.reject(new ApiError(500, 'internal_error', 'Falhou.'));
		await flush();

		expect(loader.state.error).toBeNull();
		expect(loader.state.seq).toBe(1);
	});

	it('mostra o skeleton só a partir de 200 ms e mantém o resultado anterior', async () => {
		const first = deferred<CatalogPage>();
		const second = deferred<CatalogPage>();
		const get = vi.fn().mockReturnValueOnce(first.promise).mockReturnValueOnce(second.promise);
		const loader = createCatalogLoader(get);

		loader.load('');
		first.resolve(page(1));
		await flush();

		loader.load('?q=b');
		await vi.advanceTimersByTimeAsync(199);
		expect(loader.state.skeleton).toBe(false);
		await vi.advanceTimersByTimeAsync(1);
		expect(loader.state.skeleton).toBe(true);
		expect(loader.state.pending).toBe(true);
		expect(loader.state.result).toEqual(page(1));

		second.resolve(page(2));
		await flush();

		expect(loader.state.skeleton).toBe(false);
		expect(loader.state.pending).toBe(false);
		expect(loader.state.result).toEqual(page(2));
	});

	it('cancela o timer do skeleton quando a resposta chega antes dos 200 ms', async () => {
		const first = deferred<CatalogPage>();
		const loader = createCatalogLoader(() => first.promise);

		loader.load('');
		await vi.advanceTimersByTimeAsync(100);
		first.resolve(page(1));
		await flush();

		expect(vi.getTimerCount()).toBe(0);
		await vi.advanceTimersByTimeAsync(500);
		expect(loader.state.skeleton).toBe(false);
	});

	it('respeita o atraso do skeleton injetado', async () => {
		const loader = createCatalogLoader(() => new Promise<CatalogPage>(() => {}), 50);

		loader.load('');
		await vi.advanceTimersByTimeAsync(49);
		expect(loader.state.skeleton).toBe(false);
		await vi.advanceTimersByTimeAsync(1);
		expect(loader.state.skeleton).toBe(true);
	});

	it('reinicia o timer do skeleton a cada carga nova', async () => {
		const loader = createCatalogLoader(() => new Promise<CatalogPage>(() => {}));

		loader.load('?q=a');
		await vi.advanceTimersByTimeAsync(150);
		loader.load('?q=b');
		await vi.advanceTimersByTimeAsync(100);
		expect(loader.state.skeleton).toBe(false);
		await vi.advanceTimersByTimeAsync(100);
		expect(loader.state.skeleton).toBe(true);
	});

	it('grava o ApiError, mantém o resultado e sobe seq; o sucesso seguinte zera o erro', async () => {
		const failure = new ApiError(0, 'network_error', 'Sem conexão com o servidor. Tente novamente.');
		const get = vi
			.fn()
			.mockResolvedValueOnce(page(1))
			.mockRejectedValueOnce(failure)
			.mockResolvedValueOnce(page(2));
		const loader = createCatalogLoader(get);

		loader.load('');
		await flush();
		expect(loader.state.seq).toBe(1);

		loader.load('?q=b');
		await flush();
		expect(loader.state.error).toBe(failure);
		expect(loader.state.result).toEqual(page(1));
		expect(loader.state.seq).toBe(2);
		expect(loader.state.pending).toBe(false);
		expect(loader.state.skeleton).toBe(false);

		loader.load('?q=c');
		await flush();
		expect(loader.state.error).toBeNull();
		expect(loader.state.result).toEqual(page(2));
		expect(loader.state.seq).toBe(3);
	});

	it('cancela o timer do skeleton quando a carga falha', async () => {
		const first = deferred<CatalogPage>();
		const loader = createCatalogLoader(() => first.promise);

		loader.load('');
		await vi.advanceTimersByTimeAsync(100);
		first.reject(new ApiError(500, 'internal_error', 'Falhou.'));
		await flush();

		expect(loader.state.error).not.toBeNull();
		expect(vi.getTimerCount()).toBe(0);
		await vi.advanceTimersByTimeAsync(500);
		expect(loader.state.skeleton).toBe(false);
		expect(loader.state.pending).toBe(false);
	});

	describe.each([
		['sucesso', (d: ReturnType<typeof deferred<CatalogPage>>) => d.resolve(page(1))],
		[
			'falha',
			(d: ReturnType<typeof deferred<CatalogPage>>) =>
				d.reject(new ApiError(500, 'internal_error', 'Falhou.'))
		]
	])('resposta antiga (%s) com a carga atual ainda pendente', (_name, settleOld) => {
		it('não altera o estado e mantém o timer da carga atual', async () => {
			const first = deferred<CatalogPage>();
			const second = deferred<CatalogPage>();
			const get = vi.fn().mockReturnValueOnce(first.promise).mockReturnValueOnce(second.promise);
			const loader = createCatalogLoader(get);

			loader.load('?q=a');
			await vi.advanceTimersByTimeAsync(100);
			loader.load('?q=b');
			await vi.advanceTimersByTimeAsync(150);

			settleOld(first);
			await flush();

			expect(loader.state.result).toBeNull();
			expect(loader.state.error).toBeNull();
			expect(loader.state.seq).toBe(0);
			expect(loader.state.pending).toBe(true);
			expect(loader.state.skeleton).toBe(false);
			expect(vi.getTimerCount()).toBe(1);

			await vi.advanceTimersByTimeAsync(49);
			expect(loader.state.skeleton).toBe(false);
			await vi.advanceTimersByTimeAsync(1);
			expect(loader.state.skeleton).toBe(true);

			second.resolve(page(2));
			await flush();

			expect(loader.state.result).toEqual(page(2));
			expect(loader.state.error).toBeNull();
			expect(loader.state.seq).toBe(1);
			expect(loader.state.pending).toBe(false);
			expect(loader.state.skeleton).toBe(false);
		});
	});

	describe('erro que não é ApiError', () => {
		const captureUnhandled = async (run: () => Promise<void>, expected: unknown[]) => {
			const saved = process.listeners('unhandledRejection');
			const unhandled: unknown[] = [];
			process.removeAllListeners('unhandledRejection');
			process.on('unhandledRejection', (reason) => unhandled.push(reason));

			try {
				await run();
				await vi.waitFor(() => expect(unhandled).toEqual(expected));
			} finally {
				process.removeAllListeners('unhandledRejection');
				for (const listener of saved) process.on('unhandledRejection', listener);
			}
		};

		it('é relançado e não grava error', async () => {
			const boom = new TypeError('bug');
			const loader = createCatalogLoader(() => Promise.reject(boom));

			await captureUnhandled(async () => {
				loader.load('');
				await flush();
			}, [boom]);

			expect(loader.state.error).toBeNull();
			expect(loader.state.pending).toBe(false);
			expect(loader.state.skeleton).toBe(false);
			expect(loader.state.seq).toBe(0);
		});

		it('de carga antiga também é relançado, sem tocar no estado', async () => {
			const boom = new TypeError('bug');
			const first = deferred<CatalogPage>();
			const second = deferred<CatalogPage>();
			const get = vi.fn().mockReturnValueOnce(first.promise).mockReturnValueOnce(second.promise);
			const loader = createCatalogLoader(get);

			await captureUnhandled(async () => {
				loader.load('?q=a');
				loader.load('?q=b');
				first.reject(boom);
				await flush();
			}, [boom]);

			expect(loader.state.error).toBeNull();
			expect(loader.state.seq).toBe(0);
			expect(loader.state.pending).toBe(true);
			expect(vi.getTimerCount()).toBe(1);

			second.resolve(page(2));
			await flush();
			expect(loader.state.result).toEqual(page(2));
			expect(loader.state.seq).toBe(1);
		});
	});

	it('retry repete a última search', async () => {
		const get = vi.fn().mockResolvedValue(page(1));
		const loader = createCatalogLoader(get);

		loader.load('?colors%5B%5D=Red');
		loader.retry();

		expect(get).toHaveBeenCalledTimes(2);
		expect(get).toHaveBeenNthCalledWith(2, '/api/catalog?colors%5B%5D=Red');
		await flush();
	});

	it('retry depois de load vazio chama /api/catalog', async () => {
		const get = vi.fn().mockResolvedValue(page(1));
		const loader = createCatalogLoader(get);

		loader.load('');
		await flush();
		loader.retry();

		expect(get).toHaveBeenCalledTimes(2);
		expect(get).toHaveBeenNthCalledWith(2, '/api/catalog');
		await flush();
	});

	it('retry depois de um erro refaz a última search e o sucesso zera o erro', async () => {
		const failure = new ApiError(0, 'network_error', 'Sem conexão com o servidor.');
		const get = vi.fn().mockRejectedValueOnce(failure).mockResolvedValueOnce(page(1));
		const loader = createCatalogLoader(get);

		loader.load('?q=b');
		await flush();
		expect(loader.state.error).toBe(failure);
		expect(loader.state.seq).toBe(1);

		loader.retry();
		expect(loader.state.pending).toBe(true);
		await flush();

		expect(get).toHaveBeenCalledTimes(2);
		expect(get).toHaveBeenNthCalledWith(2, '/api/catalog?q=b');
		expect(loader.state.error).toBeNull();
		expect(loader.state.result).toEqual(page(1));
		expect(loader.state.seq).toBe(2);
		expect(loader.state.pending).toBe(false);
	});
});
