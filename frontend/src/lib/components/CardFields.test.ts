import '@testing-library/jest-dom/vitest';
import { cleanup, render, screen } from '@testing-library/svelte';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { afterEach, describe, expect, it } from 'vitest';
import type { CatalogCard } from '../api/types';
import CardFields from './CardFields.svelte';

afterEach(cleanup);

const card = (over: Partial<CatalogCard> = {}): CatalogCard => ({
	card_number: 'OP01-001',
	name: 'Roronoa Zoro',
	card_type: 'character',
	colors: ['Red'],
	cost: 3,
	life: 5,
	power: 5000,
	counter: 1000,
	block_icon: 1,
	attributes: ['Slash'],
	traits: ['Straw Hat Crew', 'Supernovas'],
	effect_text: null,
	trigger_text: null,
	set: { code: 'OP01', name: 'Romance Dawn' },
	variants: [],
	...over
});

const labels = () => Array.from(document.querySelectorAll('dt')).map((dt) => dt.textContent);

describe('CardFields — campos por tipo (SCAR-17)', () => {
	it('leader mostra Power, Life, Attribute, Traits e Block, e não Custo nem Counter', () => {
		render(CardFields, { card: card({ card_type: 'leader' }) });
		expect(labels()).toEqual(['Power', 'Life', 'Attribute', 'Traits', 'Block']);
	});

	it('character mostra Custo, Power, Counter, Attribute, Traits e Block, e não Life', () => {
		render(CardFields, { card: card() });
		expect(labels()).toEqual(['Custo', 'Power', 'Counter', 'Attribute', 'Traits', 'Block']);
	});

	it.each(['event', 'stage'])('%s mostra Custo, Attribute, Traits e Block', (card_type) => {
		render(CardFields, { card: card({ card_type }) });
		expect(labels()).toEqual(['Custo', 'Attribute', 'Traits', 'Block']);
	});

	it('character com counter null não mostra Counter; com 0 mostra 0', () => {
		const { unmount } = render(CardFields, { card: card({ counter: null }) });
		expect(labels()).not.toContain('Counter');
		unmount();
		render(CardFields, { card: card({ counter: 0 }) });
		const dt = screen.getByText('Counter');
		expect(dt.nextElementSibling).toHaveTextContent(/^0$/);
	});

	it('exibe 0 como valor', () => {
		render(CardFields, { card: card({ cost: 0 }) });
		expect(screen.getByText('Custo').nextElementSibling).toHaveTextContent(/^0$/);
	});

	it('lista vazia omite o campo e listas são unidas por ", "', () => {
		const { unmount } = render(CardFields, { card: card({ attributes: [], traits: [] }) });
		expect(labels()).not.toContain('Attribute');
		expect(labels()).not.toContain('Traits');
		unmount();
		render(CardFields, { card: card({ attributes: ['Slash', 'Strike'] }) });
		expect(screen.getByText('Attribute').nextElementSibling).toHaveTextContent('Slash, Strike');
		expect(screen.getByText('Traits').nextElementSibling).toHaveTextContent(
			'Straw Hat Crew, Supernovas'
		);
	});

	it('campo null é omitido', () => {
		render(CardFields, { card: card({ power: null, block_icon: null }) });
		expect(labels()).not.toContain('Power');
		expect(labels()).not.toContain('Block');
	});
});

describe('CardFields — seção Efeito (SCAR-18)', () => {
	it('mostra effect_text como texto puro, sem interpretar HTML', () => {
		const { container } = render(CardFields, {
			card: card({ effect_text: '<script>alert(1)</script>\n[On Play] Draw 1.' })
		});
		expect(screen.getByRole('heading', { name: 'Efeito' })).toBeInTheDocument();
		expect(container.querySelector('script')).toBeNull();
		const p = container.querySelector('.effect-text') as HTMLElement;
		expect(p.textContent).toBe('<script>alert(1)</script>\n[On Play] Draw 1.');
	});

	it('preserva quebras de linha no texto, com white-space: pre-line', () => {
		const { container } = render(CardFields, { card: card({ effect_text: 'a\nb' }) });
		const p = container.querySelector('.effect-text') as HTMLElement;
		expect(p.textContent).toBe('a\nb');
		const source = readFileSync(resolve(process.cwd(), 'src/lib/components/CardFields.svelte'), 'utf8');
		const rule = source.match(/\.effect-text\s*\{([^}]*)\}/);
		expect(rule?.[1]).toMatch(/white-space:\s*pre-line/);
	});

	it('trigger depois do efeito, sob o rótulo Trigger em <strong>', () => {
		const { container } = render(CardFields, {
			card: card({ effect_text: 'Efeito.', trigger_text: 'Ative isto.' })
		});
		const strong = screen.getByText('Trigger');
		expect(strong.tagName).toBe('STRONG');
		const text = (container.querySelector('section') as HTMLElement).textContent ?? '';
		expect(text.indexOf('Efeito.')).toBeLessThan(text.indexOf('Trigger'));
		expect(text.indexOf('Trigger')).toBeLessThan(text.indexOf('Ative isto.'));
	});

	it('trigger sem efeito exibe a seção com Trigger', () => {
		render(CardFields, { card: card({ trigger_text: 'Ative isto.' }) });
		expect(screen.getByRole('heading', { name: 'Efeito' })).toBeInTheDocument();
		expect(screen.getByText('Trigger').tagName).toBe('STRONG');
		expect(screen.getByText('Ative isto.')).toBeInTheDocument();
	});

	it('sem efeito nem trigger, sem a seção', () => {
		render(CardFields, { card: card() });
		expect(screen.queryByRole('heading', { name: 'Efeito' })).toBeNull();
		expect(screen.queryByText('Trigger')).toBeNull();
	});

	it('texto vazio conta como ausente', () => {
		render(CardFields, { card: card({ effect_text: '', trigger_text: '' }) });
		expect(screen.queryByRole('heading', { name: 'Efeito' })).toBeNull();
	});
});
