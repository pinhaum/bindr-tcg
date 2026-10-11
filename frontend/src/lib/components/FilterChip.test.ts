import '@testing-library/jest-dom/vitest';
import { cleanup, render, screen } from '@testing-library/svelte';
import { afterEach, describe, expect, it } from 'vitest';
import FilterChip from './FilterChip.svelte';

afterEach(cleanup);

describe('FilterChip', () => {
	it('inativo é link com o href dado, nome acessível = rótulo e sem ×', () => {
		const { container } = render(FilterChip, { href: '/app?colors=Red', label: 'Red', active: false });
		const link = screen.getByRole('link', { name: 'Red' });
		expect(link).toHaveAttribute('href', '/app?colors=Red');
		expect(link).not.toHaveAttribute('aria-current');
		expect(container.textContent).not.toContain('×');
	});

	it('ativo mostra o rótulo, × aria-hidden e nome acessível removeName', () => {
		render(FilterChip, {
			href: '/app',
			label: 'Cor: Red',
			active: true,
			removeName: 'Remover filtro Cor: Red'
		});
		const link = screen.getByRole('link', { name: 'Remover filtro Cor: Red' });
		expect(link).toHaveTextContent('Cor: Red');
		const cross = link.querySelector('[aria-hidden="true"]');
		expect(cross).toHaveTextContent('×');
		expect(link).toHaveClass('active');
	});

	it('current põe aria-current="true" e não mostra ×', () => {
		const { container } = render(FilterChip, { href: '/app', label: 'Todas', active: false, current: true });
		expect(screen.getByRole('link', { name: 'Todas' })).toHaveAttribute('aria-current', 'true');
		expect(container.textContent).not.toContain('×');
	});

	it('todo chip tem data-sveltekit-reset="false"', () => {
		render(FilterChip, { href: '/app', label: 'Red', active: false });
		expect(screen.getByRole('link')).toHaveAttribute('data-sveltekit-reset', 'false');
	});

	it('swatch acrescenta o quadrado neutro aria-hidden', () => {
		render(FilterChip, { href: '/app', label: 'Red', active: false, swatch: true });
		const link = screen.getByRole('link', { name: 'Red' });
		expect(link.querySelector('.swatch')).toHaveAttribute('aria-hidden', 'true');
	});

	it('sem swatch não há quadrado', () => {
		render(FilterChip, { href: '/app', label: 'Red', active: false });
		expect(screen.getByRole('link').querySelector('.swatch')).toBeNull();
	});
});
