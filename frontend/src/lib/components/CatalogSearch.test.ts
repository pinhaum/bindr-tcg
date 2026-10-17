import '@testing-library/jest-dom/vitest';
import { cleanup, fireEvent, render, screen } from '@testing-library/svelte';
import { afterEach, describe, expect, it, vi } from 'vitest';
import CatalogSearch from './CatalogSearch.svelte';

afterEach(cleanup);

describe('CatalogSearch', () => {
	it('expõe o formulário de busca, o campo rotulado e o botão', () => {
		render(CatalogSearch, { value: '', onsearch: vi.fn() });
		expect(screen.getByRole('search')).toBeInTheDocument();
		const input = screen.getByLabelText('Buscar por nome ou card_number');
		expect(input).toHaveAttribute('type', 'search');
		expect(input).toHaveAttribute('placeholder', 'OP01-024');
		expect(screen.getByRole('button', { name: 'Buscar' })).toBeInTheDocument();
	});

	it('exibe o valor inicial no campo', () => {
		render(CatalogSearch, { value: 'zoro', onsearch: vi.fn() });
		expect(screen.getByLabelText('Buscar por nome ou card_number')).toHaveValue('zoro');
	});

	it('envia o texto digitado sem tratar e previne o envio nativo', async () => {
		const onsearch = vi.fn();
		render(CatalogSearch, { value: '', onsearch });
		await fireEvent.input(screen.getByLabelText('Buscar por nome ou card_number'), {
			target: { value: '  zoro ' }
		});
		const submit = new Event('submit', { bubbles: true, cancelable: true });
		screen.getByRole('search').dispatchEvent(submit);
		expect(onsearch).toHaveBeenCalledExactlyOnceWith('  zoro ');
		expect(submit.defaultPrevented).toBe(true);
	});

	it('segue a prop value quando ela muda', async () => {
		const { rerender } = render(CatalogSearch, { value: 'zoro', onsearch: vi.fn() });
		const input = screen.getByLabelText('Buscar por nome ou card_number');
		await rerender({ value: '' });
		expect(input).toHaveValue('');
	});

	it('o que o usuário digita vira o termo enviado, mesmo com value inicial', async () => {
		const onsearch = vi.fn();
		render(CatalogSearch, { value: 'zoro', onsearch });
		const input = screen.getByLabelText('Buscar por nome ou card_number');
		await fireEvent.input(input, { target: { value: 'luffy' } });
		expect(input).toHaveValue('luffy');
		screen.getByRole('search').dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));
		expect(onsearch).toHaveBeenCalledExactlyOnceWith('luffy');
	});
});
