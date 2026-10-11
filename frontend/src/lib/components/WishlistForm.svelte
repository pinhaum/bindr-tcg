<script lang="ts">
	import { tick } from 'svelte';
	import { api } from '../api';
	import { ApiError } from '../api/errors';
	import type { WishlistResult } from '../api/types';
	import { variantApiPath } from '../cards/url';
	import { notifyError, notifySuccess } from '../toasts.svelte';
	import Button from './Button.svelte';

	interface Props {
		cardNumber: string;
		cardName: string;
		variantCode: string;
		target: number | null;
	}

	let { cardNumber, cardName, variantCode, target }: Props = $props();

	let quantity = $derived(target);
	let saved = $derived(target);
	let pending = $state(false);
	let errors = $state<string[]>([]);
	let input: HTMLInputElement | undefined;

	const id = $derived(`wishlist-${variantCode}`);
	const errorsId = $derived(`${id}-errors`);
	const invalid = $derived(errors.length > 0);
	const label = $derived(`${cardName} ${variantCode}`);

	async function onsubmit(event: SubmitEvent) {
		event.preventDefault();
		if (pending) return;
		pending = true;
		errors = [];
		try {
			const result = await api.put<WishlistResult>(variantApiPath(cardNumber, variantCode, 'wishlist'), {
				target_quantity: quantity
			});
			saved = result.wishlist_target;
			quantity = result.wishlist_target;
			notifySuccess(
				`${label} na lista de desejos: ${saved} ${saved === 1 ? 'cópia' : 'cópias'}.`
			);
		} catch (error) {
			if (!(error instanceof ApiError)) throw error;
			const messages = error.code === 'validation_failed' ? error.fields.target_quantity : undefined;
			if (messages?.length) {
				errors = messages;
				await tick();
				input?.focus();
			} else {
				notifyError(error.message);
			}
		} finally {
			pending = false;
		}
	}
</script>

<form {onsubmit} novalidate>
	<div role="group" aria-label="Marcar {label} como desejada">
		<label for={id}>Quero</label>
		<input
			bind:this={input}
			bind:value={quantity}
			{id}
			type="number"
			min="1"
			step="1"
			aria-invalid={invalid ? 'true' : undefined}
			aria-describedby={invalid ? errorsId : undefined}
		/>
		{#if invalid}
			<ul id={errorsId} class="errors" role="alert">
				{#each errors as message, index (index)}
					<li>{message}</li>
				{/each}
			</ul>
		{/if}
		<Button {pending} variant="secondary">{saved === null ? 'Quero esta' : 'Atualizar desejo'}</Button>
	</div>
</form>

<style>
	[role='group'] {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		gap: var(--space-2);
	}

	label {
		color: var(--ink);
		font-weight: 600;
	}

	input {
		box-sizing: border-box;
		min-block-size: var(--touch-target);
		inline-size: 5rem;
		padding-inline: var(--space-3);
		border: 1px solid var(--border-strong);
		border-radius: var(--radius-sm);
		background: var(--surface-sunken);
		color: var(--ink);
		font: inherit;
	}

	input[aria-invalid='true'] {
		border-width: 2px;
		border-color: var(--danger);
		padding-inline: calc(var(--space-3) - 1px);
	}

	.errors {
		flex-basis: 100%;
		order: 1;
		margin: 0;
		padding: 0;
		list-style: none;
		color: var(--danger);
	}
</style>
