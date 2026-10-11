import { beforeEach, describe, expect, it } from 'vitest';
import { isMarked, markCard, morphName } from './morph.svelte';

const CUSTOM_IDENT = /^[A-Za-z][A-Za-z0-9_-]*$/;

describe('morphName', () => {
	it('gera <custom-ident> válido e distinto para códigos de carta', () => {
		const names = ['OP01-001', 'P-029', 'ST01.001 x', '1', '--x', 'é'].map(morphName);
		for (const name of names) expect(name).toMatch(CUSTOM_IDENT);
		expect(new Set(names).size).toBe(names.length);
	});

	it('é determinístico', () => {
		expect(morphName('OP01-001')).toBe(morphName('OP01-001'));
	});

	it('não confunde um código com o escape de outro', () => {
		expect(morphName('a.b')).not.toBe(morphName('a_2e_b'));
		expect(morphName('a b')).not.toBe(morphName('a.b'));
	});
});

describe('markCard', () => {
	beforeEach(() => markCard(null));

	it('marcar uma carta substitui a anterior', () => {
		markCard('OP01-001');
		markCard('P-029');
		expect(isMarked('P-029')).toBe(true);
		expect(isMarked('OP01-001')).toBe(false);
	});

	it('sem marca, nenhuma carta é marcada', () => {
		expect(isMarked('OP01-001')).toBe(false);
	});
});
