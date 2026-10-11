import {
  expect,
  test,
  type Browser,
  type BrowserContext,
  type Page,
} from "@playwright/test";

type Variant = { variant_code: string; in_source: boolean };
type Card = { card_number: string; name: string; variants: Variant[] };
type Pick = { number: string; code: string; name: string };
type Owner = {
  email: string;
  state: Awaited<ReturnType<BrowserContext["storageState"]>>;
};
type Row = {
  label: string;
  number: string;
  variant: string;
  name: string;
  line: string;
  numbers: string[];
  reason: string | null;
};
type Group = { title: string; support: string; rows: Row[] };
type Preview = { file: string; warning: string | null; groups: Group[] };

const PASSWORD = "senha-correta-1";
const BASE_URL = "http://frontend:5173/app/";
const CONFIRM = "Confirmar e gravar na minha coleção";
const SUBMIT = "Pré-visualizar importação";
const LONG_NAME = "Nome".padEnd(120, "x");
const LONG_CODE = "tcgplayer:1234567890";
const MAX_ROWS = 10_000;
const PREVIEW_BUDGET_MS = 5000;
const PIXEL_PNG = Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==",
  "base64",
);

const VIEWPORTS = [
  { name: "360px", width: 360, height: 740 },
  { name: "1280px", width: 1280, height: 800 },
];
const SCHEMES = ["light", "dark"] as const;

const squash = (text: string | null | undefined) =>
  (text ?? "").replace(/\s+/g, " ").trim();
const csvFile = (content: string, name = "colecao.csv") => ({
  name,
  mimeType: "text/csv",
  buffer: Buffer.from(content, "utf-8"),
});
const csv = (rows: [string, string, string, number][]) =>
  ["card_number,variant_code,card_name,quantity"]
    .concat(
      rows.map(
        ([number, code, name, quantity]) =>
          `${number},${code},"${name.replaceAll('"', '""')}",${quantity}`,
      ),
    )
    .join("\n") + "\n";

const confirmButton = (page: Page) =>
  page.getByRole("button", { name: CONFIRM });
const alertBlock = (page: Page) => page.locator('main [role="alert"]');
const doneHeading = (page: Page) =>
  page.getByRole("heading", { name: "Importação concluída", level: 1 });

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

const variantsOf = (cards: Card[]): Pick[] =>
  cards.flatMap((card) =>
    card.variants
      .filter((variant) => variant.in_source)
      .map((variant) => ({
        number: card.card_number,
        code: variant.variant_code,
        name: card.name,
      })),
  );

let accountSeq = 0;
async function createOwner(
  browser: Browser,
  label: string,
  seed: { pick: Pick; copies: number }[],
): Promise<Owner> {
  const context = await browser.newContext({
    baseURL: BASE_URL,
    locale: "pt-BR",
  });
  const page = await context.newPage();
  const email = `e2e-${Date.now()}-importar-${label}-${accountSeq++}@exemplo.test`;
  await page.goto("criar-conta");
  await page.getByLabel("E-mail").fill(email);
  await page.getByLabel("Senha", { exact: true }).fill(PASSWORD);
  await page.getByLabel("Confirmação da senha").fill(PASSWORD);
  await page.getByRole("button", { name: "Criar conta" }).click();
  await expect(
    page
      .getByRole("navigation", { name: "Principal" })
      .getByRole("button", { name: "Sair" }),
  ).toBeVisible();

  const token = await csrfToken(context);
  for (const { pick, copies } of seed) {
    for (let copy = 0; copy < copies; copy++) {
      const result = await context.request.post(
        `/api/cards/${encodeURIComponent(pick.number)}/variants/${encodeURIComponent(pick.code)}/increment`,
        { headers: { "X-CSRF-Token": token } },
      );
      expect(result.ok(), `increment ${pick.code}`).toBe(true);
    }
  }
  const state = await context.storageState();
  await context.close();
  return { email, state };
}

async function openAs(
  browser: Browser,
  owner: Owner,
  options: Parameters<Browser["newContext"]>[0] = {},
) {
  const context = await browser.newContext({
    baseURL: BASE_URL,
    locale: "pt-BR",
    storageState: owner.state,
    viewport: { width: 1280, height: 800 },
    ...options,
  });
  await context.route("**/card_images/**", (route) =>
    route.fulfill({ status: 200, contentType: "image/png", body: PIXEL_PNG }),
  );
  return { context, page: await context.newPage() };
}

// O CSV da coleção é o retrato exato de `collection_items` (POR-11).
async function exportCsv(context: BrowserContext) {
  const response = await context.request.get("/collection/export");
  expect(response.ok(), "GET /collection/export").toBe(true);
  return response.text();
}

async function uploadHtml(page: Page, content: string) {
  await page.goto("/collection/import");
  await page.locator('input[name="arquivo"]').setInputFiles(csvFile(content));
  await page.getByRole("button", { name: SUBMIT }).click();
  await page.waitForURL(/\/collection\/import\/[^/]+$/);
}

async function uploadSpa(page: Page, content: string) {
  await page.goto("pasta/importar");
  await expect(
    page.getByRole("heading", { name: "Importar coleção", level: 1 }),
  ).toBeVisible();
  await page.locator('input[type="file"]').setInputFiles(csvFile(content));
  await page.getByRole("button", { name: SUBMIT }).click();
  await page.waitForURL(/\/app\/pasta\/importar\/[^/]+$/);
}

// Mesma forma para as duas telas; só os seletores mudam.
function htmlPreview(page: Page): Promise<Preview> {
  return page.evaluate(() => {
    const squash = (text: string | null | undefined) =>
      (text ?? "").replace(/\s+/g, " ").trim();
    const text = (root: Element, selector: string) =>
      squash(root.querySelector(selector)?.textContent);
    const groups = [
      ...document.querySelectorAll("section.import-preview__group"),
    ].map((group) => ({
      title: text(group, ".import-preview__group-title"),
      support: text(group, ".import-preview__group-help"),
      rows: [...group.querySelectorAll("li.import-preview__row")].map(
        (row) => ({
          label: text(row, ".import-preview__badge"),
          number: text(row, ".import-preview__number"),
          variant: text(row, ".import-preview__variant"),
          name: text(row, ".import-preview__name"),
          line: text(row, ".import-preview__origin"),
          numbers: [
            ...row.querySelectorAll(
              ".import-preview__antes, .import-preview__depois",
            ),
          ].map((node) => squash(node.textContent)),
          reason: row.querySelector(".import-preview__motivo")
            ? text(row, ".import-preview__motivo")
            : null,
        }),
      ),
    }));
    const warning = document.querySelector(".import-preview__warning");
    return {
      file: text(document.body, ".import-preview__file"),
      warning: warning ? squash(warning.textContent) : null,
      groups,
    };
  });
}

function spaPreview(page: Page): Promise<Preview> {
  return page.evaluate(() => {
    const squash = (text: string | null | undefined) =>
      (text ?? "").replace(/\s+/g, " ").trim();
    const text = (root: Element, selector: string) =>
      squash(root.querySelector(selector)?.textContent);
    const groups = [...document.querySelectorAll("main section.group")].map(
      (group) => ({
        title: text(group, "h2"),
        support: squash(group.querySelector(":scope > p")?.textContent),
        rows: [...group.querySelectorAll("li > .row")].map((row) => {
          const detail = row.querySelector(".detail");
          const rejected = row.classList.contains("rejected");
          return {
            label: text(row, ".label"),
            number: text(row, ".card-number"),
            variant: squash(
              row.querySelector(".head > :nth-child(3)")?.textContent,
            ),
            name: text(row, ".name"),
            line: text(row, ".line"),
            numbers: rejected
              ? []
              : [...(detail?.querySelectorAll("strong") ?? [])].map((node) =>
                  squash(node.textContent),
                ),
            reason: rejected ? squash(detail?.textContent) : null,
          };
        }),
      }),
    );
    const warning = document.querySelector("main .removal");
    return {
      file: squash(
        document.querySelector("main section[aria-busy] > p > strong")
          ?.textContent,
      ),
      warning: warning ? squash(warning.textContent) : null,
      groups,
    };
  });
}

async function expectNoHorizontalScroll(page: Page, where: string) {
  const { scrollWidth, clientWidth } = await page.evaluate(() => ({
    scrollWidth: document.documentElement.scrollWidth,
    clientWidth: document.documentElement.clientWidth,
  }));
  expect(scrollWidth, `scroll horizontal em ${where}`).toBe(clientWidth);
}

async function expectTouchTargets(page: Page, where: string) {
  const buttons = page.locator("main#conteudo button");
  const count = await buttons.count();
  for (let index = 0; index < count; index++) {
    const box = await buttons.nth(index).boundingBox();
    expect(box, `caixa do botão ${index} em ${where}`).not.toBeNull();
    expect(
      box!.height,
      `altura do botão ${index} em ${where}`,
    ).toBeGreaterThanOrEqual(44);
    expect(
      box!.width,
      `largura do botão ${index} em ${where}`,
    ).toBeGreaterThanOrEqual(44);
  }
}

const countsOf = (page: Page, selector: string) =>
  page
    .locator(selector)
    .evaluateAll((items) =>
      items.map(
        (item) =>
          (item.textContent ?? "").replace(/\s+/g, " ").trim().split(" ")[0],
      ),
    );

let picks: Pick[] = [];
let fiveClasses = "";
// A não confirma nada; B confirma pelo HTML e C pela SPA, com a mesma coleção inicial.
const owners = {} as Record<"A" | "B" | "C", Owner>;

test.describe.configure({ mode: "serial" });

test.beforeAll(async ({ browser }) => {
  test.setTimeout(240_000);
  const probe = await browser.newContext({ baseURL: BASE_URL });
  picks = variantsOf(await fetchCards(probe));
  await probe.close();
  expect(picks.length, "variantes na fonte").toBeGreaterThan(MAX_ROWS / 2);

  const [owned2, owned3, owned1, absent] = picks;
  const seed = [
    { pick: owned2, copies: 2 },
    { pick: owned3, copies: 3 },
    { pick: owned1, copies: 1 },
  ];
  // Uma linha de cada classificação, fora da ordem de exibição.
  fiveClasses = csv([
    [absent.number, absent.code, "Passa a constar <i>não é html</i>", 2],
    [owned2.number, owned2.code, owned2.name, 0],
    [owned3.number, LONG_CODE, "Variante que não existe", 1],
    [owned1.number, owned1.code, owned1.name, 1],
    [owned3.number, owned3.code, owned3.name, 5],
  ]);

  for (const label of ["A", "B", "C"] as const) {
    owners[label] = await createOwner(browser, label, seed);
  }
});

test.describe("pré-visualização igual à do HTML e coleção intacta (Goal 1, SPOR-13..15, SPOR-20)", () => {
  test("o mesmo arquivo dá os mesmos grupos, linhas, antes, depois e motivos", async ({
    browser,
  }) => {
    const { context, page } = await openAs(browser, owners.A);
    expect(
      (await exportCsv(context)).trim().split("\n").length,
      "cabeçalho e três variantes",
    ).toBe(4);

    await uploadHtml(page, fiveClasses);
    const html = await htmlPreview(page);

    await uploadSpa(page, fiveClasses);
    await expect(confirmButton(page)).toBeVisible();
    const spa = await spaPreview(page);

    expect(
      html.groups.map((group) => group.title.replace(/ \(\d+\)$/, "")),
      "as cinco classificações, na ordem de consequência",
    ).toEqual([
      "Remove da coleção",
      "Passa a constar",
      "Altera a quantidade",
      "Não será importada",
      "Já está assim",
    ]);
    expect(
      spa.groups,
      "grupos, ordem, linhas, números de linha, antes, depois e motivos",
    ).toEqual(html.groups);
    expect(spa.file, "arquivo e linhas analisadas").toBe(html.file);
    expect(spa.warning, "aviso de remoção").toBe(html.warning);
    expect(spa.warning).toContain(
      "Atenção: 1 carta que você possui hoje sai da sua coleção",
    );
    expect(
      html.groups.flatMap((group) => group.rows).map((row) => row.line),
      "números de linha do arquivo (o cabeçalho é a linha 1)",
    ).toEqual(
      expect.arrayContaining(["Linha 2 do arquivo", "Linha 6 do arquivo"]),
    );
    const creates = spa.groups.find((group) =>
      group.title.startsWith("Passa a constar"),
    )!;
    expect(creates.rows[0].numbers, '"cria" só traz a nova quantidade').toEqual(
      ["2"],
    );
    expect(
      creates.rows[0].name,
      "o HTML do arquivo aparece como texto",
    ).toContain("<i>");

    await context.close();
  });

  test("enviar, abrir, recarregar e sair da pré-visualização não mexe em collection_items", async ({
    browser,
  }) => {
    const { context, page } = await openAs(browser, owners.A);
    const before = await exportCsv(context);

    await uploadSpa(page, fiveClasses);
    await expect(confirmButton(page)).toBeVisible();
    expect(await exportCsv(context), "depois de enviar e abrir").toBe(before);

    await page.reload();
    await expect(confirmButton(page)).toBeVisible();
    expect(await exportCsv(context), "depois de recarregar").toBe(before);

    await page.getByRole("link", { name: "envie outro arquivo" }).click();
    await expect(page).toHaveURL(/\/app\/pasta\/importar$/);
    await page.goto("pasta");
    await expect(
      page.getByRole("heading", { name: "Minha pasta", level: 1 }),
    ).toBeVisible();
    expect(await exportCsv(context), "depois de sair sem confirmar").toBe(
      before,
    );

    await context.close();
  });

  test('o CSV baixado, enviado sem edição, só tem "Já está assim" (SPOR-34)', async ({
    browser,
  }) => {
    const { context, page } = await openAs(browser, owners.A);
    const before = await exportCsv(context);

    await uploadSpa(page, before);
    await expect(confirmButton(page)).toBeVisible();
    const preview = await spaPreview(page);
    expect(preview.groups.map((group) => group.title)).toEqual([
      "Já está assim (3)",
    ]);

    await confirmButton(page).click();
    await expect(doneHeading(page)).toBeVisible();
    expect(
      await exportCsv(context),
      "coleção idêntica depois de confirmar",
    ).toBe(before);

    await context.close();
  });
});

test.describe("confirmação (Goal 2, SPOR-22, SPOR-30)", () => {
  test("confirmar pela SPA grava o mesmo que o HTML e recarregar dá 409", async ({
    browser,
  }) => {
    const html = await openAs(browser, owners.B);
    const spa = await openAs(browser, owners.C);
    const initial = await exportCsv(html.context);
    expect(await exportCsv(spa.context), "mesma coleção inicial").toBe(initial);

    await uploadHtml(html.page, fiveClasses);
    // O HTML responde 200 sem redirect: com Turbo a resposta seria descartada, então o form vai nativo.
    await html.page.locator("form.import-preview__form").evaluate((form) => {
      form.setAttribute("data-turbo", "false");
    });
    await confirmButton(html.page).click();
    await expect(doneHeading(html.page)).toBeVisible();
    const htmlCounts = await countsOf(html.page, ".import-summary__count");
    const afterHtml = await exportCsv(html.context);
    expect(afterHtml, "o HTML mudou a coleção").not.toBe(initial);

    await uploadSpa(spa.page, fiveClasses);
    await confirmButton(spa.page).click();
    await expect(doneHeading(spa.page)).toBeVisible();
    await expect(
      doneHeading(spa.page),
      "foco no h1 do resumo (SPOR-22)",
    ).toBeFocused();
    await expect(spa.page).toHaveTitle("Importação concluída — Bindr");

    const spaCounts = await countsOf(spa.page, "main .stat");
    expect(spaCounts, "mesmas contagens do HTML").toEqual(htmlCounts);
    expect(
      spaCounts,
      "importadas, atualizadas (com a remoção) e recusadas",
    ).toEqual(["1", "2", "1"]);
    const summary = squash(await spa.page.locator("main").innerText());
    expect(summary).toContain(
      "1 dessas atualizações removeu a carta da sua coleção: o arquivo trazia zero para uma variante que você possuía.",
    );
    expect(summary).toContain(
      "1 linha do arquivo já estava assim na sua coleção: nada mudou nelas.",
    );
    expect(summary).toContain(
      "Confira estas linhas: 1 linha do arquivo não foi aplicada.",
    );

    const afterSpa = await exportCsv(spa.context);
    expect(afterSpa, "a SPA grava o mesmo que o HTML").toBe(afterHtml);

    await spa.page.reload();
    await expect(confirmButton(spa.page)).toBeVisible();
    await confirmButton(spa.page).click();
    await expect(alertBlock(spa.page)).toContainText(
      "Esta importação já foi confirmada ou expirou",
    );
    await expect(
      confirmButton(spa.page),
      "a pré-visualização continua",
    ).toBeVisible();
    expect(
      await exportCsv(spa.context),
      "a segunda confirmação não grava",
    ).toBe(afterSpa);

    await html.context.close();
    await spa.context.close();
  });
});

test.describe("recusa do arquivo (SPOR-07)", () => {
  test('arquivo com ";" mostra a frase do separador, foca o alerta e fica na tela de envio', async ({
    browser,
  }) => {
    const { context, page } = await openAs(browser, owners.A);
    const before = await exportCsv(context);

    await page.goto("pasta/importar");
    await page
      .locator('input[type="file"]')
      .setInputFiles(
        csvFile(
          "card_number;variant_code;card_name;quantity\nOP01-001;x;y;1\n",
        ),
      );
    await page.getByRole("button", { name: SUBMIT }).click();

    await expect(alertBlock(page)).toContainText(
      'O arquivo está separado por ";" em vez de ","',
    );
    await expect(alertBlock(page)).toBeFocused();
    await expect(page.locator('input[type="file"]')).toHaveAttribute(
      "aria-invalid",
      "true",
    );
    await expect(page).toHaveURL(/\/app\/pasta\/importar$/);
    expect(await exportCsv(context)).toBe(before);

    await context.close();
  });
});

test.describe("360px e 1280px nos dois temas (SPOR-46)", () => {
  for (const viewport of VIEWPORTS) {
    for (const scheme of SCHEMES) {
      test(`${viewport.name}, tema ${scheme}: envio, pré-visualização e resumo sem scroll lateral`, async ({
        browser,
      }) => {
        const { context, page } = await openAs(browser, owners.A, {
          viewport: { width: viewport.width, height: viewport.height },
          colorScheme: scheme,
        });
        const file = csv([
          [picks[2].number, LONG_CODE, LONG_NAME, 1],
          [picks[2].number, picks[2].code, LONG_NAME, 1],
        ]);
        const where = `${viewport.name} ${scheme}`;

        await page.goto("pasta/importar");
        await expect(
          page.getByRole("heading", { name: "Importar coleção", level: 1 }),
        ).toBeVisible();
        expect(await page.locator("html").getAttribute("data-theme")).toBe(
          scheme,
        );
        await expectNoHorizontalScroll(page, `envio ${where}`);
        await expectTouchTargets(page, `envio ${where}`);

        await page.locator('input[type="file"]').setInputFiles(csvFile(file));
        await page.getByRole("button", { name: SUBMIT }).click();
        await page.waitForURL(/\/app\/pasta\/importar\/[^/]+$/);
        await expect(confirmButton(page)).toBeVisible();
        await expect(page.getByText(LONG_NAME).first()).toBeVisible();
        await expect(page.getByText(LONG_CODE).first()).toBeVisible();
        await expectNoHorizontalScroll(page, `pré-visualização ${where}`);
        await expectTouchTargets(page, `pré-visualização ${where}`);

        await confirmButton(page).click();
        await expect(doneHeading(page)).toBeVisible();
        await expect(page.getByText(LONG_NAME).first()).toBeVisible();
        await expectNoHorizontalScroll(page, `resumo ${where}`);
        await expectTouchTargets(page, `resumo ${where}`);

        await context.close();
      });
    }
  }
});

test.describe("10.000 linhas (tempo de renderização)", () => {
  for (const viewport of VIEWPORTS) {
    test(`${viewport.name}: tempo até o botão de confirmar visível`, async ({
      browser,
    }) => {
      test.setTimeout(240_000);
      const { context, page } = await openAs(browser, owners.A, {
        viewport: { width: viewport.width, height: viewport.height },
      });
      const rows = picks
        .slice(0, MAX_ROWS)
        .map((pick): [string, string, string, number] => [
          pick.number,
          pick.code,
          pick.name,
          1,
        ]);
      while (rows.length < MAX_ROWS) rows.push(rows[0]);

      await page.goto("pasta/importar");
      await page
        .locator('input[type="file"]')
        .setInputFiles(csvFile(csv(rows)));
      const sentAt = Date.now();
      await page.getByRole("button", { name: SUBMIT }).click();
      await page.waitForURL(/\/app\/pasta\/importar\/[^/]+$/, {
        timeout: 120_000,
      });
      await expect(confirmButton(page)).toBeVisible({ timeout: 120_000 });
      const uploadMs = Date.now() - sentAt;
      await expect(page.locator("main section.group li")).toHaveCount(MAX_ROWS);

      const url = page.url();
      await page.goto("about:blank");
      const openedAt = Date.now();
      await page.goto(url);
      await expect(confirmButton(page)).toBeVisible({ timeout: 120_000 });
      const openMs = Date.now() - openedAt;

      const report = `${viewport.name}: envio até o botão ${uploadMs} ms; abrir a URL até o botão ${openMs} ms`;
      console.log(`[tempo 10.000 linhas] ${report}`);
      test
        .info()
        .annotations.push({ type: "tempo 10.000 linhas", description: report });
      if (viewport.width === 360) {
        expect(
          openMs,
          "acima de 5 s a 360px: parar e levar ao dono",
        ).toBeLessThanOrEqual(PREVIEW_BUDGET_MS);
      }

      await context.close();
    });
  }
});
