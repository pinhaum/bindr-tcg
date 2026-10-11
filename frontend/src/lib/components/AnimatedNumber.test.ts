import '@testing-library/jest-dom/vitest';
import { cleanup, render } from '@testing-library/svelte';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { flushSync } from 'svelte';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { formatPrice } from '../format';
import AnimatedNumber from './AnimatedNumber.svelte';

const reduced = vi.hoisted(() => ({ current: false }));
vi.mock('svelte/motion', async () => {
	vi.stubGlobal('matchMedia', () => ({
		matches: false,
		addEventListener: () => {},
		removeEventListener: () => {}
	}));
	return { ...(await vi.importActual<typeof import('svelte/motion')>('svelte/motion')), prefersReducedMotion: reduced };
});

const money = (cents: number) => formatPrice((cents / 100).toFixed(2), 'USD');
const props = (amount: string) => ({
	value: Math.round(Number(amount) * 100),
	format: money,
	finalText: formatPrice(amount, 'USD')
});

function visible(container: HTMLElement) {
	return container.querySelector<HTMLElement>('.number')!;
}

function hidden(container: HTMLElement) {
	return container.querySelector<HTMLElement>('.visually-hidden')!;
}

function advance(ms: number) {
	vi.advanceTimersByTime(ms);
	flushSync();
}

beforeEach(() => {
	reduced.current = false;
	vi.useFakeTimers({ toFake: ['requestAnimationFrame', 'cancelAnimationFrame', 'performance'] });
});

afterEach(() => {
	cleanup();
	vi.useRealTimers();
});

describe('AnimatedNumber', () => {
	it('começa em 0 com o texto acessível já final e termina em 320 ms no texto final', () => {
		const { container } = render(AnimatedNumber, {
			value: 42,
			format: String,
			finalText: '42'
		});
		flushSync();
		expect(visible(container)).toHaveTextContent('0');
		expect(hidden(container)).toHaveTextContent('42');

		advance(160);
		const mid = Number(visible(container).textContent);
		expect(mid).toBeGreaterThan(0);
		expect(mid).toBeLessThan(42);
		expect(hidden(container)).toHaveTextContent('42');

		advance(200);
		expect(visible(container)).toHaveTextContent('42');
	});

	it('anima de US$ 10,00 a US$ 12,50 na troca de valor e não anima com o mesmo valor', async () => {
		const view = render(AnimatedNumber, props('10.00'));
		flushSync();
		advance(400);
		expect(visible(view.container)).toHaveTextContent('US$ 10,00');

		await view.rerender(props('10.00'));
		advance(0);
		expect(visible(view.container)).toHaveTextContent('US$ 10,00');
		advance(100);
		expect(visible(view.container)).toHaveTextContent('US$ 10,00');

		await view.rerender(props('12.50'));
		advance(100);
		const mid = visible(view.container).textContent!;
		expect(mid).not.toBe('US$ 10,00');
		expect(mid).not.toBe('US$ 12,50');
		expect(hidden(view.container)).toHaveTextContent('US$ 12,50');

		advance(400);
		expect(visible(view.container)).toHaveTextContent('US$ 12,50');
	});

	it('com reduced motion o primeiro quadro já é o final', () => {
		reduced.current = true;
		const { container } = render(AnimatedNumber, props('12.50'));
		expect(visible(container)).toHaveTextContent('US$ 12,50');
	});

	it('reserva a largura final com uma cópia invisível escondida da acessibilidade', () => {
		const { container } = render(AnimatedNumber, props('1234.56'));
		const reserve = container.querySelector<HTMLElement>('.reserve')!;
		expect(reserve).toHaveTextContent('US$ 1.234,56');
		expect(reserve).toHaveAttribute('aria-hidden', 'true');
		const source = readFileSync(resolve(__dirname, 'AnimatedNumber.svelte'), 'utf8');
		expect(source).toContain('visibility: hidden');
		expect(source).toContain('grid-area: 1 / 1');
		advance(400);
	});

	it('com value 0 mostra 0 sem animar', () => {
		const { container } = render(AnimatedNumber, { value: 0, format: String, finalText: '0' });
		flushSync();
		advance(400);
		expect(visible(container)).toHaveTextContent('0');
		expect(hidden(container)).toHaveTextContent('0');
	});

	it('redireciona a animação no meio do caminho para o novo valor', async () => {
		const view = render(AnimatedNumber, { value: 0, format: String, finalText: '0' });
		await view.rerender({ value: 100, format: String, finalText: '100' });
		advance(160);
		const mid = Number(visible(view.container).textContent);
		expect(mid).toBeGreaterThan(0);
		expect(mid).toBeLessThan(100);

		await view.rerender({ value: 200, format: String, finalText: '200' });
		advance(100);
		const retargeted = Number(visible(view.container).textContent);
		expect(retargeted).toBeGreaterThan(mid);
		expect(retargeted).toBeLessThan(200);
		expect(hidden(view.container)).toHaveTextContent('200');

		advance(400);
		expect(visible(view.container)).toHaveTextContent('200');
	});

	it('termina em US$ 1.234,56 sem erro de ponto flutuante', () => {
		const { container } = render(AnimatedNumber, props('1234.56'));
		flushSync();
		advance(400);
		expect(visible(container)).toHaveTextContent('US$ 1.234,56');
		expect(hidden(container)).toHaveTextContent('US$ 1.234,56');
	});

	it('esconde o visível da árvore de acessibilidade e não declara região viva', () => {
		const { container } = render(AnimatedNumber, props('10.00'));
		expect(visible(container)).toHaveAttribute('aria-hidden', 'true');
		expect(container.querySelector('[aria-live]')).toBeNull();
		expect(container.querySelector('[role="status"]')).toBeNull();
	});

	it('declara algarismos tabulares no estilo', () => {
		const source = readFileSync(resolve(__dirname, 'AnimatedNumber.svelte'), 'utf8');
		expect(source).toContain('font-variant-numeric: tabular-nums');
	});
});
