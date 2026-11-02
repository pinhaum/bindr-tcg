import '@testing-library/jest-dom/vitest';
import { cleanup, render } from '@testing-library/svelte';
import { flushSync } from 'svelte';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { ProgressPayload } from '../api/types';

const reduced = vi.hoisted(() => ({ current: false }));
vi.mock('svelte/motion', async () => {
	vi.stubGlobal('matchMedia', () => ({
		matches: false,
		addEventListener: () => {},
		removeEventListener: () => {}
	}));
	return {
		...(await vi.importActual<typeof import('svelte/motion')>('svelte/motion')),
		prefersReducedMotion: reduced
	};
});

import PastaSummary from './PastaSummary.svelte';

beforeEach(() => {
	vi.useFakeTimers({ toFake: ['requestAnimationFrame', 'cancelAnimationFrame', 'performance'] });
});

afterEach(() => {
	vi.advanceTimersByTime(1000);
	cleanup();
	vi.useRealTimers();
});

const makeSummary = (over: Partial<ProgressPayload['summary']> = {}): ProgressPayload['summary'] => ({
	total_copies: 10,
	distinct_variants: 4,
	estimated_value: { amount: '1234.56', currency: 'USD' },
	unpriced_copies: 0,
	...over
});

const accessibleText = (el: Element) => {
	const clone = el.cloneNode(true) as Element;
	clone.querySelectorAll('[aria-hidden="true"]').forEach((hidden) => hidden.remove());
	return clone.textContent?.replace(/\s+/g, ' ').trim();
};

const cards = (container: HTMLElement) =>
	Array.from(container.querySelectorAll('.card')).map(accessibleText);

describe('PastaSummary', () => {
	it('três cartões na ordem cópias, diferentes, valor (SPAS-08)', () => {
		const { container } = render(PastaSummary, { summary: makeSummary() });
		expect(cards(container)).toEqual([
			expect.stringContaining('10 cartas na pasta'),
			expect.stringContaining('4 cartas diferentes'),
			expect.stringContaining('US$ 1.234,56 valor estimado')
		]);
	});

	it.each([
		[0, '0 cartas na pasta', '0 cartas diferentes'],
		[1, '1 carta na pasta', '1 carta diferente'],
		[2, '2 cartas na pasta', '2 cartas diferentes']
	])('plural com %i (SPAS-08)', (n, copiesText, distinctText) => {
		const { container } = render(PastaSummary, {
			summary: makeSummary({ total_copies: n, distinct_variants: n })
		});
		const [first, second] = cards(container);
		expect(first).toContain(copiesText);
		expect(second).toContain(distinctText);
	});

	it.each([
		[1, '1 cópia sem preço'],
		[2, '2 cópias sem preço']
	])('nota com %i cópia(s) sem preço (SPAS-09)', (n, note) => {
		const { container } = render(PastaSummary, { summary: makeSummary({ unpriced_copies: n }) });
		expect(cards(container)[2]).toContain(note);
	});

	it('sem nota com zero cópias sem preço (SPAS-09)', () => {
		const { container } = render(PastaSummary, { summary: makeSummary({ unpriced_copies: 0 }) });
		expect(accessibleText(container)).not.toContain('sem preço');
	});

	it('"0.00" vira US$ 0,00 (SPAS-10)', () => {
		const { container } = render(PastaSummary, {
			summary: makeSummary({ estimated_value: { amount: '0.00', currency: 'USD' } })
		});
		expect(cards(container)[2]).toContain('US$ 0,00 valor estimado');
	});

	it('texto acessível é o valor final seguido do rótulo (SPAS-15)', () => {
		const { container } = render(PastaSummary, { summary: makeSummary() });
		const first = container.querySelector('.card')!;
		expect(first.querySelector('.visually-hidden')).toHaveTextContent('10');
		expect(first.querySelector('.number')).toHaveAttribute('aria-hidden', 'true');
		expect(accessibleText(first)).toBe('10 cartas na pasta');
	});

	it('interpola o valor em centavos e termina em US$ 12,50 (SPAS-13)', async () => {
		const view = render(PastaSummary, {
			summary: makeSummary({ estimated_value: { amount: '10.00', currency: 'USD' } })
		});
		flushSync();
		vi.advanceTimersByTime(400);
		flushSync();
		const number = () => view.container.querySelectorAll('.number')[2];
		expect(number()).toHaveTextContent('US$ 10,00');

		await view.rerender({
			summary: makeSummary({ estimated_value: { amount: '12.50', currency: 'USD' } })
		});
		vi.advanceTimersByTime(160);
		flushSync();
		const mid = number().textContent!;
		expect(mid).toMatch(/US\$\s10,\d\d|US\$\s11,\d\d|US\$\s12,\d\d/);
		expect(mid).not.toMatch(/,00$/);
		expect(mid).not.toContain('12,50');

		vi.advanceTimersByTime(400);
		flushSync();
		expect(number()).toHaveTextContent('US$ 12,50');
	});

	it('estado final "1234.56" é US$ 1.234,56 (SPAS-10)', () => {
		const { container } = render(PastaSummary, { summary: makeSummary() });
		flushSync();
		vi.advanceTimersByTime(400);
		flushSync();
		expect(container.querySelectorAll('.number')[2]).toHaveTextContent('US$ 1.234,56');
	});
});
