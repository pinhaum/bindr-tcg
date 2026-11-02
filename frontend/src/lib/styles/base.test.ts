import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';

const here = dirname(fileURLToPath(import.meta.url));
const baseCss = readFileSync(join(here, 'base.css'), 'utf8').replace(/\/\*[\s\S]*?\*\//g, '');

const declarationsOf = (selector: string): Map<string, string> => {
	const escaped = selector.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
	const block = baseCss.match(new RegExp(`(?:^|\\})\\s*${escaped}\\s*\\{([^}]*)\\}`));
	expect(block, `regra ${selector} ausente em base.css`).not.toBeNull();
	return new Map(
		(block?.[1] ?? '')
			.split(';')
			.map((d) => d.trim())
			.filter(Boolean)
			.map((d) => {
				const i = d.indexOf(':');
				return [d.slice(0, i).trim(), d.slice(i + 1).trim()] as [string, string];
			})
	);
};

describe('base.css .visually-hidden', () => {
	const rule = declarationsOf('.visually-hidden');

	it('tira o elemento do fluxo sem escondê-lo das tecnologias assistivas', () => {
		expect(rule.get('position')).toBe('absolute');
		expect(rule.get('width')).toBe('1px');
		expect(rule.get('height')).toBe('1px');
		expect(rule.get('overflow')).toBe('hidden');
		expect(rule.get('clip-path')).toBe('inset(50%)');
		expect(rule.get('white-space')).toBe('nowrap');
	});

	it('zera margem, borda e padding', () => {
		expect(rule.get('margin')).toBe('0');
		expect(rule.get('border')).toBe('0');
		expect(rule.get('padding')).toBe('0');
	});

	it('não usa display:none nem visibility:hidden (a região aria-live precisa ser anunciada)', () => {
		expect(rule.has('display')).toBe(false);
		expect(rule.has('visibility')).toBe(false);
	});
});
