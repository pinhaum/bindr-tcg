import { expect, test, type Browser, type BrowserContext, type Page } from '@playwright/test';

type Variant = { variant_code: string; in_source: boolean };
type Card = { card_number: string; colors: string[]; variants: Variant[] };
type Owner = { state: Awaited<ReturnType<BrowserContext['storageState']>> };
type DeckApi = { entries: { card_number: string; quantity: number }[] };
type ShortfallRow = { name: string; number: string; missing: string; decks: string[] };

const PASSWORD = 'senha-correta-1';
const BASE_URL = 'http://frontend:5173/app/';
const PIXEL_PNG = Buffer.from(
	'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
	'base64'
);
const enc = encodeURIComponent;

const mainNav = (page: Page) => page.getByRole('navigation', { name: 'Principal' });
const deckPanel = (page: Page) => page.locator('section[aria-labelledby="deck-panel-title"]');
const addCopy = (page: Page) =>
	deckPanel(page).getByRole('button', { name: /^Adicionar uma cópia de .* ao deck / });

async function csrfToken(context: BrowserContext) {
	const response = await context.request.get('/api/session');
	const { data } = (await response.json()) as { data: { csrf_token: string } };
	return data.csrf_token;
}

async function catalog(context: BrowserContext, query: string) {
	const response = await context.request.get(`/api/catalog?per_page=100&${query}`);
	const { data } = (await response.json()) as { data: Card[] };
	return data;
}

const mono = (cards: Card[], color: string) =>
	cards.filter((card) => card.colors.length === 1 && card.colors[0] === color);

async function post(context: BrowserContext, path: string, body?: object) {
	const headers = { 'X-CSRF-Token': await csrfToken(context) };
	const response = await context.request.post(path, { headers, data: body });
	expect(response.ok(), `POST ${path}`).toBe(true);
	return (await response.json()) as { data: { id: number } };
}

let owner: Owner;
let suffix: string;
let leader: Card;
let reds: Card[];

// Criar um deck já o põe em edição; o deck seguinte tira o alvo dela, e a SPA precisa pedi-la.
async function createDeck(context: BrowserContext, name: string) {
	const { data } = await post(context, '/api/decks', { name: `${name} ${suffix}` });
	await post(context, '/api/decks', { name: `Outro de ${name} ${suffix}` });
	return data.id;
}

async function addCopies(context: BrowserContext, deckId: number, card: Card, copies: number) {
	for (let copy = 0; copy < copies; copy++) {
		await post(context, `/api/decks/${deckId}/cards/${enc(card.card_number)}/increment`);
	}
}

async function ownCopy(context: BrowserContext, card: Card) {
	const variant = card.variants.find((item) => item.in_source) ?? card.variants[0];
	await post(
		context,
		`/api/cards/${enc(card.card_number)}/variants/${enc(variant.variant_code)}/increment`
	);
}

async function deckEntries(page: Page, deckId: number) {
	const response = await page.context().request.get(`/api/decks/${deckId}`);
	expect(response.ok(), `GET /api/decks/${deckId}`).toBe(true);
	const { data } = (await response.json()) as { data: DeckApi };
	return data.entries;
}

async function openAs(browser: Browser) {
	const context = await browser.newContext({
		baseURL: BASE_URL,
		locale: 'pt-BR',
		storageState: owner.state,
		viewport: { width: 1280, height: 800 }
	});
	await context.route('**/card_images/**', (route) =>
		route.fulfill({ status: 200, contentType: 'image/png', body: PIXEL_PNG })
	);
	return { context, page: await context.newPage() };
}

async function editThisDeck(page: Page, deckId: number) {
	await page.goto(`baralhos/${deckId}`);
	await page.getByRole('button', { name: 'Editar este deck' }).click();
	await expect(page.getByText('Em edição', { exact: true })).toBeVisible();
}

async function openCard(page: Page, card: Card) {
	await page.goto(`cartas/${enc(card.card_number)}`);
	await expect(page.getByRole('heading', { name: 'Deck em edição', level: 2 })).toBeVisible();
}

test.describe.configure({ mode: 'serial' });

test.beforeAll(async ({ browser }) => {
	test.setTimeout(120_000);
	const context = await browser.newContext({ baseURL: BASE_URL, locale: 'pt-BR' });
	const page = await context.newPage();
	suffix = `e2e${Date.now()}`;
	await page.goto('criar-conta');
	await page.getByLabel('E-mail').fill(`e2e-${suffix}-montagem@exemplo.test`);
	await page.getByLabel('Senha', { exact: true }).fill(PASSWORD);
	await page.getByLabel('Confirmação da senha').fill(PASSWORD);
	await page.getByRole('button', { name: 'Criar conta' }).click();
	await expect(mainNav(page).getByRole('button', { name: 'Sair' })).toBeVisible();

	const leaders = mono(await catalog(context, 'card_types[]=leader&colors[]=Red'), 'Red');
	reds = mono(await catalog(context, 'card_types[]=character&colors[]=Red'), 'Red');
	expect(leaders.length, 'Leader vermelho no catálogo').toBeGreaterThan(0);
	expect(reds.length, 'Characters vermelhos').toBeGreaterThanOrEqual(14);
	leader = leaders[0];
	owner = { state: await context.storageState() };
	await context.close();
});

test.describe('montagem pelo detalhe da carta (SDEC-20, SDEC-33, SDEC-35, SDEC-36)', () => {
	test('três "+" na carta viram 3× na página do deck', async ({ browser }) => {
		const { context, page } = await openAs(browser);
		const deckName = `Montagem três ${suffix}`;
		const deckId = await createDeck(context, 'Montagem três');
		const card = reds[0];

		await editThisDeck(page, deckId);
		await openCard(page, card);
		await expect(deckPanel(page).getByRole('link', { name: deckName })).toBeVisible();

		for (let tap = 0; tap < 3; tap++) await addCopy(page).click();
		await expect(deckPanel(page).getByText(/^3 cópias de .* no deck$/).first()).toBeVisible();
		await expect(async () => {
			const entries = await deckEntries(page, deckId);
			expect(entries.map(({ card_number, quantity }) => ({ card_number, quantity }))).toEqual([
				{ card_number: card.card_number, quantity: 3 }
			]);
		}).toPass();

		await deckPanel(page).getByRole('link', { name: deckName }).click();
		await expect(page).toHaveURL(new RegExp(`/app/baralhos/${deckId}/?$`));
		await expect(page.locator('li.entry', { hasText: card.card_number }).locator('.quantity')).toHaveText(
			'3×'
		);
		await context.close();
	});

	test('cinco toques rápidos terminam em +5, igual ao GET seguinte', async ({ browser }) => {
		const { context, page } = await openAs(browser);
		const deckId = await createDeck(context, 'Montagem cinco');
		const card = reds[1];

		await editThisDeck(page, deckId);
		await openCard(page, card);
		const add = addCopy(page);
		for (let tap = 0; tap < 5; tap++) await add.click();

		await expect(deckPanel(page).getByText(/^5 cópias de .* no deck$/).first()).toBeVisible();
		await expect(async () => {
			const entries = await deckEntries(page, deckId);
			expect(entries.find((entry) => entry.card_number === card.card_number)?.quantity).toBe(5);
		}).toPass();
		await expect(deckPanel(page).getByText(/^5 cópias de .* no deck$/).first()).toBeVisible();
		await context.close();
	});

	test('Leader pela SPA e cópias até 50: válido na SPA e em /decks/<id>', async ({ browser }) => {
		const { context, page } = await openAs(browser);
		const deckId = await createDeck(context, 'Montagem válido');
		for (const card of reds.slice(0, 12)) await addCopies(context, deckId, card, 4);

		await editThisDeck(page, deckId);
		await openCard(page, leader);
		await deckPanel(page).getByRole('button', { name: /^Usar .* como Leader do deck/ }).click();
		await expect(deckPanel(page).getByRole('button', { name: /é o Leader deste deck/ })).toBeVisible();

		await openCard(page, reds[12]);
		await addCopy(page).click();
		await addCopy(page).click();
		await expect(deckPanel(page).getByText(/^2 cópias de .* no deck$/).first()).toBeVisible();
		await expect(async () => {
			const entries = await deckEntries(page, deckId);
			expect(entries.reduce((sum, entry) => sum + entry.quantity, 0)).toBe(50);
		}).toPass();

		await page.goto(`baralhos/${deckId}`);
		await expect(page.locator('#deck-status-title')).toHaveText('Status: válido');
		await expect(page.locator('#deck-main-title')).toHaveText('Deck principal: 50 / 50');

		const html = await (await context.request.get(`/decks/${deckId}`)).text();
		const hotwire = await page.evaluate((source) => {
			const doc = new DOMParser().parseFromString(source, 'text/html');
			return (doc.querySelector('#deck-status-title')?.textContent ?? '').replace(/\s+/g, ' ').trim();
		}, html);
		expect(hotwire).toBe('Status: válido');
		await context.close();
	});
});

// Lê o bloco "Faltando para os baralhos": `source` é o HTML do Hotwire; sem ele, o DOM da SPA.
function shortfall(page: Page, source: string | null): Promise<ShortfallRow[]> {
	return page.evaluate((html) => {
		const squash = (text: string | null | undefined) => (text ?? '').replace(/\s+/g, ' ').trim();
		const root = html ? new DOMParser().parseFromString(html, 'text/html') : document;
		const section = root.querySelector(
			html
				? 'section[aria-labelledby="deck-folder-shortfall-title"]'
				: 'section[aria-labelledby="deck-shortfall-title"]'
		);
		return [...(section?.querySelectorAll('li') ?? [])].map((li) => ({
			name: squash(li.querySelector('a')?.textContent),
			number: squash(li.querySelector('code')?.textContent),
			missing: squash(li.querySelector('code')?.nextElementSibling?.textContent),
			decks: [...li.querySelectorAll('a')].slice(1).map((a) => squash(a.textContent))
		}));
	}, source);
}

test.describe('"Faltando para os baralhos" na pasta (SDEC-40)', () => {
	test('o bloco da /app/pasta traz as mesmas cartas, faltas e decks da /progress', async ({
		browser
	}) => {
		const { context, page } = await openAs(browser);
		const first = await createDeck(context, 'Falta A');
		const second = await createDeck(context, 'Falta B');
		await addCopies(context, first, reds[2], 3);
		await addCopies(context, second, reds[2], 2);
		await addCopies(context, second, reds[3], 1);
		await ownCopy(context, reds[2]);

		await page.goto('pasta');
		await expect(page.getByRole('heading', { name: 'Minha pasta', level: 1 })).toBeVisible();
		await expect(
			page.getByRole('heading', { name: 'Faltando para os baralhos', level: 2 })
		).toBeVisible();

		const spa = await shortfall(page, null);
		const html = await shortfall(page, await (await context.request.get('/progress')).text());
		expect(html.length, 'o Hotwire lista as cartas que faltam').toBeGreaterThan(0);
		expect(spa, 'mesmas cartas, faltas e decks').toEqual(html);
		const row = spa.find((item) => item.number === reds[2].card_number);
		// maior uso entre os decks do dono (4, no deck válido) menos 1 possuída
		expect(row?.missing).toBe('faltam 3');
		expect(row?.decks).toContain(`Falta A ${suffix}`);
		await context.close();
	});
});
