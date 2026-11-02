import '@testing-library/jest-dom/vitest';
import { cleanup, render, screen } from '@testing-library/svelte';
import { afterEach, describe, expect, it, vi } from 'vitest';

const pageState = vi.hoisted(() => ({ status: 404 }));
vi.mock('$app/state', () => ({ page: pageState }));
vi.mock('$app/paths', () => ({ resolve: (path: string) => path }));

import ErrorPage from './+error.svelte';

afterEach(() => {
	cleanup();
	pageState.status = 404;
});

describe('+error.svelte', () => {
	it('status 404: título, h1 e link para o catálogo', () => {
		render(ErrorPage);
		expect(screen.getByRole('heading', { level: 1, name: 'Página não encontrada' })).toBeInTheDocument();
		expect(document.title).toBe('Página não encontrada — Bindr');
		expect(screen.getByRole('link', { name: 'Ir para o catálogo' })).toHaveAttribute('href', '/');
	});

	it('outro status: "Algo deu errado" com o mesmo link', () => {
		pageState.status = 500;
		render(ErrorPage);
		expect(screen.getByRole('heading', { level: 1, name: 'Algo deu errado' })).toBeInTheDocument();
		expect(screen.queryByText('Página não encontrada')).not.toBeInTheDocument();
		expect(document.title).toBe('Algo deu errado — Bindr');
		expect(screen.getByRole('link', { name: 'Ir para o catálogo' })).toHaveAttribute('href', '/');
	});
});
