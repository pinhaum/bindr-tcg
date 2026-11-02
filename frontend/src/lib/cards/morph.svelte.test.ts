import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
	armArrival,
	awaitArrival,
	hasMark,
	isMarked,
	markCard,
	morphName,
	signalArrival
} from './morph.svelte';

const CUSTOM_IDENT = /^[A-Za-z][A-Za-z0-9_-]*$/;

describe('morphName', () => {
	it('gera <custom-ident> válido e distinto para códigos de carta', () => {
		const names = ['OP01-001', 'P-029', 'ST01.001 x', '1', '--x', 'é'].map(morphName);
		for (const name of names) expect(name).toMatch(CUSTOM_IDENT);
		expect(new Set(names).size).toBe(names.length);
	});

	it('é determinístico', () => {
		expect(morphName('OP01-001')).toBe(morphName('OP01-001'));
	});

	it('não confunde um código com o escape de outro', () => {
		expect(morphName('a.b')).not.toBe(morphName('a_2e_b'));
		expect(morphName('a b')).not.toBe(morphName('a.b'));
	});
});

describe('markCard', () => {
	beforeEach(() => markCard(null));

	it('marcar uma carta substitui a anterior', () => {
		markCard('OP01-001');
		markCard('P-029');
		expect(isMarked('P-029')).toBe(true);
		expect(isMarked('OP01-001')).toBe(false);
	});

	it('sem marca, nenhuma carta é marcada', () => {
		expect(isMarked('OP01-001')).toBe(false);
	});
});

describe('hasMark', () => {
	beforeEach(() => markCard(null));

	it('só é verdadeiro com uma carta marcada', () => {
		expect(hasMark()).toBe(false);
		markCard('OP01-001');
		expect(hasMark()).toBe(true);
		markCard(null);
		expect(hasMark()).toBe(false);
	});
});

describe('awaitArrival / signalArrival', () => {
	beforeEach(() => {
		vi.useFakeTimers();
		armArrival();
	});
	afterEach(() => vi.useRealTimers());

	const track = (promise: Promise<void>) => {
		const state = { done: false };
		void promise.then(() => (state.done = true));
		return state;
	};

	it('resolve quando a chegada é sinalizada, antes do teto', async () => {
		const waiting = track(awaitArrival(500));
		await vi.advanceTimersByTimeAsync(100);
		expect(waiting.done).toBe(false);

		signalArrival();
		await vi.advanceTimersByTimeAsync(0);
		expect(waiting.done).toBe(true);
		expect(vi.getTimerCount()).toBe(0);
	});

	it('resolve sozinha ao fim do teto, sem rejeitar', async () => {
		const waiting = track(awaitArrival(500));
		await vi.advanceTimersByTimeAsync(499);
		expect(waiting.done).toBe(false);

		await vi.advanceTimersByTimeAsync(1);
		expect(waiting.done).toBe(true);
	});

	it('resolve na hora quando a chegada veio antes de a espera começar', async () => {
		signalArrival();
		const waiting = track(awaitArrival(500));
		await vi.advanceTimersByTimeAsync(0);

		expect(waiting.done).toBe(true);
		expect(vi.getTimerCount()).toBe(0);
	});

	it('armArrival descarta a chegada da navegação anterior', async () => {
		signalArrival();
		armArrival();
		const waiting = track(awaitArrival(500));
		await vi.advanceTimersByTimeAsync(499);

		expect(waiting.done).toBe(false);
		signalArrival();
	});

	it('duas esperas simultâneas resolvem juntas com um único sinal', async () => {
		const first = track(awaitArrival(500));
		const second = track(awaitArrival(500));

		signalArrival();
		await vi.advanceTimersByTimeAsync(0);
		expect(first.done && second.done).toBe(true);
	});

	it('sinalizar sem espera pendente não lança', () => {
		expect(() => signalArrival()).not.toThrow();
	});
});
