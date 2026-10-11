import { describe, expect, it } from 'vitest';
import { copies, formatObservedDate, formatPrice } from './format';

describe('formatPrice', () => {
	it('escreve milhar em ponto e centavos em vírgula, com espaço comum', () => {
		expect(formatPrice('1234.56', 'USD')).toBe('US$ 1.234,56');
	});

	it('completa a segunda casa decimal', () => {
		expect(formatPrice('1.7', 'USD')).toBe('US$ 1,70');
		expect(formatPrice('0.5', 'USD')).toBe('US$ 0,50');
	});

	it('zero é US$ 0,00', () => {
		expect(formatPrice('0', 'USD')).toBe('US$ 0,00');
	});

	it('usa o código ISO quando a moeda não tem unidade conhecida', () => {
		expect(formatPrice('12', 'BRL')).toBe('BRL 12,00');
		expect(formatPrice('1234.56', 'EUR')).toBe('EUR 1.234,56');
	});
});

describe('formatObservedDate', () => {
	it('mostra a data no horário de Brasília', () => {
		expect(formatObservedDate('2026-10-05T02:00:00Z')).toBe('04/10/2026');
		expect(formatObservedDate('2026-10-06T01:30:00Z')).toBe('05/10/2026');
	});
});

describe('copies', () => {
	it('singular para 1 e plural para os demais', () => {
		expect(copies(1)).toBe('1 cópia');
		expect(copies(2)).toBe('2 cópias');
		expect(copies(12)).toBe('12 cópias');
	});
});
