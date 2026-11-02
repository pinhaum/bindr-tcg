<script lang="ts">
	import { page } from '$app/state';
	import { ApiError } from '../api/errors';
	import { navEntries } from '../navigation/nav-entries';
	import { session, signOut } from '../session.svelte';
	import { notifyError } from '../toasts.svelte';

	const entries = $derived(navEntries(session.user));

	const trimSlash = (path: string) => (path.length > 1 ? path.replace(/\/+$/, '') : path);
	const isCurrent = (href: string) => trimSlash(page.url.pathname) === trimSlash(href);

	async function leave() {
		try {
			await signOut();
		} catch (error) {
			if (error instanceof ApiError) notifyError(error.message);
			else throw error;
		}
	}
</script>

<nav aria-label="Principal">
	<ul>
		{#each entries as entry (entry.label)}
			<li>
				{#if entry.kind === 'action'}
					<button type="button" onclick={leave}>{entry.label}</button>
				{:else if entry.reload}
					<a href={entry.href} rel="external" data-sveltekit-reload>{entry.label}</a>
				{:else}
					<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- href já vem de resolve('/') em nav-entries -->
					<a href={entry.href} aria-current={isCurrent(entry.href) ? 'page' : undefined}>{entry.label}</a
					>
				{/if}
			</li>
		{/each}
	</ul>
</nav>

<style>
	ul {
		display: flex;
		gap: var(--space-2);
		margin: 0;
		padding: 0;
		list-style: none;
	}

	li {
		flex: 1 1 0;
		min-inline-size: 0;
	}

	a,
	button {
		box-sizing: border-box;
		inline-size: 100%;
		text-align: center;
		display: inline-flex;
		align-items: center;
		justify-content: center;
		min-height: var(--touch-target);
		min-width: 0;
		overflow-wrap: anywhere;
		padding: 0 var(--space-3);
		border: 0;
		border-block-end: 2px solid transparent;
		border-radius: var(--radius-md);
		background: transparent;
		color: inherit;
		font: inherit;
		text-decoration: none;
		cursor: pointer;
	}

	a[aria-current='page'] {
		border-block-end-color: var(--accent);
		background: var(--surface-sunken);
		font-weight: var(--nav-current-weight);
	}
</style>
