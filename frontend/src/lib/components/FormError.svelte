<script lang="ts">
	import type { Snippet } from 'svelte';

	let { children }: { children: Snippet } = $props();

	let block: HTMLDivElement | undefined;

	export function focus() {
		block?.focus();
	}
</script>

<div bind:this={block} tabindex="-1" role="alert" class="form-error">
	<strong>Erro:</strong>
	{@render children()}
</div>

<style>
	.form-error {
		padding: var(--space-2) var(--space-3);
		border: 1px solid var(--danger);
		border-radius: var(--radius-md);
		background: var(--surface-raised);
		color: var(--ink);
		overflow-wrap: anywhere;
	}
</style>
