# Decks na SPA — Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Design**: `.specs/features/spa-decks/design.md`
**Status**: Approved

**Pré-condição:** `spa-carta` e `spa-pasta` encerradas (estão) e nenhuma outra fatia
executando neste checkout. O commit-pai da T1 é a **base da feature** (`<base>` abaixo) e
é registrado na própria T1.

---

## Test Coverage Matrix

> Generated from codebase, project guidelines, and spec - confirm before Execute. Guidelines found: `CLAUDE.md` (gates do front e do Rails, armadilhas do Kit 3, teste de CSRF com `allow_forgery_protection` ligado no `setup`, teste de corrida com `use_transactional_tests = false`, "toda task termina com código que roda e teste que passa", e2e exige o catálogo importado), `frontend/src/lib/styles/guard.test.ts`, ESLint que proíbe `fetch` fora de `client.ts`. Amostras lidas: `test/integration/api/card_variants_test.rb` (helpers de sessão e CSRF), `test/integration/api/card_variants_concurrency_test.rb`, `test/integration/deck_entries_concurrency_test.rb`, `test/integration/deck_page_test.rb`, `frontend/src/lib/cards/ownership-queue.svelte.ts` e seu teste, `frontend/src/lib/components/OwnershipStepper.svelte`, `frontend/e2e/pasta.spec.ts`. O piso é o da `spa-pasta`; o alvo vem dos ACs do spec (strong default).

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| ---------- | ------------------ | -------------------- | ---------------- | ----------- |
| Model e objeto de consulta (`DeckEntry.increment_for!`, `DeckDetail`) | unit (model/query test) | Todos os ramos: criar, somar, teto, decrementar, apagar em 1, sem entrada; retrato com fora da fonte e falta por carta; deck alheio `RecordNotFound` | `test/models/*_test.rb`, `test/queries/*_test.rb` (novos) | Rails quick |
| Controller da API (`Api::DecksController`, `Api::DeckEntriesController`, `Api::DeckImportsController`, `Api::CardsController#show`) | integration (request test) | Cada endpoint: corpo exato do contrato; números iguais aos da tela HTML; 401 sem sessão; 422 `invalid_csrf_token` com `allow_forgery_protection` ligado; 404 de deck alheio e de carta inexistente; `user_id` alheio ignorado; `400 invalid_json`; `card_number` com caractere reservado; consultas constantes onde o spec pede; nunca HTML nem redirect | `test/integration/api/*_test.rb` (novos) | Rails quick |
| Concorrência | integration (`use_transactional_tests = false`) | Incrementos e decrementos simultâneos sobre a API somam todos, sem passar de 50 nem gravar abaixo de 1 | `test/integration/api/deck_entries_concurrency_test.rb` | Rails quick |
| Funções puras e estado (`lib/decks/*.ts`, `*.svelte.ts`) | unit | Todos os ramos, 1:1 com os ACs da task; codificação de caracteres reservados | `frontend/src/lib/**/*.test.ts` | Front quick |
| Componentes e páginas (`.svelte`) | unit (componente, jsdom) | Cada AC de tela: texto exato pt-BR com plurais 0/1/2, `href` exato, ARIA (`aria-current`, `aria-busy`, `aria-disabled`, `aria-describedby`, `aria-invalid`, `aria-live`), foco depois de `tick()`, carga lenta, erro, 404, resposta antiga descartada | `frontend/src/**/*.test.ts` | Front quick |
| Jornadas no navegador | e2e (Playwright contra a API real) | Paridade `/app/baralhos*` × `/decks*` e bloco da pasta × `/progress`; 360px e 1280px nos dois temas sem scroll horizontal; montagem pelo detalhe; importação de ida e volta | `frontend/e2e/*.spec.ts` | e2e |
| Docs (`CLAUDE.md`, `STATE.md`, `.context/tasks.md`, specs) | none | - | - | build gate only |

## Gate Check Commands

> Generated from codebase - confirm before Execute. Rodar as suítes em série, nunca em paralelo (flake D-10). `npm ci` com o serviço `frontend` de pé troca o `node_modules` sob o Vite: parar o serviço antes do quick ou reiniciá-lo depois. O e2e exige o catálogo importado no banco de dev (`ingestion:import SNAPSHOT=…`). Se o pull de imagem falhar pelo `credsStore` do host, `export DOCKER_CONFIG=$(mktemp -d)` com `{}` em `config.json`.

| Gate Level | When to Use | Command |
| ---------- | ----------- | ------- |
| Rails quick | Tasks do Rails | `docker compose exec app bin/rails test test/models test/queries test/integration && docker compose exec app bin/rubocop` |
| Front quick | Tasks do front com teste de unidade | `docker compose run --rm --no-deps frontend sh -c "npm ci && npm run check && npm run lint && npm test -- --run"` |
| Full | Tasks e2e e a última task do Rails | Front quick + `docker compose up -d app frontend && docker compose --profile e2e run --rm e2e` + `docker compose exec app bin/rails test` |
| Build | Fechamento | `docker build -f Dockerfile .` + Full + `docker compose exec app bin/rubocop` + `docker compose exec app bin/brakeman` + `git diff --name-status <base>..HEAD -- test/` só com `A` (SDEC-61) |

---

## Execution Plan

Phases are ordered and run sequentially - each phase completes before the next begins, and tasks within a phase execute in order. Cada diagrama traz todas as dependências das tasks da phase, inclusive as que vêm de phases anteriores.

### Phase 1: Extração no Rails (A1)

T1 e T2 não dependem de nada.

### Phase 2: API de decks (Rails)

```
T2 → T3
T3 → T4
T3 → T5
T1 → T6
T3 → T6
T6 → T7
T4 → T8
T3 → T9
T3 → T10
```

### Phase 3: Base do front

```
T11 → T12
```

T13 e T14 não dependem de nada.

### Phase 4: Componentes

```
T11 → T15
T11 → T16
T11 → T17
T13 → T17
T11 → T18
```

### Phase 5: Páginas e integração

```
T11 → T19
T12 → T19
T14 → T19
T15 → T20
T12 → T21
T16 → T21
T15 → T22
T16 → T22
T16 → T23
T11 → T24
T17 → T25
T18 → T26
```

### Phase 6: Ponta a ponta e fechamento

```
T3 → T27
T4 → T27
T5 → T27
T8 → T27
T19 → T27
T20 → T27
T21 → T27
T22 → T27
T23 → T27
T24 → T27
T6 → T28
T9 → T28
T10 → T28
T25 → T28
T26 → T28
T27 → T28
T7 → T29
T28 → T29
```

---

## Task Breakdown

### T1: `DeckEntry.increment_for!` / `decrement_for!`

**What**: Mover o SQL atômico de `DeckEntriesController#increment`/`#decrement` para dois métodos de classe em `DeckEntry` (`increment_for!(deck, card) → Integer | nil`, `decrement_for!(deck, card) → Integer | nil`), sem mudar o SQL, e fazer o controller HTML chamá-los com as mesmas respostas e mensagens. Registrar na task o hash do commit-pai (base da feature).
**Where**: `app/models/deck_entry.rb`
**Depends on**: None
**Reuses**: SQL de `app/controllers/deck_entries_controller.rb:42-101`, `CollectionItem.execute_returning_quantity` (binds `BigInteger`)
**Requirement**: SDEC-51, SDEC-52, SDEC-53, SDEC-56, SDEC-61

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Model test: incremento cria com 1, soma até 50 e devolve `nil` em 50 sem gravar; decremento devolve N-1, devolve `0` e apaga a linha em 1, devolve `nil` sem entrada
- [x] `DeckEntriesController` HTML só chama os dois métodos; nenhum SQL de entrada fica no controller
- [x] `deck_entries_test.rb`, `deck_leader_test.rb` e `deck_entries_concurrency_test.rb` passam sem edição
- [x] Gate check passes: Rails quick

**Tests**: unit
**Gate**: quick

**Base da feature (commit-pai da T1)**: `3beb228` (o plano aprovado; o commit `1238386` desenha a feature). `git diff --name-status 1238386..HEAD -- test/` só pode ter `A` (SDEC-61).

**Commit**: `refactor(spa-decks): mover o SQL atômico de entrada de deck para o model`

---

### T2: `DeckDetail`

**What**: Criar `DeckDetail.new(user:, deck_id:).call → Result(deck, legality, absent_card_ids, shortfall_by_card_id)` com o retrato `REPEATABLE READ` e o cálculo de cartas fora da fonte que hoje estão em `DecksController`, e fazer `DecksController#show` usá-lo, com a mesma página e o mesmo `.txt`.
**Where**: `app/queries/deck_detail.rb`
**Depends on**: None
**Reuses**: `consistent_snapshot` e `absent_card_ids` de `app/controllers/decks_controller.rb:111-123`, `DeckShortfallQuery.new(user, deck:)`, `Deck#legality`, forma de `app/queries/card_detail.rb`
**Requirement**: SDEC-47, SDEC-61

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Query test: deck do usuário com Leader e entradas devolve `legality` igual a `Deck::Legality`, `absent_card_ids` só com a carta sem variante presente e `shortfall_by_card_id` com `required`/`owned`/`missing` por carta; deck de outro usuário e id inexistente levantam `RecordNotFound`
- [x] Dentro de transação aberta não pede `REPEATABLE READ` (sem `TransactionIsolationError`)
- [x] `deck_page_test.rb`, `deck_shortfall_page_test.rb`, `deck_export_test.rb` e `deck_entries_concurrency_test.rb` passam sem edição
- [x] Gate check passes: Rails quick

**Tests**: unit
**Gate**: quick

**Commit**: `refactor(spa-decks): extrair a leitura da página do deck para DeckDetail`

---

### T3: `GET /api/decks` e `GET /api/decks/:id`

**What**: Criar `Api::DecksController` com `index` e `show` (inclui `EditingDeck`), as views `index.json.jbuilder`, `_summary.json.jbuilder` e `show.json.jbuilder`, e as rotas `resources :decks, only: %i[index show]` no `scope "api"`, acima do catch-all, devolvendo os formatos do SDEC-43 e do SDEC-47.
**Where**: `app/controllers/api/decks_controller.rb`
**Depends on**: T2
**Reuses**: `DeckDetail`, `Deck#legality`, `#ordered_entries`, `#main_total`, `editing_deck`, helpers de `test/integration/api/card_variants_test.rb:33-51`
**Requirement**: SDEC-43, SDEC-47, SDEC-60

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] `index`: decks do usuário por nome e id, cada um com `id`, `name`, `leader` (`{card_number, name}` ou `null`), `main_total` e `status` igual ao da lista `/decks`; deck de outro usuário ausente; consultas iguais com 1 e 3 decks (SDEC-43)
- [x] `show`: todos os campos do SDEC-47; `entries` na ordem de `ordered_entries`; `required`/`owned`/`missing`, `in_source`, `cost: null` de Event, `missing_total` e `reasons`/`warnings` iguais aos de `/decks/:id` para um deck vazio, um incompleto, um inválido por cor e um com Leader de regra própria; `editing` verdadeiro só para o deck da sessão (SDEC-47)
- [x] Sem sessão → `401`; deck de outro usuário e id inexistente → `404 not_found`; `user_id` alheio na query ignorado; resposta JSON, nunca redirect (SDEC-60)
- [x] Gate check passes: Rails quick

**Tests**: integration
**Gate**: quick

**Commit**: `feat(spa-decks): expor a lista e o deck na API`

---

### T4: `POST /api/decks` e `PATCH /api/decks/:id`

**What**: Acrescentar `create` e `update` ao `Api::DecksController` (nome no topo do corpo, só `String`), com `start_editing` na criação, resposta `201`/`200` no formato do `show` e recusa `422 validation_failed` com `fields.name` em frase inteira.
**Where**: `app/controllers/api/decks_controller.rb` (modify)
**Depends on**: T3
**Reuses**: `Deck` (`normalizes :name`, mensagens de `NAME_LENGTH`), `start_editing`, `render_error`
**Requirement**: SDEC-44, SDEC-45, SDEC-46, SDEC-60

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Criar com nome válido → `201`, deck vazio do usuário da sessão, e o `GET /decks` HTML mostra "Em edição" nele (SDEC-44)
- [x] Renomear muda só o nome → `200` no formato do `show`; Leader e entradas intactos (SDEC-45)
- [x] Nome ausente, não-`String`, só espaços → `fields.name == ["O nome não pode ficar vazio."]`; 61 caracteres → `["O nome pode ter no máximo 60 caracteres."]`; nada gravado (SDEC-46)
- [x] Sem token com `allow_forgery_protection` ligado → `422 invalid_csrf_token`; `user_id` alheio no corpo ignorado; renomear deck de outro usuário → `404`; JSON malformado → `400 invalid_json` (SDEC-60)
- [x] Gate check passes: Rails quick

**Tests**: integration
**Gate**: quick

**Commit**: `feat(spa-decks): criar e renomear deck pela API`

---

### T5: `DELETE /api/decks/:id` e `POST /api/decks/:id/select`

**What**: Acrescentar `destroy` e `select` ao `Api::DecksController` e a rota `member { post :select }`, ambos com `200 { id, name }`.
**Where**: `app/controllers/api/decks_controller.rb` (modify)
**Depends on**: T3
**Reuses**: `deck.destroy!`, `start_editing`, `session[:editing_deck_id]`
**Requirement**: SDEC-48, SDEC-49, SDEC-60

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Excluir apaga deck e entradas, mantém coleção e wishlist do usuário; o deck excluído some do `/decks` HTML e o `/decks/:id` HTML seguinte não mostra "Em edição" para nenhum deck (SDEC-48)
- [x] `select` grava a chave que o Hotwire lê: depois dele, `/decks/:id` HTML mostra "Em edição"; repetir não muda nada (SDEC-49)
- [x] Sem sessão `401`, sem token `422 invalid_csrf_token`, deck alheio `404` nos dois, sem gravar (SDEC-60)
- [x] Gate check passes: Rails quick

**Tests**: integration
**Gate**: quick

**Commit**: `feat(spa-decks): excluir e escolher o deck em edição pela API`

---

### T6: Entradas e Leader do deck na API

**What**: Criar `Api::DeckEntriesController` (`increment`, `decrement`, `leader`) com `set_deck` em `Current.user.decks`, `set_card` por `card_number`, `rescue_from InvalidForeignKey` → `not_found`, as views jbuilder e as três rotas com `constraints: { card_number: /[^\/]+/ }`.
**Where**: `app/controllers/api/deck_entries_controller.rb`
**Depends on**: T1, T3
**Reuses**: `DeckEntry.increment_for!`/`decrement_for!`, frases de `app/controllers/deck_entries_controller.rb`, `render_error`
**Requirement**: SDEC-51, SDEC-52, SDEC-53, SDEC-54, SDEC-55, SDEC-60

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] `increment` cria com 1 e soma → `200 { card_number, quantity }`; em 50 → `422` "O máximo é 50 cópias por carta no deck." sem gravar; carta Leader → `422` "<card_number> é um Leader; use “Usar como Leader” em vez de somar cópias." (SDEC-51, SDEC-53, SDEC-54)
- [x] `decrement` → `200` com N-1; em 1 apaga a linha e responde `0`; sem entrada → `200` com `quantity: 0` sem gravar (SDEC-52)
- [x] `leader` com Leader grava ou troca sem tocar entradas → `200 { leader_card_number }`; com não-Leader → `422` "<card_number> não é um Leader; use “+” para somar cópias ao deck."; `card_number` ausente ou não-`String` → `404` (SDEC-55)
- [x] `card_number` `P-117` e com ponto codificados no caminho funcionam; carta inexistente `404`; deck alheio `404`; sem sessão `401`; sem token `422 invalid_csrf_token`; nada gravado nos casos de erro (SDEC-60)
- [x] Gate check passes: Rails quick

**Tests**: integration
**Gate**: quick

**Commit**: `feat(spa-decks): somar, tirar e escolher o Leader do deck pela API`

---

### T7: Corrida das entradas na API

**What**: Teste de concorrência sobre `POST /api/decks/:id/cards/:card_number/increment` e `/decrement`, no molde do `deck_entries_concurrency_test.rb`, com sobreposição forçada por lock.
**Where**: `test/integration/api/deck_entries_concurrency_test.rb`
**Depends on**: T6
**Reuses**: `test/integration/deck_entries_concurrency_test.rb`, `test/integration/api/card_variants_concurrency_test.rb`
**Requirement**: SDEC-56

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] N incrementos simultâneos somam N; incrementos a partir de 48 param em 50 com os excedentes `422`; decrementos simultâneos a partir de 2 deixam a linha apagada e nenhum `quantity` abaixo de 1 gravado
- [x] `use_transactional_tests = false` com limpeza no `teardown`; o teste falha se o SQL atômico for trocado por ler-e-gravar (conferido localmente, não commitado)
- [x] Gate check passes: Rails quick

**Tests**: integration
**Gate**: quick

**Commit**: `test(spa-decks): provar a atomicidade das entradas de deck na API`

---

### T8: `POST /api/decks/import`

**What**: Criar `Api::DeckImportsController#create` e a rota `post "decks/import"` antes de `resources :decks`: `Deck::ListText.parse`, recusa com `fields.list` por linha, criação com nome padrão do Leader, `start_editing` e `201` no formato do `show`.
**Where**: `app/controllers/api/deck_imports_controller.rb`
**Depends on**: T4
**Reuses**: `Deck::ListText.parse`, montagem de `app/controllers/deck_imports_controller.rb:22-39`, a recusa de nome da T4
**Requirement**: SDEC-46, SDEC-57, SDEC-58, SDEC-60

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] O texto de `GET /decks/:id.txt` importado cria deck com o mesmo Leader e as mesmas entradas e o torna o deck em edição → `201` (SDEC-57)
- [x] Sem nome com Leader → nome do Leader; sem nome e sem Leader → `fields.name == ["O nome não pode ficar vazio."]` (SDEC-46)
- [x] Lista com duas linhas ruins → `422`, `message` "A lista não foi importada. Nenhum deck foi criado.", `fields.list` == `["Linha 2: …", "Linha 5: …"]` na ordem; 201 linhas e 10.001 caracteres → o limite sem número de linha; `list` ausente → "A lista não tem nenhuma carta"; contagem de decks inalterada (SDEC-58)
- [x] Sem sessão `401`, sem token `422 invalid_csrf_token`, `user_id` alheio ignorado (SDEC-60)
- [x] Gate check passes: Rails quick

**Tests**: integration
**Gate**: quick

**Commit**: `feat(spa-decks): importar a lista do OPTCG Simulator pela API`

---

### T9: `GET /api/decks/shortfall`

**What**: Acrescentar `shortfall` ao `Api::DecksController`, com a rota `get "decks/shortfall"` antes de `resources :decks`, devolvendo só as cartas com `missing > 0`, por `card_number`, cada uma com os decks `{ id, name }` por id.
**Where**: `app/controllers/api/decks_controller.rb` (modify)
**Depends on**: T3
**Reuses**: `DeckShortfallQuery.new(user)`, filtro de `app/controllers/progress_controller.rb:46-51`
**Requirement**: SDEC-59, SDEC-60

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Para dois decks que dividem uma carta, as cartas, `missing` e decks são os mesmos do bloco de `/progress`; cartas completas ficam de fora; sem decks → `[]` (SDEC-59)
- [x] Consultas: duas com linhas, uma sem; iguais com 1 e 3 decks
- [x] Sem sessão `401`; decks de outro usuário nunca aparecem (SDEC-60)
- [x] Gate check passes: Rails quick

**Tests**: integration
**Gate**: quick

**Commit**: `feat(spa-decks): expor o que falta para os decks na API`

---

### T10: `editing_deck` no detalhe da carta

**What**: Incluir `EditingDeck` em `Api::CardsController` e o campo `editing_deck` (`{ id, name, quantity, is_leader }` ou `null`) em `cards/show.json.jbuilder`, ao lado de `featured_variant_code`.
**Where**: `app/controllers/api/cards_controller.rb` (modify)
**Depends on**: T3
**Reuses**: `editing_deck` (já faz `authenticated?` e apaga chave de deck sumido)
**Requirement**: SDEC-50

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Sem sessão → `editing_deck: null`; com sessão sem deck em edição → `null`; com deck → `quantity` 0 sem entrada e N com entrada, `is_leader` verdadeiro só para o Leader do deck
- [x] Depois de excluir o deck em edição (pelo HTML ou pela API) → `null`
- [x] Os demais campos do `GET /api/cards/:card_number` iguais aos de antes (os testes de `cards` existentes passam sem edição); consultas a mais só com sessão e deck em edição, em número fixo
- [x] Gate check passes: Full (última task do Rails)

**Tests**: integration
**Gate**: full

**Commit**: `feat(spa-decks): mostrar o deck em edição no detalhe da carta pela API`

---

### T11: Tipos e caminhos de deck no front

**What**: Acrescentar os tipos do design (`DeckSummary`, `DeckLine`, `DeckEntryLine`, `DeckPayload`, `DeckRef`, `ShortfallCard`, `DeckEntryResult`, `EditingDeck`, `editing_deck` em `CardDetailPayload`) a `src/lib/api/types.ts` e criar `src/lib/decks/url.ts` com `deckHref(id, sub?)`, `deckApiPath(id, sub?)` e `deckCardApiPath(id, cardNumber, op)`.
**Where**: `frontend/src/lib/decks/url.ts`
**Depends on**: None
**Reuses**: `appPath`, padrão de `frontend/src/lib/cards/url.ts`
**Requirement**: SDEC-07, SDEC-25, SDEC-26, SDEC-51

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Unit test: `deckHref(7)` → `/app/baralhos/7`, `deckHref(7, 'renomear')` → `/app/baralhos/7/renomear`; `deckCardApiPath(7, 'P-117', 'increment')` e com espaço/ponto codificados por `encodeURIComponent`; `deckApiPath(7, 'leader')` → `/api/decks/7/leader`
- [x] `npm run check` passa com os tipos novos usados pelo menos pelo teste
- [x] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-decks): tipos e caminhos de deck no front`

---

### T12: Rótulos e grupos de deck

**What**: Criar `src/lib/decks/labels.ts` com `statusLabel`, `groupLabel` (outro valor com inicial maiúscula), `groupEntries` (corta a cada troca de `card_type`, na ordem recebida) e `missingSentence` (as quatro frases do SDEC-24).
**Where**: `frontend/src/lib/decks/labels.ts`
**Depends on**: T11
**Reuses**: `DECK_STATUS_LABELS` e `DECK_GROUP_LABELS` de `app/helpers/decks_helper.rb`
**Requirement**: SDEC-07, SDEC-21, SDEC-24, SDEC-26

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] `statusLabel` dá "válido", "incompleto", "inválido"
- [x] `groupLabel` dá "Personagens", "Eventos", "Locais" e "Don" para `don`
- [x] `groupEntries` em `[character, character, event, character]` dá três grupos, sem reordenar
- [x] `missingSentence` para deck sem Leader e sem entradas, `missing_total` 0, 1 e 3 dá as quatro frases exatas do SDEC-24
- [x] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-decks): rótulos de status e grupos do deck`

---

### T13: `QuantityStepper` e fila generalizada (B1, AD-030)

**What**: Mudar `createOwnershipQueue` para `send: (op) => Promise<number>`, extrair `QuantityStepper.svelte` (props `confirmed`, `send`, `bind:displayed`, `decrementLabel`, `incrementLabel`, `refusedMessage`, `quantityText`, `settledText`) e reescrever `OwnershipStepper` como invólucro dele, com a mesma marcação, e o `VariantRow` mapeando `r => r.owned_quantity`.
**Where**: `frontend/src/lib/components/QuantityStepper.svelte`
**Depends on**: None
**Reuses**: `frontend/src/lib/cards/ownership-queue.svelte.ts`, `frontend/src/lib/components/OwnershipStepper.svelte`
**Requirement**: SDEC-35, SDEC-36, SDEC-37

**Tools**:

- MCP: Svelte (`svelte-autofixer`)
- Skill: `svelte:svelte-core-bestpractices`

**Done when**:

- [x] Teste do `QuantityStepper`: rótulos e frase de recusa vêm das props; `−` em zero tem `aria-disabled="true"`, é focável, não chama `send` e anuncia a recusa; cinco `+` rápidos mostram 1..5 e chamam `send` cinco vezes em série; falha no 3º volta ao confirmado e chama o erro
- [x] Os testes de `OwnershipStepper`, `VariantRow`, da fila e da página da carta passam sem edição de asserção (só o mock do `send` pode mudar de forma, registrado na task)
- [x] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `refactor(spa-decks): generalizar o stepper otimista em QuantityStepper`

---

### T14: Entrada "Baralhos" na SPA

**What**: Trocar `hotwire("Baralhos", "/decks")` por `inApp("Baralhos", "/baralhos")` em `nav-entries.ts`.
**Where**: `frontend/src/lib/navigation/nav-entries.ts` (modify)
**Depends on**: None
**Reuses**: `inApp`, `MainNav.isCurrent`
**Requirement**: SDEC-02

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Unit test: com sessão, "Baralhos" aponta para `/app/baralhos` sem `reload`; `MainNav` marca `aria-current="page"` em `/app/baralhos` e `/app/baralhos?x=1`, e não em `/app/baralhos/7`
- [x] Testes de casco existentes que esperavam `/decks` atualizados só nessa asserção (registrado na task)
- [x] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-decks): levar a entrada Baralhos para a SPA`

---

### T15: `DeckNameForm`

**What**: Criar `DeckNameForm.svelte` (rótulo "Nome do deck (até 60 caracteres)", `maxlength="60"`, valor inicial, `Button pending`, envio repetido ignorado, `fields.name` no campo com foco) e a prop opcional `maxlength` em `TextField`.
**Where**: `frontend/src/lib/components/DeckNameForm.svelte`
**Depends on**: T11
**Reuses**: `TextField` (`errors`, `focus()`), `Button`, `distribute` de `criar-conta/+page.svelte:29-39`
**Requirement**: SDEC-10, SDEC-13, SDEC-14

**Tools**:

- MCP: Svelte (`svelte-autofixer`)
- Skill: `svelte:svelte-core-bestpractices`

**Done when**:

- [x] Rótulo, `required` e `maxlength="60"`; valor inicial preenchido (SDEC-10)
- [x] `submit` que rejeita com `validation_failed` e `fields.name` mostra a mensagem ligada por `aria-describedby`, `aria-invalid="true"`, foco no campo depois de `tick()` e valor mantido; outro erro vai para `FormError` (SDEC-13)
- [x] Segundo envio com o primeiro pendente não chama `submit` e o botão fica desabilitado (SDEC-14)
- [x] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-decks): formulário de nome do deck`

---

### T16: `DeckNotFound`

**What**: Criar `DeckNotFound.svelte` com o título de página "Deck não encontrado — Bindr", a `message` recebida e o link "Voltar aos baralhos" para `/app/baralhos`.
**Where**: `frontend/src/lib/components/DeckNotFound.svelte`
**Depends on**: T11
**Reuses**: `<svelte:head>` das rotas existentes
**Requirement**: SDEC-18

**Tools**:

- MCP: Svelte (`svelte-autofixer`)
- Skill: NONE

**Done when**:

- [ ] Renderiza `document.title` "Deck não encontrado — Bindr", a mensagem e o link com `href` `/app/baralhos`
- [ ] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-decks): tela de deck não encontrado`

---

### T17: `EditingDeckPanel`

**What**: Criar `EditingDeckPanel.svelte`: seção "Deck em edição" com o link do deck, `QuantityStepper` de cópias para carta comum (rótulos do SDEC-35, recusa do SDEC-37, texto "N cópias de <nome> no deck" em `aria-live="polite"`) e, para Leader, "Usar como Leader" não otimista ou o botão `aria-disabled` de Leader atual.
**Where**: `frontend/src/lib/components/EditingDeckPanel.svelte`
**Depends on**: T11, T13
**Reuses**: `QuantityStepper`, `api.post`/`api.put`, `deckCardApiPath`, `deckApiPath`, `deckHref`, `Button pending`, `notifySuccess`/`notifyError`, `copies` de `lib/format.ts`
**Requirement**: SDEC-33, SDEC-35, SDEC-36, SDEC-37, SDEC-38, SDEC-39

**Tools**:

- MCP: Svelte (`svelte-autofixer`)
- Skill: `svelte:svelte-core-bestpractices`

**Done when**:

- [ ] "As cartas vão para o deck <nome>" com link para `/app/baralhos/<id>` (SDEC-33)
- [ ] Carta comum com 0, 1 e 2: "0 cópias de X no deck", "1 cópia…", "2 cópias…" na região viva; nomes acessíveis dos botões exatos; alvos com `min-block-size`/`min-inline-size` de 44px (SDEC-35)
- [ ] Três `+` enviam três `POST` em série a `/api/decks/<id do payload>/cards/<cn>/increment`; falha `422` do teto volta ao confirmado e mostra a `message` (SDEC-36)
- [ ] `−` em 0 não chama o cliente e anuncia "<cn> não está no deck “<deck>”." (SDEC-37)
- [ ] Leader sem `is_leader`: botão com nome acessível "Usar <nome> como Leader do deck <deck>"; sucesso envia `PUT …/leader` com `{ card_number }`, troca para "<nome> é o Leader deste deck" `aria-disabled` focável sem envio e mostra "<cn> é o Leader do deck “<deck>”." (SDEC-38, SDEC-39)
- [ ] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-decks): controle do deck em edição no detalhe da carta`

---

### T18: `DeckShortfall`

**What**: Criar `DeckShortfall.svelte` com carregador próprio de `GET /api/decks/shortfall`: bloco "Faltando para os baralhos" com cada carta (link, `code`, "falta 1"/"faltam N", "Em" + links dos decks separados por ", "), nada no DOM sem cartas e erro com "Tentar novamente" só no bloco.
**Where**: `frontend/src/lib/components/DeckShortfall.svelte`
**Depends on**: T11
**Reuses**: `createLoader`, `cardDetailHref`, `deckHref`
**Requirement**: SDEC-40, SDEC-41, SDEC-42

**Tools**:

- MCP: Svelte (`svelte-autofixer`)
- Skill: NONE

**Done when**:

- [ ] Lista vazia → nada no DOM, nem cabeçalho (SDEC-41)
- [ ] "falta 1" e "faltam 2"; carta em dois decks com dois links na ordem da API separados por ", " (SDEC-40)
- [ ] Erro → `message` + "Tentar novamente", que repete a consulta (SDEC-42)
- [ ] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-decks): bloco do que falta para os decks`

---

### T19: Rota `/app/baralhos`

**What**: Criar `baralhos/+page.ts` (`requireSession`) e `baralhos/+page.svelte` com a lista de decks por `createLoader`, carga lenta, erro, lista vazia e as ações "Novo deck" e "Importar lista".
**Where**: `frontend/src/routes/baralhos/+page.svelte`
**Depends on**: T11, T12, T14
**Reuses**: `createLoader`, `requireSession`, `statusLabel`, `deckHref`, padrão de `pasta/+page.svelte`
**Requirement**: SDEC-01, SDEC-03, SDEC-04, SDEC-05, SDEC-06, SDEC-07, SDEC-08, SDEC-09

**Tools**:

- MCP: Svelte (`svelte-autofixer`)
- Skill: NONE

**Done when**:

- [ ] Sem sessão, o `load` redireciona para `/app/entrar?return_to=%2Fapp%2Fbaralhos` sem chamar o cliente (SDEC-03)
- [ ] Título "Baralhos — Bindr" e `h1` "Baralhos" (SDEC-01)
- [ ] Deck com e sem Leader, os três status, "N / 50", `h2` com link para `/app/baralhos/<id>` (SDEC-07); lista vazia (SDEC-08); links das ações (SDEC-09)
- [ ] Antes de 200 ms nada muda; depois, `aria-busy="true"` e "Carregando baralhos…"; resposta antiga descartada; erro com "Tentar novamente" (SDEC-04..06)
- [ ] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-decks): lista de decks na SPA`

---

### T20: Rota `/app/baralhos/novo`

**What**: Criar `baralhos/novo/+page.ts` e `+page.svelte` com `DeckNameForm` enviando `POST /api/decks`, levando ao deck criado com "Deck criado.".
**Where**: `frontend/src/routes/baralhos/novo/+page.svelte`
**Depends on**: T15
**Reuses**: `DeckNameForm`, `requireSession`, `deckHref`, `notifySuccess`
**Requirement**: SDEC-03, SDEC-10, SDEC-11

**Tools**:

- MCP: Svelte (`svelte-autofixer`)
- Skill: NONE

**Done when**:

- [ ] Título e `h1` "Novo deck"; campo vazio (SDEC-10); sem sessão redireciona (SDEC-03)
- [ ] Sucesso chama `POST /api/decks` com `{ name }`, navega a `/app/baralhos/<id>` e mostra "Deck criado." (SDEC-11)
- [ ] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-decks): criar deck pela SPA`

---

### T21: Rota `/app/baralhos/[id]`

**What**: Criar `baralhos/[id]/+page.ts` e `+page.svelte` com o deck por `createLoader`: título, "Em edição" ou "Editar este deck", status e motivos, avisos de Leader, banidas, "Na sua pasta", Leader, deck principal em grupos com "pedida, possuída, falta", fora da fonte, ações e 404.
**Where**: `frontend/src/routes/baralhos/[id]/+page.svelte`
**Depends on**: T12, T16
**Reuses**: `createLoader`, `labels.ts`, `DeckNotFound`, `cardDetailHref`, `Button pending`, `notifySuccess`
**Requirement**: SDEC-03, SDEC-04, SDEC-05, SDEC-06, SDEC-17, SDEC-18, SDEC-19, SDEC-20, SDEC-21, SDEC-22, SDEC-23, SDEC-24, SDEC-25, SDEC-26, SDEC-27, SDEC-28, SDEC-29

**Tools**:

- MCP: Svelte (`svelte-autofixer`)
- Skill: NONE

**Done when**:

- [ ] Título "<nome> — Bindr" e `h1` (SDEC-17); `404` → `DeckNotFound` (SDEC-18); outro erro → "Tentar novamente"; carga lenta "Carregando deck…"; resposta de outro id descartada (SDEC-04..06)
- [ ] `editing: true` → "Em edição"; senão "Editar este deck" envia `POST …/select` e troca para "Em edição" com "Agora as cartas vão para o deck “<nome>”." (SDEC-19, SDEC-20)
- [ ] "Status: <rótulo>", motivos só fora de `valid`, aviso com cabeçalho e `<blockquote>`, "A lista de banidas não é verificada" sempre (SDEC-21..23)
- [ ] As quatro frases de "Na sua pasta" (SDEC-24); Leader com link ou "Sem Leader" (SDEC-25); "Deck principal: N / 50", `h3` por troca de tipo, "N×", link, "custo N" só com `cost` (SDEC-26); "carta fora da fonte" (SDEC-27); "pedida N, possuída N, falta N" (SDEC-28)
- [ ] "Exportar lista" com `href` `/decks/<id>.txt` e recarga; "Renomear", "Excluir" e "Voltar aos baralhos" sem recarga (SDEC-29)
- [ ] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-decks): página do deck na SPA`

---

### T22: Rota `/app/baralhos/[id]/renomear`

**What**: Criar `baralhos/[id]/renomear/+page.ts` e `+page.svelte`: carrega o deck (nome atual, 404), `DeckNameForm` enviando `PATCH /api/decks/:id`, e volta à página do deck com "Deck renomeado.".
**Where**: `frontend/src/routes/baralhos/[id]/renomear/+page.svelte`
**Depends on**: T15, T16
**Reuses**: `createLoader`, `DeckNameForm`, `DeckNotFound`, `notifySuccess`
**Requirement**: SDEC-03, SDEC-10, SDEC-12, SDEC-18

**Tools**:

- MCP: Svelte (`svelte-autofixer`)
- Skill: NONE

**Done when**:

- [ ] Título e `h1` "Renomear deck"; campo com o nome atual (SDEC-10); `404` → `DeckNotFound` (SDEC-18)
- [ ] Sucesso envia `PATCH` com `{ name }`, navega à página do deck e mostra "Deck renomeado." (SDEC-12)
- [ ] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-decks): renomear deck pela SPA`

---

### T23: Rota `/app/baralhos/[id]/excluir`

**What**: Criar `baralhos/[id]/excluir/+page.ts` e `+page.svelte`: confirmação com os textos do SDEC-15, "Excluir deck" (`Button pending`) enviando `DELETE` só depois do toque, e volta à lista com "Deck “<nome>” excluído.".
**Where**: `frontend/src/routes/baralhos/[id]/excluir/+page.svelte`
**Depends on**: T16
**Reuses**: `createLoader`, `DeckNotFound`, `Button`, `notifySuccess`/`notifyError`
**Requirement**: SDEC-03, SDEC-15, SDEC-16, SDEC-18

**Tools**:

- MCP: Svelte (`svelte-autofixer`)
- Skill: NONE

**Done when**:

- [ ] Título "Excluir deck — Bindr", cabeçalho "Excluir o deck “<nome>”?", texto, botão e "Cancelar" para a página do deck; abrir só chama o `GET` (SDEC-15)
- [ ] Confirmar envia `DELETE`, navega a `/app/baralhos` só depois do `200` e mostra "Deck “<nome>” excluído."; erro mantém a tela com `notifyError` (SDEC-16)
- [ ] `404` → `DeckNotFound` (SDEC-18)
- [ ] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-decks): excluir deck pela SPA`

---

### T24: Rota `/app/baralhos/importar`

**What**: Criar `baralhos/importar/+page.ts` e `+page.svelte` com o texto, o nome opcional, a área de texto obrigatória, o envio a `POST /api/decks/import` e a recusa num `FormError` focado com `message` e cada linha de `fields.list`.
**Where**: `frontend/src/routes/baralhos/importar/+page.svelte`
**Depends on**: T11
**Reuses**: `TextField`, `FormError`, `Button pending`, `requireSession`, `deckHref`, `notifySuccess`
**Requirement**: SDEC-03, SDEC-30, SDEC-31, SDEC-32

**Tools**:

- MCP: Svelte (`svelte-autofixer`)
- Skill: NONE

**Done when**:

- [ ] Título, cabeçalho, texto explicativo, rótulos exatos, `maxlength="60"` no nome, área obrigatória, botão e link (SDEC-30)
- [ ] Sucesso navega ao deck criado e mostra "Deck importado." (SDEC-31)
- [ ] Recusa com três linhas: resumo `role="alert"` focado com a `message` e as três linhas na ordem, área com `aria-describedby` do resumo e `aria-invalid="true"`, nome e lista mantidos; `fields.name` vai ao campo de nome (SDEC-32)
- [ ] Envio repetido ignorado enquanto pendente
- [ ] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-decks): importar lista pela SPA`

---

### T25: Deck em edição no detalhe da carta

**What**: Montar `EditingDeckPanel` em `cartas/[card_number]/+page.svelte`, dentro do `{#key detailKey}` e depois de "Variantes na pasta", só com sessão e `editing_deck` não nulo.
**Where**: `frontend/src/routes/cartas/[card_number]/+page.svelte` (modify)
**Depends on**: T17
**Reuses**: `EditingDeckPanel`, `detailKey`
**Requirement**: SDEC-33, SDEC-34, SDEC-36

**Tools**:

- MCP: Svelte (`svelte-autofixer`)
- Skill: NONE

**Done when**:

- [ ] Payload com `editing_deck: null` ou sem sessão → sem seção "Deck em edição" (SDEC-34); com deck → seção presente (SDEC-33)
- [ ] Trocar de carta com `+` pendente descarta o não enviado e não aplica a resposta antiga à carta nova (edge case)
- [ ] Testes existentes da página da carta passam sem edição
- [ ] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-decks): ligar o deck em edição ao detalhe da carta`

---

### T26: Bloco de falta na pasta

**What**: Montar `DeckShortfall` em `pasta/+page.svelte`, dentro do grupo de ações secundárias, antes dos links, com carga independente da pasta.
**Where**: `frontend/src/routes/pasta/+page.svelte` (modify)
**Depends on**: T18
**Reuses**: `DeckShortfall`
**Requirement**: SDEC-40, SDEC-41, SDEC-42

**Tools**:

- MCP: Svelte (`svelte-autofixer`)
- Skill: NONE

**Done when**:

- [ ] Com o progresso e o shortfall respondendo em ordens diferentes, cada parte aparece quando a sua chega (edge case); falha do shortfall não altera indicadores nem sets (SDEC-42)
- [ ] O bloco fica antes do primeiro link de ação; sem cartas, nada (SDEC-40, SDEC-41)
- [ ] Testes existentes da página da pasta passam sem edição de asserção (o mock do cliente passa a responder também ao shortfall)
- [ ] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-decks): mostrar na pasta o que falta para os decks`

---

### T27: E2E das telas de deck

**What**: Playwright contra a API real: casco → `/app/baralhos` sem recarga e paridade com `/decks`; criar, renomear e excluir conferindo no Hotwire; paridade de `/app/baralhos/<id>` com `/decks/<id>` para deck vazio, incompleto, inválido por cor e válido, a 360px e 1280px nos dois temas sem scroll horizontal; importação de ida e volta e lista com duas linhas ruins.
**Where**: `frontend/e2e/baralhos.spec.ts`
**Depends on**: T3, T4, T5, T8, T19, T20, T21, T22, T23, T24
**Reuses**: `createOwner`/`openAs`/`csrfToken` de `frontend/e2e/pasta.spec.ts`, montagem de deck pela API
**Requirement**: SDEC-01, SDEC-02, SDEC-07, SDEC-11, SDEC-12, SDEC-16, SDEC-17, SDEC-21, SDEC-24, SDEC-26, SDEC-28, SDEC-31, SDEC-32

**Tools**:

- MCP: NONE
- Skill: `ecc:e2e-testing`

**Done when**:

- [ ] "Baralhos" no casco abre `/app/baralhos` sem recarga, com a mesma sequência de nomes, Leaders, totais e status de `/decks` (SDEC-01, SDEC-02, SDEC-07)
- [ ] Criar, renomear e excluir pela SPA aparecem em `/decks` (SDEC-11, SDEC-12, SDEC-16)
- [ ] Para os quatro decks, status, motivos, aviso, "Na sua pasta", grupos, ordem e "pedida, possuída, falta" iguais aos de `/decks/<id>`, a 360px e 1280px, nos dois temas, sem scroll horizontal (SDEC-17, SDEC-21, SDEC-24, SDEC-26, SDEC-28)
- [ ] Texto de `/decks/<id>.txt` colado em `/app/baralhos/importar` gera deck com o mesmo Leader e entradas; duas linhas ruins mostram as duas e não criam deck (SDEC-31, SDEC-32)
- [ ] Gate check passes: Full

**Tests**: e2e
**Gate**: full

**Commit**: `test(spa-decks): telas de deck contra a API real`

---

### T28: E2E da montagem pelo detalhe e do bloco da pasta

**What**: Playwright: escolher o deck em `/app/baralhos/<id>`, abrir uma carta, `+` três vezes e ver `3×` na página do deck; cinco toques rápidos deixam `+5` igual ao `GET` seguinte; montar 1 Leader + 50 (a maior parte pela API, Leader e algumas cópias pela SPA) e ver `válido` na SPA e em `/decks`; bloco "Faltando para os baralhos" igual ao de `/progress`.
**Where**: `frontend/e2e/baralhos-montagem.spec.ts`
**Depends on**: T6, T9, T10, T25, T26, T27
**Reuses**: helpers de `frontend/e2e/baralhos.spec.ts` e `pasta.spec.ts`
**Requirement**: SDEC-20, SDEC-33, SDEC-35, SDEC-36, SDEC-38, SDEC-39, SDEC-40, SDEC-56

**Tools**:

- MCP: NONE
- Skill: `ecc:e2e-testing`

**Done when**:

- [ ] "Editar este deck" na SPA, depois a carta: seção "Deck em edição" com o deck; três `+` → `3×` na página do deck (SDEC-20, SDEC-33, SDEC-35)
- [ ] Cinco toques rápidos → `+5` e o número igual ao do `GET /api/decks/:id` seguinte (SDEC-36)
- [ ] "Usar como Leader" na carta Leader e entradas até 50 → `válido` em `/app/baralhos/<id>` e em `/decks/<id>` (SDEC-38, SDEC-39)
- [ ] O bloco da `/app/pasta` traz as mesmas cartas, faltas e decks que o da `/progress` (SDEC-40)
- [ ] Gate check passes: Full

**Tests**: e2e
**Gate**: full

**Commit**: `test(spa-decks): montagem pelo detalhe e falta na pasta contra a API real`

---

### T29: Fechamento da documentação

**What**: Atualizar `CLAUDE.md` (estado da `spa-decks`, rotas novas na tabela da API, módulos e armadilhas, `QuantityStepper`), a traceability do spec para `Implemented`, a §16 nova do `.context/tasks.md`, o *Handoff* do `STATE.md`, e rodar o gate de build.
**Where**: `CLAUDE.md`
**Depends on**: T7, T28
**Reuses**: formato dos blocos da `spa-pasta`
**Requirement**: SDEC-61

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] `CLAUDE.md` lista as rotas de deck da API e o estado da feature
- [ ] Traceability SDEC-01..61 em `Implemented` com a task de cada um; §16 do `.context/tasks.md` criada e marcada
- [ ] `git diff --name-status <base>..HEAD -- test/` só com `A`; rotas HTML de deck intocadas em `config/routes.rb` (SDEC-61)
- [ ] Gate check passes: Build

**Tests**: none
**Gate**: build

**Commit**: `docs(spa-decks): registrar os decks na SPA`

---

## Phase Execution Map

```
Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6

Phase 1:  T1, T2
Phase 2:  T3, T4, T5, T6, T7, T8, T9, T10
Phase 3:  T11, T12, T13, T14
Phase 4:  T15, T16, T17, T18
Phase 5:  T19, T20, T21, T22, T23, T24, T25, T26
Phase 6:  T27, T28, T29
```

Execução sequencial dentro de cada phase, na ordem numérica (as dependências reais estão nos diagramas acima). 29 tasks → lotes de ~7 por phases inteiras:
Phases 1+2 (10), Phases 3+4 (8), Phase 5 (8), Phase 6 (3).

---

## Task Granularity Check

| Task | Scope | Status |
|---|---|---|
| T1 | 2 métodos de model + chamada no controller HTML | ⚠️ coeso (a extração é uma coisa só) |
| T2 | 1 objeto de consulta + chamada no controller HTML | ⚠️ coeso |
| T3 | 2 actions de leitura + views | ⚠️ coeso (mesmo recurso) |
| T4, T5, T9 | 2/2/1 actions no mesmo controller | ✅ |
| T6 | 1 controller (3 actions do mesmo recurso) | ⚠️ coeso |
| T7 | 1 teste | ✅ |
| T8, T10 | 1 endpoint | ✅ |
| T11 | tipos + 1 módulo de caminhos | ⚠️ coeso |
| T12, T14, T16, T18 | 1 módulo / 1 componente | ✅ |
| T13 | 1 componente + invólucro + assinatura da fila | ⚠️ coeso (B1 é uma refatoração só) |
| T15 | 1 componente + 1 prop em `TextField` | ⚠️ coeso |
| T17 | 1 componente | ✅ |
| T19–T24 | 1 rota cada | ✅ |
| T25, T26 | 1 montagem cada | ✅ |
| T27, T28 | 1 spec cada | ✅ |
| T29 | docs | ✅ |

## Diagram-Definition Cross-Check

| Task | Depends On (task body) | Diagram Shows | Status |
|---|---|---|---|
| T1 | None | — | ✅ |
| T2 | None | — | ✅ |
| T3 | T2 | T2 → T3 | ✅ |
| T4 | T3 | T3 → T4 | ✅ |
| T5 | T3 | T3 → T5 | ✅ |
| T6 | T1, T3 | T1 → T6, T3 → T6 | ✅ |
| T7 | T6 | T6 → T7 | ✅ |
| T8 | T4 | T4 → T8 | ✅ |
| T9 | T3 | T3 → T9 | ✅ |
| T10 | T3 | T3 → T10 | ✅ |
| T11 | None | — | ✅ |
| T12 | T11 | T11 → T12 | ✅ |
| T13 | None | — | ✅ |
| T14 | None | — | ✅ |
| T15 | T11 | T11 → T15 | ✅ |
| T16 | T11 | T11 → T16 | ✅ |
| T17 | T11, T13 | T11 → T17, T13 → T17 | ✅ |
| T18 | T11 | T11 → T18 | ✅ |
| T19 | T11, T12, T14 | T11/T12/T14 → T19 | ✅ |
| T20 | T15 | T15 → T20 | ✅ |
| T21 | T12, T16 | T12/T16 → T21 | ✅ |
| T22 | T15, T16 | T15/T16 → T22 | ✅ |
| T23 | T16 | T16 → T23 | ✅ |
| T24 | T11 | T11 → T24 | ✅ |
| T25 | T17 | T17 → T25 | ✅ |
| T26 | T18 | T18 → T26 | ✅ |
| T27 | T3, T4, T5, T8, T19–T24 | as dez setas | ✅ |
| T28 | T6, T9, T10, T25, T26, T27 | as seis setas | ✅ |
| T29 | T7, T28 | T7/T28 → T29 | ✅ |

## Test Co-location Validation

| Task | Code Layer Created/Modified | Matrix Requires | Task Says | Status |
|---|---|---|---|---|
| T1 | Model | unit | unit | ✅ |
| T2 | Objeto de consulta | unit | unit | ✅ |
| T3–T6, T8–T10 | Controller da API | integration | integration | ✅ |
| T7 | Concorrência | integration | integration | ✅ |
| T11, T12, T14 | Funções puras | unit | unit | ✅ |
| T13, T15–T18 | Componentes | unit | unit | ✅ |
| T19–T26 | Páginas | unit | unit | ✅ |
| T27, T28 | Jornadas | e2e | e2e | ✅ |
| T29 | Docs | none | none | ✅ |
