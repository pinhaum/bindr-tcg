<script lang="ts">
	import { tick, type Snippet } from 'svelte';
	import { ApiError } from '../api/errors';
	import Button from './Button.svelte';
	import FormError from './FormError.svelte';
	import TextField from './TextField.svelte';

	interface Props {
		initialName?: string;
		submit: (name: string) => Promise<void>;
		children: Snippet;
	}

	let { initialName = '', submit, children }: Props = $props();

	// svelte-ignore state_referenced_locally
	let name = $state(initialName);
	let pending = $state(false);
	let formError = $state<string | null>(null);
	let nameErrors = $state<string[]>([]);
	let formErrorBlock: FormError | undefined = $state();
	let field: TextField | undefined = $state();

	function distribute(error: ApiError) {
		const { name: own = [], ...others } = error.fields;
		const rest = Object.entries(others).flatMap(([key, messages]) =>
			messages.map((message) => (key === 'base' ? message : `${key}: ${message}`))
		);
		nameErrors = own;
		formError = rest.length > 0 ? rest.join(' ') : own.length > 0 ? null : error.message;
	}

	async function onsubmit(event: SubmitEvent) {
		event.preventDefault();
		if (pending) return;
		pending = true;
		formError = null;
		nameErrors = [];
		try {
			await submit(name);
		} catch (error) {
			if (!(error instanceof ApiError)) throw error;
			if (error.code === 'validation_failed') distribute(error);
			else formError = error.message;
			await tick();
			if (nameErrors.length > 0) field?.focus();
			else formErrorBlock?.focus();
		} finally {
			pending = false;
		}
	}
</script>

<form {onsubmit}>
	{#if formError}
		<FormError bind:this={formErrorBlock}>{formError}</FormError>
	{/if}
	<TextField
		bind:this={field}
		name="name"
		label="Nome do deck (até 60 caracteres)"
		autocomplete="off"
		bind:value={name}
		errors={nameErrors}
		maxlength={60}
		required
	/>
	<Button {pending}>{@render children()}</Button>
</form>

<style>
	form {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
		max-inline-size: 28rem;
	}
</style>
