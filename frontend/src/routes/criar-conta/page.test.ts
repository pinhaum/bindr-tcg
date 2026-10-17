import '@testing-library/jest-dom/vitest';
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/svelte';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiError, networkError } from '../../lib/api/errors';

const nav = vi.hoisted(() => ({ goto: vi.fn() }));
vi.mock('$app/navigation', () => nav);

const pageState = vi.hoisted(() => ({ url: new URL('http://localhost/criar-conta') }));
vi.mock('$app/state', () => ({ page: pageState }));

vi.mock('$app/paths', () => ({ resolve: (path: string) => path }));

const signUp = vi.hoisted(() => vi.fn());
vi.mock('../../lib/session.svelte', () => ({
	signUp,
	session: { status: 'ready', user: null, error: null }
}));

import { session } from '../../lib/session.svelte';
import { load } from './+page';
import Page from './+page.svelte';

const fill = async (email = 'ana@example.com', password = 'segredo123', confirmation = 'segredo123') => {
	await fireEvent.input(screen.getByLabelText('E-mail'), { target: { value: email } });
	await fireEvent.input(screen.getByLabelText('Senha'), { target: { value: password } });
	await fireEvent.input(screen.getByLabelText('Confirmação da senha'), { target: { value: confirmation } });
};
const submit = () => fireEvent.click(screen.getByRole('button', { name: 'Criar conta' }));
const validationFailed = (fields: Record<string, string[]>) =>
	new ApiError(422, 'validation_failed', 'Dados inválidos.', fields);

describe('criar-conta/+page.svelte', () => {
	beforeEach(() => {
		signUp.mockReset();
		nav.goto.mockReset();
		pageState.url = new URL('http://localhost/criar-conta');
	});
	afterEach(cleanup);

	it('usa validação nativa e o autocomplete correto', () => {
		const { container } = render(Page);

		expect(screen.getByRole('heading', { level: 1, name: 'Criar conta' })).toBeInTheDocument();
		expect(container.querySelector('form')).not.toHaveAttribute('novalidate');
		const email = screen.getByLabelText('E-mail');
		const password = screen.getByLabelText('Senha');
		const confirmation = screen.getByLabelText('Confirmação da senha');
		for (const field of [email, password, confirmation]) expect(field).toBeRequired();
		expect(email).toHaveAttribute('autocomplete', 'email');
		expect(password).toHaveAttribute('autocomplete', 'new-password');
		expect(confirmation).toHaveAttribute('autocomplete', 'new-password');
		expect(confirmation).toHaveAttribute('name', 'password_confirmation');
	});

	it('envia os três campos para signUp e vai para /', async () => {
		signUp.mockResolvedValue(undefined);
		render(Page);
		await fill();
		await submit();

		await waitFor(() => expect(nav.goto).toHaveBeenCalledWith('/'));
		expect(signUp).toHaveBeenCalledWith({
			email: 'ana@example.com',
			password: 'segredo123',
			password_confirmation: 'segredo123'
		});
	});

	it('preserva o return_to seguro após o cadastro', async () => {
		pageState.url = new URL('http://localhost/criar-conta?return_to=%2Fx');
		signUp.mockResolvedValue(undefined);
		render(Page);
		await fill();
		await submit();

		await waitFor(() => expect(nav.goto).toHaveBeenCalledWith('/x'));
	});

	it('com return_to de rota de arquivo navega a página inteira, sem goto', async () => {
		const assign = vi.fn();
		vi.stubGlobal('location', { assign });
		pageState.url = new URL('http://localhost/criar-conta?return_to=%2Fdecks%2F5.txt');
		signUp.mockResolvedValue(undefined);
		render(Page);
		await fill();
		await submit();

		await waitFor(() => expect(assign).toHaveBeenCalledWith('/decks/5.txt'));
		expect(nav.goto).not.toHaveBeenCalled();
		vi.unstubAllGlobals();
	});

	it('com return_to /pasta navega pelo goto, sem assign', async () => {
		const assign = vi.fn();
		vi.stubGlobal('location', { assign });
		pageState.url = new URL('http://localhost/criar-conta?return_to=%2Fpasta');
		signUp.mockResolvedValue(undefined);
		render(Page);
		await fill();
		await submit();

		await waitFor(() => expect(nav.goto).toHaveBeenCalledWith('/pasta'));
		expect(assign).not.toHaveBeenCalled();
		vi.unstubAllGlobals();
	});

	it('descarta return_to inseguro', async () => {
		pageState.url = new URL('http://localhost/criar-conta?return_to=%2F%2Fevil.com');
		signUp.mockResolvedValue(undefined);
		render(Page);
		await fill();
		await submit();

		await waitFor(() => expect(nav.goto).toHaveBeenCalledWith('/'));
	});

	it('erro em password e password_confirmation aparece junto dos campos e foca password', async () => {
		signUp.mockRejectedValue(
			validationFailed({
				password_confirmation: ['não é igual a Senha'],
				password: ['é muito curto (mínimo: 8 caracteres)']
			})
		);
		render(Page);
		await fill('ana@example.com', 'curta', 'outra');
		await submit();

		const password = screen.getByLabelText('Senha');
		const confirmation = screen.getByLabelText('Confirmação da senha');
		await waitFor(() => expect(password).toHaveFocus());
		expect(password).toHaveAttribute('aria-invalid', 'true');
		expect(confirmation).toHaveAttribute('aria-invalid', 'true');
		expect(password).toHaveAccessibleDescription('é muito curto (mínimo: 8 caracteres)');
		expect(confirmation).toHaveAccessibleDescription('não é igual a Senha');
		expect(screen.getByLabelText('E-mail')).not.toHaveAttribute('aria-invalid');
		expect(screen.queryByRole('alert')).not.toBeInTheDocument();
		expect(screen.queryByText('Dados inválidos.')).not.toBeInTheDocument();
		expect(nav.goto).not.toHaveBeenCalled();
	});

	it('erro só em email foca email', async () => {
		signUp.mockRejectedValue(validationFailed({ email: ['já está em uso'] }));
		render(Page);
		await fill();
		await submit();

		const email = screen.getByLabelText('E-mail');
		await waitFor(() => expect(email).toHaveFocus());
		expect(email).toHaveAccessibleDescription('já está em uso');
	});

	it('atributo desconhecido aparece no topo sem descartar e junto dos campos conhecidos', async () => {
		signUp.mockRejectedValue(
			validationFailed({ base: ['Cadastro indisponível.'], email: ['já está em uso'] })
		);
		render(Page);
		await fill();
		await submit();

		const alert = await screen.findByRole('alert');
		expect(alert).toHaveTextContent('Cadastro indisponível.');
		expect(alert).not.toHaveTextContent('Dados inválidos.');
		await waitFor(() => expect(screen.getByLabelText('E-mail')).toHaveFocus());
		expect(screen.getByLabelText('E-mail')).toHaveAccessibleDescription('já está em uso');
	});

	it('só atributo desconhecido: mostra no topo e foca o erro', async () => {
		signUp.mockRejectedValue(validationFailed({ role: ['é inválido'] }));
		render(Page);
		await fill();
		await submit();

		const alert = await screen.findByRole('alert');
		expect(alert).toHaveTextContent('role: é inválido');
		await waitFor(() => expect(alert).toHaveFocus());
	});

	it('validation_failed sem fields mostra a mensagem do envelope', async () => {
		signUp.mockRejectedValue(validationFailed({}));
		render(Page);
		await fill();
		await submit();

		expect(await screen.findByRole('alert')).toHaveTextContent('Dados inválidos.');
	});

	it('network_error mostra a mensagem exata no topo e foca o erro', async () => {
		signUp.mockRejectedValue(networkError());
		render(Page);
		await fill();
		await submit();

		const alert = await screen.findByRole('alert');
		expect(alert).toHaveTextContent('Sem conexão com o servidor. Tente novamente.');
		await waitFor(() => expect(alert).toHaveFocus());
		expect(screen.getByLabelText('Senha')).toHaveValue('segredo123');
	});

	it('um novo envio limpa os erros anteriores', async () => {
		signUp.mockRejectedValueOnce(validationFailed({ email: ['já está em uso'] }));
		signUp.mockResolvedValueOnce(undefined);
		render(Page);
		await fill();
		await submit();
		await screen.findByText('já está em uso');
		await submit();

		await waitFor(() => expect(nav.goto).toHaveBeenCalledOnce());
		expect(screen.queryByText('já está em uso')).not.toBeInTheDocument();
	});

	it('envio pendente ignora o segundo envio e desabilita o botão', async () => {
		let resolveSignUp: () => void = () => {};
		signUp.mockReturnValue(new Promise<void>((resolve) => (resolveSignUp = resolve)));
		const { container } = render(Page);
		await fill();
		await submit();

		expect(screen.getByRole('button', { name: 'Criar conta' })).toBeDisabled();
		await fireEvent.submit(container.querySelector('form')!);
		expect(signUp).toHaveBeenCalledTimes(1);

		resolveSignUp();
		await waitFor(() => expect(nav.goto).toHaveBeenCalledOnce());
	});

	it('tem link para entrar', () => {
		render(Page);
		expect(screen.getByRole('link', { name: 'Entrar' })).toHaveAttribute('href', '/entrar');
	});
});

describe('criar-conta/+page load', () => {
	it('com sessão ativa lança redirect para /', async () => {
		session.user = { email: 'ana@example.com' } as never;
		await expect(load({ parent: async () => ({}) } as never)).rejects.toMatchObject({
			status: 307,
			location: '/'
		});
	});

	it('sem sessão não redireciona', async () => {
		session.user = null;
		await expect(load({ parent: async () => ({}) } as never)).resolves.toBeUndefined();
	});

	it('define o título da página', () => {
		render(Page);

		expect(document.title).toBe('Criar conta — Bindr');
	});
});
