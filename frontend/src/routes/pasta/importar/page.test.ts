import '@testing-library/jest-dom/vitest';
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/svelte';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiError, networkError } from '../../../lib/api/errors';

const nav = vi.hoisted(() => ({ goto: vi.fn() }));
vi.mock('$app/navigation', () => nav);
vi.mock('$app/paths', () => ({ resolve: (path: string) => path }));

const post = vi.hoisted(() => vi.fn());
vi.mock('../../../lib/api/index', () => ({ api: { post } }));

vi.mock('../../../lib/session.svelte', () => ({
	session: { status: 'ready', user: { email: 'ana@example.com' }, error: null }
}));

import { session } from '../../../lib/session.svelte';
import { load } from './+page';
import Page from './+page.svelte';

const csv = () => new File(['a,b'], 'colecao.csv', { type: 'text/csv' });
const pick = (file = csv()) => fireEvent.change(screen.getByLabelText('Arquivo CSV'), { target: { files: [file] } });
const submit = () => fireEvent.submit(screen.getByLabelText('Arquivo CSV').closest('form')!);
const refusal = (fields: Record<string, string[]>) =>
	new ApiError(422, 'validation_failed', 'O arquivo não foi importado. Sua coleção não foi alterada.', fields);

describe('pasta/importar/+page.svelte', () => {
	beforeEach(() => {
		post.mockReset();
		nav.goto.mockReset();
	});
	afterEach(cleanup);

	it('mostra título, texto, campo obrigatório e botão', () => {
		render(Page);

		expect(document.title).toBe('Importar coleção — Bindr');
		expect(screen.getByRole('heading', { level: 1, name: 'Importar coleção' })).toBeInTheDocument();
		expect(
			screen.getByText(
				'Envie o arquivo CSV exportado da sua coleção. Você verá o que vai mudar antes de qualquer alteração ser gravada.'
			)
		).toBeInTheDocument();
		const input = screen.getByLabelText('Arquivo CSV');
		expect(input).toBeRequired();
		expect(input).toHaveAttribute('type', 'file');
		expect(input).toHaveAttribute('accept', 'text/csv,.csv');
		expect(input).toHaveAttribute('name', 'file');
		expect(screen.getByRole('button', { name: 'Pré-visualizar importação' })).toBeInTheDocument();
	});

	it('o load redireciona a sessão anônima sem chamar a API', async () => {
		const original = session.user;
		(session as { user: unknown }).user = null;
		try {
			await expect(
				load({ parent: async () => ({}), url: new URL('http://localhost/pasta/importar') } as never)
			).rejects.toMatchObject({ status: 307, location: '/entrar?return_to=%2Fpasta%2Fimportar' });
		} finally {
			(session as { user: unknown }).user = original;
		}
		expect(post).not.toHaveBeenCalled();
	});

	it('envia o arquivo uma vez em duplo clique, com o botão pendente', async () => {
		let resolvePost!: (value: unknown) => void;
		post.mockReturnValue(new Promise((resolve) => (resolvePost = resolve)));
		render(Page);
		const file = csv();
		await pick(file);

		await submit();
		await submit();

		expect(post).toHaveBeenCalledTimes(1);
		const [path, body, options] = post.mock.calls[0];
		expect(path).toBe('/api/collection/imports');
		expect(body).toBeInstanceOf(FormData);
		expect((body as FormData).get('file')).toBe(file);
		expect(options).toEqual({ timeoutMs: 60000 });
		expect(screen.getByRole('button', { name: 'Pré-visualizar importação' })).toBeDisabled();
		resolvePost({ token: 'x' });
	});

	it('vai para a pré-visualização com o token codificado', async () => {
		post.mockResolvedValue({ token: 'a/b', filename: 'colecao.csv', rows: [] });
		render(Page);
		await pick();
		await submit();

		await waitFor(() => expect(nav.goto).toHaveBeenCalledWith('/pasta/importar/a%2Fb'));
	});

	it('no 422 mostra a mensagem e as frases do arquivo no alerta focado e liga o campo', async () => {
		post.mockRejectedValue(refusal({ file: ['Primeira frase.', 'Segunda frase.'] }));
		render(Page);
		await pick();
		await submit();

		const alert = await screen.findByRole('alert');
		expect(alert.textContent).toMatch(
			/O arquivo não foi importado\. Sua coleção não foi alterada\.\s*Primeira frase\.\s*Segunda frase\./
		);
		await waitFor(() => expect(alert).toHaveFocus());
		const input = screen.getByLabelText('Arquivo CSV');
		expect(input).toHaveAttribute('aria-invalid', 'true');
		const describedBy = input.getAttribute('aria-describedby');
		expect(describedBy).toBeTruthy();
		expect(document.getElementById(describedBy!)).toContainElement(alert);
		expect(nav.goto).not.toHaveBeenCalled();
		expect(screen.getByRole('button', { name: 'Pré-visualizar importação' })).toBeEnabled();
	});

	it('em erro de rede mostra a mensagem como veio, sem marcar o campo', async () => {
		const error = networkError();
		post.mockRejectedValue(error);
		render(Page);
		await pick();
		await submit();

		expect((await screen.findByRole('alert')).textContent).toContain(error.message);
		expect(screen.getByLabelText('Arquivo CSV')).not.toHaveAttribute('aria-invalid');
	});

	it('401 não mostra erro local', async () => {
		post.mockRejectedValue(new ApiError(401, 'unauthenticated', 'Entre para continuar.', {}));
		render(Page);
		await pick();
		await submit();

		await waitFor(() => expect(screen.getByRole('button', { name: 'Pré-visualizar importação' })).toBeEnabled());
		expect(screen.queryByRole('alert')).not.toBeInTheDocument();
	});

	it('anuncia o envio em andamento numa região status', async () => {
		post.mockReturnValue(new Promise(() => {}));
		render(Page);
		await pick();
		await submit();

		await waitFor(() => expect(screen.getByRole('status')).toHaveTextContent('Enviando o arquivo…'));
	});
});
