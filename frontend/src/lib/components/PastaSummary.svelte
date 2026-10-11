<script lang="ts">
	import type { ProgressPayload } from '../api/types';
	import { copies, formatPrice } from '../format';
	import AnimatedNumber from './AnimatedNumber.svelte';

	interface Props {
		summary: ProgressPayload['summary'];
	}

	let { summary }: Props = $props();

	const integer = (n: number) => String(n);
	const { currency } = $derived(summary.estimated_value);
	const money = (cents: number) => formatPrice((cents / 100).toFixed(2), currency);
</script>

<div class="summary">
	<div class="card">
		<AnimatedNumber
			value={summary.total_copies}
			format={integer}
			finalText={integer(summary.total_copies)}
		/>
		<span class="label">{summary.total_copies === 1 ? 'carta na pasta' : 'cartas na pasta'}</span>
	</div>
	<div class="card">
		<AnimatedNumber
			value={summary.distinct_variants}
			format={integer}
			finalText={integer(summary.distinct_variants)}
		/>
		<span class="label">
			{summary.distinct_variants === 1 ? 'carta diferente' : 'cartas diferentes'}
		</span>
	</div>
	<div class="card">
		<AnimatedNumber
			value={Math.round(Number(summary.estimated_value.amount) * 100)}
			format={money}
			finalText={formatPrice(summary.estimated_value.amount, currency)}
		/>
		<span class="label">valor estimado</span>
		{#if summary.unpriced_copies > 0}
			<span class="note">{copies(summary.unpriced_copies)} sem preço</span>
		{/if}
	</div>
</div>

<style>
	.summary {
		display: grid;
		gap: var(--space-2);
	}

	.card {
		display: grid;
		gap: var(--space-1);
		padding: var(--space-3);
		border: 1px solid var(--border);
		background: var(--surface-raised);
		border-radius: var(--radius-md);
	}

	.label,
	.note {
		color: var(--ink-muted);
	}

	@media (min-width: 64rem) {
		.summary {
			grid-template-columns: repeat(4, 1fr);
		}
	}
</style>
