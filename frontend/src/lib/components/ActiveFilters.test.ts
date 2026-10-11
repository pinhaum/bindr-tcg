import '@testing-library/jest-dom/vitest';
import { cleanup, fireEvent, render, screen, within } from '@testing-library/svelte';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { Chip } from '../catalog/url';
import ActiveFilters from './ActiveFilters.svelte';

afterEach(cleanup);

const chips: Chip[] = [
	{ key: 'colors', value: 'Red', label: 'Cor', text: 'Cor: Red', href: '/app?types[]=Leader' },
	{ key: 'card_types', value: 'Leader', label: 'Tipo', text: 'Tipo: Leader', href: '/app?colors[]=Red' },
	{ key: 'owned', value: 'owned', label: 'Posse', text: 'Posse: Tenho', href: '/app?q=luffy' }
];

describe('ActiveFilters', () => {
	it('três chips viram três links na lista "Filtros ativos" com nome e href do chip', () => {
		render(ActiveFilters, { chips, onremove: vi.fn() });
		const list = screen.getByRole('list', { name: 'Filtros ativos' });
		const links = within(list).getAllByRole('link');
		expect(links).toHaveLength(3);
		chips.forEach((chip, i) => {
			expect(links[i]).toHaveAccessibleName(`Remover filtro ${chip.text}`);
			expect(links[i]).toHaveAttribute('href', chip.href);
		});
	});

	it('clicar o segundo chama onremove(1)', async () => {
		const onremove = vi.fn();
		render(ActiveFilters, { chips, onremove });
		await fireEvent.click(screen.getByRole('link', { name: 'Remover filtro Tipo: Leader' }));
		expect(onremove).toHaveBeenCalledExactlyOnceWith(1);
	});

	it.each([
		['Ctrl', { ctrlKey: true }],
		['Meta', { metaKey: true }],
		['Shift', { shiftKey: true }],
		['Alt', { altKey: true }],
		['botão do meio', { button: 1 }]
	])('clique com %s não chama onremove', async (_name, init) => {
		const onremove = vi.fn();
		render(ActiveFilters, { chips, onremove });
		await fireEvent.click(screen.getByRole('link', { name: 'Remover filtro Tipo: Leader' }), init);
		expect(onremove).not.toHaveBeenCalled();
	});

	it('ativação por teclado (Enter no link dispara click sem modificador) chama onremove', () => {
		const onremove = vi.fn();
		render(ActiveFilters, { chips, onremove });
		const link = screen.getByRole('link', { name: 'Remover filtro Cor: Red' });
		link.focus();
		link.click();
		expect(onremove).toHaveBeenCalledExactlyOnceWith(0);
	});

	it('lista vazia não renderiza a <ul>', () => {
		render(ActiveFilters, { chips: [], onremove: vi.fn() });
		expect(screen.queryByRole('list')).toBeNull();
	});
});
