import { expect, test, type Locator, type Page } from '@playwright/test';
import { ownOneCopy } from './helpers/ownership';

const PASSWORD = 'senha-correta-1';
const STATUS_SENTENCE = /^\d+ cartas?( · \d+ filtros? ativos?)?$/;
const CARD_NUMBER = 'OP01-024';

const encode = (pairs: [string, string][]) => new URLSearchParams(pairs).toString();

const marker = (page: Page) =>
	page.evaluate(() => (window as unknown as { __marker?: string }).__marker);
const setMarker = (page: Page) =>
	page.evaluate(() => ((window as unknown as { __marker: string }).__marker = 'mesma-pagina'));
const expectSamePage = async (page: Page, where: string) =>
	expect(await marker(page), `a página recarregou: ${where}`).toBe('mesma-pagina');

const searchParams = (page: Page) => new URL(page.url()).searchParams;

// A frase aparece no parágrafo focável da linha de status e, de novo, no anúncio fora da vista (SCAT-44).
const spaStatus = (page: Page) =>
	page.locator('p[tabindex="-1"]').filter({ hasText: STATUS_SENTENCE });
const spaAnnouncement = (page: Page) => page.getByRole('status').filter({ hasText: STATUS_SENTENCE });
const activeFilters = (page: Page) => page.getByRole('list', { name: 'Filtros ativos' });
const mainNav = (page: Page) => page.getByRole('navigation', { name: 'Principal' });
const tiles = (page: Page) => page.locator('ul.grid li');
const badges = (page: Page) => page.locator('ul.grid li').getByRole('img', { name: /^\d+ cópias?$/ });

// Os chips da lista de filtros ativos só aparecem com a resposta da API da URL nova.
const activeChip = (page: Page, text: string) =>
	activeFilters(page).getByRole('link', { name: `Remover filtro ${text}` });

async function waitForCatalog(page: Page) {
	await expect(page.getByRole('heading', { name: 'Catálogo', level: 1 })).toBeVisible();
	await expect(spaStatus(page)).toBeVisible();
	await expect(page.locator('section[aria-busy="false"]')).toBeVisible();
}

async function openCatalog(page: Page, pairs: [string, string][] = []) {
	await page.goto(pairs.length > 0 ? `/?${encode(pairs)}` : '/');
	await waitForCatalog(page);
	await setMarker(page);
}

function trackBadResponses(page: Page) {
	const bad: string[] = [];
	page.on('response', (response) => {
		const status = response.status();
		// A arte vem de um CDN externo e responde 502 quando ele recusa (403); a SPA mostra o placeholder (SCAT-11).
		if (new URL(response.url()).pathname.startsWith('/card_images/')) return;
		if (status === 406 || status >= 500)
			bad.push(`${status} ${response.request().method()} ${response.url()}`);
	});
	return bad;
}

// Tab de verdade até o link da cor: prova que o chip está na ordem de tabulação.
async function tabTo(page: Page, linkText: string, max = 80) {
	for (let step = 0; step < max; step++) {
		await page.keyboard.press('Tab');
		const reached = await page.evaluate((expected) => {
			const el = document.activeElement;
			return el?.tagName === 'A' && el.textContent?.trim() === expected;
		}, linkText);
		if (reached) return;
	}
	throw new Error(`Tab não alcançou "${linkText}" em ${max} passos`);
}

const inPanel = (focused: Locator) => focused.evaluate((el) => el.closest('.panel') !== null);

async function activate(control: Locator) {
	await control.focus();
	await control.page().keyboard.press('Enter');
}

async function signUp(page: Page, email: string) {
	await page.goto('criar-conta');
	await page.getByLabel('E-mail').fill(email);
	await page.getByLabel('Senha', { exact: true }).fill(PASSWORD);
	await page.getByLabel('Confirmação da senha').fill(PASSWORD);
	await page.getByRole('button', { name: 'Criar conta' }).click();
	await expect(page).toHaveURL(/^https?:\/\/[^/]+\/$/);
	await expect(mainNav(page).getByRole('button', { name: 'Sair' })).toBeVisible();
}

async function signIn(page: Page, email: string) {
	await page.getByLabel('E-mail').fill(email);
	await page.getByLabel('Senha', { exact: true }).fill(PASSWORD);
	await page.getByRole('button', { name: 'Entrar' }).click();
}

test.describe('teclado e foco a 1280px (SCAT-41, SCAT-42, SCAT-43, SCAT-44)', () => {
	test.use({ viewport: { width: 1280, height: 800 } });

	test('Tab até "Red" e Enter: a URL muda, o foco segue no chip e a página não recarrega', async ({
		page
	}) => {
		const bad = trackBadResponses(page);
		await page.goto('/');
		await waitForCatalog(page);
		await expect(page.getByRole('link', { name: 'Red', exact: true })).toBeVisible();
		await setMarker(page);

		await tabTo(page, 'Red');
		await page.keyboard.press('Enter');

		await expect.poll(() => searchParams(page).getAll('colors[]')).toEqual(['Red']);
		await expect(spaStatus(page)).toHaveText(/ · 1 filtro ativo$/);
		await expect(activeChip(page, 'Cor: Red')).toBeVisible();

		const focused = page.locator(':focus');
		await expect(focused).toHaveAttribute('aria-label', 'Remover filtro Cor: Red');
		expect(await inPanel(focused), 'o foco continua no chip do painel').toBe(true);
		await expect(page.locator('main#conteudo')).not.toBeFocused();
		await expectSamePage(page, 'chip "Red"');

		await expect(spaAnnouncement(page)).toHaveText((await spaStatus(page).textContent())!);
		expect(bad, 'nenhuma resposta 406 nem 5xx').toEqual([]);
	});

	test('três chips de cor seguidos pelo teclado: foco no painel e um anúncio a cada resposta', async ({
		page
	}) => {
		const bad = trackBadResponses(page);
		await openCatalog(page);
		await expect(page.getByRole('link', { name: 'Red', exact: true })).toBeVisible();

		const steps: { color: string; sentence: RegExp }[] = [
			{ color: 'Red', sentence: /^\d+ cartas? · 1 filtro ativo$/ },
			{ color: 'Green', sentence: /^\d+ cartas? · 2 filtros ativos$/ },
			{ color: 'Blue', sentence: /^\d+ cartas? · 3 filtros ativos$/ }
		];
		const applied: string[] = [];

		for (const { color, sentence } of steps) {
			await tabTo(page, color);
			await page.keyboard.press('Enter');
			applied.push(color);

			await expect.poll(() => searchParams(page).getAll('colors[]')).toEqual(applied);
			// Os hrefs dos chips nascem da última resposta: o próximo Tab só vale depois dela.
			await expect(activeChip(page, `Cor: ${color}`)).toBeVisible();
			await expect(spaStatus(page)).toHaveText(sentence);
			await expect(spaAnnouncement(page)).toHaveText(sentence);

			const focused = page.locator(':focus');
			await expect(focused).toHaveAttribute('aria-label', `Remover filtro Cor: ${color}`);
			expect(await inPanel(focused), `o foco continua no chip "${color}" do painel`).toBe(true);
			await expect(page.locator('main#conteudo')).not.toBeFocused();
		}

		expect(searchParams(page).getAll('colors[]')).toEqual(['Red', 'Green', 'Blue']);
		await expectSamePage(page, 'três chips seguidos');
		expect(bad, 'nenhuma resposta 406 nem 5xx').toEqual([]);
	});

	test('"Aplicar" e "Buscar" acionados pelo teclado mantêm o foco', async ({ page }) => {
		await openCatalog(page);

		const select = page.getByLabel('Set', { exact: true });
		await expect(select.locator('option[value="OP01"]')).toBeAttached();
		await select.selectOption('OP01');
		const apply = page.getByRole('button', { name: 'Aplicar' });
		await activate(apply);

		await expect.poll(() => searchParams(page).getAll('sets[]')).toEqual(['OP01']);
		await expect(activeChip(page, 'Set: OP01')).toBeVisible();
		await expect(apply).toBeFocused();

		await page.getByLabel('Buscar por nome ou card_number').fill(CARD_NUMBER);
		const search = page.getByRole('button', { name: 'Buscar' });
		await activate(search);

		await expect.poll(() => searchParams(page).get('q')).toBe(CARD_NUMBER);
		await expect(activeChip(page, `Busca: ${CARD_NUMBER}`)).toBeVisible();
		await expect(search).toBeFocused();
		await expect(page.locator('main#conteudo')).not.toBeFocused();
		await expectSamePage(page, '"Aplicar" e "Buscar"');
	});

	test('remover o único chip ativo leva o foco à linha de status', async ({ page }) => {
		await openCatalog(page, [['colors[]', 'Red']]);
		await expect(activeChip(page, 'Cor: Red')).toBeVisible();

		await activate(activeChip(page, 'Cor: Red'));

		await expect.poll(() => searchParams(page).has('colors[]')).toBe(false);
		await expect(activeFilters(page)).toHaveCount(0);
		await expect(spaStatus(page)).toHaveText(/^\d+ cartas?$/);
		await expect(spaStatus(page)).toBeFocused();
		await expect(page.locator('main#conteudo')).not.toBeFocused();
		await expectSamePage(page, 'remover o único chip');
	});

	test('remover um chip leva o foco ao seguinte, ou ao anterior se era o último', async ({
		page
	}) => {
		const colors: [string, string][] = [
			['colors[]', 'Red'],
			['colors[]', 'Green']
		];

		await openCatalog(page, colors);
		await expect(activeChip(page, 'Cor: Green')).toBeVisible();
		await activate(activeChip(page, 'Cor: Red'));
		await expect.poll(() => searchParams(page).getAll('colors[]')).toEqual(['Green']);
		await expect(activeChip(page, 'Cor: Red')).toHaveCount(0);
		await expect(activeChip(page, 'Cor: Green')).toBeFocused();
		await expectSamePage(page, 'remover o primeiro de dois chips');

		await openCatalog(page, colors);
		await expect(activeChip(page, 'Cor: Red')).toBeVisible();
		await activate(activeChip(page, 'Cor: Green'));
		await expect.poll(() => searchParams(page).getAll('colors[]')).toEqual(['Red']);
		await expect(activeChip(page, 'Cor: Green')).toHaveCount(0);
		await expect(activeChip(page, 'Cor: Red')).toBeFocused();
		await expectSamePage(page, 'remover o último de dois chips');
	});

	test('"Próxima" e "Anterior" levam o foco à linha de status', async ({ page }) => {
		await openCatalog(page);
		const pagination = page.getByRole('navigation', { name: 'Paginação do catálogo' });

		await activate(pagination.getByRole('link', { name: 'Próxima' }));
		await expect.poll(() => searchParams(page).get('page')).toBe('2');
		await expect(pagination.getByText(/^Página 2 de \d+$/)).toBeVisible();
		await expect(spaStatus(page)).toBeFocused();
		await expect(page.locator('main#conteudo')).not.toBeFocused();
		await expect(spaAnnouncement(page)).toHaveText((await spaStatus(page).textContent())!);
		await expectSamePage(page, '"Próxima"');

		await activate(pagination.getByRole('link', { name: 'Anterior' }));
		await expect(pagination.getByText(/^Página 1 de \d+$/)).toBeVisible();
		expect(['1', null]).toContain(searchParams(page).get('page'));
		await expect(spaStatus(page)).toBeFocused();
		await expectSamePage(page, '"Anterior"');
	});
});

test.describe('painel de filtros a 360px (SCAT-34, SCAT-35)', () => {
	test.use({ viewport: { width: 360, height: 740 } });

	test('o painel nasce fechado, o chip ativo fica à vista e o painel aberto segue aberto', async ({
		page
	}) => {
		const bad = trackBadResponses(page);
		await openCatalog(page, [['colors[]', 'Red']]);

		const details = page.locator('details');
		const summary = details.locator('summary');
		const isOpen = () => details.evaluate((el: HTMLDetailsElement) => el.open);

		await expect(summary).toHaveText('Filtros · 1 filtro ativo');
		expect(await isOpen(), 'painel fechado na carga').toBe(false);
		await expect(activeChip(page, 'Cor: Red')).toBeVisible();
		await expect(page.locator('.panel')).toBeHidden();

		await summary.click();
		expect(await isOpen()).toBe(true);
		await details.getByRole('link', { name: 'Green', exact: true }).click();
		await expect.poll(() => searchParams(page).getAll('colors[]')).toEqual(['Red', 'Green']);
		await expect(summary).toHaveText('Filtros · 2 filtros ativos');
		expect(await isOpen(), 'aberto depois de um chip do painel').toBe(true);

		await activeChip(page, 'Cor: Red').click();
		await expect.poll(() => searchParams(page).getAll('colors[]')).toEqual(['Green']);
		// Os chips vêm da resposta da API: só depois dela o chip "Green" remove só o "Green".
		await expect(summary).toHaveText('Filtros · 1 filtro ativo');
		await expect(activeChip(page, 'Cor: Red')).toHaveCount(0);
		expect(await isOpen(), 'aberto depois de remover um chip da lista').toBe(true);

		await summary.click();
		expect(await isOpen()).toBe(false);
		await activeChip(page, 'Cor: Green').click();
		await expect.poll(() => searchParams(page).has('colors[]')).toBe(false);
		await expect(summary).toHaveText('Filtros');
		expect(await isOpen(), 'fechado segue fechado').toBe(false);

		await expectSamePage(page, 'painel a 360px');
		expect(bad, 'nenhuma resposta 406 nem 5xx').toEqual([]);
	});
});

test.describe('painel de filtros a 360px pelo teclado (SCAT-35, SCAT-41)', () => {
	test.use({ viewport: { width: 360, height: 740 } });

	test('Tab até um chip do painel aberto e Enter: o foco segue no chip e o painel segue aberto', async ({
		page
	}) => {
		const bad = trackBadResponses(page);
		await openCatalog(page);

		const details = page.locator('details');
		const summary = details.locator('summary');
		const isOpen = () => details.evaluate((el: HTMLDetailsElement) => el.open);

		expect(await isOpen(), 'painel fechado na carga').toBe(false);
		await activate(summary);
		expect(await isOpen(), 'painel aberto pelo teclado').toBe(true);

		await tabTo(page, 'Red');
		await expect(page.locator(':focus')).toHaveText('Red');
		expect(await inPanel(page.locator(':focus')), 'o foco está num chip do painel').toBe(true);
		await page.keyboard.press('Enter');

		await expect.poll(() => searchParams(page).getAll('colors[]')).toEqual(['Red']);
		await expect(summary).toHaveText('Filtros · 1 filtro ativo');
		const focused = page.locator(':focus');
		await expect(focused).toHaveAttribute('aria-label', 'Remover filtro Cor: Red');
		expect(await inPanel(focused), 'o foco continua no chip do painel').toBe(true);
		expect(await isOpen(), 'o painel continua aberto').toBe(true);
		await expect(page.locator('main#conteudo')).not.toBeFocused();
		await expectSamePage(page, 'chip do painel por teclado');
		expect(bad, 'nenhuma resposta 406 nem 5xx').toEqual([]);
	});
});

test.describe('coluna lateral a 1280px (SCAT-33)', () => {
	test.use({ viewport: { width: 1280, height: 800 } });

	test('os filtros ficam na coluna lateral, abaixo da navegação, sempre visíveis e com espaçamento fixo', async ({
		page
	}) => {
		await openCatalog(page);
		const panel = page.locator('.aside .panel');
		await expect(panel).toBeVisible();
		await expect(page.getByRole('group', { name: 'Cor' })).toBeVisible();

		await expect(page.locator('details')).toHaveCount(0);
		await expect(page.locator('main#conteudo .panel')).toHaveCount(0);

		const nav = (await mainNav(page).boundingBox())!;
		const box = (await panel.boundingBox())!;
		expect(box.y, 'o painel começa abaixo da navegação').toBeGreaterThanOrEqual(nav.y + nav.height - 1);
		const main = (await page.locator('main#conteudo').boundingBox())!;
		expect(box.x + box.width, 'o painel fica à esquerda do conteúdo').toBeLessThanOrEqual(main.x);

		const gaps = await panel.evaluate((el) => {
			const rects = [...el.children].map((child) => child.getBoundingClientRect());
			return rects.slice(1).map((rect, index) => rect.top - rects[index].bottom);
		});
		expect(gaps.length, 'grupos do painel anônimo').toBe(3);
		for (const gap of gaps) expect(gap).toBeCloseTo(gaps[0], 0);
		expect(gaps[0]).toBeGreaterThan(0);
	});
});

test.describe('voltar e avançar (SCAT-07)', () => {
	test.use({ viewport: { width: 1280, height: 800 } });

	test('restauram a lista, o termo e os chips de cada URL sem recarregar', async ({ page }) => {
		await openCatalog(page);
		const searchBox = page.getByLabel('Buscar por nome ou card_number');
		const firstNumber = () => tiles(page).first().locator('.number');

		// O resultado de cada estado: a frase de status (total e filtros) e a primeira carta da grade.
		const result = async () => ({
			status: await spaStatus(page).textContent(),
			first: (await tiles(page).count()) > 0 ? await firstNumber().textContent() : null
		});
		const expectResult = (expected: Awaited<ReturnType<typeof result>>) =>
			expect.poll(result).toEqual(expected);

		const all = await result();
		expect(all.status).toMatch(/^\d+ cartas$/);

		await searchBox.fill(CARD_NUMBER);
		await page.getByRole('button', { name: 'Buscar' }).click();
		await expect(activeChip(page, `Busca: ${CARD_NUMBER}`)).toBeVisible();
		await expect(firstNumber()).toHaveText(CARD_NUMBER);
		const searched = await result();
		expect(searched.status).toMatch(/ · 1 filtro ativo$/);
		expect(searched.first).toBe(CARD_NUMBER);

		await page.getByRole('link', { name: 'Red', exact: true }).click();
		await expect(activeChip(page, 'Cor: Red')).toBeVisible();
		await expect(searchBox).toHaveValue(CARD_NUMBER);
		await expect(spaStatus(page)).toHaveText(/ · 2 filtros ativos$/);
		const colored = await result();

		await page.goBack();
		await expect.poll(() => searchParams(page).has('colors[]')).toBe(false);
		await expect(activeChip(page, 'Cor: Red')).toHaveCount(0);
		await expect(activeChip(page, `Busca: ${CARD_NUMBER}`)).toBeVisible();
		await expect(searchBox).toHaveValue(CARD_NUMBER);
		await expectResult(searched);
		await expect(page.getByRole('link', { name: 'Red', exact: true })).toBeVisible();

		await page.goBack();
		await expect.poll(() => searchParams(page).has('q')).toBe(false);
		await expect(activeFilters(page)).toHaveCount(0);
		await expect(searchBox).toHaveValue('');
		await expectResult(all);

		await page.goForward();
		await expect(activeChip(page, `Busca: ${CARD_NUMBER}`)).toBeVisible();
		await expect(searchBox).toHaveValue(CARD_NUMBER);
		await expectResult(searched);

		await page.goForward();
		await expect(activeChip(page, 'Cor: Red')).toBeVisible();
		await expect(searchBox).toHaveValue(CARD_NUMBER);
		await expectResult(colored);
		await expectSamePage(page, 'voltar e avançar');
	});
});

test.describe('sem sessão (SCAT-26, SCAT-31)', () => {
	test('sem controles de posse, com "owned" ignorado e o convite único para entrar', async ({
		page
	}) => {
		const bad = trackBadResponses(page);
		await openCatalog(page, [
			['colors[]', 'Red'],
			['owned', 'owned']
		]);

		await expect(activeChip(page, 'Cor: Red')).toBeVisible();
		await expect(activeFilters(page).getByRole('listitem')).toHaveCount(1);
		await expect(activeChip(page, 'Posse: Tenho')).toHaveCount(0);
		await expect(page.getByRole('group', { name: 'Posse' })).toHaveCount(0);
		await expect(page.getByRole('link', { name: 'Tenho', exact: true })).toHaveCount(0);
		await expect(badges(page)).toHaveCount(0);

		const invite = page.getByRole('link', { name: 'Entrar para registrar posse' });
		await expect(invite).toHaveCount(1);
		// O convite vive ao lado da frase de status, dentro do mesmo bloco.
		await expect(
			spaStatus(page).locator('..').getByRole('link', { name: 'Entrar para registrar posse' })
		).toHaveCount(1);

		const href = new URL((await invite.getAttribute('href'))!, page.url());
		expect(href.pathname).toBe('/entrar');
		const returnTo = new URL(href.searchParams.get('return_to')!, page.url());
		expect(returnTo.pathname).toBe('/');
		expect(returnTo.searchParams.getAll('colors[]')).toEqual(['Red']);

		await invite.click();
		await expect(page).toHaveURL(/\/entrar\?return_to=/);
		await expect(page.getByRole('button', { name: 'Entrar' })).toBeVisible();
		await expectSamePage(page, 'convite para entrar');
		expect(bad, 'nenhuma resposta 406 nem 5xx').toEqual([]);
	});
});

test.describe('com sessão a 1280px (SCAT-9, SCAT-13, SCAT-25, SCAT-31)', () => {
	test.use({ viewport: { width: 1280, height: 800 } });

	test('posse: selo e filtros "Tenho"/"Não tenho"; sair os remove e o convite volta à mesma query', async ({
		page
	}) => {
		const email = `e2e-${Date.now()}-catalogo@exemplo.test`;
		const bad = trackBadResponses(page);
		await signUp(page, email);
		await ownOneCopy(page, CARD_NUMBER);

		await test.step('"Todas" é a posição atual e nenhum chip de posse tem sinal de remoção (SCAT-25)', async () => {
			await openCatalog(page);
			const owned = page.getByRole('group', { name: 'Posse' });
			await expect(owned).toBeVisible();
			await expect(owned.getByRole('link', { name: 'Todas' })).toHaveAttribute('aria-current', 'true');
			await expect(owned.getByRole('link', { name: /^Remover/ })).toHaveCount(0);
			await expect(page.getByRole('link', { name: 'Entrar para registrar posse' })).toHaveCount(0);
		});

		await test.step('"Tenho" mostra só cartas com selo (SCAT-13, SCAT-25)', async () => {
			const owned = page.getByRole('group', { name: 'Posse' });
			await owned.getByRole('link', { name: 'Tenho', exact: true }).click();
			await expect.poll(() => searchParams(page).get('owned')).toBe('owned');
			await expect(activeChip(page, 'Posse: Tenho')).toBeVisible();

			const total = await tiles(page).count();
			expect(total, 'cartas que tenho').toBeGreaterThan(0);
			await expect(badges(page)).toHaveCount(total);
			await expect(
				tiles(page).filter({ hasText: CARD_NUMBER }).getByRole('img', { name: '1 cópia' })
			).toBeVisible();
			await expect(owned.getByRole('link', { name: 'Todas' })).not.toHaveAttribute('aria-current');
			await expect(owned.getByRole('link', { name: 'Remover filtro Posse: Tenho' })).toBeVisible();
			await expectSamePage(page, '"Tenho"');
		});

		await test.step('"Não tenho" troca o valor e some com todos os selos (SCAT-25)', async () => {
			await page
				.getByRole('group', { name: 'Posse' })
				.getByRole('link', { name: 'Não tenho', exact: true })
				.click();
			await expect.poll(() => searchParams(page).get('owned')).toBe('missing');
			await expect(activeChip(page, 'Posse: Não tenho')).toBeVisible();
			expect(await tiles(page).count(), 'cartas que não tenho').toBeGreaterThan(0);
			await expect(badges(page)).toHaveCount(0);
			await expectSamePage(page, '"Não tenho"');
		});

		await test.step('"Todas" remove o filtro de posse (SCAT-25)', async () => {
			await page
				.getByRole('group', { name: 'Posse' })
				.getByRole('link', { name: 'Todas' })
				.click();
			await expect.poll(() => searchParams(page).has('owned')).toBe(false);
			await expect(activeFilters(page)).toHaveCount(0);
			await expect(
				page.getByRole('group', { name: 'Posse' }).getByRole('link', { name: 'Todas' })
			).toHaveAttribute('aria-current', 'true');
			await expectSamePage(page, '"Todas"');
		});

		await test.step('a mesma busca por card_number separa quem tenho de quem não tenho (SCAT-13, SCAT-25)', async () => {
			const oneCard = /^1 carta( · \d+ filtros? ativos?)?$/;

			await openCatalog(page, [
				['q', CARD_NUMBER],
				['owned', 'owned']
			]);
			await expect(spaStatus(page)).toHaveText(oneCard);
			await expect(tiles(page)).toHaveCount(1);
			await expect(tiles(page).first().locator('.number')).toHaveText(CARD_NUMBER);
			await expect(badges(page)).toHaveCount(1);

			await openCatalog(page, [
				['q', CARD_NUMBER],
				['owned', 'missing']
			]);
			await expect(spaStatus(page)).toHaveText(/^0 cartas( · \d+ filtros? ativos?)?$/);
			await expect(tiles(page)).toHaveCount(0);
			await expect(badges(page)).toHaveCount(0);
		});

		await test.step('sair em ?owned=owned refaz a consulta e remove chip, selo e controles sem recarregar (SCAT-9, SCAT-13)', async () => {
			await openCatalog(page, [['owned', 'owned']]);
			await expect(activeChip(page, 'Posse: Tenho')).toBeVisible();
			await expect(badges(page).first()).toBeVisible();
			await expect(page.getByRole('group', { name: 'Posse' })).toBeVisible();

			// Ao limpar a sessão a página refaz a consulta da URL ainda com "owned" (a API o ignora sem sessão).
			const refetch = page.waitForRequest((request) => {
				const url = new URL(request.url());
				return url.pathname === '/api/catalog' && url.searchParams.get('owned') === 'owned';
			});
			await mainNav(page).getByRole('button', { name: 'Sair' }).click();
			await refetch;

			await expect(mainNav(page).getByRole('link', { name: 'Entrar', exact: true })).toBeVisible();
			await expect(activeChip(page, 'Posse: Tenho')).toHaveCount(0);
			await expect(badges(page)).toHaveCount(0);
			await expect(page.getByRole('group', { name: 'Posse' })).toHaveCount(0);
			await expect(page.getByRole('link', { name: 'Entrar para registrar posse' })).toHaveCount(1);
			await expectSamePage(page, 'sair');
		});

		await test.step('o convite leva a /entrar com a query e o login volta a ela (SCAT-31)', async () => {
			// Sair volta o catálogo a / (SPA-22): a busca é refeita para o convite carregar a query.
			await page.getByLabel('Buscar por nome ou card_number').fill(CARD_NUMBER);
			await page.getByRole('button', { name: 'Buscar' }).click();
			await expect(activeChip(page, `Busca: ${CARD_NUMBER}`)).toBeVisible();
			await page.getByRole('link', { name: 'Entrar para registrar posse' }).click();
			await expect(page).toHaveURL(/\/entrar\?return_to=/);
			const returnTo = new URL(searchParams(page).get('return_to')!, page.url());
			expect(returnTo.pathname).toBe('/');
			expect(returnTo.searchParams.get('q')).toBe(CARD_NUMBER);

			await signIn(page, email);
			await expect(page).toHaveURL(/\/\?q=OP01-024$/);
			await expect(
				tiles(page).filter({ hasText: CARD_NUMBER }).getByRole('img', { name: '1 cópia' })
			).toBeVisible();
			await expect(page.getByRole('group', { name: 'Posse' })).toBeVisible();
			await expect(page.getByRole('link', { name: 'Entrar para registrar posse' })).toHaveCount(0);
			await expectSamePage(page, 'convite e login');
		});

		expect(bad, 'nenhuma resposta 406 nem 5xx').toEqual([]);
	});
});
