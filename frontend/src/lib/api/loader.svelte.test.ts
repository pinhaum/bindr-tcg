import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiError } from './errors';
import { createLoader } from './loader.svelte';

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
const apiError = () => new ApiError(500, 'internal_error', 'Algo deu errado.', {});

describe('createLoader', () => {
	beforeEach(() => {
		vi.useFakeTimers();
	});

	afterEach(() => {
		vi.useRealTimers();
	});

	it('repassa a chave crua e retry repete a última', async () => {
		const fetcher = vi.fn().mockResolvedValue('a');
		const loader = createLoader<string>(fetcher);

		loader.load('?order=code');
		await flush();
		loader.retry();

		expect(fetcher).toHaveBeenNthCalledWith(1, '?order=code');
		expect(fetcher).toHaveBeenNthCalledWith(2, '?order=code');
	});

	it('guarda o resultado e incrementa seq', async () => {
		const loader = createLoader<string>(vi.fn().mockResolvedValue('a'));

		loader.load('');
		expect(loader.state.pending).toBe(true);
		await flush();

		expect(loader.state).toMatchObject({ result: 'a', error: null, pending: false, seq: 1 });
	});

	it('retry antes de qualquer load não busca nada', () => {
		const fetcher = vi.fn().mockResolvedValue('a');
		const loader = createLoader<string>(fetcher);

		loader.retry();

		expect(fetcher).not.toHaveBeenCalled();
		expect(loader.state.pending).toBe(false);
	});

	it('guarda a resposta como veio, sem proxy reativo', async () => {
		const payload = { items: [{ id: 1 }] };
		const loader = createLoader<typeof payload>(vi.fn().mockResolvedValue(payload));

		loader.load('');
		await flush();

		expect(loader.state.result).toBe(payload);
		expect(loader.state.result?.items).toBe(payload.items);
	});

	it('slow só vira true após 200 ms e o resultado anterior permanece', async () => {
		const first = deferred<string>();
		const second = deferred<string>();
		const fetcher = vi.fn().mockReturnValueOnce(first.promise).mockReturnValueOnce(second.promise);
		const loader = createLoader<string>(fetcher);

		loader.load('1');
		first.resolve('antigo');
		await flush();
		loader.load('2');

		await vi.advanceTimersByTimeAsync(199);
		expect(loader.state.slow).toBe(false);
		expect(loader.state.result).toBe('antigo');
		await vi.advanceTimersByTimeAsync(1);
		expect(loader.state.slow).toBe(true);
		expect(loader.state.result).toBe('antigo');

		second.resolve('novo');
		await flush();
		expect(loader.state).toMatchObject({ result: 'novo', pending: false, slow: false });
	});

	it('descarta a resposta de um load superado', async () => {
		const old = deferred<string>();
		const fresh = deferred<string>();
		const fetcher = vi.fn().mockReturnValueOnce(old.promise).mockReturnValueOnce(fresh.promise);
		const loader = createLoader<string>(fetcher);

		loader.load('1');
		loader.load('2');
		old.resolve('velho');
		await flush();

		expect(loader.state).toMatchObject({ result: null, pending: true, seq: 0 });

		fresh.resolve('novo');
		await flush();
		expect(loader.state).toMatchObject({ result: 'novo', seq: 1 });
	});

	it('descarta o erro de um load superado', async () => {
		const old = deferred<string>();
		const fetcher = vi.fn().mockReturnValueOnce(old.promise).mockReturnValue(new Promise(() => {}));
		const loader = createLoader<string>(fetcher);

		loader.load('1');
		loader.load('2');
		old.reject(apiError());
		await flush();

		expect(loader.state).toMatchObject({ error: null, pending: true, seq: 0 });
	});

	it('ApiError vai para error e zera pending e slow', async () => {
		const failure = deferred<string>();
		const loader = createLoader<string>(vi.fn().mockReturnValue(failure.promise));

		loader.load('');
		await vi.advanceTimersByTimeAsync(200);
		expect(loader.state.slow).toBe(true);
		const error = apiError();
		failure.reject(error);
		await flush();

		expect(loader.state).toMatchObject({ error, pending: false, slow: false, seq: 1 });
	});

	it('um novo load bem-sucedido limpa o erro', async () => {
		const fetcher = vi.fn().mockRejectedValueOnce(apiError()).mockResolvedValueOnce('ok');
		const loader = createLoader<string>(fetcher);

		loader.load('');
		await flush();
		loader.retry();
		await flush();

		expect(loader.state).toMatchObject({ result: 'ok', error: null });
	});

	it('relança erro que não é ApiError e encerra o estado pendente', async () => {
		const boom = new TypeError('boom');
		const loader = createLoader<string>(vi.fn().mockRejectedValue(boom));
		const unhandled = vi.fn();
		process.once('unhandledRejection', unhandled);

		loader.load('');
		await flush();

		expect(unhandled).toHaveBeenCalledWith(boom, expect.anything());
		expect(loader.state).toMatchObject({ pending: false, slow: false });
	});
});
