import { describe, expect, it, vi } from 'vitest';
import { isFileRoute, safeReturnTo } from './return-to';

// `base` saiu dos tipos do SvelteKit 3 e chega `undefined` no Vitest; `resolve` é a API tipada.
vi.mock('$app/paths', () => ({ resolve: (path: string) => path }));

describe('safeReturnTo', () => {
	it.each([
		['/pasta', '/pasta'],
		['/pasta?x=1#topo', '/pasta?x=1#topo'],
		['/catalogo?q=luffy&page=2#topo', '/catalogo?q=luffy&page=2#topo'],
		['/x%20y', '/x%20y'],
		['/%252F%252Fevil', '/%252F%252Fevil'],
		['/x..y', '/x..y'],
		['/a.b/c', '/a.b/c'],
		['/x?y=..', '/x?y=..'],
		['/x#/../y', '/x#/../y'],
		['/appx', '/appx'],
		['/application/x', '/application/x'],
		['/', '/'],
		['/?colors%5B%5D=Red&owned=owned', '/?colors%5B%5D=Red&owned=owned'],
		['/app/pasta', '/pasta'],
		['/app', '/'],
		['/app?x=1', '/?x=1'],
		['/app#topo', '/#topo'],
		['/app/?x=1', '/?x=1'],
		['/collection/export', '/collection/export'],
		['/decks/5.txt?x=1', '/decks/5.txt?x=1']
	])('aceita %s como %s', (raw, expected) => {
		expect(safeReturnTo(raw)).toBe(expected);
	});

	it('lê %2Fapp%2Fpasta, com o prefixo legado codificado, como /pasta', () => {
		expect(safeReturnTo(decodeURIComponent('%2Fapp%2Fpasta'))).toBe('/pasta');
	});

	it.each([
		['/api/session'],
		['/api'],
		['/_app/x.js'],
		['/card_images/x'],
		['/app/api/session'],
		['/app/app/api/session'],
		['/app/app/app/_app/x.js'],
		['/app/_app/x.js'],
		['/app/card_images/x'],
		['/%61pi/session'],
		['/app/%61pi/session']
	])('manda %s para a raiz', (raw) => {
		expect(safeReturnTo(raw)).toBe('/');
	});

	it.each([
		['null', null],
		['vazio', ''],
		['query com //', '/app?x=//evil'],
		['query com %2F%2F', '/app?x=%2F%2Fevil'],
		['query com barra invertida', '/app?\\'],
		['query com %5C', '/app?x=%5C'],
		['query com controle', '/app?x=\n1'],
		['query com %0A', '/app?x=%0A1'],
		['//evil.com', '//evil.com'],
		['/app//evil', '/app//evil'],
		['/app/..//evil', '/app/..//evil'],
		['%2F%2Fevil.com', '%2F%2Fevil.com'],
		['/app/%2F%2Fevil', '/app/%2F%2Fevil'],
		['/app/%2f%2fevil', '/app/%2f%2fevil'],
		['https://evil.com/app/x', 'https://evil.com/app/x'],
		['javascript:alert(1)', 'javascript:alert(1)'],
		['/app\\evil', '/app\\evil'],
		['/app/\\evil', '/app/\\evil'],
		['/app%5Cevil', '/app%5Cevil'],
		['/app/%5Cevil', '/app/%5Cevil'],
		['decodificação inválida', '%E0%A4%A'],
		['/app/x%E0%A4%A', '/app/x%E0%A4%A'],
		['barra invertida logo após a raiz', '/\\x'],
		['ponto-ponto sem prefixo', '/a/../b'],
		['espaço no começo', ' /app/x'],
		['tab no começo', '\t/app/x'],
		['newline no começo', '\n/app/x'],
		['tab entre as barras', '/app/\t/evil'],
		['newline entre as barras', '/app/\n/evil'],
		['%09 no começo', '%09/app/x'],
		['%0A entre as barras', '/app/%0A/evil'],
		['ponto-ponto no caminho', '/app/../x'],
		['%2e%2e minúsculo', '/app/%2e%2e/x'],
		['%2E%2E maiúsculo', '/app/%2E%2E/x'],
		['.%2e misto', '/app/.%2e/x'],
		['%2e. misto', '/app/%2e./x'],
		['ponto-ponto encadeado', '/app/x/../../y'],
		['ponto simples', '/app/./x'],
		['%2e simples', '/app/%2e/x'],
		['ponto-ponto no fim', '/app/x/..'],
		['ponto-ponto antes da query', '/app/x/..?y=1'],
		['ponto-ponto antes do hash', '/app/x/..#a'],
		['ponto-ponto após %3F no segmento anterior', '/app/x%3F/../y']
	])('descarta %s', (_nome, raw) => {
		expect(safeReturnTo(raw)).toBe('/');
	});
});

describe('isFileRoute', () => {
	it.each([
		'/collection/export',
		'/collection/export?x=1',
		'/decks/5.txt',
		'/decks/5.txt?x=1',
		'/decks/5.txt#a'
	])('reconhece %s', (path) => {
		expect(isFileRoute(path)).toBe(true);
	});

	it.each([
		'/pasta',
		'/',
		'/decks/5',
		'/decks/5.txt/x',
		'/decks/a/b.txt',
		'/api/x.txt',
		'/decks/.txt/x',
		'/decks//5.txt',
		'/collection/exports',
		'/collection/export/x',
		'/x/collection/export'
	])('não reconhece %s', (path) => {
		expect(isFileRoute(path)).toBe(false);
	});
});
