<script lang="ts">
	import type { HTMLInputAttributes } from 'svelte/elements';

	interface Props {
		name: string;
		label: string;
		type?: HTMLInputAttributes['type'];
		autocomplete?: HTMLInputAttributes['autocomplete'];
		value?: string;
		required?: boolean;
		errors?: string[];
	}

	let {
		name,
		label,
		type = 'text',
		autocomplete,
		value = $bindable(''),
		required = false,
		errors = []
	}: Props = $props();

	const id = $derived(`field-${name}`);
	const errorsId = $derived(`${id}-errors`);
	const invalid = $derived(errors.length > 0);

	let input: HTMLInputElement | undefined;

	export function focus() {
		input?.focus();
	}
</script>

<div class="field">
	<label for={id}>{label}</label>
	<input
		bind:this={input}
		bind:value
		{id}
		{name}
		{type}
		{autocomplete}
		{required}
		aria-invalid={invalid ? 'true' : undefined}
		aria-describedby={invalid ? errorsId : undefined}
	/>
	{#if invalid}
		<ul id={errorsId} class="errors">
			{#each errors as message, index (index)}
				<li>{message}</li>
			{/each}
		</ul>
	{/if}
</div>

<style>
	.field {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	label {
		color: var(--ink);
		font-weight: 600;
	}

	input {
		box-sizing: border-box;
		min-block-size: var(--touch-target);
		padding-inline: var(--space-3);
		border: 1px solid var(--border-strong);
		border-radius: var(--radius-sm);
		background: var(--surface-sunken);
		color: var(--ink);
		font: inherit;
	}

	input[aria-invalid='true'] {
		border-width: 2px;
		border-color: var(--danger);
		padding-inline: calc(var(--space-3) - 1px);
	}

	.errors {
		margin: 0;
		padding: 0;
		list-style: none;
		color: var(--danger);
	}
</style>
