import { describe, expect, it, vi } from 'vitest';

vi.mock('$app/paths', () => ({ resolve: (path: string) => `/app${path}` }));

import type { DeckEntryResult, DeckPayload, DeckSummary, EditingDeck, ShortfallCard } from '../api/types';
import { deckApiPath, deckCardApiPath, deckHref } from './url';

describe('deckHref', () => {
	it('sem sub leva só o id', () => {
		expect(deckHref(7)).toBe('/app/baralhos/7');
	});

	it('com sub acrescenta o segmento', () => {
		expect(deckHref(7, 'renomear')).toBe('/app/baralhos/7/renomear');
	});
});

describe('deckApiPath', () => {
	it('sem sub leva só o id', () => {
		expect(deckApiPath(7)).toBe('/api/decks/7');
	});

	it('com sub acrescenta o segmento', () => {
		expect(deckApiPath(7, 'leader')).toBe('/api/decks/7/leader');
	});
});

describe('deckCardApiPath', () => {
	it('monta a rota de incremento', () => {
		expect(deckCardApiPath(7, 'P-117', 'increment')).toBe('/api/decks/7/cards/P-117/increment');
	});

	it('codifica espaço e ponto no card_number', () => {
		expect(deckCardApiPath(7, 'A B.C', 'decrement')).toBe(
			`/api/decks/7/cards/${encodeURIComponent('A B.C')}/decrement`,
		);
	});
});

describe('tipos de deck', () => {
	it('descrevem os contratos da API', () => {
		const line = { card_number: 'OP01-001', name: 'Zoro', card_type: 'leader', cost: null, in_source: true, required: 1, owned: 1, missing: 0 };
		const deck: DeckPayload = {
			id: 7, name: 'Deck', editing: false, status: 'incomplete', reasons: [], warnings: [],
			main_total: 0, missing_total: 0, leader: line, entries: [{ ...line, quantity: 4 }],
		};
		const summary: DeckSummary = { id: 7, name: 'Deck', leader: null, main_total: 0, status: 'valid' };
		const shortfall: ShortfallCard = { card_number: 'P-117', name: 'X', missing: 2, decks: [{ id: 7, name: 'Deck' }] };
		const result: DeckEntryResult = { card_number: 'P-117', quantity: 1 };
		const editing: EditingDeck = { id: 7, name: 'Deck', quantity: 1, is_leader: false };
		expect([deck.id, summary.id, shortfall.missing, result.quantity, editing.id]).toEqual([7, 7, 2, 1, 7]);
	});
});
