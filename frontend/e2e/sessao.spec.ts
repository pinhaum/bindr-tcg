import { expect, test, type Page } from '@playwright/test';

const PASSWORD = 'senha-correta-1';
const WRONG_PASSWORD = 'senha-errada-99';

type Combo = { name: string; width: number; height: number; scheme: 'light' | 'dark' };

const COMBOS: Combo[] = [
	{ name: '360x740 claro', width: 360, height: 740, scheme: 'light' },
	{ name: '360x740 escuro', width: 360, height: 740, scheme: 'dark' },
	{ name: '1280x800 claro', width: 1280, height: 800, scheme: 'light' },
	{ name: '1280x800 escuro', width: 1280, height: 800, scheme: 'dark' }
];

async function expectNoHorizontalScroll(page: Page, where: string) {
	const { scrollWidth, clientWidth } = await page.evaluate(() => ({
		scrollWidth: document.documentElement.scrollWidth,
		clientWidth: document.documentElement.clientWidth
	}));
	expect(scrollWidth, `scroll horizontal em ${where}`).toBeLessThanOrEqual(clientWidth);
}

async function expectTheme(page: Page, scheme: Combo['scheme'], where: string) {
	expect(await page.locator('html').getAttribute('data-theme'), `data-theme em ${where}`).toBe(scheme);
}

async function expectLayout(page: Page, combo: Combo, where: string) {
	await expectNoHorizontalScroll(page, where);
	await expectTheme(page, combo.scheme, where);
}

const mainNav = (page: Page) => page.getByRole('navigation', { name: 'Principal' });

const signOut = (page: Page) => mainNav(page).getByRole('button', { name: 'Sair' }).click();

async function expectSignedIn(page: Page) {
	await expect(mainNav(page).getByRole('button', { name: 'Sair' })).toBeVisible();
	await expect(mainNav(page).getByRole('link', { name: 'Entrar', exact: true })).toHaveCount(0);
}

async function expectSignedOut(page: Page) {
	await expect(mainNav(page).getByRole('link', { name: 'Entrar', exact: true })).toBeVisible();
	await expect(mainNav(page).getByRole('button', { name: 'Sair' })).toHaveCount(0);
}

async function expectNavOnTop(page: Page, name: string) {
	const entry = mainNav(page).getByRole('button', { name });
	await entry.scrollIntoViewIfNeeded();
	// Repete: durante uma view transition o hit-test cai em <html>; coberto de verdade fica coberto.
	await expect
		.poll(
			() =>
				entry.evaluate((el) => {
					const { x, y, width, height } = el.getBoundingClientRect();
					const hit = document.elementFromPoint(x + width / 2, y + height / 2);
					return hit !== null && el.contains(hit) ? 'ok' : `${hit?.tagName}.${hit?.className}`;
				}),
			{ message: `"${name}" não está coberto pelo conteúdo` }
		)
		.toBe('ok');
}

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

async function signIn(page: Page, email: string, password: string) {
	await page.getByLabel('E-mail').fill(email);
	await page.getByLabel('Senha', { exact: true }).fill(password);
	await page.getByRole('button', { name: 'Entrar' }).click();
}

for (const combo of COMBOS) {
	test.describe(`jornada de sessão contra a API real — ${combo.name}`, () => {
		test.use({ viewport: { width: combo.width, height: combo.height }, colorScheme: combo.scheme });

		test('criar conta, sair, senha errada, entrar, sair', async ({ page }) => {
			const email = `e2e-${Date.now()}-${combo.width}-${combo.scheme}@exemplo.test`;
			const bad = trackBadResponses(page);

			await test.step('criar conta leva a /app com o e-mail (SPA-14, SPA-18, SPA-23)', async () => {
				await page.goto('criar-conta');
				await expectLayout(page, combo, '/criar-conta');
				await page.getByLabel('E-mail').fill(email);
				await page.getByLabel('Senha', { exact: true }).fill(PASSWORD);
				await page.getByLabel('Confirmação da senha').fill(PASSWORD);
				await page.getByRole('button', { name: 'Criar conta' }).click();

				await expect(page).toHaveURL(/\/app\/?$/);
				await expectSignedIn(page);
				await expectLayout(page, combo, '/ com sessão');
				await expectNavOnTop(page, 'Sair');
			});

			await test.step('sair mostra a mensagem e volta a anônimo (SPA-22)', async () => {
				await signOut(page);

				const message = page.getByText('Sessão encerrada.', { exact: true });
				await expect(message).toBeVisible();
				await expect(page).toHaveURL(/\/app\/?$/);
				await expectSignedOut(page);
				await expectLayout(page, combo, '/ após sair');

				// Só posição e largura: a altura de main acompanha a grade do catálogo, que recarrega ao sair.
				const anchor = async () => {
					const { x, y, width } = (await page.locator('main#conteudo').boundingBox())!;
					return { x, y, width };
				};
				await expect(page.locator('.layer')).toHaveCSS('position', 'fixed');
				const withMessage = await anchor();
				await expect(message).toHaveCount(0, { timeout: 10_000 });
				expect(await anchor(), 'a mensagem não desloca o conteúdo (SPA-46)').toEqual(withMessage);
			});

			await test.step('senha errada mostra o erro, mantém o e-mail e foca o bloco (SPA-17)', async () => {
				await page.goto('entrar');
				await expectLayout(page, combo, '/entrar');
				await signIn(page, email, WRONG_PASSWORD);

				const alert = page.getByRole('alert').filter({ hasText: 'E-mail ou senha inválidos.' });
				await expect(alert).toBeVisible();
				await expect(alert).toBeFocused();
				await expect(page.getByLabel('E-mail')).toHaveValue(email);
				await expect(page.getByLabel('Senha', { exact: true })).toHaveValue('');
				await expect(page).toHaveURL(/\/app\/entrar$/);
				await expectLayout(page, combo, '/entrar com erro');
			});

			await test.step('senha certa leva a /app com o e-mail (SPA-16)', async () => {
				await page.getByLabel('Senha', { exact: true }).fill(PASSWORD);
				await page.getByRole('button', { name: 'Entrar' }).click();

				await expect(page).toHaveURL(/\/app\/?$/);
				await expectSignedIn(page);
				await expectLayout(page, combo, '/ após entrar');
			});

			await test.step('com sessão, /entrar e /criar-conta voltam a /app sem formulário (SPA-24)', async () => {
				await page.goto('entrar?return_to=/app/criar-conta');
				await expect(page).toHaveURL(/\/app\/?$/);
				await expectSignedIn(page);

				await page.goto('criar-conta');
				await expect(page).toHaveURL(/\/app\/?$/);
				await expect(page.getByLabel('Confirmação da senha')).toHaveCount(0);
				await expectLayout(page, combo, '/ após redirecionar de /criar-conta');
			});

			await test.step('a sessão sobrevive a recarregar a página (SPA-14)', async () => {
				await page.reload();
				await expectSignedIn(page);
				await expectLayout(page, combo, '/ após recarregar');
			});

			await test.step('sair de novo encerra a sessão (SPA-22)', async () => {
				await signOut(page);

				await expect(page.getByText('Sessão encerrada.', { exact: true })).toBeVisible();
				await expectSignedOut(page);
				await expectLayout(page, combo, '/ após sair no fim');
			});

			expect(bad, 'nenhuma resposta 406 nem 5xx').toEqual([]);
		});
	});
}

test('return_to externo é descartado e o destino é /app (SPA-23)', async ({ page }) => {
	const email = `e2e-${Date.now()}-rt@exemplo.test`;
	const bad = trackBadResponses(page);

	await page.goto('criar-conta');
	await page.getByLabel('E-mail').fill(email);
	await page.getByLabel('Senha', { exact: true }).fill(PASSWORD);
	await page.getByLabel('Confirmação da senha').fill(PASSWORD);
	await page.getByRole('button', { name: 'Criar conta' }).click();
	await expectSignedIn(page);
	await signOut(page);
	await expect(page.getByText('Sessão encerrada.', { exact: true })).toBeVisible();

	await page.goto('entrar?return_to=%2F%2Fexemplo.test%2Fapp');
	await signIn(page, email, PASSWORD);
	await expect(page).toHaveURL(/^http:\/\/frontend:5173\/app\/?$/);
	await expectSignedIn(page);

	expect(bad, 'nenhuma resposta 406 nem 5xx').toEqual([]);
});
