import { expect, test, type Page } from '@playwright/test';

type Recorded = { groups: string[]; skipped: boolean; finished: boolean };
type ProbeWindow = { __transitions: Recorded[] };

const PIXEL_PNG = Buffer.from(
	'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
	'base64'
);

const VIEWPORTS = [
	{ name: '360px', width: 360, height: 740 },
	{ name: '1280px', width: 1280, height: 800 }
];

// Mesma regra de `morphName` em src/lib/cards/morph.svelte.ts (o módulo usa runes e não roda
// fora do compilador do Svelte).
const morphName = (cardNumber: string) =>
	`carta-${cardNumber.replace(/[^A-Za-z0-9-]/gu, (char) => `_${char.codePointAt(0)!.toString(16)}_`)}`;

// O CDN da arte responde 403 (a pilha devolve 502): a rota devolve uma imagem mínima.
const stubImages = (page: Page) =>
	page.route('**/card_images/**', (route) =>
		route.fulfill({ status: 200, contentType: 'image/png', body: PIXEL_PNG })
	);

function trackConsoleErrors(page: Page) {
	const errors: string[] = [];
	page.on('console', (message) => {
		if (message.type() === 'error') errors.push(`console: ${message.text()}`);
	});
	page.on('pageerror', (error) => errors.push(`pageerror: ${error.message}`));
	return errors;
}

// Embrulha document.startViewTransition: quando a transição fica pronta, registra os nomes dos
// ::view-transition-group(...) que a página tem animando (a prova de que a arte virou um grupo).
async function trackTransitions(page: Page) {
	await page.addInitScript(() => {
		const w = window as unknown as ProbeWindow;
		w.__transitions = [];
		const original = document.startViewTransition?.bind(document);
		if (!original) return;
		document.startViewTransition = ((callback) => {
			const entry: Recorded = { groups: [], skipped: false, finished: false };
			w.__transitions.push(entry);
			const transition = original(callback);
			transition.ready.then(
				() => {
					const prefix = '::view-transition-group(';
					entry.groups = document
						.getAnimations()
						.map((animation) => (animation.effect as KeyframeEffect | null)?.pseudoElement)
						.filter((pseudo): pseudo is string => !!pseudo?.startsWith(prefix))
						.map((pseudo) => pseudo.slice(prefix.length, -1));
				},
				() => {
					entry.skipped = true;
				}
			);
			transition.finished.then(
				() => {
					entry.finished = true;
				},
				() => {
					entry.skipped = true;
				}
			);
			return transition;
		}) as typeof document.startViewTransition;
	});
}

const transitions = (page: Page) =>
	page.evaluate(() => (window as unknown as ProbeWindow).__transitions);
const resetTransitions = (page: Page) =>
	page.evaluate(() => {
		(window as unknown as ProbeWindow).__transitions.length = 0;
	});
const groupNames = async (page: Page) => (await transitions(page)).flatMap((item) => item.groups);
const allFinished = async (page: Page) => (await transitions(page)).every((item) => item.finished);

const firstTile = (page: Page) => page.locator('li.tile').first();
const backLink = (page: Page) => page.getByRole('link', { name: 'Voltar ao catálogo', exact: true });

async function openCatalog(page: Page) {
	await page.goto('');
	await expect(firstTile(page)).toBeVisible();
	const number = (await firstTile(page).locator('.number').textContent())?.trim();
	if (!number) throw new Error('o primeiro tile do catálogo não traz o número da carta');
	return number;
}

async function waitForDetail(page: Page, number: string) {
	await expect(page).toHaveURL(new RegExp(`/app/cartas/${encodeURIComponent(number)}`));
	await expect(page.locator('section.detail[aria-busy="false"]')).toBeVisible();
	await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
}

async function waitForCatalog(page: Page, number: string) {
	await expect(page).toHaveURL(/\/app\/?(\?.*)?$/);
	await expect(page.locator('li.tile', { hasText: number }).first()).toBeVisible();
}

async function expectMorph(page: Page, number: string, where: string) {
	await expect
		.poll(() => groupNames(page), { message: `::view-transition-group da carta ${where}` })
		.toContain(morphName(number));
	const recorded = await transitions(page);
	expect(
		recorded.filter((item) => item.skipped),
		`transição ${where} não pode ser descartada`
	).toEqual([]);
	await expect.poll(() => allFinished(page)).toBe(true);
}

async function openDetailFromTile(page: Page, number: string) {
	await firstTile(page).getByRole('link').click();
	await waitForDetail(page, number);
	await expect.poll(() => allFinished(page)).toBe(true);
}

for (const viewport of VIEWPORTS) {
	test.describe(`morph da carta a ${viewport.name}`, () => {
		test.use({ viewport: { width: viewport.width, height: viewport.height } });

		test.beforeEach(async ({ page }) => {
			await page.emulateMedia({ reducedMotion: 'no-preference' });
			await stubImages(page);
			await trackTransitions(page);
		});

		test('tile → detalhe cria o grupo da carta (SCAR-39)', async ({ page }) => {
			const errors = trackConsoleErrors(page);
			const number = await openCatalog(page);
			expect(await page.evaluate(() => typeof document.startViewTransition)).toBe('function');
			await resetTransitions(page);

			await firstTile(page).getByRole('link').click();
			await waitForDetail(page, number);

			await expectMorph(page, number, 'na ida');
			expect(errors, 'nenhum erro no console').toEqual([]);
		});

		test('detalhe → catálogo pelo botão cria o grupo da carta (SCAR-40)', async ({ page }) => {
			const errors = trackConsoleErrors(page);
			const number = await openCatalog(page);
			await openDetailFromTile(page, number);
			await resetTransitions(page);

			await backLink(page).click();
			await waitForCatalog(page, number);

			await expectMorph(page, number, 'na volta pelo botão');
			expect(errors, 'nenhum erro no console').toEqual([]);
		});

		test('detalhe → catálogo pelo voltar do navegador cria o grupo da carta (SCAR-40)', async ({
			page
		}) => {
			const errors = trackConsoleErrors(page);
			const number = await openCatalog(page);
			await openDetailFromTile(page, number);
			await resetTransitions(page);

			await page.goBack();
			await waitForCatalog(page, number);

			await expectMorph(page, number, 'na volta pelo navegador');
			expect(errors, 'nenhum erro no console').toEqual([]);
		});

		test('detalhe aberto por link direto também morfa na volta ao catálogo (SCAR-40)', async ({
			page
		}) => {
			const errors = trackConsoleErrors(page);
			const number = await openCatalog(page);
			await page.goto(`cartas/${encodeURIComponent(number)}`);
			await waitForDetail(page, number);
			await resetTransitions(page);

			await backLink(page).click();
			await waitForCatalog(page, number);

			await expectMorph(page, number, 'na volta após link direto');
			expect(errors, 'nenhum erro no console').toEqual([]);
		});
	});

	test.describe(`morph da carta com reduced motion a ${viewport.name}`, () => {
		test.use({
			viewport: { width: viewport.width, height: viewport.height },
			reducedMotion: 'reduce'
		});

		test.beforeEach(async ({ page }) => {
			await stubImages(page);
			await trackTransitions(page);
		});

		test('ida e volta trocam de tela sem grupo da carta e sem erro (SCAR-41)', async ({ page }) => {
			const errors = trackConsoleErrors(page);
			const number = await openCatalog(page);

			await firstTile(page).getByRole('link').click();
			await waitForDetail(page, number);
			await backLink(page).click();
			await waitForCatalog(page, number);

			await firstTile(page).getByRole('link').click();
			await waitForDetail(page, number);
			await page.goBack();
			await waitForCatalog(page, number);

			expect(await groupNames(page)).toEqual([]);
			expect(await transitions(page), 'nenhuma View Transition com movimento reduzido').toEqual([]);
			expect(errors, 'nenhum erro no console').toEqual([]);
		});
	});
}
