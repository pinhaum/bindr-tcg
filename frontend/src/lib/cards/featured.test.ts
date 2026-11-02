import { describe, expect, it } from 'vitest';
import type { DetailVariant } from '../api/types';
import { pickFeatured } from './featured';

const variant = (code: string, inSource = true): DetailVariant => ({
	variant_code: code,
	rarity: 'SR',
	art_kind: 'base',
	set: { code: 'OP01', name: 'Romance Dawn' },
	illustrator: null,
	image_url: null,
	in_source: inSource,
	owned_quantity: null,
	wishlist_target: null,
	price: null
});

describe('pickFeatured', () => {
	const list = [variant('a', false), variant('b'), variant('c')];

	it('devolve a variante do parâmetro quando ela está na lista (SCAR-24)', () => {
		expect(pickFeatured(list, 'c')?.variant_code).toBe('c');
		expect(pickFeatured(list, 'a')?.variant_code).toBe('a');
	});

	it('usa a primeira na fonte quando o parâmetro falta ou é desconhecido', () => {
		expect(pickFeatured(list, null)?.variant_code).toBe('b');
		expect(pickFeatured(list, undefined)?.variant_code).toBe('b');
		expect(pickFeatured(list, 'zzz')?.variant_code).toBe('b');
		expect(pickFeatured(list, '')?.variant_code).toBe('b');
	});

	it('usa a primeira listada quando nenhuma está na fonte', () => {
		const out = [variant('x', false), variant('y', false)];
		expect(pickFeatured(out, null)?.variant_code).toBe('x');
	});

	it('devolve null para lista vazia, sem erro', () => {
		expect(pickFeatured([], 'a')).toBeNull();
		expect(pickFeatured([], null)).toBeNull();
	});
});
