<script lang="ts">
	import type { ImportSummary } from '../api/types';
	import {
		failureSentence,
		rejectedSentence,
		removedSentence,
		unchangedSentence
	} from '../imports/groups';
	import { appPath } from '../navigation/nav-entries';

	let { summary }: { summary: ImportSummary } = $props();

	let heading: HTMLHeadingElement | undefined = $state();

	const stats = $derived([
		{
			label: 'Importadas',
			value: summary.created,
			support: 'Variantes que não estavam na sua coleção e passaram a estar.'
		},
		{
			label: 'Atualizadas',
			value: summary.updated,
			support: 'Variantes que já estavam na sua coleção e tiveram a quantidade substituída.'
		},
		{
			label: 'Recusadas',
			value: summary.rejected.length,
			support: 'Linhas do arquivo que não foram aplicadas.'
		}
	]);

	export function focus() {
		heading?.focus();
	}
</script>

<section class="summary">
	<h1 bind:this={heading} tabindex="-1">Importação concluída</h1>
	<p>Arquivo: {summary.filename} — sua coleção foi atualizada.</p>

	<ul class="stats">
		{#each stats as stat (stat.label)}
			<li class="stat">
				<span class="value">{stat.value}</span>
				<span class="label">{stat.label}</span>
				<span class="support">{stat.support}</span>
			</li>
		{/each}
	</ul>

	{#if summary.removed > 0}
		<p>{removedSentence(summary.removed)}</p>
	{/if}
	{#if summary.unchanged > 0}
		<p>{unchangedSentence(summary.unchanged)}</p>
	{/if}

	{#if summary.rejected.length > 0}
		<div class="block">
			<p>{rejectedSentence(summary.rejected.length)}</p>
			<ul>
				{#each summary.rejected as row (row.line)}
					<li>
						<code>{row.card_number}</code>
						<code>{row.variant_code}</code>
						{row.card_name}
						<span>Linha {row.line} do arquivo</span>
						<span>{row.message}</span>
					</li>
				{/each}
			</ul>
		</div>
	{/if}

	{#if summary.failures.length > 0}
		<div class="block">
			<p>{failureSentence(summary.failures.length)}</p>
			<ul>
				{#each summary.failures as row (row.line)}
					<li>Linha {row.line} do arquivo — {row.card_number} {row.variant_code}</li>
				{/each}
			</ul>
		</div>
	{/if}

	<p class="links">
		<!-- eslint-disable svelte/no-navigation-without-resolve -- href já vem de appPath, que usa resolve('/') -->
		<a href={appPath('/pasta')}>Ver minha coleção</a>
		<a href={appPath('/pasta/importar')}>importar outro arquivo</a>
		<!-- eslint-enable svelte/no-navigation-without-resolve -->
	</p>
</section>

<style>
	.summary {
		display: grid;
		gap: var(--space-3);
	}

	h1:focus-visible {
		outline: 2px solid var(--focus-ring, currentColor);
		outline-offset: 2px;
	}

	.stats {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(14rem, 1fr));
		gap: var(--space-3);
		margin: 0;
		padding: 0;
		list-style: none;
	}

	.stat {
		display: grid;
		gap: var(--space-1);
		padding: var(--space-3);
		border: 1px solid var(--border);
		border-radius: var(--radius-md);
		background: var(--surface-raised);
	}

	.value {
		font-size: 2rem;
		font-weight: 700;
	}

	.support {
		color: var(--ink-muted);
	}

	.block ul {
		display: grid;
		gap: var(--space-2);
		padding-left: var(--space-4);
		overflow-wrap: anywhere;
	}

	.links {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-3);
	}
</style>
