import { describe, expect, it } from 'vitest';

import type { DeckEntryLine, DeckLine } from '../api/types';
import { groupEntries, groupLabel, missingSentence, statusLabel } from './labels';

const line = (card_type: string, card_number = 'X'): DeckEntryLine => ({
	card_number, name: 'N', card_type, cost: null, in_source: true, required: 1, owned: 1, missing: 0, quantity: 1,
});
const leader: DeckLine = { ...line('leader'), };

describe('statusLabel', () => {
	it('traduz os três status', () => {
		expect(['valid', 'incomplete', 'invalid'].map((s) => statusLabel(s as never))).toEqual([
			'válido', 'incompleto', 'inválido',
		]);
	});
});

describe('groupLabel', () => {
	it('traduz os tipos conhecidos e capitaliza os outros', () => {
		expect(['character', 'event', 'stage', 'don'].map(groupLabel)).toEqual([
			'Personagens', 'Eventos', 'Locais', 'Don',
		]);
	});
});

describe('groupEntries', () => {
	it('corta a cada troca de tipo sem reordenar', () => {
		const groups = groupEntries([line('character', 'A'), line('character', 'B'), line('event', 'C'), line('character', 'D')]);
		expect(groups.map((g) => [g.cardType, g.entries.map((e) => e.card_number)])).toEqual([
			['character', ['A', 'B']], ['event', ['C']], ['character', ['D']],
		]);
	});

	it('lista vazia não dá grupos', () => {
		expect(groupEntries([])).toEqual([]);
	});
});

describe('missingSentence', () => {
	it('dá a frase de cada caso', () => {
		expect(missingSentence({ leader: null, entries: [], missing_total: 0 })).toBe('Este deck ainda não tem cartas');
		expect(missingSentence({ leader, entries: [], missing_total: 0 })).toBe('Você tem todas as cartas deste deck');
		expect(missingSentence({ leader, entries: [], missing_total: 1 })).toBe('Falta 1 cópia para montar este deck');
		expect(missingSentence({ leader, entries: [line('event')], missing_total: 3 })).toBe('Faltam 3 cópias para montar este deck');
	});
});
