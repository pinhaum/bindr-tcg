import adapter from '@sveltejs/adapter-static';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vitest/config';
import { RAILS_PATH_PATTERN } from './rails-paths';

export default defineConfig({
	plugins: [
		sveltekit({
			adapter: adapter({ fallback: '200.html' })
		})
	],
	server: {
		allowedHosts: ['localhost', 'frontend'],
		proxy: {
			// Só a lista fechada do STRO-08 vai ao Rails; o resto é da SPA e do Vite.
			// Sem changeOrigin de propósito: o Host tem de chegar ao Rails como
			// localhost:5173 para a checagem de origem do CSRF.
			[RAILS_PATH_PATTERN]: { target: 'http://app:3000' }
		}
	},
	resolve: process.env.VITEST ? { conditions: ['browser'] } : undefined,
	test: {
		environment: 'jsdom',
		include: ['src/**/*.test.ts']
	}
});
