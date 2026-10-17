import { describe, expect, it, vi } from 'vitest';
import type { ActiveFilters } from '../api/types';

vi.mock('$app/paths', () => ({ resolve: (path: string) => path }));

import {
	catalogHref,
	clearHref,
	FILTER_LABELS,
	filterChips,
	pageHref,
	searchHref,
	setHref,
	toggleHref,
	withoutHref,
} from './url';

const enc = (s: string) => s.replace(/\[\]/g, '%5B%5D');

describe('catalogHref', () => {
	it('sem parâmetro devolve só /', () => {
		expect(catalogHref({})).toBe('/');
	});

	it('serializa listas repetidas e escalares na ordem das chaves', () => {
		expect(catalogHref({ colors: ['Red', 'Green'], sort: 'name' })).toBe(
			'/?colors%5B%5D=Red&colors%5B%5D=Green&sort=name',
		);
	});

	it('nunca gera per_page', () => {
		const filters = { q: 'zoro', per_page: 24 } as never;
		expect(catalogHref(filters)).toBe('/?q=zoro');
	});
});

describe('toggleHref', () => {
	it('acrescenta valor inativo a uma lista', () => {
		expect(toggleHref({ colors: ['Red'] }, 'colors', 'Green')).toBe(
			enc('/?colors[]=Red&colors[]=Green'),
		);
	});

	it('cria a lista quando a chave não existe', () => {
		expect(toggleHref({ sort: 'name' }, 'rarities', 'SR')).toBe(
			enc('/?sort=name&rarities[]=SR'),
		);
	});

	it('remove valor ativo e a chave quando a lista esvazia', () => {
		expect(toggleHref({ colors: ['Red'], sort: 'name' }, 'colors', 'Red')).toBe('/?sort=name');
		expect(toggleHref({ colors: ['Red', 'Green'] }, 'colors', 'Red')).toBe(
			enc('/?colors[]=Green'),
		);
	});

	it('descarta page', () => {
		const filters = { colors: ['Red'], page: 3 } as never;
		expect(toggleHref(filters, 'colors', 'Green')).toBe(enc('/?colors[]=Red&colors[]=Green'));
	});

	it('liga owned', () => {
		expect(toggleHref({}, 'owned', 'owned')).toBe('/?owned=owned');
		expect(toggleHref({ owned: 'owned' }, 'owned', 'missing')).toBe('/?owned=missing');
	});

	it('remove owned com o mesmo valor ou com all', () => {
		expect(toggleHref({ owned: 'owned' }, 'owned', 'owned')).toBe('/');
		expect(toggleHref({ owned: 'missing', sort: 'name' }, 'owned', 'all')).toBe('/?sort=name');
	});
});

describe('withoutHref', () => {
	it('tira um valor de lista e a chave quando esvazia', () => {
		expect(withoutHref({ colors: ['Red', 'Green'] }, 'colors', 'Red')).toBe(
			enc('/?colors[]=Green'),
		);
		expect(withoutHref({ colors: ['Red'] }, 'colors', 'Red')).toBe('/');
	});

	it('tira a chave escalar e descarta page', () => {
		const filters = { q: 'zoro', cost_min: 2, page: 2 } as never;
		expect(withoutHref(filters, 'q', 'zoro')).toBe('/?cost_min=2');
	});
});

describe('pageHref', () => {
	it('mantém os filtros e põe page', () => {
		expect(pageHref({ colors: ['Red'], sort: 'name' }, 2)).toBe(
			enc('/?colors[]=Red&sort=name&page=2'),
		);
	});

	it('substitui um page existente', () => {
		const filters = { q: 'a', page: 2 } as never;
		expect(pageHref(filters, 3)).toBe('/?q=a&page=3');
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
		).toBe('/?sort=cost&dir=desc');
		expect(clearHref({ colors: ['Red'] })).toBe('/');
	});
});

describe('searchHref', () => {
	it('põe q aparado, mantém os filtros e descarta page', () => {
		const filters = { colors: ['Red'], page: 3 } as never;
		expect(searchHref(filters, '  zoro ')).toBe(enc('/?q=zoro&colors[]=Red'));
	});

	it('substitui o q existente na mesma posição', () => {
		expect(searchHref({ q: 'a', sort: 'name' }, 'b')).toBe('/?q=b&sort=name');
	});

	it('remove q com termo só de espaços', () => {
		expect(searchHref({ q: 'zoro', sort: 'name' }, '   ')).toBe('/?sort=name');
	});
});

describe('setHref', () => {
	it('null mantém tudo menos page', () => {
		const filters = { sets: ['OP01', 'OP02'], page: 2 } as never;
		expect(setHref(filters, null)).toBe(enc('/?sets[]=OP01&sets[]=OP02'));
	});

	it('vazio remove sets', () => {
		expect(setHref({ sets: ['OP01'], sort: 'name' }, '')).toBe('/?sort=name');
	});

	it('código põe sets igual só a ele', () => {
		expect(setHref({ sets: ['OP01', 'OP02'], sort: 'name' }, 'OP03')).toBe(
			enc('/?sets[]=OP03&sort=name'),
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

describe('chips de filtros ativos (SCAT-28)', () => {
	it('rótulos exatos', () => {
		expect(FILTER_LABELS).toEqual({
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
		});
	});

	it('um chip por valor, sem sort, dir, page e per_page', () => {
		const chips = filterChips({
			colors: ['Red', 'Green'],
			owned: 'missing',
			sort: 'name',
			page: 2,
		});
		expect(chips.map((chip) => chip.text)).toEqual([
			'Cor: Red',
			'Cor: Green',
			'Posse: Não tenho',
		]);
		expect(chips[0]).toMatchObject({ key: 'colors', value: 'Red', label: 'Cor' });
		expect(chips[0].href).toBe(enc('/?colors[]=Green&owned=missing&sort=name'));
		expect(chips[1].href).toBe(enc('/?colors[]=Red&owned=missing&sort=name'));
		expect(chips[2].href).toBe(enc('/?colors[]=Red&colors[]=Green&sort=name'));
	});

	it('posse "owned" sai como Tenho', () => {
		expect(filterChips({ owned: 'owned' })[0].text).toBe('Posse: Tenho');
	});

	it('valores numéricos e busca viram texto', () => {
		const texts = filterChips({ q: 'luffy', cost_min: 2, power_max: 9000 }).map((c) => c.text);
		expect(texts).toEqual(['Busca: luffy', 'Custo mín.: 2', 'Power máx.: 9000']);
	});

	it('sem filtro devolve lista vazia', () => {
		expect(filterChips({})).toEqual([]);
		expect(filterChips({ sort: 'name', dir: 'desc', page: 3, per_page: 24 })).toEqual([]);
	});
});
