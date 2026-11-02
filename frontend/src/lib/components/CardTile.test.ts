import '@testing-library/jest-dom/vitest';
import { cleanup, fireEvent, render, screen } from '@testing-library/svelte';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { hasMark, isMarked, markCard, morphName } from '../cards/morph.svelte';
import type { CatalogCard, CatalogVariant } from '../api/types';
import CardTile from './CardTile.svelte';

vi.mock('$app/paths', () => ({ resolve: (path: string) => path }));

beforeEach(() => markCard(null));
afterEach(cleanup);

const variant = (over: Partial<CatalogVariant> = {}): CatalogVariant => ({
	variant_code: 'tcgplayer:1',
	rarity: 'SR',
	art_kind: 'base',
	set: { code: 'OP01', name: 'Romance Dawn' },
	illustrator: null,
	image_url: '/cards/images/tcgplayer:1',
	in_source: true,
	owned_quantity: null,
	wishlist_target: null,
	price: null,
	...over
});

const card = (over: Partial<CatalogCard> = {}): CatalogCard => ({
	card_number: 'OP01-001',
	name: 'Roronoa Zoro',
	card_type: 'Leader',
	colors: ['Red'],
	cost: null,
	life: 5,
	power: 5000,
	counter: null,
	block_icon: null,
	attributes: [],
	traits: [],
	effect_text: null,
	trigger_text: null,
	set: { code: 'OP01', name: 'Romance Dawn' },
	variants: [variant()],
	...over
});

const owned = (...quantities: (number | null)[]) =>
	quantities.map((q, i) => variant({ variant_code: `tcgplayer:${i + 1}`, owned_quantity: q }));

describe('CardTile', () => {
	it.each([
		['Ctrl', { ctrlKey: true }],
		['Meta', { metaKey: true }],
		['Shift', { shiftKey: true }],
		['Alt', { altKey: true }],
		['botão do meio', { button: 1 }]
	])('clique com %s não marca a carta para o morph (G2)', async (_, init) => {
		render(CardTile, { card: card(), signedIn: false });
		const link = screen.getByRole('link');
		link.addEventListener('click', (event) => event.preventDefault());
		await fireEvent.click(link, init);
		expect(hasMark()).toBe(false);
	});

	it('clique simples marca a carta para o morph', async () => {
		render(CardTile, { card: card(), signedIn: false });
		const link = screen.getByRole('link');
		link.addEventListener('click', (event) => event.preventDefault());
		await fireEvent.click(link);
		expect(isMarked('OP01-001')).toBe(true);
	});

	// SCAR-03 emenda o SCAT-03: o tile leva ao detalhe da SPA, sem recarregar a página.
	it('é um <li> com link para /cartas/<card_number> na SPA (SCAR-03)', () => {
		const { container } = render(CardTile, { card: card(), signedIn: false });
		expect(container.querySelector('li')).not.toBeNull();
		const link = screen.getByRole('link');
		expect(link).toHaveAttribute('href', '/cartas/OP01-001');
		expect(link).not.toHaveAttribute('rel', 'external');
		expect(link).not.toHaveAttribute('data-sveltekit-reload');
	});

	it('codifica o card_number com # ou ? no href', () => {
		render(CardTile, { card: card({ card_number: 'OP01-0#1?x' }), signedIn: false });
		expect(screen.getByRole('link')).toHaveAttribute('href', '/cartas/OP01-0%231%3Fx');
	});

	it('o clique marca a carta e só a arte do tile marcado recebe view-transition-name (SCAR-39)', async () => {
		const { container } = render(CardTile, { card: card(), signedIn: false });
		const art = container.querySelector<HTMLElement>('.art')!;
		expect(art.style.viewTransitionName).toBe('');
		await fireEvent.click(screen.getByRole('link'));
		expect(art.style.viewTransitionName).toBe(morphName('OP01-001'));
	});

	it('tile de outra carta marcada não recebe o nome (SCAR-40: um só na grade)', () => {
		markCard('OP01-002');
		const { container } = render(CardTile, { card: card(), signedIn: false });
		expect(container.querySelector<HTMLElement>('.art')!.style.viewTransitionName).toBe('');
	});

	it('carta já marcada (volta do detalhe) mostra o nome na arte (SCAR-40)', () => {
		markCard('OP01-001');
		const { container } = render(CardTile, { card: card(), signedIn: false });
		expect(container.querySelector<HTMLElement>('.art')!.style.viewTransitionName).toBe(
			morphName('OP01-001')
		);
	});

	it('mostra nome e card_number, e a imagem da primeira variante (SCAT-10)', () => {
		const { container } = render(CardTile, {
			card: card({
				variants: [
					variant({ image_url: '/cards/images/a' }),
					variant({ variant_code: 'tcgplayer:2', image_url: '/cards/images/b' })
				]
			}),
			signedIn: false
		});
		const img = container.querySelector('img');
		expect(img).toHaveAttribute('src', '/cards/images/a');
		expect(img).toHaveAttribute('alt', '');
		expect(img).toHaveAttribute('loading', 'lazy');
		expect(container.querySelector('.name')).toHaveTextContent('Roronoa Zoro');
		expect(container.querySelector('.number')).toHaveTextContent('OP01-001');
	});

	it('placeholder aria-hidden com nome e código existe com image_url (SCAT-11)', () => {
		const { container } = render(CardTile, { card: card(), signedIn: false });
		const placeholder = container.querySelector('.placeholder');
		expect(placeholder).toHaveAttribute('aria-hidden', 'true');
		expect(placeholder).toHaveTextContent('Roronoa Zoro');
		expect(placeholder).toHaveTextContent('OP01-001');
		expect(container.querySelector('img')).not.toBeNull();
	});

	it('sem image_url há placeholder e nenhum <img> (SCAT-11)', () => {
		const { container } = render(CardTile, {
			card: card({ variants: [variant({ image_url: null })] }),
			signedIn: false
		});
		expect(container.querySelector('.placeholder')).toHaveAttribute('aria-hidden', 'true');
		expect(container.querySelector('img')).toBeNull();
	});

	it('o evento error da imagem não troca elemento nem classe (SCAT-11)', async () => {
		const { container } = render(CardTile, { card: card(), signedIn: false });
		const before = container.innerHTML;
		await fireEvent.error(container.querySelector('img')!);
		expect(container.innerHTML).toBe(before);
		expect(container.querySelector('img')).not.toBeNull();
		expect(container.querySelector('.placeholder')).not.toBeNull();
	});

	it('uma variante mostra a raridade dela (SCAT-12)', () => {
		const { container } = render(CardTile, { card: card(), signedIn: false });
		expect(container.querySelector('.rarity')).toHaveTextContent('SR');
	});

	it('uma variante com rarity null não mostra texto de raridade (SCAT-12)', () => {
		const { container } = render(CardTile, {
			card: card({ variants: [variant({ rarity: null })] }),
			signedIn: false
		});
		expect(container.querySelector('.rarity')?.textContent?.trim() ?? '').toBe('');
	});

	it('duas variantes mostram "2 impressões" no lugar da raridade (SCAT-12)', () => {
		const { container } = render(CardTile, {
			card: card({ variants: owned(null, null) }),
			signedIn: false
		});
		expect(container.querySelector('.rarity')).toHaveTextContent('2 impressões');
		expect(container.textContent).not.toContain('SR');
	});

	it('três variantes mostram "3 impressões" no lugar da raridade (SCAT-12)', () => {
		const { container } = render(CardTile, {
			card: card({ variants: owned(null, null, null) }),
			signedIn: false
		});
		expect(container.querySelector('.rarity')).toHaveTextContent('3 impressões');
		expect(container.textContent).not.toContain('SR');
	});

	it('com sessão e soma 3 mostra o selo "3 cópias" com o número (SCAT-13)', () => {
		render(CardTile, { card: card({ variants: owned(1, 2) }), signedIn: true });
		const badge = screen.getByRole('img', { name: '3 cópias' });
		expect(badge).toHaveTextContent('3');
	});

	it('o nome do link começa pela identificação da carta e termina com o selo', () => {
		render(CardTile, { card: card({ variants: owned(3) }), signedIn: true });
		const name = /^Roronoa Zoro\s*OP01-001\s*SR\s*3 cópias$/;
		expect(screen.getByRole('link', { name })).toBeInTheDocument();
	});

	it('com soma 1 o nome acessível é "1 cópia"', () => {
		render(CardTile, { card: card({ variants: owned(1) }), signedIn: true });
		expect(screen.getByRole('img', { name: '1 cópia' })).toBeInTheDocument();
	});

	it('ignora owned_quantity null na soma', () => {
		render(CardTile, { card: card({ variants: owned(null, 2) }), signedIn: true });
		expect(screen.getByRole('img', { name: '2 cópias' })).toBeInTheDocument();
	});

	it.each([
		['soma 0', [0], true],
		['owned_quantity null', [null], true],
		['sem sessão', [3], false]
	])('sem selo com %s', (_label, quantities, signedIn) => {
		render(CardTile, { card: card({ variants: owned(...quantities) }), signedIn });
		expect(screen.queryByRole('img')).toBeNull();
	});

	it('não tem nenhum botão', () => {
		render(CardTile, { card: card({ variants: owned(2) }), signedIn: true });
		expect(screen.queryByRole('button')).toBeNull();
	});
});
