import { describe, expect, it } from 'vitest';

const sources = import.meta.glob(['./**/*.svelte', './**/*.ts', '!./**/*.test.ts'], {
	query: '?raw',
	import: 'default',
	eager: true
}) as Record<string, string>;

const NAVIGATION_TARGET =
	/(?:\bhref\s*[=:]\s*\{?\s*|\b(?:goto|redirect|assign|resolve)\(\s*(?:\d+\s*,\s*)?)["'`](\/[^"'`]*)["'`]/g;

const REMOVED_ROUTE =
	/^\/(?:catalog|cards|session|registration|progress|wishlist|collection_items|decks|app)(?:\/|$)|^\/collection\/import/;
const FILE_ROUTE = /^\/(?:collection\/export|decks\/[^/]+\.txt)$/;

function pathOf(target: string): string {
	return target.split(/[?#]/)[0];
}

function destinations(source: string): string[] {
	return [...source.matchAll(NAVIGATION_TARGET)].map((match) => match[1]);
}

function removedDestinations(source: string): string[] {
	return destinations(source).filter((target) => {
		const path = pathOf(target);
		return REMOVED_ROUTE.test(path) && !FILE_ROUTE.test(path);
	});
}

describe('destinos de rotas HTML removidas', () => {
	it('nenhum href, goto ou redirect do código da SPA aponta para rota removida', () => {
		const found = Object.entries(sources).flatMap(([file, source]) =>
			removedDestinations(source).map((target) => `${file}: ${target}`)
		);
		expect(found).toEqual([]);
	});

	it('a varredura lê o código da SPA e enxerga as rotas de arquivo permitidas', () => {
		expect(Object.keys(sources).length).toBeGreaterThan(50);
		const all = Object.values(sources).flatMap(destinations);
		expect(all).toContain('/collection/export');
		expect(all).toContain('/decks/{deck.id}.txt');
	});

	it.each([
		['href="/progress"'],
		['<a href="/catalog?q=luffy">'],
		['<a href={`/cards/OP01-001`}>'],
		["goto('/session')"],
		["goto(resolve('/registration'))"],
		["redirect(307, '/wishlist')"],
		["window.location.assign('/app/pasta')"],
		["{ href: '/app' }"],
		['<a href="/collection/import">'],
		['<a href="/collection_items/1">'],
		['<a href="/decks">'],
		['<a href="/decks/1/rename">'],
		['<a href="/decks/1.txt/x">']
	])('reprova um fonte sintético com %s', (source) => {
		expect(removedDestinations(source)).not.toEqual([]);
	});

	it.each([
		['<a href="/collection/export">'],
		['<a href="/collection/export?x=1">'],
		['<a href="/decks/{deck.id}.txt">'],
		["goto(resolve('/pasta'))"],
		["goto(resolve('/baralhos'))"],
		['<a href="/cartas/OP01-001">'],
		['<a href="/application">']
	])('aceita um fonte sintético com %s', (source) => {
		expect(removedDestinations(source)).toEqual([]);
	});
});
