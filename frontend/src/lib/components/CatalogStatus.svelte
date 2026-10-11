<script module lang="ts">
	export const statusSentence = (total: number, chipCount: number) =>
		`${total} ${total === 1 ? 'carta' : 'cartas'}` +
		(chipCount > 0 ? ` · ${chipCount} ${chipCount === 1 ? 'filtro ativo' : 'filtros ativos'}` : '');
</script>

<script lang="ts">
	interface Props {
		total: number;
		chipCount: number;
		clearHref?: string;
		signInHref?: string;
	}

	let { total, chipCount, clearHref, signInHref }: Props = $props();

	let sentenceEl: HTMLParagraphElement | undefined;

	export function focus() {
		sentenceEl?.focus();
	}

	const sentence = $derived(statusSentence(total, chipCount));
</script>

<div class="status">
	<p bind:this={sentenceEl} tabindex="-1">{sentence}</p>
	{#if clearHref || signInHref}
		<div class="links">
			{#if clearHref}
				<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- href já vem resolvido pelo chamador -->
				<a href={clearHref} data-sveltekit-reset="false">Limpar filtros</a>
			{/if}
			{#if signInHref}
				<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- href já vem resolvido pelo chamador -->
				<a href={signInHref}>Entrar para registrar posse</a>
			{/if}
		</div>
	{/if}
</div>

<style>
	.status {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		justify-content: space-between;
		gap: var(--space-1) var(--space-3);
	}

	p {
		margin: 0;
	}

	.links {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-1) var(--space-3);
	}

	a {
		display: inline-flex;
		align-items: center;
		min-block-size: var(--touch-target);
		color: var(--accent);
	}
</style>
