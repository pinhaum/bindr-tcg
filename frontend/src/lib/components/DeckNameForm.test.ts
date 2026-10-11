import '@testing-library/jest-dom/vitest';
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/svelte';
import { createRawSnippet } from 'svelte';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { ApiError } from '../api/errors';
import DeckNameForm from './DeckNameForm.svelte';

afterEach(cleanup);

const children = createRawSnippet(() => ({ render: () => '<span>Salvar</span>' }));

describe('DeckNameForm', () => {
	it('tem rótulo, required, maxlength 60 e valor inicial', () => {
		render(DeckNameForm, { initialName: 'Luffy', submit: vi.fn(), children });
		const input = screen.getByLabelText('Nome do deck (até 60 caracteres)');
		expect(input).toBeRequired();
		expect(input).toHaveAttribute('maxlength', '60');
		expect(input).toHaveValue('Luffy');
	});

	it('validation_failed com fields.name liga a mensagem, foca e mantém o valor', async () => {
		const submit = vi.fn().mockRejectedValue(
			new ApiError(422, 'validation_failed', 'Dados inválidos.', { name: ['já está em uso'] })
		);
		render(DeckNameForm, { initialName: 'Luffy', submit, children });
		await fireEvent.click(screen.getByRole('button', { name: 'Salvar' }));
		const input = screen.getByLabelText('Nome do deck (até 60 caracteres)');
		await waitFor(() => expect(input).toHaveFocus());
		expect(input).toHaveAttribute('aria-invalid', 'true');
		expect(input).toHaveAttribute('aria-describedby', 'field-name-errors');
		expect(document.getElementById('field-name-errors')).toHaveTextContent('já está em uso');
		expect(input).toHaveValue('Luffy');
		expect(screen.queryByRole('alert')).not.toBeInTheDocument();
	});

	it('outro erro vai para o FormError', async () => {
		const submit = vi.fn().mockRejectedValue(new ApiError(0, 'network_error', 'Sem conexão.'));
		render(DeckNameForm, { initialName: 'A', submit, children });
		await fireEvent.click(screen.getByRole('button', { name: 'Salvar' }));
		const alert = await screen.findByRole('alert');
		expect(alert).toHaveTextContent('Sem conexão.');
		await waitFor(() => expect(alert).toHaveFocus());
	});

	it('segundo envio com o primeiro pendente é ignorado e o botão fica desabilitado', async () => {
		const submit = vi.fn(() => new Promise<void>(() => {}));
		render(DeckNameForm, { initialName: 'A', submit, children });
		const button = screen.getByRole('button', { name: 'Salvar' });
		await fireEvent.click(button);
		await waitFor(() => expect(button).toBeDisabled());
		await fireEvent.submit(button.closest('form')!);
		expect(submit).toHaveBeenCalledTimes(1);
		expect(submit).toHaveBeenCalledWith('A');
	});
});
