import { describe, expect, it } from 'vitest';

describe('ambiente de teste', () => {
	it('roda em jsdom com as condições de browser', () => {
		expect(typeof document).toBe('object');
		expect(document.createElement('div')).toBeInstanceOf(HTMLElement);
	});
});
