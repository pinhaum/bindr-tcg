import { expect, test, type Locator, type Page } from '@playwright/test';

const PASSWORD = 'senha-correta-1';
const STATUS_SENTENCE = /^\d+ cartas?( · \d+ filtros? ativos?)?$/;
const CARD_NUMBER = 'OP01-024';
const WIDE_MIN_WIDTH = 1024;

const VIEWPORTS = [
	{ name: '360px', width: 360, height: 740 },
	{ name: '1280px', width: 1280, height: 800 }
];
const SCHEMES = ['light', 'dark'] as const;
const COMBOS = VIEWPORTS.flatMap((viewport) =>
	SCHEMES.map((scheme) => ({ ...viewport, scheme, label: `${viewport.name}, tema ${scheme}` }))
);

const spaStatus = (page: Page) =>
	page.locator('p[tabindex="-1"]').filter({ hasText: STATUS_SENTENCE });
const activeFilters = (page: Page) => page.getByRole('list', { name: 'Filtros ativos' });
const mainNav = (page: Page) => page.getByRole('navigation', { name: 'Principal' });
const tiles = (page: Page) => page.locator('ul.grid li');
const searchField = (page: Page) => page.getByLabel('Buscar por nome ou card_number');

async function waitForCatalog(page: Page) {
	await expect(page.getByRole('heading', { name: 'Catálogo', level: 1 })).toBeVisible();
	await expect(spaStatus(page)).toBeVisible();
	await expect(page.locator('section[aria-busy="false"]')).toBeVisible();
	await expect(tiles(page).first()).toBeVisible();
}

async function openCatalog(page: Page, pairs: [string, string][] = []) {
	const query = new URLSearchParams(pairs).toString();
	await page.goto(query ? `/app/?${query}` : '/app/');
	await waitForCatalog(page);
}

// O painel só tem o conteúdo (grupos e opções de set) depois do `GET /api/catalog/filters`.
async function waitForPanel(page: Page) {
	await expect(page.getByRole('group', { name: 'Cor' }).getByRole('link').first()).toBeVisible();
	await expect(page.getByLabel('Set', { exact: true }).locator('option[value="OP01"]')).toBeAttached();
}

// Abaixo de 64rem o painel mora num <details> fechado.
async function openPanel(page: Page) {
	const details = page.locator('details');
	if ((await details.count()) > 0) await details.locator('summary').click();
	await waitForPanel(page);
}

// Resolve um valor de token no próprio documento, no tema em vigor: nada de hex nem px no teste.
const resolveToken = (page: Page, property: 'color' | 'width' | 'fontFamily', token: string) =>
	page.evaluate(
		([prop, value]) => {
			const probe = document.createElement('div');
			probe.style.setProperty(prop === 'fontFamily' ? 'font-family' : prop, value);
			document.body.append(probe);
			const resolved = getComputedStyle(probe)[prop as 'color'];
			probe.remove();
			return resolved;
		},
		[property, `var(${token})`] as const
	);

const resolveSpace = async (page: Page, token: string) =>
	parseFloat(await resolveToken(page, 'width', token));

const box = async (locator: Locator) => {
	const found = await locator.boundingBox();
	expect(found, 'elemento visível com caixa').not.toBeNull();
	return found!;
};

async function expectTouchTarget(locator: Locator, what: string) {
	const count = await locator.count();
	expect(count, `há ao menos um(a) ${what}`).toBeGreaterThan(0);
	for (const [index, item] of (await locator.all()).entries()) {
		const { height } = await box(item);
		expect(height, `${what} #${index} tem 44px ou mais de altura`).toBeGreaterThanOrEqual(44);
	}
}

for (const combo of COMBOS) {
	test.describe(`layout do catálogo a ${combo.label}`, () => {
		test.use({ viewport: { width: combo.width, height: combo.height }, colorScheme: combo.scheme });

		test('alvos de 44px em chips, set, "Aplicar", "Buscar" e campo de busca (SCAT-15, SCAT-22)', async ({
			page
		}) => {
			await openCatalog(page, [['colors[]', 'Red']]);
			await openPanel(page);

			await expectTouchTarget(page.locator('.panel .chip'), 'chip do painel');
			await expectTouchTarget(activeFilters(page).locator('.chip'), 'chip ativo');
			await expectTouchTarget(page.getByLabel('Set', { exact: true }), 'seletor "Set"');
			await expectTouchTarget(page.getByRole('button', { name: 'Aplicar' }), 'botão "Aplicar"');
			await expectTouchTarget(page.getByRole('button', { name: 'Buscar' }), 'botão "Buscar"');
			await expectTouchTarget(searchField(page), 'campo de busca');

			await expect(searchField(page)).toHaveAttribute('placeholder', 'OP01-024');
		});

		test('chip ativo tem anel sólido de 2px em accent e o de cor não é preenchido (SCAT-20)', async ({
			page
		}) => {
			await openCatalog(page, [['colors[]', 'Red']]);
			await openPanel(page);
			const accent = await resolveToken(page, 'color', '--accent');

			const rings = [
				['chip ativo da lista', activeFilters(page).getByRole('link', { name: 'Remover filtro Cor: Red' })],
				['chip ativo do painel', page.locator('.panel').getByRole('link', { name: 'Remover filtro Cor: Red' })]
			] as const;

			for (const [what, chip] of rings) {
				await expect(chip, what).toBeVisible();
				const style = await chip.evaluate((el) => {
					const computed = getComputedStyle(el);
					return {
						widths: [
							computed.borderTopWidth,
							computed.borderRightWidth,
							computed.borderBottomWidth,
							computed.borderLeftWidth
						],
						styles: [computed.borderTopStyle, computed.borderLeftStyle],
						colors: [computed.borderTopColor, computed.borderLeftColor],
						background: computed.backgroundColor
					};
				});
				expect(style.widths, `${what}: largura da borda`).toEqual(['2px', '2px', '2px', '2px']);
				expect(style.styles, `${what}: borda sólida`).toEqual(['solid', 'solid']);
				expect(style.colors, `${what}: cor da borda é accent`).toEqual([accent, accent]);
				expect(style.background, `${what}: não é preenchido com accent`).not.toBe(accent);
			}

			const idle = page.locator('.panel').getByRole('link', { name: 'Green', exact: true });
			await expect(idle).toBeVisible();
			expect(await idle.evaluate((el) => getComputedStyle(el).borderTopWidth), 'chip inativo').toBe('1px');

			// SCAT-20/21: a amostra do chip de cor é neutra (borda em border-strong), nunca preenchida com accent.
			const borderStrong = await resolveToken(page, 'color', '--border-strong');
			const swatches = [
				['amostra do chip ativo', page.locator('.panel').getByRole('link', { name: 'Remover filtro Cor: Red' })],
				['amostra do chip inativo', idle]
			] as const;
			for (const [what, chip] of swatches) {
				const swatch = chip.locator('.swatch');
				await expect(swatch, what).toBeVisible();
				const style = await swatch.evaluate((el) => {
					const computed = getComputedStyle(el);
					return {
						background: computed.backgroundColor,
						width: computed.borderTopWidth,
						color: computed.borderTopColor
					};
				});
				expect(style.background, `${what}: não é preenchida com accent`).not.toBe(accent);
				expect(style.width, `${what}: borda de 1px`).toBe('1px');
				expect(style.color, `${what}: borda em border-strong`).toBe(borderStrong);
			}
		});

		test('sem imagem, o placeholder fica visível sob a arte transparente e o tile não muda (SCAT-10, SCAT-11)', async ({
			page
		}) => {
			// O CDN da arte responde 403 (a pilha devolve 502); a rota fixa isso e o teste não depende dele.
			await page.route('**/card_images/**', (route) =>
				route.fulfill({ status: 502, contentType: 'text/plain', body: '' })
			);
			await openCatalog(page);

			const tile = tiles(page).first();
			const image = tile.locator('img.image');
			await expect(image).toHaveCount(1);
			await expect
				.poll(() => image.evaluate((el: HTMLImageElement) => el.complete && el.naturalWidth === 0))
				.toBe(true);

			const placeholder = tile.locator('.placeholder');
			await expect(placeholder).toBeVisible();
			await expect(placeholder).toContainText(/\S/);
			await expect(placeholder.locator('.placeholder-number')).toHaveText(/^[A-Z0-9]+-\d+/);

			expect(
				await image.evaluate((el) => getComputedStyle(el).backgroundColor),
				'a arte quebrada não cobre o placeholder'
			).toBe('rgba(0, 0, 0, 0)');

			const art = await box(tile.locator('.art'));
			const imageBox = await box(image);
			const placeholderBox = await box(placeholder);
			for (const [what, inner] of [
				['imagem', imageBox],
				['placeholder', placeholderBox]
			] as const) {
				expect(inner.width, `${what}: largura da arte`).toBeCloseTo(art.width, 0);
				expect(inner.height, `${what}: altura da arte`).toBeCloseTo(art.height, 0);
			}
			expect(art.height / art.width, 'arte em 5/7').toBeCloseTo(7 / 5, 1);

			const mono = await resolveToken(page, 'fontFamily', '--font-mono');
			expect(
				await tile.locator('.number').evaluate((el) => getComputedStyle(el).fontFamily),
				'card_number em estilo code'
			).toBe(mono);
		});

		test('linha de status ao lado do campo de busca a partir de 64rem e empilhada abaixo (SCAT-30, SCAT-32)', async ({
			page
		}) => {
			await openCatalog(page, [['colors[]', 'Red']]);
			const tolerance = (await resolveSpace(page, '--space-2')) + 1;

			const sentence = spaStatus(page);
			const status = sentence.locator('..');
			const toolbar = status.locator('..');
			const clear = status.getByRole('link', { name: 'Limpar filtros' });
			const searchForm = page.getByRole('search');
			await expect(clear).toBeVisible();

			const statusBox = await box(status);
			const sentenceBox = await box(sentence);
			const clearBox = await box(clear);
			const toolbarBox = await box(toolbar);
			const formBox = await box(searchForm);
			const fieldBox = await box(searchField(page));

			if (combo.width >= WIDE_MIN_WIDTH) {
				expect(Math.abs(statusBox.y - fieldBox.y), 'status e campo na mesma linha').toBeLessThanOrEqual(
					tolerance
				);
				const sentenceMiddle = sentenceBox.y + sentenceBox.height / 2;
				expect(sentenceMiddle, 'a frase está na faixa do campo').toBeGreaterThanOrEqual(fieldBox.y);
				expect(sentenceMiddle, 'a frase está na faixa do campo').toBeLessThanOrEqual(
					fieldBox.y + fieldBox.height
				);
				expect(statusBox.x, 'status à direita do formulário de busca').toBeGreaterThanOrEqual(
					formBox.x + formBox.width - 1
				);
				expect(
					statusBox.x + statusBox.width,
					'status encostado na borda direita da barra'
				).toBeCloseTo(toolbarBox.x + toolbarBox.width, 0);
				expect(clearBox.x, '"Limpar filtros" à direita da frase').toBeGreaterThanOrEqual(
					sentenceBox.x + sentenceBox.width
				);
				expect(Math.abs(clearBox.y + clearBox.height / 2 - (fieldBox.y + fieldBox.height / 2))).toBeLessThanOrEqual(
					tolerance
				);
			} else {
				expect(statusBox.y, 'status abaixo do formulário de busca').toBeGreaterThanOrEqual(
					formBox.y + formBox.height - 1
				);
				expect(statusBox.x, 'status alinhado à esquerda da barra').toBeCloseTo(toolbarBox.x, 0);

				// Deslogado, os dois links não cabem ao lado da frase e quebram para uma 2ª linha: o
				// bloco continua encostado na borda direita da linha de status.
				await expect(status.getByRole('link', { name: 'Entrar para registrar posse' })).toBeVisible();
				const linksBox = await box(clear.locator('..'));
				expect(linksBox.y, 'links quebraram para baixo da frase').toBeGreaterThanOrEqual(
					sentenceBox.y + sentenceBox.height - 1
				);
				expect(
					Math.abs(linksBox.x + linksBox.width - (statusBox.x + statusBox.width)),
					'links encostados na borda direita da linha de status ao quebrar'
				).toBeLessThanOrEqual(1);
			}
		});
	});
}

// A 360px os dois links (frase de entrada incluída) não cabem na linha da frase e quebram para
// baixo; a "à direita" só é medível onde frase e links dividem a linha, abaixo e junto de 64rem.
for (const width of [768, WIDE_MIN_WIDTH - 1]) {
	test.describe(`links do status a ${width}px`, () => {
		test.use({ viewport: { width, height: 800 } });

		test('encostam na borda direita da linha de status abaixo de 64rem (SCAT-30)', async ({ page }) => {
			await openCatalog(page, [['colors[]', 'Red']]);

			const sentence = spaStatus(page);
			const status = sentence.locator('..');
			const links = status.getByRole('link', { name: 'Limpar filtros' }).locator('..');
			const statusBox = await box(status);
			const sentenceBox = await box(sentence);
			const linksBox = await box(links);

			expect(linksBox.x, 'links à direita da frase, na mesma linha').toBeGreaterThanOrEqual(
				sentenceBox.x + sentenceBox.width
			);
			expect(Math.abs(linksBox.y - statusBox.y), 'links na primeira linha do status').toBeLessThanOrEqual(1);
			expect(
				Math.abs(linksBox.x + linksBox.width - (statusBox.x + statusBox.width)),
				'links encostados na borda direita da linha de status'
			).toBeLessThanOrEqual(1);
		});
	});
}

for (const viewport of VIEWPORTS) {
	test.describe(`selo de posse a ${viewport.name}`, () => {
		test.use({ viewport: { width: viewport.width, height: viewport.height } });

		test('fica no canto superior direito da arte (SCAT-13)', async ({ page }) => {
			const email = `e2e-${Date.now()}-layout-${viewport.width}@exemplo.test`;
			await page.goto('criar-conta');
			await page.getByLabel('E-mail').fill(email);
			await page.getByLabel('Senha', { exact: true }).fill(PASSWORD);
			await page.getByLabel('Confirmação da senha').fill(PASSWORD);
			await page.getByRole('button', { name: 'Criar conta' }).click();
			await expect(page).toHaveURL(/\/app\/?$/);
			await expect(mainNav(page).getByRole('button', { name: 'Sair' })).toBeVisible();

			// A SPA ainda não registra posse: usa o "+" do detalhe em HTML, na mesma sessão.
			await page.goto(`/cards/${CARD_NUMBER}`);
			await Promise.all([
				page.waitForResponse(
					(response) =>
						response.url().includes('/increment') && response.request().method() === 'POST'
				),
				page
					.getByRole('button', { name: /^Adicionar uma cópia de/ })
					.first()
					.click()
			]);

			await openCatalog(page, [['owned', 'owned']]);
			const tile = tiles(page).first();
			const badge = tile.getByRole('img', { name: /^\d+ cópias?$/ });
			await expect(badge).toBeVisible();
			const tolerance = (await resolveSpace(page, '--space-2')) + 1;

			const art = await box(tile.locator('.art'));
			const badgeBox = await box(badge);

			expect(art.x + art.width - (badgeBox.x + badgeBox.width), 'borda direita do selo').toBeGreaterThanOrEqual(-1);
			expect(art.x + art.width - (badgeBox.x + badgeBox.width), 'borda direita do selo').toBeLessThanOrEqual(
				tolerance
			);
			expect(badgeBox.y - art.y, 'topo do selo').toBeGreaterThanOrEqual(-1);
			expect(badgeBox.y - art.y, 'topo do selo').toBeLessThanOrEqual(tolerance);
		});
	});
}
