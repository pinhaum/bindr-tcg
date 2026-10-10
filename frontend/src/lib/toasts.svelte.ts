export type Toast = { id: number; kind: 'success' | 'error'; message: string };

const SUCCESS_LIFETIME_MS = 5000;

export const toasts: Toast[] = $state([]);

let nextId = 1;

function push(kind: Toast['kind'], message: string): number {
	const id = nextId++;
	toasts.push({ id, kind, message });
	return id;
}

export function dismiss(id: number): void {
	const index = toasts.findIndex((toast) => toast.id === id);
	if (index !== -1) toasts.splice(index, 1);
}

export function notifySuccess(message: string): void {
	const id = push('success', message);
	setTimeout(() => dismiss(id), SUCCESS_LIFETIME_MS);
}

export function notifyError(message: string): void {
	push('error', message);
}
