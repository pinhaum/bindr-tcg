import '@testing-library/jest-dom/vitest';
import { cleanup, render, screen } from '@testing-library/svelte';
import { createRawSnippet } from 'svelte';
import { afterEach, describe, expect, it } from 'vitest';
import Button from './Button.svelte';

afterEach(cleanup);

const children = createRawSnippet(() => ({ render: () => '<span>Entrar</span>' }));

describe('Button', () => {
	it('por padrão é submit, habilitado e sem aria-busy', () => {
		render(Button, { children });
		const button = screen.getByRole('button', { name: 'Entrar' });
		expect(button).toHaveAttribute('type', 'submit');
		expect(button).toBeEnabled();
		expect(button).not.toHaveAttribute('aria-busy');
	});

	it('pendente fica desabilitado com aria-busy="true"', () => {
		render(Button, { children, pending: true });
		const button = screen.getByRole('button', { name: 'Entrar' });
		expect(button).toBeDisabled();
		expect(button).toHaveAttribute('aria-busy', 'true');
	});

	it('aceita type e variant', () => {
		render(Button, { children, type: 'button', variant: 'secondary' });
		const button = screen.getByRole('button', { name: 'Entrar' });
		expect(button).toHaveAttribute('type', 'button');
		expect(button).toHaveClass('secondary');
	});
});
