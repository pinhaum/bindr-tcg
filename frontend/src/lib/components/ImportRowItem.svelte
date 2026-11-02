<script lang="ts">
	import type { ImportRow } from '../api/types';
	import { groupRows } from '../imports/groups';

	interface Props {
		row: ImportRow;
	}

	let { row }: Props = $props();

	const label = $derived(groupRows([row])[0].label);
</script>

<div class="row {row.classification}">
	<p class="head">
		<strong class="label">{label}</strong>
		<span class="card-number">{row.card_number ?? '—'}</span>
		{#if row.variant_code}<code>{row.variant_code}</code>{:else}<span>—</span>{/if}
		<span class="name">{row.card_name ?? ''}</span>
	</p>
	<p class="line">Linha {row.line} do arquivo</p>
	{#if row.classification === 'rejected'}
		<p class="detail">{row.message ?? ''}</p>
	{:else if row.classification === 'creates'}
		<p class="detail">
			Você não tem esta variante registrada; passará a ter nova quantidade
			<strong>{row.quantity_after}</strong>.
		</p>
	{:else}
		<p class="detail">
			De quantidade atual <strong>{row.quantity_before}</strong> para nova quantidade
			<strong>{row.quantity_after}</strong>.
		</p>
	{/if}
</div>

<style>
	.row {
		display: grid;
		gap: var(--space-1);
		padding-inline-start: var(--space-2);
		border-inline-start: 3px solid var(--border-strong);
		overflow-wrap: anywhere;
	}

	.removes {
		border-inline-start-style: double;
	}

	.creates {
		border-inline-start-style: solid;
	}

	.updates {
		border-inline-start-style: dashed;
	}

	.rejected {
		border-inline-start-style: dotted;
	}

	.unchanged {
		border-inline-start-style: solid;
		border-inline-start-width: 1px;
	}

	p {
		margin: 0;
	}

	.head {
		display: flex;
		flex-wrap: wrap;
		align-items: baseline;
		gap: var(--space-1) var(--space-2);
	}

	.label {
		font-weight: var(--body-strong-weight);
		text-transform: uppercase;
	}

	.name {
		overflow-wrap: anywhere;
	}

	code {
		overflow-wrap: anywhere;
	}

	.line {
		color: var(--ink-muted);
		font-size: var(--caption-size);
	}
</style>
