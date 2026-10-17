import { readdirSync, readFileSync } from 'node:fs';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';

const here = dirname(fileURLToPath(import.meta.url));
const srcDir = join(here, '..', '..');
const tokensCss = readFileSync(join(here, 'tokens.css'), 'utf8');

const tokenPx = [...new Set([...tokensCss.matchAll(/(?<![\w.])(\d+)px\b/g)].map((m) => m[1]))];
const TOKEN_PX = new RegExp(`(?<![\\w.])(?:${tokenPx.join('|')})px\\b`);
const HEX = /#[0-9a-fA-F]{3,8}\b/;
const ANIMATABLE = new Set(['transform', 'opacity', 'none']);

const walk = (dir: string): string[] =>
	readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
		const path = join(dir, entry.name);
		if (entry.isDirectory()) return walk(path);
		return /\.(svelte|css)$/.test(entry.name) && entry.name !== 'tokens.css' ? [path] : [];
	});

const stylesOf = (file: string): string => {
	const source = readFileSync(file, 'utf8');
	const css = file.endsWith('.svelte')
		? [...source.matchAll(/<style[^>]*>([\s\S]*?)<\/style>/g)].map((m) => m[1]).join('\n')
		: source;
	return css.replace(/\/\*[\s\S]*?\*\//g, '');
};

const animatedProperties = (css: string): string[] => {
	const props: string[] = [];
	for (const m of css.matchAll(/(?<![\w-])transition(?:-property)?\s*:\s*([^;}]+)/g)) {
		for (const part of m[1].split(',')) {
			const name = part.trim().split(/\s+/)[0];
			if (name) props.push(name);
		}
	}
	for (const m of css.matchAll(/@keyframes\s+[\w-]+\s*\{/g)) {
		let depth = 1;
		let i = m.index + m[0].length;
		const start = i;
		for (; i < css.length && depth > 0; i++) {
			if (css[i] === '{') depth++;
			else if (css[i] === '}') depth--;
		}
		for (const d of css.slice(start, i).matchAll(/([\w-]+)\s*:[^;{}]+(?=[;}])/g)) {
			if (d[1] !== 'animation-timing-function') props.push(d[1]);
		}
	}
	return props;
};

const files = walk(srcDir).map((file) => ({ file: relative(srcDir, file), css: stylesOf(file) }));

describe('guarda de tokens e animação (SPA-31, SPA-41)', () => {
	it('encontra arquivos e valores de token para varrer', () => {
		expect(files.length).toBeGreaterThan(5);
		expect(tokenPx).toEqual(expect.arrayContaining(['44', '8', '16']));
	});

	it.each(files)('$file não repete valor px de token nem hex', ({ css }) => {
		expect(css.match(TOKEN_PX)?.[0]).toBeUndefined();
		expect(css.match(HEX)?.[0]).toBeUndefined();
	});

	it.each(files)('$file anima só transform e opacity', ({ css }) => {
		const offenders = animatedProperties(css).filter((p) => !ANIMATABLE.has(p));
		expect(offenders).toEqual([]);
	});
});
