import '@testing-library/jest-dom/vitest';
import { cleanup, render, screen } from '@testing-library/svelte';
import { createRawSnippet } from 'svelte';
import { afterEach, describe, expect, it } from 'vitest';
import FormError from './FormError.svelte';

afterEach(cleanup);

const children = createRawSnippet(() => ({ render: () => '<span>E-mail ou senha inválidos.</span>' }));

describe('FormError', () => {
	it('é um alerta com "Erro:" escrito e a mensagem', () => {
		render(FormError, { children });
		const alert = screen.getByRole('alert');
		expect(alert).toHaveTextContent('Erro:');
		expect(alert).toHaveTextContent('E-mail ou senha inválidos.');
		expect(alert).toHaveAttribute('tabindex', '-1');
	});

	it('focus() o torna o activeElement', () => {
		const { component } = render(FormError, { children });
		component.focus();
		expect(document.activeElement).toBe(screen.getByRole('alert'));
	});
});
