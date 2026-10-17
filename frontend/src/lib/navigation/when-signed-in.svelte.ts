import { untrack } from 'svelte';
import { session } from '../session.svelte';

// Chamar na inicialização do componente: com sessão, roda `load` com a chave atual e de novo a cada
// troca de conta ou de chave. Chave `null` não carrega. `load` roda fora do rastreio.
export function whenSignedIn(key: () => string | null, load: (key: string) => void): void {
	$effect(() => {
		if (!session.user) return;
		void session.user.email;
		const current = key();
		if (current === null) return;
		untrack(() => load(current));
	});
}
