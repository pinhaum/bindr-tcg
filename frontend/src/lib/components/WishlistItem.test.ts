import '@testing-library/jest-dom/vitest';
import { cleanup, fireEvent, render, screen } from '@testing-library/svelte';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { afterEach, describe, expect, it, vi } from 'vitest';
import WishlistItem from './WishlistItem.svelte';

vi.mock('$app/paths', () => ({ resolve: (path: string) => path }));

const base = {
	cardNumber: 'OP01-001',
	cardName: 'Luffy',
	variantCode: 'tcgplayer:1',
	targetQuantity: 2,
	ownedQuantity: 0
};

afterEach(cleanup);

describe('WishlistItem', () => {
	it('liga ao detalhe da carta com o nome e o código da variante (SPAS-30)', () => {
		render(WishlistItem, { ...base, onremove: vi.fn() });
		const link = screen.getByRole('link', { name: 'Luffy tcgplayer:1' });
		expect(link).toHaveAttribute('href', '/cartas/OP01-001');
		const code = screen.getByText('tcgplayer:1');
		expect(code.tagName).toBe('CODE');
		expect(link).toContainElement(code);
	});

	it('codifica o card_number reservado no href (SPAS-30)', () => {
		render(WishlistItem, { ...base, cardNumber: 'A/B?C', onremove: vi.fn() });
		expect(screen.getByRole('link', { name: 'Luffy tcgplayer:1' })).toHaveAttribute(
			'href',
			'/cartas/A%2FB%3FC'
		);
	});

	it('usa o plural pelo alvo (SPAS-30)', () => {
		const { unmount } = render(WishlistItem, {
			...base,
			targetQuantity: 1,
			ownedQuantity: 1,
			onremove: vi.fn()
		});
		expect(screen.getByText('1 de 1 cópia')).toBeInTheDocument();
		unmount();
		render(WishlistItem, { ...base, onremove: vi.fn() });
		expect(screen.getByText('0 de 2 cópias')).toBeInTheDocument();
	});

	it('mostra "Atendido" quando a posse atinge ou excede o alvo (SPAS-31)', () => {
		render(WishlistItem, { ...base, ownedQuantity: 3, onremove: vi.fn() });
		expect(screen.getByText('Atendido')).toBeInTheDocument();
		expect(screen.queryByText(/Faltam/)).toBeNull();
	});

	it('mostra "Faltam N" quando não atendido (SPAS-31)', () => {
		render(WishlistItem, { ...base, onremove: vi.fn() });
		expect(screen.getByText('Faltam 2')).toBeInTheDocument();
		expect(screen.queryByText('Atendido')).toBeNull();
	});

	it('nomeia o botão com o estado do item (SPAS-32)', () => {
		const { unmount } = render(WishlistItem, { ...base, ownedQuantity: 2, onremove: vi.fn() });
		expect(
			screen.getByRole('button', {
				name: 'Remover Luffy tcgplayer:1 da lista de desejos (atendido)'
			})
		).toBeInTheDocument();
		unmount();
		render(WishlistItem, { ...base, onremove: vi.fn() });
		expect(
			screen.getByRole('button', {
				name: 'Remover Luffy tcgplayer:1 da lista de desejos (faltam 2)'
			})
		).toBeInTheDocument();
	});

	it('declara alvo mínimo de 44px no CSS (SPAS-32)', () => {
		const source = readFileSync(resolve(__dirname, 'WishlistItem.svelte'), 'utf8');
		expect(source).toMatch(/min-block-size:\s*var\(--touch-target\)/);
		expect(source).toMatch(/min-inline-size:\s*var\(--touch-target\)/);
	});

	it('chama onremove ao clicar (SPAS-33)', async () => {
		const onremove = vi.fn();
		render(WishlistItem, { ...base, onremove });
		await fireEvent.click(screen.getByRole('button', { name: /^Remover Luffy/ }));
		expect(onremove).toHaveBeenCalledTimes(1);
	});

	it('com pending desabilita o botão e não chama onremove (SPAS-35)', async () => {
		const onremove = vi.fn();
		render(WishlistItem, { ...base, pending: true, onremove });
		const button = screen.getByRole('button', { name: /^Remover Luffy/ });
		expect(button).toBeDisabled();
		button.click();
		expect(onremove).not.toHaveBeenCalled();
	});
});
