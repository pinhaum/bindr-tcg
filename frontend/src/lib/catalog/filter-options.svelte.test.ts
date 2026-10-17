import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { FilterOptions } from '../api/types';

const api = vi.hoisted(() => ({ get: vi.fn() }));
vi.mock('../api/index', () => ({ api }));

const options: FilterOptions = {
	colors: ['Red', 'Green'],
	card_types: ['leader', 'character'],
	rarities: ['C', 'SR'],
	sets: [{ code: 'OP01', name: 'Romance Dawn' }]
};

const deferred = <T>() => {
	let resolve!: (value: T) => void;
	let reject!: (reason: unknown) => void;
	const promise = new Promise<T>((res, rej) => {
		resolve = res;
		reject = rej;
	});
	return { promise, resolve, reject };
};

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

// O reset recarrega `../api/errors` junto com o módulo: o `ApiError` do teste tem de vir do mesmo grafo.
const load = async () => {
	vi.resetModules();
	const [{ ApiError }, state] = await Promise.all([import('../api/errors'), import('./filter-options.svelte')]);
	return { ApiError, ...state };
};

describe('filterOptions', () => {
	beforeEach(() => {
		api.get.mockReset();
	});

	it('começa vazio e sem carga em curso', async () => {
		const { filterOptions } = await load();

		expect(filterOptions).toEqual({ value: null, error: null, loading: false });
	});

	it('busca /api/catalog/filters e guarda o valor recebido', async () => {
		const pending = deferred<FilterOptions>();
		api.get.mockReturnValue(pending.promise);
		const { filterOptions, ensureFilterOptions } = await load();

		ensureFilterOptions();
		expect(filterOptions.loading).toBe(true);
		expect(api.get).toHaveBeenCalledWith('/api/catalog/filters');

		pending.resolve(options);
		await flush();

		expect(filterOptions).toEqual({ value: options, error: null, loading: false });
	});

	it('faz um único GET com duas chamadas, antes e depois da resposta', async () => {
		const pending = deferred<FilterOptions>();
		api.get.mockReturnValue(pending.promise);
		const { ensureFilterOptions } = await load();

		ensureFilterOptions();
		ensureFilterOptions();
		pending.resolve(options);
		await flush();
		ensureFilterOptions();

		expect(api.get).toHaveBeenCalledTimes(1);
	});

	it('grava a message da API em error e zera loading ao falhar', async () => {
		const { ApiError, filterOptions, ensureFilterOptions } = await load();
		const failure = new ApiError(500, 'internal_error', 'Algo deu errado.');
		api.get.mockRejectedValue(failure);

		ensureFilterOptions();
		await flush();

		expect(filterOptions.error).toBe(failure);
		expect(filterOptions.error?.message).toBe('Algo deu errado.');
		expect(filterOptions.value).toBeNull();
		expect(filterOptions.loading).toBe(false);
	});

	it('refaz a chamada ao tentar de novo e zera error com sucesso', async () => {
		const { ApiError, filterOptions, ensureFilterOptions, retryFilterOptions } = await load();
		api.get
			.mockRejectedValueOnce(new ApiError(500, 'internal_error', 'Algo deu errado.'))
			.mockResolvedValueOnce(options);

		ensureFilterOptions();
		await flush();
		retryFilterOptions();
		expect(filterOptions.loading).toBe(true);
		await flush();

		expect(api.get).toHaveBeenCalledTimes(2);
		expect(filterOptions).toEqual({ value: options, error: null, loading: false });
	});

	it('tenta de novo a partir de ensure depois de uma falha', async () => {
		const { ApiError, filterOptions, ensureFilterOptions } = await load();
		api.get.mockRejectedValueOnce(new ApiError(0, 'network_error', 'Sem conexão.')).mockResolvedValueOnce(options);

		ensureFilterOptions();
		await flush();
		ensureFilterOptions();
		await flush();

		expect(api.get).toHaveBeenCalledTimes(2);
		expect(filterOptions.value).toEqual(options);
	});

	it('ignora retry com a carga em curso', async () => {
		api.get.mockReturnValue(deferred<FilterOptions>().promise);
		const { ensureFilterOptions, retryFilterOptions } = await load();

		ensureFilterOptions();
		retryFilterOptions();

		expect(api.get).toHaveBeenCalledTimes(1);
	});
});
