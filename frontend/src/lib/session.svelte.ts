import { goto } from '$app/navigation';
import { navigating, page } from '$app/state';
import { api } from './api/index';
import { ApiError } from './api/errors';
import type { SessionPayload, SessionUser } from './api/types';
import { appPath } from './navigation/nav-entries';
import { notifySuccess } from './toasts.svelte';

export type SessionState = {
	status: 'loading' | 'ready' | 'error';
	user: SessionUser | null;
	error: ApiError | null;
};

export type SignUpFields = { email: string; password: string; password_confirmation: string };

export const session: SessionState = $state({ status: 'loading', user: null, error: null });

// Todo destino nasce de `appPath`; `resolve('/entrar')` só tipa quando a rota existir (T16).
const navigate = (path: string) => goto(path); // eslint-disable-line svelte/no-navigation-without-resolve

export async function loadSession(): Promise<void> {
	const { user } = await api.get<SessionPayload>('/api/session');
	session.user = user;
	session.status = 'ready';
	session.error = null;
}

export async function signIn(email: string, password: string): Promise<void> {
	const { user } = await api.post<SessionPayload>('/api/session', { email, password });
	session.user = user;
}

export async function signUp(fields: SignUpFields): Promise<void> {
	const { user } = await api.post<SessionPayload>('/api/registration', { user: fields });
	session.user = user;
}

export async function signOut(): Promise<void> {
	try {
		await api.delete('/api/session');
	} catch (error) {
		if (!(error instanceof ApiError && error.code === 'unauthenticated')) throw error;
	}
	session.user = null;
	await navigate(appPath(''));
	notifySuccess('Sessão encerrada.');
}

export function handleUnauthenticated(): void {
	session.user = null;
	const { pathname, search } = navigating.to?.url ?? page.url;
	const signInPath = appPath('/entrar');
	if (pathname === signInPath || pathname === appPath('/criar-conta')) return;
	void navigate(`${signInPath}?return_to=${encodeURIComponent(pathname + search)}`);
}

export function handleSessionChanged(user: SessionUser): void {
	session.user = user;
	void navigate(appPath(''));
}
