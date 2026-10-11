import '@testing-library/jest-dom/vitest';
import { cleanup, fireEvent, render, screen } from '@testing-library/svelte';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { flushSync, mount, unmount } from 'svelte';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiError } from '../api/errors';
import type { OwnershipOp } from '../cards/ownership-queue.svelte';
import { toasts } from '../toasts.svelte';
import OwnershipStepper from './OwnershipStepper.svelte';

type Deferred = {
	op: OwnershipOp;
	resolve: (quantity: number) => void;
	reject: (error: unknown) => void;
};

const NAME = 'Monkey D. Luffy';
const CODE = 'tcgplayer:12345';
const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

function setup(confirmed: number) {
	const calls: Deferred[] = [];
	const send = vi.fn(
		(op: OwnershipOp) =>
			new Promise<number>((resolve, reject) => {
				calls.push({ op, resolve, reject });
			})
	);
	const view = render(OwnershipStepper, { name: NAME, variantCode: CODE, confirmed, send });
	const remove = () => screen.getByRole('button', { name: `Remover uma cópia de ${NAME} ${CODE}` });
	const add = () => screen.getByRole('button', { name: `Adicionar uma cópia de ${NAME} ${CODE}` });
	const live = () => view.container.querySelector<HTMLElement>('[aria-live="polite"]')!;
	return { calls, send, remove, add, live, view };
}

beforeEach(() => {
	toasts.splice(0);
});

afterEach(() => {
	cleanup();
	toasts.splice(0);
});

describe('OwnershipStepper', () => {
	it.each([
		[0, 'não tenho'],
		[1, '1 cópia'],
		[3, '3 cópias']
	])('mostra a quantidade em texto com %i (SCAR-25)', (confirmed, text) => {
		const { view } = setup(confirmed);
		expect(view.container).toHaveTextContent(text);
	});

	it('mostra o [n] só como número aria-hidden entre os botões (SCAR-25)', () => {
		const { remove, add, view } = setup(3);
		const hidden = [...view.container.querySelectorAll<HTMLElement>('[aria-hidden="true"]')].find(
			(el) => el.textContent?.trim() === '3'
		);
		expect(hidden).toBeDefined();
		expect(remove().compareDocumentPosition(hidden!) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
		expect(hidden!.compareDocumentPosition(add()) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
	});

	it('usa o token de alvo de toque nos botões (SCAR-25)', () => {
		const source = readFileSync(
			resolve(process.cwd(), 'src/lib/components/QuantityStepper.svelte'),
			'utf8'
		);
		expect(source).toContain('min-block-size: var(--touch-target)');
		expect(source).toContain('min-inline-size: var(--touch-target)');
	});

	it('soma 1 antes da resposta e envia increment (SCAR-27)', async () => {
		const { add, calls, send, view } = setup(0);

		await fireEvent.click(add());

		expect(send).toHaveBeenCalledExactlyOnceWith('increment');
		expect(view.container).toHaveTextContent('1 cópia');
		expect(calls).toHaveLength(1);
	});

	it('subtrai 1 antes da resposta e envia decrement (SCAR-28)', async () => {
		const { remove, send, view } = setup(2);

		await fireEvent.click(remove());

		expect(send).toHaveBeenCalledExactlyOnceWith('decrement');
		expect(view.container).toHaveTextContent('1 cópia');
	});

	it('em zero o − fica aria-disabled, focável, sem enviar, e anuncia o motivo (SCAR-29)', async () => {
		const { remove, send, live } = setup(0);

		expect(remove()).toHaveAttribute('aria-disabled', 'true');
		expect(remove()).not.toHaveAttribute('disabled');
		remove().focus();
		await fireEvent.click(remove());

		expect(send).not.toHaveBeenCalled();
		expect(live()).toHaveTextContent('Você não tem cópias desta variante para remover.');
		expect(remove()).toHaveFocus();
	});

	it('acima de zero o − não é aria-disabled (SCAR-29)', () => {
		const { remove } = setup(1);
		expect(remove()).not.toHaveAttribute('aria-disabled', 'true');
	});

	it('anuncia a quantidade com nome e código quando a fila esvazia (SCAR-33)', async () => {
		const { add, calls, live } = setup(1);

		await fireEvent.click(add());
		expect(live()).not.toHaveTextContent(`2 cópias ${NAME} ${CODE}`);
		calls[0].resolve(2);
		await flush();

		expect(live()).toHaveTextContent(`2 cópias ${NAME} ${CODE}`);
	});

	it('anuncia "não tenho" com nome e código ao zerar (SCAR-33)', async () => {
		const { remove, calls, live } = setup(1);

		await fireEvent.click(remove());
		calls[0].resolve(0);
		await flush();

		expect(live()).toHaveTextContent(`não tenho ${NAME} ${CODE}`);
	});

	it('na falha volta ao confirmado e empurra a message do erro como toast (SCAR-32)', async () => {
		const { add, calls, view } = setup(2);

		await fireEvent.click(add());
		expect(view.container).toHaveTextContent('3 cópias');
		calls[0].reject(new ApiError(500, 'internal_error', 'Algo deu errado. Tente novamente.'));
		await flush();

		expect(view.container).toHaveTextContent('2 cópias');
		expect(toasts).toEqual([
			expect.objectContaining({ kind: 'error', message: 'Algo deu errado. Tente novamente.' })
		]);
	});

	it('mantém o foco no botão acionado e nenhum botão fica disabled (SCAR-34)', async () => {
		const { add, remove, calls } = setup(0);

		add().focus();
		await fireEvent.click(add());
		expect(add()).toHaveFocus();
		expect(add()).not.toHaveAttribute('disabled');
		expect(remove()).not.toHaveAttribute('disabled');

		calls[0].resolve(1);
		await flush();

		expect(add()).toHaveFocus();
		expect(add()).not.toHaveAttribute('disabled');
		expect(remove()).not.toHaveAttribute('disabled');
	});

	it('reflete a quantidade exibida na prop vinculável displayed', async () => {
		let displayed = 0;
		const target = document.body.appendChild(document.createElement('div'));
		const send = vi.fn(() => new Promise<number>(() => {}));
		const component = mount(OwnershipStepper, {
			target,
			props: {
				name: NAME,
				variantCode: CODE,
				confirmed: 2,
				send,
				get displayed() {
					return displayed;
				},
				set displayed(value: number) {
					displayed = value;
				}
			}
		});
		flushSync();
		expect(displayed).toBe(2);

		await fireEvent.click(screen.getByRole('button', { name: `Adicionar uma cópia de ${NAME} ${CODE}` }));
		flushSync();

		expect(displayed).toBe(3);
		unmount(component);
		target.remove();
	});
});
