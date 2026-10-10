import '@testing-library/jest-dom/vitest';
import { cleanup, render, screen } from '@testing-library/svelte';
import { createRawSnippet } from 'svelte';
import { afterEach, describe, expect, it, vi } from 'vitest';

vi.hoisted(() => {
	vi.stubGlobal('matchMedia', () => ({ matches: false, addEventListener() {}, removeEventListener() {} }));
});

vi.mock('$app/paths', () => ({ resolve: () => '/app/' }));
vi.mock('$app/state', () => ({ page: { url: new URL('http://localhost/app/') } }));

import AppShell from './AppShell.svelte';

const children = createRawSnippet(() => ({ render: () => '<p>conteúdo da rota</p>' }));

describe('AppShell', () => {
	afterEach(cleanup);

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
});
