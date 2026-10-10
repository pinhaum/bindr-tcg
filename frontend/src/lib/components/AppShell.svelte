<script lang="ts">
	import type { Snippet } from 'svelte';
	import MainNav from './MainNav.svelte';
	import ThemeSelect from './ThemeSelect.svelte';

	let { children }: { children: Snippet } = $props();
</script>

<a class="skip-link" href="#conteudo">Ir para o conteúdo</a>

<div class="shell">
	<header class="brand">
		<strong>Bindr</strong>
		<ThemeSelect />
	</header>
	<div class="nav">
		<MainNav />
	</div>
	<main id="conteudo" tabindex="-1">
		{@render children()}
	</main>
</div>

<style>
	.skip-link {
		position: absolute;
		inset-block-start: var(--space-2);
		inset-inline-start: var(--space-2);
		z-index: 1;
		padding: var(--space-2) var(--space-3);
		border-radius: var(--radius-md);
		background: var(--surface-raised);
		color: var(--ink);
		transform: translateY(-200%);
	}

	.skip-link:focus {
		transform: none;
	}

	main:focus {
		outline: none;
	}

	.shell {
		display: grid;
		grid-template-areas:
			'brand'
			'main'
			'nav';
		grid-template-rows: auto 1fr auto;
		min-height: 100dvh;
	}

	.brand {
		grid-area: brand;
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: var(--space-3);
		padding: var(--space-2) var(--space-3);
	}

	.nav {
		grid-area: nav;
		position: fixed;
		inset: auto 0 0 0;
		display: flex;
		justify-content: center;
		box-sizing: border-box;
		min-height: calc(var(--nav-height) + env(safe-area-inset-bottom));
		padding-bottom: env(safe-area-inset-bottom);
		background: var(--surface-raised);
		border-top: 1px solid var(--border);
	}

	.nav :global(nav),
	.nav :global(ul) {
		inline-size: 100%;
	}

	main {
		grid-area: main;
		padding: var(--space-3);
		padding-bottom: calc(var(--nav-height) + env(safe-area-inset-bottom));
	}

	@media (min-width: 64rem) {
		.shell {
			grid-template-areas:
				'brand main'
				'nav main';
			grid-template-columns: var(--sidebar-width) 1fr;
			grid-template-rows: auto 1fr;
		}

		.brand,
		.nav {
			background: var(--surface-raised);
			border-right: 1px solid var(--border);
		}

		.nav {
			position: static;
			display: block;
			border-top: 0;
			padding: var(--space-2) var(--space-3);
		}

		.nav :global(ul) {
			flex-direction: column;
		}

		main {
			padding-bottom: var(--space-3);
		}
	}
</style>
