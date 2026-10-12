import '@testing-library/jest-dom/vitest';
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/svelte';
import { tick } from 'svelte';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { CardDetailPayload, EditingDeck } from '../../../lib/api/types';

vi.hoisted(() => {
	const query = { matches: false, addEventListener: () => {}, removeEventListener: () => {} };
	vi.stubGlobal('matchMedia', () => query);
});

vi.mock('$app/navigation', () => ({ goto: vi.fn() }));

vi.mock('$app/state', async () => {
	const { SvelteMap, SvelteURL } = await import('svelte/reactivity');
	const params = new SvelteMap<string, string>();
	return {
		page: {
			url: new SvelteURL('http://localhost/cartas/OP01-001'),
			params: new Proxy({}, { get: (_, key) => params.get(String(key)) }),
			setParam: (value: string) => params.set('card_number', value)
		},
		navigating: { to: null }
	};
});

vi.mock('$app/paths', () => ({ resolve: (path: string) => path }));

const client = vi.hoisted(() => ({ get: vi.fn(), post: vi.fn(), put: vi.fn() }));
vi.mock('../../../lib/api/index', () => ({ api: client }));
vi.mock('../../../lib/api', () => ({ api: client }));

import { page } from '$app/state';
import { session } from '../../../lib/session.svelte';
import { shell } from '../../../lib/shell.svelte';
import Page from './+page.svelte';

const mockPage = page as unknown as { setParam: (value: string) => void };

const DECK: EditingDeck = { id: 7, name: 'Mugiwara', quantity: 0, is_leader: false };

const detail = (number: string, name: string, editing_deck: EditingDeck | null): CardDetailPayload => ({
	card_number: number,
	name,
	card_type: 'character',
	colors: ['Red'],
	cost: 1,
	life: null,
	power: 5000,
	counter: null,
	block_icon: null,
	attributes: [],
	traits: [],
	effect_text: null,
	trigger_text: null,
	set: { code: 'OP01', name: 'Romance Dawn' },
	featured_variant_code: null,
	editing_deck,
	variants: []
});

const panel = () => screen.queryByRole('heading', { level: 2, name: 'Deck em edição' });
const signIn = () => {
	session.user = { email: 'a@exemplo.test' } as typeof session.user;
};

describe('cartas/[card_number]/+page.svelte — deck em edição', () => {
	beforeEach(() => {
		client.get.mockReset();
		client.post.mockReset();
		mockPage.setParam('OP01-001');
		session.user = null;
	});
	afterEach(() => {
		cleanup();
		shell.aside = null;
	});

	it('SDEC-33: com sessão e deck em edição, mostra a seção', async () => {
		signIn();
		client.get.mockResolvedValue(detail('OP01-001', 'Luffy', DECK));
		render(Page);

		expect(await screen.findByRole('heading', { level: 2, name: 'Deck em edição' })).toBeInTheDocument();
		expect(screen.getByRole('link', { name: 'Mugiwara' })).toBeInTheDocument();
	});

	it('SDEC-34: editing_deck nulo não mostra a seção', async () => {
		signIn();
		client.get.mockResolvedValue(detail('OP01-001', 'Luffy', null));
		render(Page);

		await screen.findByRole('heading', { level: 1, name: 'Luffy' });
		expect(panel()).toBeNull();
	});

	it('SDEC-34: sem sessão não mostra a seção, mesmo com deck no payload', async () => {
		client.get.mockResolvedValue(detail('OP01-001', 'Luffy', DECK));
		render(Page);

		await screen.findByRole('heading', { level: 1, name: 'Luffy' });
		expect(panel()).toBeNull();
	});

	it('SDEC-36: trocar de carta com envio em voo não aplica a resposta antiga à carta nova', async () => {
		signIn();
		let resolveOld!: (value: { quantity: number }) => void;
		client.post.mockReturnValue(new Promise((resolve) => (resolveOld = resolve)));
		client.get.mockImplementation(async (path: string) =>
			path.includes('OP01-002')
				? detail('OP01-002', 'Zoro', { ...DECK, quantity: 1 })
				: detail('OP01-001', 'Luffy', DECK)
		);
		render(Page);

		fireEvent.click(
			await screen.findByRole('button', { name: 'Adicionar uma cópia de Luffy ao deck Mugiwara' })
		);
		await waitFor(() => expect(client.post).toHaveBeenCalledTimes(1));

		mockPage.setParam('OP01-002');
		await tick();
		await screen.findByRole('heading', { level: 1, name: 'Zoro' });
		resolveOld({ quantity: 3 });
		await tick();

		expect(screen.getByRole('button', { name: 'Remover uma cópia de Zoro do deck Mugiwara' })).toBeInTheDocument();
		expect(screen.queryByText(/3 cópias/)).toBeNull();
		expect(client.post).toHaveBeenCalledTimes(1);
	});
});
