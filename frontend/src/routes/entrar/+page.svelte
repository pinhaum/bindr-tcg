<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import { tick } from 'svelte';
	import { ApiError } from '../../lib/api/errors';
	import Button from '../../lib/components/Button.svelte';
	import FormError from '../../lib/components/FormError.svelte';
	import TextField from '../../lib/components/TextField.svelte';
	import { appPath } from '../../lib/navigation/nav-entries';
	import { isFileRoute, safeReturnTo } from '../../lib/navigation/return-to';
	import { signIn } from '../../lib/session.svelte';

	let email = $state('');
	let password = $state('');
	let pending = $state(false);
	let formError = $state<string | null>(null);
	let formErrorBlock: FormError | undefined = $state();

	const signUpHref = appPath('/criar-conta');

	async function onsubmit(event: SubmitEvent) {
		event.preventDefault();
		if (pending) return;
		pending = true;
		formError = null;
		try {
			await signIn(email, password);
			const destination = safeReturnTo(page.url.searchParams.get('return_to'));
			if (isFileRoute(destination)) window.location.assign(destination);
			else await goto(destination); // eslint-disable-line svelte/no-navigation-without-resolve
		} catch (error) {
			if (!(error instanceof ApiError)) throw error;
			formError = error.message;
			if (error.code === 'invalid_credentials') password = '';
			await tick();
			formErrorBlock?.focus();
		} finally {
			pending = false;
		}
	}
</script>

<svelte:head><title>Entrar — Bindr</title></svelte:head>

<h1>Entrar</h1>

<form {onsubmit}>
	{#if formError}
		<FormError bind:this={formErrorBlock}>{formError}</FormError>
	{/if}
	<TextField name="email" label="E-mail" type="email" autocomplete="email" bind:value={email} required />
	<TextField
		name="password"
		label="Senha"
		type="password"
		autocomplete="current-password"
		bind:value={password}
		required
	/>
	<Button {pending}>Entrar</Button>
</form>

<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -->
<p>Não tem conta? <a href={signUpHref}>Criar conta</a></p>

<style>
	form {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
		max-inline-size: 28rem;
	}
</style>
