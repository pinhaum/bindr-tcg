import '@testing-library/jest-dom/vitest';
import { cleanup, render, screen } from '@testing-library/svelte';
import { afterEach, describe, expect, it } from 'vitest';
import TextField from './TextField.svelte';

afterEach(cleanup);

describe('TextField', () => {
	it('associa o rótulo ao campo', () => {
		render(TextField, { name: 'email', label: 'E-mail', type: 'email', errors: [] });
		const input = screen.getByLabelText('E-mail');
		expect(input).toBe(document.getElementById('field-email'));
		expect(input).toHaveAttribute('type', 'email');
		expect(input).toHaveAttribute('name', 'email');
	});

	it('sem erro não declara aria-invalid nem aria-describedby', () => {
		render(TextField, { name: 'email', label: 'E-mail', errors: [] });
		const input = screen.getByLabelText('E-mail');
		expect(input).not.toHaveAttribute('aria-invalid');
		expect(input).not.toHaveAttribute('aria-describedby');
	});

	it('com erro aponta aria-describedby para a lista com as mensagens', () => {
		render(TextField, {
			name: 'email',
			label: 'E-mail',
			errors: ['não pode ficar em branco', 'é inválido']
		});
		const input = screen.getByLabelText('E-mail');
		expect(input).toHaveAttribute('aria-invalid', 'true');
		expect(input).toHaveAttribute('aria-describedby', 'field-email-errors');
		const list = document.getElementById('field-email-errors')!;
		expect(list).toHaveTextContent('não pode ficar em branco');
		expect(list).toHaveTextContent('é inválido');
		expect(list.querySelectorAll('li')).toHaveLength(2);
	});

	it('renderiza uma linha por mensagem mesmo repetida', () => {
		render(TextField, { name: 'email', label: 'E-mail', errors: ['x', 'x'] });
		expect(document.getElementById('field-email-errors')!.querySelectorAll('li')).toHaveLength(2);
	});

	it('focus() foca o input', () => {
		const { component } = render(TextField, { name: 'email', label: 'E-mail', errors: [] });
		component.focus();
		expect(screen.getByLabelText('E-mail')).toHaveFocus();
	});
});
