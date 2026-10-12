import '@testing-library/jest-dom/vitest';
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/svelte';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiError } from '../api/errors';
import type { ShortfallCard } from '../api/types';

vi.mock('$app/paths', () => ({ resolve: (path: string) => path }));

const apiMock = vi.hoisted(() => ({ get: vi.fn() }));
vi.mock('../api/index', () => ({ api: apiMock }));

import DeckShortfall from './DeckShortfall.svelte';

const card = (extra: Partial<ShortfallCard> = {}): ShortfallCard => ({
	card_number: 'OP01-001',
	name: 'Luffy',
	missing: 1,
	decks: [{ id: 7, name: 'Chapéus' }],
	...extra
});

beforeEach(() => apiMock.get.mockReset());
afterEach(cleanup);

describe('DeckShortfall', () => {
	it('não renderiza nada com a lista vazia (SDEC-41)', async () => {
		apiMock.get.mockResolvedValue([]);
		const { container } = render(DeckShortfall);
		await waitFor(() => expect(apiMock.get).toHaveBeenCalledWith('/api/decks/shortfall'));
		await Promise.resolve();
		expect(screen.queryByText('Faltando para os baralhos')).toBeNull();
		expect(container.querySelector('section, h2, ul')).toBeNull();
	});

	it('mostra "falta 1", "faltam 2" e os decks em ordem separados por vírgula (SDEC-40)', async () => {
		apiMock.get.mockResolvedValue([
			card(),
			card({
				card_number: 'OP02-002',
				name: 'Zoro',
				missing: 2,
				decks: [
					{ id: 3, name: 'Alfa' },
					{ id: 9, name: 'Beta' }
				]
			})
		]);
		const { container } = render(DeckShortfall);
		expect(await screen.findByRole('heading', { name: 'Faltando para os baralhos' })).toBeVisible();
		expect(screen.getByRole('link', { name: 'Luffy' })).toHaveAttribute('href', '/cartas/OP01-001');
		expect(screen.getByText('OP01-001').tagName).toBe('CODE');
		expect(screen.getByText('falta 1')).toBeVisible();
		expect(screen.getByText('faltam 2')).toBeVisible();
		expect(screen.getByRole('link', { name: 'Chapéus' })).toHaveAttribute('href', '/baralhos/7');
		expect(screen.getByRole('link', { name: 'Alfa' })).toHaveAttribute('href', '/baralhos/3');
		expect(screen.getByRole('link', { name: 'Beta' })).toHaveAttribute('href', '/baralhos/9');
		const second = container.querySelectorAll('li')[1];
		expect(second.textContent?.replace(/\s+/g, ' ')).toContain('Em Alfa, Beta');
	});

	it('mostra a mensagem e repete a consulta em "Tentar novamente" (SDEC-42)', async () => {
		apiMock.get
			.mockRejectedValueOnce(new ApiError(500, 'internal_error', 'Algo deu errado.'))
			.mockResolvedValueOnce([card()]);
		render(DeckShortfall);
		expect(await screen.findByText('Algo deu errado.')).toBeVisible();
		await fireEvent.click(screen.getByRole('button', { name: 'Tentar novamente' }));
		expect(await screen.findByText('falta 1')).toBeVisible();
		expect(apiMock.get).toHaveBeenCalledTimes(2);
		expect(screen.queryByText('Algo deu errado.')).toBeNull();
	});
});
