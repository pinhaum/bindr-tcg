import {
	expect,
	test,
	type Browser,
	type BrowserContext,
	type Locator,
	type Page
} from '@playwright/test';

type Variant = { variant_code: string; in_source: boolean; price: unknown };
type Card = { card_number: string; variants: Variant[] };
type Owner = { email: string; state: Awaited<ReturnType<BrowserContext['storageState']>> };
type SetRow = {
	code: string;
	name: string;
	owned: string;
	total: string | null;
	percent: string | null;
	basis: string;
	parallels: string;
	value: string;
};
type Snapshot = { stats: { value: string; label: string; note: string | null }[]; sets: SetRow[] };
type Order = 'recent' | 'code';

const PASSWORD = 'senha-correta-1';
const BASE_URL = 'http://frontend:5173/';
const ORDERS: Order[] = ['recent', 'code'];
const CAPTURES_DIR = 'test-results/pasta-capturas';
const PIXEL_PNG = Buffer.from(
	'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
	'base64'
);

const VIEWPORTS = [
	{ name: '360px', width: 360, height: 740 },
	{ name: '1280px', width: 1280, height: 800 }
];
const SCHEMES = ['light', 'dark'] as const;

// Coleções diferentes: A tem 1 cópia em sets de índice ímpar; B tem 2 em sets de índice par.
const PLANS = [
	{ label: 'A', indexes: [1, 3, 5, 7, 9, 11], copies: 1 },
	{ label: 'B', indexes: [0, 2, 4, 6, 8], copies: 2 }
];

const mainNav = (page: Page) => page.getByRole('navigation', { name: 'Principal' });
const setList = (page: Page) => page.getByRole('list', { name: 'Progresso por set' });
const indicators = (page: Page) => page.locator('main .summary .card');
const addCards = (page: Page) => page.getByRole('link', { name: /^Adicionar cartas/ });
const squash = (text: string | null | undefined) => (text ?? '').replace(/\s+/g, ' ').trim();

const box = async (locator: Locator) => {
	const found = await locator.boundingBox();
	expect(found, 'elemento visível com caixa').not.toBeNull();
	return found!;
};

async function csrfToken(context: BrowserContext) {
	const response = await context.request.get('/api/session');
	const { data } = (await response.json()) as { data: { csrf_token: string } };
	return data.csrf_token;
}

async function ownVariants(context: BrowserContext, indexes: number[], copies: number) {
	const filters = await context.request.get('/api/catalog/filters');
	const { data } = (await filters.json()) as { data: { sets: { code: string }[] } };
	const token = await csrfToken(context);

	for (const index of indexes) {
		const code = data.sets[index].code;
		const response = await context.request.get(
			`/api/catalog?per_page=100&sets[]=${encodeURIComponent(code)}`
		);
		const { data: cards } = (await response.json()) as { data: Card[] };
		const variants = cards.flatMap((card) =>
			card.variants
				.filter((variant) => variant.in_source)
				.map((variant) => ({ number: card.card_number, variant }))
		);
		// Variantes com preço primeiro: o valor do set deixa de ser sempre US$ 0,00.
		variants.sort((a, b) => Number(b.variant.price !== null) - Number(a.variant.price !== null));
		const picked = variants.slice(0, 2);
		expect(picked.length, `variantes na fonte do set ${code}`).toBeGreaterThan(0);

		for (const { number, variant } of picked) {
			for (let copy = 0; copy < copies; copy++) {
				const result = await context.request.post(
					`/api/cards/${encodeURIComponent(number)}/variants/${encodeURIComponent(variant.variant_code)}/increment`,
					{ headers: { 'X-CSRF-Token': token } }
				);
				expect(result.ok(), `increment ${variant.variant_code}`).toBe(true);
			}
		}
	}
}

let accountSeq = 0;
async function createOwner(browser: Browser, plan: (typeof PLANS)[number]): Promise<Owner> {
	const context = await browser.newContext({ baseURL: BASE_URL, locale: 'pt-BR' });
	const page = await context.newPage();
	const email = `e2e-${Date.now()}-pasta-${plan.label}-${accountSeq++}@exemplo.test`;
	await page.goto('criar-conta');
	await page.getByLabel('E-mail').fill(email);
	await page.getByLabel('Senha', { exact: true }).fill(PASSWORD);
	await page.getByLabel('Confirmação da senha').fill(PASSWORD);
	await page.getByRole('button', { name: 'Criar conta' }).click();
	await expect(mainNav(page).getByRole('button', { name: 'Sair' })).toBeVisible();
	await ownVariants(context, plan.indexes, plan.copies);
	const state = await context.storageState();
	await context.close();
	return { email, state };
}

// O CDN da arte responde 403 (a pilha devolve 502): a pasta não mostra arte, mas o stub é barato.
async function openAs(
	browser: Browser,
	owner: Owner | null,
	options: Parameters<Browser['newContext']>[0] = {}
) {
	const context = await browser.newContext({
		baseURL: BASE_URL,
		locale: 'pt-BR',
		storageState: owner?.state,
		...options
	});
	await context.route('**/card_images/**', (route) =>
		route.fulfill({ status: 200, contentType: 'image/png', body: PIXEL_PNG })
	);
	return { context, page: await context.newPage() };
}

async function waitForPasta(page: Page, order?: Order) {
	await expect(page.getByRole('heading', { name: 'Minha pasta', level: 1 })).toBeVisible();
	await expect(page.locator('section[aria-busy="false"]')).toBeVisible();
	await expect(indicators(page)).toHaveCount(3);
	await expect(setList(page).locator(':scope > li').first()).toBeVisible();
	if (order) {
		await expect(
			page.getByRole('list', { name: 'Ordenar sets' }).locator('a[aria-current="page"]')
		).toHaveText(order === 'recent' ? 'Recentes' : 'Por código');
	}
}

async function openPasta(page: Page, order: Order) {
	await page.goto(`pasta?order=${order}`);
	await waitForPasta(page, order);
}

// O DOM da pasta da SPA, no mesmo formato de `apiSnapshot`.
function spaSnapshot(page: Page): Promise<Snapshot> {
	return page.evaluate(() => {
		const squash = (text: string | null | undefined) => (text ?? '').replace(/\s+/g, ' ').trim();
		const stats = [...document.querySelectorAll('main .summary .card')].map((card) => ({
			value: squash(card.querySelector('.visually-hidden')?.textContent),
			label: squash(card.querySelector('.label')?.textContent),
			note: card.querySelector('.note') ? squash(card.querySelector('.note')?.textContent) : null
		}));
		const rows = document.querySelector('ul.sets')?.querySelectorAll(':scope > li') ?? [];
		const sets = [...rows].map((li) => {
			const numbers = squash(li.querySelector('.numbers')?.textContent);
			const known = /^(\d+) \/ (\d+) · (\d+)%$/.exec(numbers);
			const paragraphs = [...li.querySelectorAll('p')].map((p) => squash(p.textContent));
			return {
				code: squash(li.querySelector('code')?.textContent),
				name: squash(li.querySelector('a')?.textContent),
				owned: known ? known[1] : numbers,
				total: known ? known[2] : null,
				percent: known ? `${known[3]}%` : null,
				basis: paragraphs[0],
				parallels: paragraphs[paragraphs.length - 2],
				value: paragraphs[paragraphs.length - 1]
			};
		});
		return { stats, sets };
	});
}

type ProgressData = {
	summary: {
		total_copies: number;
		distinct_variants: number;
		estimated_value: { amount: string; currency: string };
		unpriced_copies: number;
	};
	sets: {
		code: string;
		name: string;
		owned_numbers: number;
		base_size: number | null;
		completion_percent: number | null;
		parallel_owned: number;
		parallel_total: number;
		value: { amount: string; currency: string };
	}[];
};

const moneyFormat = new Intl.NumberFormat('pt-BR', {
	minimumFractionDigits: 2,
	maximumFractionDigits: 2
});
const money = ({ amount, currency }: { amount: string; currency: string }) => {
	expect(currency, 'moeda da API').toBe('USD');
	return `US$ ${moneyFormat.format(Number(amount))}`;
};
const plural = (n: number, one: string, many: string) => (n === 1 ? one : many);

// O que a tela deve mostrar, calculado de `GET /api/progress` (a fonte dos números), com a sessão da página.
async function apiSnapshot(page: Page, order: Order): Promise<Snapshot> {
	const path = `/api/progress?order=${order}`;
	const response = await page.context().request.get(path);
	expect(response.ok(), `GET ${path}`).toBe(true);
	const { data } = (await response.json()) as { data: ProgressData };
	const { summary } = data;

	return {
		stats: [
			{
				value: String(summary.total_copies),
				label: plural(summary.total_copies, 'carta na pasta', 'cartas na pasta'),
				note: null
			},
			{
				value: String(summary.distinct_variants),
				label: plural(summary.distinct_variants, 'carta diferente', 'cartas diferentes'),
				note: null
			},
			{
				value: money(summary.estimated_value),
				label: 'valor estimado',
				note:
					summary.unpriced_copies > 0
						? `${summary.unpriced_copies} ${plural(summary.unpriced_copies, 'cópia', 'cópias')} sem preço`
						: null
			}
		],
		sets: data.sets.map((set) => ({
			code: set.code,
			name: set.name,
			owned: String(set.owned_numbers),
			total: set.base_size === null ? null : String(set.base_size),
			percent: set.base_size === null ? null : `${set.completion_percent}%`,
			basis:
				set.base_size === null
					? 'Percentual indisponível: este set não informa o tamanho do set base.'
					: `${set.owned_numbers} de ${set.base_size} do set base`,
			parallels: `${set.parallel_owned} de ${set.parallel_total} ${plural(set.parallel_total, 'parallel', 'parallels')}`,
			value: `valor ${money(set.value)}`
		}))
	};
}

async function expectNoHorizontalScroll(page: Page, where: string) {
	const { scrollWidth, clientWidth } = await page.evaluate(() => ({
		scrollWidth: document.documentElement.scrollWidth,
		clientWidth: document.documentElement.clientWidth
	}));
	expect(scrollWidth, `scroll horizontal em ${where}`).toBeLessThanOrEqual(clientWidth);
}

const owners: Owner[] = [];

test.describe.configure({ mode: 'serial' });

test.beforeAll(async ({ browser }) => {
	test.setTimeout(240_000);
	for (const [index, plan] of PLANS.entries()) owners[index] = await createOwner(browser, plan);
});

test.describe('paridade da pasta com GET /api/progress (SPAS-17, SPAS-18, SPAS-26)', () => {
	for (const [index, plan] of PLANS.entries()) {
		for (const order of ORDERS) {
			test(`usuário ${plan.label}, ordem ${order}: indicadores e sets iguais aos da API`, async ({
				browser
			}) => {
				const { context, page } = await openAs(browser, owners[index], {
					viewport: { width: 1280, height: 800 }
				});
				await openPasta(page, order);

				const api = await apiSnapshot(page, order);
				const spa = await spaSnapshot(page);

				expect(api.sets.length, 'a /api/progress lista sets').toBeGreaterThan(0);
				expect(spa.stats, 'três indicadores, com rótulo e nota').toEqual(api.stats);
				expect(
					spa.sets.map((set) => set.code),
					'sequência de `code`'
				).toEqual(api.sets.map((set) => set.code));
				for (const [position, expected] of api.sets.entries()) {
					expect(spa.sets[position], `set ${expected.code}`).toEqual(expected);
				}
				expect(
					spa.sets.reduce((sum, set) => sum + Number(set.owned), 0),
					'o usuário tem posse em algum set'
				).toBeGreaterThan(0);
				expect(
					spa.sets.some((set) => set.value !== 'valor US$ 0,00'),
					'algum set tem valor diferente de US$ 0,00'
				).toBe(true);
				expect(
					spa.sets.some((set) => /^[1-9]\d* de /.test(set.parallels)),
					'algum set tem parallels possuídos'
				).toBe(true);
				await context.close();
			});
		}
	}

	test('os dois usuários enxergam coleções diferentes', async ({ browser }) => {
		const totals: string[] = [];
		for (const owner of owners) {
			const { context, page } = await openAs(browser, owner, {
				viewport: { width: 1280, height: 800 }
			});
			await openPasta(page, 'code');
			totals.push((await spaSnapshot(page)).stats[0].value);
			await context.close();
		}
		expect(totals[0], 'total de cartas').not.toBe(totals[1]);
	});
});

test.describe('sessão e navegação (SPAS-01, SPAS-02, SPAS-03)', () => {
	test('anônimo em /pasta?order=code termina em /entrar?return_to=… sem chamar /api/progress', async ({
		browser
	}) => {
		const { context, page } = await openAs(browser, null);
		const calls: string[] = [];
		page.on('request', (request) => {
			if (new URL(request.url()).pathname.startsWith('/api/progress')) calls.push(request.url());
		});

		await page.goto('pasta?order=code');
		await expect(page).toHaveURL(/\/entrar\?return_to=/);
		expect(new URL(page.url()).searchParams.get('return_to')).toBe('/pasta?order=code');
		await expect(page.getByRole('heading', { name: 'Entrar', level: 1 })).toBeVisible();
		await expect(page.getByRole('button', { name: 'Entrar' })).toBeVisible();
		expect(calls, 'GET /api/progress observados').toEqual([]);
		await context.close();
	});

	test('/app/entrar?return_to=%2Fapp%2Fpasta redireciona, entra e termina em /pasta (STRO-11, STRO-21)', async ({
		browser
	}) => {
		const { context, page } = await openAs(browser, null);

		await page.goto('app/entrar?return_to=%2Fapp%2Fpasta');
		await expect(page).toHaveURL(/\/entrar\?return_to=%2Fapp%2Fpasta$/);
		expect(new URL(page.url()).pathname, 'o prefixo /app saiu do caminho').toBe('/entrar');
		await expect(page.getByRole('heading', { name: 'Entrar', level: 1 })).toBeVisible();

		await page.getByLabel('E-mail').fill(owners[0].email);
		await page.getByLabel('Senha', { exact: true }).fill(PASSWORD);
		await page.getByRole('button', { name: 'Entrar' }).click();

		await expect(page).toHaveURL(/^https?:\/\/[^/]+\/pasta$/);
		await waitForPasta(page);
		await expect(mainNav(page).getByRole('button', { name: 'Sair' })).toBeVisible();
		await context.close();
	});

	test('/progress e /app/pasta?order=code redirecionam para /pasta preservando a query (STRO-11, STRO-12)', async ({
		browser
	}) => {
		const { context, page } = await openAs(browser, owners[0], {
			viewport: { width: 1280, height: 800 }
		});

		await page.goto('progress?order=code');
		await expect(page).toHaveURL(/^https?:\/\/[^/]+\/pasta\?order=code$/);
		await waitForPasta(page, 'code');

		await page.goto('app/pasta?order=recent');
		await expect(page).toHaveURL(/^https?:\/\/[^/]+\/pasta\?order=recent$/);
		await waitForPasta(page, 'recent');
		await context.close();
	});

	test('"Minha pasta" do casco navega sem recarga e fica aria-current', async ({ browser }) => {
		const { context, page } = await openAs(browser, owners[0], {
			viewport: { width: 1280, height: 800 }
		});
		await page.goto('');
		await expect(page.getByRole('heading', { name: 'Catálogo', level: 1 })).toBeVisible();
		await page.evaluate(() => {
			(window as unknown as { __kept: boolean }).__kept = true;
		});

		const link = mainNav(page).getByRole('link', { name: 'Minha pasta' });
		await expect(link).not.toHaveAttribute('aria-current', 'page');
		await link.click();

		await expect(page).toHaveURL(/\/pasta\/?$/);
		await waitForPasta(page);
		await expect(page).toHaveTitle('Minha pasta — Bindr');
		await expect(mainNav(page).getByRole('link', { name: 'Minha pasta' })).toHaveAttribute(
			'aria-current',
			'page'
		);
		expect(
			await page.evaluate(() => (window as unknown as { __kept?: boolean }).__kept),
			'a página não recarregou'
		).toBe(true);
		await context.close();
	});
});

for (const viewport of VIEWPORTS) {
	for (const scheme of SCHEMES) {
		test(`sem scroll horizontal com todos os sets a ${viewport.name}, tema ${scheme} (SPAS-26)`, async ({
			browser
		}) => {
			const { context, page } = await openAs(browser, owners[0], {
				viewport: { width: viewport.width, height: viewport.height },
				colorScheme: scheme
			});
			for (const order of ORDERS) {
				await openPasta(page, order);
				expect(await page.locator('html').getAttribute('data-theme')).toBe(scheme);
				expect(
					await setList(page).locator(':scope > li').count(),
					'todos os sets do catálogo na lista'
				).toBeGreaterThan(20);
				await expectNoHorizontalScroll(page, `${viewport.name}, ${scheme}, ${order}`);
			}
			await context.close();
		});
	}
}

test('1280px: indicadores de um quarto da coluna e ação na lateral (SPAS-11, SPAS-24)', async ({
	browser
}) => {
	const { context, page } = await openAs(browser, owners[0], {
		viewport: { width: 1280, height: 800 }
	});
	await openPasta(page, 'recent');

	// Quatro trilhas `1fr` com `gap`: um quarto da coluna é o que sobra depois dos três vãos.
	const quarter = await page.locator('main#conteudo').evaluate((el) => {
		const style = getComputedStyle(el);
		const column =
			el.getBoundingClientRect().width -
			parseFloat(style.paddingLeft) -
			parseFloat(style.paddingRight) -
			parseFloat(style.borderLeftWidth) -
			parseFloat(style.borderRightWidth);
		const gap = parseFloat(getComputedStyle(el.querySelector('.summary')!).columnGap);
		return (column - 3 * gap) / 4;
	});
	const cards = await indicators(page).all();
	expect(cards).toHaveLength(3);
	for (const [index, card] of cards.entries()) {
		const { width } = await box(card);
		expect(Math.abs(width - quarter), `indicador #${index}: ${width}px contra ${quarter}px`)
			.toBeLessThanOrEqual(1);
	}

	const link = addCards(page);
	await expect(link).toHaveCount(1);
	await expect(link).toHaveText('Adicionar cartas');
	const navBottom = await box(mainNav(page)).then((nav) => nav.y + nav.height);
	const placement = await link.evaluate((el, navBottom) => {
		const aside = el.closest('.aside');
		const block = el.closest('.add')!;
		const border = parseFloat(getComputedStyle(block).borderTopWidth);
		const main = document.querySelector('main#conteudo')!.getBoundingClientRect();
		const linkRect = el.getBoundingClientRect();
		const blockRect = block.getBoundingClientRect();
		return {
			inAside: aside !== null,
			border,
			position: getComputedStyle(block).position,
			belowDivider: linkRect.top >= blockRect.top + border,
			beforeMain: linkRect.right <= main.left + 1,
			belowNav: linkRect.top >= navBottom
		};
	}, navBottom);
	expect(placement.inAside, 'o link mora na coluna lateral').toBe(true);
	expect(placement.border, 'divisor de 1px acima da ação').toBe(1);
	expect(placement.position, 'a ação lateral não é fixa').not.toBe('fixed');
	expect(placement.belowDivider, 'a ação fica abaixo do divisor').toBe(true);
	expect(placement.beforeMain, 'a ação fica à esquerda do conteúdo').toBe(true);
	expect(placement.belowNav, 'a ação fica abaixo da navegação').toBe(true);
	await context.close();
});

test('390px: ação fixa acima da barra e último set visível acima dela (SPAS-24)', async ({
	browser
}) => {
	const { context, page } = await openAs(browser, owners[0], {
		viewport: { width: 390, height: 844 }
	});
	await openPasta(page, 'code');

	const link = addCards(page);
	await expect(link).toHaveCount(1);
	await expect(link).toHaveText('Adicionar cartas à pasta');
	expect(await link.evaluate((el) => getComputedStyle(el.closest('.add')!).position)).toBe('fixed');
	const nav = await box(mainNav(page));
	const action = await box(link);
	expect(action.y + action.height, 'a ação termina acima da barra inferior').toBeLessThanOrEqual(
		nav.y + 0.5
	);

	const lastSet = setList(page).locator(':scope > li').last();
	await page.evaluate(() => window.scrollTo(0, document.documentElement.scrollHeight));
	const last = await box(lastSet);
	expect(last.y + last.height, 'o último set termina acima da ação fixa').toBeLessThanOrEqual(
		(await box(link)).y + 0.5
	);
	await expect(lastSet).toBeInViewport({ ratio: 1 });
	await context.close();
});

test.describe('animação dos indicadores (SPAS-12, SPAS-14, SPAS-16)', () => {
	type Samples = { widths: number[]; texts: string[] }[];

	const sampler = () => {
		const samples: Samples = [];
		(window as unknown as { __samples: Samples }).__samples = samples;
		const tick = () => {
			const cards = [...document.querySelectorAll('main .summary .card')];
			if (cards.length === 3) {
				samples.push({
					widths: cards.map((card) => card.getBoundingClientRect().width),
					texts: cards.map((card) => (card.querySelector('.number')?.textContent ?? '').trim())
				});
			}
			requestAnimationFrame(tick);
		};
		requestAnimationFrame(tick);
	};
	const readSamples = (page: Page) =>
		page.evaluate(() => (window as unknown as { __samples: Samples }).__samples);

	test('a largura do cartão não muda e o texto final é o valor da API', async ({
		browser
	}) => {
		const { context, page } = await openAs(browser, owners[1], {
			viewport: { width: 1280, height: 800 },
			reducedMotion: 'no-preference'
		});
		await page.addInitScript(sampler);
		await openPasta(page, 'recent');
		const finals = (await apiSnapshot(page, 'recent')).stats.map((stat) => stat.value);

		await expect
			.poll(async () => (await page.locator('main .summary .card .number').allTextContents()).map(squash))
			.toEqual(finals);
		await expect
		.poll(async () => (await readSamples(page)).at(-1)?.texts.map(squash))
		.toEqual(finals);

		const samples = await readSamples(page);
		expect(samples.length, 'quadros amostrados').toBeGreaterThan(2);
		for (const column of [0, 1, 2]) {
			const widths = samples.map((sample) => sample.widths[column]);
			expect(
				Math.max(...widths) - Math.min(...widths),
				`largura do indicador #${column} durante a animação`
			).toBeLessThanOrEqual(0.5);
		}
		const intermediate = samples.filter((sample) =>
			sample.texts.some((text, column) => squash(text) !== finals[column])
		);
		expect(intermediate.length, 'houve valor intermediário (a animação rodou)').toBeGreaterThan(0);
		for (const sample of intermediate) {
			expect(squash(sample.texts[2]), 'valor intermediário em dólar').toMatch(/^US\$ /);
		}
		expect(samples[samples.length - 1].texts.map(squash), 'último quadro').toEqual(finals);
		await context.close();
	});

	test('com reduced motion o primeiro quadro já é o final', async ({ browser }) => {
		const { context, page } = await openAs(browser, owners[1], {
			viewport: { width: 1280, height: 800 },
			reducedMotion: 'reduce'
		});
		await page.addInitScript(sampler);
		await openPasta(page, 'recent');
		const finals = (await apiSnapshot(page, 'recent')).stats.map((stat) => stat.value);

		const samples = await readSamples(page);
		expect(samples.length, 'quadros amostrados').toBeGreaterThan(0);
		for (const [index, sample] of samples.entries()) {
			expect(sample.texts.map(squash), `quadro #${index}`).toEqual(finals);
		}
		await context.close();
	});
});

for (const width of [390, 1280]) {
	test(`captura de /pasta a ${width}px para o dono (SPAS-26)`, async ({ browser }) => {
		const { context, page } = await openAs(browser, owners[0], {
			viewport: { width, height: width === 390 ? 844 : 800 },
			reducedMotion: 'reduce'
		});
		await openPasta(page, 'recent');
		await page.screenshot({ path: `${CAPTURES_DIR}/spa-pasta-${width}.png`, fullPage: true });
		await context.close();
	});
}
