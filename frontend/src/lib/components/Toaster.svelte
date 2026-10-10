<script lang="ts">
	import { fly } from 'svelte/transition';
	import { duration } from '../motion';
	import { dismiss, toasts } from '../toasts.svelte';

	const successes = $derived(toasts.filter((toast) => toast.kind === 'success'));
	const errors = $derived(toasts.filter((toast) => toast.kind === 'error'));
</script>

<div class="layer">
	<div aria-live="polite" class="region">
		{#each successes as toast (toast.id)}
			<p class="toast success" transition:fly={{ y: 8, duration: duration(200) }}>
				{toast.message}
			</p>
		{/each}
	</div>
	<div role="alert" class="region">
		{#each errors as toast (toast.id)}
			<div class="toast error" transition:fly={{ y: 8, duration: duration(200) }}>
				<p class="message"><strong>Erro:</strong> {toast.message}</p>
				<button type="button" onclick={() => dismiss(toast.id)}>Fechar</button>
			</div>
		{/each}
	</div>
</div>

<style>
	.layer {
		position: fixed;
		inset-inline: var(--space-3);
		bottom: calc(var(--nav-height) + var(--space-3));
		z-index: 100;
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		pointer-events: none;
	}

	.region {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.toast {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: var(--space-3);
		margin: 0;
		padding: var(--space-2) var(--space-3);
		border: 1px solid var(--border-strong);
		border-radius: var(--radius-md);
		background: var(--surface-raised);
		color: var(--ink);
		font-size: var(--body-size);
		line-height: var(--body-line-height);
		pointer-events: auto;
	}

	.error {
		border-color: var(--danger);
	}

	.message {
		margin: 0;
	}

	button {
		min-block-size: var(--touch-target);
		min-inline-size: var(--touch-target);
		padding-inline: var(--space-3);
		border: 1px solid var(--border-strong);
		border-radius: var(--radius-sm);
		background: transparent;
		color: var(--ink);
		font: inherit;
		cursor: pointer;
	}

	@media (min-width: 768px) {
		.layer {
			inset-inline: auto var(--space-4);
			bottom: var(--space-4);
			inline-size: 24rem;
		}
	}
</style>
