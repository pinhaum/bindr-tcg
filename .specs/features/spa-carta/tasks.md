# Detalhe da carta na SPA — Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Design**: `.specs/features/spa-carta/design.md`
**Status**: Draft

---

## Test Coverage Matrix

> Generated from codebase, project guidelines, and spec - confirm before Execute. Guidelines found: `CLAUDE.md` (gates do front e do Rails, armadilhas do Kit 3, teste de CSRF com `allow_forgery_protection` ligado no `setup`, teste de corrida com `use_transactional_tests = false`, "toda task termina com código que roda e teste que passa"), `frontend/src/lib/styles/guard.test.ts` (hex, px de token e animação fora de `transform`/`opacity` reprovam), ESLint que proíbe `fetch` fora de `client.ts`. Amostras lidas: `test/integration/api/cards_test.rb`, `test/integration/api/sessions_test.rb`, `test/integration/deck_entries_concurrency_test.rb`, `test/models/collection_item_test.rb`, `frontend/src/lib/catalog/catalog.svelte.ts` e seu teste, `frontend/src/lib/components/CardTile.test.ts`, `frontend/src/routes/page.test.ts`, `frontend/e2e/catalogo.spec.ts`. O piso é o da `spa-catalogo`; o alvo vem dos ACs do spec (strong default).

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| ---------- | ------------------ | -------------------- | ---------------- | ----------- |
| Model Rails (`CollectionItem`) | unit (Minitest) | `increment_for!` cria com 1 e soma; `decrement_for!` subtrai, devolve `nil` no zero e sem registro, nunca grava negativo; escopo por usuário e variante | `test/models/*_test.rb` | Rails quick |
| Controller da API (`Api::CardVariantsController`) | integration (request test) | Os três endpoints: sucesso com o corpo exato do contrato; cada valor inválido do SCAR-46; 404 por carta inexistente e por variante de outra carta; 401 sem sessão; 422 `invalid_csrf_token` com `allow_forgery_protection` ligado; `user_id` alheio ignorado; `400 invalid_json`; `variant_code` com `:` codificado; nunca HTML nem redirect | `test/integration/api/*_test.rb` | Rails quick |
| Concorrência de posse | integration (`use_transactional_tests = false`) | Incrementos e decrementos sobrepostos por lock sobre o endpoint da API, sem operação perdida nem negativo | `test/integration/api/*_concurrency_test.rb` | Rails quick |
| Funções puras (`format.ts`, `cards/url.ts`, `cards/featured.ts`) | unit | Todos os ramos, 1:1 com os ACs da task; paridade de preço e data com `prices_helper.rb` (`02:00Z` → dia anterior em São Paulo); codificação de `card_number` reservado e `variant_code` com `:` | `frontend/src/lib/**/*.test.ts` | Front quick |
| Estado (`*.svelte.ts`) | unit | Com cliente falso, timer falso e promessas controladas: token de sequência, skeleton após 200 ms, erro não-`ApiError` relançado, `retry`; fila em série, último `owned_quantity` vence, falha volta ao confirmado e descarta não enviadas, `refused` no zero, `discard()` ignora a resposta em voo | `frontend/src/lib/**/*.test.ts` | Front quick |
| Componentes e página (`.svelte`) | unit (componente, jsdom) | Cada AC de tela: texto exato pt-BR, `href` exato, ARIA (`aria-current`, `aria-disabled`, `aria-live`, `aria-describedby`, `aria-invalid`, `aria-busy`, `role="img"`, `role="group"`), foco depois de `tick()`, com e sem sessão, estados 404/erro/skeleton | `frontend/src/**/*.test.ts` | Front quick |
| Jornadas no navegador | e2e (Playwright contra a API real) | Paridade `/app/cartas/X?variant=Y` × `/cards/X?variant=Y`; 360px e 1280px nos dois temas sem scroll horizontal; tile → detalhe e voltar sem recarga; cinco `+` rápidos gravam +5; desejo persiste após recarga; morph com e sem `reducedMotion` | `frontend/e2e/*.spec.ts` | e2e |
| Docs (`CLAUDE.md`, `STATE.md`, `.context/tasks.md`, specs) | none | - | - | build gate only |

## Gate Check Commands

> Generated from codebase - confirm before Execute. Rodar as suítes em série, nunca em paralelo (flake D-10). `npm ci` com o serviço `frontend` de pé troca o `node_modules` sob o Vite: parar o serviço antes do quick ou reiniciá-lo depois. O e2e exige o catálogo importado no banco de dev (`ingestion:import SNAPSHOT=…`). Se o pull de imagem falhar pelo `credsStore` do host, `export DOCKER_CONFIG=$(mktemp -d)` com `{}` em `config.json`.

| Gate Level | When to Use | Command |
| ---------- | ----------- | ------- |
| Rails quick | Tasks do Rails | `docker compose exec app bin/rails test test/models test/integration && docker compose exec app bin/rubocop` |
| Front quick | Tasks do front com teste de unidade | `docker compose run --rm --no-deps frontend sh -c "npm ci && npm run check && npm run lint && npm test -- --run"` |
| Full | Tasks e2e (depois do Front quick) | Front quick + `docker compose up -d app frontend && docker compose --profile e2e run --rm e2e` + `docker compose exec app bin/rails test` |
| Build | Fechamento | `docker build -f Dockerfile .` + Full + `docker compose exec app bin/rubocop` + `docker compose exec app bin/brakeman` + `git diff --name-status 213f0bc..HEAD -- test/` só com `A` (SCAR-49: nenhum teste Rails existente editado) |

---

## Execution Plan

Phases are ordered and run sequentially - each phase completes before the next begins, and tasks within a phase execute in order. Cada diagrama traz todas as dependências das tasks da phase, inclusive as que vêm de phases anteriores. A varredura "JSON, nunca redirect" das rotas novas fica nos request tests da T2 e da T3, sem editar `end_to_end_test.rb` (SCAR-49).

### Phase 1: API de posse e desejo (Rails)

```
T1 → T2
T2 → T3
T2 → T4
```

### Phase 2: Funções puras e estado do front

```
T6 → T7
T6 → T8
T7 → T8
```

T5, T9 e T10 não dependem de nada.

### Phase 3: Componentes do detalhe

```
T5 → T11
T5 → T13
T10 → T13
T11 → T13
T5 → T14
T9 → T14
T5 → T15
T6 → T15
T5 → T16
T6 → T16
T11 → T16
T14 → T16
T15 → T16
```

T12 não depende de nada.

### Phase 4: Página, tile, ponta a ponta e fechamento

```
T7 → T17
T8 → T17
T10 → T17
T12 → T17
T13 → T17
T16 → T17
T6 → T18
T10 → T18
T3 → T19
T17 → T19
T18 → T19
T4 → T20
T19 → T20
T20 → T21
T21 → T22
```

---

## Task Breakdown

### T1: SQL atômico de posse no model `CollectionItem`

**What**: Mover o SQL de incremento e decremento de `CollectionItemsController` para `CollectionItem.increment_for!(user, variant) -> Integer` e `CollectionItem.decrement_for!(user, variant) -> Integer | nil`, sem alterar o SQL nem o comentário de concorrência, e fazer o controller HTML chamar esses métodos mantendo respostas, mensagens e rotas.
**Where**: `app/models/collection_item.rb`
**Depends on**: None
**Reuses**: SQL e comentário de `app/controllers/collection_items_controller.rb:30-108` (abordagem A do design)
**Requirement**: SCAR-49, SCAR-44

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Teste novo de model: `increment_for!` sem registro devolve 1 e cria; com 3 devolve 4
- [x] `decrement_for!` com 2 devolve 1; com 0 e sem registro devolve `nil` e não cria nem altera registro
- [x] Os métodos só tocam o registro do `user` e da `variant` passados (outro usuário com a mesma variante fica intacto)
- [x] `CollectionItemsController` não contém mais SQL; nenhum teste Rails existente editado e todos passam
- [x] Gate check passes: Rails quick + `docker compose exec app bin/rails test` (suíte inteira, SCAR-49)

**Tests**: unit
**Gate**: full

**Commit**: `refactor(spa-carta): mover o SQL atômico de posse para CollectionItem`

---

### T2: Endpoints de incremento e decremento da API

**What**: Criar `Api::CardVariantsController` com `increment` e `decrement`, a resolução da variante por `card_number` + `variant_code` (`before_action`, 404 pelo base), as views jbuilder `{ data: { variant_code, owned_quantity } }` e as duas rotas no `scope "api"`, acima do catch-all, com `constraints` que aceitam `.` e `:` codificado.
**Where**: `app/controllers/api/card_variants_controller.rb`
**Depends on**: T1
**Reuses**: `Api::BaseController` (sessão, `render_error`, 404/422/400), helpers de CSRF de `test/integration/api/sessions_test.rb:8-30`
**Requirement**: SCAR-42, SCAR-43, SCAR-47, SCAR-48

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Request test: `increment` sem registro → `200` `{ data: { variant_code, owned_quantity: 1 } }`; segundo → `2` (SCAR-42)
- [x] `decrement` com 2 → `1`; com 0 e sem registro → `200` `owned_quantity: 0` sem criar registro (SCAR-43, P10)
- [x] `variant_code` `tcgplayer:123` enviado como `tcgplayer%3A123` é encontrado; `card_number` com `.` é aceito
- [x] Carta inexistente e `variant_code` de outra carta → `404 not_found` sem gravar (SCAR-47)
- [x] Sem sessão → `401 unauthenticated`; sem `X-CSRF-Token` com `allow_forgery_protection` ligado → `422 invalid_csrf_token`; `user_id` alheio no corpo e na query é ignorado (SCAR-48)
- [x] Toda resposta dos dois endpoints é `application/json` e nenhuma é redirect (API-17)
- [x] Gate check passes: Rails quick

**Tests**: integration
**Gate**: quick

**Commit**: `feat(spa-carta): gravar posse por card_number e variant_code na API`

---

### T3: Endpoint de desejo da API

**What**: Acrescentar ao `Api::CardVariantsController` a action `wishlist` (`PUT …/wishlist`), que cria ou atualiza o desejo do `Current.user`, valida `target_quantity` como inteiro JSON ≥ 1 ou string só de dígitos ≥ 1, responde `422 validation_failed` com a mensagem do SCAR-46 e repete uma vez em `RecordNotUnique`.
**Where**: `app/controllers/api/card_variants_controller.rb` (modify)
**Depends on**: T2
**Reuses**: `WishlistItem` (`find_or_initialize_by` + `save`), resolução de variante da T2
**Requirement**: SCAR-45, SCAR-46, SCAR-47, SCAR-48

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] `PUT` com `2` sem desejo cria e responde `200` `{ data: { variant_code, wishlist_target: 2 } }`; com `3` atualiza o mesmo registro; com o mesmo alvo responde igual sem duplicar (SCAR-45)
- [x] `0`, `-1`, `1.5`, `"abc"`, `null` e ausência → `422` `validation_failed`, `message` "Dados inválidos.", `fields.target_quantity` `["Informe um número inteiro maior ou igual a 1."]`, sem gravar (SCAR-46)
- [x] `"3"` é aceito como 3
- [x] Corpo JSON malformado → `400 invalid_json`
- [x] 404, 401, 422 de CSRF, `user_id` alheio e "JSON, nunca redirect" como na T2 (SCAR-47, SCAR-48)
- [x] `RecordNotUnique` simulado na primeira tentativa resulta em `200` com o alvo gravado
- [x] Gate check passes: Rails quick

**Tests**: integration
**Gate**: quick

**Commit**: `feat(spa-carta): marcar e atualizar desejo por variante na API`

---

### T4: Teste de corrida dos endpoints de posse

**What**: Teste de integração com `use_transactional_tests = false` que sobrepõe incrementos e decrementos da mesma variante e do mesmo usuário sobre os endpoints da API, forçando a sobreposição por lock, e prova que nenhuma operação se perde nem a quantidade fica negativa.
**Where**: `test/integration/api/card_variants_concurrency_test.rb`
**Depends on**: T2
**Reuses**: `race(lock_sql:)` e `wait_until_blocked` de `test/integration/deck_entries_concurrency_test.rb:25-123`
**Requirement**: SCAR-44

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] N incrementos sobrepostos a partir de zero terminam em N
- [x] Decrementos sobrepostos a partir de 1 terminam em 0, um deles com `owned_quantity: 0` e sem registro negativo
- [x] Mutação que troque o SQL atômico por ler-somar-gravar em `CollectionItem` faz o teste falhar (verificado à mão e registrado na task)
- [x] O teste limpa o que gravou
- [x] Gate check passes: Rails quick

**Tests**: integration
**Gate**: quick

**Commit**: `test(spa-carta): provar a posse atômica sob concorrência na API`

---

### T5: Formatadores de preço, data e cópias

**What**: Criar `formatPrice(amount, currency)`, `formatObservedDate(iso)` e `copies(n)` com paridade com `prices_helper.rb`.
**Where**: `frontend/src/lib/format.ts`
**Depends on**: None
**Reuses**: valores de `test/helpers/prices_helper_test.rb` como casos de paridade
**Requirement**: SCAR-15, SCAR-21, SCAR-25, SCAR-36

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] `formatPrice('1234.56', 'USD')` → `US$ 1.234,56` com espaço comum; `EUR` → `EUR 1.234,56`; `'0.5'` → `US$ 0,50`
- [x] `formatObservedDate('2026-10-05T02:00:00Z')` → `04/10/2026` (São Paulo)
- [x] `copies(1)` → "1 cópia"; `copies(2)` → "2 cópias"
- [x] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-carta): formatar preço, data e cópias como o HTML`

---

### T6: Caminhos do detalhe e dos endpoints de escrita

**What**: Criar `cardDetailHref(cardNumber, variantCode?)` (`/app/cartas/<enc>?variant=<enc>`, com `base`), `cardApiPath(cardNumber, variant?)` e `variantApiPath(cardNumber, variantCode, 'increment' | 'decrement' | 'wishlist')`, todos com `encodeURIComponent`.
**Where**: `frontend/src/lib/cards/url.ts`
**Depends on**: None
**Reuses**: padrão de `frontend/src/lib/catalog/url.ts` e `vi.mock('$app/paths')`
**Requirement**: SCAR-02, SCAR-03, SCAR-22, SCAR-42, SCAR-45

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] `cardDetailHref('P-029')` → `/app/cartas/P-029`; com `'tcgplayer:1'` → `…?variant=tcgplayer%3A1`; `card_number` com espaço e `/` codificados
- [x] `cardApiPath('OP01-001', 'tcgplayer:1')` → `/api/cards/OP01-001?variant=tcgplayer%3A1`; sem `variant` não leva query (SCAR-02)
- [x] `variantApiPath('OP01-001', 'tcgplayer:1', 'increment')` → `/api/cards/OP01-001/variants/tcgplayer%3A1/increment`
- [x] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-carta): montar caminhos do detalhe e da escrita de posse`

---

### T7: Tipos do detalhe e regra da variante em destaque

**What**: Acrescentar a `src/lib/api/types.ts` os tipos `CardDetailPayload`, `DetailVariant`, `OwnershipResult` e `WishlistResult` do design, e criar `pickFeatured(variants, variantParam)` com a regra do CNF-42.
**Where**: `frontend/src/lib/cards/featured.ts`
**Depends on**: T6
**Reuses**: campos de `app/views/api/cards/_variant.json.jbuilder` (AD-024, tipos à mão)
**Requirement**: SCAR-24

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] `variantParam` presente na lista → essa variante
- [x] Ausente ou desconhecido → primeira com `in_source: true`; nenhuma na fonte → primeira listada; lista vazia → `null`, sem erro
- [x] `npm run check` aceita os tipos novos
- [x] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-carta): escolher a variante em destaque como o HTML`

---

### T8: Carregador do detalhe

**What**: Criar `createCardDetailLoader(client, skeletonDelayMs = 200)` com `state { result, error, notFound, pending, skeleton, seq }`, `load(cardNumber, variant)` e `retry()`, descartando resposta de consulta superada.
**Where**: `frontend/src/lib/cards/card-detail.svelte.ts`
**Depends on**: T6, T7
**Reuses**: desenho de `frontend/src/lib/catalog/catalog.svelte.ts` (token, `settle`, relançar erro não-`ApiError`)
**Requirement**: SCAR-02, SCAR-05, SCAR-06, SCAR-07, SCAR-08

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] `load('P-029', 'tcgplayer:1')` chama `client.get('/api/cards/P-029?variant=tcgplayer%3A1')` (SCAR-02)
- [x] `skeleton` só vira `true` depois de 200 ms pendentes; antes disso `result` anterior continua (SCAR-07)
- [x] Resposta de `load` superada por outro `load` não altera `state` (SCAR-08)
- [x] `404 not_found` → `notFound` com a `message`; outro `ApiError` → `error`; `retry()` repete a última consulta (SCAR-05, SCAR-06)
- [x] Erro que não é `ApiError` é relançado
- [x] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-carta): carregar o detalhe da carta com descarte de resposta antiga`

---

### T9: Fila de posse otimista

**What**: Criar `createOwnershipQueue({ confirmed, send, onSettled, onError })` com `displayed`, `confirmed`, `settled`, `tap(op)` e `discard()`, pelas regras do design.
**Where**: `frontend/src/lib/cards/ownership-queue.svelte.ts`
**Depends on**: None
**Reuses**: NONE (módulo puro com `send` injetado)
**Requirement**: SCAR-27, SCAR-28, SCAR-29, SCAR-30, SCAR-31, SCAR-32, SCAR-33

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Cinco `tap('increment')` sobre 0 dão `displayed` 1..5 na hora e uma só chamada de `send` em voo por vez, na ordem (SCAR-27, SCAR-30)
- [x] `tap('decrement')` com `displayed` 0 devolve `'refused'` e não chama `send` (SCAR-29)
- [x] Ao esvaziar a fila, `displayed` é o `owned_quantity` da última resposta (ex.: 7 vindo de outra aba) e `onSettled(7)` é chamado uma vez (SCAR-31, SCAR-33)
- [x] Falha na 3ª de cinco: `displayed` volta ao último confirmado, 4ª e 5ª não são enviadas, `onError` recebe o erro (SCAR-32)
- [x] `discard()` com operação em voo: não envia as pendentes e a resposta em voo não muda `displayed` nem chama `onSettled`
- [x] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-carta): enfileirar a posse otimista por variante`

---

### T10: Estado do morph grade → detalhe

**What**: Criar o estado de módulo que guarda o `card_number` marcado para a transição e `morphName(cardNumber)`, que escapa o código para um `<custom-ident>` válido.
**Where**: `frontend/src/lib/cards/morph.svelte.ts`
**Depends on**: None
**Reuses**: `frontend/src/lib/view-transition.ts` (inalterado)
**Requirement**: SCAR-39, SCAR-40, SCAR-41

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] `morphName('OP01-001')`, `morphName('P-029')` e um código com `.` e espaço dão nomes distintos que casam com a gramática de `<custom-ident>`
- [x] Marcar uma carta substitui a anterior; `isMarked(x)` só é verdadeiro para a última
- [x] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-carta): marcar a carta da transição grade → detalhe`

---

### T11: Componente `CardArt`

**What**: Quadro de proporção fixa com placeholder (nome + `card_number`) por trás da imagem, que esconde a imagem no `error` e aplica `transitionName` quando recebido.
**Where**: `frontend/src/lib/components/CardArt.svelte`
**Depends on**: T5
**Reuses**: placeholder e proporção de `CardTile.svelte`
**Requirement**: SCAR-10

**Tools**:

- MCP: `plugin:svelte:svelte` (autofixer)
- Skill: `svelte:svelte-core-bestpractices`

**Done when**:

- [x] Com `image_url` mostra `<img>` com `alt` recebido ("<nome> <variant_code>") e o placeholder atrás
- [x] `image_url` `null` → sem `<img>`, placeholder visível; `error` da imagem → imagem oculta (edge case 403)
- [x] O quadro usa a mesma regra de proporção nos três casos (verificado pela classe aplicada)
- [x] `transitionName` presente vira `style="view-transition-name: …"`; ausente, nenhum
- [x] Gate check passes: Front quick (inclui `guard.test.ts`)

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-carta): quadro da arte com placeholder estável`

---

### T12: Componente `CardFields`

**What**: Campos da carta pela tabela de tipo e seção "Efeito" com texto puro, `white-space: pre-line` e "Trigger" em `<strong>`.
**Where**: `frontend/src/lib/components/CardFields.svelte`
**Depends on**: None
**Reuses**: tabela de campos de `app/views/cards/show.html.erb` como referência de paridade
**Requirement**: SCAR-17, SCAR-18

**Tools**:

- MCP: `plugin:svelte:svelte` (autofixer)
- Skill: `svelte:svelte-core-bestpractices`

**Done when**:

- [x] Leader mostra Power, Life, Attribute, Traits, Block e não Custo; Character com counter `null` não mostra Counter e com `0` mostra `0`; Event e Stage mostram Custo, Attribute, Traits, Block
- [x] `0` aparece como valor; lista vazia omite o campo; listas unidas por ", "
- [x] `effect_text` com `<script>` aparece como texto; quebras de linha preservadas
- [x] Trigger sem efeito exibe a seção "Efeito" com "Trigger" em `<strong>`; sem efeito nem trigger, sem a seção
- [x] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-carta): exibir campos e efeito da carta por tipo`

---

### T13: Componente `CardHeader`

**What**: Cabeçalho com `h1`, chips, linha do set, "Variante fora da fonte", selo de posse, ilustração e a imagem em miniatura + `<details>` "Ver imagem maior" abaixo de 64rem ou em coluna a partir dele, com o nome de transição só na imagem visível.
**Where**: `frontend/src/lib/components/CardHeader.svelte`
**Depends on**: T5, T10, T11
**Reuses**: `wide` de `frontend/src/lib/shell.svelte.ts`, `CardArt`
**Requirement**: SCAR-01, SCAR-11, SCAR-12, SCAR-13, SCAR-14, SCAR-15, SCAR-16, SCAR-39

**Tools**:

- MCP: `plugin:svelte:svelte` (autofixer)
- Skill: `svelte:svelte-core-bestpractices`

**Done when**:

- [x] `h1` com o nome; chips com tipo capitalizado, raridade do destaque, uma por cor e "Counter N" só com `wide` e counter aplicável não `null`; linha "<set> · <código>" (SCAR-13)
- [x] Abaixo de 64rem: miniatura + `<details>` fechado com resumo "Ver imagem maior"; a partir dele: coluna sem `<details>` (SCAR-11, SCAR-12)
- [x] "Variante fora da fonte" só com `in_source: false` (SCAR-14); "Ilustração: X" só com `illustrator` (SCAR-16)
- [x] Selo com `role="img"` e nome "N cópias" só com sessão e valor exibido > 0, seguindo o valor recebido por prop (SCAR-15)
- [x] Com a carta marcada, exatamente um elemento com o `view-transition-name` dela, nos dois valores de `wide` (SCAR-39)
- [x] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-carta): cabeçalho do detalhe com imagem por largura`

---

### T14: Componente `OwnershipStepper`

**What**: Controle `−` `[n]` `+` sobre uma `OwnershipQueue`, com quantidade em texto, região `aria-live="polite"`, `aria-disabled` no zero e foco preservado.
**Where**: `frontend/src/lib/components/OwnershipStepper.svelte`
**Depends on**: T5, T9
**Reuses**: `toasts` para o erro (SPA-45), `copies` da T5
**Requirement**: SCAR-25, SCAR-27, SCAR-28, SCAR-29, SCAR-32, SCAR-33, SCAR-34

**Tools**:

- MCP: `plugin:svelte:svelte` (autofixer)
- Skill: `svelte:svelte-core-bestpractices`

**Done when**:

- [x] Texto "não tenho" / "1 cópia" / "N cópias"; `[n]` com `aria-hidden`; botões com os nomes acessíveis exatos do SCAR-25 e mínimo de 44px (token)
- [x] Clique em `+` muda o número antes da resposta do `send` falso (SCAR-27); `−` acima de zero idem (SCAR-28)
- [x] Em zero, `−` tem `aria-disabled="true"`, não tem `disabled`, não chama `send` e a região viva anuncia "Você não tem cópias desta variante para remover." (SCAR-29)
- [x] Ao esvaziar a fila a região anuncia "2 cópias <nome> <variant_code>" ou "não tenho <nome> <variant_code>" (SCAR-33)
- [x] Falha: valor volta e um toast de erro com a `message` é empurrado (SCAR-32)
- [x] Foco continua no botão acionado depois da resposta e nenhum botão recebe `disabled` (SCAR-34)
- [x] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-carta): stepper de posse com atualização otimista`

---

### T15: Componente `WishlistForm`

**What**: Formulário `role="group"` com campo "Quero" e botão "Quero esta" / "Atualizar desejo", que envia `PUT …/wishlist`, mostra sucesso por toast, erro de campo ligado por `aria-describedby` e ignora envio duplicado.
**Where**: `frontend/src/lib/components/WishlistForm.svelte`
**Depends on**: T5, T6
**Reuses**: `Button`, `FormError`, `toasts`, cliente da fundação
**Requirement**: SCAR-35, SCAR-36, SCAR-37, SCAR-38

**Tools**:

- MCP: `plugin:svelte:svelte` (autofixer)
- Skill: `svelte:svelte-core-bestpractices`

**Done when**:

- [x] `role="group"` com nome "Marcar <nome> <variant_code> como desejada"; campo de rótulo "Quero", `min="1"`, `step="1"`, valor inicial `wishlist_target`; botão "Quero esta" com `null`, "Atualizar desejo" com valor (SCAR-35)
- [x] Sucesso: toast "<nome> <variant_code> na lista de desejos: 1 cópia." ou "…: N cópias.", campo com o alvo devolvido, botão "Atualizar desejo" (SCAR-36)
- [x] `validation_failed`: mensagem de `fields.target_quantity` ligada por `aria-describedby`, `aria-invalid="true"`, foco no campo, valor digitado mantido (SCAR-37)
- [x] Com envio pendente o botão está desabilitado e um segundo submit não chama o cliente (SCAR-38)
- [x] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-carta): formulário de desejo por variante`

---

### T16: Componente `VariantRow`

**What**: Linha de variante com miniatura-link, código, raridade e tipo de arte, set, "fora da fonte", preço, e posse ou convite e desejo conforme a sessão.
**Where**: `frontend/src/lib/components/VariantRow.svelte`
**Depends on**: T5, T6, T11, T14, T15
**Reuses**: `CardArt`, `OwnershipStepper`, `WishlistForm`, `safeReturnTo`
**Requirement**: SCAR-19, SCAR-20, SCAR-21, SCAR-22, SCAR-23, SCAR-25, SCAR-26, SCAR-35

**Tools**:

- MCP: `plugin:svelte:svelte` (autofixer)
- Skill: `svelte:svelte-core-bestpractices`

**Done when**:

- [x] Miniatura com `alt=""` e `loading="lazy"`; `variant_code` em `<code>`; "R · arte base", "SR · parallel", "SEC · alternativa"; sem `rarity`, sem o rótulo; "<set> (<código>)" (SCAR-19)
- [x] "fora da fonte" só com `in_source: false` (SCAR-20)
- [x] Preço `US$ 1.234,56` + "TCGplayer · market · dd/mm/aaaa", `EUR` com o código, "Sem preço" com `null`, com e sem sessão (SCAR-21)
- [x] Miniatura é link para `cardDetailHref(card, variant)`, nome "Mostrar <variant_code> na imagem principal", `aria-current="true"` só no destaque; clique chama o callback de seleção e não navega (SCAR-22, SCAR-23)
- [x] Sem sessão: link "Entrar para registrar posse" para `/app/entrar?return_to=<caminho e query atuais>`, sem stepper nem desejo (SCAR-26)
- [x] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-carta): linha de variante com preço, posse e desejo`

---

### T17: Rota `/app/cartas/[card_number]`

**What**: Página do detalhe que lê `card_number` e `variant`, carrega pelo carregador, refaz a consulta na troca de carta e de sessão, mantém um `Map` de filas por variante (descartadas na troca de carta e de sessão), troca o destaque por `replaceState`, define `<title>`, "Voltar ao catálogo" e os estados 404, erro e skeleton.
**Where**: `frontend/src/routes/cartas/[card_number]/+page.svelte`
**Depends on**: T7, T8, T10, T12, T13, T16
**Reuses**: `shell.aside` + `wide`, `session`, padrão de `src/routes/+page.svelte` e `page.test.ts`
**Requirement**: SCAR-01, SCAR-02, SCAR-04, SCAR-05, SCAR-06, SCAR-07, SCAR-08, SCAR-09, SCAR-15, SCAR-23, SCAR-24

**Tools**:

- MCP: `plugin:svelte:svelte` (autofixer)
- Skill: `svelte:svelte-core-bestpractices`

**Done when**:

- [x] `<title>` "<nome> (<card_number>) — Bindr"; 404 → `message`, "Voltar ao catálogo" e "Carta não encontrada — Bindr" (SCAR-01, SCAR-05)
- [x] Erro → `message` + "Tentar novamente" que repete a consulta (SCAR-06); `aria-busy` e "Carregando carta…" só após 200 ms (SCAR-07)
- [x] Troca de `card_number` refaz a consulta e descarta filas; troca de sessão (e-mail) refaz a consulta (SCAR-08, SCAR-09)
- [x] "Voltar ao catálogo": botão bordado sem seta para `/app`, em `shell.aside` com `wide`, no topo sem ele (SCAR-04)
- [x] Clique na miniatura muda destaque, selo, ilustração e chips, chama `replaceState` com `?variant=` e não chama o cliente de novo (SCAR-23); `variant` inválido usa a regra da T7 (SCAR-24)
- [x] Selo do cabeçalho segue o `displayed` da fila da variante em destaque (SCAR-15)
- [x] Sair com operações pendentes: filas descartadas, convite no lugar dos steppers, sem selo (edge cases de sessão); trocar de variante não interrompe a fila de outra
- [x] Carta sem variantes: cabeçalho, campos e efeito, sem imagem nem "Variantes na pasta"
- [x] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-carta): rota do detalhe da carta na SPA`

---

### T18: Tile do catálogo leva ao detalhe da SPA

**What**: Trocar o `href` do `CardTile` de `/cards/…` para `cardDetailHref`, marcar a carta no clique para o morph, aplicar `view-transition-name` à arte do tile marcado e emendar o SCAT-03 no spec da `spa-catalogo` e o Req. 18.3.
**Where**: `frontend/src/lib/components/CardTile.svelte` (modify)
**Depends on**: T6, T10
**Reuses**: `morph.svelte.ts`, `CardTile.test.ts`
**Requirement**: SCAR-03, SCAR-39, SCAR-40

**Tools**:

- MCP: `plugin:svelte:svelte` (autofixer)
- Skill: `svelte:svelte-core-bestpractices`

**Done when**:

- [ ] `href` do tile é `/app/cartas/<card_number codificado>`; os testes de front que afirmavam o destino Hotwire (`CardTile.test.ts`, `page.test.ts`, e2e do catálogo) passam a afirmar o novo, citando a emenda do SCAT-03
- [ ] Clique marca a carta; só o tile marcado tem `view-transition-name`, e só um na grade
- [ ] SCAT-03 (spec da `spa-catalogo`) e Req. 18.3 emendados para o detalhe da SPA
- [ ] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-carta): levar o tile do catálogo ao detalhe da SPA`

---

### T19: E2E do detalhe: navegação, paridade e layout

**What**: Playwright contra a API real: tile → detalhe e "Voltar ao catálogo" sem recarga; paridade de campos, variantes, preços e destaque entre `/app/cartas/X?variant=Y` e `/cards/X?variant=Y`; 360px e 1280px nos dois temas sem scroll horizontal; 404.
**Where**: `frontend/e2e/carta.spec.ts`
**Depends on**: T3, T17, T18
**Reuses**: helpers e padrão de `frontend/e2e/catalogo.spec.ts` e `catalogo-layout.spec.ts`
**Requirement**: SCAR-01, SCAR-03, SCAR-04, SCAR-05, SCAR-10, SCAR-11, SCAR-12, SCAR-13, SCAR-17, SCAR-19, SCAR-21, SCAR-22, SCAR-23, SCAR-24

**Tools**:

- MCP: NONE
- Skill: `ecc:e2e-testing`

**Done when**:

- [ ] Clique no tile abre `/app/cartas/X` sem carregar documento novo; "Voltar ao catálogo" volta a `/app` idem (SCAR-03, SCAR-04)
- [ ] Para uma carta com várias variantes, nomes dos campos, lista de variantes (código, rótulo, set, preço) e destaque iguais aos do HTML, com `?variant=` válido, inválido e ausente (SCAR-13, SCAR-17, SCAR-19, SCAR-21, SCAR-24)
- [ ] 360px: miniatura + "Ver imagem maior" fechado; 1280px: coluna visível e chip "Counter"; `scrollWidth <= clientWidth` nos dois temas (SCAR-11, SCAR-12)
- [ ] Clique na miniatura de variante muda a URL sem item novo no histórico (SCAR-23); `/app/cartas/NAO-EXISTE` mostra a mensagem e o título do 404 (SCAR-05)
- [ ] Gate check passes: Full

**Tests**: e2e
**Gate**: full

**Commit**: `test(spa-carta): navegação, paridade e layout do detalhe no navegador`

---

### T20: E2E de posse e desejo

**What**: Playwright contra a API real com conta nova: cinco `+` rápidos gravam +5 e o número final é o do `GET` seguinte; `−` em zero não envia; desejo marcado persiste após recarga; sair troca controles pelo convite.
**Where**: `frontend/e2e/carta-posse.spec.ts`
**Depends on**: T4, T19
**Reuses**: criação de conta de `frontend/e2e/sessao.spec.ts`
**Requirement**: SCAR-09, SCAR-25, SCAR-26, SCAR-27, SCAR-29, SCAR-30, SCAR-31, SCAR-36

**Tools**:

- MCP: NONE
- Skill: `ecc:e2e-testing`

**Done when**:

- [ ] Cinco cliques rápidos em `+`: o número passa por 1..5 antes das respostas e, depois, `GET /api/cards/X` devolve `owned_quantity` 5 (SCAR-27, SCAR-30, SCAR-31)
- [ ] Exatamente cinco `POST …/increment` observados, em série (SCAR-30)
- [ ] `−` em zero não gera requisição (SCAR-29)
- [ ] Marcar 2 em "Quero", recarregar: campo com 2 e botão "Atualizar desejo" (SCAR-36)
- [ ] Sair pelo casco com o detalhe aberto: convite "Entrar para registrar posse" no lugar dos controles e sem selo (SCAR-09, SCAR-26)
- [ ] Gate check passes: Full

**Tests**: e2e
**Gate**: full

**Commit**: `test(spa-carta): posse otimista e desejo contra a API real`

---

### T21: E2E do morph grade → detalhe

**What**: Playwright (Chromium) prova o pseudo-elemento `::view-transition-group` da carta na ida e na volta, e a ausência dele com `reducedMotion: 'reduce'`, com a navegação concluindo nos dois casos.
**Where**: `frontend/e2e/carta-morph.spec.ts`
**Depends on**: T20
**Reuses**: padrão de View Transition de `frontend/e2e/casco.spec.ts`
**Requirement**: SCAR-39, SCAR-40, SCAR-41

**Tools**:

- MCP: NONE
- Skill: `ecc:e2e-testing`

**Done when**:

- [ ] Tile → detalhe: durante a transição existe `::view-transition-group(<nome da carta>)` (SCAR-39)
- [ ] Detalhe → catálogo pelo botão e pelo voltar do navegador: idem quando o tile está na grade (SCAR-40)
- [ ] Com `reducedMotion: 'reduce'`: nenhum grupo da carta e a navegação conclui (SCAR-41)
- [ ] Gate check passes: Full

**Tests**: e2e
**Gate**: full

**Commit**: `test(spa-carta): morph da arte entre grade e detalhe`

---

### T22: Fechamento da documentação

**What**: Atualizar `CLAUDE.md` (estado da `spa-carta`, rotas novas da API, armadilhas), a traceability do spec para `Implemented`, a §14 do `.context/tasks.md`, o *Handoff* do `STATE.md` (dívida do `CardImagesController` por `variant_code` global) e rodar o gate de build.
**Where**: `CLAUDE.md`
**Depends on**: T21
**Reuses**: formato dos blocos da `spa-catalogo`
**Requirement**: SCAR-49

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] `CLAUDE.md` lista `POST …/increment`, `…/decrement`, `PUT …/wishlist` na tabela da API e o estado da feature
- [ ] Traceability SCAR-01..49 em `Implemented` com a task de cada um; §14 do `.context/tasks.md` marcada
- [ ] `git diff --name-status 213f0bc..HEAD -- test/` só com `A` (SCAR-49)
- [ ] Gate check passes: Build

**Tests**: none
**Gate**: build

**Commit**: `docs(spa-carta): registrar o detalhe da carta na SPA`

---

## Phase Execution Map

```
Phase 1 → Phase 2 → Phase 3 → Phase 4

Phase 1:  T1, T2, T3, T4
Phase 2:  T5, T6, T7, T8, T9, T10
Phase 3:  T11, T12, T13, T14, T15, T16
Phase 4:  T17, T18, T19, T20, T21, T22
```

Execução estritamente sequencial, na ordem numérica dentro de cada phase; as dependências reais estão nos diagramas de cada phase.

---

## Task Granularity Check

| Task | Scope | Status |
| ---- | ----- | ------ |
| T1 | 2 métodos de classe no model + delegação | ✅ Coeso |
| T2 | 1 controller, 2 actions irmãs + rotas | ✅ Coeso |
| T3 | 1 action | ✅ Granular |
| T4 | 1 teste | ✅ Granular |
| T5 | 3 funções puras no mesmo arquivo | ✅ Coeso |
| T6 | 3 construtores de caminho no mesmo arquivo | ✅ Coeso |
| T7 | 1 função + os tipos que ela usa | ✅ Granular |
| T8–T10 | 1 módulo de estado cada | ✅ Granular |
| T11–T16 | 1 componente cada | ✅ Granular |
| T17 | 1 rota | ✅ Granular |
| T18 | 1 componente (modify) | ✅ Granular |
| T19–T21 | 1 spec e2e cada | ✅ Granular |
| T22 | docs | ✅ Granular |

## Diagram-Definition Cross-Check

| Task | Depends On (task body) | Diagram Shows | Status |
| ---- | ---------------------- | ------------- | ------ |
| T1 | None | — | ✅ |
| T2 | T1 | T1 → T2 | ✅ |
| T3 | T2 | T2 → T3 | ✅ |
| T4 | T2 | T2 → T4 | ✅ |
| T5 | None | — | ✅ |
| T6 | None | — | ✅ |
| T7 | T6 | T6 → T7 | ✅ |
| T8 | T6, T7 | T6 → T8, T7 → T8 | ✅ |
| T9 | None | — | ✅ |
| T10 | None | — | ✅ |
| T11 | T5 | T5 → T11 | ✅ |
| T12 | None | — | ✅ |
| T13 | T5, T10, T11 | T5/T10/T11 → T13 | ✅ |
| T14 | T5, T9 | T5/T9 → T14 | ✅ |
| T15 | T5, T6 | T5/T6 → T15 | ✅ |
| T16 | T5, T6, T11, T14, T15 | T5/T6/T11/T14/T15 → T16 | ✅ |
| T17 | T7, T8, T10, T12, T13, T16 | idem | ✅ |
| T18 | T6, T10 | T6/T10 → T18 | ✅ |
| T19 | T3, T17, T18 | T3/T17/T18 → T19 | ✅ |
| T20 | T4, T19 | T4/T19 → T20 | ✅ |
| T21 | T20 | T20 → T21 | ✅ |
| T22 | T21 | T21 → T22 | ✅ |

## Test Co-location Validation

| Task | Code Layer Created/Modified | Matrix Requires | Task Says | Status |
| ---- | --------------------------- | --------------- | --------- | ------ |
| T1 | Model Rails | unit | unit | ✅ |
| T2, T3 | Controller da API | integration | integration | ✅ |
| T4 | Concorrência | integration | integration | ✅ |
| T5, T6, T7 | Funções puras | unit | unit | ✅ |
| T8, T9, T10 | Estado | unit | unit | ✅ |
| T11–T18 | Componentes e página | unit | unit | ✅ |
| T19–T21 | Jornadas | e2e | e2e | ✅ |
| T22 | Docs | none | none | ✅ |
