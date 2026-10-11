import '@testing-library/jest-dom/vitest';
import { cleanup, render, screen } from '@testing-library/svelte';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { ImportSummary as Summary } from '../api/types';

vi.mock('$app/paths', () => ({ resolve: () => '/app/' }));

import ImportSummary from './ImportSummary.svelte';

afterEach(cleanup);

const summary = (over: Partial<Summary> = {}): Summary => ({
	filename: 'colecao.csv',
	created: 0,
	updated: 0,
	removed: 0,
	unchanged: 0,
	rejected: [],
	failures: [],
	...over
});

const stat = (label: string) => screen.getByText(label).parentElement as HTMLElement;

describe('ImportSummary', () => {
	it('mostra título, arquivo e as três contagens em ordem, inclusive com zero', () => {
		const { container } = render(ImportSummary, { summary: summary() });
		expect(screen.getByRole('heading', { level: 1, name: 'Importação concluída' })).toBeInTheDocument();
		expect(screen.getByText('Arquivo: colecao.csv — sua coleção foi atualizada.')).toBeInTheDocument();
		const labels = ['Importadas', 'Atualizadas', 'Recusadas'];
		const found = [...container.querySelectorAll('.label')].map((el) => el.textContent);
		expect(found).toEqual(labels);
		for (const label of labels) {
			expect(stat(label).querySelector('.value')).toHaveTextContent('0');
		}
		expect(
			screen.getByText('Variantes que não estavam na sua coleção e passaram a estar.')
		).toBeInTheDocument();
		expect(
			screen.getByText('Variantes que já estavam na sua coleção e tiveram a quantidade substituída.')
		).toBeInTheDocument();
		expect(screen.getByText('Linhas do arquivo que não foram aplicadas.')).toBeInTheDocument();
	});

	it('atualizadas inclui removidas e a frase de remoção aparece com 1', () => {
		render(ImportSummary, { summary: summary({ created: 2, updated: 3, removed: 1 }) });
		expect(stat('Atualizadas').querySelector('.value')).toHaveTextContent('3');
		expect(stat('Importadas').querySelector('.value')).toHaveTextContent('2');
		expect(
			screen.getByText(
				'1 dessas atualizações removeu a carta da sua coleção: o arquivo trazia zero para uma variante que você possuía.'
			)
		).toBeInTheDocument();
	});

	it('frase de inalteradas só quando há', () => {
		const { unmount } = render(ImportSummary, { summary: summary() });
		expect(screen.queryByText(/já estavam assim/)).not.toBeInTheDocument();
		unmount();
		render(ImportSummary, { summary: summary({ unchanged: 4 }) });
		expect(
			screen.getByText('4 linhas do arquivo já estavam assim na sua coleção: nada mudou nelas.')
		).toBeInTheDocument();
	});

	it('lista recusas e falhas em blocos separados', () => {
		render(ImportSummary, {
			summary: summary({
				rejected: [
					{
						line: 7,
						card_number: 'OP01-001',
						variant_code: 'tcgplayer:1',
						card_name: 'Zoro',
						message: 'Quantidade inválida.'
					}
				],
				failures: [{ line: 9, card_number: 'OP01-002', variant_code: 'tcgplayer:2' }]
			})
		});
		expect(
			screen.getByText(
				'Confira estas linhas: 1 linha do arquivo não foi aplicada. Sua coleção não foi alterada por ela.'
			)
		).toBeInTheDocument();
		const rejected = screen.getByText('Linha 7 do arquivo').closest('li') as HTMLElement;
		expect(rejected).toHaveTextContent('OP01-001');
		expect(rejected).toHaveTextContent('tcgplayer:1');
		expect(rejected).toHaveTextContent('Zoro');
		expect(rejected).toHaveTextContent('Quantidade inválida.');
		expect(screen.getByText(/^Atenção: 1 linha não pôde ser gravada/)).toBeInTheDocument();
		expect(screen.getByText('Linha 9 do arquivo — OP01-002 tcgplayer:2')).toBeInTheDocument();
	});

	it('sem recusa nem falha o texto não tem vocabulário de erro', () => {
		const { container } = render(ImportSummary, {
			summary: summary({ created: 1, updated: 2, removed: 1, unchanged: 3 })
		});
		expect(container.textContent).not.toMatch(/rejeitada|falha|erro/i);
	});

	it('links finais usam navegação do app, sem recarga', () => {
		render(ImportSummary, { summary: summary() });
		const collection = screen.getByRole('link', { name: 'Ver minha coleção' });
		const another = screen.getByRole('link', { name: 'importar outro arquivo' });
		expect(collection).toHaveAttribute('href', '/app/pasta');
		expect(another).toHaveAttribute('href', '/app/pasta/importar');
		expect(collection).not.toHaveAttribute('data-sveltekit-reload');
		expect(another).not.toHaveAttribute('data-sveltekit-reload');
	});

	it('focus() põe o foco no h1', () => {
		const { component } = render(ImportSummary, { summary: summary() });
		component.focus();
		expect(screen.getByRole('heading', { level: 1 })).toHaveFocus();
	});
});
