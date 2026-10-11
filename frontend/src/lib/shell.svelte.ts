import type { Snippet } from 'svelte';
import { MediaQuery } from 'svelte/reactivity';

export const shell: { aside: Snippet | null } = $state({ aside: null });

export const wide = new MediaQuery('min-width: 64rem');
