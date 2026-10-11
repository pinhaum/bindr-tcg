import '@testing-library/jest-dom/vitest';
import { cleanup, render, screen } from '@testing-library/svelte';
import { createRawSnippet } from 'svelte';
import { afterEach, describe, expect, it, vi } from 'vitest';

const wideQuery = vi.hoisted(() => {
	const query = { matches: false, addEventListener() {}, removeEventListener() {} };
	vi.stubGlobal('matchMedia', () => query);
	return query;
});

vi.mock('$app/paths', () => ({ resolve: () => '/app/' }));
vi.mock('$app/state', () => ({ page: { url: new URL('http://localhost/app/') } }));

import { shell } from '../shell.svelte';
import AppShell from './AppShell.svelte';

const children = createRawSnippet(() => ({ render: () => '<p>conteúdo da rota</p>' }));
const aside = createRawSnippet(() => ({ render: () => '<p>painel lateral</p>' }));

describe('AppShell', () => {
	afterEach(() => {
		cleanup();
		wideQuery.matches = false;
		shell.aside = null;
	});

	it('renderiza a marca, o seletor de tema, a navegação principal e o conteúdo em main', () => {
		render(AppShell, { children });

		expect(screen.getByText('Bindr')).toBeInTheDocument();
		expect(screen.getByLabelText('Tema')).toBeInTheDocument();
		expect(screen.getByRole('navigation', { name: 'Principal' })).toBeInTheDocument();
		expect(screen.getByRole('main')).toContainElement(screen.getByText('conteúdo da rota'));
	});

	it('mantém um só DOM: uma navegação e um seletor', () => {
		render(AppShell, { children });

		expect(screen.getAllByRole('navigation')).toHaveLength(1);
		expect(screen.getAllByLabelText('Tema')).toHaveLength(1);
	});

	it('tem o skip link como primeiro focável, apontando para main#conteudo', () => {
		const { container } = render(AppShell, { children });

		const skip = screen.getByRole('link', { name: 'Ir para o conteúdo' });
		expect(skip).toHaveAttribute('href', '#conteudo');
		expect(container.querySelector('a, button, select')).toBe(skip);
		expect(screen.getByRole('main')).toHaveAttribute('id', 'conteudo');
		expect(screen.getByRole('main')).toHaveAttribute('tabindex', '-1');
	});

	describe('slot da coluna lateral (SCAT-33)', () => {
		it('a partir de 64rem, com snippet, mostra o conteúdo em .nav depois da navegação', () => {
			wideQuery.matches = true;
			shell.aside = aside;
			const { container } = render(AppShell, { children });

			const nav = container.querySelector('.nav');
			const panel = screen.getByText('painel lateral');
			expect(nav).toContainElement(panel);
			expect(screen.getByRole('navigation', { name: 'Principal' }).compareDocumentPosition(panel)).toBe(
				Node.DOCUMENT_POSITION_FOLLOWING
			);
		});

		it('abaixo de 64rem não renderiza o snippet', () => {
			shell.aside = aside;
			render(AppShell, { children });

			expect(screen.queryByText('painel lateral')).not.toBeInTheDocument();
		});

		it('a partir de 64rem, sem snippet, não renderiza o contêiner', () => {
			wideQuery.matches = true;
			const { container } = render(AppShell, { children });

			expect(container.querySelector('.aside')).toBeNull();
		});
	});
});
