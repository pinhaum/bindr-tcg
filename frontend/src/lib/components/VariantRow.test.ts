import '@testing-library/jest-dom/vitest';
import { cleanup, fireEvent, render, screen, within } from '@testing-library/svelte';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { DetailVariant } from '../api/types';
import { toasts } from '../toasts.svelte';

vi.mock('$app/paths', () => ({ resolve: (path: string) => path }));
vi.mock('$app/state', async () => {
	const { SvelteURL } = await import('svelte/reactivity');
	return { page: { url: new SvelteURL('http://localhost/cartas/OP01-001?variant=tcgplayer:1') } };
});

const post = vi.hoisted(() => vi.fn());
vi.mock('../api', () => ({ api: { post, put: vi.fn() } }));

import VariantRow from './VariantRow.svelte';

const card = { card_number: 'OP01-001', name: 'Luffy' };
const variant = (overrides: Partial<DetailVariant> = {}): DetailVariant => ({
	variant_code: 'tcgplayer:1',
	rarity: 'R',
	art_kind: 'base',
	set: { code: 'OP01', name: 'Romance Dawn' },
	illustrator: null,
	image_url: 'https://cdn.example/1.jpg',
	in_source: true,
	owned_quantity: 2,
	wishlist_target: null,
	price: { amount: '1234.56', currency: 'USD', observed_at: '2026-10-05T12:00:00Z' },
	...overrides
});

const setup = (props: Partial<{ variant: DetailVariant; featured: boolean; signedIn: boolean }> = {}) => {
	const onSelect = vi.fn();
	const view = render(VariantRow, {
		card,
		variant: variant(),
		featured: false,
		signedIn: true,
		onSelect,
		...props
	});
	return { onSelect, view };
};

describe('VariantRow', () => {
	beforeEach(() => {
		post.mockReset();
		toasts.splice(0);
	});
	afterEach(cleanup);

	it('SCAR-19: miniatura sem alt e lazy, código em <code>, raridade · arte e set', () => {
		const { view } = setup();
		const img = view.container.querySelector('img')!;
		expect(img).toHaveAttribute('alt', '');
		expect(img).toHaveAttribute('loading', 'lazy');
		expect(view.container.querySelector('code')).toHaveTextContent('tcgplayer:1');
		expect(view.container).toHaveTextContent('R · arte base');
		expect(view.container).toHaveTextContent('Romance Dawn (OP01)');
	});

	it.each([
		['parallel', 'SR', 'SR · parallel'],
		['alternate', 'SEC', 'SEC · alternativa']
	])('SCAR-19: art_kind %s', (art_kind, rarity, text) => {
		const { view } = setup({ variant: variant({ art_kind, rarity }) });
		expect(view.container).toHaveTextContent(text);
	});

	it('SCAR-19: sem rarity omite o rótulo', () => {
		const { view } = setup({ variant: variant({ rarity: null }) });
		expect(view.container).not.toHaveTextContent('arte base');
	});

	it('SCAR-20: "fora da fonte" só com in_source false', () => {
		expect(setup().view.container).not.toHaveTextContent('fora da fonte');
		cleanup();
		expect(setup({ variant: variant({ in_source: false }) }).view.container).toHaveTextContent(
			'fora da fonte'
		);
	});

	it('SCAR-21: preço USD com fonte e data, com e sem sessão', () => {
		for (const signedIn of [true, false]) {
			const { view } = setup({ signedIn });
			expect(view.container).toHaveTextContent('US$ 1.234,56');
			expect(view.container).toHaveTextContent('TCGplayer · market · 05/10/2026');
			cleanup();
		}
	});

	it('SCAR-21: moeda diferente usa o código; null mostra "Sem preço"', () => {
		let { view } = setup({
			variant: variant({ price: { amount: '12', currency: 'EUR', observed_at: '2026-10-05T12:00:00Z' } })
		});
		expect(view.container).toHaveTextContent('EUR 12,00');
		cleanup();
		({ view } = setup({ variant: variant({ price: null }), signedIn: false }));
		expect(view.container).toHaveTextContent('Sem preço');
		expect(view.container).not.toHaveTextContent('TCGplayer');
	});

	it('SCAR-22: miniatura é link nomeado com aria-current só no destaque', () => {
		setup({ featured: true });
		const link = screen.getByRole('link', { name: 'Mostrar tcgplayer:1 na imagem principal' });
		expect(link).toHaveAttribute('href', '/cartas/OP01-001?variant=tcgplayer%3A1');
		expect(link).toHaveAttribute('aria-current', 'true');
		cleanup();
		setup({ featured: false });
		expect(
			screen.getByRole('link', { name: 'Mostrar tcgplayer:1 na imagem principal' })
		).not.toHaveAttribute('aria-current');
	});

	it('SCAR-23: clique chama onSelect e não navega', async () => {
		const { onSelect } = setup();
		const link = screen.getByRole('link', { name: 'Mostrar tcgplayer:1 na imagem principal' });
		const notPrevented = await fireEvent.click(link);
		expect(notPrevented).toBe(false);
		expect(onSelect).toHaveBeenCalledExactlyOnceWith('tcgplayer:1');
	});

	it('SCAR-25/35: com sessão mostra posse e desejo', () => {
		const { view } = setup();
		expect(view.container).toHaveTextContent('2 cópias');
		expect(screen.getByRole('button', { name: 'Adicionar uma cópia de Luffy tcgplayer:1' })).toBeInTheDocument();
		expect(
			within(screen.getByRole('group', { name: 'Marcar Luffy tcgplayer:1 como desejada' })).getByLabelText('Quero')
		).toBeInTheDocument();
		expect(screen.queryByRole('link', { name: 'Entrar para registrar posse' })).not.toBeInTheDocument();
	});

	it('SCAR-25: o stepper envia pela API da variante', async () => {
		post.mockResolvedValue({ variant_code: 'tcgplayer:1', owned_quantity: 3 });
		setup();
		await fireEvent.click(screen.getByRole('button', { name: 'Adicionar uma cópia de Luffy tcgplayer:1' }));
		expect(post).toHaveBeenCalledWith('/api/cards/OP01-001/variants/tcgplayer%3A1/increment');
	});

	it('SCAR-26: sem sessão só o convite, com return_to do caminho e query atuais', () => {
		setup({ signedIn: false });
		const link = screen.getByRole('link', { name: 'Entrar para registrar posse' });
		expect(link).toHaveAttribute(
			'href',
			`/entrar?return_to=${encodeURIComponent('/cartas/OP01-001?variant=tcgplayer:1')}`
		);
		expect(screen.queryByRole('group')).not.toBeInTheDocument();
		expect(screen.queryByRole('button')).not.toBeInTheDocument();
	});
});
