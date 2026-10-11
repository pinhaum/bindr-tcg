<script lang="ts">
	import { tick, untrack } from 'svelte';
	import { ApiError } from '../api/errors';
	import { copies } from '../format';
	import {
		createOwnershipQueue,
		type OwnershipOp,
		type OwnershipResult
	} from '../cards/ownership-queue.svelte';
	import { notifyError } from '../toasts.svelte';

	interface Props {
		name: string;
		variantCode: string;
		confirmed: number;
		send: (op: OwnershipOp) => Promise<OwnershipResult>;
		displayed?: number;
	}

	const NOTHING_TO_REMOVE = 'Você não tem cópias desta variante para remover.';
	const UNEXPECTED_ERROR = 'Algo deu errado. Tente novamente.';

	// eslint-disable-next-line @typescript-eslint/no-unused-vars, no-useless-assignment -- só escrita: o pai lê via bind
	let { name, variantCode, confirmed, send, displayed = $bindable() }: Props = $props();

	let announcement = $state('');

	const quantityText = (quantity: number) => (quantity === 0 ? 'não tenho' : copies(quantity));

	async function announce(message: string) {
		announcement = '';
		await tick();
		announcement = message;
	}

	const queue = createOwnershipQueue({
		confirmed: untrack(() => confirmed),
		send: (op) => send(op),
		onSettled: (quantity) => announce(`${quantityText(quantity)} ${name} ${variantCode}`),
		onError: (error) => notifyError(error instanceof ApiError ? error.message : UNEXPECTED_ERROR)
	});

	$effect.pre(() => {
		displayed = queue.displayed;
	});

	$effect(() => () => queue.discard());

	function tap(op: OwnershipOp) {
		if (queue.tap(op) === 'refused') announce(NOTHING_TO_REMOVE);
	}
</script>

<div class="ownership">
	<p class="quantity" class:empty={queue.displayed === 0}>{quantityText(queue.displayed)}</p>

	<div class="actions">
		<button
			type="button"
			aria-label="Remover uma cópia de {name} {variantCode}"
			aria-disabled={queue.displayed === 0 ? 'true' : undefined}
			onclick={() => tap('decrement')}
		>
			<span aria-hidden="true">&minus;</span>
		</button>
		<span class="step" aria-hidden="true">{queue.displayed}</span>
		<button
			type="button"
			aria-label="Adicionar uma cópia de {name} {variantCode}"
			onclick={() => tap('increment')}
		>
			<span aria-hidden="true">+</span>
		</button>
	</div>

	<p class="visually-hidden" aria-live="polite" aria-atomic="true">{announcement}</p>
</div>

<style>
	.ownership {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		gap: var(--space-2) var(--space-3);
	}

	.quantity {
		margin: 0;
		font-weight: 600;
	}

	.quantity.empty {
		color: var(--ink-muted);
		font-weight: 400;
	}

	.actions {
		display: inline-flex;
		align-items: center;
		gap: var(--space-2);
	}

	.step {
		min-inline-size: var(--space-4);
		text-align: center;
		font-variant-numeric: tabular-nums;
	}

	button {
		min-block-size: var(--touch-target);
		min-inline-size: var(--touch-target);
		border: 1px solid var(--border-strong);
		border-radius: var(--radius-sm);
		background: transparent;
		color: var(--ink);
		font: inherit;
		font-weight: 600;
		cursor: pointer;
	}

	button[aria-disabled='true'] {
		opacity: 0.6;
		cursor: not-allowed;
	}
</style>
