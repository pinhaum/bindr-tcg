import '@testing-library/jest-dom/vitest';
import { cleanup, fireEvent, render, screen } from '@testing-library/svelte';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiError } from '../api/errors';
import type { OwnershipOp } from '../cards/ownership-queue.svelte';
import { toasts } from '../toasts.svelte';
import QuantityStepper from './QuantityStepper.svelte';

type Deferred = { op: OwnershipOp; resolve: (q: number) => void; reject: (e: unknown) => void };

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

function setup(confirmed = 0) {
	const calls: Deferred[] = [];
	const send = vi.fn(
		(op: OwnershipOp) =>
			new Promise<number>((resolve, reject) => {
				calls.push({ op, resolve, reject });
			})
	);
	const view = render(QuantityStepper, {
		confirmed,
		send,
		decrementLabel: 'Tirar um deck',
		incrementLabel: 'Pôr um deck',
		refusedMessage: 'Nada a tirar.',
		quantityText: (q: number) => `${q} no deck`,
		settledText: (q: number) => `fechou em ${q}`
	});
	const remove = () => screen.getByRole('button', { name: 'Tirar um deck' });
	const add = () => screen.getByRole('button', { name: 'Pôr um deck' });
	const live = () => view.container.querySelector<HTMLElement>('[aria-live="polite"]')!;
	return { calls, send, remove, add, live, view };
}

describe('QuantityStepper', () => {
	beforeEach(() => toasts.splice(0));
	afterEach(() => {
		cleanup();
		toasts.splice(0);
	});

	it('usa rótulos e textos vindos das props', () => {
		const { remove, add, view } = setup(2);

		expect(remove()).toBeInTheDocument();
		expect(add()).toBeInTheDocument();
		expect(view.container.querySelector('.quantity')).toHaveTextContent('2 no deck');
	});

	it('em zero o − é focável, aria-disabled, não envia e anuncia a recusa', async () => {
		const { remove, send, live } = setup(0);

		expect(remove()).toHaveAttribute('aria-disabled', 'true');
		expect(remove()).not.toHaveAttribute('disabled');
		remove().focus();
		await fireEvent.click(remove());
		await flush();

		expect(remove()).toHaveFocus();
		expect(send).not.toHaveBeenCalled();
		expect(live()).toHaveTextContent('Nada a tirar.');
	});

	it('cinco + rápidos mostram 1..5 e enviam cinco vezes, em série', async () => {
		const { add, calls, send, view } = setup(0);
		const step = () => view.container.querySelector('.step')!;

		for (let i = 1; i <= 5; i++) {
			await fireEvent.click(add());
			expect(step()).toHaveTextContent(String(i));
		}
		expect(send).toHaveBeenCalledTimes(1);

		for (let i = 1; i <= 5; i++) {
			calls[i - 1].resolve(i);
			await flush();
		}

		expect(send).toHaveBeenCalledTimes(5);
		expect(step()).toHaveTextContent('5');
	});

	it('falha no 3º volta ao confirmado e chama o erro', async () => {
		const { add, calls, send, view } = setup(0);
		const step = () => view.container.querySelector('.step')!;

		for (let i = 0; i < 5; i++) await fireEvent.click(add());
		calls[0].resolve(1);
		await flush();
		calls[1].resolve(2);
		await flush();
		calls[2].reject(new ApiError(422, 'validation_failed', 'Recusado pelo servidor.'));
		await flush();

		expect(send).toHaveBeenCalledTimes(3);
		expect(step()).toHaveTextContent('2');
		expect(toasts.map((t) => t.message)).toEqual(['Recusado pelo servidor.']);
	});
});
