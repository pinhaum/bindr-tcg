import type { ActiveFilters } from '../api/types';
import { appPath } from '../navigation/nav-entries';

type Params = ActiveFilters & { page?: number; per_page?: number };
type ListKey = 'colors' | 'card_types' | 'sets' | 'rarities' | 'attributes' | 'traits';

const KEPT_BY_CLEAR = ['sort', 'dir'];
const NON_FILTER_KEYS = ['sort', 'dir', 'page', 'per_page'];

export const FILTER_LABELS: Record<string, string> = {
	q: 'Busca',
	colors: 'Cor',
	card_types: 'Tipo',
	sets: 'Set',
	rarities: 'Raridade',
	attributes: 'Attribute',
	traits: 'Trait',
	cost_min: 'Custo mín.',
	cost_max: 'Custo máx.',
	power_min: 'Power mín.',
	power_max: 'Power máx.',
	counter_min: 'Counter mín.',
	counter_max: 'Counter máx.',
	owned: 'Posse',
};

const OWNED_TEXT = { owned: 'Tenho', missing: 'Não tenho' };

export type Chip = {
	key: keyof ActiveFilters;
	value: string;
	label: string;
	text: string;
	href: string;
};

const hrefFor = (params: Params): string => {
	const query = new URLSearchParams();
	for (const [key, value] of Object.entries(params)) {
		if (key === 'per_page' || value === undefined) continue;
		if (Array.isArray(value)) for (const item of value) query.append(`${key}[]`, item);
		else query.append(key, String(value));
	}
	const search = query.toString();
	return appPath(search ? `?${search}` : '');
};

const withoutPage = (filters: Params): Params => {
	const rest = { ...filters };
	delete rest.page;
	return rest;
};

export const catalogHref = (filters: ActiveFilters): string => hrefFor(filters);

export const toggleHref = (
	filters: ActiveFilters,
	key: ListKey | 'owned',
	value: string,
): string => {
	const next = withoutPage(filters);
	if (key === 'owned') {
		if (next.owned === value || value === 'all') delete next.owned;
		else next.owned = value as 'owned' | 'missing';
		return hrefFor(next);
	}
	const list = next[key] ?? [];
	const rest = list.includes(value) ? list.filter((item) => item !== value) : [...list, value];
	if (rest.length) next[key] = rest;
	else delete next[key];
	return hrefFor(next);
};

export const withoutHref = (
	filters: ActiveFilters,
	key: keyof ActiveFilters,
	value: string,
): string => {
	const next = withoutPage(filters);
	const current = next[key];
	const rest = Array.isArray(current) ? current.filter((item) => item !== value) : [];
	if (rest.length) next[key as ListKey] = rest;
	else delete next[key];
	return hrefFor(next);
};

export const pageHref = (filters: ActiveFilters, page: number): string =>
	hrefFor({ ...withoutPage(filters), page });

export const clearHref = (filters: ActiveFilters): string =>
	hrefFor(
		Object.fromEntries(Object.entries(filters).filter(([key]) => KEPT_BY_CLEAR.includes(key))),
	);

export const searchHref = (filters: ActiveFilters, term: string): string => {
	const q = term.trim();
	const next = withoutPage(filters);
	if (!q) {
		delete next.q;
		return hrefFor(next);
	}
	return hrefFor('q' in next ? { ...next, q } : { q, ...next });
};

export const setHref = (filters: ActiveFilters, choice: string | null): string => {
	const next = withoutPage(filters);
	if (choice === '') delete next.sets;
	else if (choice !== null) next.sets = [choice];
	return hrefFor(next);
};

export const filterChips = (filters: Params): Chip[] =>
	Object.entries(filters).flatMap(([name, raw]) => {
		if (NON_FILTER_KEYS.includes(name) || raw === undefined) return [];
		const key = name as keyof ActiveFilters;
		const label = FILTER_LABELS[key] ?? key;
		return (Array.isArray(raw) ? raw : [raw]).map((item) => {
			const value = String(item);
			const shown = key === 'owned' ? (OWNED_TEXT[item as 'owned' | 'missing'] ?? value) : value;
			return { key, value, label, text: `${label}: ${shown}`, href: withoutHref(filters, key, value) };
		});
	});
