import { defineConfig } from '@playwright/test';

export default defineConfig({
	testDir: 'e2e',
	fullyParallel: false,
	workers: 1,
	forbidOnly: true,
	reporter: 'list',
	use: {
		baseURL: 'http://frontend:5173/',
		locale: 'pt-BR',
		trace: 'retain-on-failure'
	}
});
