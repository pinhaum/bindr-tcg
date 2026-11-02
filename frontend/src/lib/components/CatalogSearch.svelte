<script lang="ts">
	import Button from './Button.svelte';

	interface Props {
		value: string;
		onsearch: (term: string) => void;
	}

	let { value, onsearch }: Props = $props();

	let term = $derived(value);

	function submit(event: SubmitEvent) {
		event.preventDefault();
		onsearch(term);
	}
</script>

<form role="search" onsubmit={submit}>
	<label for="catalog-search">Buscar por nome ou card_number</label>
	<div class="row">
		<input
			id="catalog-search"
			name="q"
			type="search"
			placeholder="OP01-024"
			autocomplete="off"
			bind:value={term}
		/>
		<Button>Buscar</Button>
	</div>
</form>

<style>
	form {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	label {
		color: var(--ink);
		font-weight: 600;
	}

	.row {
		display: flex;
		gap: var(--space-2);
	}

	input {
		box-sizing: border-box;
		flex: 1;
		min-inline-size: 0;
		min-block-size: var(--touch-target);
		padding-inline: var(--space-3);
		border: 1px solid var(--border-strong);
		border-radius: var(--radius-sm);
		background: var(--surface-sunken);
		color: var(--ink);
		font: inherit;
	}
</style>
