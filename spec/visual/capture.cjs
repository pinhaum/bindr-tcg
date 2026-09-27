#!/usr/bin/env node

/**
 * Script Node puro para capturar telas do app em diferentes viewports
 * e estados de autenticação, produzindo evidência visual das tasks de layout.
 *
 * Uso:
 *   NODE_PATH=/path/to/node_modules node spec/visual/capture.cjs
 *
 * Env vars:
 *   BASE_URL (default: http://localhost:3000)
 *   CHROMIUM_PATH (opcional, path executável do Chromium)
 *   NODE_PATH (obrigatório se playwright não estiver em node_modules padrão)
 */

const fs = require('fs');
const path = require('path');

let playwright;
try {
  playwright = require('playwright');
} catch (e) {
  const nodePathMsg = process.env.NODE_PATH
    ? ` (NODE_PATH=${process.env.NODE_PATH})`
    : '';
  console.error(
    'Erro: playwright não encontrado. ' +
    'Defina NODE_PATH para um diretório node_modules que contenha playwright, ' +
    'ex.: NODE_PATH=/home/pho/lab/wallpaper-slider/node_modules' +
    nodePathMsg
  );
  process.exit(1);
}

const BASE_URL = process.env.BASE_URL || 'http://localhost:3000';
const CAPTURE_DIR = path.join(__dirname, '..', '..', 'tmp', 'capturas');
const CHROMIUM_PATH = process.env.CHROMIUM_PATH || undefined;

// Viewports: mobile (390x1000) e desktop (1280x900)
const VIEWPORTS = [
  { name: '390', width: 390, height: 1000 },
  { name: '1280', width: 1280, height: 900 },
];

/**
 * Aguarda até que a URL atenda a um critério (ou timeout).
 */
async function waitForUrl(page, predicate, timeout = 10000) {
  const startTime = Date.now();
  while (Date.now() - startTime < timeout) {
    const url = page.url();
    if (predicate(url)) {
      return url;
    }
    await page.waitForTimeout(100);
  }
  throw new Error(`Timeout aguardando URL (${timeout}ms)`);
}

/**
 * Cria um usuário descartável e faz login via formulário de cadastro.
 */
async function createAndLoginUser(page) {
  const timestamp = Date.now();
  const email = `captura-${timestamp}@example.com`;
  const password = `SecurePass${timestamp}`;

  console.log(`[auth] Navegando para cadastro...`);
  await page.goto(`${BASE_URL}/registration/new`, { waitUntil: 'domcontentloaded' });

  console.log(`[auth] Preenchendo formulário com email: ${email}`);
  await page.fill('input[name="user[email]"]', email);
  await page.fill('input[name="user[password]"]', password);
  await page.fill('input[name="user[password_confirmation]"]', password);

  console.log(`[auth] Enviando formulário...`);
  // Usa input[type="submit"] que é o seletor para form.submit no Rails
  await page.click('input[type="submit"]');

  // Aguarda a navegação sair do register/sessions (Turbo navega após 'load')
  console.log(`[auth] Aguardando redirecionamento pós-login...`);
  const finalUrl = await waitForUrl(
    page,
    (url) => !url.includes('registration') && !url.includes('session'),
    10000
  );
  console.log(`[auth] Login concluído, URL final: ${finalUrl}`);

  return email;
}

/**
 * Captura tela e registra metadados.
 */
async function captureScreen(page, screenName, viewport, authenticated) {
  const filename = `${screenName}-${viewport.name}-${authenticated ? 'sessao' : 'anon'}.png`;
  const filepath = path.join(CAPTURE_DIR, filename);

  const url = page.url();
  const scrollWidth = await page.evaluate(() => document.documentElement.scrollWidth);
  const hasHorizontalScroll = scrollWidth > viewport.width;

  console.log(`  [captura] ${filename}`);
  console.log(`    URL: ${url}`);
  console.log(`    scrollWidth: ${scrollWidth}px (viewport: ${viewport.width}px)`);
  if (hasHorizontalScroll) {
    console.log(`    SCROLL-HORIZONTAL`);
  }

  await page.screenshot({ path: filepath, fullPage: true });
}

/**
 * Main
 */
async function main() {
  // Verifica conectividade com o app
  console.log(`[startup] Verificando conectividade com ${BASE_URL}...`);
  try {
    const response = await fetch(`${BASE_URL}/up`);
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    console.log(`[startup] App respondendo OK`);
  } catch (error) {
    console.error(
      `Erro: app não responde em ${BASE_URL} — rode docker compose up\n` +
      `Detalhes: ${error.message}`
    );
    process.exit(1);
  }

  // Cria diretório de capturas
  if (!fs.existsSync(CAPTURE_DIR)) {
    fs.mkdirSync(CAPTURE_DIR, { recursive: true });
    console.log(`[startup] Diretório criado: ${CAPTURE_DIR}`);
  }

  let browser;
  try {
    console.log(`[startup] Iniciando navegador...`);
    const launchOptions = {};
    if (CHROMIUM_PATH) {
      launchOptions.executablePath = CHROMIUM_PATH;
    }
    browser = await playwright.chromium.launch(launchOptions);

    // === Capturas sem sessão (anônimo) ===
    console.log(`\n[anon] Iniciando capturas sem sessão...`);
    for (const viewport of VIEWPORTS) {
      const context = await browser.newContext({ viewport });
      const page = await context.newPage();

      // Tela 1: Catálogo
      console.log(`\n[anon] ${viewport.name}px - Catálogo`);
      await page.goto(`${BASE_URL}/`, { waitUntil: 'domcontentloaded' });
      await captureScreen(page, 'catalogo', viewport, false);

      // Tela 2: Detalhe (primeira carta da grade)
      console.log(`\n[anon] ${viewport.name}px - Detalhe`);
      // Navega para a primeira carta
      const firstCardLink = await page.$('.catalog__body a.card-tile__link');
      if (!firstCardLink) {
        throw new Error('Nenhuma carta encontrada no catálogo');
      }
      const cardHref = await firstCardLink.getAttribute('href');
      console.log(`[anon] Primeira carta: ${cardHref}`);
      await page.goto(`${BASE_URL}${cardHref}`, { waitUntil: 'domcontentloaded' });
      await captureScreen(page, 'detalhe', viewport, false);

      await context.close();
    }

    // === Capturas com sessão ===
    console.log(`\n[auth] Iniciando capturas com sessão...`);
    for (const viewport of VIEWPORTS) {
      const context = await browser.newContext({ viewport });
      const page = await context.newPage();

      // Login
      const email = await createAndLoginUser(page);
      console.log(`[auth] ${viewport.name}px - Usuário criado: ${email}`);

      // Tela 1: Catálogo
      console.log(`\n[auth] ${viewport.name}px - Catálogo`);
      await page.goto(`${BASE_URL}/`, { waitUntil: 'domcontentloaded' });
      await captureScreen(page, 'catalogo', viewport, true);

      // Tela 2: Detalhe (primeira carta)
      console.log(`\n[auth] ${viewport.name}px - Detalhe`);
      const firstCardLink = await page.$('.catalog__body a.card-tile__link');
      if (!firstCardLink) {
        throw new Error('Nenhuma carta encontrada no catálogo');
      }
      const cardHref = await firstCardLink.getAttribute('href');
      await page.goto(`${BASE_URL}${cardHref}`, { waitUntil: 'domcontentloaded' });
      await captureScreen(page, 'detalhe', viewport, true);

      // Tela 3: Pasta (progresso)
      console.log(`\n[auth] ${viewport.name}px - Pasta`);
      await page.goto(`${BASE_URL}/progress`, { waitUntil: 'domcontentloaded' });
      await captureScreen(page, 'pasta', viewport, true);

      // Tela 4: Wishlist
      console.log(`\n[auth] ${viewport.name}px - Wishlist`);
      await page.goto(`${BASE_URL}/wishlist`, { waitUntil: 'domcontentloaded' });
      await captureScreen(page, 'wishlist', viewport, true);

      // Tela 5: Import
      console.log(`\n[auth] ${viewport.name}px - Import`);
      await page.goto(`${BASE_URL}/collection/import`, { waitUntil: 'domcontentloaded' });
      await captureScreen(page, 'import', viewport, true);

      await context.close();
    }

    console.log(`\n[done] ${VIEWPORTS.length * (2 + 5)} capturas salvas em ${CAPTURE_DIR}`);
    process.exit(0);
  } catch (error) {
    console.error(`\nErro durante captura: ${error.message}`);
    console.error(error.stack);
    process.exit(1);
  } finally {
    if (browser) {
      await browser.close();
    }
  }
}

main();
