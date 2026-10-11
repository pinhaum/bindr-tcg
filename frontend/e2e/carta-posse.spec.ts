import { expect, test, type APIRequestContext, type Locator, type Page } from '@playwright/test';

type Variant = { variant_code: string; in_source: boolean; owned_quantity?: number | null };
type Card = { card_number: string; name: string; variants: Variant[] };
type Picked = { card: Card; code: string };

const PASSWORD = 'senha-correta-1';
const NETWORK_ERROR = 'Sem conexão com o servidor. Tente novamente.';
const NOTHING_TO_REMOVE = 'Você não tem cópias desta variante para remover.';
const PIXEL_PNG = Buffer.from(
	'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
	'base64'
);
const INCREMENT = /\/variants\/[^/]+\/increment$/;
const VARIANT_CALL = /\/variants\//;
const RESPONSE_DELAY_MS = 600;

test.use({ viewport: { width: 1280, height: 800 } });

let pickedPromise: Promise<Picked> | undefined;
const pickCard = (request: APIRequestContext) =>
	(pickedPromise ??= (async () => {
		const response = await request.get('/api/catalog?per_page=50');
		expect(response.ok(), 'GET /api/catalog').toBe(true);
		const { data } = (await response.json()) as { data: Card[] };
		for (const card of data) {
			const variant = card.variants.find((item) => item.in_source);
			if (variant) return { card, code: variant.variant_code };
		}
		throw new Error('nenhuma carta do catálogo importado tem variante na fonte');
	})());

// O CDN da arte responde 403 (a pilha devolve 502): a rota devolve uma imagem mínima.
const stubImages = (page: Page) =>
	page.route('**/card_images/**', (route) =>
		route.fulfill({ status: 200, contentType: 'image/png', body: PIXEL_PNG })
	);

const mainNav = (page: Page) => page.getByRole('navigation', { name: 'Principal' });

let accountSeq = 0;
async function createAccount(page: Page) {
	const email = `e2e-${Date.now()}-posse-${accountSeq++}@exemplo.test`;
	await page.goto('criar-conta');
	await page.getByLabel('E-mail').fill(email);
	await page.getByLabel('Senha', { exact: true }).fill(PASSWORD);
	await page.getByLabel('Confirmação da senha').fill(PASSWORD);
	await page.getByRole('button', { name: 'Criar conta' }).click();
	await expect(page).toHaveURL(/\/app\/?$/);
	await expect(mainNav(page).getByRole('button', { name: 'Sair' })).toBeVisible();
}

const detailPath = ({ card, code }: Picked) =>
	`/app/cartas/${encodeURIComponent(card.card_number)}?variant=${encodeURIComponent(code)}`;

async function waitForDetail(page: Page, { card }: Picked) {
	await expect(page.getByRole('heading', { name: card.name, level: 1, exact: true })).toBeVisible();
	await expect(page.locator('section.detail[aria-busy="false"]')).toBeVisible();
}

const variantRow = (page: Page, { code }: Picked) =>
	page
		.locator('section.variants li.row')
		.filter({ has: page.locator('p.code', { hasText: code }) });

async function openDetail(page: Page, picked: Picked) {
	await page.goto(detailPath(picked));
	await waitForDetail(page, picked);
	await expect(variantRow(page, picked)).toBeVisible();
}

const plus = (row: Locator, { card, code }: Picked) =>
	row.getByRole('button', { name: `Adicionar uma cópia de ${card.name} ${code}`, exact: true });
const minus = (row: Locator, { card, code }: Picked) =>
	row.getByRole('button', { name: `Remover uma cópia de ${card.name} ${code}`, exact: true });

async function ownedQuantity(
	page: Page,
	{ card, code }: Picked
): Promise<number | null | undefined> {
	const response = await page.request.get(`/api/cards/${encodeURIComponent(card.card_number)}`);
	expect(response.ok(), 'GET /api/cards/:card_number').toBe(true);
	const { data } = (await response.json()) as { data: Card };
	return data.variants.find((variant) => variant.variant_code === code)?.owned_quantity;
}

// Atrasa cada requisição que bater em `pattern` para que os toques cheguem antes das respostas e
// registra a sobreposição: `active` sobe na entrada e desce assim que a resposta real chega, então
// um segundo envio antes da resposta do primeiro aparece em `maxActive`.
async function delayCalls(page: Page, pattern: RegExp, abortAt?: number) {
	const log = { started: 0, completed: 0, active: 0, maxActive: 0 };
	await page.route(pattern, async (route) => {
		log.started++;
		log.active++;
		log.maxActive = Math.max(log.maxActive, log.active);
		await new Promise((resolve) => setTimeout(resolve, RESPONSE_DELAY_MS));
		if (log.started === abortAt) {
			log.active--;
			await route.abort('connectionfailed');
			return;
		}
		const response = await route.fetch();
		log.active--;
		log.completed++;
		await route.fulfill({ response });
	});
	return log;
}

function trackVariantCalls(page: Page) {
	const calls: string[] = [];
	page.on('request', (request) => {
		const { pathname } = new URL(request.url());
		if (VARIANT_CALL.test(pathname)) calls.push(`${request.method()} ${pathname}`);
	});
	return calls;
}

test.describe('posse e desejo no detalhe da carta contra a API real', () => {
	test('"−" e "+" medem 44 px ou mais no navegador (SCAR-25)', async ({ page, request }) => {
		const picked = await pickCard(request);
		await stubImages(page);
		await createAccount(page);
		await openDetail(page, picked);
		const row = variantRow(page, picked);

		for (const [name, button] of [
			['Remover', minus(row, picked)],
			['Adicionar', plus(row, picked)]
		] as const) {
			await expect(button).toBeVisible();
			const box = await button.boundingBox();
			expect(box, `caixa do botão ${name}`).not.toBeNull();
			expect(box!.height, `altura do botão ${name}`).toBeGreaterThanOrEqual(44);
			expect(box!.width, `largura do botão ${name}`).toBeGreaterThanOrEqual(44);
		}
	});

	test('"−" em zero não envia; cinco "+" rápidos gravam 5 em série (SCAR-27, 29, 30, 31)', async ({
		page,
		request
	}) => {
		const picked = await pickCard(request);
		await stubImages(page);
		await createAccount(page);
		await openDetail(page, picked);
		const row = variantRow(page, picked);
		const calls = trackVariantCalls(page);

		await test.step('"−" em zero: aria-disabled, focável, avisa e não envia (SCAR-29)', async () => {
			const remove = minus(row, picked);
			await expect(remove).toHaveAttribute('aria-disabled', 'true');
			await remove.focus();
			await expect(remove).toBeFocused();
			// O Playwright espera para sempre por um botão aria-disabled: force pula a checagem "enabled".
			await remove.click({ force: true });

			await expect(row.locator('[aria-live="polite"]')).toHaveText(NOTHING_TO_REMOVE);
			await page.waitForLoadState('networkidle');
			expect(calls, 'nenhuma requisição de posse saiu').toEqual([]);
			await expect(row.locator('.step')).toHaveText('0');
		});

		const log = await delayCalls(page, INCREMENT);

		await test.step('cinco "+" rápidos: o número passa por 1..5 antes das respostas (SCAR-27)', async () => {
			for (let tap = 1; tap <= 5; tap++) {
				await plus(row, picked).click();
				await expect(row.locator('.step')).toHaveText(String(tap));
			}
			expect(log.completed, 'nenhuma resposta chegou antes do quinto toque').toBe(0);
		});

		await test.step('exatamente cinco incrementos, em série, e o valor final é o do GET (SCAR-30, 31)', async () => {
			await expect.poll(() => log.completed, { timeout: 15_000 }).toBe(5);
			await expect(row.locator('.step')).toHaveText('5');
			await expect(row.locator('.quantity')).toHaveText('5 cópias');

			expect(log.started, 'POST …/increment enviados').toBe(5);
			expect(log.maxActive, 'nunca duas operações da variante em voo').toBe(1);
			expect(
				calls.filter((call) => call.startsWith('POST ') && call.endsWith('/increment')),
				'POST …/increment observados'
			).toHaveLength(5);
			expect(calls, 'só incrementos').toHaveLength(5);

			expect(await ownedQuantity(page, picked), 'GET /api/cards/:card_number').toBe(5);
		});
	});

	test('rede cortada no 3º envio: a tela volta ao confirmado e avisa (SCAR-32)', async ({
		page,
		request
	}) => {
		const picked = await pickCard(request);
		await stubImages(page);
		await createAccount(page);
		await openDetail(page, picked);
		const row = variantRow(page, picked);
		const log = await delayCalls(page, INCREMENT, 3);

		for (let tap = 1; tap <= 4; tap++) await plus(row, picked).click();
		await expect(row.locator('.step')).toHaveText('4');

		await expect(
			page.getByRole('alert').filter({ hasText: NETWORK_ERROR }),
			'toast de erro de rede'
		).toBeVisible({ timeout: 15_000 });
		await expect(row.locator('.step')).toHaveText('2');
		await expect(row.locator('.quantity')).toHaveText('2 cópias');
		expect(log.started, 'o 4º toque nunca foi enviado').toBe(3);
		expect(await ownedQuantity(page, picked), 'GET /api/cards/:card_number').toBe(2);
	});

	test('desejo marcado com 2 persiste após recarregar (SCAR-36)', async ({ page, request }) => {
		const picked = await pickCard(request);
		const { card, code } = picked;
		await stubImages(page);
		await createAccount(page);
		await openDetail(page, picked);
		const row = variantRow(page, picked);

		await row.getByLabel('Quero').fill('2');
		await row.getByRole('button', { name: 'Quero esta' }).click();

		await expect(
			page.getByText(`${card.name} ${code} na lista de desejos: 2 cópias.`, { exact: true })
		).toBeVisible();
		await expect(row.getByLabel('Quero')).toHaveValue('2');
		await expect(row.getByRole('button', { name: 'Atualizar desejo' })).toBeVisible();

		await page.reload();
		await waitForDetail(page, picked);
		await expect(row.getByLabel('Quero')).toHaveValue('2');
		await expect(row.getByRole('button', { name: 'Atualizar desejo' })).toBeVisible();
		await expect(row.getByRole('button', { name: 'Quero esta' })).toHaveCount(0);
	});

	test('sair pelo casco troca os controles pelo convite e some o selo (SCAR-9, 25, 26)', async ({
		page,
		request
	}) => {
		const picked = await pickCard(request);
		await stubImages(page);
		await createAccount(page);
		await openDetail(page, picked);
		const row = variantRow(page, picked);

		await plus(row, picked).click();
		await expect(row.locator('.quantity')).toHaveText('1 cópia');
		await expect(page.locator('.badge:visible'), 'selo com posse').toHaveCount(1);
		await expect(row.getByRole('link', { name: 'Entrar para registrar posse' })).toHaveCount(0);
		const detailUrl = new URL(page.url());

		// O "Sair" do casco leva ao catálogo; voltar reabre o detalhe já sem sessão.
		await mainNav(page).getByRole('button', { name: 'Sair' }).click();
		await expect(page.getByText('Sessão encerrada.', { exact: true })).toBeVisible();
		await expect(page).toHaveURL(/\/app\/?$/);
		await page.goBack();
		await expect(page).toHaveURL(detailUrl.href);
		await waitForDetail(page, picked);

		const invite = row.getByRole('link', { name: 'Entrar para registrar posse' });
		await expect(invite).toBeVisible();
		const href = new URL((await invite.getAttribute('href'))!, page.url());
		expect(href.pathname).toBe('/app/entrar');
		expect(href.searchParams.get('return_to'), 'return_to = caminho e query atuais').toBe(
			detailUrl.pathname + detailUrl.search
		);
		await expect(plus(row, picked)).toHaveCount(0);
		await expect(minus(row, picked)).toHaveCount(0);
		await expect(row.getByLabel('Quero')).toHaveCount(0);
		await expect(page.locator('.badge')).toHaveCount(0);
	});
});
