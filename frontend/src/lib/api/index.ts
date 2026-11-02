import { handleSessionChanged, handleUnauthenticated, session } from '../session.svelte';
import { createApiClient } from './client';

// As dependências são lambdas porque `session.svelte` importa este módulo (ciclo): nada é lido na avaliação.
export const api = createApiClient({
	fetch: (input, init) => globalThis.fetch(input, init),
	onUnauthenticated: () => handleUnauthenticated(),
	currentUserEmail: () => session.user?.email ?? null,
	onSessionChanged: (user) => handleSessionChanged(user)
});
