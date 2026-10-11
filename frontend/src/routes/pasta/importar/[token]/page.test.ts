import '@testing-library/jest-dom/vitest';
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/svelte';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiError, networkError } from '../../../../lib/api/errors';
import type { ImportPreview, ImportRow, ImportSummary } from '../../../../lib/api/types';

vi.mock('$app/paths', () => ({ resolve: (path: string) => `/app${path === '/' ? '/' : path}` }));
vi.mock('$app/state', () => ({
	page: { params: { token: 'abc' }, url: new URL('http://localhost/app/pasta/importar/abc') }
}));

const get = vi.hoisted(() => vi.fn());
const post = vi.hoisted(() => vi.fn());
vi.mock('../../../../lib/api/index', () => ({ api: { get, post } }));

const sessionState = vi.hoisted(() => ({
	status: 'ready',
	user: { email: 'ana@example.com' } as { email: string } | null,
	error: null
}));
vi.mock('../../../../lib/session.svelte', () => ({ session: sessionState }));

import { load } from './+page';
import Page from './+page.svelte';

const row = (line: number, classification: ImportRow['classification'], name = 'Luffy'): ImportRow => ({
	line,
	classification,
	card_number: 'OP01-001',
	variant_code: `tcgplayer:${line}`,
	card_name: name,
	quantity_before: 1,
	quantity_after: classification === 'removes' ? 0 : 2,
	message: classification === 'rejected' ? 'Quantidade inválida.' : null
});

const preview = (rows: ImportRow[]): ImportPreview => ({ token: 'abc', filename: 'colecao.csv', rows });

const summary: ImportSummary = {
	filename: 'colecao.csv',
	created: 1,
	updated: 3,
	removed: 1,
	unchanged: 0,
	rejected: [],
	failures: []
};

describe('pasta/importar/[token]/+page.svelte', () => {
	beforeEach(() => {
		get.mockReset();
		post.mockReset();
		sessionState.user = { email: 'ana@example.com' };
	});
	afterEach(() => {
		cleanup();
		vi.useRealTimers();
	});

	it('sessão anônima redireciona com return_to sem chamar a API', async () => {
		sessionState.user = null;
		const url = new URL('http://localhost/app/pasta/importar/abc');
		await expect(load({ parent: async () => ({}), url } as never)).rejects.toMatchObject({
			status: 307,
			location: '/app/entrar?return_to=%2Fapp%2Fpasta%2Fimportar%2Fabc'
		});
		expect(get).not.toHaveBeenCalled();
	});

	it('consulta o token e mostra título, h1, arquivo e linhas analisadas', async () => {
		get.mockResolvedValue(preview([row(2, 'creates'), row(3, 'updates')]));
		render(Page);

		expect(await screen.findByText(/Arquivo: colecao.csv — 2 linhas analisadas\./)).toBeInTheDocument();
		expect(get).toHaveBeenCalledWith('/api/collection/imports/abc');
		expect(document.title).toBe('Pré-visualização da importação — Bindr');
		expect(screen.getByRole('heading', { level: 1, name: 'Confira o que vai mudar' })).toBeInTheDocument();
		expect(screen.getByText(/Nada foi gravado na sua coleção ainda/)).toBeInTheDocument();
	});

	it('agrupa na ordem fixa, omite grupo vazio e só avisa de remoção com removes', async () => {
		get.mockResolvedValue(
			preview([row(2, 'unchanged'), row(3, 'creates'), row(4, 'removes'), row(5, 'removes')])
		);
		render(Page);

		const headings = (await screen.findAllByRole('heading', { level: 2 })).map((h) => h.textContent);
		expect(headings).toEqual(['Remove da coleção (2)', 'Passa a constar (1)', 'Já está assim (1)']);
		expect(
			screen.getByText('Atenção: 2 cartas que você possui hoje saem da sua coleção se você confirmar.')
		).toBeInTheDocument();
	});

	it('sem removes não mostra o aviso; só cabeçalho mostra 0 linhas e o botão', async () => {
		get.mockResolvedValue(preview([]));
		render(Page);

		expect(await screen.findByText(/0 linhas analisadas\./)).toBeInTheDocument();
		expect(screen.queryAllByRole('heading', { level: 2 })).toHaveLength(0);
		expect(screen.queryByText(/Atenção:/)).not.toBeInTheDocument();
		expect(screen.getByRole('button', { name: 'Confirmar e gravar na minha coleção' })).toBeInTheDocument();
		expect(screen.getByRole('link', { name: 'envie outro arquivo' })).toHaveAttribute(
			'href',
			'/app/pasta/importar'
		);
	});

	it('mostra o nome da carta como texto, sem executar script', async () => {
		get.mockResolvedValue(preview([row(2, 'creates', '<script>alert(1)</script>')]));
		const { container } = render(Page);

		expect(await screen.findByText('<script>alert(1)</script>')).toBeInTheDocument();
		expect(container.querySelector('script')).toBeNull();
	});

	it('marca aria-busy e o texto de carga após 200 ms', async () => {
		vi.useFakeTimers();
		get.mockReturnValue(new Promise(() => {}));
		render(Page);
		await vi.advanceTimersByTimeAsync(250);

		expect(screen.getByText('Carregando pré-visualização…').closest('section')).toHaveAttribute(
			'aria-busy',
			'true'
		);
	});

	it('404 mostra a mensagem e "Enviar um arquivo", sem "Tentar novamente"', async () => {
		get.mockRejectedValue(new ApiError(404, 'not_found', 'Importação não encontrada.'));
		render(Page);

		expect(await screen.findByText('Importação não encontrada.')).toBeInTheDocument();
		expect(screen.getByRole('link', { name: 'Enviar um arquivo' })).toHaveAttribute(
			'href',
			'/app/pasta/importar'
		);
		expect(screen.queryByRole('button', { name: 'Tentar novamente' })).not.toBeInTheDocument();
	});

	it('500 mostra "Tentar novamente", que repete o GET', async () => {
		get.mockRejectedValueOnce(new ApiError(500, 'internal_error', 'Algo deu errado.'));
		get.mockResolvedValueOnce(preview([]));
		render(Page);

		await fireEvent.click(await screen.findByRole('button', { name: 'Tentar novamente' }));

		expect(await screen.findByText(/0 linhas analisadas\./)).toBeInTheDocument();
		expect(get).toHaveBeenCalledTimes(2);
	});

	it('confirma uma vez em duplo clique e troca pelo resumo com foco no h1', async () => {
		get.mockResolvedValue(preview([row(2, 'creates')]));
		let finish!: (value: ImportSummary) => void;
		post.mockReturnValue(new Promise<ImportSummary>((resolve) => (finish = resolve)));
		render(Page);

		const form = (await screen.findByRole('button', { name: 'Confirmar e gravar na minha coleção' })).closest(
			'form'
		)!;
		await fireEvent.submit(form);
		await fireEvent.submit(form);
		finish(summary);

		const heading = await screen.findByRole('heading', { level: 1, name: 'Importação concluída' });
		expect(post).toHaveBeenCalledTimes(1);
		expect(post).toHaveBeenCalledWith('/api/collection/imports/abc/confirm', undefined, {
			timeoutMs: 60000
		});
		await waitFor(() => expect(heading).toHaveFocus());
		expect(document.title).toBe('Importação concluída — Bindr');
	});

	it('409 import_closed mantém a pré-visualização e mostra a mensagem como alerta', async () => {
		get.mockResolvedValue(preview([row(2, 'creates')]));
		post.mockRejectedValue(
			new ApiError(409, 'import_closed', 'Esta importação já foi confirmada ou expirou.')
		);
		render(Page);

		await fireEvent.click(await screen.findByRole('button', { name: 'Confirmar e gravar na minha coleção' }));

		expect(await screen.findByRole('alert')).toHaveTextContent(
			'Esta importação já foi confirmada ou expirou.'
		);
		expect(screen.getByRole('heading', { level: 1, name: 'Confira o que vai mudar' })).toBeInTheDocument();
		expect(screen.getByRole('button', { name: 'Confirmar e gravar na minha coleção' })).toBeEnabled();
	});

	it('network_error na confirmação mostra a frase de resultado desconhecido, sem reenviar', async () => {
		get.mockResolvedValue(preview([row(2, 'creates')]));
		post.mockRejectedValue(networkError());
		render(Page);

		await fireEvent.click(await screen.findByRole('button', { name: 'Confirmar e gravar na minha coleção' }));

		expect(
			await screen.findByText(
				'Não foi possível saber se a importação foi gravada. Confira a sua pasta antes de enviar o arquivo de novo.'
			)
		).toBeInTheDocument();
		expect(screen.getByRole('link', { name: 'Ver minha coleção' })).toHaveAttribute('href', '/app/pasta');
		expect(screen.queryByRole('button', { name: 'Confirmar e gravar na minha coleção' })).not.toBeInTheDocument();
		expect(post).toHaveBeenCalledTimes(1);
	});
});
