import { expect, test, type Page } from '@playwright/test';

const DARK_BG = 'rgb(5, 27, 35)'; // --surface-base escuro (#051b23)
const LIGHT_BG = 'rgb(242, 248, 251)'; // --surface-base claro (#f2f8fb)
const DESKTOP_MIN_WIDTH = 1024; // 64rem
const TOUCH_TARGET = 44;
const UNPAINTED_BG = 'rgba(0, 0, 0, 0)';

type ThemeProbe = { themes: string[]; firstFrame: { theme: string | null; colorScheme: string; bodyBg: string } | null };

function trackBadResponses(page: Page) {
	const bad: string[] = [];
	page.on('response', (response) => {
		const status = response.status();
		// A arte vem de um CDN externo e responde 502 quando ele recusa (403); a SPA mostra o placeholder (SCAT-11).
		if (new URL(response.url()).pathname.startsWith('/card_images/')) return;
		if (status === 406 || status >= 500) bad.push(`${status} ${response.request().method()} ${response.url()}`);
	});
	return bad;
}

function trackConsoleErrors(page: Page) {
	const errors: string[] = [];
	page.on('console', (message) => {
		if (message.type() === 'error') errors.push(`console: ${message.text()}`);
	});
	page.on('pageerror', (error) => errors.push(`pageerror: ${error.message}`));
	return errors;
}

async function openApp(page: Page, path = '') {
	await page.goto(path);
	await expect(page.getByRole('navigation', { name: 'Principal' })).toBeVisible();
}

// Roda antes de qualquer script da página (inclusive o inline de app.html e o do Kit):
// registra todo valor de data-theme do <html> e, no primeiro quadro, o tema e o fundo do body.
async function installThemeProbe(page: Page, storedPreference?: string) {
	await page.addInitScript((stored) => {
		if (stored !== undefined) localStorage.setItem('bindr-theme', stored);

		const probe: ThemeProbe = { themes: [], firstFrame: null };
		(window as unknown as { __themeProbe: ThemeProbe }).__themeProbe = probe;
		// o <html> ainda não existe quando este script roda: observa o documento inteiro
		const currentTheme = () => document.documentElement?.getAttribute('data-theme') ?? null;
		const record = () => {
			const theme = currentTheme();
			if (theme && probe.themes[probe.themes.length - 1] !== theme) probe.themes.push(theme);
		};
		new MutationObserver(record).observe(document, { subtree: true, childList: true, attributes: true, attributeFilter: ['data-theme'] });
		requestAnimationFrame(() => {
			record();
			probe.firstFrame = {
				theme: currentTheme(),
				colorScheme: getComputedStyle(document.documentElement).colorScheme,
				bodyBg: document.body ? getComputedStyle(document.body).backgroundColor : ''
			};
		});
	}, storedPreference);
}

// No dev server o Vite injeta o CSS por JS: no primeiro quadro o body ainda pode estar sem pintura
// (fundo transparente, color-scheme "normal"). O que nunca pode aparecer é o outro tema.
function expectFirstFrameNeverOtherTheme(probe: ThemeProbe, theme: string, expectedBg: string) {
	expect([theme, 'normal'], 'color-scheme do primeiro quadro').toContain(probe.firstFrame?.colorScheme);
	expect([expectedBg, UNPAINTED_BG], 'fundo do body no primeiro quadro').toContain(probe.firstFrame?.bodyBg);
}

async function readThemeProbe(page: Page): Promise<ThemeProbe> {
	await page.waitForFunction(() => (window as unknown as { __themeProbe: ThemeProbe }).__themeProbe.firstFrame !== null);
	return page.evaluate(() => (window as unknown as { __themeProbe: ThemeProbe }).__themeProbe);
}

async function countViewTransitions(page: Page) {
	await page.addInitScript(() => {
		const w = window as unknown as { __viewTransitions: number };
		w.__viewTransitions = 0;
		const original = document.startViewTransition?.bind(document);
		if (!original) return;
		document.startViewTransition = ((callback) => {
			w.__viewTransitions++;
			return original(callback);
		}) as typeof document.startViewTransition;
	});
}

const viewTransitions = (page: Page) => page.evaluate(() => (window as unknown as { __viewTransitions: number }).__viewTransitions);
const marker = (page: Page) => page.evaluate(() => (window as unknown as { __marker?: string }).__marker);
const setMarker = (page: Page) => page.evaluate(() => ((window as unknown as { __marker: string }).__marker = 'mesma-pagina'));
const dataTheme = (page: Page) => page.locator('html').getAttribute('data-theme');
const bodyBackground = (page: Page) => page.evaluate(() => getComputedStyle(document.body).backgroundColor);
const navPosition = (page: Page) => page.locator('.nav').evaluate((el) => getComputedStyle(el).position);
const mainNav = (page: Page) => page.getByRole('navigation', { name: 'Principal' });

for (const viewport of [
	{ name: '360px', width: 360, height: 740 },
	{ name: '1280px', width: 1280, height: 800 }
]) {
	test.describe(`casco a ${viewport.name}`, () => {
		test.use({ viewport: { width: viewport.width, height: viewport.height } });
		const desktop = viewport.width >= DESKTOP_MIN_WIDTH;

		test('posição da navegação e conteúdo sem scroll horizontal (SPA-28, SPA-29, SPA-30)', async ({ page }) => {
			const bad = trackBadResponses(page);
			for (const path of ['', 'entrar', 'criar-conta']) {
				await openApp(page, path);

				const overflow = await page.evaluate(() => ({
					scrollWidth: document.documentElement.scrollWidth,
					clientWidth: document.documentElement.clientWidth
				}));
				expect(overflow.scrollWidth, `scroll horizontal em /${path}`).toBeLessThanOrEqual(overflow.clientWidth);
			}

			await openApp(page);
			const nav = (await page.locator('.nav').boundingBox())!;
			const brand = (await page.locator('header.brand').boundingBox())!;
			const main = (await page.locator('main#conteudo').boundingBox())!;

			if (desktop) {
				expect(nav.x, 'coluna lateral à esquerda').toBe(0);
				expect(nav.width, 'largura fixa da coluna').toBeLessThanOrEqual(280);
				expect(nav.y, 'logo abaixo da marca').toBeGreaterThanOrEqual(brand.y + brand.height - 1);
				expect(main.x, 'conteúdo ao lado da coluna').toBeGreaterThanOrEqual(nav.x + nav.width);
				expect(await navPosition(page)).not.toBe('fixed');
				const column = await page.locator('.nav').evaluate((el) => {
					const style = getComputedStyle(el);
					return { borderRight: style.borderRightWidth, background: style.backgroundColor };
				});
				expect(column.borderRight, 'borda separando coluna e conteúdo').toBe('1px');
				expect(column.background, 'superfície elevada').not.toBe(await bodyBackground(page));
			} else {
				expect(nav.y + nav.height, 'barra colada na borda inferior').toBeCloseTo(viewport.height, 0);
				expect(nav.width, 'barra em toda a largura').toBeCloseTo(viewport.width, 0);
				expect(await navPosition(page)).toBe('fixed');

				const links = await mainNav(page).getByRole('link').all();
				const widths = await Promise.all(links.map(async (link) => (await link.boundingBox())!.width));
				for (const width of widths) expect(width, 'entradas de largura igual').toBeCloseTo(widths[0], 0);

				const reserved = await page.locator('main#conteudo').evaluate((el) => parseFloat(getComputedStyle(el).paddingBottom));
				expect(reserved, 'conteúdo reserva a altura medida da barra').toBeGreaterThanOrEqual(nav.height);
			}
			expect(bad, 'nenhuma resposta 406 nem 5xx').toEqual([]);
		});

		test('alvos de toque têm no mínimo 44px (SPA-28, SPA-30)', async ({ page }) => {
			await openApp(page);
			const targets = page.locator('header.brand select, header.brand button, nav[aria-label="Principal"] a, nav[aria-label="Principal"] button');
			const count = await targets.count();
			expect(count).toBeGreaterThanOrEqual(4); // seletor de tema + Catálogo, Entrar, Criar conta

			for (let index = 0; index < count; index++) {
				const target = targets.nth(index);
				const box = (await target.boundingBox())!;
				const name = await target.evaluate((el) => el.textContent?.trim() || el.tagName);
				expect(box.height, `altura de "${name}"`).toBeGreaterThanOrEqual(TOUCH_TARGET);
				expect(box.width, `largura de "${name}"`).toBeGreaterThanOrEqual(TOUCH_TARGET);
			}
		});

		test('marca só a entrada da rota atual com aria-current (SPA-27)', async ({ page }) => {
			const nav = mainNav(page);

			await openApp(page, 'entrar');
			await expect(nav.getByRole('link', { name: 'Entrar' })).toHaveAttribute('aria-current', 'page');
			await expect(nav.getByRole('link', { name: 'Criar conta' })).not.toHaveAttribute('aria-current');
			await expect(nav.getByRole('link', { name: 'Catálogo' })).not.toHaveAttribute('aria-current');

			await nav.getByRole('link', { name: 'Criar conta' }).click();
			await expect(page).toHaveURL(/\/criar-conta$/);
			await expect(nav.getByRole('link', { name: 'Criar conta' })).toHaveAttribute('aria-current', 'page');
			await expect(nav.getByRole('link', { name: 'Entrar' })).not.toHaveAttribute('aria-current');

			const look = (name: string) =>
				nav.getByRole('link', { name }).evaluate((el) => {
					const style = getComputedStyle(el);
					return { background: style.backgroundColor, weight: Number(style.fontWeight) };
				});
			const current = await look('Criar conta');
			const other = await look('Entrar');
			expect(current.background, 'fundo distingue a entrada atual').not.toBe(other.background);
			expect(current.weight, 'peso distingue a entrada atual').toBeGreaterThan(other.weight);
		});
	});
}

test('cruzar 64rem muda o layout sem recarregar nem perder o foco (SPA-28, SPA-29)', async ({ page }) => {
	await page.setViewportSize({ width: 1280, height: 800 });
	await openApp(page, 'entrar');
	await setMarker(page);

	const link = mainNav(page).getByRole('link', { name: 'Criar conta' });
	await link.focus();
	await expect(link).toBeFocused();
	expect(await navPosition(page)).not.toBe('fixed');

	await page.setViewportSize({ width: DESKTOP_MIN_WIDTH - 1, height: 800 });
	await expect.poll(() => navPosition(page)).toBe('fixed');
	await expect(link).toBeFocused();
	expect(await marker(page)).toBe('mesma-pagina');

	await page.setViewportSize({ width: DESKTOP_MIN_WIDTH, height: 800 });
	await expect.poll(() => navPosition(page)).not.toBe('fixed');
	await expect(link).toBeFocused();
	expect(await marker(page)).toBe('mesma-pagina');
});

test.describe('temas', () => {
	for (const [scheme, expectedBg] of [
		['dark', DARK_BG],
		['light', LIGHT_BG]
	] as const) {
		test(`sem preferência guardada segue o sistema ${scheme} já no primeiro quadro (SPA-35, SPA-37)`, async ({ page }) => {
			await page.emulateMedia({ colorScheme: scheme });
			await installThemeProbe(page);
			await openApp(page);

			const probe = await readThemeProbe(page);
			expect(probe.themes, 'o <html> nunca exibe o outro tema').toEqual([scheme]);
			expect(probe.firstFrame?.theme).toBe(scheme);
			expectFirstFrameNeverOtherTheme(probe, scheme, expectedBg);
			expect(await bodyBackground(page)).toBe(expectedBg);
		});
	}

	test('com "Sistema" acompanha a mudança do sistema sem recarregar (SPA-35)', async ({ page }) => {
		await page.emulateMedia({ colorScheme: 'light' });
		await openApp(page);
		await setMarker(page);
		expect(await dataTheme(page)).toBe('light');

		await page.emulateMedia({ colorScheme: 'dark' });
		await expect.poll(() => dataTheme(page)).toBe('dark');
		expect(await bodyBackground(page)).toBe(DARK_BG);
		expect(await marker(page)).toBe('mesma-pagina');
	});

	for (const [stored, systemScheme, expectedTheme, expectedBg] of [
		['light', 'dark', 'light', LIGHT_BG],
		['dark', 'light', 'dark', DARK_BG],
		['system', 'dark', 'dark', DARK_BG],
		['valor-invalido', 'light', 'light', LIGHT_BG],
		['valor-invalido', 'dark', 'dark', DARK_BG]
	] as const) {
		test(`localStorage "${stored}" com sistema ${systemScheme} aplica ${expectedTheme} no primeiro quadro (SPA-36, SPA-37)`, async ({ page }) => {
			await page.emulateMedia({ colorScheme: systemScheme });
			await installThemeProbe(page, stored);
			await openApp(page);

			const probe = await readThemeProbe(page);
			expect(probe.themes, 'o <html> nunca exibe o outro tema').toEqual([expectedTheme]);
			expect(probe.firstFrame?.theme).toBe(expectedTheme);
			expectFirstFrameNeverOtherTheme(probe, expectedTheme, expectedBg);
			expect(await page.getByLabel('Tema').inputValue()).toBe(stored === 'light' || stored === 'dark' ? stored : 'system');
		});
	}

	test('trocar no seletor muda o fundo na hora, persiste após recarregar e "Sistema" volta a seguir o sistema (SPA-35, SPA-36)', async ({
		page
	}) => {
		await page.emulateMedia({ colorScheme: 'dark' });
		await openApp(page);
		expect(await bodyBackground(page)).toBe(DARK_BG);

		await page.getByLabel('Tema').selectOption({ label: 'Claro' });
		await expect.poll(() => bodyBackground(page)).toBe(LIGHT_BG);
		expect(await dataTheme(page)).toBe('light');
		expect(await page.evaluate(() => localStorage.getItem('bindr-theme'))).toBe('light');

		await page.reload();
		await expect(page.getByLabel('Tema')).toHaveValue('light');
		expect(await dataTheme(page)).toBe('light');
		expect(await bodyBackground(page)).toBe(LIGHT_BG);

		await page.getByLabel('Tema').selectOption({ label: 'Escuro' });
		await page.emulateMedia({ colorScheme: 'light' });
		await expect.poll(() => bodyBackground(page)).toBe(DARK_BG);
		expect(await page.evaluate(() => localStorage.getItem('bindr-theme'))).toBe('dark');

		await page.reload();
		await expect(page.getByLabel('Tema')).toHaveValue('dark');
		expect(await bodyBackground(page)).toBe(DARK_BG);

		await page.getByLabel('Tema').selectOption({ label: 'Sistema' });
		await expect.poll(() => bodyBackground(page)).toBe(LIGHT_BG);
		await page.emulateMedia({ colorScheme: 'dark' });
		await expect.poll(() => bodyBackground(page)).toBe(DARK_BG);
		expect(await dataTheme(page)).toBe('dark');
		expect(await page.evaluate(() => localStorage.getItem('bindr-theme'))).toBe('system');
	});
});

test.describe('movimento', () => {
	// O elemento de prova declara transição e animação longas em estilo inline;
	// só o !important do corte por preferência (base.css) consegue zerá-las.
	const probeDurations = (page: Page) =>
		page.evaluate(() => {
			const el = document.createElement('div');
			el.style.cssText = 'transition: opacity 1s; animation: none 1s;';
			document.body.append(el);
			const style = getComputedStyle(el);
			const result = { transition: style.transitionDuration, animation: style.animationDuration };
			el.remove();
			const root = getComputedStyle(document.documentElement);
			return {
				...result,
				fast: root.getPropertyValue('--duration-fast').trim(),
				base: root.getPropertyValue('--duration-base').trim(),
				slow: root.getPropertyValue('--duration-slow').trim()
			};
		});

	test('com reduced motion todas as durações leem zero (SPA-42)', async ({ page }) => {
		await page.emulateMedia({ reducedMotion: 'reduce' });
		await openApp(page);

		expect(await probeDurations(page)).toEqual({ transition: '0s', animation: '0s', fast: '0ms', base: '0ms', slow: '0ms' });
	});

	test('sem reduced motion a prova e os tokens mantêm o valor declarado (controle de SPA-42)', async ({ page }) => {
		await page.emulateMedia({ reducedMotion: 'no-preference' });
		await openApp(page);

		expect(await probeDurations(page)).toEqual({ transition: '1s', animation: '1s', fast: '120ms', base: '200ms', slow: '320ms' });
	});

	test('a navegação entre rotas usa View Transition sem erro (SPA-43)', async ({ page }) => {
		const errors = trackConsoleErrors(page);
		const bad = trackBadResponses(page);
		await page.emulateMedia({ reducedMotion: 'no-preference' });
		await countViewTransitions(page);
		await openApp(page, 'entrar');
		expect(await page.evaluate(() => typeof document.startViewTransition)).toBe('function');

		await mainNav(page).getByRole('link', { name: 'Criar conta' }).click();
		await expect(page).toHaveURL(/\/criar-conta$/);
		await expect(page.getByRole('heading', { name: 'Criar conta' })).toBeVisible();

		expect(await viewTransitions(page)).toBeGreaterThanOrEqual(1);
		expect(errors, 'nenhum erro no console').toEqual([]);
		expect(bad, 'nenhuma resposta 406 nem 5xx').toEqual([]);
	});

	test('com reduced motion a navegação troca a rota sem View Transition (SPA-42, SPA-43)', async ({ page }) => {
		const errors = trackConsoleErrors(page);
		await page.emulateMedia({ reducedMotion: 'reduce' });
		await countViewTransitions(page);
		await openApp(page, 'entrar');

		await mainNav(page).getByRole('link', { name: 'Criar conta' }).click();
		await expect(page).toHaveURL(/\/criar-conta$/);
		await expect(page.getByRole('heading', { name: 'Criar conta' })).toBeVisible();

		expect(await viewTransitions(page)).toBe(0);
		expect(errors, 'nenhum erro no console').toEqual([]);
	});

	test('sem suporte a startViewTransition a rota troca sem transição e sem erro (SPA-43)', async ({ page }) => {
		const errors = trackConsoleErrors(page);
		await page.emulateMedia({ reducedMotion: 'no-preference' });
		await page.addInitScript(() => {
			Object.defineProperty(document, 'startViewTransition', { value: undefined, configurable: true });
		});
		await openApp(page, 'entrar');
		expect(await page.evaluate(() => document.startViewTransition)).toBeUndefined();

		await mainNav(page).getByRole('link', { name: 'Criar conta' }).click();
		await expect(page).toHaveURL(/\/criar-conta$/);
		await expect(page.getByRole('heading', { name: 'Criar conta' })).toBeVisible();

		expect(errors, 'nenhum erro no console').toEqual([]);
	});
});
