import '@testing-library/jest-dom/vitest';
import { cleanup, fireEvent, render, screen } from '@testing-library/svelte';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiError } from '../../../lib/api/errors';

vi.mock('$app/paths', () => ({ resolve: (path: string) => `/app${path === '/' ? '/' : path}` }));

const nav = vi.hoisted(() => ({ goto: vi.fn() }));
vi.mock('$app/navigation', () => nav);

const apiMock = vi.hoisted(() => ({ post: vi.fn() }));
vi.mock('../../../lib/api/index', () => ({ api: apiMock }));

const sessionState = vi.hoisted(() => ({
	status: 'ready',
	user: { email: 'ana@example.com' } as { email: string } | null,
	error: null
}));
vi.mock('../../../lib/session.svelte', () => ({ session: sessionState }));

const toast = vi.hoisted(() => ({ notifySuccess: vi.fn(), notifyError: vi.fn() }));
vi.mock('../../../lib/toasts.svelte', () => toast);

import { load } from './+page';
import Page from './+page.svelte';

const NAME = /Nome do deck \(opcional/;
const LIST = /Lista \(até 200 linhas/;

describe('baralhos/importar/+page.ts', () => {
	beforeEach(() => {
		sessionState.user = { email: 'ana@example.com' };
	});

	it('sem sessão redireciona para entrar com return_to (SDEC-03)', async () => {
		sessionState.user = null;
		const url = new URL('http://localhost/app/baralhos/importar');
		await expect(load({ parent: async () => ({}), url } as never)).rejects.toMatchObject({
			status: 307,
			location: '/app/entrar?return_to=%2Fapp%2Fbaralhos%2Fimportar'
		});
	});

	it('com sessão não redireciona', async () => {
		const url = new URL('http://localhost/app/baralhos/importar');
		await expect(load({ parent: async () => ({}), url } as never)).resolves.toBeUndefined();
	});
});

describe('baralhos/importar/+page.svelte', () => {
	beforeEach(() => {
		apiMock.post.mockReset();
		nav.goto.mockReset();
		toast.notifySuccess.mockReset();
		apiMock.post.mockResolvedValue({ id: 7, name: 'Red Zoro' });
	});
	afterEach(cleanup);

	async function fill(name: string, list: string) {
		await fireEvent.input(screen.getByLabelText(NAME), { target: { value: name } });
		await fireEvent.input(screen.getByLabelText(LIST), { target: { value: list } });
	}

	it('formulário com os textos e atributos exatos (SDEC-30)', () => {
		render(Page);

		expect(document.title).toBe('Importar lista — Bindr');
		expect(screen.getByRole('heading', { level: 1, name: 'Importar lista' })).toBeInTheDocument();
		expect(
			screen.getByText(
				'Cole a lista do OPTCG Simulator: uma carta por linha, como 4xOP01-016, com o Leader como 1x. A importação cria um deck novo e não altera nenhum deck que você já tem.'
			)
		).toBeInTheDocument();
		const name = screen.getByLabelText('Nome do deck (opcional; sem nome, o deck leva o nome do Leader)');
		expect(name).toHaveAttribute('maxlength', '60');
		expect(name).not.toBeRequired();
		expect(screen.getByLabelText('Lista (até 200 linhas e 10.000 caracteres)')).toBeRequired();
		expect(screen.getByRole('button', { name: 'Importar lista' })).toBeInTheDocument();
		expect(screen.getByRole('link', { name: 'Voltar aos baralhos' })).toHaveAttribute('href', '/app/baralhos');
	});

	it('envia { name, list }, navega ao deck e avisa "Deck importado." (SDEC-31)', async () => {
		render(Page);
		await fill('Red Zoro', '1x OP01-001\n4x OP01-016');
		await fireEvent.click(screen.getByRole('button', { name: 'Importar lista' }));

		await vi.waitFor(() => expect(toast.notifySuccess).toHaveBeenCalledWith('Deck importado.'));
		expect(apiMock.post).toHaveBeenCalledWith('/api/decks/import', {
			name: 'Red Zoro',
			list: '1x OP01-001\n4x OP01-016'
		});
		expect(nav.goto).toHaveBeenCalledWith('/app/baralhos/7');
	});

	it('recusa mostra resumo focado com as três linhas na ordem e liga a área (SDEC-32)', async () => {
		apiMock.post.mockRejectedValue(
			new ApiError(422, 'validation_failed', 'Lista não importada.', {
				list: ['Linha 2: carta desconhecida', 'Linha 3: quantidade inválida', 'Linha 5: formato inválido']
			})
		);
		render(Page);
		await fill('Meu deck', 'lixo');
		await fireEvent.click(screen.getByRole('button', { name: 'Importar lista' }));

		const alert = await screen.findByRole('alert');
		await vi.waitFor(() => expect(alert).toHaveFocus());
		expect(alert).toHaveTextContent('Lista não importada.');
		const items = screen.getAllByRole('listitem').map((li) => li.textContent);
		expect(items).toEqual(['Linha 2: carta desconhecida', 'Linha 3: quantidade inválida', 'Linha 5: formato inválido']);

		const list = screen.getByLabelText(LIST);
		expect(list).toHaveAttribute('aria-invalid', 'true');
		expect(list).toHaveAccessibleDescription(/Lista não importada\..*Linha 2.*Linha 3.*Linha 5/s);
		expect(list).toHaveValue('lixo');
		expect(screen.getByLabelText(NAME)).toHaveValue('Meu deck');
		expect(nav.goto).not.toHaveBeenCalled();
	});

	it('fields.name vai ao campo de nome e o foco segue para ele (SDEC-32)', async () => {
		apiMock.post.mockRejectedValue(
			new ApiError(422, 'validation_failed', 'Nome inválido.', { name: ['Nome é muito longo'] })
		);
		render(Page);
		await fill('x', 'lista');
		await fireEvent.click(screen.getByRole('button', { name: 'Importar lista' }));

		expect(await screen.findByText('Nome é muito longo')).toBeInTheDocument();
		await vi.waitFor(() => expect(screen.getByLabelText(NAME)).toHaveFocus());
		expect(screen.queryByRole('alert')).not.toBeInTheDocument();
		expect(screen.getByLabelText(LIST)).not.toHaveAttribute('aria-invalid');
	});

	it('envio repetido é ignorado enquanto pendente', async () => {
		let resolve!: (value: unknown) => void;
		apiMock.post.mockReturnValue(new Promise((r) => (resolve = r)));
		render(Page);
		await fill('', 'lista');
		const form = screen.getByRole('button', { name: 'Importar lista' }).closest('form')!;
		await fireEvent.submit(form);
		await fireEvent.submit(form);

		expect(apiMock.post).toHaveBeenCalledTimes(1);
		resolve({ id: 7 });
		await vi.waitFor(() => expect(toast.notifySuccess).toHaveBeenCalled());
	});
});
