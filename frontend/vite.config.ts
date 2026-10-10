import adapter from '@sveltejs/adapter-static';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vitest/config';

export default defineConfig({
	plugins: [
		sveltekit({
			adapter: adapter({ fallback: '200.html' }),
			paths: { base: '/app' }
		})
	],
	server: {
		allowedHosts: ['localhost', 'frontend'],
		proxy: {
			// Tudo fora de /app vai ao Rails. Os internos do Vite (/@vite/client etc.)
			// ficam sob /app por causa do `base`, então não precisam de exclusão.
			// Sem changeOrigin de propósito: o Host tem de chegar ao Rails como
			// localhost:5173 para a checagem de origem do CSRF.
			'^/(?!app(/|$))': { target: 'http://app:3000' }
		}
	},
	resolve: process.env.VITEST ? { conditions: ['browser'] } : undefined,
	test: {
		environment: 'jsdom',
		include: ['src/**/*.test.ts']
	}
});
