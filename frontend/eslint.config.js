import js from '@eslint/js';
import globals from 'globals';
import svelte from 'eslint-plugin-svelte';
import tseslint from 'typescript-eslint';

export default tseslint.config(
	{ ignores: ['build/', '.svelte-kit/', 'node_modules/', 'playwright-report/', 'test-results/'] },
	js.configs.recommended,
	...tseslint.configs.recommended,
	...svelte.configs.recommended,
	{
		languageOptions: { globals: { ...globals.browser, ...globals.node } }
	},
	{
		files: ['**/*.svelte', '**/*.svelte.ts'],
		languageOptions: { parserOptions: { parser: tseslint.parser } }
	},
	{ rules: { 'no-restricted-globals': [
				'error',
				{
					name: 'fetch',
					message: 'Use o cliente de src/lib/api/client.ts; fetch só é permitido lá (SPA-06).'
				}
			] } },
	{ files: ['src/lib/api/client.ts'], rules: { 'no-restricted-globals': 'off' } }
);
