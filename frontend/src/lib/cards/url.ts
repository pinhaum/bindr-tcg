import { appPath } from '../navigation/nav-entries';

const query = (variant?: string) => (variant === undefined ? '' : `?variant=${encodeURIComponent(variant)}`);

export const cardDetailHref = (cardNumber: string, variantCode?: string): string =>
	`${appPath(`/cartas/${encodeURIComponent(cardNumber)}`)}${query(variantCode)}`;

export const cardApiPath = (cardNumber: string, variant?: string): string =>
	`/api/cards/${encodeURIComponent(cardNumber)}${query(variant)}`;

export const variantApiPath = (
	cardNumber: string,
	variantCode: string,
	action: 'increment' | 'decrement' | 'wishlist',
): string =>
	`/api/cards/${encodeURIComponent(cardNumber)}/variants/${encodeURIComponent(variantCode)}/${action}`;
