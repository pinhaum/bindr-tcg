import '@testing-library/jest-dom/vitest';
import { cleanup, render, screen } from '@testing-library/svelte';
import { afterEach, describe, expect, it, vi } from 'vitest';
import DeckNotFound from './DeckNotFound.svelte';

vi.mock('$app/paths', () => ({ resolve: () => '/' }));

afterEach(cleanup);

describe('DeckNotFound', () => {
	it('define o título da página', () => {
		render(DeckNotFound, { message: 'Deck não encontrado.' });
		expect(document.title).toBe('Deck não encontrado — Bindr');
	});

	it('mostra a mensagem recebida', () => {
		render(DeckNotFound, { message: 'Esse deck não existe.' });
		expect(screen.getByRole('heading', { name: 'Esse deck não existe.' })).toBeInTheDocument();
	});

	it('leva de volta à lista de baralhos', () => {
		render(DeckNotFound, { message: 'x' });
		expect(screen.getByRole('link', { name: 'Voltar aos baralhos' })).toHaveAttribute(
			'href',
			'/baralhos'
		);
	});
});
