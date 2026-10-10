import { describe, expect, it, vi } from 'vitest';
import { safeReturnTo } from './return-to';

// `base` saiu dos tipos do SvelteKit 3 e chega `undefined` no Vitest; `resolve` é a API tipada.
vi.mock('$app/paths', () => ({ resolve: (path: string) => `/app${path}` }));

describe('safeReturnTo', () => {
	it.each([
		['/app/x?y=1'],
		['/app/x'],
		['/app/catalogo?q=luffy&page=2#topo'],
		['/app/x%20y'],
		['/app/%252F%252Fevil'],
		['/app/x..y'],
		['/app/a.b/c'],
		['/app/x?y=..'],
		['/app/x#/../y']
	])('aceita %s', (raw) => {
		expect(safeReturnTo(raw)).toBe(raw);
	});

	it.each([
		['null', null],
		['vazio', ''],
		['/app sozinho', '/app'],
		['/app?x=1 sem barra', '/app?x=1'],
		['/catalog', '/catalog'],
		['/application/x', '/application/x'],
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
		expect(safeReturnTo(raw)).toBe('/app');
	});
});
