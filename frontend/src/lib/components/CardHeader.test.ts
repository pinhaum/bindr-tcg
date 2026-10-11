import '@testing-library/jest-dom/vitest';
import { cleanup, render, screen } from '@testing-library/svelte';
import { afterEach, describe, expect, it, vi } from 'vitest';

const wideQuery = vi.hoisted(() => {
	const query = { matches: false, addEventListener() {}, removeEventListener() {} };
	vi.stubGlobal('matchMedia', () => query);
	return query;
});

import { markCard, morphName } from '../cards/morph.svelte';
import type { CardDetailPayload, DetailVariant } from '../api/types';
import CardHeader from './CardHeader.svelte';

const variant = (over: Partial<DetailVariant> = {}): DetailVariant => ({
	variant_code: 'tcgplayer:1',
	rarity: 'SR',
	art_kind: 'base',
	set: { code: 'OP01', name: 'Romance Dawn' },
	illustrator: null,
	image_url: '/card_images/1',
	in_source: true,
	owned_quantity: 0,
	wishlist_target: 0,
	price: null,
	...over
});

const card = (over: Partial<CardDetailPayload> = {}): CardDetailPayload => ({
	card_number: 'OP01-003',
	name: 'Monkey.D.Luffy',
	card_type: 'character',
	colors: ['red', 'green'],
	cost: 4,
	life: null,
	power: 5000,
	counter: 1000,
	block_icon: null,
	attributes: [],
	traits: [],
	effect_text: null,
	trigger_text: null,
	set: { code: 'OP01', name: 'Romance Dawn' },
	featured_variant_code: 'tcgplayer:1',
	variants: [variant()],
	...over
});

const renderHeader = (props: Partial<{ card: CardDetailPayload; featured: DetailVariant | null; owned: number; signedIn: boolean }> = {}) =>
	render(CardHeader, { card: card(), featured: variant(), owned: 0, signedIn: false, ...props });

const named = (container: HTMLElement) =>
	[...container.querySelectorAll<HTMLElement>('*')].filter((el) => el.style.viewTransitionName);

describe('CardHeader', () => {
	afterEach(() => {
		cleanup();
		wideQuery.matches = false;
		markCard(null);
	});

	it('mostra o nome em h1 e os chips de tipo, raridade e cores', () => {
		renderHeader();

		expect(screen.getByRole('heading', { level: 1, name: 'Monkey.D.Luffy' })).toBeInTheDocument();
		const items = screen.getAllByRole('listitem').map((li) => li.textContent?.trim());
		expect(items).toEqual(['Character', 'SR', 'red', 'green']);
	});

	it('mostra a linha "<set> · <código>" da variante em destaque', () => {
		renderHeader({ featured: variant({ set: { code: 'OP05', name: 'Awakening' } }) });

		expect(screen.getByText('Awakening · OP05')).toBeInTheDocument();
	});

	it('omite a raridade quando a variante não a tem', () => {
		renderHeader({ featured: variant({ rarity: null }) });

		expect(screen.getAllByRole('listitem').map((li) => li.textContent?.trim())).toEqual([
			'Character',
			'red',
			'green'
		]);
	});

	it('mostra o chip Counter só a partir de 64rem, em Character com counter não nulo', () => {
		renderHeader();
		expect(screen.queryByText('Counter 1000')).toBeNull();
		cleanup();

		wideQuery.matches = true;
		renderHeader();
		expect(screen.getByText('Counter 1000')).toBeInTheDocument();
		cleanup();

		renderHeader({ card: card({ counter: 0 }) });
		expect(screen.getByText('Counter 0')).toBeInTheDocument();
		cleanup();

		renderHeader({ card: card({ counter: null }) });
		expect(screen.queryByText(/Counter/)).toBeNull();
		cleanup();

		renderHeader({ card: card({ card_type: 'event', counter: 2000 }) });
		expect(screen.queryByText(/Counter/)).toBeNull();
	});

	it('abaixo de 64rem tem a miniatura e um <details> fechado "Ver imagem maior"', () => {
		const { container } = renderHeader();

		const details = container.querySelector('details');
		expect(details).not.toBeNull();
		expect(details).not.toHaveAttribute('open');
		expect(screen.getByText('Ver imagem maior')).toBeInTheDocument();
		expect(details!.querySelector('summary')).toHaveTextContent('Ver imagem maior');
	});

	it('a partir de 64rem mostra a imagem numa coluna, sem <details>', () => {
		wideQuery.matches = true;
		const { container } = renderHeader();

		expect(container.querySelector('details')).toBeNull();
		expect(screen.queryByText('Ver imagem maior')).toBeNull();
		expect(container.querySelectorAll('img')).toHaveLength(1);
	});

	it('mostra "Variante fora da fonte" só com in_source false', () => {
		renderHeader({ featured: variant({ in_source: false }) });
		expect(screen.getByText('Variante fora da fonte')).toBeInTheDocument();
		cleanup();

		renderHeader();
		expect(screen.queryByText('Variante fora da fonte')).toBeNull();
	});

	it('mostra "Ilustração: X" só com illustrator', () => {
		renderHeader({ featured: variant({ illustrator: 'Eiichiro Oda' }) });
		expect(screen.getByText('Ilustração: Eiichiro Oda')).toBeInTheDocument();
		cleanup();

		renderHeader();
		expect(screen.queryByText(/Ilustração/)).toBeNull();
	});

	it('mostra o selo de posse com sessão e valor maior que zero, pelo valor recebido', () => {
		renderHeader({ signedIn: true, owned: 1 });
		expect(screen.getByRole('img', { name: '1 cópia' })).toBeInTheDocument();
		cleanup();

		renderHeader({ signedIn: true, owned: 3, featured: variant({ owned_quantity: 0 }) });
		expect(screen.getByRole('img', { name: '3 cópias' })).toBeInTheDocument();
	});

	it('não mostra o selo sem sessão ou com valor zero', () => {
		renderHeader({ signedIn: false, owned: 2 });
		expect(screen.queryByRole('img', { name: /cópia/ })).toBeNull();
		cleanup();

		renderHeader({ signedIn: true, owned: 0 });
		expect(screen.queryByRole('img', { name: /cópia/ })).toBeNull();
	});

	it.each([false, true])(
		'com a carta marcada, um só elemento leva o view-transition-name (wide=%s)',
		(wide) => {
			wideQuery.matches = wide;
			markCard('OP01-003');
			const { container } = renderHeader();

			const els = named(container);
			expect(els).toHaveLength(1);
			expect(els[0].style.viewTransitionName).toBe(morphName('OP01-003'));
			expect(els[0].closest('details')).toBeNull();
		}
	);

	it('sem a carta marcada nenhum elemento leva o nome', () => {
		const { container } = renderHeader();

		expect(named(container)).toHaveLength(0);
	});

	it('usa "<nome> <variant_code>" como texto alternativo da imagem principal', () => {
		const { container } = renderHeader();

		expect(container.querySelector('img')).toHaveAttribute('alt', 'Monkey.D.Luffy tcgplayer:1');
	});

	it('sem variante em destaque mostra o card_number da carta; com variante não', () => {
		const paragraphs = (container: HTMLElement) =>
			[...container.querySelectorAll('p')].map((p) => p.textContent?.trim());

		const { container } = renderHeader({ featured: null });
		expect(paragraphs(container)).toEqual(['OP01-003']);
		cleanup();

		const withVariant = renderHeader();
		expect(paragraphs(withVariant.container)).not.toContain('OP01-003');
	});

	it('mostra o placeholder sem imagem e sem variante em destaque', () => {
		const { container } = renderHeader({ featured: null });

		expect(container.querySelector('img')).toBeNull();
		expect(screen.getByRole('heading', { level: 1 })).toBeInTheDocument();
		expect(screen.getAllByRole('listitem').map((li) => li.textContent?.trim())).toEqual([
			'Character',
			'red',
			'green'
		]);
	});
});
