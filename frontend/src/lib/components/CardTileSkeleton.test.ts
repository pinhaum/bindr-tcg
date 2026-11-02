import '@testing-library/jest-dom/vitest';
import { cleanup, render } from '@testing-library/svelte';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { afterEach, describe, expect, it } from 'vitest';
import CardTileSkeleton from './CardTileSkeleton.svelte';

afterEach(cleanup);

const renderTile = (): HTMLLIElement => {
	const list = document.body.appendChild(document.createElement('ul'));
	render(CardTileSkeleton, { target: list });
	return list.querySelector('li') as HTMLLIElement;
};

const styleOf = (): string => {
	const here = dirname(fileURLToPath(import.meta.url));
	const source = readFileSync(join(here, 'CardTileSkeleton.svelte'), 'utf8');
	return source.match(/<style[^>]*>([\s\S]*?)<\/style>/)?.[1] ?? '';
};

describe('CardTileSkeleton (SCAT-38)', () => {
	it('é um item de lista escondido da tecnologia assistiva', () => {
		const tile = renderTile();

		expect(tile).toBeInTheDocument();
		expect(tile).toHaveAttribute('aria-hidden', 'true');
	});

	it('não tem texto lido, link, imagem nem alvo de foco', () => {
		const tile = renderTile();

		expect(tile.textContent?.trim()).toBe('');
		expect(tile.querySelector('a, img, button, [tabindex]')).toBeNull();
	});

	it('tem o contorno do CardTile: uma arte e duas linhas de texto', () => {
		const tile = renderTile();

		expect(tile.querySelectorAll('.art')).toHaveLength(1);
		expect(tile.querySelectorAll('.line')).toHaveLength(2);
	});

	it('pulsa com --duration-slow e os quadros-chave só mexem em opacity', () => {
		const css = styleOf();

		expect(css).toMatch(/animation\s*:[^;]*var\(--duration-slow\)/);

		const body = css.match(/@keyframes\s+[\w-]+\s*\{([\s\S]*)\}\s*(?:\.|$|@)/)?.[1] ?? '';
		const properties = [...body.matchAll(/([\w-]+)\s*:[^;{}]+(?=[;}])/g)].map((m) => m[1]);
		expect(properties.length).toBeGreaterThan(0);
		expect(new Set(properties)).toEqual(new Set(['opacity']));
	});
});
