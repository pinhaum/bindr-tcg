<script lang="ts">
	import { page } from '$app/state';
	import { tick } from 'svelte';
	import { ApiError } from '../../../../lib/api/errors';
	import { api } from '../../../../lib/api/index';
	import { createLoader } from '../../../../lib/api/loader.svelte';
	import type { ImportPreview, ImportSummary as ImportSummaryData } from '../../../../lib/api/types';
	import Button from '../../../../lib/components/Button.svelte';
	import FormError from '../../../../lib/components/FormError.svelte';
	import ImportRowItem from '../../../../lib/components/ImportRowItem.svelte';
	import ImportSummary from '../../../../lib/components/ImportSummary.svelte';
	import { IMPORT_TIMEOUT_MS, confirmPath, importPath } from '../../../../lib/imports/api';
	import { analyzedLines, groupRows, removalWarning } from '../../../../lib/imports/groups';
	import { appPath } from '../../../../lib/navigation/nav-entries';
	import { whenSignedIn } from '../../../../lib/navigation/when-signed-in.svelte';

	const loader = createLoader((token) => api.get<ImportPreview>(importPath(token)));

	const token = $derived(page.params.token ?? '');

	let summary = $state<ImportSummaryData | null>(null);
	let confirming = $state(false);
	let confirmAlert = $state<string | null>(null);
	let outcomeUnknown = $state(false);
	let summaryView: ImportSummary | undefined = $state();
	let alertBlock: FormError | undefined = $state();

	const preview = $derived(loader.state.result);
	const error = $derived(loader.state.error);
	const groups = $derived(preview ? groupRows(preview.rows) : []);
	const removes = $derived(groups.find((group) => group.classification === 'removes')?.rows.length ?? 0);
	const title = $derived(
		summary ? 'Importação concluída — Bindr' : 'Pré-visualização da importação — Bindr'
	);

	// Troca de token ou de sessão descarta confirmação, alerta e resumo da tela anterior.
	whenSignedIn(
		() => token,
		(current) => {
			summary = null;
			confirming = false;
			confirmAlert = null;
			outcomeUnknown = false;
			loader.load(current);
		}
	);

	function retry(event: SubmitEvent) {
		event.preventDefault();
		loader.retry();
	}

	async function confirm(event: SubmitEvent) {
		event.preventDefault();
		if (confirming) return;
		confirming = true;
		confirmAlert = null;
		try {
			summary = await api.post<ImportSummaryData>(confirmPath(token), undefined, {
				timeoutMs: IMPORT_TIMEOUT_MS
			});
			await tick();
			summaryView?.focus();
		} catch (cause) {
			if (!(cause instanceof ApiError)) throw cause;
			if (cause.code === 'unauthenticated' || cause.code === 'session_changed') return;
			if (cause.status === 0) outcomeUnknown = true;
			else confirmAlert = cause.message;
			await tick();
			alertBlock?.focus();
		} finally {
			confirming = false;
		}
	}
</script>

<svelte:head><title>{title}</title></svelte:head>

{#if summary}
	<ImportSummary bind:this={summaryView} {summary} />
{:else}
	<h1>Confira o que vai mudar</h1>
	<p class="visually-hidden" role="status">{confirming ? 'Gravando na sua coleção…' : ''}</p>

	<section aria-busy={loader.state.slow}>
		{#if loader.state.slow}
			<p class="visually-hidden">Carregando pré-visualização…</p>
		{/if}
		{#if error}
			{#if error.status === 404}
				<p>{error.message}</p>
				<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- href parte de appPath -->
				<p><a href={appPath('/pasta/importar')}>Enviar um arquivo</a></p>
			{:else}
				<form class="message" onsubmit={retry}>
					<p role="alert">{error.message}</p>
					<Button>Tentar novamente</Button>
				</form>
			{/if}
		{:else if preview}
			<p>
				<strong>Arquivo: {preview.filename} — {analyzedLines(preview.rows.length)}.</strong>
				Nada foi gravado na sua coleção ainda. Sua coleção só muda quando você confirmar, no fim desta
				página.
			</p>

			{#each groups as group (group.classification)}
				<section class="group {group.classification}">
					<h2>{group.title} ({group.rows.length})</h2>
					<p>{group.support}</p>
					<ul>
						{#each group.rows as row (row.line)}
							<li><ImportRowItem {row} /></li>
						{/each}
					</ul>
				</section>
			{/each}

			{#if outcomeUnknown}
				<FormError bind:this={alertBlock}>
					Não foi possível saber se a importação foi gravada. Confira a sua pasta antes de enviar o
					arquivo de novo.
				</FormError>
				<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- href parte de appPath -->
				<p><a href={appPath('/pasta')}>Ver minha coleção</a></p>
			{:else}
				{#if removes > 0}
					<p class="removal">
						<strong>{removalWarning(removes)}</strong>
						Veja quais em “Remove da coleção”, no topo desta página.
					</p>
				{/if}
				{#if confirmAlert}
					<FormError bind:this={alertBlock}>{confirmAlert}</FormError>
				{/if}
				<form onsubmit={confirm}>
					<Button pending={confirming}>Confirmar e gravar na minha coleção</Button>
				</form>
				<p>
					Se algo estiver errado, <!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- href parte de appPath --><a
						href={appPath('/pasta/importar')}>envie outro arquivo</a
					>. Sair desta página sem confirmar deixa sua coleção exatamente como está.
				</p>
			{/if}
		{/if}
	</section>
{/if}

<style>
	section {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
		margin-block-start: var(--space-3);
	}

	p,
	h2 {
		margin: 0;
	}

	ul {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		margin: 0;
		padding: 0;
		list-style: none;
	}

	.group {
		margin: 0;
	}

	.removal {
		padding: var(--space-2) var(--space-3);
		border: 2px solid var(--danger);
		border-radius: var(--radius-md);
	}
</style>
