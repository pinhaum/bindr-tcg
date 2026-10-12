import {
	expect,
	test,
	type Browser,
	type BrowserContext,
	type Page
} from '@playwright/test';

type Variant = { variant_code: string; in_source: boolean };
type Card = { card_number: string; colors: string[]; variants: Variant[] };
type Owner = { email: string; state: Awaited<ReturnType<BrowserContext['storageState']>> };
type DeckIds = { empty: number; incomplete: number; invalidColor: number; valid: number };
type DeckRow = { name: string; leader: string; cards: string; status: string };
type Entry = { text: string };
type DeckView = {
	title: string;
	status: string;
	reasons: string[];
	warnings: string[];
	note: string;
	shortfall: string;
	leader: string;
	main: string;
	groups: { title: string; entries: Entry[] }[];
};

const PASSWORD = 'senha-correta-1';
const BASE_URL = 'http://frontend:5173/app/';
const PIXEL_PNG = Buffer.from(
	'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
	'base64'
);
const VIEWPORTS = [
	{ name: '360px', width: 360, height: 740 },
	{ name: '1280px', width: 1280, height: 800 }
];
const SCHEMES = ['light', 'dark'] as const;
const DECK_KEYS = ['empty', 'incomplete', 'invalidColor', 'valid'] as const;

const mainNav = (page: Page) => page.getByRole('navigation', { name: 'Principal' });

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

// Monta os quatro decks pela API e dá posse a parte das cartas, para "falta" variar.
async function buildDecks(context: BrowserContext, suffix: string): Promise<DeckIds> {
	const token = await csrfToken(context);
	const headers = { 'X-CSRF-Token': token };

	const leaders = mono(await catalog(context, 'card_types[]=leader&colors[]=Red'), 'Red');
	const reds = mono(await catalog(context, 'card_types[]=character&colors[]=Red'), 'Red');
	const events = mono(await catalog(context, 'card_types[]=event&colors[]=Red'), 'Red');
	const blues = mono(await catalog(context, 'card_types[]=character&colors[]=Blue'), 'Blue');
	expect(leaders.length, 'Leader vermelho no catálogo').toBeGreaterThan(0);
	expect(reds.length, 'Characters vermelhos').toBeGreaterThanOrEqual(13);
	expect(blues.length, 'Character azul').toBeGreaterThan(0);

	const post = async (path: string, body?: object) => {
		const response = await context.request.post(path, { headers, data: body });
		expect(response.ok(), `POST ${path}`).toBe(true);
		return (await response.json()) as { data: { id: number } };
	};
	const addCopies = async (deckId: number, card: Card, copies: number) => {
		for (let copy = 0; copy < copies; copy++) {
			await post(`/api/decks/${deckId}/cards/${encodeURIComponent(card.card_number)}/increment`);
		}
	};
	const own = async (card: Card, copies: number) => {
		const variant = card.variants.find((item) => item.in_source) ?? card.variants[0];
		for (let copy = 0; copy < copies; copy++) {
			await post(
				`/api/cards/${encodeURIComponent(card.card_number)}/variants/${encodeURIComponent(variant.variant_code)}/increment`
			);
		}
	};
	const create = async (name: string, leader?: Card) => {
		const { data } = await post('/api/decks', { name: `${name} ${suffix}` });
		if (leader) {
			const response = await context.request.put(`/api/decks/${data.id}/leader`, {
				headers,
				data: { card_number: leader.card_number }
			});
			expect(response.ok(), 'PUT leader').toBe(true);
		}
		return data.id;
	};

	const leader = leaders[0];
	await own(leader, 1);
	await own(reds[0], 1);
	await own(reds[1], 3);

	const empty = await create('Vazio');

	const incomplete = await create('Incompleto', leader);
	await addCopies(incomplete, reds[0], 2);
	await addCopies(incomplete, reds[1], 2);

	const invalidColor = await create('Cor errada', leader);
	await addCopies(invalidColor, reds[0], 4);
	await addCopies(invalidColor, blues[0], 1);

	const valid = await create('Válido', leader);
	for (const card of reds.slice(0, 12)) await addCopies(valid, card, 4);
	await addCopies(valid, events[0] ?? reds[12], 2);

	return { empty, incomplete, invalidColor, valid };
}

let accountSeq = 0;
let owner: Owner;
let decks: DeckIds;
let suffix: string;

async function createOwner(browser: Browser) {
	const context = await browser.newContext({ baseURL: BASE_URL, locale: 'pt-BR' });
	const page = await context.newPage();
	const email = `e2e-${Date.now()}-baralhos-${accountSeq++}@exemplo.test`;
	suffix = `e2e${Date.now()}`;
	await page.goto('criar-conta');
	await page.getByLabel('E-mail').fill(email);
	await page.getByLabel('Senha', { exact: true }).fill(PASSWORD);
	await page.getByLabel('Confirmação da senha').fill(PASSWORD);
	await page.getByRole('button', { name: 'Criar conta' }).click();
	await expect(mainNav(page).getByRole('button', { name: 'Sair' })).toBeVisible();
	decks = await buildDecks(context, suffix);
	owner = { email, state: await context.storageState() };
	await context.close();
}

async function openAs(browser: Browser, options: Parameters<Browser['newContext']>[0] = {}) {
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

async function expectNoHorizontalScroll(page: Page, where: string) {
	const { scrollWidth, clientWidth } = await page.evaluate(() => ({
		scrollWidth: document.documentElement.scrollWidth,
		clientWidth: document.documentElement.clientWidth
	}));
	expect(scrollWidth, `scroll horizontal em ${where}`).toBeLessThanOrEqual(clientWidth);
}

async function hotwireHtml(page: Page, path: string) {
	const response = await page.context().request.get(path);
	expect(response.ok(), `GET ${path}`).toBe(true);
	return response.text();
}

const mine = (rows: DeckRow[]) => rows.filter((row) => row.name.endsWith(suffix));

// Lê a lista de decks: `source` é o HTML do Hotwire; sem ele, o DOM da SPA.
function deckRows(page: Page, source: string | null): Promise<DeckRow[]> {
	return page.evaluate((html) => {
		const squash = (text: string | null | undefined) => (text ?? '').replace(/\s+/g, ' ').trim();
		const root = html ? new DOMParser().parseFromString(html, 'text/html') : document;
		const items = root.querySelectorAll(html ? 'li.deck__item' : 'ul.decks > li');
		return [...items].map((li) => {
			const facts = [...li.querySelectorAll('dd')].map((dd) => squash(dd.textContent));
			return {
				name: squash(li.querySelector('h2')?.textContent),
				leader: facts[0],
				cards: facts[1],
				status: facts[2]
			};
		});
	}, source);
}

// Lê a página de um deck. As duas telas têm os mesmos blocos, com marcação própria.
function deckView(page: Page, source: string | null): Promise<DeckView> {
	return page.evaluate((html) => {
		const squash = (text: string | null | undefined) => (text ?? '').replace(/\s+/g, ' ').trim();
		const root = html ? new DOMParser().parseFromString(html, 'text/html') : document;
		const sel = html
			? {
					reasons: '.deck__reason',
					warning: '.deck__warning blockquote',
					note: '.deck__note',
					summary: '.deck__summary',
					entry: '.deck__entry',
					group: 'section.deck__group'
				}
			: {
					reasons: 'section[aria-labelledby="deck-status-title"] ul li',
					warning: '.warning blockquote',
					note: 'section[aria-labelledby="deck-status-title"] > p',
					summary: 'p',
					entry: 'p.entry',
					group: 'section.group'
				};
		const section = (id: string) => root.querySelector(`section[aria-labelledby="${id}"]`)!;
		const all = (scope: ParentNode, query: string) =>
			[...scope.querySelectorAll(query)].map((node) => squash(node.textContent));
		const notes = all(section('deck-status-title'), sel.note);
		const leaderSection = section('deck-leader-title');
		return {
			title: squash(root.querySelector('main h1')?.textContent),
			status: squash(root.querySelector('#deck-status-title')?.textContent),
			reasons: all(root, sel.reasons),
			warnings: all(root, sel.warning),
			note: notes[notes.length - 1],
			shortfall: squash(section('deck-shortfall-title').querySelector(sel.summary)?.textContent),
			leader: squash(
				(leaderSection.querySelector(sel.entry) ?? leaderSection.querySelector(sel.summary))
					?.textContent
			),
			main: squash(root.querySelector('#deck-main-title')?.textContent),
			groups: [...section('deck-main-title').querySelectorAll(sel.group)].map((group) => ({
				title: squash(group.querySelector('h3')?.textContent),
				entries: [...group.querySelectorAll('li')].map((li) => ({ text: squash(li.textContent) }))
			}))
		};
	}, source);
}

test.describe.configure({ mode: 'serial' });

test.beforeAll(async ({ browser }) => {
	test.setTimeout(240_000);
	await createOwner(browser);
});

test.describe('lista de baralhos (SDEC-01, SDEC-02, SDEC-07)', () => {
	test('"Baralhos" do casco abre a lista sem recarga, igual à /decks', async ({ browser }) => {
		const { context, page } = await openAs(browser);
		await page.goto('');
		await expect(page.getByRole('heading', { name: 'Catálogo', level: 1 })).toBeVisible();
		await page.evaluate(() => {
			(window as unknown as { __kept: boolean }).__kept = true;
		});

		const link = mainNav(page).getByRole('link', { name: 'Baralhos' });
		await expect(link).not.toHaveAttribute('aria-current', 'page');
		await link.click();

		await expect(page).toHaveURL(/\/app\/baralhos\/?$/);
		await expect(page.getByRole('heading', { name: 'Baralhos', level: 1 })).toBeVisible();
		await expect(page).toHaveTitle('Baralhos — Bindr');
		await expect(mainNav(page).getByRole('link', { name: 'Baralhos' })).toHaveAttribute(
			'aria-current',
			'page'
		);
		await expect(page.locator('ul.decks > li')).toHaveCount(4);
		expect(
			await page.evaluate(() => (window as unknown as { __kept?: boolean }).__kept),
			'a página não recarregou'
		).toBe(true);

		const spa = await deckRows(page, null);
		const html = await deckRows(page, await hotwireHtml(page, '/decks'));
		expect(mine(html), 'o Hotwire lista os quatro decks').toHaveLength(4);
		expect(spa, 'mesma sequência de nomes, Leaders, totais e status').toEqual(html);
		expect(new Set(spa.map((row) => row.status)).size, 'status variados').toBeGreaterThan(1);
		await context.close();
	});
});

test.describe('criar, renomear e excluir (SDEC-11, SDEC-12, SDEC-16)', () => {
	test('cada operação pela SPA aparece em /decks', async ({ browser }) => {
		const { context, page } = await openAs(browser);
		const name = `Novo ${suffix}`;
		const renamed = `Renomeado ${suffix}`;

		await page.goto('baralhos/novo');
		await page.getByLabel('Nome do deck (até 60 caracteres)').fill(name);
		await page.getByRole('button', { name: 'Criar deck' }).click();
		await expect(page.getByRole('heading', { name, level: 1 })).toBeVisible();
		await expect(page.getByText('Deck criado.')).toBeVisible();
		expect(await hotwireHtml(page, '/decks')).toContain(name);

		await page.getByRole('link', { name: 'Renomear' }).click();
		const field = page.getByLabel('Nome do deck (até 60 caracteres)');
		await expect(field).toHaveValue(name);
		await field.fill(renamed);
		await page.getByRole('button', { name: 'Renomear deck' }).click();
		await expect(page.getByRole('heading', { name: renamed, level: 1 })).toBeVisible();
		await expect(page.getByText('Deck renomeado.')).toBeVisible();
		const afterRename = await hotwireHtml(page, '/decks');
		expect(afterRename).toContain(renamed);
		expect(afterRename).not.toContain(`>${name}<`);

		await page.getByRole('link', { name: 'Excluir', exact: true }).click();
		await expect(page.getByRole('heading', { name: `Excluir o deck “${renamed}”?` })).toBeVisible();
		await page.getByRole('button', { name: 'Excluir deck' }).click();
		await expect(page).toHaveURL(/\/app\/baralhos\/?$/);
		await expect(page.getByText(`Deck “${renamed}” excluído.`)).toBeVisible();
		expect(await hotwireHtml(page, '/decks')).not.toContain(renamed);
		await context.close();
	});
});

test.describe('página do deck igual à /decks/<id> (SDEC-17, SDEC-21, SDEC-24, SDEC-26, SDEC-28)', () => {
	for (const viewport of VIEWPORTS) {
		for (const scheme of SCHEMES) {
			test(`quatro decks a ${viewport.name}, tema ${scheme}`, async ({ browser }) => {
				const { context, page } = await openAs(browser, {
					viewport: { width: viewport.width, height: viewport.height },
					colorScheme: scheme
				});
				const seen = new Set<string>();

				for (const key of DECK_KEYS) {
					const id = decks[key];
					await page.goto(`baralhos/${id}`);
					await expect(page.locator('#deck-main-title')).toBeVisible();
					expect(await page.locator('html').getAttribute('data-theme')).toBe(scheme);

					const spa = await deckView(page, null);
					const html = await deckView(page, await hotwireHtml(page, `/decks/${id}`));
					expect(spa, `deck ${key}`).toEqual(html);
					await expectNoHorizontalScroll(page, `${key}, ${viewport.name}, ${scheme}`);
					seen.add(spa.status.replace('Status: ', ''));

					if (key === 'valid') {
						expect(spa.status).toBe('Status: válido');
						expect(spa.main).toBe('Deck principal: 50 / 50');
					}
					if (key === 'invalidColor') expect(spa.status).toBe('Status: inválido');
					if (key === 'empty') expect(spa.shortfall).toBe('Este deck ainda não tem cartas');
				}
				expect(seen, 'os três status aparecem').toEqual(new Set(['incompleto', 'inválido', 'válido']));
				await context.close();
			});
		}
	}
});

test.describe('importar lista (SDEC-31, SDEC-32)', () => {
	test('o texto exportado reproduz o deck; linhas ruins não criam nada', async ({ browser }) => {
		const { context, page } = await openAs(browser);
		const text = await hotwireHtml(page, `/decks/${decks.valid}.txt`);
		expect(text.trim().length, 'lista exportada').toBeGreaterThan(0);

		await page.goto('baralhos/importar');
		await page.getByLabel(/^Nome do deck/).fill(`Importado ${suffix}`);
		await page.getByLabel(/^Lista/).fill(text);
		await page.getByRole('button', { name: 'Importar lista' }).click();
		await expect(page.getByText('Deck importado.')).toBeVisible();
		await expect(page).toHaveURL(/\/app\/baralhos\/\d+\/?$/);
		const importedId = Number(/baralhos\/(\d+)/.exec(page.url())![1]);

		const original = await deckView(page, await hotwireHtml(page, `/decks/${decks.valid}`));
		const imported = await deckView(page, await hotwireHtml(page, `/decks/${importedId}`));
		expect(imported.leader, 'mesmo Leader').toBe(original.leader);
		expect(imported.groups, 'mesmas entradas').toEqual(original.groups);
		expect(imported.status).toBe('Status: válido');

		const before = mine(await deckRows(page, await hotwireHtml(page, '/decks'))).length;
		await page.goto('baralhos/importar');
		await page.getByLabel(/^Lista/).fill('isto não é uma linha\n4xOP01-016\nlixo 2');
		await page.getByRole('button', { name: 'Importar lista' }).click();
		const alert = page.locator('main [role="alert"]');
		await expect(alert).toContainText('A lista não foi importada. Nenhum deck foi criado.');
		const lines = await alert.locator('li').allTextContents();
		expect(lines, 'as duas linhas ruins, com número e motivo').toHaveLength(2);
		expect(lines[0]).toMatch(/^Linha 1:/);
		expect(lines[1]).toMatch(/^Linha 3:/);
		await expect(page).toHaveURL(/\/app\/baralhos\/importar\/?$/);

		const after = mine(await deckRows(page, await hotwireHtml(page, '/decks'))).length;
		expect(after, 'nenhum deck criado').toBe(before);
		await context.close();
	});
});
