import '@testing-library/jest-dom/vitest';
import { cleanup, fireEvent, render, screen } from '@testing-library/svelte';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { CatalogMeta } from '../api/types';

vi.mock('$app/paths', () => ({ resolve: (path: string) => `/app${path}` }));

import CatalogPagination from './CatalogPagination.svelte';

afterEach(cleanup);

const meta = (page: number, total_pages: number): CatalogMeta => ({
	page,
	per_page: 30,
	total_count: total_pages * 30,
	total_pages,
	active_filters: { colors: ['Red'], sort: 'name' }
});

const props = (page: number, total_pages: number) => ({ meta: meta(page, total_pages), onpage: vi.fn() });

describe('CatalogPagination', () => {
	it('página 1 de 3: sem "Anterior", com "Próxima" para page=2 mantendo os filtros', () => {
		render(CatalogPagination, props(1, 3));
		expect(screen.getByRole('navigation', { name: 'Paginação do catálogo' })).toBeInTheDocument();
		expect(screen.queryByRole('link', { name: 'Anterior' })).toBeNull();
		expect(screen.getByText('Página 1 de 3')).toBeInTheDocument();
		const next = screen.getByRole('link', { name: 'Próxima' });
		expect(next).toHaveAttribute('href', '/app?colors%5B%5D=Red&sort=name&page=2');
		expect(next).toHaveAttribute('rel', 'next');
		expect(next).toHaveAttribute('data-sveltekit-reset', 'false');
	});

	it('página 2 de 3: os dois links', () => {
		render(CatalogPagination, props(2, 3));
		const prev = screen.getByRole('link', { name: 'Anterior' });
		expect(prev).toHaveAttribute('href', '/app?colors%5B%5D=Red&sort=name&page=1');
		expect(prev).toHaveAttribute('rel', 'prev');
		expect(prev).toHaveAttribute('data-sveltekit-reset', 'false');
		expect(screen.getByRole('link', { name: 'Próxima' })).toBeInTheDocument();
	});

	it('página 3 de 3: só "Anterior"', () => {
		render(CatalogPagination, props(3, 3));
		expect(screen.getByRole('link', { name: 'Anterior' })).toBeInTheDocument();
		expect(screen.queryByRole('link', { name: 'Próxima' })).toBeNull();
	});

	it('total_pages 1: nada renderizado', () => {
		render(CatalogPagination, props(1, 1));
		expect(screen.queryByRole('navigation')).toBeNull();
	});

	it('página 5 com total_pages 3: "Anterior" presente e sem "Próxima"', () => {
		render(CatalogPagination, props(5, 3));
		expect(screen.getByRole('link', { name: 'Anterior' })).toHaveAttribute(
			'href',
			'/app?colors%5B%5D=Red&sort=name&page=4'
		);
		expect(screen.queryByRole('link', { name: 'Próxima' })).toBeNull();
	});

	it('clique em qualquer link chama onpage()', async () => {
		const p = props(2, 3);
		render(CatalogPagination, p);
		await fireEvent.click(screen.getByRole('link', { name: 'Próxima' }));
		await fireEvent.click(screen.getByRole('link', { name: 'Anterior' }));
		expect(p.onpage).toHaveBeenCalledTimes(2);
	});

	it.each([
		['Ctrl', { ctrlKey: true }],
		['Meta', { metaKey: true }],
		['Shift', { shiftKey: true }],
		['Alt', { altKey: true }],
		['botão do meio', { button: 1 }]
	])('clique com %s não chama onpage', async (_name, init) => {
		const p = props(2, 3);
		render(CatalogPagination, p);
		await fireEvent.click(screen.getByRole('link', { name: 'Próxima' }), init);
		await fireEvent.click(screen.getByRole('link', { name: 'Anterior' }), init);
		expect(p.onpage).not.toHaveBeenCalled();
	});

	it('ativação por teclado (Enter no link dispara click sem modificador) chama onpage', () => {
		const p = props(2, 3);
		render(CatalogPagination, p);
		const link = screen.getByRole('link', { name: 'Próxima' });
		link.focus();
		link.click();
		expect(p.onpage).toHaveBeenCalledOnce();
	});
});
