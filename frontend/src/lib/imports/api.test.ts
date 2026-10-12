import { describe, expect, it } from 'vitest';
import { IMPORT_TIMEOUT_MS, IMPORTS_PATH, confirmPath, importPath } from './api';

describe('imports api paths', () => {
	it('monta os caminhos base, da pré-visualização e da confirmação', () => {
		expect(IMPORTS_PATH).toBe('/api/collection/imports');
		expect(importPath('abc')).toBe('/api/collection/imports/abc');
		expect(confirmPath('abc')).toBe('/api/collection/imports/abc/confirm');
	});

	it('codifica caracteres reservados do token sem abrir um segundo segmento', () => {
		const token = 'a/b?c#d%e';
		const encoded = 'a%2Fb%3Fc%23d%25e';

		expect(importPath(token)).toBe(`/api/collection/imports/${encoded}`);
		expect(confirmPath(token)).toBe(`/api/collection/imports/${encoded}/confirm`);
		expect(importPath(token).startsWith('/api/')).toBe(true);
		expect(importPath(token).startsWith('//')).toBe(false);
	});

	it('usa 60 s de tempo limite para envio e confirmação', () => {
		expect(IMPORT_TIMEOUT_MS).toBe(60000);
	});
});
