import '@testing-library/jest-dom/vitest';
import { cleanup, render, screen } from '@testing-library/svelte';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { ProgressSet } from '../api/types';

vi.mock('$app/paths', () => ({ resolve: (path: string) => path }));

import SetProgressRow from './SetProgressRow.svelte';

afterEach(cleanup);

const makeSet = (over: Partial<ProgressSet> = {}): ProgressSet => ({
	code: 'OP01',
	name: 'Romance Dawn',
	owned_numbers: 3,
	base_size: 7,
	completion_percent: 43,
	parallel_owned: 1,
	parallel_total: 1,
	value: { amount: '1234.56', currency: 'USD' },
	...over
});

describe('SetProgressRow', () => {
	it('link do nome para o catálogo do set, com nome acessível e code em <code> (SPAS-19)', () => {
		const { container } = render(SetProgressRow, { set: makeSet() });
		const link = screen.getByRole('link', { name: 'Romance Dawn (OP01): ver no catálogo' });
		expect(link).toHaveAttribute('href', '/?sets[]=OP01');
		expect(link).toHaveTextContent('Romance Dawn');
		expect(container.querySelector('code')).toHaveTextContent('OP01');
	});

	it('codifica caractere reservado do code no href (SPAS-19)', () => {
		render(SetProgressRow, { set: makeSet({ code: 'A&B#1', name: 'X' }) });
		expect(screen.getByRole('link')).toHaveAttribute('href', '/?sets[]=A%26B%231');
	});

	it('com base_size: números, barra aria-hidden e legenda (SPAS-20)', () => {
		const { container } = render(SetProgressRow, { set: makeSet() });
		expect(screen.getByText('3 / 7 · 43%')).toBeInTheDocument();
		const bar = container.querySelector('progress');
		expect(bar).toHaveAttribute('aria-hidden', 'true');
		expect(bar).toHaveAttribute('value', '3');
		expect(bar).toHaveAttribute('max', '7');
		expect(screen.getByText('3 de 7 do set base')).toBeInTheDocument();
	});

	it('sem base_size: só owned_numbers, sem barra nem percentual (SPAS-21)', () => {
		const { container } = render(SetProgressRow, {
			set: makeSet({ base_size: null, completion_percent: null, owned_numbers: 5 })
		});
		expect(container.querySelector('progress')).toBeNull();
		expect(container.textContent).not.toMatch(/%/);
		expect(container.textContent).not.toContain('0%');
		expect(screen.getByText('5')).toBeInTheDocument();
		expect(
			screen.getByText('Percentual indisponível: este set não informa o tamanho do set base.')
		).toBeInTheDocument();
	});

	it('parallels no singular e no plural, fora do percentual (SPAS-22)', () => {
		const { unmount } = render(SetProgressRow, { set: makeSet() });
		const one = screen.getByText('1 de 1 parallel');
		expect(one.tagName).toBe('P');
		expect(one).not.toContainElement(screen.getByText('3 / 7 · 43%'));
		expect(screen.getByText('3 / 7 · 43%')).not.toContainElement(one);
		unmount();
		render(SetProgressRow, { set: makeSet({ parallel_owned: 0, parallel_total: 2 }) });
		expect(screen.getByText('0 de 2 parallels').tagName).toBe('P');
	});

	it('subtotal em US$ (SPAS-23)', () => {
		const { unmount } = render(SetProgressRow, { set: makeSet() });
		expect(screen.getByText('valor US$ 1.234,56')).toBeInTheDocument();
		unmount();
		render(SetProgressRow, { set: makeSet({ value: { amount: '0.00', currency: 'USD' } }) });
		expect(screen.getByText('valor US$ 0,00')).toBeInTheDocument();
	});
});
