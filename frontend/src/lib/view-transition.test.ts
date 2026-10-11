import { afterEach, describe, expect, it, vi } from 'vitest';

const reduced = vi.hoisted(() => ({ current: false }));
vi.mock('svelte/motion', () => ({ prefersReducedMotion: reduced }));

import { armArrival, markCard, signalArrival } from './cards/morph.svelte';
import { viewTransitionOnNavigate } from './view-transition';

const navigation = (complete: Promise<void> = Promise.resolve()) =>
	({ complete }) as Parameters<typeof viewTransitionOnNavigate>[0];

describe('viewTransitionOnNavigate', () => {
	afterEach(() => {
		reduced.current = false;
		Reflect.deleteProperty(document, 'startViewTransition');
	});

	it('não lança nem devolve nada sem document.startViewTransition', () => {
		expect(() => viewTransitionOnNavigate(navigation())).not.toThrow();
		expect(viewTransitionOnNavigate(navigation())).toBeUndefined();
	});

	it('não chama startViewTransition com movimento reduzido', () => {
		const start = vi.fn();
		Object.assign(document, { startViewTransition: start });
		reduced.current = true;

		expect(viewTransitionOnNavigate(navigation())).toBeUndefined();
		expect(start).not.toHaveBeenCalled();
	});

	const between = (from: string, to: string) =>
		({
			from: { url: new URL(from, 'http://localhost') },
			to: { url: new URL(to, 'http://localhost'), route: { id: null } },
			complete: Promise.resolve()
		}) as unknown as Parameters<typeof viewTransitionOnNavigate>[0];

	it('não chama startViewTransition quando só a query muda', () => {
		const start = vi.fn();
		Object.assign(document, { startViewTransition: start });

		expect(
			viewTransitionOnNavigate(between('/app?colors%5B%5D=Red', '/app?colors%5B%5D=Green'))
		).toBeUndefined();
		expect(start).not.toHaveBeenCalled();
	});

	it('chama startViewTransition entre rotas diferentes', () => {
		const start = vi.fn();
		Object.assign(document, { startViewTransition: start });

		void viewTransitionOnNavigate(between('/app', '/app/entrar'));
		expect(start).toHaveBeenCalledOnce();
	});

	it('envolve a troca de rota na transição e mantém a atualização até navigation.complete', async () => {
		let finish!: () => void;
		const complete = new Promise<void>((resolve) => (finish = resolve));
		let update!: Promise<void>;
		const start = vi.fn((callback: () => Promise<void>) => {
			update = callback();
		});
		Object.assign(document, { startViewTransition: start });

		await viewTransitionOnNavigate(navigation(complete));
		expect(start).toHaveBeenCalledOnce();

		let settled = false;
		void update.then(() => (settled = true));
		await Promise.resolve();
		expect(settled).toBe(false);
		finish();
		await update;
		expect(settled).toBe(true);
	});

	describe('com carta marcada (morph)', () => {
		const settled = (promise: Promise<void>) => {
			const state = { done: false };
			void promise.then(() => (state.done = true));
			return state;
		};
		const toRoute = (routeId: string | null) =>
			({
				from: { url: new URL('/app/cartas/OP01-001', 'http://localhost') },
				to: { url: new URL('/app/x', 'http://localhost'), route: { id: routeId } },
				complete: Promise.resolve()
			}) as unknown as Parameters<typeof viewTransitionOnNavigate>[0];
		const startUpdate = async (routeId: string | null = '/cartas/[card_number]') => {
			let update!: Promise<void>;
			Object.assign(document, {
				startViewTransition: vi.fn((callback: () => Promise<void>) => {
					update = callback();
				})
			});
			await viewTransitionOnNavigate(toRoute(routeId));
			return settled(update);
		};

		afterEach(() => {
			markCard(null);
			vi.useRealTimers();
		});

		it('espera a chegada do destino depois de navigation.complete', async () => {
			markCard('OP01-001');
			const update = await startUpdate();
			await Promise.resolve();
			await Promise.resolve();
			expect(update.done).toBe(false);

			signalArrival();
			await vi.waitFor(() => expect(update.done).toBe(true));
		});

		it('não espera se o destino chegou antes de o callback consumir a espera', async () => {
			markCard('OP01-001');
			const update = await startUpdate();
			signalArrival();

			await vi.waitFor(() => expect(update.done).toBe(true));
		});

		it('descarta a chegada de uma navegação anterior', async () => {
			markCard('OP01-001');
			signalArrival();
			const update = await startUpdate();
			await Promise.resolve();
			await Promise.resolve();

			expect(update.done).toBe(false);
			signalArrival();
		});

		it('libera a transição no teto de 500 ms quando o destino não chega', async () => {
			vi.useFakeTimers();
			markCard('OP01-001');
			const update = await startUpdate();
			await vi.advanceTimersByTimeAsync(499);
			expect(update.done).toBe(false);

			await vi.advanceTimersByTimeAsync(1);
			expect(update.done).toBe(true);
		});

		it('espera a chegada também quando o destino é o catálogo', async () => {
			vi.useFakeTimers();
			markCard('OP01-001');
			const update = await startUpdate('/');
			await vi.advanceTimersByTimeAsync(499);
			expect(update.done).toBe(false);

			await vi.advanceTimersByTimeAsync(1);
			expect(update.done).toBe(true);
		});

		it.each([['/entrar'], ['/criar-conta'], [null]])(
			'destino %s com carta marcada não espera chegada (G1)',
			async (routeId) => {
				vi.useFakeTimers();
				markCard('OP01-001');
				const update = await startUpdate(routeId);
				await vi.advanceTimersByTimeAsync(0);

				expect(update.done).toBe(true);
			}
		);

		it('sem carta marcada não espera chegada nenhuma', async () => {
			vi.useFakeTimers();
			markCard(null);
			armArrival();
			const update = await startUpdate('/');
			await vi.advanceTimersByTimeAsync(0);

			expect(update.done).toBe(true);
		});

		it('sem carta marcada não espera chegada nenhuma (tempo real)', async () => {
			markCard(null);
			armArrival();
			const update = await startUpdate();

			await vi.waitFor(() => expect(update.done).toBe(true));
		});
	});
});
