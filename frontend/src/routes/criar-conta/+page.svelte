<script lang="ts">
	import { goto } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import { tick } from 'svelte';
	import { ApiError } from '../../lib/api/errors';
	import Button from '../../lib/components/Button.svelte';
	import FormError from '../../lib/components/FormError.svelte';
	import TextField from '../../lib/components/TextField.svelte';
	import { safeReturnTo } from '../../lib/navigation/return-to';
	import { signUp } from '../../lib/session.svelte';

	const FIELD_ORDER = ['email', 'password', 'password_confirmation'] as const;
	type FieldName = (typeof FIELD_ORDER)[number];

	let email = $state('');
	let password = $state('');
	let passwordConfirmation = $state('');
	let pending = $state(false);
	let formError = $state<string | null>(null);
	let fieldErrors = $state<Partial<Record<FieldName, string[]>>>({});
	let formErrorBlock: FormError | undefined = $state();
	const fieldRefs: Partial<Record<FieldName, TextField>> = $state({});

	const signInHref = `${resolve('/').replace(/\/$/, '')}/entrar`;

	const isKnown = (name: string): name is FieldName => (FIELD_ORDER as readonly string[]).includes(name);

	function distribute(error: ApiError) {
		const known: Partial<Record<FieldName, string[]>> = {};
		const rest: string[] = [];
		for (const [name, messages] of Object.entries(error.fields)) {
			if (isKnown(name)) known[name] = messages;
			else rest.push(...messages.map((message) => (name === 'base' ? message : `${name}: ${message}`)));
		}
		fieldErrors = known;
		const hasField = Object.keys(known).length > 0;
		formError = rest.length > 0 ? rest.join(' ') : hasField ? null : error.message;
	}

	async function onsubmit(event: SubmitEvent) {
		event.preventDefault();
		if (pending) return;
		pending = true;
		formError = null;
		fieldErrors = {};
		try {
			await signUp({ email, password, password_confirmation: passwordConfirmation });
			await goto(safeReturnTo(page.url.searchParams.get('return_to'))); // eslint-disable-line svelte/no-navigation-without-resolve
		} catch (error) {
			if (!(error instanceof ApiError)) throw error;
			if (error.code === 'validation_failed') distribute(error);
			else formError = error.message;
			await tick();
			const firstInvalid = FIELD_ORDER.find((name) => fieldErrors[name]?.length);
			if (firstInvalid) fieldRefs[firstInvalid]?.focus();
			else formErrorBlock?.focus();
		} finally {
			pending = false;
		}
	}
</script>

<h1>Criar conta</h1>

<form {onsubmit}>
	{#if formError}
		<FormError bind:this={formErrorBlock}>{formError}</FormError>
	{/if}
	<TextField
		bind:this={fieldRefs.email}
		name="email"
		label="E-mail"
		type="email"
		autocomplete="email"
		bind:value={email}
		errors={fieldErrors.email}
		required
	/>
	<TextField
		bind:this={fieldRefs.password}
		name="password"
		label="Senha"
		type="password"
		autocomplete="new-password"
		bind:value={password}
		errors={fieldErrors.password}
		required
	/>
	<TextField
		bind:this={fieldRefs.password_confirmation}
		name="password_confirmation"
		label="Confirmação da senha"
		type="password"
		autocomplete="new-password"
		bind:value={passwordConfirmation}
		errors={fieldErrors.password_confirmation}
		required
	/>
	<Button {pending}>Criar conta</Button>
</form>

<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -->
<p>Já tem conta? <a href={signInHref}>Entrar</a></p>

<style>
	form {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
		max-inline-size: 28rem;
	}
</style>
