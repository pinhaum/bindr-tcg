import { appPath } from '../navigation/nav-entries';

const suffix = (sub?: string) => (sub === undefined ? '' : `/${sub}`);

export const deckHref = (id: number, sub?: string): string => appPath(`/baralhos/${id}${suffix(sub)}`);

export const deckApiPath = (id: number, sub?: string): string => `/api/decks/${id}${suffix(sub)}`;

export const deckCardApiPath = (
	id: number,
	cardNumber: string,
	op: 'increment' | 'decrement',
): string => `/api/decks/${id}/cards/${encodeURIComponent(cardNumber)}/${op}`;
