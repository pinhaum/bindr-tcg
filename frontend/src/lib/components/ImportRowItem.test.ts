import '@testing-library/jest-dom/vitest';
import { cleanup, render, screen } from '@testing-library/svelte';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { afterEach, describe, expect, it } from 'vitest';
import type { ImportRow } from '../api/types';
import ImportRowItem from './ImportRowItem.svelte';

const row = (over: Partial<ImportRow> = {}): ImportRow => ({
	line: 7,
	classification: 'updates',
	card_number: 'OP01-001',
	variant_code: 'tcgplayer:1',
	card_name: 'Luffy',
	quantity_before: 2,
	quantity_after: 5,
	message: null,
	...over
});

afterEach(cleanup);

describe('ImportRowItem', () => {
	it.each([
		['removes', 'Remove da coleção'],
		['creates', 'Cria'],
		['updates', 'Altera'],
		['rejected', 'Recusada'],
		['unchanged', 'Sem alteração']
	] as const)('mostra o rótulo escrito de %s (SPOR-14)', (classification, label) => {
		render(ImportRowItem, { row: row({ classification }) });
		expect(screen.getByText(label)).toBeInTheDocument();
	});

	it('mostra identidade, linha do arquivo e variant_code em code (SPOR-14)', () => {
		render(ImportRowItem, { row: row() });
		expect(screen.getByText('OP01-001')).toBeInTheDocument();
		expect(screen.getByText('Luffy')).toBeInTheDocument();
		expect(screen.getByText('Linha 7 do arquivo')).toBeInTheDocument();
		expect(screen.getByText('tcgplayer:1').tagName).toBe('CODE');
	});

	it('mostra — no lugar de card_number e variant_code ausentes (SPOR-14)', () => {
		render(ImportRowItem, {
			row: row({ classification: 'rejected', card_number: null, variant_code: null, message: 'x' })
		});
		expect(screen.getAllByText('—')).toHaveLength(2);
	});

	it('mostra antes e depois em elementos próprios (SPOR-15)', () => {
		const { container } = render(ImportRowItem, { row: row() });
		expect(container).toHaveTextContent('De quantidade atual 2 para nova quantidade 5.');
		expect(screen.getByText('2').tagName).toBe('STRONG');
		expect(screen.getByText('5').tagName).toBe('STRONG');
	});

	it('creates não mostra o antes (SPOR-15)', () => {
		const { container } = render(ImportRowItem, {
			row: row({ classification: 'creates', quantity_before: null, quantity_after: 3 })
		});
		expect(container).toHaveTextContent(
			'Você não tem esta variante registrada; passará a ter nova quantidade 3.'
		);
		expect(container).not.toHaveTextContent('De quantidade atual');
	});

	it('recusada mostra a message e nenhuma frase de quantidade (SPOR-15)', () => {
		const { container } = render(ImportRowItem, {
			row: row({
				classification: 'rejected',
				quantity_before: null,
				quantity_after: null,
				message: 'Quantidade inválida.'
			})
		});
		expect(screen.getByText('Quantidade inválida.')).toBeInTheDocument();
		expect(container).not.toHaveTextContent('nova quantidade');
	});

	it('exibe HTML do nome como texto (SPOR-17)', () => {
		const { container } = render(ImportRowItem, {
			row: row({ card_name: '<script>alert(1)</script>' })
		});
		expect(screen.getByText('<script>alert(1)</script>')).toBeInTheDocument();
		expect(container.querySelector('script')).toBeNull();
	});

	it('quebra nome e código longos e não depende só de cor (SPOR-16)', () => {
		const css = readFileSync(resolve(__dirname, 'ImportRowItem.svelte'), 'utf8');
		expect(css).toMatch(/overflow-wrap:\s*anywhere/);
		expect(css).toMatch(/border-inline-start-style/);
	});
});
