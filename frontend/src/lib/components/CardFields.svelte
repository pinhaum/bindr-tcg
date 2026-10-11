<script lang="ts">
	import type { CatalogCard } from '../api/types';

	let { card }: { card: CatalogCard } = $props();

	const FIELDS_BY_TYPE: Record<string, string[]> = {
		Leader: ['power', 'life', 'attribute', 'traits', 'block'],
		Character: ['cost', 'power', 'counter', 'attribute', 'traits', 'block'],
		Event: ['cost', 'attribute', 'traits', 'block'],
		Stage: ['cost', 'attribute', 'traits', 'block']
	};

	const fields = $derived.by(() => {
		const values: Record<string, { label: string; value: number | string[] | null }> = {
			cost: { label: 'Custo', value: card.cost },
			power: { label: 'Power', value: card.power },
			life: { label: 'Life', value: card.life },
			counter: { label: 'Counter', value: card.counter },
			attribute: { label: 'Attribute', value: card.attributes },
			traits: { label: 'Traits', value: card.traits },
			block: { label: 'Block', value: card.block_icon }
		};
		return (FIELDS_BY_TYPE[card.card_type] ?? [])
			.map((key) => ({ key, ...values[key] }))
			.filter(({ value }) => (Array.isArray(value) ? value.length > 0 : value !== null))
			.map(({ key, label, value }) => ({
				key,
				label,
				text: Array.isArray(value) ? value.join(', ') : String(value)
			}));
	});
</script>

{#if fields.length > 0}
	<dl class="fields">
		{#each fields as field (field.key)}
			<div class="field">
				<dt>{field.label}</dt>
				<dd>{field.text}</dd>
			</div>
		{/each}
	</dl>
{/if}

{#if card.effect_text || card.trigger_text}
	<section class="effect">
		<h2>Efeito</h2>
		{#if card.effect_text}
			<p class="effect-text">{card.effect_text}</p>
		{/if}
		{#if card.trigger_text}
			<p class="trigger-label"><strong>Trigger</strong></p>
			<p class="effect-text">{card.trigger_text}</p>
		{/if}
	</section>
{/if}

<style>
	.fields {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(8rem, 1fr));
		gap: var(--space-3);
		margin: 0;
	}

	dt {
		color: var(--ink-muted);
	}

	dd {
		margin: 0;
		color: var(--ink);
		overflow-wrap: anywhere;
	}

	.effect {
		margin-block-start: var(--space-4);
	}

	.effect h2 {
		margin: 0 0 var(--space-2);
	}

	.effect-text,
	.trigger-label {
		margin: 0 0 var(--space-2);
	}

	.effect-text {
		white-space: pre-line;
		overflow-wrap: anywhere;
	}
</style>
