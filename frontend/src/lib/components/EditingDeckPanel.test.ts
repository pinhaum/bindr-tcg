import '@testing-library/jest-dom/vitest';
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/svelte';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiError } from '../api/errors';
import { toasts } from '../toasts.svelte';

const post = vi.hoisted(() => vi.fn());
const put = vi.hoisted(() => vi.fn());
vi.mock('../api', () => ({ api: { post, put } }));

import EditingDeckPanel from './EditingDeckPanel.svelte';

const NAME = 'Monkey D. Luffy';
const CN = 'OP01-003';
const DECK = 'Mugiwara';

const props = (over: Record<string, unknown> = {}) => ({
	deck: { id: 7, name: DECK, quantity: 0, is_leader: false },
	cardNumber: CN,
	name: NAME,
	cardType: 'character',
	...over
});
const remove = () => screen.getByRole('button', { name: `Remover uma cópia de ${NAME} do deck ${DECK}` });
const add = () => screen.getByRole('button', { name: `Adicionar uma cópia de ${NAME} ao deck ${DECK}` });
const flush = () => new Promise((r) => setTimeout(r, 0));

beforeEach(() => {
	post.mockReset();
	put.mockReset();
	toasts.splice(0);
});
afterEach(cleanup);

describe('EditingDeckPanel', () => {
	it('SDEC-33: título e link para o deck', () => {
		render(EditingDeckPanel, props());
		expect(screen.getByRole('heading', { name: 'Deck em edição' })).toBeInTheDocument();
		expect(screen.getByRole('link', { name: DECK })).toHaveAttribute('href', '/baralhos/7');
		expect(screen.getByText(/As cartas vão para o deck/)).toBeInTheDocument();
	});

	it.each([
		[0, `0 cópias de ${NAME} no deck`],
		[1, `1 cópia de ${NAME} no deck`],
		[2, `2 cópias de ${NAME} no deck`]
	])('SDEC-35: com %i cópias mostra "%s"', (quantity, text) => {
		render(EditingDeckPanel, props({ deck: { id: 7, name: DECK, quantity, is_leader: false } }));
		expect(screen.getByText(text)).toBeInTheDocument();
		expect(add()).toBeInTheDocument();
		expect(remove()).toBeInTheDocument();
	});

	it('SDEC-35: região viva polite e alvos de 44px', () => {
		const { container } = render(EditingDeckPanel, props());
		expect(container.querySelector('[aria-live="polite"]')).not.toBeNull();
		const source = readFileSync(resolve(process.cwd(), 'src/lib/components/QuantityStepper.svelte'), 'utf8');
		expect(source).toContain('min-block-size: var(--touch-target)');
	});

	it('SDEC-36: três + enviam três POST em série ao deck do payload', async () => {
		let resolveCurrent: (v: { quantity: number }) => void = () => {};
		post.mockImplementation(() => new Promise((r) => (resolveCurrent = r)));
		render(EditingDeckPanel, props());
		await fireEvent.click(add());
		await fireEvent.click(add());
		await fireEvent.click(add());
		expect(post).toHaveBeenCalledTimes(1);
		for (let n = 1; n <= 3; n++) {
			await waitFor(() => expect(post).toHaveBeenCalledTimes(n));
			resolveCurrent({ quantity: n });
			await flush();
		}
		expect(post.mock.calls.map((c) => c[0])).toEqual(
			Array(3).fill(`/api/decks/7/cards/${CN}/increment`)
		);
	});

	it('SDEC-36: recusa 422 do teto volta ao confirmado e mostra a message', async () => {
		post.mockRejectedValue(new ApiError(422, 'validation_failed', 'O deck já tem 50 cópias.'));
		render(EditingDeckPanel, props({ deck: { id: 7, name: DECK, quantity: 4, is_leader: false } }));
		await fireEvent.click(add());
		await waitFor(() => expect(toasts.some((t) => t.message === 'O deck já tem 50 cópias.')).toBe(true));
		expect(screen.getByText(`4 cópias de ${NAME} no deck`)).toBeInTheDocument();
	});

	it('SDEC-37: − em zero não envia e anuncia', async () => {
		const { container } = render(EditingDeckPanel, props());
		expect(remove()).toHaveAttribute('aria-disabled', 'true');
		await fireEvent.click(remove());
		await flush();
		expect(post).not.toHaveBeenCalled();
		expect(container.querySelector('[aria-live="polite"]')).toHaveTextContent(
			`${CN} não está no deck “${DECK}”.`
		);
	});

	it('SDEC-38: Leader sem is_leader envia PUT, troca o botão e avisa (SDEC-39)', async () => {
		put.mockResolvedValue({ leader_card_number: CN });
		render(EditingDeckPanel, props({ cardType: 'leader' }));
		expect(screen.queryByRole('button', { name: /Remover uma cópia/ })).toBeNull();
		const button = screen.getByRole('button', { name: `Usar ${NAME} como Leader do deck ${DECK}` });
		expect(button).toHaveTextContent('Usar como Leader');
		await fireEvent.click(button);
		await waitFor(() =>
			expect(screen.getByRole('button', { name: `${NAME} é o Leader deste deck` })).toBeInTheDocument()
		);
		expect(put).toHaveBeenCalledWith('/api/decks/7/leader', { card_number: CN });
		expect(toasts.some((t) => t.message === `${CN} é o Leader do deck “${DECK}”.`)).toBe(true);
	});

	it('SDEC-38: erro do PUT mostra a message e mantém o botão', async () => {
		put.mockRejectedValue(new ApiError(422, 'validation_failed', 'Não é um Leader.'));
		render(EditingDeckPanel, props({ cardType: 'leader' }));
		await fireEvent.click(screen.getByRole('button', { name: /Usar .* como Leader/ }));
		await waitFor(() => expect(toasts.some((t) => t.message === 'Não é um Leader.')).toBe(true));
		expect(screen.getByRole('button', { name: /Usar .* como Leader/ })).toBeEnabled();
	});

	it('SDEC-38: Leader atual é aria-disabled, focável e sem envio', async () => {
		render(EditingDeckPanel, props({ cardType: 'leader', deck: { id: 7, name: DECK, quantity: 1, is_leader: true } }));
		const current = screen.getByRole('button', { name: `${NAME} é o Leader deste deck` });
		expect(current).toHaveAttribute('aria-disabled', 'true');
		expect(current).not.toBeDisabled();
		await fireEvent.click(current);
		expect(put).not.toHaveBeenCalled();
	});
});
