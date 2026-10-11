import { describe, expect, it, vi } from 'vitest';
import type { ActiveFilters } from '../api/types';

vi.mock('$app/paths', () => ({ resolve: (path: string) => `/app${path}` }));

import {
	catalogHref,
	clearHref,
	pageHref,
	searchHref,
	setHref,
	toggleHref,
	withoutHref,
} from './url';

const enc = (s: string) => s.replace(/\[\]/g, '%5B%5D');

describe('catalogHref', () => {
	it('sem parâmetro devolve só /app', () => {
		expect(catalogHref({})).toBe('/app');
	});

	it('serializa listas repetidas e escalares na ordem das chaves', () => {
		expect(catalogHref({ colors: ['Red', 'Green'], sort: 'name' })).toBe(
			'/app?colors%5B%5D=Red&colors%5B%5D=Green&sort=name',
		);
	});

	it('nunca gera per_page', () => {
		const filters = { q: 'zoro', per_page: 24 } as never;
		expect(catalogHref(filters)).toBe('/app?q=zoro');
	});
});

describe('toggleHref', () => {
	it('acrescenta valor inativo a uma lista', () => {
		expect(toggleHref({ colors: ['Red'] }, 'colors', 'Green')).toBe(
			enc('/app?colors[]=Red&colors[]=Green'),
		);
	});

	it('cria a lista quando a chave não existe', () => {
		expect(toggleHref({ sort: 'name' }, 'rarities', 'SR')).toBe(
			enc('/app?sort=name&rarities[]=SR'),
		);
	});

	it('remove valor ativo e a chave quando a lista esvazia', () => {
		expect(toggleHref({ colors: ['Red'], sort: 'name' }, 'colors', 'Red')).toBe('/app?sort=name');
		expect(toggleHref({ colors: ['Red', 'Green'] }, 'colors', 'Red')).toBe(
			enc('/app?colors[]=Green'),
		);
	});

	it('descarta page', () => {
		const filters = { colors: ['Red'], page: 3 } as never;
		expect(toggleHref(filters, 'colors', 'Green')).toBe(enc('/app?colors[]=Red&colors[]=Green'));
	});

	it('liga owned', () => {
		expect(toggleHref({}, 'owned', 'owned')).toBe('/app?owned=owned');
		expect(toggleHref({ owned: 'owned' }, 'owned', 'missing')).toBe('/app?owned=missing');
	});

	it('remove owned com o mesmo valor ou com all', () => {
		expect(toggleHref({ owned: 'owned' }, 'owned', 'owned')).toBe('/app');
		expect(toggleHref({ owned: 'missing', sort: 'name' }, 'owned', 'all')).toBe('/app?sort=name');
	});
});

describe('withoutHref', () => {
	it('tira um valor de lista e a chave quando esvazia', () => {
		expect(withoutHref({ colors: ['Red', 'Green'] }, 'colors', 'Red')).toBe(
			enc('/app?colors[]=Green'),
		);
		expect(withoutHref({ colors: ['Red'] }, 'colors', 'Red')).toBe('/app');
	});

	it('tira a chave escalar e descarta page', () => {
		const filters = { q: 'zoro', cost_min: 2, page: 2 } as never;
		expect(withoutHref(filters, 'q', 'zoro')).toBe('/app?cost_min=2');
	});
});

describe('pageHref', () => {
	it('mantém os filtros e põe page', () => {
		expect(pageHref({ colors: ['Red'], sort: 'name' }, 2)).toBe(
			enc('/app?colors[]=Red&sort=name&page=2'),
		);
	});

	it('substitui um page existente', () => {
		const filters = { q: 'a', page: 2 } as never;
		expect(pageHref(filters, 3)).toBe('/app?q=a&page=3');
	});
});

describe('clearHref', () => {
	it('mantém só sort e dir', () => {
		expect(
			clearHref({
				colors: ['Red'],
				q: 'zoro',
				sort: 'cost',
				dir: 'desc',
				owned: 'owned',
			}),
		).toBe('/app?sort=cost&dir=desc');
		expect(clearHref({ colors: ['Red'] })).toBe('/app');
	});
});

describe('searchHref', () => {
	it('põe q aparado, mantém os filtros e descarta page', () => {
		const filters = { colors: ['Red'], page: 3 } as never;
		expect(searchHref(filters, '  zoro ')).toBe(enc('/app?q=zoro&colors[]=Red'));
	});

	it('substitui o q existente na mesma posição', () => {
		expect(searchHref({ q: 'a', sort: 'name' }, 'b')).toBe('/app?q=b&sort=name');
	});

	it('remove q com termo só de espaços', () => {
		expect(searchHref({ q: 'zoro', sort: 'name' }, '   ')).toBe('/app?sort=name');
	});
});

describe('setHref', () => {
	it('null mantém tudo menos page', () => {
		const filters = { sets: ['OP01', 'OP02'], page: 2 } as never;
		expect(setHref(filters, null)).toBe(enc('/app?sets[]=OP01&sets[]=OP02'));
	});

	it('vazio remove sets', () => {
		expect(setHref({ sets: ['OP01'], sort: 'name' }, '')).toBe('/app?sort=name');
	});

	it('código põe sets igual só a ele', () => {
		expect(setHref({ sets: ['OP01', 'OP02'], sort: 'name' }, 'OP03')).toBe(
			enc('/app?sets[]=OP03&sort=name'),
		);
	});
});

describe('preservação (SCAT-27)', () => {
	const all: ActiveFilters = {
		cost_min: 1,
		cost_max: 5,
		power_min: 1000,
		power_max: 9000,
		counter_min: 1000,
		counter_max: 2000,
		attributes: ['Slash'],
		traits: ['Straw Hat Crew'],
		sort: 'cost',
		dir: 'desc',
	};
	const keep = (href: string) => {
		const p = new URLSearchParams(href.split('?')[1]);
		for (const k of ['cost_min', 'power_max', 'counter_min', 'sort', 'dir'])
			expect(p.has(k)).toBe(true);
		expect(p.getAll('attributes[]')).toEqual(['Slash']);
		expect(p.getAll('traits[]')).toEqual(['Straw Hat Crew']);
	};

	it('sobrevive a toda função', () => {
		keep(toggleHref({ ...all }, 'colors', 'Red'));
		keep(withoutHref({ ...all, colors: ['Red'] }, 'colors', 'Red'));
		keep(pageHref({ ...all }, 2));
		keep(searchHref({ ...all }, 'x'));
		keep(setHref({ ...all }, 'OP01'));
	});
});
