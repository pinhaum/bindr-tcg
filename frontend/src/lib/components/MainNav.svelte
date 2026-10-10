<script lang="ts">
	import { page } from '$app/state';
	import { ApiError } from '../api/errors';
	import { navEntries } from '../navigation/nav-entries';
	import { session, signOut } from '../session.svelte';
	import { notifyError } from '../toasts.svelte';

	const entries = $derived(navEntries(session.user));

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
					<a href={entry.href} aria-current={page.url.pathname === entry.href ? 'page' : undefined}
						>{entry.label}</a
					>
				{/if}
			</li>
		{/each}
	</ul>
</nav>

<style>
	ul {
		display: flex;
		gap: var(--space-2, 0.5rem);
		margin: 0;
		padding: 0;
		list-style: none;
	}

	a,
	button {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		min-height: 44px;
		min-width: 44px;
		padding: 0 var(--space-3, 0.75rem);
		border: 0;
		border-radius: var(--radius-md, 0.5rem);
		background: transparent;
		color: inherit;
		font: inherit;
		text-decoration: none;
		cursor: pointer;
	}

	a[aria-current='page'] {
		background: var(--surface-sunken);
		font-weight: var(--nav-current-weight);
	}
</style>
