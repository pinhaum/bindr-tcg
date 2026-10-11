# Pasta e lista de desejos na SPA — Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Design**: `.specs/features/spa-pasta/design.md`
**Status**: Approved

**Pré-condição:** a `spa-carta` encerrada (T1–T22 commitadas e `validation.md` PASS). A
T1 só abre com a árvore limpa dos arquivos da `spa-carta`. O commit-pai da T1 é a
**base da feature** (`<base>` abaixo) e é registrado na própria T1.

---

## Test Coverage Matrix

> Generated from codebase, project guidelines, and spec - confirm before Execute. Guidelines found: `CLAUDE.md` (gates do front e do Rails, armadilhas do Kit 3, teste de CSRF com `allow_forgery_protection` ligado no `setup`, "toda task termina com código que roda e teste que passa", e2e exige o catálogo importado), `frontend/src/lib/styles/guard.test.ts` (hex, px de token e animação fora de `transform`/`opacity` reprovam), ESLint que proíbe `fetch` fora de `client.ts`. Amostras lidas: `test/integration/api/card_variants_wishlist_test.rb`, `test/integration/api/catalog_test.rb` (contagem de consultas), `test/queries/set_progress_query_test.rb`, `test/integration/wishlist_items_test.rb`, `frontend/src/lib/catalog/catalog.svelte.ts` e seu teste, `frontend/src/routes/page.test.ts`, `frontend/e2e/catalogo-layout.spec.ts`. O piso é o da `spa-carta`; o alvo vem dos ACs do spec (strong default).

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| ---------- | ------------------ | -------------------- | ---------------- | ----------- |
| Controller da API (`Api::ProgressController`, `Api::WishlistController`, `Api::CardVariantsController#unwish`) | integration (request test) | Cada endpoint: corpo exato do contrato; números iguais aos da consulta HTML para dois usuários; cada valor de `order` do SPAS-38; consultas constantes com N pequeno e grande; 401 sem sessão; 422 `invalid_csrf_token` com `allow_forgery_protection` ligado; `user_id` alheio ignorado; 404 da remoção; `400 invalid_json`; `variant_code` com `:` codificado; nunca HTML nem redirect | `test/integration/api/*_test.rb` (arquivos novos) | Rails quick |
| Funções puras (`motion.ts`, `cards/url.ts`, `navigation/*.ts`) | unit | Todos os ramos, 1:1 com os ACs da task; codificação de caracteres reservados | `frontend/src/lib/**/*.test.ts` | Front quick |
| Estado (`*.svelte.ts`) | unit | Com fetch falso, timer falso e promessas controladas: token de sequência, carga lenta após 200 ms, erro não-`ApiError` relançado, `retry` | `frontend/src/lib/**/*.test.ts` | Front quick |
| Componentes e páginas (`.svelte`) | unit (componente, jsdom) | Cada AC de tela: texto exato pt-BR com plurais 0/1/2, `href` exato, ARIA (`aria-current`, `aria-busy`, `aria-hidden`, `aria-label`), foco depois de `tick()`, estados de carga lenta e erro | `frontend/src/**/*.test.ts` | Front quick |
| Jornadas no navegador | e2e (Playwright contra a API real) | Paridade `/app/pasta?order=` × `/progress?order=` e `/app/pasta/desejos` × `/wishlist` para dois usuários; 360px e 1280px nos dois temas sem scroll horizontal; medidas de layout dos ACs; remoção persiste; reduced motion | `frontend/e2e/*.spec.ts` | e2e |
| Docs (`CLAUDE.md`, `STATE.md`, `.context/tasks.md`, specs) | none | - | - | build gate only |

## Gate Check Commands

> Generated from codebase - confirm before Execute. Rodar as suítes em série, nunca em paralelo (flake D-10). `npm ci` com o serviço `frontend` de pé troca o `node_modules` sob o Vite: parar o serviço antes do quick ou reiniciá-lo depois. O e2e exige o catálogo importado no banco de dev (`ingestion:import SNAPSHOT=…`). Se o pull de imagem falhar pelo `credsStore` do host, `export DOCKER_CONFIG=$(mktemp -d)` com `{}` em `config.json`.

| Gate Level | When to Use | Command |
| ---------- | ----------- | ------- |
| Rails quick | Tasks do Rails | `docker compose exec app bin/rails test test/models test/integration && docker compose exec app bin/rubocop` |
| Front quick | Tasks do front com teste de unidade | `docker compose run --rm --no-deps frontend sh -c "npm ci && npm run check && npm run lint && npm test -- --run"` |
| Full | Tasks e2e e a última task do Rails | Front quick + `docker compose up -d app frontend && docker compose --profile e2e run --rm e2e` + `docker compose exec app bin/rails test` |
| Build | Fechamento | `docker build -f Dockerfile .` + Full + `docker compose exec app bin/rubocop` + `docker compose exec app bin/brakeman` + `git diff --name-status <base>..HEAD -- test/` só com `A` e `git diff --stat <base>..HEAD -- app/views/progress app/views/wishlist_items app/controllers/progress_controller.rb app/controllers/wishlist_items_controller.rb` vazio (SPAS-46) |

---

## Execution Plan

Phases are ordered and run sequentially - each phase completes before the next begins, and tasks within a phase execute in order. Cada diagrama traz todas as dependências das tasks da phase, inclusive as que vêm de phases anteriores.

### Phase 1: API da pasta e da lista de desejos (Rails)

```
T1 → T2
T2 → T3
```

### Phase 2: Funções puras, estado e navegação do front

T4, T5, T6, T7 e T8 não dependem de nada.

### Phase 3: Componentes

```
T6 → T9
T4 → T10
T9 → T10
T4 → T11
T4 → T12
```

### Phase 4: Páginas, ponta a ponta e fechamento

```
T4 → T13
T5 → T13
T8 → T13
T10 → T13
T11 → T13
T4 → T14
T5 → T14
T7 → T14
T12 → T14
T13 → T14
T1 → T15
T13 → T15
T14 → T15
T2 → T16
T3 → T16
T15 → T16
T16 → T17
```

---

## Task Breakdown

### T1: `GET /api/progress`

**What**: Criar `Api::ProgressController#show`, a view `progress/show.json.jbuilder` e a rota `get "progress"` no `scope "api"`, acima do catch-all, devolvendo `{ data: { order, summary, sets } }` a partir de `SetProgressQuery` e `CollectionItem.collection_stats_for`, com `base_size` nulo para ausente ou zero, `completion_percent` inteiro e `value` por set. Registrar na task o hash do commit-pai (base da feature).
**Where**: `app/controllers/api/progress_controller.rb`
**Depends on**: None
**Reuses**: `SetProgressQuery` (`order`, `Row#displayed_owned_numbers`, `#completion_percent_known?`), `CollectionItem.collection_stats_for` (`value_by_set_id`), formato `"%.2f"` de `app/views/api/cards/_price.json.jbuilder`, helpers de sessão e CSRF de `test/integration/api/card_variants_wishlist_test.rb`
**Requirement**: SPAS-37, SPAS-38, SPAS-39, SPAS-40, SPAS-41, SPAS-45

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Request test: dois usuários com coleções diferentes recebem `summary` igual a `collection_stats_for` de cada um e `sets` igual, linha a linha, a `SetProgressQuery` (code, name, `displayed_owned_numbers`, base, parallels), com `value` igual a `value_by_set_id` e `"0.00"` sem cópia com preço (SPAS-37, SPAS-39, SPAS-40)
- [x] `order` ausente, `xyz`, vazio e `order[]=code` → `order: "recent"` e `200`; `code` → `order: "code"` e a ordem por código (SPAS-38)
- [x] Set com `base_set_size` nulo e com zero → `base_size: null` e `completion_percent: null`; posse acima do `base_size` → `owned_numbers` igual ao `base_size` e `completion_percent: 100` (SPAS-40)
- [x] `completion_percent` igual ao inteiro que a página `/progress` renderiza para 1 de 8 (13) e 7 de 8 (88)
- [x] Preço em moeda diferente de `USD` fica fora de `estimated_value` e de `value`
- [x] Número de consultas SQL igual com 2 e com 20 sets e com 1 e 10 itens de coleção (SPAS-41)
- [x] Sem sessão → `401 unauthenticated`; `user_id` de outro usuário na query é ignorado; resposta `application/json`, nunca redirect (SPAS-45)
- [x] Gate check passes: Rails quick

**Tests**: integration
**Gate**: quick

**Commit**: `feat(spa-pasta): expor o progresso da pasta na API`


**Registro**: `<base>` da feature = `8e6c92d` (commit-pai da T1). Achados MINOR da revisão (moeda "USD" repetida em três lugares; `format` via Float; lacunas de cobertura de `order=code` com sets sem posse) registrados no relatório, sem correção.
---

### T2: `GET /api/wishlist`

**What**: Criar `Api::WishlistController#index`, a view `wishlist/index.json.jbuilder` e a rota `get "wishlist"` acima do catch-all, devolvendo os desejos do usuário da sessão com `card_number`, `card_name`, `variant_code`, `target_quantity`, `owned_quantity` e `fulfilled`.
**Where**: `app/controllers/api/wishlist_controller.rb`
**Depends on**: T1
**Reuses**: `WishlistItem.for_user(...).with_fulfillment`, `WishlistItem#fulfilled?`
**Requirement**: SPAS-42, SPAS-45

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Request test: itens na ordem de criação e id; atendido com 3 de 2 e 2 de 2; não atendido com 0 de 2 e `owned_quantity: 0` sem registro de coleção; lista vazia → `data: []` (SPAS-42)
- [x] A posse de outro usuário na mesma variante não entra em `owned_quantity`; desejos de outro usuário não aparecem; `user_id` alheio na query é ignorado (SPAS-45)
- [x] Número de consultas SQL igual com 1 e com 10 itens (SPAS-42)
- [x] Sem sessão → `401 unauthenticated`; resposta `application/json`, nunca redirect
- [x] Gate check passes: Rails quick

**Tests**: integration
**Gate**: quick

**Commit**: `feat(spa-pasta): expor a lista de desejos na API`


**Registro**: Achado MINOR da revisão (desempate por id sem teste de created_at igual) registrado no relatório, sem correção.
---

### T3: `DELETE /api/cards/:card_number/variants/:variant_code/wishlist`

**What**: Acrescentar a action `unwish` ao `Api::CardVariantsController` (com o `set_card_variant` existente), a view `unwish.json.jbuilder` com `{ data: { variant_code, wishlist_target: null } }` e a rota `delete` com as mesmas constraints do `put`, apagando por `WishlistItem.for_user(Current.user).where(card_variant:).delete_all`.
**Where**: `app/controllers/api/card_variants_controller.rb`
**Depends on**: T2
**Reuses**: `before_action :set_card_variant`, rota do `put …/wishlist` em `config/routes.rb`
**Requirement**: SPAS-43, SPAS-44, SPAS-45, SPAS-46

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [ ] Request test em arquivo novo: com desejo → `200` com o corpo exato e o registro apagado; sem desejo → o mesmo `200` sem apagar nada (SPAS-43, AD-027)
- [ ] O desejo de outro usuário na mesma variante continua gravado; `user_id` alheio no corpo e na query é ignorado (SPAS-45)
- [ ] Carta inexistente e `variant_code` de outra carta → `404 not_found` sem apagar (SPAS-44)
- [ ] `variant_code` `tcgplayer:123` enviado como `tcgplayer%3A123` é encontrado
- [ ] Sem sessão → `401`; sem `X-CSRF-Token` com `allow_forgery_protection` ligado → `422 invalid_csrf_token` sem apagar; corpo JSON malformado → `400 invalid_json`
- [ ] Gate check passes: Rails quick + `docker compose exec app bin/rails test` (suíte inteira sem edição, SPAS-46)

**Tests**: integration
**Gate**: full

**Commit**: `feat(spa-pasta): remover desejo por variante na API`

---

### T4: Carregador genérico e tipos da pasta

**What**: Criar `createLoader<T>(fetch, slowMs = 200)` com `{ state: { result, error, pending, slow, seq }, load(key), retry() }` e acrescentar `Money`, `ProgressSet`, `ProgressPayload` e `WishlistEntry` a `frontend/src/lib/api/types.ts`.
**Where**: `frontend/src/lib/api/loader.svelte.ts`
**Depends on**: None
**Reuses**: a forma de `frontend/src/lib/catalog/catalog.svelte.ts` (sem copiá-lo; abordagem A do design)
**Requirement**: SPAS-04, SPAS-05, SPAS-06, SPAS-07

**Tools**:

- MCP: NONE
- Skill: `svelte:svelte-code-writer`

**Done when**:

- [x] `load('?order=code')` chama `fetch('?order=code')`; `retry()` repete a última chave (SPAS-07)
- [x] `slow` só vira `true` depois de 200 ms pendentes; antes disso `result` anterior continua (SPAS-06)
- [x] Resposta de um `load` superado por outro não altera `state` (SPAS-05)
- [x] `ApiError` vai para `error` e zera `pending`/`slow`; erro que não é `ApiError` é relançado
- [x] `npm run check` aceita os tipos novos
- [x] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-pasta): carregador genérico com descarte e carga lenta`

---

### T5: Guarda de sessão `requireSession`

**What**: Criar `requireSession(url: URL)`, que com `session.user` nulo lança `redirect(307, '<base>/entrar?return_to=' + encodeURIComponent(url.pathname + url.search))`.
**Where**: `frontend/src/lib/navigation/require-session.ts`
**Depends on**: None
**Reuses**: padrão de `frontend/src/routes/entrar/+page.ts`, `resolve('/')`
**Requirement**: SPAS-03

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Sem usuário e URL `/app/pasta?order=code` → redirect 307 para `/app/entrar?return_to=%2Fapp%2Fpasta%3Forder%3Dcode` (SPAS-03)
- [x] Com usuário → não lança
- [x] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-pasta): exigir sessão antes de abrir a rota`

---

### T6: Curva `easeStandard`

**What**: Acrescentar a `motion.ts` `cubicBezier(x1, y1, x2, y2)` e `easeStandard = cubicBezier(0.2, 0, 0, 1)`, a curva de `--ease-standard` em JS.
**Where**: `frontend/src/lib/motion.ts`
**Depends on**: None
**Reuses**: `duration()` do mesmo arquivo
**Requirement**: SPAS-12

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] `easeStandard(0)` é 0, `easeStandard(1)` é 1 e a curva é monotônica em 0..1 (amostras a cada 0,05)
- [x] Valores em 0,25 e 0,5 batem com uma referência de `cubic-bezier(0.2, 0, 0, 1)` calculada no teste com tolerância de 0,001
- [x] O teste lê `--ease-standard` de `tokens.css` e confirma os quatro números usados
- [x] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-pasta): curva padrão de movimento em JS`

---

### T7: Caminho da remoção de desejo

**What**: Acrescentar `variantWishlistPath(cardNumber, variantCode)` a `cards/url.ts`, ou reusar o caminho do `PUT` se a `spa-carta` já o tiver criado (registrar qual na task).
**Where**: `frontend/src/lib/cards/url.ts`
**Depends on**: None
**Reuses**: `variantApiPath` e `cardDetailHref` do mesmo arquivo
**Requirement**: SPAS-30, SPAS-43

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] `variantWishlistPath('OP01-001', 'tcgplayer:1')` → `/api/cards/OP01-001/variants/tcgplayer%3A1/wishlist`; `card_number` com espaço e `/` codificados
- [x] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-pasta): montar o caminho da remoção de desejo`


**Registro**: Reusado `variantApiPath(card, variant, 'wishlist')` de `cards/url.ts`, que já serve ao `PUT`; `variantWishlistPath` não foi criado (a T14 usa `variantApiPath`).
---

### T8: "Minha pasta" na navegação da SPA

**What**: Trocar o destino Hotwire de "Minha pasta" em `navEntries` por `/app/pasta` sem recarga.
**Where**: `frontend/src/lib/navigation/nav-entries.ts`
**Depends on**: None
**Reuses**: `inApp`, `isCurrent` do `MainNav`
**Requirement**: SPAS-02

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Com usuário, "Minha pasta" é `{ href: '/app/pasta', reload: false }`
- [x] Teste do `MainNav`: `aria-current="page"` em "Minha pasta" com `page.url` `/app/pasta` e `/app/pasta?order=code`, e ausente em `/app/pasta/desejos` (SPAS-02)
- [x] Testes existentes do front que esperavam `/progress` atualizados para o novo destino (a suíte Rails não é tocada)
- [x] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-pasta): levar "Minha pasta" à rota da SPA`

---

### T9: `AnimatedNumber`

**What**: Criar o componente do número interpolado: `Tween` de 0 ao `value` em `duration(320)` com `easeStandard`, texto visível `aria-hidden` com algarismos tabulares, `finalText` em `.visually-hidden` sempre, e o texto final exato quando a animação termina.
**Where**: `frontend/src/lib/components/AnimatedNumber.svelte`
**Depends on**: T6
**Reuses**: `Tween` de `svelte/motion`, `duration()`, `easeStandard`
**Requirement**: SPAS-12, SPAS-13, SPAS-14, SPAS-15, SPAS-16

**Tools**:

- MCP: `plugin:svelte:svelte` (autofixer)
- Skill: `svelte:svelte-code-writer`

**Done when**:

- [ ] Primeiro passo registrado na task: qual relógio avança o `Tween` no jsdom (`vi.useFakeTimers` com `requestAnimationFrame` e `performance`, ou espera real com `vi.waitFor`)
- [ ] Aos 0 ms o visível é `0` e o acessível já é o `finalText`; aos 320 ms o visível é o `finalText` (SPAS-12, SPAS-15)
- [ ] Troca de `value` de 1000 para 1250 centavos anima de `US$ 10,00` a `US$ 12,50`; o mesmo `value` não produz quadro intermediário (SPAS-13)
- [ ] Com `prefersReducedMotion` verdadeiro, o primeiro quadro já é o final (SPAS-14)
- [ ] `amount` `"1234.56"` termina em `US$ 1.234,56` (SPAS-16)
- [ ] O visível tem `aria-hidden="true"`, nenhum elemento tem `aria-live` nem `role="status"`, e o estilo declara `font-variant-numeric: tabular-nums` (SPAS-15, SPAS-16)
- [ ] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-pasta): número interpolado dos indicadores`

---

### T10: `PastaSummary` (três indicadores)

**What**: Criar os três cartões de indicador sobre `summary`, na ordem cópias, cartas diferentes e valor estimado, com plurais, a nota de cópias sem preço e cada número num `AnimatedNumber`, numa grade de quatro colunas a partir de 64rem.
**Where**: `frontend/src/lib/components/PastaSummary.svelte`
**Depends on**: T4, T9
**Reuses**: `formatPrice`, `AnimatedNumber`, tokens de `tokens.css`
**Requirement**: SPAS-08, SPAS-09, SPAS-10, SPAS-11, SPAS-15

**Tools**:

- MCP: `plugin:svelte:svelte` (autofixer)
- Skill: `svelte:svelte-code-writer`

**Done when**:

- [ ] Rótulos com 0, 1 e 2: "cartas na pasta"/"carta na pasta"; "cartas diferentes"/"carta diferente"; "valor estimado" (SPAS-08)
- [ ] Nota "1 cópia sem preço" e "2 cópias sem preço"; ausente com zero (SPAS-09)
- [ ] `amount` `"0.00"` → `US$ 0,00` (SPAS-10)
- [ ] O texto acessível de cada cartão é o valor final seguido do rótulo (SPAS-15)
- [ ] CSS declara `grid-template-columns: repeat(4, 1fr)` a partir de `64rem` (a medida fica na T15)
- [ ] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-pasta): indicadores da pasta`

---

### T11: `SetProgressRow`

**What**: Criar a linha de set: `code` em estilo `code`, link do nome para `/app?sets[]=<code>` com o nome acessível do spec, números, barra `aria-hidden` e legenda com `base_size`, frase de indisponível sem ele, parallels num `<p>` irmão e o subtotal.
**Where**: `frontend/src/lib/components/SetProgressRow.svelte`
**Depends on**: T4
**Reuses**: `appPath`, `formatPrice`
**Requirement**: SPAS-19, SPAS-20, SPAS-21, SPAS-22, SPAS-23

**Tools**:

- MCP: `plugin:svelte:svelte` (autofixer)
- Skill: `svelte:svelte-code-writer`

**Done when**:

- [ ] Link `href` `/app?sets[]=OP01` com `aria-label` "Romance Dawn (OP01): ver no catálogo"; `code` com caractere reservado codificado (SPAS-19)
- [ ] Com `base_size`: "3 / 7 · 43%", `<progress aria-hidden="true" value="3" max="7">` e "3 de 7 do set base" (SPAS-20)
- [ ] Com `base_size` nulo: só `owned_numbers`, sem `<progress>` nem `%`, e a frase de indisponível; nem "0%" nem "100%" (SPAS-21)
- [ ] "1 de 1 parallel" e "0 de 2 parallels", num `<p>` que não está dentro do elemento do percentual (SPAS-22)
- [ ] "valor US$ 0,00" e "valor US$ 1.234,56" (SPAS-23)
- [ ] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-pasta): linha de progresso por set`

---

### T12: `WishlistItem`

**What**: Criar o item da lista de desejos: link `card_name` + `variant_code` para o detalhe da carta, "<owned> de <target> cópia(s)" com plural certo, "Atendido" ou "Faltam N", e o botão "Remover" de 44px com nome acessível, prop `pending` que o desabilita e callback `onremove`.
**Where**: `frontend/src/lib/components/WishlistItem.svelte`
**Depends on**: T4
**Reuses**: `cardDetailHref`, `Button`
**Requirement**: SPAS-30, SPAS-31, SPAS-32, SPAS-35

**Tools**:

- MCP: `plugin:svelte:svelte` (autofixer)
- Skill: `svelte:svelte-code-writer`

**Done when**:

- [ ] Link `href` `/app/cartas/OP01-001` (`card_number` reservado codificado) com o nome e o `variant_code` em `code` (SPAS-30)
- [ ] "1 de 1 cópia" e "0 de 2 cópias" (SPAS-30)
- [ ] 3 de 2 → "Atendido"; 0 de 2 → "Faltam 2" (SPAS-31)
- [ ] Nome acessível "Remover Luffy tcgplayer:1 da lista de desejos (atendido)" e "(faltam 2)"; alvo mínimo de 44px no CSS (SPAS-32)
- [ ] Com `pending`, o botão fica desabilitado e o clique não chama `onremove` (SPAS-35)
- [ ] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-pasta): item da lista de desejos`

---

### T13: Rota `/app/pasta`

**What**: Criar `routes/pasta/+page.ts` (`requireSession`) e `+page.svelte`: título e `h1`, carga por `createLoader` sobre `GET /api/progress` com o `order` da URL, carga lenta e erro, `PastaSummary`, "Progresso por set" com os chips de ordem marcados por `data.order` e a lista de `SetProgressRow`, ações secundárias e "Adicionar cartas" no `shell.aside` (AD-028) ou fixa abaixo de 64rem.
**Where**: `frontend/src/routes/pasta/+page.svelte`
**Depends on**: T4, T5, T8, T10, T11
**Reuses**: `api`, `createLoader`, `requireSession`, `shell`/`wide`, `data-sveltekit-reset="false"` dos chips da `spa-catalogo`, `Button`
**Requirement**: SPAS-01, SPAS-03, SPAS-04, SPAS-05, SPAS-06, SPAS-07, SPAS-17, SPAS-18, SPAS-24, SPAS-25

**Tools**:

- MCP: `plugin:svelte:svelte` (autofixer)
- Skill: `svelte:svelte-code-writer`

**Done when**:

- [ ] `load` sem sessão redireciona sem chamar o cliente; com sessão a página chama `get('/api/progress?order=code')` com a URL `?order=code` e `get('/api/progress')` sem `order` (SPAS-03, SPAS-04)
- [ ] `<title>` "Minha pasta — Bindr" e `h1` "Minha pasta" (SPAS-01)
- [ ] Resposta antiga descartada; "Carregando pasta…" e `aria-busy="true"` só após 200 ms; `500` mostra a `message` e "Tentar novamente", que repete a consulta (SPAS-05, SPAS-06, SPAS-07)
- [ ] Chips "Recentes" e "Por código" na lista "Ordenar sets", `aria-current="page"` no chip de `data.order = "recent"` com a URL `?order=xyz` (SPAS-17)
- [ ] Lista de sets nomeada por "Progresso por set", na ordem de `data.sets`, sem contagem (SPAS-18)
- [ ] Links "Baixar minha coleção (CSV)" `/collection/export` e "Importar coleção" `/collection/import` com `data-sveltekit-reload`; "Lista de desejos" `/app/pasta/desejos` e "Adicionar cartas à pasta" `/app` sem recarga (SPAS-24, SPAS-25)
- [ ] Com `wide` verdadeiro, `shell.aside` recebe a ação com o texto "Adicionar cartas"; ao desmontar, volta a `null` (SPAS-24, AD-028)
- [ ] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-pasta): pasta em /app/pasta`

---

### T14: Rota `/app/pasta/desejos`

**What**: Criar `routes/pasta/desejos/+page.ts` (`requireSession`) e `+page.svelte`: título e `h1`, carga por `createLoader` sobre `GET /api/wishlist`, lista vazia, contagem, `WishlistItem` por item, remoção não otimista com pendência por item, foco no seguinte, no anterior ou no `h1`, e toasts de sucesso e erro.
**Where**: `frontend/src/routes/pasta/desejos/+page.svelte`
**Depends on**: T4, T5, T7, T12, T13
**Reuses**: `api`, `createLoader`, `requireSession`, `variantWishlistPath`, `notifySuccess`/`notifyError`, `SvelteSet`
**Requirement**: SPAS-03, SPAS-06, SPAS-07, SPAS-27, SPAS-28, SPAS-29, SPAS-33, SPAS-34, SPAS-35, SPAS-36

**Tools**:

- MCP: `plugin:svelte:svelte` (autofixer)
- Skill: `svelte:svelte-code-writer`

**Done when**:

- [ ] `load` sem sessão redireciona sem chamar o cliente; com sessão chama `get('/api/wishlist')`; `<title>` "Lista de desejos — Bindr" e `h1` "Lista de desejos" (SPAS-03, SPAS-27)
- [ ] "Carregando lista de desejos…" só após 200 ms; erro mostra a `message` e "Tentar novamente" (SPAS-06, SPAS-07)
- [ ] Lista vazia: as duas frases e "catálogo" como link para `/app` (SPAS-28)
- [ ] "1 item" e "2 itens", itens na ordem de `data` (SPAS-29)
- [ ] Remoção com `200`: `delete` no caminho de `variantWishlistPath`, item sai, contagem atualiza, toast "Item removido da lista de desejos." (SPAS-33)
- [ ] Foco depois de `tick()`: "Remover" do seguinte; do último, o do anterior; do único, o `h1` (SPAS-34)
- [ ] Segundo clique durante a pendência não chama o cliente; o botão de outro item segue acionável e a segunda remoção conclui (SPAS-35)
- [ ] `500` mantém o item e chama `notifyError` com a `message` (SPAS-36)
- [ ] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-pasta): lista de desejos em /app/pasta/desejos`

---

### T15: E2E da pasta

**What**: Playwright contra a API real com dois usuários de coleções diferentes: paridade de indicadores, ordem e números de cada set de `/app/pasta?order=recent|code` com `/progress?order=recent|code`, layout a 360px, 390px e 1280px nos dois temas, a ação fixa e a lateral, a largura dos indicadores e a animação com e sem `reducedMotion`.
**Where**: `frontend/e2e/pasta.spec.ts`
**Depends on**: T1, T13, T14
**Reuses**: criação de conta de `frontend/e2e/sessao.spec.ts`, medidas de `frontend/e2e/catalogo-layout.spec.ts`
**Requirement**: SPAS-01, SPAS-02, SPAS-03, SPAS-11, SPAS-12, SPAS-14, SPAS-16, SPAS-17, SPAS-18, SPAS-24, SPAS-26

**Tools**:

- MCP: NONE
- Skill: `ecc:e2e-testing`

**Done when**:

- [ ] Para cada usuário e cada `order`: os três indicadores e a sequência de `code` com `owned_numbers`, `base_size`, percentual, parallels e valor de cada linha iguais aos de `/progress` (SPAS-18, SPAS-26)
- [ ] Anônimo em `/app/pasta?order=code` termina em `/app/entrar?return_to=…` sem `GET /api/progress` observado (SPAS-03)
- [ ] "Minha pasta" do casco navega sem recarga e fica `aria-current` (SPAS-01, SPAS-02)
- [ ] 360px e 1280px, temas claro e escuro: `scrollWidth <= clientWidth` com todos os sets (SPAS-26)
- [ ] 1280px: cada indicador mede um quarto da coluna de conteúdo (±1px); a ação está na coluna lateral, abaixo do divisor, com "Adicionar cartas" (SPAS-11, SPAS-24)
- [ ] 390px: a ação fica acima da barra inferior e o último set rola até ficar visível acima dela (SPAS-24)
- [ ] A largura do cartão de valor não muda durante a animação; ao fim, o texto é o valor de `/progress`; com `reducedMotion: 'reduce'`, o primeiro quadro já é o final (SPAS-12, SPAS-14, SPAS-16)
- [ ] Capturas a 390px e 1280px de `/app/pasta` e `/progress` salvas para comparação do dono (SPAS-26)
- [ ] Gate check passes: Full

**Tests**: e2e
**Gate**: full

**Commit**: `test(spa-pasta): paridade e layout da pasta contra a API real`

---

### T16: E2E da lista de desejos

**What**: Playwright contra a API real: paridade de `/app/pasta/desejos` com `/wishlist` (itens, ordem, "Atendido"/"Faltam N"), remoção que some de `/wishlist` sem tocar o desejo de outro usuário, foco nunca no `<body>`, e link para o detalhe da carta sem recarga.
**Where**: `frontend/e2e/pasta-desejos.spec.ts`
**Depends on**: T2, T3, T15
**Reuses**: criação de conta de `frontend/e2e/sessao.spec.ts`, marcação de desejo pela API (`PUT …/wishlist`)
**Requirement**: SPAS-27, SPAS-29, SPAS-30, SPAS-31, SPAS-33, SPAS-34, SPAS-43

**Tools**:

- MCP: NONE
- Skill: `ecc:e2e-testing`

**Done when**:

- [ ] Com três desejos (um atendido), a lista da SPA tem os mesmos nomes, `variant_code`, contagens e estados, na mesma ordem, que `/wishlist` (SPAS-29, SPAS-31)
- [ ] Remover o do meio: o foco vai ao "Remover" do seguinte e nunca ao `<body>`; recarregar `/wishlist` não mostra o item; o mesmo desejo de outro usuário continua lá (SPAS-33, SPAS-34, SPAS-43)
- [ ] Remover todos: foco no `h1` e a mensagem de lista vazia (SPAS-34)
- [ ] O link do item abre `/app/cartas/<card_number>` sem recarga (SPAS-30)
- [ ] 360px nos dois temas sem scroll horizontal (SPAS-27)
- [ ] Gate check passes: Full

**Tests**: e2e
**Gate**: full

**Commit**: `test(spa-pasta): lista de desejos e remoção contra a API real`

---

### T17: Fechamento da documentação

**What**: Atualizar `CLAUDE.md` (estado da `spa-pasta`, rotas novas na tabela da API, armadilhas, `createLoader` e a dívida de migrar os dois carregadores antigos), a traceability do spec para `Implemented`, a §15 do `.context/tasks.md`, o *Handoff* do `STATE.md`, e rodar o gate de build.
**Where**: `CLAUDE.md`
**Depends on**: T16
**Reuses**: formato dos blocos da `spa-catalogo` e da `spa-carta`
**Requirement**: SPAS-46

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] `CLAUDE.md` lista `GET /api/progress`, `GET /api/wishlist` e `DELETE …/wishlist` na tabela da API e o estado da feature
- [ ] Traceability SPAS-01..46 em `Implemented` com a task de cada um; §15 do `.context/tasks.md` marcada
- [ ] *Handoff* registra a dívida: migrar `catalog.svelte.ts` e `card-detail.svelte.ts` para `createLoader`
- [ ] `git diff --name-status <base>..HEAD -- test/` só com `A`; controllers e views HTML da pasta e da wishlist intocados (SPAS-46)
- [ ] Gate check passes: Build

**Tests**: none
**Gate**: build

**Commit**: `docs(spa-pasta): registrar a pasta na SPA`

---

## Phase Execution Map

```
Phase 1 → Phase 2 → Phase 3 → Phase 4

Phase 1:  T1, T2, T3
Phase 2:  T4, T5, T6, T7, T8
Phase 3:  T9, T10, T11, T12
Phase 4:  T13, T14, T15, T16, T17
```

Execução estritamente sequencial, na ordem numérica dentro de cada phase; as dependências reais estão nos diagramas de cada phase.

---

## Task Granularity Check

| Task | Scope | Status |
|---|---|---|
| T1 | 1 endpoint (controller + view + rota) | ✅ |
| T2 | 1 endpoint | ✅ |
| T3 | 1 action + rota | ✅ |
| T4 | 1 módulo + tipos que ele devolve | ⚠️ coeso |
| T5 | 1 função | ✅ |
| T6 | 1 função (+ constante) | ✅ |
| T7 | 1 função | ✅ |
| T8 | 1 mudança de dado | ✅ |
| T9–T12 | 1 componente cada | ✅ |
| T13 | 1 rota (página + guarda de 3 linhas) | ⚠️ coeso |
| T14 | 1 rota (página + guarda de 3 linhas) | ⚠️ coeso |
| T15, T16 | 1 spec e2e cada | ✅ |
| T17 | docs | ✅ |

## Diagram-Definition Cross-Check

| Task | Depends On (task body) | Diagram Shows | Status |
|---|---|---|---|
| T1 | None | — | ✅ |
| T2 | T1 | T1 → T2 | ✅ |
| T3 | T2 | T2 → T3 | ✅ |
| T4 | None | sem dependência | ✅ |
| T5 | None | sem dependência | ✅ |
| T6 | None | sem dependência | ✅ |
| T7 | None | sem dependência | ✅ |
| T8 | None | sem dependência | ✅ |
| T9 | T6 | T6 → T9 | ✅ |
| T10 | T4, T9 | T4 → T10, T9 → T10 | ✅ |
| T11 | T4 | T4 → T11 | ✅ |
| T12 | T4 | T4 → T12 | ✅ |
| T13 | T4, T5, T8, T10, T11 | as cinco setas | ✅ |
| T14 | T4, T5, T7, T12, T13 | as cinco setas | ✅ |
| T15 | T1, T13, T14 | as três setas | ✅ |
| T16 | T2, T3, T15 | as três setas | ✅ |
| T17 | T16 | T16 → T17 | ✅ |

## Test Co-location Validation

| Task | Code Layer | Matrix Requires | Task Says | Status |
|---|---|---|---|---|
| T1–T3 | Controller da API | integration | integration | ✅ |
| T4 | Estado (`*.svelte.ts`) | unit | unit | ✅ |
| T5–T8 | Funções puras | unit | unit | ✅ |
| T9–T14 | Componentes e páginas | unit | unit | ✅ |
| T15, T16 | Jornadas no navegador | e2e | e2e | ✅ |
| T17 | Docs | none | none | ✅ |

## Requirement Coverage

Cada SPAS-01..46 aparece no campo `Requirement` de ao menos uma task: 01 (T13, T15), 02 (T8, T15), 03 (T5, T13, T14, T15), 04–05 (T4, T13), 06–07 (T4, T13, T14), 08–10 (T10), 11 (T10, T15), 12 (T6, T9, T15), 13 (T9), 14 (T9, T15), 15 (T9, T10), 16 (T9, T15), 17–18 (T13, T15), 19–23 (T11), 24 (T13, T15), 25 (T13), 26 (T15), 27 (T14, T16), 28 (T14), 29 (T14, T16), 30 (T7, T12, T16), 31 (T12, T16), 32 (T12), 33–34 (T14, T16), 35 (T12, T14), 36 (T14), 37–41 (T1), 42 (T2), 43 (T3, T7, T16), 44 (T3), 45 (T1, T2, T3), 46 (T3, T17).

## Plano de delegação

17 tasks → 3 lotes de phases inteiras: lote 1 = Phases 1 e 2 (T1–T8, Rails e funções puras; tier rápido), lote 2 = Phase 3 (T9–T12, componentes; tier alto pelo `AnimatedNumber`), lote 3 = Phase 4 (T13–T17, páginas e e2e; tier alto). Revisões: `ecc:security-reviewer` na T3 (escrita escopada por usuário e CSRF), `ecc:database-reviewer` na T1 (contagem de consultas), `ecc:a11y-architect` nas T9 e T14 (número interpolado e foco depois da remoção). O Verifier roda depois da T17, em contexto novo.
