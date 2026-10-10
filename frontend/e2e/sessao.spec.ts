import { expect, test, type Page } from '@playwright/test';

const PASSWORD = 'senha-correta-1';
const WRONG_PASSWORD = 'senha-errada-99';

function trackBadResponses(page: Page) {
	const bad: string[] = [];
	page.on('response', (response) => {
		const status = response.status();
		if (status === 406 || status >= 500) bad.push(`${status} ${response.request().method()} ${response.url()}`);
	});
	return bad;
}

async function signIn(page: Page, email: string, password: string) {
	await page.getByLabel('E-mail').fill(email);
	await page.getByLabel('Senha', { exact: true }).fill(password);
	await page.getByRole('button', { name: 'Entrar' }).click();
}

test('jornada de sessão contra a API real', async ({ page }) => {
	const email = `e2e-${Date.now()}@exemplo.test`;
	const bad = trackBadResponses(page);

	await test.step('criar conta leva a /app com o e-mail (SPA-14, SPA-18, SPA-23)', async () => {
		await page.goto('criar-conta');
		await page.getByLabel('E-mail').fill(email);
		await page.getByLabel('Senha', { exact: true }).fill(PASSWORD);
		await page.getByLabel('Confirmação da senha').fill(PASSWORD);
		await page.getByRole('button', { name: 'Criar conta' }).click();

		await expect(page).toHaveURL(/\/app\/?$/);
		await expect(page.getByRole('main').getByText(email, { exact: true })).toBeVisible();
	});

	await test.step('sair mostra a mensagem e volta a anônimo (SPA-22)', async () => {
		await page.getByRole('button', { name: 'Sair' }).click();

		await expect(page.getByText('Sessão encerrada.', { exact: true })).toBeVisible();
		await expect(page).toHaveURL(/\/app\/?$/);
		await expect(page.getByText(email)).toHaveCount(0);
	});

	await test.step('senha errada mostra o erro, mantém o e-mail e foca o bloco (SPA-17)', async () => {
		await page.goto('entrar');
		await signIn(page, email, WRONG_PASSWORD);

		const alert = page.getByRole('alert').filter({ hasText: 'E-mail ou senha inválidos.' });
		await expect(alert).toBeVisible();
		await expect(alert).toBeFocused();
		await expect(page.getByLabel('E-mail')).toHaveValue(email);
		await expect(page.getByLabel('Senha', { exact: true })).toHaveValue('');
		await expect(page).toHaveURL(/\/app\/entrar$/);
	});

	await test.step('senha certa leva a /app com o e-mail (SPA-16)', async () => {
		await page.getByLabel('Senha', { exact: true }).fill(PASSWORD);
		await page.getByRole('button', { name: 'Entrar' }).click();

		await expect(page).toHaveURL(/\/app\/?$/);
		await expect(page.getByRole('main').getByText(email, { exact: true })).toBeVisible();
	});

	await test.step('com sessão, /entrar e /criar-conta voltam a /app sem formulário (SPA-24)', async () => {
		await page.goto('entrar?return_to=/app/criar-conta');
		await expect(page).toHaveURL(/\/app\/?$/);
		await expect(page.getByRole('main').getByText(email, { exact: true })).toBeVisible();

		await page.goto('criar-conta');
		await expect(page).toHaveURL(/\/app\/?$/);
		await expect(page.getByLabel('Confirmação da senha')).toHaveCount(0);
	});

	await test.step('a sessão sobrevive a recarregar a página (SPA-14)', async () => {
		await page.reload();
		await expect(page.getByRole('main').getByText(email, { exact: true })).toBeVisible();
	});

	expect(bad, 'nenhuma resposta 406 nem 5xx').toEqual([]);
});

test('return_to externo é descartado e o destino é /app (SPA-23)', async ({ page }) => {
	const email = `e2e-${Date.now()}-rt@exemplo.test`;
	const bad = trackBadResponses(page);

	await page.goto('criar-conta');
	await page.getByLabel('E-mail').fill(email);
	await page.getByLabel('Senha', { exact: true }).fill(PASSWORD);
	await page.getByLabel('Confirmação da senha').fill(PASSWORD);
	await page.getByRole('button', { name: 'Criar conta' }).click();
	await expect(page.getByRole('main').getByText(email, { exact: true })).toBeVisible();
	await page.getByRole('button', { name: 'Sair' }).click();
	await expect(page.getByText('Sessão encerrada.', { exact: true })).toBeVisible();

	await page.goto('entrar?return_to=%2F%2Fexemplo.test%2Fapp');
	await signIn(page, email, PASSWORD);
	await expect(page).toHaveURL(/^http:\/\/frontend:5173\/app\/?$/);
	await expect(page.getByRole('main').getByText(email, { exact: true })).toBeVisible();

	expect(bad, 'nenhuma resposta 406 nem 5xx').toEqual([]);
});
