import { describe, expect, it, vi } from 'vitest';

vi.mock('$app/paths', () => ({ resolve: (path: string) => `/app${path}` }));

import { cardApiPath, cardDetailHref, variantApiPath } from './url';

describe('cardDetailHref', () => {
	it('sem variante leva só o card_number', () => {
		expect(cardDetailHref('P-029')).toBe('/app/cartas/P-029');
	});

	it('codifica a variante na query', () => {
		expect(cardDetailHref('OP01-001', 'tcgplayer:1')).toBe(
			'/app/cartas/OP01-001?variant=tcgplayer%3A1',
		);
	});

	it('codifica espaço e barra no card_number', () => {
		expect(cardDetailHref('A B/C')).toBe('/app/cartas/A%20B%2FC');
	});
});

describe('cardApiPath', () => {
	it('sem variante não leva query', () => {
		expect(cardApiPath('OP01-001')).toBe('/api/cards/OP01-001');
	});

	it('repassa a variante codificada', () => {
		expect(cardApiPath('OP01-001', 'tcgplayer:1')).toBe('/api/cards/OP01-001?variant=tcgplayer%3A1');
	});

	it('codifica o card_number', () => {
		expect(cardApiPath('A B/C')).toBe('/api/cards/A%20B%2FC');
	});
});

describe('variantApiPath', () => {
	it.each(['increment', 'decrement', 'wishlist'] as const)('monta a rota de %s', (action) => {
		expect(variantApiPath('OP01-001', 'tcgplayer:1', action)).toBe(
			`/api/cards/OP01-001/variants/tcgplayer%3A1/${action}`,
		);
	});

	it('codifica card_number e variant_code', () => {
		expect(variantApiPath('A B/C', 'x/y', 'increment')).toBe(
			'/api/cards/A%20B%2FC/variants/x%2Fy/increment',
		);
	});

	it('o caminho de wishlist serve ao PUT e à remoção, com card_number codificado', () => {
		expect(variantApiPath('OP01-001', 'tcgplayer:1', 'wishlist')).toBe(
			'/api/cards/OP01-001/variants/tcgplayer%3A1/wishlist',
		);
		expect(variantApiPath('A B/C', 'tcgplayer:1', 'wishlist')).toBe(
			'/api/cards/A%20B%2FC/variants/tcgplayer%3A1/wishlist',
		);
	});
});
