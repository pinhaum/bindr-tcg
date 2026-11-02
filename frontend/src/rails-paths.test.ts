import { describe, expect, it } from 'vitest';
import { RAILS_PATH_PATTERN } from '../rails-paths';

const RAILS_PATHS = [
	'/api/session',
	'/card_images/x',
	'/up',
	'/collection/export',
	'/collection/import',
	'/decks',
	'/decks/5.txt',
	'/decks/5/edit',
	'/catalog?x=1',
	'/cards/OP01-001',
	'/progress',
	'/wishlist',
	'/session/new',
	'/registration/new',
	'/app',
	'/app/pasta',
	'/collection_items/1/increment',
	'/icon.png',
	'/icon.svg',
	'/robots.txt',
	'/200.html',
	'/404.html'
];

const SPA_PATHS = [
	'/',
	'/entrar',
	'/criar-conta',
	'/cartas/OP01-001',
	'/pasta',
	'/pasta/desejos',
	'/pasta/importar',
	'/pasta/importar/abc',
	'/baralhos',
	'/baralhos/novo',
	'/baralhos/importar',
	'/baralhos/7',
	'/baralhos/7/renomear',
	'/baralhos/7/excluir',
	'/@vite/client',
	'/src/app.html',
	'/cardsx'
];

const pattern = new RegExp(RAILS_PATH_PATTERN);

describe('RAILS_PATH_PATTERN', () => {
	it.each(RAILS_PATHS)('encaminha %s ao Rails', (path) => {
		expect(pattern.test(path)).toBe(true);
	});

	it.each(SPA_PATHS)('deixa %s para a SPA', (path) => {
		expect(pattern.test(path)).toBe(false);
	});

	describe('cada alternativa do padrão', () => {
		const group = /^\^\/\((.*)\)\(\/\|\\\?\|\$\)$/.exec(RAILS_PATH_PATTERN);
		const alternatives = group ? group[1].split('|') : [];

		it('é extraída do padrão', () => {
			expect(alternatives.length).toBeGreaterThan(0);
		});

		it.each(alternatives)('%s é necessária: sem ela algum caminho do Rails cai na SPA', (alt) => {
			const without = new RegExp(
				RAILS_PATH_PATTERN.replace(`(${alternatives.join('|')})`, `(${alternatives.filter((a) => a !== alt).join('|')})`)
			);
			expect(RAILS_PATHS.some((path) => !without.test(path))).toBe(true);
		});
	});
});
