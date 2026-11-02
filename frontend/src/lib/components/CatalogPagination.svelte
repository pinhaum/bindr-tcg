<script lang="ts">
	import type { CatalogMeta } from '../api/types';
	import { pageHref } from '../catalog/url';
	import { isPlainClick } from '../plain-click';

	interface Props {
		meta: CatalogMeta;
		onpage: () => void;
	}

	let { meta, onpage }: Props = $props();

	function handleClick(event: MouseEvent) {
		if (isPlainClick(event)) onpage();
	}
</script>

{#if meta.total_pages > 1}
	<nav aria-label="Paginação do catálogo">
		{#if meta.page > 1}
			<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- href já vem resolvido por pageHref -->
			<a href={pageHref(meta.active_filters, meta.page - 1)}
				rel="prev"
				data-sveltekit-reset="false"
				onclick={handleClick}>Anterior</a
			>
		{/if}
		<span>Página {meta.page} de {meta.total_pages}</span>
		{#if meta.page < meta.total_pages}
			<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- href já vem resolvido por pageHref -->
			<a href={pageHref(meta.active_filters, meta.page + 1)}
				rel="next"
				data-sveltekit-reset="false"
				onclick={handleClick}>Próxima</a
			>
		{/if}
	</nav>
{/if}

<style>
	nav {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		justify-content: center;
		gap: var(--space-1) var(--space-3);
	}

	a {
		display: inline-flex;
		align-items: center;
		min-block-size: var(--touch-target);
		color: var(--accent);
	}
</style>
