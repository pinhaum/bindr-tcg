import type { Snippet } from 'svelte';
import { MediaQuery } from 'svelte/reactivity';

export const shell: { aside: Snippet | null } = $state({ aside: null });

export const wide = new MediaQuery('min-width: 64rem');

// Chamar na inicialização do componente: a partir de `64rem` o snippet ocupa a coluna lateral do casco.
export function useAside(snippet: Snippet): void {
	$effect(() => {
		if (!wide.current) return;
		shell.aside = snippet;
		return () => {
			shell.aside = null;
		};
	});
}
