<script lang="ts">
	import type { ProgressSet } from '../api/types';
	import { formatPrice } from '../format';
	import { appPath } from '../navigation/nav-entries';

	interface Props {
		set: ProgressSet;
	}

	let { set }: Props = $props();

	const href = $derived(appPath('?sets[]=' + encodeURIComponent(set.code)));
	const parallels = $derived(
		`${set.parallel_owned} de ${set.parallel_total} ${set.parallel_total === 1 ? 'parallel' : 'parallels'}`
	);
</script>

<div class="row">
	<div class="head">
		<code>{set.code}</code>
		<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- href parte de appPath -->
		<a {href} aria-label={`${set.name} (${set.code}): ver no catálogo`}>{set.name}</a>
		{#if set.base_size !== null}
			<span class="numbers">{set.owned_numbers} / {set.base_size} · {set.completion_percent}%</span>
		{:else}
			<span class="numbers">{set.owned_numbers}</span>
		{/if}
	</div>
	{#if set.base_size !== null}
		<progress aria-hidden="true" value={set.owned_numbers} max={set.base_size}></progress>
		<p>{set.owned_numbers} de {set.base_size} do set base</p>
	{:else}
		<p>Percentual indisponível: este set não informa o tamanho do set base.</p>
	{/if}
	<p>{parallels}</p>
	<p>valor {formatPrice(set.value.amount, set.value.currency)}</p>
</div>

<style>
	.row {
		display: grid;
		gap: var(--space-1);
		padding-block: var(--space-2);
	}

	.head {
		display: flex;
		flex-wrap: wrap;
		align-items: baseline;
		gap: var(--space-2);
	}

	code {
		font-family: var(--font-mono);
		font-size: var(--code-size);
		line-height: var(--code-line-height);
		font-weight: var(--code-weight);
	}

	.numbers {
		margin-inline-start: auto;
	}

	progress {
		inline-size: 100%;
		accent-color: var(--accent);
	}

	p {
		margin: 0;
	}
</style>
