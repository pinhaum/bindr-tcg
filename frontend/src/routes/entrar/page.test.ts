import '@testing-library/jest-dom/vitest';
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/svelte';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiError, networkError } from '../../lib/api/errors';

const nav = vi.hoisted(() => ({ goto: vi.fn() }));
vi.mock('$app/navigation', () => nav);

const pageState = vi.hoisted(() => ({ url: new URL('http://localhost/app/entrar') }));
vi.mock('$app/state', () => ({ page: pageState }));

vi.mock('$app/paths', () => ({ resolve: (path: string) => `/app${path === '/' ? '/' : path}` }));

const signIn = vi.hoisted(() => vi.fn());
vi.mock('../../lib/session.svelte', () => ({
	signIn,
	session: { status: 'ready', user: null, error: null }
}));

import { session } from '../../lib/session.svelte';
import { load } from './+page';
import Page from './+page.svelte';

const fill = async (email: string, password: string) => {
	await fireEvent.input(screen.getByLabelText('E-mail'), { target: { value: email } });
	await fireEvent.input(screen.getByLabelText('Senha'), { target: { value: password } });
};
const submit = () => fireEvent.click(screen.getByRole('button', { name: 'Entrar' }));

describe('entrar/+page.svelte', () => {
	beforeEach(() => {
		signIn.mockReset();
		nav.goto.mockReset();
		pageState.url = new URL('http://localhost/app/entrar');
	});
	afterEach(cleanup);

	it('usa validação nativa e o autocomplete correto', () => {
		const { container } = render(Page);

		expect(screen.getByRole('heading', { level: 1, name: 'Entrar' })).toBeInTheDocument();
		expect(container.querySelector('form')).not.toHaveAttribute('novalidate');
		const email = screen.getByLabelText('E-mail');
		const password = screen.getByLabelText('Senha');
		expect(email).toBeRequired();
		expect(email).toHaveAttribute('type', 'email');
		expect(email).toHaveAttribute('autocomplete', 'email');
		expect(password).toBeRequired();
		expect(password).toHaveAttribute('type', 'password');
		expect(password).toHaveAttribute('autocomplete', 'current-password');
		expect(screen.getByRole('link', { name: 'Criar conta' })).toHaveAttribute('href', '/app/criar-conta');
	});

	it('envia os valores para signIn e vai para /app sem return_to', async () => {
		signIn.mockResolvedValue(undefined);
		render(Page);
		await fill('ana@example.com', 'segredo123');
		await submit();

		await waitFor(() => expect(nav.goto).toHaveBeenCalledWith('/app'));
		expect(signIn).toHaveBeenCalledWith('ana@example.com', 'segredo123');
	});

	it('vai para o return_to seguro', async () => {
		pageState.url = new URL('http://localhost/app/entrar?return_to=%2Fapp%2Fcatalogo%3Fq%3Dluffy');
		signIn.mockResolvedValue(undefined);
		render(Page);
		await fill('ana@example.com', 'segredo123');
		await submit();

		await waitFor(() => expect(nav.goto).toHaveBeenCalledWith('/app/catalogo?q=luffy'));
	});

	it('descarta return_to inseguro', async () => {
		pageState.url = new URL('http://localhost/app/entrar?return_to=%2F%2Fevil.com');
		signIn.mockResolvedValue(undefined);
		render(Page);
		await fill('ana@example.com', 'segredo123');
		await submit();

		await waitFor(() => expect(nav.goto).toHaveBeenCalledWith('/app'));
	});

	it('invalid_credentials mostra a mensagem, mantém o e-mail, limpa a senha e foca o erro', async () => {
		signIn.mockRejectedValue(new ApiError(401, 'invalid_credentials', 'E-mail ou senha inválidos.'));
		render(Page);
		await fill('ana@example.com', 'errada');
		await submit();

		const alert = await screen.findByRole('alert');
		expect(alert).toHaveTextContent('E-mail ou senha inválidos.');
		await waitFor(() => expect(alert).toHaveFocus());
		expect(screen.getByLabelText('E-mail')).toHaveValue('ana@example.com');
		expect(screen.getByLabelText('Senha')).toHaveValue('');
		expect(nav.goto).not.toHaveBeenCalled();
	});

	it('network_error mostra a mensagem exata no topo', async () => {
		signIn.mockRejectedValue(networkError());
		render(Page);
		await fill('ana@example.com', 'segredo123');
		await submit();

		expect(await screen.findByRole('alert')).toHaveTextContent(
			'Sem conexão com o servidor. Tente novamente.'
		);
		expect(screen.getByLabelText('Senha')).toHaveValue('segredo123');
	});

	it('envio pendente ignora o segundo envio e desabilita o botão', async () => {
		let resolveSignIn: () => void = () => {};
		signIn.mockReturnValue(new Promise<void>((resolve) => (resolveSignIn = resolve)));
		const { container } = render(Page);
		await fill('ana@example.com', 'segredo123');
		await submit();

		const button = screen.getByRole('button', { name: 'Entrar' });
		expect(button).toBeDisabled();
		await fireEvent.submit(container.querySelector('form')!);
		expect(signIn).toHaveBeenCalledTimes(1);

		resolveSignIn();
		await waitFor(() => expect(nav.goto).toHaveBeenCalledOnce());
	});
});

describe('entrar/+page load', () => {
	it('com sessão ativa lança redirect para /app', async () => {
		session.user = { email: 'ana@example.com' } as never;
		await expect(load({ parent: async () => ({}) } as never)).rejects.toMatchObject({
			status: 307,
			location: '/app'
		});
	});

	it('sem sessão não redireciona', async () => {
		session.user = null;
		await expect(load({ parent: async () => ({}) } as never)).resolves.toBeUndefined();
	});

	it('define o título da página', () => {
		render(Page);

		expect(document.title).toBe('Entrar — Bindr');
	});
});
