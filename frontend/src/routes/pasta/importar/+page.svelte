<script lang="ts">
	import { goto } from '$app/navigation';
	import { tick } from 'svelte';
	import { ApiError } from '../../../lib/api/errors';
	import { api } from '../../../lib/api/index';
	import Button from '../../../lib/components/Button.svelte';
	import FormError from '../../../lib/components/FormError.svelte';
	import { IMPORT_TIMEOUT_MS, IMPORTS_PATH } from '../../../lib/imports/api';
	import { appPath } from '../../../lib/navigation/nav-entries';
	import type { ImportPreview } from '../../../lib/api/types';

	const ERROR_ID = 'import-file-error';

	let files = $state<FileList | null>(null);
	let pending = $state(false);
	let message = $state<string | null>(null);
	let fileMessages = $state<string[]>([]);
	let errorBlock: FormError | undefined = $state();

	async function onsubmit(event: SubmitEvent) {
		event.preventDefault();
		const file = files?.[0];
		if (pending || !file) return;
		pending = true;
		message = null;
		fileMessages = [];
		try {
			const body = new FormData();
			body.append('file', file);
			const preview = await api.post<ImportPreview>(IMPORTS_PATH, body, { timeoutMs: IMPORT_TIMEOUT_MS });
			// eslint-disable-next-line svelte/no-navigation-without-resolve -- parte de appPath
			await goto(appPath(`/pasta/importar/${encodeURIComponent(preview.token)}`));
		} catch (error) {
			if (!(error instanceof ApiError)) throw error;
			if (error.code === 'unauthenticated') return;
			message = error.message;
			fileMessages = error.code === 'validation_failed' ? (error.fields.file ?? []) : [];
			await tick();
			errorBlock?.focus();
		} finally {
			pending = false;
		}
	}
</script>

<svelte:head><title>Importar coleção — Bindr</title></svelte:head>

<h1>Importar coleção</h1>

<p>
	Envie o arquivo CSV exportado da sua coleção. Você verá o que vai mudar antes de qualquer alteração ser gravada.
</p>

<form {onsubmit}>
	<p class="visually-hidden" role="status">{pending ? 'Enviando o arquivo…' : ''}</p>
	{#if message}
		<div id={ERROR_ID}>
			<FormError bind:this={errorBlock}>{[message, ...fileMessages].join(' ')}</FormError>
		</div>
	{/if}
	<div class="field">
		<label for="field-file">Arquivo CSV</label>
		<input
			id="field-file"
			name="file"
			type="file"
			accept="text/csv,.csv"
			required
			bind:files
			aria-invalid={fileMessages.length > 0 ? 'true' : undefined}
			aria-describedby={fileMessages.length > 0 ? ERROR_ID : undefined}
		/>
	</div>
	<Button {pending}>Pré-visualizar importação</Button>
</form>

<style>
	form {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
		max-inline-size: 28rem;
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

	input {
		min-block-size: var(--touch-target);
		font: inherit;
		color: var(--ink);
	}
</style>
