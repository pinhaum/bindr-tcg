<script lang="ts">
	import { setPreference, theme, type ThemePreference } from '../theme.svelte';

	function change(event: Event & { currentTarget: HTMLSelectElement }) {
		setPreference(event.currentTarget.value as ThemePreference);
	}
</script>

<label>
	Tema
	<select value={theme.preference} onchange={change}>
		<option value="system">Sistema</option>
		<option value="light">Claro</option>
		<option value="dark">Escuro</option>
	</select>
</label>

<style>
	label {
		display: inline-flex;
		align-items: center;
		gap: var(--space-2);
	}

	select {
		min-height: var(--touch-target);
		padding: 0 var(--space-2);
		border: 1px solid var(--border-strong);
		border-radius: var(--radius-md);
		background: var(--surface-raised);
		color: inherit;
		font: inherit;
	}
</style>
