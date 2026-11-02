import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';

const dir = dirname(fileURLToPath(import.meta.url));
const tokensCss = readFileSync(join(dir, 'tokens.css'), 'utf8');
const baseCss = readFileSync(join(dir, 'base.css'), 'utf8');

const COLOR_TOKENS = [
	'surface-base',
	'surface-raised',
	'surface-sunken',
	'border',
	'border-strong',
	'ink',
	'ink-muted',
	'accent',
	'on-accent',
	'danger'
] as const;

const SURFACES = ['surface-base', 'surface-raised', 'surface-sunken'] as const;

const block = (css: string, selector: string): string => {
	const start = css.indexOf(`${selector} {`);
	if (start === -1) throw new Error(`Bloco ${selector} não encontrado`);
	const end = css.indexOf('}', start);
	return css.slice(start, end);
};

const declarations = (body: string): Record<string, string> =>
	Object.fromEntries(
		[...body.matchAll(/(--[\w-]+|color-scheme)\s*:\s*([^;]+);/g)].map((m) => [m[1], m[2].trim()])
	);

const themes = {
	dark: declarations(block(tokensCss, ':root[data-theme="dark"]')),
	light: declarations(block(tokensCss, ':root[data-theme="light"]'))
};

// WCAG 2.2, limiar 0.04045 (igual a test/design/contrast_test.rb)
const LINEARIZATION_THRESHOLD = 0.04045;

const channels = (hex: string): [number, number, number] => {
	const h = hex.replace(/^#/, '');
	return [0, 2, 4].map((i) => parseInt(h.slice(i, i + 2), 16) / 255) as [number, number, number];
};

const linear = (c: number): number =>
	c <= LINEARIZATION_THRESHOLD ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;

const luminance = (hex: string): number => {
	const [r, g, b] = channels(hex).map(linear);
	return 0.2126 * r + 0.7152 * g + 0.0722 * b;
};

const contrast = (a: string, b: string): number => {
	const [l1, l2] = [luminance(a), luminance(b)];
	return (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05);
};

const oklch = (hex: string): { c: number; h: number } => {
	const [r, g, b] = channels(hex).map(linear);
	const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
	const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
	const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
	const A = 1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s;
	const B = 0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s;
	return { c: Math.hypot(A, B), h: ((Math.atan2(B, A) * 180) / Math.PI + 360) % 360 };
};

const hueDistance = (a: number, b: number): number => {
	const d = Math.abs(a - b) % 360;
	return Math.min(d, 360 - d);
};

describe('fórmula de contraste', () => {
	it('preto sobre branco dá 21:1 e cor idêntica dá 1:1', () => {
		expect(contrast('#000000', '#ffffff')).toBeCloseTo(21, 1);
		expect(contrast('#ff9e14', '#ff9e14')).toBeCloseTo(1, 2);
	});
});

describe.each(['dark', 'light'] as const)('tema %s', (name) => {
	const t = themes[name];

	it('declara os dez tokens de cor como hex e color-scheme coerente', () => {
		for (const token of COLOR_TOKENS) expect(t[`--${token}`], token).toMatch(/^#[0-9a-f]{6}$/i);
		expect(t['color-scheme']).toBe(name);
	});

	it.each(SURFACES)('ink e ink-muted têm 4.5:1 sobre %s', (surface) => {
		expect(contrast(t['--ink'], t[`--${surface}`])).toBeGreaterThanOrEqual(4.5);
		expect(contrast(t['--ink-muted'], t[`--${surface}`])).toBeGreaterThanOrEqual(4.5);
	});

	it.each(SURFACES)('accent tem 4.5:1 (texto) e 3:1 (anel) sobre %s', (surface) => {
		expect(contrast(t['--accent'], t[`--${surface}`])).toBeGreaterThanOrEqual(4.5);
		expect(contrast(t['--accent'], t[`--${surface}`])).toBeGreaterThanOrEqual(3);
	});

	it.each(SURFACES)('border-strong tem 3:1 sobre %s', (surface) => {
		expect(contrast(t['--border-strong'], t[`--${surface}`])).toBeGreaterThanOrEqual(3);
	});

	it('on-accent tem 4.5:1 sobre accent e sobre danger; danger tem 4.5:1 sobre surface-base', () => {
		expect(contrast(t['--on-accent'], t['--accent'])).toBeGreaterThanOrEqual(4.5);
		expect(contrast(t['--on-accent'], t['--danger'])).toBeGreaterThanOrEqual(4.5);
		expect(contrast(t['--danger'], t['--surface-base'])).toBeGreaterThanOrEqual(4.5);
	});

	it.each(SURFACES)('danger como texto tem 4.5:1 sobre %s', (surface) => {
		expect(contrast(t['--danger'], t[`--${surface}`])).toBeGreaterThanOrEqual(4.5);
	});

	it('toda cor com croma ≥ 0.01 cai em 228°, 66° ou 28° (só danger) ± 8', () => {
		for (const token of COLOR_TOKENS) {
			const { c, h } = oklch(t[`--${token}`]);
			if (c < 0.01) continue;
			const allowed = token === 'danger' ? [28] : [228, 66];
			expect(
				allowed.some((target) => hueDistance(h, target) <= 8),
				`${token}: matiz ${h.toFixed(1)}°`
			).toBe(true);
		}
	});
});

describe('tokens.css', () => {
	it('os dois temas declaram os mesmos dez nomes mais color-scheme', () => {
		const expected = [...COLOR_TOKENS.map((t) => `--${t}`), 'color-scheme'].sort();
		expect(Object.keys(themes.dark).sort()).toEqual(expected);
		expect(Object.keys(themes.light).sort()).toEqual(expected);
	});

	it('o :root traz movimento, tipo, espaço, raio e navegação', () => {
		const root = declarations(block(tokensCss, ':root'));
		for (const name of [
			'--duration-fast',
			'--duration-base',
			'--duration-slow',
			'--ease-standard',
			'--ease-exit',
			'--font-sans',
			'--body-size',
			'--space-1',
			'--radius-md',
			'--nav-height',
			'--touch-target'
		])
			expect(root[name], name).toBeTruthy();
	});
});

describe('base.css', () => {
	it('declara o anel de foco com accent', () => {
		expect(baseCss).toMatch(/:focus-visible\s*\{[^}]*outline:\s*2px solid var\(--accent\)/);
		expect(baseCss).toMatch(/:focus-visible\s*\{[^}]*outline-offset:\s*2px/);
	});

	it('estiliza o body com tokens, sem cor literal', () => {
		const body = baseCss.match(/body\s*\{([^}]*)\}/)?.[1] ?? '';
		for (const decl of [
			'margin: 0',
			'background: var(--surface-base)',
			'color: var(--ink)',
			'font-family: var(--font-sans)',
			'font-size: var(--body-size)',
			'line-height: var(--body-line-height)'
		])
			expect(body).toContain(decl);
		expect(body).not.toMatch(/#[0-9a-f]{3,8}\b/i);
	});

	it('zera os tokens de duração e as transições sob prefers-reduced-motion', () => {
		const start = baseCss.indexOf('@media (prefers-reduced-motion: reduce)');
		expect(start).toBeGreaterThan(-1);
		const media = baseCss.slice(start);
		for (const t of ['fast', 'base', 'slow'])
			expect(media).toMatch(new RegExp(`--duration-${t}:\\s*0ms`));
		expect(media).toContain('::view-transition-group(*)');
		expect(media).toContain('::view-transition-old(*)');
		expect(media).toContain('::view-transition-new(*)');
		expect(media).toMatch(/transition-duration:\s*0s\s*!important/);
		expect(media).toMatch(/animation-duration:\s*0s\s*!important/);
	});
});
