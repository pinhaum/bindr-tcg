import '@testing-library/jest-dom/vitest';
import { cleanup, fireEvent, render, screen } from '@testing-library/svelte';
import { createRawSnippet } from 'svelte';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiError, networkError, unexpectedResponse } from '../lib/api/errors';

vi.hoisted(() => {
	vi.stubGlobal('matchMedia', () => ({ matches: false, addEventListener() {}, removeEventListener() {} }));
});

const nav = vi.hoisted(() => ({ refreshAll: vi.fn(), onNavigate: vi.fn(), afterNavigate: vi.fn() }));
vi.mock('$app/navigation', () => nav);
vi.mock('$app/paths', () => ({ resolve: () => '/' }));
vi.mock('$app/state', () => ({ page: { url: new URL('http://localhost/') } }));

const reduced = vi.hoisted(() => ({ current: false }));
vi.mock('svelte/motion', () => ({ prefersReducedMotion: reduced }));

import { session } from '../lib/session.svelte';
import { viewTransitionOnNavigate } from '../lib/view-transition';
import Layout from './+layout.svelte';

const children = createRawSnippet(() => ({ render: () => '<p>conteúdo da rota</p>' }));
const renderLayout = () => render(Layout, { children });

describe('+layout.svelte', () => {
	beforeEach(() => {
		nav.refreshAll.mockReset();
		nav.onNavigate.mockReset();
		nav.afterNavigate.mockReset();
		session.status = 'loading';
		session.user = null;
		session.error = null;
	});

	afterEach(cleanup);

	it('com "loading" não mostra nada da rota nem erro', () => {
		renderLayout();

		expect(screen.queryByText('conteúdo da rota')).not.toBeInTheDocument();
		expect(screen.queryByRole('button', { name: 'Tentar novamente' })).not.toBeInTheDocument();
	});

	it('com "loading" anuncia "Carregando…" em um status', () => {
		renderLayout();

		expect(screen.getByRole('status')).toHaveTextContent('Carregando…');
	});

	it('com erro mostra h1 "Erro", a mensagem em alert, main#conteudo e o título', () => {
		session.status = 'error';
		session.error = networkError();
		const { container } = renderLayout();

		expect(screen.getByRole('heading', { level: 1, name: 'Erro' })).toBeInTheDocument();
		expect(screen.getByText(networkError().message)).toHaveAttribute('role', 'alert');
		expect(container.querySelector('main#conteudo')).toBeInTheDocument();
		expect(document.title).toBe('Erro — Bindr');
	});

	it('com "ready" mostra a rota', () => {
		session.status = 'ready';
		renderLayout();

		expect(screen.getByText('conteúdo da rota')).toBeInTheDocument();
		expect(screen.queryByRole('button', { name: 'Tentar novamente' })).not.toBeInTheDocument();
	});

	it.each([
		['network_error', networkError()],
		['unexpected_response', unexpectedResponse()],
		[
			'406 unsupported_browser',
			new ApiError(406, 'unsupported_browser', 'Navegador não suportado. Atualize para uma versão recente.')
		],
		['500 internal_error', new ApiError(500, 'internal_error', 'Erro interno. Tente novamente mais tarde.')]
	])('com erro %s mostra a mensagem exata e "Tentar novamente", sem a rota', (_name, error) => {
		session.status = 'error';
		session.error = error;
		renderLayout();

		expect(screen.getByText(error.message)).toBeInTheDocument();
		expect(screen.getByRole('button', { name: 'Tentar novamente' })).toBeInTheDocument();
		expect(screen.queryByText('conteúdo da rota')).not.toBeInTheDocument();
	});

	it('"Tentar novamente" chama refreshAll', async () => {
		session.status = 'error';
		session.error = networkError();
		renderLayout();

		await fireEvent.click(screen.getByRole('button', { name: 'Tentar novamente' }));

		expect(nav.refreshAll).toHaveBeenCalledOnce();
	});

	it('monta o Toaster e registra onNavigate com a transição', () => {
		session.status = 'ready';
		const { container } = renderLayout();

		expect(container.querySelector('[aria-live="polite"]')).toBeInTheDocument();
		expect(nav.onNavigate).toHaveBeenCalledWith(viewTransitionOnNavigate);
	});

	describe('foco após navegação', () => {
		const navigate = (type: string) => {
			session.status = 'ready';
			const { container } = renderLayout();
			const callback = nav.afterNavigate.mock.calls[0][0];
			callback({ type });
			return container.querySelector<HTMLElement>('main#conteudo')!;
		};

		it('navegação client-side move o foco para o main', () => {
			const main = navigate('link');

			expect(main).toHaveAttribute('tabindex', '-1');
			expect(main).toHaveFocus();
		});

		it('na carga inicial ("enter") não rouba o foco', () => {
			const main = navigate('enter');

			expect(main).not.toHaveFocus();
		});

		it('não tira o foco de quem já está dentro do main', () => {
			session.status = 'ready';
			const { container } = renderLayout();
			const main = container.querySelector<HTMLElement>('main#conteudo')!;
			const inner = document.createElement('input');
			main.appendChild(inner);
			inner.focus();

			nav.afterNavigate.mock.calls[0][0]({ type: 'goto' });

			expect(inner).toHaveFocus();
		});

		describe('com origem e destino', () => {
			const at = (url: string) => ({ url: new URL(url) });
			const renderWithOutsideFocus = () => {
				session.status = 'ready';
				const { container } = renderLayout();
				const outside = document.createElement('button');
				container.appendChild(outside);
				outside.focus();
				return { main: container.querySelector<HTMLElement>('main#conteudo')!, outside };
			};

			it('só a query muda: mantém o foco fora do main', () => {
				const { main, outside } = renderWithOutsideFocus();

				nav.afterNavigate.mock.calls[0][0]({
					type: 'goto',
					from: at('http://localhost/?a=1'),
					to: at('http://localhost/?a=2')
				});

				expect(outside).toHaveFocus();
				expect(main).not.toHaveFocus();
			});

			it('rota diferente: o foco vai para o main', () => {
				const { main } = renderWithOutsideFocus();

				nav.afterNavigate.mock.calls[0][0]({
					type: 'link',
					from: at('http://localhost/'),
					to: at('http://localhost/entrar')
				});

				expect(main).toHaveFocus();
			});
		});
	});
});
