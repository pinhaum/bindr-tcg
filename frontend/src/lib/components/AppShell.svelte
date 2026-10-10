<script lang="ts">
	import type { Snippet } from 'svelte';
	import MainNav from './MainNav.svelte';
	import ThemeSelect from './ThemeSelect.svelte';

	let { children }: { children: Snippet } = $props();
</script>

<div class="shell">
	<header class="brand">
		<strong>Bindr</strong>
		<ThemeSelect />
	</header>
	<div class="nav">
		<MainNav />
	</div>
	<main>
		{@render children()}
	</main>
</div>

<style>
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
		min-height: var(--nav-height);
		padding-bottom: env(safe-area-inset-bottom);
		background: var(--surface-raised);
		border-top: 1px solid var(--border);
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
