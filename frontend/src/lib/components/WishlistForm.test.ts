import '@testing-library/jest-dom/vitest';
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/svelte';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiError } from '../api/errors';
import { toasts } from '../toasts.svelte';

const put = vi.hoisted(() => vi.fn());
vi.mock('../api', () => ({ api: { put } }));

import WishlistForm from './WishlistForm.svelte';

const props = { cardNumber: 'OP01-001', cardName: 'Luffy', variantCode: 'tcgplayer:1', target: null };
const group = () => screen.getByRole('group', { name: 'Marcar Luffy tcgplayer:1 como desejada' });
const field = () => screen.getByLabelText('Quero');

describe('WishlistForm', () => {
	beforeEach(() => {
		put.mockReset();
		toasts.length = 0;
	});
	afterEach(cleanup);

	it('SCAR-35: grupo nomeado, campo numérico e botão "Quero esta" sem alvo', () => {
		render(WishlistForm, { props });

		expect(group()).toBeInTheDocument();
		expect(field()).toHaveAttribute('type', 'number');
		expect(field()).toHaveAttribute('min', '1');
		expect(field()).toHaveAttribute('step', '1');
		expect(field()).toHaveValue(null);
		expect(screen.getByRole('button', { name: 'Quero esta' })).toBeInTheDocument();
	});

	it('SCAR-35: com alvo, mostra o valor e "Atualizar desejo"', () => {
		render(WishlistForm, { props: { ...props, target: 3 } });

		expect(field()).toHaveValue(3);
		expect(screen.getByRole('button', { name: 'Atualizar desejo' })).toBeInTheDocument();
	});

	it('SCAR-36: envia PUT com target_quantity e avisa com 1 cópia', async () => {
		put.mockResolvedValue({ variant_code: 'tcgplayer:1', wishlist_target: 1 });
		render(WishlistForm, { props });
		await fireEvent.input(field(), { target: { value: '1' } });
		await fireEvent.click(screen.getByRole('button', { name: 'Quero esta' }));

		await waitFor(() => expect(screen.getByRole('button', { name: 'Atualizar desejo' })).toBeEnabled());
		expect(put).toHaveBeenCalledWith('/api/cards/OP01-001/variants/tcgplayer%3A1/wishlist', {
			target_quantity: 1
		});
		expect(toasts.map((t) => t.message)).toEqual(['Luffy tcgplayer:1 na lista de desejos: 1 cópia.']);
	});

	it('SCAR-36: mostra o alvo devolvido e usa plural', async () => {
		put.mockResolvedValue({ variant_code: 'tcgplayer:1', wishlist_target: 4 });
		render(WishlistForm, { props: { ...props, target: 2 } });
		await fireEvent.input(field(), { target: { value: '4' } });
		await fireEvent.click(screen.getByRole('button', { name: 'Atualizar desejo' }));

		await waitFor(() => expect(toasts).toHaveLength(1));
		expect(toasts[0].message).toBe('Luffy tcgplayer:1 na lista de desejos: 4 cópias.');
		expect(field()).toHaveValue(4);
	});

	it('SCAR-37: validation_failed liga a mensagem ao campo, foca e mantém o valor', async () => {
		put.mockRejectedValue(
			new ApiError(422, 'validation_failed', 'Dados inválidos.', {
				target_quantity: ['deve ser maior que 0']
			})
		);
		render(WishlistForm, { props });
		await fireEvent.input(field(), { target: { value: '7' } });
		await fireEvent.click(screen.getByRole('button', { name: 'Quero esta' }));

		const message = await screen.findByText('deve ser maior que 0');
		expect(field()).toHaveAttribute('aria-invalid', 'true');
		expect(field()).toHaveAttribute('aria-describedby', message.parentElement!.id);
		await waitFor(() => expect(field()).toHaveFocus());
		expect(field()).toHaveValue(7);
		expect(toasts).toHaveLength(0);
	});

	it('SCAR-37: o 0 chega à API pelo clique real (sem validação nativa) e o erro é anunciado', async () => {
		put.mockRejectedValue(
			new ApiError(422, 'validation_failed', 'Dados inválidos.', {
				target_quantity: ['deve ser maior que 0']
			})
		);
		const { container } = render(WishlistForm, { props });
		expect(container.querySelector('form')).toHaveAttribute('novalidate');
		await fireEvent.input(field(), { target: { value: '0' } });
		await fireEvent.click(screen.getByRole('button', { name: 'Quero esta' }));

		await waitFor(() => expect(put).toHaveBeenCalledWith(expect.any(String), { target_quantity: 0 }));
		const alert = await screen.findByRole('alert');
		expect(alert).toHaveTextContent('deve ser maior que 0');
		expect(field()).toHaveAttribute('aria-describedby', alert.id);
	});

	it('SCAR-37: o erro some no envio seguinte', async () => {
		put.mockRejectedValueOnce(
			new ApiError(422, 'validation_failed', 'x', { target_quantity: ['inválido'] })
		);
		put.mockResolvedValueOnce({ variant_code: 'tcgplayer:1', wishlist_target: 2 });
		render(WishlistForm, { props });
		await fireEvent.input(field(), { target: { value: '7' } });
		await fireEvent.click(screen.getByRole('button', { name: 'Quero esta' }));
		await screen.findByText('inválido');
		await fireEvent.input(field(), { target: { value: '2' } });
		await fireEvent.click(screen.getByRole('button', { name: 'Quero esta' }));

		await waitFor(() => expect(screen.queryByText('inválido')).not.toBeInTheDocument());
		expect(field()).not.toHaveAttribute('aria-invalid');
	});

	it('falha sem campo vira toast de erro', async () => {
		put.mockRejectedValue(new ApiError(0, 'network_error', 'Sem conexão com o servidor. Tente novamente.'));
		render(WishlistForm, { props });
		await fireEvent.input(field(), { target: { value: '2' } });
		await fireEvent.click(screen.getByRole('button', { name: 'Quero esta' }));

		await waitFor(() => expect(toasts).toHaveLength(1));
		expect(toasts[0]).toMatchObject({
			kind: 'error',
			message: 'Sem conexão com o servidor. Tente novamente.'
		});
	});

	it('SCAR-38: com envio pendente o botão fica desabilitado e novo submit é ignorado', async () => {
		let resolve!: (value: unknown) => void;
		put.mockReturnValue(new Promise((r) => (resolve = r)));
		render(WishlistForm, { props });
		await fireEvent.input(field(), { target: { value: '2' } });
		const form = field().closest('form')!;
		await fireEvent.submit(form);

		expect(screen.getByRole('button', { name: 'Quero esta' })).toBeDisabled();
		await fireEvent.submit(form);
		expect(put).toHaveBeenCalledTimes(1);

		resolve({ variant_code: 'tcgplayer:1', wishlist_target: 2 });
		await waitFor(() => expect(screen.getByRole('button', { name: 'Atualizar desejo' })).toBeEnabled());
	});
});
