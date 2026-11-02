import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { dismiss, notifyError, notifySuccess, toasts } from './toasts.svelte';

describe('toasts', () => {
	beforeEach(() => {
		vi.useFakeTimers();
	});

	afterEach(() => {
		toasts.splice(0);
		vi.useRealTimers();
	});

	it('notifySuccess adiciona a mensagem e a remove aos 5000 ms, não antes', () => {
		notifySuccess('Sessão encerrada.');

		expect(toasts).toHaveLength(1);
		expect(toasts[0]).toMatchObject({ kind: 'success', message: 'Sessão encerrada.' });

		vi.advanceTimersByTime(4999);
		expect(toasts).toHaveLength(1);

		vi.advanceTimersByTime(1);
		expect(toasts).toHaveLength(0);
	});

	it('notifyError permanece até dismiss', () => {
		notifyError('Falha ao salvar.');
		vi.advanceTimersByTime(60_000);

		expect(toasts).toHaveLength(1);
		expect(toasts[0]).toMatchObject({ kind: 'error', message: 'Falha ao salvar.' });

		dismiss(toasts[0].id);
		expect(toasts).toHaveLength(0);
	});

	it('dismiss remove só a mensagem indicada e ignora id desconhecido', () => {
		notifyError('A');
		notifyError('B');
		const [a, b] = toasts;

		expect(a.id).not.toBe(b.id);
		dismiss(9999);
		expect(toasts).toHaveLength(2);

		dismiss(a.id);
		expect(toasts.map((t) => t.message)).toEqual(['B']);
	});

	it('dismiss antes dos 5000 ms não quebra o timer do sucesso', () => {
		notifySuccess('Ok');
		dismiss(toasts[0].id);

		expect(() => vi.advanceTimersByTime(5000)).not.toThrow();
		expect(toasts).toHaveLength(0);
	});
});
