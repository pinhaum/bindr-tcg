import { expect, test, type Browser, type BrowserContext, type Page } from '@playwright/test';

type Variant = { variant_code: string; in_source: boolean };
type Card = { card_number: string; name: string; variants: Variant[] };
type Pick = { number: string; code: string };
type Wish = {
	card_number: string;
	card_name: string;
	variant_code: string;
	target_quantity: number;
	owned_quantity: number;
	fulfilled: boolean;
};
type Row = { name: string; code: string; quantity: string; status: string; label: string };
type Snapshot = { count: string; rows: Row[] };
type Owner = { email: string; state: Awaited<ReturnType<BrowserContext['storageState']>> };

const PASSWORD = 'senha-correta-1';
const BASE_URL = 'http://frontend:5173/';
const EMPTY_MESSAGE = 'Você ainda não marcou nenhuma carta como desejada.';
const PIXEL_PNG = Buffer.from(
	'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
	'base64'
);
const VIEWPORTS = [
	{ name: '360px', width: 360, height: 740 },
	{ name: '1280px', width: 1280, height: 800 }
];
const SCHEMES = ['light', 'dark'] as const;

// Alvo 1 com posse 1 (atendido), alvo 2 sem posse, alvo 3 com posse 1 (faltam 2).
const PLAN = [
	{ target: 1, owned: 1 },
	{ target: 2, owned: 0 },
	{ target: 3, owned: 1 }
];

const mainNav = (page: Page) => page.getByRole('navigation', { name: 'Principal' });
const removeButtons = (page: Page) => page.getByRole('button', { name: /^Remover / });

async function csrfToken(context: BrowserContext) {
	const response = await context.request.get('/api/session');
	const { data } = (await response.json()) as { data: { csrf_token: string } };
	return data.csrf_token;
}

async function pickVariants(context: BrowserContext, count: number): Promise<Pick[]> {
	const response = await context.request.get('/api/catalog?per_page=50');
	expect(response.ok(), 'GET /api/catalog').toBe(true);
	const { data } = (await response.json()) as { data: Card[] };
	const picks: Pick[] = [];
	for (const card of data) {
		const variant = card.variants.find((item) => item.in_source);
		if (variant) picks.push({ number: card.card_number, code: variant.variant_code });
		if (picks.length === count) return picks;
	}
	throw new Error('o catálogo importado não tem cartas distintas suficientes');
}

const variantPath = (pick: Pick, action: string) =>
	`/api/cards/${encodeURIComponent(pick.number)}/variants/${encodeURIComponent(pick.code)}/${action}`;

async function wish(context: BrowserContext, pick: Pick, target: number, owned: number) {
	const headers = { 'X-CSRF-Token': await csrfToken(context) };
	const put = await context.request.put(variantPath(pick, 'wishlist'), {
		headers,
		data: { target_quantity: target }
	});
	expect(put.ok(), `PUT wishlist ${pick.code}`).toBe(true);
	for (let copy = 0; copy < owned; copy++) {
		const inc = await context.request.post(variantPath(pick, 'increment'), { headers });
		expect(inc.ok(), `increment ${pick.code}`).toBe(true);
	}
}

let accountSeq = 0;
async function createOwner(
	browser: Browser,
	label: string,
	work: (context: BrowserContext) => Promise<void>
): Promise<Owner> {
	const context = await browser.newContext({ baseURL: BASE_URL, locale: 'pt-BR' });
	const page = await context.newPage();
	const email = `e2e-${Date.now()}-desejos-${label}-${accountSeq++}@exemplo.test`;
	await page.goto('criar-conta');
	await page.getByLabel('E-mail').fill(email);
	await page.getByLabel('Senha', { exact: true }).fill(PASSWORD);
	await page.getByLabel('Confirmação da senha').fill(PASSWORD);
	await page.getByRole('button', { name: 'Criar conta' }).click();
	await expect(mainNav(page).getByRole('button', { name: 'Sair' })).toBeVisible();
	await work(context);
	const state = await context.storageState();
	await context.close();
	return { email, state };
}

async function openAs(
	browser: Browser,
	owner: Owner,
	options: Parameters<Browser['newContext']>[0] = {}
) {
	const context = await browser.newContext({
		baseURL: BASE_URL,
		locale: 'pt-BR',
		storageState: owner.state,
		viewport: { width: 1280, height: 800 },
		...options
	});
	await context.route('**/card_images/**', (route) =>
		route.fulfill({ status: 200, contentType: 'image/png', body: PIXEL_PNG })
	);
	return { context, page: await context.newPage() };
}

async function openWishlist(page: Page, expected: number) {
	await page.goto('pasta/desejos');
	await expect(page.getByRole('heading', { name: 'Lista de desejos', level: 1 })).toBeVisible();
	await expect(page.locator('section[aria-busy="false"]')).toBeVisible();
	await expect(removeButtons(page)).toHaveCount(expected);
}

// O DOM da lista da SPA, no mesmo formato de `apiSnapshot`.
function spaSnapshot(page: Page): Promise<Snapshot> {
	return page.evaluate(() => {
		const squash = (text: string | null | undefined) => (text ?? '').replace(/\s+/g, ' ').trim();
		const rows = [...document.querySelectorAll('main section ul > li')].map((li) => ({
			name: squash(li.querySelector('a')?.textContent),
			code: squash(li.querySelector('a code')?.textContent),
			quantity: squash(li.querySelector('.quantity')?.textContent),
			status: squash(li.querySelector('.status')?.textContent),
			label: li.querySelector('button')?.getAttribute('aria-label') ?? ''
		}));
		return { count: squash(document.querySelector('main section > p')?.textContent), rows };
	});
}

async function listWishes(context: BrowserContext) {
	const response = await context.request.get('/api/wishlist');
	expect(response.ok(), 'GET /api/wishlist').toBe(true);
	const { data } = (await response.json()) as { data: Wish[] };
	return data;
}

const copiesOf = (n: number) => (n === 1 ? '1 cópia' : `${n} cópias`);

// O que a tela deve mostrar, calculado de `GET /api/wishlist` (a fonte dos números), com a sessão da página.
async function apiSnapshot(context: BrowserContext): Promise<Snapshot> {
	const wishes = await listWishes(context);
	return {
		count: wishes.length === 1 ? '1 item' : `${wishes.length} itens`,
		rows: wishes.map((item) => {
			const missing = Math.max(item.target_quantity - item.owned_quantity, 0);
			expect(item.fulfilled, `fulfilled de ${item.variant_code} da API`).toBe(missing === 0);
			return {
				name: `${item.card_name} ${item.variant_code}`,
				code: item.variant_code,
				quantity: `${item.owned_quantity} de ${copiesOf(item.target_quantity)}`,
				status: item.fulfilled ? 'Atendido' : `Faltam ${missing}`,
				label: `Remover ${item.card_name} ${item.variant_code} da lista de desejos (${
					item.fulfilled ? 'atendido' : `faltam ${missing}`
				})`
			};
		})
	};
}

let picks: Pick[] = [];
let owner: Owner;
let other: Owner;

test.describe.configure({ mode: 'serial' });

test.beforeAll(async ({ browser }) => {
	test.setTimeout(120_000);
	owner = await createOwner(browser, 'a', async (context) => {
		picks = await pickVariants(context, PLAN.length);
		for (const [index, step] of PLAN.entries()) {
			await wish(context, picks[index], step.target, step.owned);
		}
	});
	// Outro usuário deseja a mesma variante do meio: a remoção do dono não pode tocá-la.
	other = await createOwner(browser, 'b', (context) => wish(context, picks[1], 1, 0));
});

test('paridade com GET /api/wishlist: nomes, variant_code, contagens, estados e ordem (SPAS-29, SPAS-31)', async ({
	browser
}) => {
	const { context, page } = await openAs(browser, owner);
	await openWishlist(page, PLAN.length);
	await expect(page).toHaveTitle('Lista de desejos — Bindr');

	const api = await apiSnapshot(context);
	const spa = await spaSnapshot(page);

	expect(api.rows.length, 'a /api/wishlist lista os três desejos').toBe(PLAN.length);
	expect(
		spa.rows.map((row) => row.code),
		'ordem de criação'
	).toEqual(picks.map((pick) => pick.code));
	expect(spa.count).toBe('3 itens');
	expect(spa.count).toBe(api.count);
	expect(spa.rows).toEqual(api.rows);
	expect(spa.rows.map((row) => row.status)).toEqual(['Atendido', 'Faltam 2', 'Faltam 2']);
	await context.close();
});

test('/wishlist e /app/pasta/desejos redirecionam para /pasta/desejos com a mesma lista (STRO-11, STRO-12, STRO-34)', async ({
	browser
}) => {
	const { context, page } = await openAs(browser, owner);
	const expected = await apiSnapshot(context);
	expect(expected.rows.length, 'a /api/wishlist tem desejos').toBe(PLAN.length);

	for (const legacy of ['wishlist', 'app/pasta/desejos']) {
		await page.goto(legacy);
		await expect(page).toHaveURL(/^https?:\/\/[^/]+\/pasta\/desejos$/);
		await expect(page.getByRole('heading', { name: 'Lista de desejos', level: 1 })).toBeVisible();
		await expect(removeButtons(page)).toHaveCount(PLAN.length);
		expect((await spaSnapshot(page)).rows, `lista depois de ${legacy}`).toEqual(expected.rows);
	}
	await context.close();
});

test('o link do item abre /cartas/<card_number> sem recarga (SPAS-30)', async ({ browser }) => {
	const { context, page } = await openAs(browser, owner);
	await openWishlist(page, PLAN.length);
	await page.evaluate(() => {
		(window as unknown as { __kept: boolean }).__kept = true;
	});

	const [first] = await listWishes(context);
	await page.locator('main section ul > li').first().getByRole('link').click();

	await expect(page).toHaveURL(new RegExp(`/cartas/${encodeURIComponent(first.card_number)}$`));
	await expect(page.getByRole('heading', { level: 1 })).toContainText(first.card_name);
	expect(
		await page.evaluate(() => (window as unknown as { __kept?: boolean }).__kept),
		'a página não recarregou'
	).toBe(true);
	await context.close();
});

for (const viewport of VIEWPORTS) {
	for (const scheme of SCHEMES) {
		test(`sem scroll horizontal a ${viewport.name}, tema ${scheme} (SPAS-27)`, async ({
			browser
		}) => {
			const { context, page } = await openAs(browser, owner, {
				viewport: { width: viewport.width, height: viewport.height },
				colorScheme: scheme
			});
			await openWishlist(page, PLAN.length);
			expect(await page.locator('html').getAttribute('data-theme')).toBe(scheme);
			const { scrollWidth, clientWidth } = await page.evaluate(() => ({
				scrollWidth: document.documentElement.scrollWidth,
				clientWidth: document.documentElement.clientWidth
			}));
			expect(scrollWidth, `scroll horizontal a ${viewport.name}, ${scheme}`).toBeLessThanOrEqual(
				clientWidth
			);
			await context.close();
		});
	}
}

test('remover o do meio leva o foco ao seguinte e não toca o desejo de outro usuário (SPAS-33, SPAS-34, SPAS-43)', async ({
	browser
}) => {
	const { context, page } = await openAs(browser, owner);
	await openWishlist(page, PLAN.length);
	const [, middle, last] = (await spaSnapshot(page)).rows;

	await page.getByRole('button', { name: middle.label, exact: true }).click();

	await expect(page.getByText('Item removido da lista de desejos.')).toBeVisible();
	await expect(removeButtons(page)).toHaveCount(2);
	await expect(page.getByRole('button', { name: last.label, exact: true })).toBeFocused();
	expect(await page.evaluate(() => document.activeElement === document.body), 'foco no body').toBe(
		false
	);
	expect((await spaSnapshot(page)).count).toBe('2 itens');

	const api = await apiSnapshot(context);
	expect(api.rows.map((row) => row.code)).toEqual([picks[0].code, picks[2].code]);
	expect(api.count).toBe('2 itens');

	const { context: otherContext, page: otherPage } = await openAs(browser, other);
	const theirs = await listWishes(otherContext);
	expect(
		theirs.map((item) => item.variant_code),
		'o desejo do outro usuário continua'
	).toEqual([picks[1].code]);
	await openWishlist(otherPage, 1);
	await otherContext.close();
	await context.close();
});

test('remover todos leva o foco ao h1 e mostra a lista vazia (SPAS-34)', async ({ browser }) => {
	const { context, page } = await openAs(browser, owner);
	await openWishlist(page, 2);
	const [first, second] = (await spaSnapshot(page)).rows;

	await page.getByRole('button', { name: first.label, exact: true }).click();
	await expect(removeButtons(page)).toHaveCount(1);
	await expect(page.getByRole('button', { name: second.label, exact: true })).toBeFocused();

	await page.getByRole('button', { name: second.label, exact: true }).click();
	await expect(page.getByText(EMPTY_MESSAGE)).toBeVisible();
	await expect(page.getByRole('heading', { name: 'Lista de desejos', level: 1 })).toBeFocused();

	expect((await apiSnapshot(context)).rows, '/api/wishlist vazia').toEqual([]);
	expect(await listWishes(context)).toEqual([]);
	await context.close();
});
