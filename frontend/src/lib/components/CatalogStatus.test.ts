import '@testing-library/jest-dom/vitest';
import { cleanup, render, screen } from '@testing-library/svelte';
import { afterEach, describe, expect, it } from 'vitest';
import CatalogStatus from './CatalogStatus.svelte';

afterEach(cleanup);

describe('CatalogStatus', () => {
	it.each([
		[2815, 0, '2815 cartas'],
		[1, 1, '1 carta · 1 filtro ativo'],
		[30, 3, '30 cartas · 3 filtros ativos'],
		[0, 0, '0 cartas']
	])('total %i e chipCount %i → "%s"', (total, chipCount, text) => {
		const { container } = render(CatalogStatus, { total, chipCount });
		expect(container.querySelector('p')?.textContent?.trim()).toBe(text);
	});

	it('o parágrafo da frase é focável por script', () => {
		const { container } = render(CatalogStatus, { total: 5, chipCount: 0 });
		expect(container.querySelector('p')).toHaveAttribute('tabindex', '-1');
	});

	it('focus() põe o foco no parágrafo da frase', () => {
		const { container, component } = render(CatalogStatus, { total: 5, chipCount: 0 });
		(component as unknown as { focus: () => void }).focus();
		expect(document.activeElement).toBe(container.querySelector('p'));
	});

	it('sem props de link não mostra links', () => {
		render(CatalogStatus, { total: 5, chipCount: 0 });
		expect(screen.queryByRole('link')).toBeNull();
	});

	it('clearHref mostra "Limpar filtros" com o href e sem reset de scroll', () => {
		render(CatalogStatus, { total: 5, chipCount: 1, clearHref: '/app?sort=name' });
		const link = screen.getByRole('link', { name: 'Limpar filtros' });
		expect(link).toHaveAttribute('href', '/app?sort=name');
		expect(link).toHaveAttribute('data-sveltekit-reset', 'false');
	});

	it('signInHref mostra "Entrar para registrar posse" com o href', () => {
		render(CatalogStatus, {
			total: 5,
			chipCount: 0,
			signInHref: '/app/entrar?return_to=%2Fapp%3Fq%3Dluffy'
		});
		expect(screen.getByRole('link', { name: 'Entrar para registrar posse' })).toHaveAttribute(
			'href',
			'/app/entrar?return_to=%2Fapp%3Fq%3Dluffy'
		);
		expect(screen.queryByRole('link', { name: 'Limpar filtros' })).toBeNull();
	});
});
