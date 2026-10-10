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
		['/app/%252F%252Fevil']
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
		['%0A entre as barras', '/app/%0A/evil']
	])('descarta %s', (_nome, raw) => {
		expect(safeReturnTo(raw)).toBe('/app');
	});
});
