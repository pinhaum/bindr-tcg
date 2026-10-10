import '@testing-library/jest-dom/vitest';
import { cleanup, fireEvent, render, screen } from '@testing-library/svelte';
import { createRawSnippet } from 'svelte';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiError, networkError, unexpectedResponse } from '../lib/api/errors';

const nav = vi.hoisted(() => ({ refreshAll: vi.fn(), onNavigate: vi.fn() }));
vi.mock('$app/navigation', () => nav);

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
});
