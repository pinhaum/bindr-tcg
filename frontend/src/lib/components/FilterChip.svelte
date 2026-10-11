<script lang="ts">
	interface Props {
		href: string;
		label: string;
		active: boolean;
		current?: boolean;
		swatch?: boolean;
		removeName?: string;
		onclick?: (event: MouseEvent) => void;
	}

	let { href, label, active, current = false, swatch = false, removeName, onclick }: Props = $props();
</script>

<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- href já vem resolvido pelo chamador -->
<a {href}
	{onclick}
	class="chip"
	class:active
	data-sveltekit-reset="false"
	aria-current={current ? 'true' : undefined}
	aria-label={active ? removeName : undefined}
>
	{#if swatch}<span class="swatch" aria-hidden="true"></span>{/if}
	<span class="label">{label}</span>
	{#if active}<span class="remove" aria-hidden="true">×</span>{/if}
</a>

<style>
	.chip {
		display: inline-flex;
		align-items: center;
		gap: var(--space-1);
		min-block-size: var(--touch-target);
		padding-inline: var(--space-2);
		border: 1px solid var(--border-strong);
		border-radius: var(--radius-sm);
		color: var(--ink);
		text-decoration: none;
		max-inline-size: 100%;
	}

	.chip.active {
		border: 2px solid var(--accent);
	}

	.chip[aria-current='true'] {
		font-weight: var(--body-strong-weight);
	}

	.label {
		overflow-wrap: anywhere;
	}

	.swatch {
		inline-size: var(--space-3);
		block-size: var(--space-3);
		border: 1px solid var(--border-strong);
	}
</style>
