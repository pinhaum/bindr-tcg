import '@testing-library/jest-dom/vitest';
import { cleanup, fireEvent, render, screen, within } from '@testing-library/svelte';
import { flushSync } from 'svelte';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { notifyError, notifySuccess, toasts } from '../toasts.svelte';
import Toaster from './Toaster.svelte';

function polite(container: HTMLElement) {
	return container.querySelector<HTMLElement>('[aria-live="polite"]')!;
}

vi.hoisted(() => {
	window.matchMedia = ((query: string) => ({
		matches: query === '(prefers-reduced-motion: reduce)',
		media: query,
		addEventListener: () => {},
		removeEventListener: () => {}
	})) as unknown as typeof window.matchMedia;
});

describe('Toaster', () => {
	beforeEach(() => {
		vi.useFakeTimers();
	});

	afterEach(() => {
		cleanup();
		toasts.splice(0);
		vi.useRealTimers();
	});

	it('monta as duas regiões antes de qualquer mensagem', () => {
		const { container } = render(Toaster);

		expect(polite(container)).toBeInTheDocument();
		expect(screen.getByRole('alert')).toBeInTheDocument();
		expect(screen.getByRole('alert').children).toHaveLength(0);
		expect(polite(container).children).toHaveLength(0);
	});

	it('exibe o sucesso na região polite e o remove aos 5000 ms, não antes', async () => {
		const { container } = render(Toaster);

		notifySuccess('Sessão encerrada.');
		flushSync();
		expect(within(polite(container)).getByText('Sessão encerrada.')).toBeInTheDocument();

		await vi.advanceTimersByTimeAsync(4999);
		expect(within(polite(container)).getByText('Sessão encerrada.')).toBeInTheDocument();

		await vi.advanceTimersByTimeAsync(1);
		flushSync();
		await vi.advanceTimersByTimeAsync(50);
		expect(within(polite(container)).queryByText('Sessão encerrada.')).not.toBeInTheDocument();
	});

	it('exibe o erro com role=alert e "Erro:" escrito, e só o remove com "Fechar"', async () => {
		render(Toaster);

		notifyError('Falha ao salvar.');
		flushSync();
		const alert = screen.getByRole('alert');
		expect(within(alert).getByText('Erro:')).toBeInTheDocument();
		expect(within(alert).getByText('Falha ao salvar.')).toBeInTheDocument();

		await vi.advanceTimersByTimeAsync(60_000);
		expect(within(alert).getByText('Falha ao salvar.')).toBeInTheDocument();

		await fireEvent.click(within(alert).getByRole('button', { name: 'Fechar' }));
		await vi.advanceTimersByTimeAsync(50);
		expect(within(alert).queryByText('Falha ao salvar.')).not.toBeInTheDocument();
	});

	it('não move o foco ao emitir mensagens', () => {
		const button = document.createElement('button');
		document.body.append(button);
		button.focus();
		render(Toaster);

		notifySuccess('Ok');
		notifyError('Falha');
		flushSync();

		expect(document.activeElement).toBe(button);
		button.remove();
	});
});
