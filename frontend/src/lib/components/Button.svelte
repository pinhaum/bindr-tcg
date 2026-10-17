<script lang="ts">
	import type { Snippet } from 'svelte';

	interface Props {
		children: Snippet;
		pending?: boolean;
		variant?: 'primary' | 'secondary';
		type?: 'submit' | 'button';
	}

	let { children, pending = false, variant = 'primary', type = 'submit' }: Props = $props();
</script>

<button {type} class={variant} disabled={pending} aria-busy={pending ? 'true' : undefined}>
	{@render children()}
</button>

<style>
	button {
		min-block-size: var(--touch-target);
		min-inline-size: var(--touch-target);
		padding-inline: var(--space-3);
		border: 1px solid var(--border-strong);
		border-radius: var(--radius-sm);
		font: inherit;
		font-weight: 600;
		cursor: pointer;
	}

	.primary {
		border-color: var(--accent);
		background: var(--accent);
		color: var(--on-accent);
	}

	.secondary {
		background: transparent;
		color: var(--ink);
	}

	button:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}
</style>
