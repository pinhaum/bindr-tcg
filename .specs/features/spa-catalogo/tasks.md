# Catálogo na SPA — Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Design**: `.specs/features/spa-catalogo/design.md`
**Status**: Executed (T1–T25); Verifier it.1 FAIL → fase 5 (T26–T28)

---

## Test Coverage Matrix

> Generated from codebase, project guidelines, and spec - confirm before Execute. Guidelines found: `CLAUDE.md` (seção "Front SPA": gates quick e e2e, ESLint que proíbe `fetch` fora de `client.ts`, armadilhas do Kit 3; "toda task termina com código que roda e teste que passa"), `frontend/vitest` + `@testing-library/svelte` (jsdom), `frontend/playwright.config.ts` (serviço `e2e`, `baseURL` `http://frontend:5173/app/`, um worker), `frontend/src/lib/styles/guard.test.ts` (hex, px de token e animação fora de `transform`/`opacity` reprovam). Amostras lidas: `src/lib/api/client.test.ts`, `src/lib/navigation/return-to.test.ts`, `src/lib/components/MainNav.test.ts`, `src/lib/components/AppShell.test.ts`, `src/routes/criar-conta/page.test.ts`, `e2e/sessao.spec.ts`, `e2e/casco.spec.ts`. O piso é o da `spa-fundacao`; o alvo vem dos ACs do spec (strong default).

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| ---------- | ------------------ | -------------------- | ---------------- | ----------- |
| Cliente HTTP (`src/lib/api/*`) | unit | `getEnvelope`: sucesso devolve `data` e `meta`; envelope sem `data` ou sem `meta` objeto dá `unexpected_response`; `401`, rede e tempo limite seguem as regras do `get` (mesmos testes, mesmo resultado) | `frontend/src/lib/api/*.test.ts` | quick |
| Funções puras (`catalog/url.ts`, `return-to.ts`, `nav-entries.ts`, `view-transition.ts`) | unit | Todos os ramos, 1:1 com os ACs citados na task; cada edge case do spec que cai na função (parâmetro descartado, `owned=all`, set `null`/`''`/código, termo só com espaços, `card_number` com caractere reservado); `href` exato, com a serialização `chave%5B%5D=valor` | `frontend/src/lib/**/*.test.ts` | quick |
| Estado (`*.svelte.ts`) | unit | Todos os ramos com cliente falso e timer falso: token de sequência (resposta antiga descartada), skeleton só depois de 200 ms, `error` mantém `result`, `seq` sobe a cada resposta aplicada, erro não-`ApiError` relançado, `retry`; opções carregadas uma vez, sem repetir carga em curso, com nova tentativa | `frontend/src/lib/**/*.test.ts` | quick |
| CSS global (`base.css`) | unit | A regra `visually-hidden` existe com as propriedades que a tornam invisível e lida; o `guard.test.ts` continua verde | `frontend/src/lib/styles/*.test.ts` | quick |
| Componentes e páginas (`.svelte`) | unit (componente, jsdom) | Cada AC de tela: texto exato (pt-BR), `href` exato, ARIA (`aria-current`, `aria-label`, `aria-busy`, `role="status"`, `role="img"`, `role="search"`), foco depois de `tick()`, estados vazio/erro/skeleton, com e sem sessão | `frontend/src/**/*.test.ts` | quick |
| Jornadas no navegador | e2e (Playwright contra a API real) | Paridade `/app?…` × `/catalog?…` (nomes, ordem, contagem) para busca, cor múltipla, set, faixa e ordenação; 360px e 1280px nos dois temas sem scroll horizontal; cinco colunas a 1280px; foco por teclado; painel; sessão; voltar e avançar; regressão da jornada de sessão da fundação | `frontend/e2e/*.spec.ts` | e2e |
| Docs (`CLAUDE.md`, `STATE.md`, `.context/tasks.md`) | none | - | - | build gate only |

## Gate Check Commands

> Generated from codebase - confirm before Execute. Rodar as suítes em série, nunca em paralelo (flake D-10). `npm ci` com o serviço `frontend` de pé troca o `node_modules` sob o Vite: parar o serviço antes do quick ou reiniciá-lo depois. Se o pull de imagem falhar pelo `credsStore` do host, `export DOCKER_CONFIG=$(mktemp -d)` com `{}` em `config.json`.

| Gate Level | When to Use | Command |
| ---------- | ----------- | ------- |
| Quick | Tasks do front com teste de unidade | `docker compose run --rm --no-deps frontend sh -c "npm ci && npm run check && npm run lint && npm test -- --run"` |
| Full | Tasks e2e (depois do quick) | quick + `docker compose up -d app frontend && docker compose --profile e2e run --rm e2e` + `docker compose exec app bin/rails test` |
| Build | Fechamento | `docker build -f Dockerfile . && docker compose run --rm --no-deps frontend sh -c "npm ci && npm run check && npm run lint && npm test -- --run && npm run build"` + Full + `docker compose exec app bin/rubocop` + `git diff --stat 751e553..HEAD -- app/` vazio (SCAT-45) |

---

## Execution Plan

Phases are ordered and run sequentially - each phase completes before the next begins, and tasks within a phase execute in order. Cada diagrama traz todas as dependências das tasks da phase, inclusive as que vêm de phases anteriores.

### Phase 1: Funções puras, cliente e guardas

```
T1 → T4
T4 → T5
```

T1, T2, T3, T6 e T7 não dependem de nada.

### Phase 2: Estado, casco e tile

```
T1 → T8
T1 → T9
T1 → T12
T12 → T13
```

T10 e T11 não dependem de nada.

### Phase 3: Componentes de busca, status e filtro

```
T5 → T17
T14 → T17
T4 → T18
T4 → T19
T9 → T19
T14 → T19
```

T14, T15 e T16 não dependem de nada.

### Phase 4: Página, ponta a ponta e fechamento

```
T3 → T20
T6 → T20
T8 → T20
T12 → T20
T13 → T20
T15 → T20
T16 → T20
T17 → T20
T18 → T20
T2 → T21
T10 → T21
T11 → T21
T19 → T21
T20 → T21
T21 → T22
T22 → T23
T23 → T24
T7 → T25
T24 → T25
```

### Phase 5: Correções do Verifier (iteração 1)

```
T25 → T26
T26 → T27
T25 → T28
```

---

## Task Breakdown

### T1: Tipos do catálogo e `getEnvelope` no cliente

**What**: Acrescentar a `src/lib/api/types.ts` os tipos `CatalogVariant`, `CatalogCard`, `ActiveFilters`, `CatalogMeta`, `CatalogPage` e `FilterOptions` do design (Data Models), e ao cliente o método `getEnvelope<T, M>(path)`, que passa pelas mesmas regras de erro do `get` e devolve `{ data, meta }`; envelope sem `data`, ou com `meta` ausente ou que não seja objeto, dá `unexpected_response`.
**Where**: `frontend/src/lib/api/client.ts`
**Depends on**: None
**Reuses**: `request` e `isRecord` do próprio cliente; testes de `client.test.ts`
**Requirement**: SCAT-04, SCAT-45

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] `getEnvelope('/api/catalog?colors%5B%5D=Red&q=zoro')` chama `fetch` com esse caminho exato, sem reordenar nem recodificar a query (SCAT-04)
- [x] Sucesso devolve `{ data, meta }` como vieram; sem `data` ou sem `meta` objeto → `ApiError` `unexpected_response`
- [x] `401 unauthenticated` chama `onUnauthenticated`; rede e tempo limite dão `network_error` (mesmos casos do `get`)
- [x] `fetch` continua só em `client.ts` (lint verde)
- [x] Gate check passes: quick
- [x] Test count: anteriores + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-catalogo): devolver data e meta do envelope pelo cliente HTTP`

---

### T2: `safeReturnTo` aceita `/app` e `/app?…`

**What**: Aceitar `raw === base` e `raw.startsWith(base + '?')` além de `base + '/'`, mantendo todas as recusas atuais (`//`, `\`, controle, segmentos `.`/`..`, fora de `/app`).
**Where**: `frontend/src/lib/navigation/return-to.ts`
**Depends on**: None
**Reuses**: `return-to.test.ts`
**Requirement**: SCAT-31

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] `/app?colors%5B%5D=Red&owned=owned` e `/app` voltam como vieram
- [x] `/appx`, `/app?x=//evil`, `/app?\\`, `/app?` com caractere de controle e todas as recusas anteriores continuam devolvendo `/app` (emenda da execução: os dois casos antigos que recusavam `/app` e `/app?x=1` viraram aceitos por exigência do SCAT-31; as demais recusas passam sem edição)
- [x] Gate check passes: quick
- [x] Test count: anteriores + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `fix(spa-catalogo): aceitar /app com query como destino de return_to`

---

### T3: Entrada "Catálogo" aponta para `/app`

**What**: Em `navEntries`, "Catálogo" vira entrada da SPA com `href` `/app` e `reload: false`, com e sem sessão; `nav-entries.test.ts` e `MainNav.test.ts` emendados para o novo destino, e `MainNav.test.ts` prova `aria-current="page"` em `/app` e em `/app?colors%5B%5D=Red`.
**Where**: `frontend/src/lib/navigation/nav-entries.ts`
**Depends on**: None
**Reuses**: `inApp` / `appPath`; `isCurrent` do `MainNav` (sem mudança)
**Requirement**: SCAT-02

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] "Catálogo" tem `href` `/app` e não recarrega a página, com e sem sessão; as demais entradas e a ordem não mudam
- [x] Em `/app` e em `/app?colors%5B%5D=Red`, só "Catálogo" tem `aria-current="page"`
- [x] Gate check passes: quick
- [x] Test count: anteriores + novos; asserções antigas de `/catalog` trocadas, não apagadas

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-catalogo): apontar a entrada Catálogo para /app`

---

### T4: Links do catálogo a partir de `active_filters`

**What**: Criar `src/lib/catalog/url.ts` com `catalogHref`, `toggleHref`, `withoutHref`, `pageHref`, `clearHref`, `searchHref` e `setHref` sobre `ActiveFilters`, com a semântica do `CatalogHelper` e do design: listas como `chave[]=valor` repetido via `URLSearchParams.append`, escalares como `chave=valor`, ordem das chaves preservada, `page` descartado em toda alternância, remoção, busca e set, `per_page` nunca gerado.
**Where**: `frontend/src/lib/catalog/url.ts`
**Depends on**: T1
**Reuses**: `appPath`; `app/helpers/catalog_helper.rb` como referência
**Requirement**: SCAT-05, SCAT-06, SCAT-16, SCAT-19, SCAT-23, SCAT-24, SCAT-25, SCAT-27, SCAT-30, SCAT-36

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] `catalogHref({})` é `/app`; `catalogHref({ colors: ['Red', 'Green'], sort: 'name' })` é `/app?colors%5B%5D=Red&colors%5B%5D=Green&sort=name`
- [x] `toggleHref` acrescenta valor inativo e remove ativo numa lista; em `owned`, liga o valor, e remove a chave com o mesmo valor ou com `all`; sem `page` (SCAT-19, 25)
- [x] `withoutHref` tira um valor de lista (a chave some com a lista vazia) ou a chave escalar; sem `page`
- [x] `pageHref` mantém os filtros e põe `page`; `clearHref` mantém só `sort` e `dir` (SCAT-30, 36)
- [x] `searchHref(f, '  zoro ')` com `colors: ['Red']` e `page: 3` gera `?q=zoro` mais `colors[]=Red`, sem `page`; termo só com espaços remove `q` (SCAT-16)
- [x] `setHref`: `null` mantém tudo menos `page`; `''` remove `sets`; código põe `sets` igual só a ele (SCAT-23, 24)
- [x] Faixas, `attributes`, `traits`, `sort` e `dir` sobrevivem a toda função (SCAT-27); nenhum link contém chave fora de `active_filters` (SCAT-06)
- [x] Gate check passes: quick
- [x] Test count: anteriores + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-catalogo): montar os links do catálogo a partir dos filtros ativos`

---

### T5: Chips de filtros ativos e rótulos

**What**: Acrescentar a `url.ts` o `FILTER_LABELS` (mapa do `CatalogHelper` mais `owned: "Posse"`) e `filterChips(filters): Chip[]`, um chip por valor na ordem das chaves e dos valores, sem `sort`, `dir`, `page` e `per_page`, com `text` "<rótulo>: <valor exibido>", posse como "Tenho"/"Não tenho" e `href` de `withoutHref`.
**Where**: `frontend/src/lib/catalog/url.ts`
**Depends on**: T4
**Reuses**: `withoutHref` (T4)
**Requirement**: SCAT-28, SCAT-29, SCAT-20

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Cada rótulo do SCAT-28 sai exato (Busca, Cor, Tipo, Set, Raridade, Attribute, Trait, Custo mín., Custo máx., Power mín., Power máx., Counter mín., Counter máx., Posse)
- [x] `{ colors: ['Red', 'Green'], owned: 'missing', sort: 'name', page: 2 }` dá três chips: "Cor: Red", "Cor: Green", "Posse: Não tenho", cada `href` sem o próprio valor, sem `page` e com `sort=name`
- [x] Sem filtro, `filterChips` devolve lista vazia
- [x] Gate check passes: quick
- [x] Test count: anteriores + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-catalogo): derivar os chips de filtros ativos com rótulos em pt-BR`

---

### T6: Classe `visually-hidden`

**What**: Regra `.visually-hidden` em `base.css` (posição absoluta, 1px × 1px, `overflow: hidden`, `clip-path: inset(50%)`, `white-space: nowrap`, sem margem nem borda), para a região de anúncio do catálogo.
**Where**: `frontend/src/lib/styles/base.css`
**Depends on**: None
**Reuses**: leitura de CSS cru do `guard.test.ts`
**Requirement**: SCAT-44

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Teste lê `base.css` cru e confere a regra com as propriedades acima
- [x] `guard.test.ts` verde sem edição
- [x] Gate check passes: quick
- [x] Test count: anteriores + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-catalogo): acrescentar a classe visually-hidden ao CSS base`

---

### T7: Sem View Transition na mesma rota

**What**: `viewTransitionOnNavigate` retorna sem transição quando `navigation.from?.url.pathname === navigation.to?.url.pathname`; entre rotas diferentes continua como hoje (SPA-43).
**Where**: `frontend/src/lib/view-transition.ts`
**Depends on**: None
**Reuses**: `view-transition.test.ts`
**Requirement**: SCAT-41

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] `/app?colors%5B%5D=Red` → `/app?colors%5B%5D=Green` não chama `startViewTransition`
- [x] `/app` → `/app/entrar` chama, como antes; os testes antigos passam sem edição
- [x] Gate check passes: quick
- [x] Test count: anteriores + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-catalogo): não abrir View Transition quando só a query muda`

---

### T8: Carregador do catálogo

**What**: `src/lib/catalog/catalog.svelte.ts` com `createCatalogLoader(get, skeletonDelayMs = 200)`, que expõe `state` (`result`, `error`, `pending`, `skeleton`, `seq`), `load(search)` e `retry()`, conforme o design (token de sequência, timer do skeleton, `ApiError` grava `error` e mantém `result`, outro erro é relançado).
**Where**: `frontend/src/lib/catalog/catalog.svelte.ts`
**Depends on**: T1
**Reuses**: `ApiError` de `errors.ts`
**Requirement**: SCAT-04, SCAT-08, SCAT-38, SCAT-39

**Tools**:

- MCP: `plugin:svelte` (`svelte-autofixer` no `.svelte.ts`)
- Skill: `superpowers:test-driven-development`, `svelte:svelte-core-bestpractices`

**Done when**:

- [x] `load('?colors%5B%5D=Red')` chama `get('/api/catalog?colors%5B%5D=Red')`; `load('')` chama `get('/api/catalog')`
- [x] Duas cargas com a primeira resolvendo por último: só a segunda vira `result`, e `seq` sobe uma vez (SCAT-08)
- [x] Com timer falso, `skeleton` é falso em 199 ms e verdadeiro em 200 ms; a resposta zera `skeleton` e `pending` e cancela o timer; o `result` anterior fica até a resposta (SCAT-38)
- [x] `ApiError` grava `error`, mantém `result` e sobe `seq`; sucesso seguinte zera `error`; erro que não é `ApiError` é relançado (SCAT-39)
- [x] `retry()` repete a última `search`
- [x] Gate check passes: quick
- [x] Test count: anteriores + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-catalogo): carregar o catálogo descartando respostas antigas`

---

### T9: Opções de filtro

**What**: `src/lib/catalog/filter-options.svelte.ts` com `filterOptions` (`value`, `error`, `loading`), `ensureFilterOptions()` (nada faz com valor ou carga em curso) e `retryFilterOptions()`, chamando `GET /api/catalog/filters` pelo `api`.
**Where**: `frontend/src/lib/catalog/filter-options.svelte.ts`
**Depends on**: T1
**Reuses**: `api` de `src/lib/api/index.ts`
**Requirement**: SCAT-18, SCAT-40

**Tools**:

- MCP: `plugin:svelte` (`svelte-autofixer`)
- Skill: `superpowers:test-driven-development`, `svelte:svelte-core-bestpractices`

**Done when**:

- [x] Duas chamadas a `ensureFilterOptions` (antes e depois da resposta) fazem um único `GET /api/catalog/filters`
- [x] Falha grava `error` com a `message` da API e zera `loading`; `retryFilterOptions` refaz a chamada e, com sucesso, zera `error`
- [x] Gate check passes: quick
- [x] Test count: anteriores + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-catalogo): buscar as opções de filtro uma vez por carga do app`

---

### T10: Slot da coluna lateral no casco

**What**: `src/lib/shell.svelte.ts` com `shell` (`aside: Snippet | null`) e `wide = new MediaQuery('min-width: 64rem')`; o `AppShell` renderiza `shell.aside` em `.nav`, depois do `MainNav`, só quando `wide.current` e há snippet, numa superfície contínua com espaçamento por token.
**Where**: `frontend/src/lib/components/AppShell.svelte`
**Depends on**: None
**Reuses**: `MediaQuery` de `svelte/reactivity`; stub de `matchMedia` de `AppShell.test.ts`
**Requirement**: SCAT-33

**Tools**:

- MCP: `plugin:svelte` (`svelte-autofixer`, `get-documentation` de `MediaQuery`)
- Skill: `superpowers:test-driven-development`, `svelte:svelte-code-writer`

**Done when**:

- [x] Com `matchMedia` casando e um snippet em `shell.aside`, o conteúdo aparece dentro de `.nav`, depois da navegação
- [x] Sem casar (abaixo de 64rem) ou com `shell.aside` nulo, nada é renderizado
- [x] Testes antigos do `AppShell` passam sem edição; `guard.test.ts` verde
- [x] Gate check passes: quick
- [x] Test count: anteriores + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-catalogo): abrir no casco um slot de coluna lateral`

---

### T11: Foco não salta para `main` na mesma rota

**What**: No `afterNavigate` do layout, retornar cedo quando `navigation.from?.url.pathname === navigation.to?.url.pathname`; entre rotas diferentes, o foco segue indo a `main#conteudo` como hoje.
**Where**: `frontend/src/routes/+layout.svelte`
**Depends on**: None
**Reuses**: `layout.svelte.test.ts`
**Requirement**: SCAT-41

**Tools**:

- MCP: `plugin:svelte` (`svelte-autofixer`)
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Navegação `/app?a` → `/app?b` com o foco num elemento fora de `main` mantém o foco nele
- [x] Navegação `/app` → `/app/entrar` continua focando `main#conteudo`; testes antigos passam sem edição
- [x] Gate check passes: quick
- [x] Test count: anteriores + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-catalogo): manter o foco quando a navegação só muda a query`

---

### T12: `CardTile`

**What**: Componente do tile: `<li>` com link de página inteira para `/cards/<encodeURIComponent(card_number)>` (`rel="external"`, `data-sveltekit-reload`); arte `aspect-ratio: 5 / 7` com placeholder `aria-hidden` (nome e código) sempre por baixo e `<img alt="" loading="lazy">` por cima só com `image_url`; nome; `card_number` no estilo `code`; raridade da variante única ou "N impressões"; selo `role="img"` "1 cópia"/"N cópias" só com `signedIn` e soma de `owned_quantity` > 0.
**Where**: `frontend/src/lib/components/CardTile.svelte`
**Depends on**: T1
**Reuses**: `_card_tile.html.erb` e `catalog.css:214-330` como referência visual; tokens
**Requirement**: SCAT-03, SCAT-10, SCAT-11, SCAT-12, SCAT-13

**Tools**:

- MCP: `plugin:svelte` (`svelte-autofixer`)
- Skill: `superpowers:test-driven-development`, `svelte:svelte-code-writer`, `ecc:frontend-a11y`

**Done when**:

- [x] `href` é `/cards/OP01-001`; `card_number` com `#` ou `?` sai codificado (edge case)
- [x] Placeholder presente com e sem `image_url`; sem `image_url` não há `<img>`; o evento `error` da imagem não troca nenhum elemento nem classe (SCAT-11)
- [x] Uma variante com raridade "SR" mostra "SR"; com `rarity` `null` não mostra texto de raridade; três variantes mostram "3 impressões" (SCAT-12)
- [x] Selo "3 cópias" com sessão e soma 3; "1 cópia" com soma 1; sem selo com soma 0, com `owned_quantity` `null` ou sem sessão; nenhum botão no tile (SCAT-13)
- [x] `guard.test.ts` verde
- [x] Gate check passes: quick
- [x] Test count: anteriores + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-catalogo): criar o tile de carta com placeholder e selo de posse`

---

### T13: `CardTileSkeleton`

**What**: Tile esqueleto com o mesmo contorno do `CardTile` (arte 5/7 e duas linhas de texto), `aria-hidden`, pulso só em `opacity` com `--duration-slow`, parado pelo corte de movimento reduzido do `base.css`.
**Where**: `frontend/src/lib/components/CardTileSkeleton.svelte`
**Depends on**: T12
**Reuses**: medidas do `CardTile`
**Requirement**: SCAT-38

**Tools**:

- MCP: `plugin:svelte` (`svelte-autofixer`)
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] O componente renderiza com `aria-hidden="true"` e sem texto lido
- [x] `guard.test.ts` verde (só `opacity` animada, sem px de token nem hex)
- [x] Gate check passes: quick
- [x] Test count: anteriores + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-catalogo): criar o tile esqueleto da grade`

---

### T14: `FilterChip`

**What**: Chip como link com `data-sveltekit-reset="false"`, altura mínima `--touch-target`; ativo com anel sólido de 2px em `accent`, `×` `aria-hidden` e `aria-label` = `removeName`; `current` com `aria-current="true"` sem `×`; `swatch` com quadrado neutro em `border-strong`, sem preencher com `accent`.
**Where**: `frontend/src/lib/components/FilterChip.svelte`
**Depends on**: None
**Reuses**: tokens; estilos de chip de `catalog.css` como referência
**Requirement**: SCAT-19, SCAT-20, SCAT-21, SCAT-22, SCAT-25

**Tools**:

- MCP: `plugin:svelte` (`svelte-autofixer`)
- Skill: `superpowers:test-driven-development`, `ecc:frontend-a11y`

**Done when**:

- [x] Inativo: link com o `href` dado, nome acessível = rótulo, sem `×`
- [x] Ativo: nome acessível "Remover filtro Cor: Red", `×` com `aria-hidden`, rótulo escrito visível (SCAT-20)
- [x] `current`: `aria-current="true"` e sem `×` (SCAT-25)
- [x] Todo chip tem `data-sveltekit-reset="false"`; `guard.test.ts` verde (sem hex de cor do jogo, SCAT-21)
- [x] Gate check passes: quick
- [x] Test count: anteriores + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-catalogo): criar o chip de filtro`

---

### T15: `CatalogSearch`

**What**: `<form role="search">` com rótulo visível "Buscar por nome ou card_number", `type="search"`, placeholder "OP01-024", botão "Buscar" (o `Button` da fundação), alvos de 44px; o campo segue a prop `value` quando ela muda; o envio chama `onsearch(term)` sem recarregar.
**Where**: `frontend/src/lib/components/CatalogSearch.svelte`
**Depends on**: None
**Reuses**: `Button.svelte`; padrão de formulário de `TextField.svelte`
**Requirement**: SCAT-15, SCAT-16, SCAT-17

**Tools**:

- MCP: `plugin:svelte` (`svelte-autofixer`)
- Skill: `superpowers:test-driven-development`, `svelte:svelte-core-bestpractices`

**Done when**:

- [x] Campo encontrado pelo rótulo exato, com placeholder e `type="search"`; botão "Buscar"
- [x] Enviar "  zoro " chama `onsearch` com o texto digitado (o `trim` é do `searchHref`) e previne o envio nativo
- [x] Trocar a prop `value` de "zoro" para "" esvazia o campo (SCAT-17, voltar/avançar)
- [x] Gate check passes: quick
- [x] Test count: anteriores + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-catalogo): criar o campo de busca do catálogo`

---

### T16: `CatalogStatus`

**What**: Linha de status: `<p tabindex="-1">` com "N cartas" (singular "1 carta") e " · M filtros ativos" (singular "1 filtro ativo") quando M > 0; à direita, "Limpar filtros" quando há `clearHref`, e "Entrar para registrar posse" quando há `signInHref`.
**Where**: `frontend/src/lib/components/CatalogStatus.svelte`
**Depends on**: None
**Reuses**: tokens
**Requirement**: SCAT-29, SCAT-30, SCAT-31

**Tools**:

- MCP: `plugin:svelte` (`svelte-autofixer`)
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] `total` 2815 e `chipCount` 0 → "2815 cartas"; 1 e 1 → "1 carta · 1 filtro ativo"; 30 e 3 → "30 cartas · 3 filtros ativos"
- [x] Os links aparecem só com as props, com o `href` dado; "Limpar filtros" tem `data-sveltekit-reset="false"`
- [x] O parágrafo da frase é focável por script (`tabindex="-1"`)
- [x] Gate check passes: quick
- [x] Test count: anteriores + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-catalogo): criar a linha de status do catálogo`

---

### T17: `ActiveFilters`

**What**: `<ul aria-label="Filtros ativos">` com um `FilterChip` ativo por `Chip`, num `{#each}` com chave `key + value`, chamando `onremove(index)` no clique antes da navegação.
**Where**: `frontend/src/lib/components/ActiveFilters.svelte`
**Depends on**: T5, T14
**Reuses**: `FilterChip` (T14), `Chip` (T5)
**Requirement**: SCAT-28, SCAT-42

**Tools**:

- MCP: `plugin:svelte` (`svelte-autofixer`)
- Skill: `superpowers:test-driven-development`, `ecc:frontend-a11y`

**Done when**:

- [x] Três chips viram três links na lista "Filtros ativos", com nome "Remover filtro <rótulo>: <valor>" e o `href` do chip
- [x] Clicar o segundo chama `onremove(1)`
- [x] Lista vazia não renderiza a `<ul>`
- [x] Gate check passes: quick
- [x] Test count: anteriores + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-catalogo): listar os filtros ativos como chips removíveis`

---

### T18: `CatalogPagination`

**What**: `<nav aria-label="Paginação do catálogo">` só com `total_pages > 1`; "Anterior" (`rel="prev"`) com `page > 1`, "Página X de Y", "Próxima" (`rel="next"`) com `page < total_pages`; links de `pageHref` com `data-sveltekit-reset="false"` e `onclick` que chama `onpage()`.
**Where**: `frontend/src/lib/components/CatalogPagination.svelte`
**Depends on**: T4
**Reuses**: `pageHref` (T4)
**Requirement**: SCAT-36, SCAT-43

**Tools**:

- MCP: `plugin:svelte` (`svelte-autofixer`)
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Página 1 de 3: sem "Anterior", "Página 1 de 3", "Próxima" com `page=2` e os filtros ativos
- [x] Página 2 de 3: os dois links; página 3 de 3: só "Anterior"; `total_pages` 1: nada renderizado
- [x] Página 5 com `total_pages` 3 (além da última): "Anterior" presente (edge case)
- [x] Clique chama `onpage()`
- [x] Gate check passes: quick
- [x] Test count: anteriores + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-catalogo): criar a paginação do catálogo`

---

### T19: `FilterPanel`

**What**: Painel com grupos Cor (chips com `swatch`), Tipo (rótulo com inicial maiúscula, valor cru na URL), Raridade, Set (`<form>` com `<select>` "Set", opções "Todos os sets", "N sets selecionados" quando há mais de um set ativo, e os sets pelo nome; botão "Aplicar" que chama `goto(setHref(...), { reset: false })`) e Posse ("Todas", "Tenho", "Não tenho", só com `signedIn`); lê `filterOptions` e chama `ensureFilterOptions` ao montar; com erro, mostra a `message` e "Tentar novamente" no lugar dos grupos.
**Where**: `frontend/src/lib/components/FilterPanel.svelte`
**Depends on**: T4, T9, T14
**Reuses**: `FilterChip` (T14), `toggleHref`/`setHref` (T4), `filterOptions` (T9), `Button`
**Requirement**: SCAT-18, SCAT-21, SCAT-22, SCAT-23, SCAT-24, SCAT-25, SCAT-26, SCAT-40

**Tools**:

- MCP: `plugin:svelte` (`svelte-autofixer`, `get-documentation` de `goto` no Kit 3)
- Skill: `superpowers:test-driven-development`, `svelte:svelte-code-writer`, `ecc:frontend-a11y`

**Done when**:

- [x] Chips de cor, tipo e raridade na ordem das opções; tipo "CHARACTER" exibido "Character" com `card_types%5B%5D=CHARACTER` no `href` (SCAT-18)
- [x] Chip ativo em `colors` leva ao `href` sem o valor; inativo, com o valor acrescentado (SCAT-19)
- [x] Seletor: um set ativo vem selecionado; dois sets ativos mostram "2 sets selecionados" selecionado, e "Aplicar" com ela chama `goto` com os sets intactos e sem `page`; "Todos os sets" remove `sets` (SCAT-23, 24)
- [x] `goto` recebe `{ reset: false }`
- [x] Com `signedIn`: três chips de posse, "Todas" com `aria-current="true"` sem filtro; sem `signedIn`: nenhum controle de posse (SCAT-25, 26)
- [x] Falha das opções: `message` e "Tentar novamente", que chama `retryFilterOptions` (SCAT-40)
- [x] Gate check passes: quick
- [x] Test count: anteriores + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-catalogo): criar o painel de filtros`

---

### T20: Página do catálogo — consulta, grade, estados e anúncio

**What**: Reescrever `src/routes/+page.svelte` como o catálogo: título "Catálogo — Bindr", `<h1>Catálogo</h1>`; `$effect` que lê `page.url.search` e `session.user?.email` e chama `loader.load`; cabeçalho com `CatalogSearch` (busca por `goto(searchHref(...), { reset: false })`) e `CatalogStatus` na mesma linha a partir de 64rem; `ActiveFilters`; região `<section aria-busy>` com skeleton (dez `CardTileSkeleton` e "Carregando cartas…"), erro (`message` + "Tentar novamente"), vazio (com e sem `q`, "Limpar filtros" só com filtro ativo) ou grade de `CardTile` (2 colunas, 5 a partir de 64rem) com `CatalogPagination`; região `visually-hidden` `role="status"` regravada a cada `seq` depois de `tick()`. `page.test.ts` reescrito: os testes do início da fundação saem por decisão do spec (SCAT-01).
**Where**: `frontend/src/routes/+page.svelte`
**Depends on**: T3, T6, T8, T12, T13, T15, T16, T17, T18
**Reuses**: `createCatalogLoader` (T8), `api.getEnvelope` (T1), componentes T12–T18, `safeReturnTo` para o convite, mocks de `$app/state` e `$app/navigation` de `criar-conta/page.test.ts`
**Requirement**: SCAT-01, SCAT-04, SCAT-07, SCAT-09, SCAT-14, SCAT-17, SCAT-29, SCAT-30, SCAT-31, SCAT-32, SCAT-37, SCAT-38, SCAT-39, SCAT-44

**Tools**:

- MCP: `plugin:svelte` (`svelte-autofixer`)
- Skill: `superpowers:test-driven-development`, `svelte:svelte-code-writer`, `ecc:frontend-a11y`

**Done when**:

- [x] Título e `<h1>` exatos; nenhum resto da página de início (e-mail, links "Entrar"/"Criar conta" em `main`) (SCAT-01)
- [x] Com cliente falso: abrir em `/app?colors%5B%5D=Red` chama `/api/catalog?colors%5B%5D=Red`; trocar `page.url` refaz a consulta e mostra o termo novo no campo (SCAT-04, 07, 17)
- [x] Trocar `session.user` com a URL igual refaz a consulta (SCAT-09)
- [x] Vazio com `q` "zoro": "Nenhuma carta encontrada para zoro." com o termo em destaque; sem `q` e sem filtro: "Nenhuma carta corresponde aos filtros aplicados." sem "Limpar filtros"; com filtro: com "Limpar filtros" (SCAT-37)
- [x] Skeleton: dez tiles esqueleto, `aria-busy="true"` e "Carregando cartas…" depois de 200 ms; erro: `message` e "Tentar novamente", que refaz a consulta, com busca e filtros ainda presentes (SCAT-38, 39)
- [x] Sem sessão, "Entrar para registrar posse" leva a `/app/entrar?return_to=` com o caminho e a query atuais codificados (SCAT-31)
- [x] A região `role="status"` recebe a frase da linha de status a cada resposta, inclusive com frase igual à anterior, e a `message` em erro (SCAT-44)
- [x] Gate check passes: quick
- [x] Test count: anteriores − os 4 testes do início da fundação + novos

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-catalogo): trocar o início da SPA pelo catálogo em /app`

---

### T21: Página do catálogo — painel e foco pendente

**What**: Na página, o snippet do `FilterPanel` vai para `shell.aside` num `$effect` com limpeza a partir de 64rem e, abaixo disso, para um `<details>` "Filtros" acima da grade (com "M filtros ativos" quando M > 0), com `open` em `$state` e `bind:open`; `ActiveFilters` fica fora do `<details>`. Foco pendente: remover chip grava `{ chip, index }` e paginar grava `{ status }`; num `$effect` sobre `seq`, depois de `tick()`, foca o chip `index`, ou o `index − 1`, ou a linha de status.
**Where**: `frontend/src/routes/+page.svelte`
**Depends on**: T2, T10, T11, T19, T20
**Reuses**: `shell`/`wide` (T10), `FilterPanel` (T19)
**Requirement**: SCAT-33, SCAT-34, SCAT-35, SCAT-41, SCAT-42, SCAT-43

**Tools**:

- MCP: `plugin:svelte` (`svelte-autofixer`)
- Skill: `superpowers:test-driven-development`, `ecc:frontend-a11y`

**Done when**:

- [x] Com `matchMedia` casando, o painel é renderizado no slot do casco e não há `<details>`; sem casar, há `<details>` "Filtros" fechado na carga, com "2 filtros ativos" no resumo quando há dois chips, e a lista "Filtros ativos" visível fora dele (SCAT-33, 34)
- [x] Abrir o `<details>` e trocar `page.url` (só query) mantém o painel aberto; nunca há duas instâncias do painel (SCAT-35)
- [x] Remover o 2º de 3 chips foca o novo 2º; remover o último de 2 foca o anterior; remover o único foca a linha de status; "Próxima" foca a linha de status (SCAT-42, 43)
- [x] Desmontar a página zera `shell.aside`
- [x] Gate check passes: quick
- [x] Test count: anteriores + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-catalogo): dispor os filtros e devolver o foco depois de remover ou paginar`

---

### T22: E2E da fundação com o catálogo em `/app`

**What**: Em `e2e/sessao.spec.ts`, trocar o sinal de sessão (o e-mail em `main`) pela entrada "Sair" da navegação e a ausência dela pela presença de "Entrar"; demais asserções da jornada intactas. Conferir `e2e/casco.spec.ts` com o catálogo em `/app` e ajustar só o que dependia da página de início.
**Where**: `frontend/e2e/sessao.spec.ts`
**Depends on**: T21
**Reuses**: helpers de `sessao.spec.ts` e `casco.spec.ts`
**Requirement**: SCAT-01

**Tools**:

- MCP: NONE
- Skill: `ecc:e2e-testing`

**Done when**:

- [x] Nenhuma asserção procura o e-mail em `main`; com sessão, "Sair" está na navegação; sem sessão, "Entrar"
- [x] `casco.spec.ts` e `sessao.spec.ts` verdes contra a API real, nas combinações de largura e tema já existentes
- [x] Gate check passes: full
- [x] Test count: e2e anteriores, nenhum removido

**Tests**: e2e
**Gate**: full

**Commit**: `test(spa-catalogo): conferir a sessão pela navegação no e2e da fundação`

---

### T23: E2E de paridade `/app?…` × `/catalog?…`

**What**: `e2e/catalogo.spec.ts`: para cada query (busca `OP01-024`, `colors[]=Red&colors[]=Green`, um set, `cost_min`/`cost_max`, `sort=name&dir=desc`, `page=2`), ler na mesma execução os `card_number` e o total de `/catalog?<query>` e de `/app?<query>` e comparar nomes, ordem e contagem; a 360px e a 1280px, nos dois temas, sem scroll horizontal; cinco colunas a 1280px; busca por `OP01-024` com a carta exata em primeiro; região de anúncio não visível.
**Where**: `frontend/e2e/catalogo.spec.ts`
**Depends on**: T22
**Reuses**: helpers de largura e tema de `casco.spec.ts`
**Requirement**: SCAT-05, SCAT-14, SCAT-16, SCAT-27, SCAT-36

**Tools**:

- MCP: `playwright` (depuração local, se preciso)
- Skill: `ecc:e2e-testing`

**Done when**:

- [x] Cada query dá a mesma lista de `card_number` na mesma ordem e o mesmo total nas duas telas (sem catálogo importado, vazio bate com vazio)
- [x] `scrollWidth <= clientWidth` a 360px e cinco colunas a 1280px, nos dois temas (SCAT-14)
- [x] Gate check passes: full
- [x] Test count: e2e anteriores + novos

**Tests**: e2e
**Gate**: full

**Commit**: `test(spa-catalogo): comparar /app e /catalog na mesma query`

---

### T24: E2E de interação do catálogo

**What**: `e2e/catalogo-interacao.spec.ts`: teclado (Tab até "Red", Enter, foco segue em "Red", URL muda sem recarregar; remover o único chip ativo leva o foco à linha de status; "Próxima" também); 360px (painel fechado na carga, chip ativo visível, painel segue aberto depois de um chip); 1280px (filtros na coluna lateral abaixo da navegação); voltar e avançar restauram resultado e termo; com sessão, "Tenho" e o selo aparecem e, depois de "Sair", somem sem recarregar; o convite leva a `/app/entrar?return_to=…` e o login volta à mesma query.
**Where**: `frontend/e2e/catalogo-interacao.spec.ts`
**Depends on**: T23
**Reuses**: `signIn` e o marcador de "mesma página" dos e2e da fundação
**Requirement**: SCAT-07, SCAT-09, SCAT-13, SCAT-25, SCAT-26, SCAT-31, SCAT-33, SCAT-34, SCAT-35, SCAT-41, SCAT-42, SCAT-43, SCAT-44

**Tools**:

- MCP: `playwright` (depuração local, se preciso)
- Skill: `ecc:e2e-testing`, `ecc:frontend-a11y`

**Done when**:

- [x] Cada jornada acima verde contra a API real, com o marcador provando que a página não recarregou
- [x] Gate check passes: full
- [x] Test count: e2e anteriores + novos

**Tests**: e2e
**Gate**: full

**Commit**: `test(spa-catalogo): provar foco, painel, sessão e histórico no catálogo`

---

### T25: Fechamento

**What**: Atualizar o estado no `CLAUDE.md` (catálogo em `/app`, componentes, armadilhas novas: `reset: false`, slot `shell.aside`), o *Handoff* do `.specs/STATE.md`, a rastreabilidade do `spec.md` e o §13 do `.context/tasks.md`; conferir que nenhum arquivo sob `app/` mudou desde `751e553` e que a suíte Rails passa sem edição.
**Where**: `CLAUDE.md`
**Depends on**: T7, T24
**Reuses**: fechamento da `spa-fundacao` (T22 dela)
**Requirement**: SCAT-45

**Tools**:

- MCP: NONE
- Skill: `superpowers:verification-before-completion`

**Done when**:

- [x] `git diff --stat 751e553..HEAD -- app/` vazio (SCAT-45)
- [x] `validate_spec.py` e `validate_tasks.py` da feature saem 0
- [x] Gate check passes: build

**Tests**: none
**Gate**: build

**Commit**: `docs(spa-catalogo): documentar o catálogo na SPA e fechar o plano`

---

### T26: E2E de layout dos ACs de dimensão e posição (G1)

**What**: `e2e/catalogo-layout.spec.ts` contra a API real, nos quatro combos de largura e tema onde couber: (a) `boundingBox().height >= 44` de cada chip do painel e dos ativos, do `select` "Set", de "Aplicar", "Buscar" e do campo de busca; (b) chip ativo com largura de borda de 2px e cor igual a `--accent` (`getComputedStyle`); (c) selo de posse com `right` e `top` do canto superior direito da arte (tolerância de `--space-2`); (d) a 1280px a linha de status na mesma linha do campo de busca (`status.y` ≈ `search.y`) com "Limpar filtros" à direita, e a 360px empilhados; (e) para uma `img` com `naturalWidth === 0` (a pilha real tem imagens 502), o placeholder visível e `getComputedStyle(img).backgroundColor` transparente.
**Where**: `frontend/e2e/catalogo-layout.spec.ts`
**Depends on**: T25
**Reuses**: helpers de largura e tema de `casco.spec.ts`; `signIn` e o fluxo de posse de `catalogo-interacao.spec.ts`
**Requirement**: SCAT-10, SCAT-11, SCAT-13, SCAT-15, SCAT-20, SCAT-22, SCAT-30, SCAT-32

**Tools**:

- MCP: `playwright` (depuração local, se preciso)
- Skill: `ecc:e2e-testing`

**Done when**:

- [x] Cada AC de dimensão e posição acima tem asserção numérica ou de estilo computado (`toBeGreaterThanOrEqual(44)`, `'2px'`, posição do canto, `y` da mesma linha)
- [x] Reexecutados na cópia isolada, os mutantes C01 (remove `min-block-size` do chip), C02 (anel de 1px), C03 (selo no canto esquerdo), C05 (toolbar em coluna a partir de 64rem) e C06 (`.image` opaca) morrem
- [x] Gate check passes: full
- [x] Test count: e2e anteriores + novos, nenhum removido

**Tests**: e2e
**Gate**: full

**Commit**: `test(spa-catalogo): provar alvos, anel, selo e linha de status por e2e de layout`

---

### T27: E2E residuais: paridade nos quatro combos, três chips por teclado e altura da sessão (G2, G3, G5)

**What**: Em `catalogo.spec.ts`, rodar os testes de paridade nos quatro combos de largura e tema (não só 1280×720 claro). Em `catalogo-interacao.spec.ts`, aplicar três chips de cor seguidos pelo teclado (`tabTo(Red)` + Enter, esperar o chip ativo, `Green`, `Blue`), afirmando `colors[]` com três valores, o foco ainda no painel e a região de anúncio com "1 filtro ativo", "2 filtros ativos" e "3 filtros ativos". Em `sessao.spec.ts`, esperar `section[aria-busy="false"]` antes de medir e voltar a comparar a caixa inteira de `main` na prova do SPA-46.
**Where**: `frontend/e2e/catalogo-interacao.spec.ts`
**Depends on**: T26
**Reuses**: `tabTo` e `spaAnnouncement` dos próprios specs
**Requirement**: SCAT-41, SCAT-44

**Tools**:

- MCP: `playwright` (depuração local, se preciso)
- Skill: `ecc:e2e-testing`

**Done when**:

- [x] A paridade `/app` × `/catalog` passa nos quatro combos
- [x] Três chips seguidos pelo teclado dão `colors[]` com três valores, foco no painel e anúncio a cada resposta
- [x] A prova do SPA-46 compara a caixa inteira de `main` depois de a grade estabilizar
- [x] Gate check passes: full
- [x] Test count: e2e anteriores + novos, nenhum removido

**Tests**: e2e
**Gate**: full

**Commit**: `test(spa-catalogo): cobrir paridade nos combos e três chips seguidos por teclado`

---

### T28: Página com falha das opções de filtro e grade intacta (G4)

**What**: Em `page.test.ts`, montar a página com `filterOptions.error` setado e afirmar que o tile, a frase de status, a lista "Filtros ativos" e a `message` com "Tentar novamente" no painel coexistem.
**Where**: `frontend/src/routes/page.test.ts`
**Depends on**: T25
**Reuses**: mocks e `envelope` de `page.test.ts`; `filterOptions` de `filter-options.svelte.ts`
**Requirement**: SCAT-40

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Com a falha das opções, a grade, a linha de status e os filtros ativos seguem renderizados e o painel mostra a `message` e "Tentar novamente"
- [x] Gate check passes: quick
- [x] Test count: anteriores + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `test(spa-catalogo): provar a grade intacta quando as opções de filtro falham`

---

## Phase Execution Map

Phase 1 → Phase 2 → Phase 3 → Phase 4, em série; dentro de cada phase, as tasks rodam na ordem numérica.

| Phase | Tasks |
| ----- | ----- |
| 1 | T1, T2, T3, T4, T5, T6, T7 |
| 2 | T8, T9, T10, T11, T12, T13 |
| 3 | T14, T15, T16, T17, T18, T19 |
| 4 | T20, T21, T22, T23, T24, T25 |
| 5 | T26, T27, T28 |

Lotes de ~7 tasks em phases inteiras: **A** = Phase 1 (T1–T7), **B** = Phase 2 (T8–T13), **C** = Phase 3 (T14–T19), **D** = Phase 4 (T20–T25). Os lotes rodam em série.

---

## Task Granularity Check

| Task | Scope | Status |
| ---- | ----- | ------ |
| T1: Tipos + `getEnvelope` | 1 método do cliente + os tipos que ele devolve | ⚠️ Coeso (tipo sem consumidor não tem teste) |
| T2: `safeReturnTo` | 1 função | ✅ Granular |
| T3: Entrada "Catálogo" | 1 função (+ emenda de teste do `MainNav`) | ✅ Granular |
| T4: Links do catálogo | 7 funções puras do mesmo módulo, mesma regra | ⚠️ Coeso (porta de um helper) |
| T5: Chips ativos | 1 função + 1 mapa | ✅ Granular |
| T6: `visually-hidden` | 1 regra CSS | ✅ Granular |
| T7: View Transition | 1 função | ✅ Granular |
| T8: Carregador | 1 módulo de estado | ✅ Granular |
| T9: Opções de filtro | 1 módulo de estado | ✅ Granular |
| T10: Slot lateral | 1 módulo de estado + o ponto de render no casco | ⚠️ Coeso (um sem o outro não renderiza) |
| T11: Foco no layout | 1 callback | ✅ Granular |
| T12: `CardTile` | 1 componente | ✅ Granular |
| T13: `CardTileSkeleton` | 1 componente | ✅ Granular |
| T14: `FilterChip` | 1 componente | ✅ Granular |
| T15: `CatalogSearch` | 1 componente | ✅ Granular |
| T16: `CatalogStatus` | 1 componente | ✅ Granular |
| T17: `ActiveFilters` | 1 componente | ✅ Granular |
| T18: `CatalogPagination` | 1 componente | ✅ Granular |
| T19: `FilterPanel` | 1 componente | ✅ Granular |
| T20: Página — consulta e estados | 1 rota (+ reescrita do teste dela) | ✅ Granular |
| T21: Página — painel e foco | 1 rota, segunda camada | ✅ Granular |
| T22: E2E da fundação | 1 spec (conferência do outro) | ✅ Granular |
| T23: E2E de paridade | 1 spec | ✅ Granular |
| T24: E2E de interação | 1 spec | ✅ Granular |
| T25: Fechamento | docs | ✅ Granular |
| T26: E2E de layout | 1 spec | ✅ Granular |
| T27: E2E residuais | 3 emendas de spec do mesmo tema | ⚠️ Coeso (mesma jornada de e2e) |
| T28: Página com opções falhando | 1 teste | ✅ Granular |

---

## Diagram-Definition Cross-Check

| Task | Depends On (task body) | Diagram Shows | Status |
| ---- | ---------------------- | ------------- | ------ |
| T1 | None | — | ✅ Match |
| T2 | None | — | ✅ Match |
| T3 | None | — | ✅ Match |
| T4 | T1 | T1 → T4 | ✅ Match |
| T5 | T4 | T4 → T5 | ✅ Match |
| T6 | None | — | ✅ Match |
| T7 | None | — | ✅ Match |
| T8 | T1 | T1 → T8 | ✅ Match |
| T9 | T1 | T1 → T9 | ✅ Match |
| T10 | None | — | ✅ Match |
| T11 | None | — | ✅ Match |
| T12 | T1 | T1 → T12 | ✅ Match |
| T13 | T12 | T12 → T13 | ✅ Match |
| T14 | None | — | ✅ Match |
| T15 | None | — | ✅ Match |
| T16 | None | — | ✅ Match |
| T17 | T5, T14 | T5 → T17, T14 → T17 | ✅ Match |
| T18 | T4 | T4 → T18 | ✅ Match |
| T19 | T4, T9, T14 | T4 → T19, T9 → T19, T14 → T19 | ✅ Match |
| T20 | T3, T6, T8, T12, T13, T15, T16, T17, T18 | as nove setas para T20 | ✅ Match |
| T21 | T2, T10, T11, T19, T20 | T2, T10, T11, T19, T20 → T21 | ✅ Match |
| T22 | T21 | T21 → T22 | ✅ Match |
| T23 | T22 | T22 → T23 | ✅ Match |
| T24 | T23 | T23 → T24 | ✅ Match |
| T25 | T7, T24 | T7 → T25, T24 → T25 | ✅ Match |
| T26 | T25 | T25 → T26 | ✅ Match |
| T27 | T26 | T26 → T27 | ✅ Match |
| T28 | T25 | T25 → T28 | ✅ Match |

---

## Test Co-location Validation

| Task | Code Layer Created/Modified | Matrix Requires | Task Says | Status |
| ---- | --------------------------- | --------------- | --------- | ------ |
| T1: `getEnvelope` | Cliente HTTP | unit | unit | ✅ OK |
| T2: `safeReturnTo` | Função pura | unit | unit | ✅ OK |
| T3: Navegação | Função pura + componente | unit | unit | ✅ OK |
| T4: Links | Função pura | unit | unit | ✅ OK |
| T5: Chips ativos | Função pura | unit | unit | ✅ OK |
| T6: `visually-hidden` | CSS global | unit | unit | ✅ OK |
| T7: View Transition | Função pura | unit | unit | ✅ OK |
| T8: Carregador | Estado | unit | unit | ✅ OK |
| T9: Opções | Estado | unit | unit | ✅ OK |
| T10: Slot lateral | Estado + componente | unit | unit | ✅ OK |
| T11: Layout | Componente/rota | unit | unit | ✅ OK |
| T12–T19: Componentes | Componentes | unit | unit | ✅ OK |
| T20: Página | Página | unit | unit | ✅ OK |
| T21: Página | Página | unit | unit | ✅ OK |
| T22: E2E da fundação | Jornada | e2e | e2e | ✅ OK |
| T23: E2E de paridade | Jornada | e2e | e2e | ✅ OK |
| T24: E2E de interação | Jornada | e2e | e2e | ✅ OK |
| T25: Fechamento | docs | none | none | ✅ OK |
| T26–T27: E2E | Jornada | e2e | e2e | ✅ OK |
| T28: Página | Página | unit | unit | ✅ OK |

---

## Plano de delegação

- **Lotes**: A (T1–T7), B (T8–T13), C (T14–T19), D (T20–T25), em série, cada um num worker que commita task a task e devolve o resumo compacto. Tier: A em médio (funções puras com teste exato), B em alto (token de sequência e timer), C em médio, D em alto (página, foco e e2e contra a API real). Workers sem `git stash` e sem nenhum git de escrita além de `add` e `commit` dos próprios arquivos; nunca tocar em `.specs/features/spa-carta/`, `.specs/features/spa-pasta/` nem em `.context/requirements.md`.
- **Revisão**: `ecc:typescript-reviewer` no cliente (T1), nos links (T4–T5) e no carregador (T8); `ecc:a11y-architect` em chip, painel, tile, linha de status, paginação e página (T12, T14, T16–T21: `aria-current`, `aria-live`, foco pendente, 44px); `ecc:pr-test-analyzer` nos testes do carregador (T8), da página (T20–T21) e nos e2e (T23–T24); `ecc:security-reviewer` no `safeReturnTo` (T2); `svelte:svelte-file-editor` / `svelte-autofixer` em todo `.svelte` e `.svelte.ts`.
- **Verifier** ao fim de T25, autor ≠ verificador, sensor de mutação em cópia isolada (worktree só com o aval do dono), nunca `git stash`.
