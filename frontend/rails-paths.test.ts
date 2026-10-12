import { describe, expect, it } from 'vitest';
import { RAILS_PATH_PATTERN } from './rails-paths';

const pattern = new RegExp(RAILS_PATH_PATTERN);

describe('RAILS_PATH_PATTERN', () => {
	it.each([
		'/api/session',
		'/card_images/x',
		'/up',
		'/collection/export',
		'/decks/5.txt',
		'/catalog?x=1',
		'/cards/OP01-001',
		'/app',
		'/app/pasta',
		'/collection_items/1/increment',
		'/icon.png',
		'/404.html'
	])('encaminha %s ao Rails', (path) => {
		expect(pattern.test(path)).toBe(true);
	});

	it.each([
		'/',
		'/entrar',
		'/cartas/OP01-001',
		'/pasta',
		'/baralhos/novo',
		'/@vite/client',
		'/src/app.html',
		'/cardsx'
	])('deixa %s para a SPA', (path) => {
		expect(pattern.test(path)).toBe(false);
	});
});
