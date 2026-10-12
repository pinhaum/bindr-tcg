import { readFile } from "node:fs/promises";
import { expect, test, type BrowserContext } from "@playwright/test";

type Variant = { variant_code: string; in_source: boolean };
type Card = { card_number: string; name: string; variants: Variant[] };

const PASSWORD = "senha-correta-1";
const BASE_URL = "http://frontend:5173/";
const CONFIRM = "Confirmar e gravar na minha coleção";
const setOf = (cardNumber: string) => cardNumber.split("-")[0];

async function csrfToken(context: BrowserContext) {
  const response = await context.request.get("/api/session");
  const { data } = (await response.json()) as { data: { csrf_token: string } };
  return data.csrf_token;
}

async function fetchCards(context: BrowserContext): Promise<Card[]> {
  const cards: Card[] = [];
  for (let page = 1; ; page++) {
    const response = await context.request.get(
      `/api/catalog?per_page=100&page=${page}`,
    );
    const { data, meta } = (await response.json()) as {
      data: Card[];
      meta: { total_pages: number };
    };
    cards.push(...data);
    if (page >= meta.total_pages) return cards;
  }
}

test("baixar o CSV pelo link da pasta, enviar sem edição e confirmar deixa a coleção igual (SPOR-33, SPOR-34)", async ({
  browser,
}) => {
  test.setTimeout(120_000);
  const context = await browser.newContext({
    baseURL: BASE_URL,
    locale: "pt-BR",
    viewport: { width: 1280, height: 800 },
  });
  const page = await context.newPage();

  const cards = await fetchCards(context);
  const picks: { number: string; code: string }[] = [];
  const seenSets = new Set<string>();
  for (const card of cards) {
    const variant = card.variants.find((item) => item.in_source);
    if (!variant || seenSets.has(setOf(card.card_number))) continue;
    seenSets.add(setOf(card.card_number));
    picks.push({ number: card.card_number, code: variant.variant_code });
    if (picks.length === 4) break;
  }
  expect(picks.length, "quatro sets distintos no catálogo").toBe(4);

  await page.goto("criar-conta");
  await page
    .getByLabel("E-mail")
    .fill(`e2e-${Date.now()}-ida-e-volta@exemplo.test`);
  await page.getByLabel("Senha", { exact: true }).fill(PASSWORD);
  await page.getByLabel("Confirmação da senha").fill(PASSWORD);
  await page.getByRole("button", { name: "Criar conta" }).click();
  await expect(
    page
      .getByRole("navigation", { name: "Principal" })
      .getByRole("button", { name: "Sair" }),
  ).toBeVisible();

  const token = await csrfToken(context);
  const variantPath = (pick: (typeof picks)[number], action: string) =>
    `/api/cards/${encodeURIComponent(pick.number)}/variants/${encodeURIComponent(pick.code)}/${action}`;
  const step = async (pick: (typeof picks)[number], action: string) => {
    const result = await context.request.post(variantPath(pick, action), {
      headers: { "X-CSRF-Token": token },
    });
    expect(result.ok(), `${action} ${pick.code}`).toBe(true);
  };
  for (const [index, copies] of [2, 1, 3].entries()) {
    for (let copy = 0; copy < copies; copy++)
      await step(picks[index], "increment");
  }
  // Variante zerada: passa a ter linha de posse e volta a zero, e não entra no CSV.
  await step(picks[3], "increment");
  await step(picks[3], "decrement");

  const before = await (await context.request.get("/collection/export")).text();
  const lines = before.trim().split("\n");
  expect(lines.length - 1, "três variantes em três sets, sem a zerada").toBe(3);
  expect(before).not.toContain(picks[3].code);

  await page.goto("pasta");
  const link = page.getByRole("link", { name: "Baixar minha coleção (CSV)" });
  await expect(link).toBeVisible();
  await page.waitForLoadState("networkidle");
  const apiCalls: string[] = [];
  page.on("request", (request) => {
    if (new URL(request.url()).pathname.startsWith("/api"))
      apiCalls.push(request.url());
  });
  const downloading = page.waitForEvent("download");
  await link.click();
  const download = await downloading;
  const downloaded = await readFile((await download.path())!, "utf-8");
  expect(downloaded, "o arquivo baixado é o export").toBe(before);
  expect(apiCalls, "o download não chama /api (SPOR-33)").toEqual([]);

  await page.goto("pasta/importar");
  await page.locator('input[type="file"]').setInputFiles({
    name: "colecao.csv",
    mimeType: "text/csv",
    buffer: Buffer.from(downloaded, "utf-8"),
  });
  await page.getByRole("button", { name: "Pré-visualizar importação" }).click();
  await page.waitForURL(/\/pasta\/importar\/[^/]+$/);
  await expect(page.getByRole("button", { name: CONFIRM })).toBeVisible();
  expect(
    await page.locator("main section.group h2").allTextContents(),
    "só o grupo Já está assim, com N linhas do CSV",
  ).toEqual([`Já está assim (${lines.length - 1})`]);

  await page.getByRole("button", { name: CONFIRM }).click();
  await expect(
    page.getByRole("heading", { name: "Importação concluída", level: 1 }),
  ).toBeVisible();
  expect(
    await (await context.request.get("/collection/export")).text(),
    "export idêntico byte a byte depois de confirmar (SPOR-34)",
  ).toBe(before);

  await context.close();
});
