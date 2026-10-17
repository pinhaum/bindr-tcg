<script lang="ts">
	import type { Chip } from '../catalog/url';
	import { isPlainClick } from '../plain-click';
	import FilterChip from './FilterChip.svelte';

	interface Props {
		chips: Chip[];
		onremove: (index: number) => void;
	}

	let { chips, onremove }: Props = $props();
</script>

{#if chips.length > 0}
	<ul aria-label="Filtros ativos">
		{#each chips as chip, index (chip.key + chip.value)}
			<li>
				<FilterChip
					href={chip.href}
					label={chip.text}
					active
					removeName={`Remover filtro ${chip.text}`}
					onclick={(event) => {
						if (isPlainClick(event)) onremove(index);
					}}
				/>
			</li>
		{/each}
	</ul>
{/if}

<style>
	ul {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-1);
		margin: 0;
		padding: 0;
		list-style: none;
	}
</style>
