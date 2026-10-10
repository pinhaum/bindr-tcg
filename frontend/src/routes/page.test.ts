import '@testing-library/jest-dom/vitest';
import { cleanup, render, screen } from '@testing-library/svelte';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('$app/paths', () => ({ resolve: () => '/app/' }));

import { session } from '../lib/session.svelte';
import Page from './+page.svelte';

describe('+page.svelte (/app)', () => {
	beforeEach(() => {
		session.user = null;
	});
	afterEach(cleanup);

	it('com sessão mostra o e-mail do usuário', () => {
		session.user = { email: 'ana@example.com' };
		render(Page);

		expect(screen.getByText('ana@example.com')).toBeInTheDocument();
		expect(screen.queryByRole('link', { name: 'Entrar' })).not.toBeInTheDocument();
	});

	it('sem sessão convida a entrar ou criar conta', () => {
		render(Page);

		expect(screen.getByRole('link', { name: 'Entrar' })).toHaveAttribute('href', '/app/entrar');
		expect(screen.getByRole('link', { name: 'Criar conta' })).toHaveAttribute('href', '/app/criar-conta');
	});
});
