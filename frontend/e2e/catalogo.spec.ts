import { expect, test, type APIRequestContext, type Page } from '@playwright/test';

type Combo = { name: string; width: number; height: number; scheme: 'light' | 'dark' };

const COMBOS: Combo[] = [
	{ name: '360x740 claro', width: 360, height: 740, scheme: 'light' },
	{ name: '360x740 escuro', width: 360, height: 740, scheme: 'dark' },
	{ name: '1280x800 claro', width: 1280, height: 800, scheme: 'light' },
	{ name: '1280x800 escuro', width: 1280, height: 800, scheme: 'dark' }
];

type Listing = { total: number; tiles: string[] };

const encode = (pairs: [string, string][]) => new URLSearchParams(pairs).toString();

const SET_CODE = 'OP01';

const totalFrom = (text: string | null) => Number(/(\d+)\s+cartas?/.exec(text ?? '')?.[1] ?? NaN);

// Número e nome de cada carta, na ordem da API, mais o total, com a mesma query da tela.
async function readApi(request: APIRequestContext, query: string): Promise<Listing> {
	const response = await request.get(`/api/catalog?${query}`);
	expect(response.ok(), `GET /api/catalog?${query}`).toBe(true);
	const { data, meta } = (await response.json()) as {
		data: { card_number: string; name: string }[];
		meta: { total_count: number };
	};
	return {
		total: meta.total_count,
		tiles: data.map((card) => `${card.card_number} | ${card.name}`)
	};
}

const STATUS_SENTENCE = /^\d+ cartas?( · \d+ filtros? ativos?)?$/;

// A frase aparece duas vezes por desenho (SCAT-44): no parágrafo visível e no anúncio fora da vista.
const spaStatus = (page: Page) => page.locator('p[tabindex="-1"]').filter({ hasText: STATUS_SENTENCE });
const spaAnnouncement = (page: Page) => page.getByRole('status').filter({ hasText: STATUS_SENTENCE });

async function waitForSpaCatalog(page: Page) {
	await expect(page.getByRole('heading', { name: 'Catálogo', level: 1 })).toBeVisible();
	// A linha de status só existe com o resultado da API na tela; só então o skeleton já saiu.
	await expect(spaStatus(page)).toBeVisible();
	await expect(page.locator('section[aria-busy="false"]')).toBeVisible();
}

async function readSpaListing(page: Page): Promise<Listing> {
	const total = totalFrom(await spaStatus(page).textContent());
	const tiles = await page
		.locator('ul.grid li')
		.evaluateAll((items) =>
			items.map(
				(item) =>
					`${item.querySelector('.number')?.textContent?.trim()} | ${item.querySelector('.name')?.textContent?.trim()}`
			)
		);
	return { total, tiles };
}

async function readSpa(page: Page, query: string): Promise<Listing> {
	await page.goto(`/?${query}`);
	await waitForSpaCatalog(page);
	return readSpaListing(page);
}

async function expectNoHorizontalScroll(page: Page, where: string) {
	const { scrollWidth, clientWidth } = await page.evaluate(() => ({
		scrollWidth: document.documentElement.scrollWidth,
		clientWidth: document.documentElement.clientWidth
	}));
	expect(scrollWidth, `scroll horizontal em ${where}`).toBeLessThanOrEqual(clientWidth);
}

for (const combo of COMBOS) {
	test.describe(`paridade entre a tela e GET /api/catalog a ${combo.name} (SCAT-05, SCAT-27)`, () => {
		test.use({ viewport: { width: combo.width, height: combo.height }, colorScheme: combo.scheme });

		const queries: { name: string; query: string }[] = [
			{ name: 'busca por card_number', query: encode([['q', 'OP01-024']]) },
			{
				name: 'duas cores',
				query: encode([
					['colors[]', 'Red'],
					['colors[]', 'Green']
				])
			},
			{ name: 'um set', query: encode([['sets[]', SET_CODE]]) },
			{
				name: 'faixa de custo',
				query: encode([
					['cost_min', '2'],
					['cost_max', '4']
				])
			},
			{
				name: 'ordenação por nome decrescente',
				query: encode([
					['sort', 'name'],
					['dir', 'desc']
				])
			},
			{ name: 'segunda página', query: encode([['page', '2']]) },
			{
				name: 'filtros combinados com ordenação e página',
				query: encode([
					['colors[]', 'Red'],
					['sets[]', SET_CODE],
					['cost_min', '1'],
					['cost_max', '9'],
					['sort', 'name'],
					['dir', 'desc'],
					['per_page', '5'],
					['page', '2']
				])
			}
		];

		for (const { name, query } of queries) {
			test(`${name}: mesma lista, mesma ordem e mesmo total`, async ({ page }) => {
				const api = await readApi(page.request, query);
				const spa = await readSpa(page, query);

				expect(api.total, 'total de /api/catalog (catálogo importado)').toBeGreaterThan(0);
				expect(api.tiles.length, 'cartas em /api/catalog').toBeGreaterThan(0);
				expect(spa.total, `total de /?${query}`).toBe(api.total);
				expect(spa.tiles, `cartas de /?${query}`).toEqual(api.tiles);
			});
		}

		test('busca por OP01-024 traz a carta exata em primeiro', async ({ page }) => {
			const query = encode([['q', 'OP01-024']]);
			const api = await readApi(page.request, query);
			const spa = await readSpa(page, query);

			expect(api.tiles[0]).toMatch(/^OP01-024 \|/);
			expect(spa.tiles[0]).toMatch(/^OP01-024 \|/);
		});
	});
}

test.describe('URL antiga do catálogo (STRO-11, STRO-34)', () => {
	test('/catalog?colors[]=Red&sort=name abre a tela na raiz com o resultado da API', async ({
		page
	}) => {
		const query = encode([
			['colors[]', 'Red'],
			['sort', 'name']
		]);
		await page.goto(`/catalog?${query}`);
		await waitForSpaCatalog(page);

		const url = new URL(page.url());
		expect(url.pathname, 'caminho depois do redirecionamento').toBe('/');
		expect(url.searchParams.getAll('colors[]')).toEqual(['Red']);
		expect(url.searchParams.get('sort')).toBe('name');

		const api = await readApi(page.request, query);
		const spa = await readSpaListing(page);
		expect(api.tiles.length, 'cartas em /api/catalog').toBeGreaterThan(0);
		expect(spa.total, 'total na tela').toBe(api.total);
		expect(spa.tiles, 'cartas na tela').toEqual(api.tiles);
	});
});

test.describe('busca e paginação pela URL (SCAT-16, SCAT-27, SCAT-36)', () => {
	test('enviar a busca apara o termo, mantém filtros e ordenação e descarta a página', async ({
		page
	}) => {
		await page.goto(
			`/?${encode([
				['colors[]', 'Red'],
				['sort', 'name'],
				['dir', 'desc'],
				['page', '2']
			])}`
		);
		await waitForSpaCatalog(page);

		await page.getByLabel('Buscar por nome ou card_number').fill('  OP01-024  ');
		await page.getByRole('button', { name: 'Buscar' }).click();

		await expect.poll(() => new URL(page.url()).searchParams.get('q')).toBe('OP01-024');
		const params = new URL(page.url()).searchParams;
		expect(params.getAll('colors[]')).toEqual(['Red']);
		expect(params.get('sort')).toBe('name');
		expect(params.get('dir')).toBe('desc');
		expect(params.has('page')).toBe(false);

		await page.getByLabel('Buscar por nome ou card_number').fill('   ');
		await page.getByRole('button', { name: 'Buscar' }).click();
		await expect.poll(() => new URL(page.url()).searchParams.has('q')).toBe(false);
		expect(new URL(page.url()).searchParams.getAll('colors[]')).toEqual(['Red']);
	});

	const paginationCases: { name: string; params: [string, string][] }[] = [
		{
			name: 'faixas e ordenação',
			params: [
				['cost_min', '1'],
				['cost_max', '9'],
				['sort', 'name'],
				['dir', 'desc']
			]
		},
		{
			name: 'duas cores',
			params: [
				['colors[]', 'Red'],
				['colors[]', 'Green']
			]
		},
		{ name: 'um set', params: [['sets[]', SET_CODE]] },
		{ name: 'termo de busca', params: [['q', 'Luffy']] }
	];

	for (const { name, params } of paginationCases) {
		test(`a paginação leva os filtros a cada link: ${name}`, async ({ page }) => {
			await page.goto(`/?${encode([...params, ['page', '2']])}`);
			await waitForSpaCatalog(page);

			const pagination = page.getByRole('navigation', { name: 'Paginação do catálogo' });
			await expect(pagination).toBeVisible();
			await expect(pagination.getByText(/^Página 2 de \d+$/)).toBeVisible();

			const linkParams = async (linkName: string) => {
				const link = pagination.getByRole('link', { name: linkName });
				await expect(link, `link "${linkName}"`).toHaveCount(1);
				return new URL((await link.getAttribute('href'))!, page.url()).searchParams;
			};
			const expected = new URLSearchParams(encode(params));

			for (const [linkName, target] of [
				['Anterior', '1'],
				['Próxima', '3']
			]) {
				const actual = await linkParams(linkName);
				expect(actual.get('page'), `${linkName}: page`).toBe(target);
				for (const key of new Set(expected.keys())) {
					expect(actual.getAll(key), `${linkName}: ${key}`).toEqual(expected.getAll(key));
				}
			}
		});
	}
});

for (const combo of COMBOS) {
	test.describe(`catálogo a ${combo.name}`, () => {
		test.use({ viewport: { width: combo.width, height: combo.height }, colorScheme: combo.scheme });

		test('sem scroll horizontal, tema certo e região de anúncio fora da vista (SCAT-14)', async ({
			page
		}) => {
			for (const query of ['', encode([['colors[]', 'Red']]), encode([['q', 'zzzz-sem-resultado']])]) {
				await page.goto(`/?${query}`);
				await waitForSpaCatalog(page);

				expect(await page.locator('html').getAttribute('data-theme')).toBe(combo.scheme);
				await expectNoHorizontalScroll(page, `/?${query} a ${combo.name}`);
			}

			const announcement = spaAnnouncement(page);
			await expect(announcement).toHaveCount(1);
			await expect(announcement).toHaveText((await spaStatus(page).textContent())!);
			const box = (await announcement.boundingBox())!;
			expect(box.width, 'largura da região de anúncio').toBeLessThanOrEqual(1);
			expect(box.height, 'altura da região de anúncio').toBeLessThanOrEqual(1);
			expect(await announcement.evaluate((el) => getComputedStyle(el).clipPath)).toBe('inset(50%)');
		});

		test('grade com a quantidade de colunas do viewport (SCAT-14)', async ({ page }) => {
			await page.goto('/');
			await waitForSpaCatalog(page);

			const grid = page.locator('ul.grid');
			await expect(grid.locator('li').first()).toBeVisible();

			const columns = await grid.evaluate(
				(el) => getComputedStyle(el).gridTemplateColumns.split(' ').length
			);
			expect(columns, `colunas a ${combo.width}px`).toBe(combo.width >= 1024 ? 5 : 2);
			await expectNoHorizontalScroll(page, `grade a ${combo.name}`);
		});
	});
}
