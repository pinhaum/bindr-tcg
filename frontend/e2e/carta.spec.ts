import { expect, test, type APIRequestContext, type Page } from '@playwright/test';

type Variant = {
	variant_code: string;
	rarity: string | null;
	in_source: boolean;
	price: unknown;
	set: { code: string; name: string };
};
type Card = {
	card_number: string;
	name: string;
	card_type: string;
	counter: number | null;
	variants: Variant[];
};
type Sample = { leader: Card; character: Card; event: Card };

const WIDE_MIN_WIDTH = 1024;
const MAX_PAGES = 10;
const PIXEL_PNG = Buffer.from(
	'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
	'base64'
);

const VIEWPORTS = [
	{ name: '360px', width: 360, height: 740 },
	{ name: '1280px', width: 1280, height: 800 }
];
const SCHEMES = ['light', 'dark'] as const;
const COMBOS = VIEWPORTS.flatMap((viewport) =>
	SCHEMES.map((scheme) => ({ ...viewport, scheme, label: `${viewport.name}, tema ${scheme}` }))
);

const hasMixedPrices = (card: Card) => {
	const priced = card.variants.map((variant) => variant.price !== null);
	return priced.some(Boolean) && !priced.every(Boolean);
};

// Cartas reais do catálogo importado: um Leader, um Character com counter, preço e "Sem preço"
// misturados, e um Event; os dois últimos com 3+ variantes.
const WANTED: { key: keyof Sample; type: string; accept: (card: Card) => boolean }[] = [
	{ key: 'leader', type: 'leader', accept: (card) => card.variants.length >= 2 },
	{
		key: 'character',
		type: 'character',
		accept: (card) => card.variants.length >= 3 && card.counter !== null && hasMixedPrices(card)
	},
	{ key: 'event', type: 'event', accept: (card) => card.variants.length >= 3 }
];

async function findCard(
	request: APIRequestContext,
	type: string,
	accept: (card: Card) => boolean
): Promise<Card> {
	for (let pageNumber = 1; pageNumber <= MAX_PAGES; pageNumber++) {
		const response = await request.get(
			`/api/catalog?${new URLSearchParams([
				['card_types[]', type],
				['per_page', '100'],
				['page', String(pageNumber)]
			])}`
		);
		expect(response.ok(), `GET /api/catalog (${type}, página ${pageNumber})`).toBe(true);
		const { data } = (await response.json()) as { data: Card[] };
		const found = data.find(accept);
		if (found) return found;
		if (data.length === 0) break;
	}
	throw new Error(`nenhuma carta "${type}" do catálogo importado serve ao teste`);
}

let samplePromise: Promise<Sample> | undefined;
const sample = (request: APIRequestContext) =>
	(samplePromise ??= (async () => {
		const found: Partial<Sample> = {};
		for (const { key, type, accept } of WANTED) found[key] = await findCard(request, type, accept);
		return found as Sample;
	})());

// O CDN da arte responde 403 (a pilha devolve 502): a rota devolve uma imagem mínima e o teste
// não depende dele.
const stubImages = (page: Page) =>
	page.route('**/card_images/**', (route) =>
		route.fulfill({ status: 200, contentType: 'image/png', body: PIXEL_PNG })
	);

const variantQuery = (variant?: string) =>
	variant === undefined ? '' : `?variant=${encodeURIComponent(variant)}`;
const detailPath = (card: Card, variant?: string) =>
	`/app/cartas/${encodeURIComponent(card.card_number)}${variantQuery(variant)}`;
const hotwirePath = (card: Card, variant?: string) =>
	`/cards/${encodeURIComponent(card.card_number)}${variantQuery(variant)}`;

const backLink = (page: Page) => page.getByRole('link', { name: 'Voltar ao catálogo', exact: true });
const variantThumb = (page: Page, code: string) =>
	page.getByRole('link', { name: `Mostrar ${code} na imagem principal`, exact: true });

async function waitForDetail(page: Page, card: Card) {
	await expect(page.getByRole('heading', { name: card.name, level: 1, exact: true })).toBeVisible();
	await expect(page.locator('section.detail[aria-busy="false"]')).toBeVisible();
	await expect(page.locator('section.variants li.row').first()).toBeVisible();
}

async function openDetail(page: Page, card: Card, variant?: string) {
	await page.goto(detailPath(card, variant));
	await waitForDetail(page, card);
}

async function expectNoHorizontalScroll(page: Page, where: string) {
	const { scrollWidth, clientWidth } = await page.evaluate(() => ({
		scrollWidth: document.documentElement.scrollWidth,
		clientWidth: document.documentElement.clientWidth
	}));
	expect(scrollWidth, `scroll horizontal em ${where}`).toBeLessThanOrEqual(clientWidth);
}

type MarkedWindow = { __documentMark?: string };
const markDocument = (page: Page) =>
	page.evaluate(() => {
		(window as unknown as MarkedWindow).__documentMark = 'mesmo-documento';
	});
const readDocumentMark = (page: Page) =>
	page.evaluate(() => (window as unknown as MarkedWindow).__documentMark);

type Detail = {
	fields: string[];
	chips: string[];
	set: string;
	illustrator: string | null;
	variants: { code: string; kind: string | null; set: string; price: string }[];
	featured: string[];
};

// Nomes e valores dos campos, chips, linhas de variante e destaque, em texto normalizado: é o que
// o usuário lê, e o que as duas telas têm de dizer igual.
async function readHotwire(page: Page, card: Card, variant?: string): Promise<Detail> {
	await stubImages(page);
	await page.goto(hotwirePath(card, variant));
	await expect(page.locator('main.card-detail h1')).toBeVisible();
	return page.evaluate(() => {
		const text = (el: Element | null | undefined) =>
			el?.textContent?.replace(/\s+/g, ' ').trim() ?? '';
		const optional = (selector: string) => {
			const el = document.querySelector(selector);
			return el ? text(el) : null;
		};
		const items = [...document.querySelectorAll('.variant')];
		return {
			fields: [...document.querySelectorAll('.card-detail__fields .field')].map(
				(field) => `${text(field.querySelector('dt'))}: ${text(field.querySelector('dd'))}`
			),
			chips: [...document.querySelectorAll('.card-detail__chips li')].map((chip) => text(chip)),
			set: text(document.querySelector('.card-detail__set')),
			illustrator: optional('.card-detail__illustrator'),
			variants: items.map((item) => {
				const kind = item.querySelector('.variant__rarity');
				return {
					code: text(item.querySelector('.variant__code')),
					kind: kind ? text(kind) : null,
					set: text(item.querySelector('.variant__set')),
					price: text(item.querySelector('.variant__price'))
				};
			}),
			featured: items
				.filter((item) => item.classList.contains('variant--current'))
				.map((item) => text(item.querySelector('.variant__code')))
		};
	});
}

async function readSpa(page: Page, card: Card, variant?: string): Promise<Detail> {
	await stubImages(page);
	await openDetail(page, card, variant);
	return page.evaluate(() => {
		const text = (el: Element | null | undefined) =>
			el?.textContent?.replace(/\s+/g, ' ').trim() ?? '';
		const optional = (selector: string) => {
			const el = document.querySelector(selector);
			return el ? text(el) : null;
		};
		const rows = [...document.querySelectorAll('section.variants li.row')];
		return {
			// O Hotwire não lista o Counter entre os campos (só como chip, a partir de 64rem); o SPA o
			// lista por SCAR-17, e a checagem dele fica num teste próprio.
			fields: [...document.querySelectorAll('dl.fields .field')]
				.map((field) => `${text(field.querySelector('dt'))}: ${text(field.querySelector('dd'))}`)
				.filter((field) => !field.startsWith('Counter: ')),
			chips: [...document.querySelectorAll('ul.chips li')].map((chip) => text(chip)),
			set: text(document.querySelector('header p.set')),
			illustrator: optional('header p.illustrator'),
			variants: rows.map((row) => {
				const metas = [...row.querySelectorAll('.info > p.meta')]
					.map((meta) => text(meta))
					.filter((meta) => meta !== 'fora da fonte');
				return {
					code: text(row.querySelector('.info p.code')),
					kind: metas.length > 1 ? metas[0] : null,
					set: metas[metas.length - 1],
					price: text(row.querySelector('.info p.price'))
				};
			}),
			featured: rows
				.filter((row) => row.querySelector('a.thumb')?.getAttribute('aria-current') === 'true')
				.map((row) => text(row.querySelector('.info p.code')))
		};
	});
}

const expectedFeatured = (card: Card, variant?: string) =>
	(
		card.variants.find((item) => item.variant_code === variant) ??
		card.variants.find((item) => item.in_source) ??
		card.variants[0]
	).variant_code;

test.describe('navegação entre catálogo e detalhe sem recarregar a página (SCAR-3, SCAR-4)', () => {
	for (const viewport of VIEWPORTS) {
		test(`tile abre o detalhe e "Voltar ao catálogo" volta, a ${viewport.name}`, async ({
			page,
			request
		}) => {
			const { character } = await sample(request);
			await page.setViewportSize({ width: viewport.width, height: viewport.height });
			await stubImages(page);

			await page.goto(`/app/?${new URLSearchParams([['q', character.card_number]])}`);
			const tile = page.locator(`ul.grid a[href$="/cartas/${character.card_number}"]`);
			await expect(tile).toBeVisible();
			await markDocument(page);

			await tile.click();
			await expect(page).toHaveURL(new RegExp(`/app/cartas/${character.card_number}$`));
			await waitForDetail(page, character);
			expect(await readDocumentMark(page), 'o clique no tile recarregou o documento').toBe(
				'mesmo-documento'
			);
			await expect(page).toHaveTitle(`${character.name} (${character.card_number}) — Bindr`);

			await expect(backLink(page)).toHaveCount(1);
			await backLink(page).click();
			await expect(page).toHaveURL(/\/app\/?$/);
			await expect(page.getByRole('heading', { name: 'Catálogo', level: 1 })).toBeVisible();
			await expect(page.locator('ul.grid li').first()).toBeVisible();
			expect(await readDocumentMark(page), '"Voltar ao catálogo" recarregou o documento').toBe(
				'mesmo-documento'
			);
		});
	}
});

test.describe('paridade do detalhe entre /app/cartas e /cards a 1280px (SCAR-13, SCAR-17, SCAR-19, SCAR-21, SCAR-24)', () => {
	test.use({ viewport: { width: 1280, height: 800 } });

	const cases: { name: string; pick: (card: Card) => string | undefined }[] = [
		{ name: 'sem ?variant=', pick: () => undefined },
		{
			name: 'com ?variant= válido',
			pick: (card) => card.variants[card.variants.length - 1].variant_code
		},
		{ name: 'com ?variant= inválido', pick: () => 'tcgplayer:0-inexistente' }
	];

	for (const key of ['leader', 'character', 'event'] as const) {
		for (const { name, pick } of cases) {
			test(`${key}, ${name}: mesmos campos, chips, variantes, preços e destaque`, async ({
				page,
				request
			}) => {
				const card = (await sample(request))[key];
				const variant = pick(card);

				const hotwire = await readHotwire(page, card, variant);
				const spa = await readSpa(page, card, variant);

				expect(hotwire.variants.length, 'variantes em /cards').toBe(card.variants.length);
				expect(spa.variants, 'variantes (código, rótulo, set, preço)').toEqual(hotwire.variants);
				expect(spa.fields, 'campos').toEqual(hotwire.fields);
				expect(spa.chips, 'chips do cabeçalho').toEqual(hotwire.chips);
				expect(spa.set, 'linha do set').toEqual(hotwire.set);
				expect(spa.illustrator, 'ilustração').toEqual(hotwire.illustrator);

				const featured = expectedFeatured(card, variant);
				expect(hotwire.featured, 'destaque em /cards').toEqual([featured]);
				expect(spa.featured, 'destaque em /app/cartas').toEqual([featured]);
			});
		}
	}

	test('preço e "Sem preço" no formato do SCAR-21, sem sessão', async ({ page, request }) => {
		const { character } = await sample(request);
		await stubImages(page);
		await openDetail(page, character);

		const prices = await page
			.locator('section.variants li.row .price')
			.evaluateAll((items) =>
				items.map((item) => item.textContent?.replace(/\s+/g, ' ').trim() ?? '')
			);
		expect(prices.length, 'uma linha de preço por variante').toBe(character.variants.length);
		for (const price of prices) {
			expect(price).toMatch(
				/^(Sem preço|US\$ \d{1,3}(\.\d{3})*,\d{2} TCGplayer · market · \d{2}\/\d{2}\/\d{4})$/
			);
		}
		expect(prices, 'há uma variante sem preço').toContain('Sem preço');
		expect(
			prices.some((price) => price.startsWith('US$ ')),
			'há uma variante com preço'
		).toBe(true);
	});

	test('campos por tipo: Counter só no Character, Custo, Power e Life conforme o tipo (SCAR-17)', async ({
		page,
		request
	}) => {
		const { leader, character, event } = await sample(request);
		await stubImages(page);
		const labels = async (card: Card) => {
			await openDetail(page, card);
			return page.locator('dl.fields dt').allTextContents();
		};

		const leaderLabels = await labels(leader);
		expect(leaderLabels).toEqual(expect.arrayContaining(['Power', 'Life']));
		for (const absent of ['Custo', 'Counter']) expect(leaderLabels).not.toContain(absent);

		const characterLabels = await labels(character);
		expect(characterLabels).toEqual(expect.arrayContaining(['Custo', 'Power', 'Counter']));
		expect(characterLabels).not.toContain('Life');
		await expect(
			page.locator('dl.fields .field').filter({ hasText: 'Counter' }).locator('dd')
		).toHaveText(String(character.counter));

		const eventLabels = await labels(event);
		expect(eventLabels).toContain('Custo');
		for (const absent of ['Power', 'Life', 'Counter']) expect(eventLabels).not.toContain(absent);
	});
});

for (const combo of COMBOS) {
	test.describe(`layout do detalhe a ${combo.label} (SCAR-4, SCAR-5, SCAR-11, SCAR-12, SCAR-13)`, () => {
		test.use({ viewport: { width: combo.width, height: combo.height }, colorScheme: combo.scheme });

		test('miniatura e "Ver imagem maior" abaixo de 64rem; coluna e chip "Counter" a partir dele', async ({
			page,
			request
		}) => {
			const { character } = await sample(request);
			await stubImages(page);
			await openDetail(page, character);

			expect(await page.locator('html').getAttribute('data-theme')).toBe(combo.scheme);
			const counterChip = page.locator('ul.chips li', { hasText: `Counter ${character.counter}` });
			const details = page.locator('details.expand');

			if (combo.width >= WIDE_MIN_WIDTH) {
				await expect(page.locator('.media')).toBeVisible();
				await expect(page.locator('.media img')).toBeVisible();
				await expect(details).toHaveCount(0);
				await expect(page.locator('header .thumb')).toHaveCount(0);
				await expect(counterChip).toBeVisible();
			} else {
				await expect(page.locator('header .thumb')).toBeVisible();
				await expect(page.locator('.media')).toHaveCount(0);
				await expect(details).toHaveCount(1);
				expect(
					await details.evaluate((el: HTMLDetailsElement) => el.open),
					'fechado por padrão'
				).toBe(false);
				await expect(details.locator('summary')).toHaveText('Ver imagem maior');
				await expect(details.locator('summary')).toBeVisible();
				await expect(counterChip).toHaveCount(0);

				await details.locator('summary').click();
				expect(await details.evaluate((el: HTMLDetailsElement) => el.open)).toBe(true);
				await expect(details.locator('img')).toBeVisible();
			}

			await expectNoHorizontalScroll(page, `detalhe a ${combo.label}`);
		});

		test('"Voltar ao catálogo" é um botão bordado de 44px ou mais, sem seta (SCAR-4)', async ({
			page,
			request
		}) => {
			const { character } = await sample(request);
			await stubImages(page);
			await openDetail(page, character);

			const back = backLink(page);
			await expect(back).toBeVisible();
			await expect(back).toHaveText('Voltar ao catálogo');
			const found = await back.boundingBox();
			expect(found, 'botão com caixa').not.toBeNull();
			expect(found!.height, 'altura do botão').toBeGreaterThanOrEqual(44);
			expect(await back.evaluate((el) => getComputedStyle(el).borderTopStyle)).toBe('solid');
		});

		test('404 mostra a mensagem da API, "Voltar ao catálogo" e o título (SCAR-5)', async ({
			page,
			request
		}) => {
			const response = await request.get('/api/cards/NAO-EXISTE');
			expect(response.status()).toBe(404);
			const { error } = (await response.json()) as { error: { code: string; message: string } };
			expect(error.code).toBe('not_found');

			await page.goto('/app/cartas/NAO-EXISTE');
			await expect(page.getByRole('heading', { name: error.message, level: 1 })).toBeVisible();
			await expect(page).toHaveTitle('Carta não encontrada — Bindr');
			await expect(backLink(page)).toBeVisible();
			expect(await page.locator('html').getAttribute('data-theme')).toBe(combo.scheme);
			await expectNoHorizontalScroll(page, `404 a ${combo.label}`);
		});
	});
}

test.describe('variante em destaque pela miniatura (SCAR-10, SCAR-22, SCAR-23)', () => {
	test.use({ viewport: { width: 1280, height: 800 } });

	test('o clique troca o destaque e substitui a URL, sem item novo no histórico nem chamada à API', async ({
		page,
		request
	}) => {
		const { character } = await sample(request);
		const first = character.variants[0];
		const last = character.variants[character.variants.length - 1];
		await stubImages(page);
		await openDetail(page, character);

		const apiReads: string[] = [];
		page.on('request', (req) => {
			if (req.method() === 'GET' && req.url().includes('/api/cards/')) apiReads.push(req.url());
		});
		await markDocument(page);
		const historyBefore = await page.evaluate(() => history.length);

		const firstThumb = variantThumb(page, first.variant_code);
		const lastThumb = variantThumb(page, last.variant_code);
		await expect(firstThumb).toHaveAttribute('aria-current', 'true');
		await expect(lastThumb).not.toHaveAttribute('aria-current');
		expect(await lastThumb.getAttribute('href')).toBe(detailPath(character, last.variant_code));
		await expect(page.locator('.media img')).toHaveAttribute(
			'alt',
			`${character.name} ${first.variant_code}`
		);

		await lastThumb.click();

		await expect
			.poll(() => new URL(page.url()).searchParams.get('variant'))
			.toBe(last.variant_code);
		await expect(lastThumb).toHaveAttribute('aria-current', 'true');
		await expect(page.locator('a[aria-current="true"]')).toHaveCount(1);
		await expect(firstThumb).not.toHaveAttribute('aria-current');
		await expect(page.locator('.media img')).toHaveAttribute(
			'alt',
			`${character.name} ${last.variant_code}`
		);
		await expect(page.locator('header p.set')).toHaveText(`${last.set.name} · ${last.set.code}`);
		if (last.rarity) {
			await expect(page.locator('ul.chips li', { hasText: last.rarity }).first()).toBeVisible();
		}

		expect(await page.evaluate(() => history.length), 'itens no histórico').toBe(historyBefore);
		expect(apiReads, 'leituras da API depois do clique').toEqual([]);
		expect(await readDocumentMark(page), 'o clique recarregou o documento').toBe(
			'mesmo-documento'
		);
	});
});
