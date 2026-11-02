<script lang="ts">
	import { tick } from 'svelte';
	import { goto } from '$app/navigation';
	import { ApiError } from '../../../lib/api/errors';
	import { api } from '../../../lib/api/index';
	import type { DeckPayload } from '../../../lib/api/types';
	import Button from '../../../lib/components/Button.svelte';
	import FormError from '../../../lib/components/FormError.svelte';
	import TextField from '../../../lib/components/TextField.svelte';
	import { deckHref } from '../../../lib/decks/url';
	import { appPath } from '../../../lib/navigation/nav-entries';
	import { notifySuccess } from '../../../lib/toasts.svelte';

	let name = $state('');
	let list = $state('');
	let pending = $state(false);
	let message = $state<string | null>(null);
	let listErrors = $state<string[]>([]);
	let nameErrors = $state<string[]>([]);
	let summary: FormError | undefined = $state();
	let nameField: TextField | undefined = $state();

	const summaryId = 'importar-erro';

	function distribute(error: ApiError) {
		const { name: own = [], list: lines = [], ...others } = error.fields;
		const rest = Object.entries(others).flatMap(([key, messages]) =>
			messages.map((text) => (key === 'base' ? text : `${key}: ${text}`))
		);
		nameErrors = own;
		listErrors = [...rest, ...lines];
		message = own.length > 0 && listErrors.length === 0 ? null : error.message;
	}

	async function onsubmit(event: SubmitEvent) {
		event.preventDefault();
		if (pending) return;
		pending = true;
		message = null;
		listErrors = [];
		nameErrors = [];
		try {
			const deck = await api.post<DeckPayload>('/api/decks/import', { name, list });
			await goto(deckHref(deck.id)); // eslint-disable-line svelte/no-navigation-without-resolve
			notifySuccess('Deck importado.');
		} catch (error) {
			if (!(error instanceof ApiError)) throw error;
			if (error.code === 'validation_failed') distribute(error);
			else message = error.message;
			await tick();
			if (message === null) nameField?.focus();
			else summary?.focus();
		} finally {
			pending = false;
		}
	}
</script>

<svelte:head><title>Importar lista — Bindr</title></svelte:head>

<h1>Importar lista</h1>

<p>
	Cole a lista do OPTCG Simulator: uma carta por linha, como 4xOP01-016, com o Leader como 1x. A importação cria um
	deck novo e não altera nenhum deck que você já tem.
</p>

<form {onsubmit}>
	{#if message !== null}
		<FormError bind:this={summary}>
			<span id={summaryId}>
				{message}
				{#if listErrors.length > 0}
					<ul>
						{#each listErrors as line, index (index)}
							<li>{line}</li>
						{/each}
					</ul>
				{/if}
			</span>
		</FormError>
	{/if}
	<TextField
		bind:this={nameField}
		name="name"
		label="Nome do deck (opcional; sem nome, o deck leva o nome do Leader)"
		autocomplete="off"
		bind:value={name}
		errors={nameErrors}
		maxlength={60}
	/>
	<div class="field">
		<label for="field-list">Lista (até 200 linhas e 10.000 caracteres)</label>
		<textarea
			id="field-list"
			name="list"
			rows="12"
			required
			bind:value={list}
			aria-invalid={message !== null && listErrors.length > 0 ? 'true' : undefined}
			aria-describedby={message !== null && listErrors.length > 0 ? summaryId : undefined}
		></textarea>
	</div>
	<Button {pending}>Importar lista</Button>
</form>

<p>
	<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- href já vem resolvido por appPath -->
	<a href={appPath('/baralhos')}>Voltar aos baralhos</a>
</p>

<style>
	form {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
		max-inline-size: 36rem;
	}

	.field {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	label {
		color: var(--ink);
		font-weight: 600;
	}

	textarea {
		box-sizing: border-box;
		padding: var(--space-2) var(--space-3);
		border: 1px solid var(--border-strong);
		border-radius: var(--radius-sm);
		background: var(--surface-sunken);
		color: var(--ink);
		font: inherit;
		font-family: ui-monospace, monospace;
	}

	textarea:focus-visible {
		outline: 2px solid var(--accent);
		outline-offset: 2px;
	}

	ul {
		margin-block: var(--space-1) 0;
		padding-inline-start: var(--space-4);
	}
</style>
