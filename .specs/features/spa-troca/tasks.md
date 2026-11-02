# Troca do front: SPA na raiz e saída do Hotwire — Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Design**: `.specs/features/spa-troca/design.md`
**Status**: Approved (dono, 2026-10-12)

**Pré-condição:** STRO-01 e STRO-02 cumpridos (ver `design.md`). O commit-pai da T1 é a
**base da feature** (`<base>`) e é registrado na própria T1. O inventário de testes do
`design.md` é o contrato das Phases 1 e 4: nenhum arquivo de teste sai antes de o seu
destino existir, e nenhuma asserção sobre a API, model, query ou service muda (STRO-32
emendado).

---

## Test Coverage Matrix

> Generated from codebase, project guidelines, and spec - confirm before Execute. Guidelines found: `CLAUDE.md` (gates do front e do Rails, armadilhas do Kit 3, CSRF com `allow_forgery_protection` ligado no `setup`, corrida com `use_transactional_tests = false`, e2e exige o catálogo importado, "toda task termina com código que roda e teste que passa"), `frontend/src/lib/styles/guard.test.ts`, ESLint que proíbe `fetch` fora de `client.ts`. Amostras lidas: `test/integration/spa_test.rb`, `test/integration/api/card_variants_concurrency_test.rb`, `test/integration/collection_import_commit_test.rb`, `test/integration/deck_export_test.rb`, `test/services/collection_csv/export_test.rb` (`count_queries`), `frontend/src/lib/navigation/return-to.test.ts`, `frontend/e2e/pasta.spec.ts`. Piso: os testes HTML que saem (as garantias migram com a mesma força); alvo: os ACs do spec (strong default).

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| ---------- | ------------------ | -------------------- | ---------------- | ----------- |
| Função pura Rails (`LegacyPath`) | unit | Toda linha da tabela do design; segmento com `.`, `%3A`, `%2F`; query crua com `[]`; `/app`, `/app/x/y`; `//` e sem regra → `nil` | `test/lib/*_test.rb` | Rails quick |
| Controllers Rails mantidos ou novos (redirect, SPA, downloads) | integration (request test) | Cada caminho do STRO-08 e da checklist: status, `Location` exato, `Content-Type`, `Cache-Control`; `404` dos outros métodos com tabelas intactas; zero consultas no redirecionamento; anônimo `302` exato; deck alheio `404` | `test/integration/*_test.rb` | Rails quick |
| Garantias migradas (API, service) | integration / unit | Cada linha "FALTA" do inventário com a mesma asserção do teste de origem | `test/integration/api/*_test.rb`, `test/services/collection_csv/*_test.rb` | Rails quick |
| Funções puras e config do front (`return-to.ts`, `rails-paths.ts`) | unit | Todos os ramos do STRO-20..22 e o padrão do proxy contra cada caminho do STRO-08 e cada rota do STRO-09 | `frontend/src/**/*.test.ts` | Front quick |
| Páginas e componentes (`.svelte`) | unit (jsdom) | Texto exato, `href` exato na raiz, título, navegação de página inteira para download | `frontend/src/**/*.test.ts` | Front quick |
| Jornadas | e2e (Playwright contra a API real) | Rotas na raiz; URL antiga → tela da SPA com o mesmo resultado; oráculo API ou banco no lugar do HTML | `frontend/e2e/*.spec.ts` | e2e |
| Gems, assets, Dockerfile, docs | none | - | - | build gate only |

## Gate Check Commands

> Generated from codebase - confirm before Execute. Suítes em série, nunca em paralelo (flake D-10). Parar o serviço `frontend` antes do `npm ci` do quick ou reiniciá-lo depois. O e2e exige o catálogo importado (`ingestion:import SNAPSHOT=…`). Worktree local usa `compose.override.yaml` (portas 35432/33000/35173). Se o pull falhar pelo `credsStore`, `export DOCKER_CONFIG=$(mktemp -d)` com `{}` em `config.json`. Gem removida exige `docker compose run --rm --no-deps app bundle install` (volume `bundle`).

| Gate Level | When to Use | Command |
| ---------- | ----------- | ------- |
| Rails quick | Tasks do Rails | `docker compose exec app bin/rails test && docker compose exec app bin/rubocop` |
| Front quick | Tasks do front | `docker compose run --rm --no-deps frontend sh -c "npm ci && npm run check && npm run lint && npm test -- --run"` |
| Full | Tasks e2e | Rails quick + Front quick + `docker compose up -d app frontend && docker compose --profile e2e run --rm e2e` |
| Build | Phase 5 e fechamento | Full + `docker compose exec app bin/brakeman` + `docker build -f Dockerfile .` + `git diff --stat <base>..HEAD -- db/structure.sql db/migrate` vazio (STRO-29) |

---

## Execution Plan

Phases are ordered and run sequentially - each phase completes before the next begins, and tasks within a phase execute in order. Cada diagrama traz todas as dependências das tasks da phase, inclusive as que vêm de phases anteriores.

### Phase 1: Garantias migradas antes da remoção (Rails)

Sobre o código atual, com o HTML no ar. T1 a T7 não dependem de nada.

### Phase 2: Rails servindo a raiz

```
T8 → T9
```

### Phase 3: SPA na raiz

```
T10 → T11
T11 → T12
T11 → T13
T11 → T14
```

### Phase 4: Corte do Hotwire

```
T1 → T15
T15 → T16
T6 → T16
T16 → T17
T17 → T18
T2 → T18
T3 → T18
T4 → T18
T5 → T18
T7 → T18
T9 → T18
T14 → T18
T18 → T19
```

### Phase 5: Dependências e build

```
T19 → T20
T20 → T21
```

### Phase 6: Ponta a ponta e documentos

```
T21 → T22
T22 → T23
T23 → T24
T24 → T25
```

---

## Task Breakdown

### T1: Garantias de cookie e sessão pela API

**What**: Criar `test/integration/api/session_cookie_test.rb` com as provas que hoje só o HTML carrega. Registrar na task o hash do commit-pai (base da feature).
**Where**: `test/integration/api/session_cookie_test.rb`
**Depends on**: None
**Reuses**: helpers de login e CSRF de `test/integration/api/card_variants_wishlist_test.rb`; origens no inventário (authentication:152,160,169; collection_authorization:258; progress_authorization:252,294,319; collection_imports:274; sessions:114,166)
**Requirement**: STRO-23, STRO-24, STRO-31
**Base da feature (`<base>`)**: `880f3c0`

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] `session_id` em params, cookie `session_id` não assinado e cookie de sessão destruída → `401` em `GET /api/progress`
- [x] Login de A, `increment`, login de B no mesmo cookie jar, `increment` → a gravação vai para B e A fica intacta; `GET /api/progress` reflete B
- [x] Header `X-User-Id` com id alheio ignorado em `GET /api/progress` e `POST /api/collection/imports`
- [x] Login com o e-mail em outra caixa aceito
- [x] `select` de deck, logout e login (mesma conta e outra conta) → `editing_deck` nulo em `GET /api/cards/:n` (STRO-23)
- [x] Gate check passes: Rails quick

**Tests**: integration
**Gate**: quick

**Commit**: `test(spa-troca): provar cookie e troca de sessão pela API`

---

### T2: Ida e volta do CSV pela API

**What**: Criar `test/integration/api/collection_csv_roundtrip_test.rb`: `GET /collection/export` → `POST /api/collection/imports` → `confirm` reproduz a coleção.
**Where**: `test/integration/api/collection_csv_roundtrip_test.rb`
**Depends on**: None
**Reuses**: fixtures de `test/integration/collection_csv_roundtrip_test.rb` (origens 178,197,213,229,251,269,359,391,415,464,493; commit:289)
**Requirement**: STRO-31

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Coleção com acento, vírgula, aspas, vários sets: export → import → confirm deixa `collection_items` idêntica; o segundo export é igual byte a byte ao primeiro; três ciclos seguidos estáveis
- [x] Quantidade zero não é escrita nem altera registro
- [x] Dois usuários importam o mesmo arquivo: coleções independentes; a confirmação de A não muda nenhuma linha de B, inclusive nos casos com escrita
- [x] Gate check passes: Rails quick

**Tests**: integration
**Gate**: quick

**Commit**: `test(spa-troca): provar a ida e volta do CSV pela API`

---

### T3: `CollectionCsv::Commit` testado direto

**What**: Criar `test/services/collection_csv/commit_test.rb` com as garantias do `Commit` que só o HTML prova hoje.
**Where**: `test/services/collection_csv/commit_test.rb`
**Depends on**: None
**Reuses**: `com_upsert_falhando_em` e cenários de `test/integration/collection_import_commit_test.rb` (191,218,252,361,468,492,539,636,657,682,704,720,736,766,793) e de `collection_import_summary_test.rb` (227,628,660); `count_queries`
**Requirement**: STRO-31

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Linha rejeitada (duplicada, resolvida mas rejeitada) não escreve, por decisão do `Commit`
- [x] Staging adulterado muda o que é gravado (staging é a única entrada)
- [x] Reivindicação: um `UPDATE` condicional, sem `SELECT` antes; segunda chamada afeta zero linhas e devolve não reivindicado; reivindicação e escrita na mesma transação com savepoint por linha
- [x] Falha de uma linha (AR, não-AR, erro cru do driver) não desfaz as anteriores nem impede o fechamento; `SignalException` propaga
- [x] `LoteGrandeDemais` antes de gravar qualquer linha
- [x] Registro criado depois da prévia é absorvido; registro apagado é recriado
- [x] `Result`: rejeitadas = as que não tocaram a coleção; contagens sem a linha que falhou; `falhas` vazio sem falha
- [x] Gate check passes: Rails quick

**Tests**: unit
**Gate**: quick

**Commit**: `test(spa-troca): provar o Commit do import sem o HTML`

---

### T4: Garantias de deck pela API

**What**: Criar `test/integration/api/deck_guarantees_test.rb`.
**Where**: `test/integration/api/deck_guarantees_test.rb`
**Depends on**: None
**Reuses**: origens deck_editing:71,86; deck_entries_concurrency:194,214; deck_page:217; deck_imports:92,173; padrão de corrida de `test/integration/api/deck_entries_concurrency_test.rb`
**Requirement**: STRO-23, STRO-31

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Deck selecionado que muda de dono → `editing_deck` nulo e a chave sai da sessão; excluir o deck em edição limpa a chave
- [x] Incremento contra deck apagado depois do `find` → `404` sem gravar; `GET /api/decks/:id` sem erro com entrada sumindo entre leituras
- [x] Número de consultas de `GET /api/decks/:id` igual com 2 e com 20 entradas
- [x] Import com 5 cópias → `201` e `status: invalid`; importar a mesma lista duas vezes cria dois decks
- [x] Gate check passes: Rails quick

**Tests**: integration
**Gate**: quick

**Commit**: `test(spa-troca): provar as garantias de deck pela API`

---

### T5: Atendimento da lista de desejos pela API

**What**: Criar `test/integration/api/wishlist_fulfillment_test.rb`.
**Where**: `test/integration/api/wishlist_fulfillment_test.rb`
**Depends on**: None
**Reuses**: origens wishlist_items:213,255,283,298,309,335
**Requirement**: STRO-31

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Alvo 2 com posse 1 e posse zero → `fulfilled: false`; posse de outra variante da mesma carta não atende
- [x] Mudar a posse muda `fulfilled` sem escrita em `wishlist_items`
- [x] Variante que saiu da fonte continua listada
- [x] Gate check passes: Rails quick

**Tests**: integration
**Gate**: quick

**Commit**: `test(spa-troca): provar o atendimento da lista de desejos pela API`

---

### T6: Plano de consultas da pasta pela API

**What**: Criar `test/integration/api/progress_plan_test.rb` com a medição que `queries/set_progress_plan_test.rb` faz hoje sobre a requisição HTML.
**Where**: `test/integration/api/progress_plan_test.rb`
**Depends on**: None
**Reuses**: `queries/set_progress_plan_test.rb:153,180,207`
**Requirement**: STRO-31

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] `GET /api/progress` faz as agregações de progresso e `GET /api/decks/shortfall` a `-- listDeckShortfall`, com e sem decks (*emenda do supervisor, 2026-10-12: na API a falta por deck é outra requisição; o HTML pagava as três na mesma; a AD-021 vale para a soma das duas*)
- [x] Gate check passes: Rails quick

**Tests**: integration
**Gate**: quick

**Commit**: `test(spa-troca): medir as consultas da pasta pela API`

---

### T7: Superfície de autorização sem segmento de usuário

**What**: Criar `test/integration/api/authorization_surface_test.rb`.
**Where**: `test/integration/api/authorization_surface_test.rb`
**Depends on**: None
**Reuses**: origens progress_authorization:353; collection_imports:410,472,504
**Requirement**: STRO-31

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Nenhuma rota de `/api/progress`, `/api/wishlist` e `/api/collection/imports*` tem segmento de usuário (leitura de `Rails.application.routes`)
- [x] Token do import tem ≥ 32 bytes urlsafe e dois uploads seguidos não dão tokens sequenciais
- [x] Gate check passes: Rails quick

**Tests**: unit
**Gate**: quick

**Commit**: `test(spa-troca): provar a superfície de autorização da API`

---

### T8: `LegacyPath`

**What**: Criar `lib/legacy_path.rb` com `LegacyPath.destination(path, query)` conforme a tabela do design.
**Where**: `lib/legacy_path.rb`
**Depends on**: None
**Reuses**: tabela da checklist de paridade (spec, P1)
**Requirement**: STRO-11, STRO-12, STRO-13, STRO-14

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Cada linha da tabela do design casa, inclusive `/cards/P.029`, `/cards/OP01-001` com query `variant=tcgplayer%3A123`, `/collection/import/<token>` e `/decks/7/edit`
- [x] Query devolvida crua (`colors[]=Red&colors[]=Green&sort=name` igual); sem query, sem `?`
- [x] Segmento codificado passa igual (`%2E`, `%3A`)
- [x] `/app` → `/`; `/app/pasta/desejos` → `/pasta/desejos`; `/app//evil.com` → `nil`; `/app/%2F%2Fevil.com` → `/%2F%2Fevil.com`; caminho sem regra (`/decks/1/x`) → `nil`
- [x] Gate check passes: Rails quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-troca): traduzir as URLs antigas para as rotas da SPA`

---

### T9: Fallback da SPA na raiz

**What**: `config.x.spa_entry_path` passa a `Rails.root.join("spa/200.html")`; acrescentar ao fim de `routes.rb` o fallback `get "*path" => "spa#show"` (exceto `/_app/` e `/app/_app/`), mantendo por enquanto a rota `app(/*path)`; `.gitignore` ganha `/spa` e `/public/_app`; `spa_test.rb` cobre a raiz.
**Where**: `config/routes.rb`
**Depends on**: T8
**Reuses**: `SpaController` sem mudança
**Requirement**: STRO-05, STRO-06, STRO-07, STRO-10

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] `GET /pasta/desejos`, `/qualquer/coisa?x=1` e `/200.html` → `200`, `text/html`, `Cache-Control: no-cache`, corpo da entrada de fixture
- [x] `GET /_app/immutable/inexistente.js` e `/app/_app/immutable/x.js` → `404`, nunca a entrada
- [x] `POST /qualquer` → `404`
- [x] As rotas HTML existentes continuam respondendo (a suíte inteira passa)
- [x] Gate check passes: Rails quick

**Tests**: integration
**Gate**: quick

**Commit**: `feat(spa-troca): servir a entrada da SPA na raiz`

---

### T10: Base vazia e proxy de lista positiva

**What**: Criar `frontend/rails-paths.ts` com `RAILS_PATH_PATTERN`; `vite.config.ts` sem `paths.base` e com o proxy desse padrão (sem `changeOrigin`); `playwright.config.ts` com `baseURL` na raiz; healthcheck do serviço `frontend` em `docker-compose.yml` em `/`.
**Where**: `frontend/rails-paths.ts`
**Depends on**: None
**Reuses**: `vite.config.ts` atual (`allowedHosts`, sem `changeOrigin`)
**Requirement**: STRO-04, STRO-08

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Vitest: o padrão casa `/api/session`, `/card_images/x`, `/up`, `/collection/export`, `/decks/5.txt`, `/catalog?x=1`, `/cards/OP01-001`, `/app`, `/app/pasta`, `/collection_items/1/increment`, `/icon.png`, `/404.html`; não casa `/`, `/entrar`, `/cartas/OP01-001`, `/pasta`, `/baralhos/novo`, `/@vite/client`, `/src/app.html`, `/cardsx`
- [x] `curl` pela porta do Vite: `/` responde a SPA e `/api/session` responde JSON do Rails
- [x] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-troca): servir a SPA na raiz e encaminhar só os caminhos do Rails`

---

### T11: Links e testes do front na raiz

**What**: Trocar os 14 `resolve('/').replace(/\/$/, '')` por `resolve('/')` e atualizar os mocks de `$app/paths` e as URLs esperadas nos testes de `/app/...` para `/...`.
**Where**: `frontend/src/lib/navigation/nav-entries.ts`
**Depends on**: T10
**Reuses**: `resolve` de `$app/paths`
**Requirement**: STRO-09

**Tools**:

- MCP: `svelte` (autofixer nos `.svelte` tocados)
- Skill: NONE

**Done when**:

- [x] Nenhum `replace(/\/$/, '')` sobre `resolve` em `frontend/src`
- [x] Nenhum teste do front espera `/app` salvo os do `return-to` (T12)
- [x] Contagem de testes Vitest igual à de antes (sem teste removido)
- [x] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `refactor(spa-troca): tirar o prefixo /app dos links da SPA`

---

### T12: `safeReturnTo` na raiz e retorno a download

**What**: Reescrever `return-to.ts` (STRO-20..22) com `isFileRoute`, e fazer `entrar` e `criar-conta` navegarem com página inteira quando o destino é rota de arquivo.
**Where**: `frontend/src/lib/navigation/return-to.ts`
**Depends on**: T11
**Reuses**: `hasControlCharacter`, `hasDotSegment` do módulo atual
**Requirement**: STRO-20, STRO-21, STRO-22

**Tools**:

- MCP: `svelte`
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] `/pasta` → `/pasta`; `/app/pasta` → `/pasta`; `/app` → `/`; `%2Fapp%2Fpasta` decodificado → `/pasta`; `//x`, `/\x`, `/a/../b`, controle, vazio e `null` → `/`
- [x] `/api/session`, `/_app/x.js`, `/card_images/x` → `/`; `/collection/export` e `/decks/5.txt?x=1` passam e `isFileRoute` é verdadeiro
- [x] Login e cadastro aceitos com `return_to=%2Fdecks%2F5.txt` → `window.location.assign('/decks/5.txt')`, sem `goto`; com `/pasta` → `goto('/pasta')`
- [x] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-troca): voltar ao destino na raiz depois do login`

---

### T13: Página não encontrada

**What**: Criar `src/routes/+error.svelte` com o estado do STRO-10 dentro do casco.
**Where**: `frontend/src/routes/+error.svelte`
**Depends on**: T11
**Reuses**: `+layout.svelte` (casco), padrão de `<svelte:head>` das rotas
**Requirement**: STRO-10

**Tools**:

- MCP: `svelte`
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Status 404: `<h1>` "Página não encontrada", título "Página não encontrada — Bindr", link "Ir para o catálogo" com `href="/"`
- [x] Outro status: "Algo deu errado" com o mesmo link
- [x] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-troca): mostrar página não encontrada dentro do casco`

---

### T14: Varredura de destinos removidos

**What**: Criar `src/no-removed-routes.test.ts`, que falha se `href`, `goto` ou `redirect` em `src/**/*.{svelte,ts}` apontar para rota HTML removida.
**Where**: `frontend/src/no-removed-routes.test.ts`
**Depends on**: T11
**Reuses**: `import.meta.glob` com `?raw`
**Requirement**: STRO-03

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Prefixos proibidos: `/catalog`, `/cards/`, `/session`, `/registration`, `/progress`, `/wishlist`, `/collection/import`, `/collection_items`, `/decks` (salvo `/decks/{…}.txt`), `/app`; `/collection/export` permitido
- [x] Teste negativo: um fonte sintético com `href="/progress"` reprova
- [x] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `test(spa-troca): impedir link da SPA para rota HTML removida`

---

### T15: Testes de API com login pela API

**What**: Nos seis testes de API do inventário, trocar o login HTML por `POST /api/session` e retirar as partes que leem HTML (STRO-32 emendado).
**Where**: `test/integration/api/decks_test.rb`
**Depends on**: T1
**Reuses**: helper de login da T1
**Requirement**: STRO-32

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] `api/cards_test`, `api/catalog_test`, `api/collection_imports_confirm_test`, `api/decks_test`, `api/decks_write_test`, `api/decks_destroy_select_test` sem `session_path`, `get "/catalog"`, `get "/decks…"`, `css_select` nem `assert_select`
- [x] `git diff` desses arquivos sem mudança de asserção sobre resposta da API (só login e remoção das partes HTML), listado no inventário
- [x] Gate check passes: Rails quick

**Tests**: integration
**Gate**: quick

**Commit**: `test(spa-troca): autenticar os testes de API pela API`

---

### T16: Testes de plano sem a requisição HTML

**What**: Em `queries/set_progress_plan_test.rb` e `queries/collection_csv_plan_test.rb`, tirar a medição por requisição HTML (já em T6 e em `api/collection_imports_create_test`) e os blocos de CSS; as asserções de plano ficam.
**Where**: `test/queries/set_progress_plan_test.rb`
**Depends on**: T15, T6
**Reuses**: T6
**Requirement**: STRO-31, STRO-32

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Nenhum `progress_path`, `session_path`, `collection_imports_path` nem leitura de `catalog.css` nos dois arquivos
- [x] `collection_csv_plan_test` mede por `POST /api/collection/imports`; as asserções de `EXPLAIN` não mudam
- [x] Gate check passes: Rails quick

**Tests**: integration
**Gate**: quick

**Commit**: `test(spa-troca): medir os planos sem a requisição HTML`

---

### T17: Downloads com login pela API e `DeckExportsController`

**What**: Criar `DeckExportsController#show` e a rota `get "decks/:id.txt"` antes de `resources :decks`; tirar o ramo `.txt` do `DecksController`; `deck_export_test` e `collection_exports_test` passam a logar pela API.
**Where**: `app/controllers/deck_exports_controller.rb`
**Depends on**: T16
**Reuses**: `Deck::ListText.format`, `Current.user.decks.find`
**Requirement**: STRO-16, STRO-17, STRO-18

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] `GET /decks/<id>.txt` com sessão: `text/plain; charset=utf-8`, corpo igual ao de antes (`"1xDT16-001\n3xDT16-010\n4xDT16-011\n2xDT16-030"`), sem CR; deck alheio e inexistente `404`
- [x] `GET /collection/export`: mesmo corpo, tipo, `Content-Disposition` e `colecao.csv`
- [x] Gate check passes: Rails quick

**Tests**: integration
**Gate**: quick

**Commit**: `refactor(spa-troca): servir a lista do deck num controller próprio`

---

### T18: Corte das rotas HTML

**What**: Trocar as rotas HTML pelas de `LegacyRedirectsController` (tabela do design), `root "spa#show"`, tirar a rota `app(/*path)` → `spa#show`; `Authentication#request_authentication` para `302 /entrar?return_to=`; remover os dez controllers HTML, `app/views/*` salvo `api/`, os testes de `test/integration/` marcados como removidos no inventário; criar `legacy_redirects_test.rb`; ajustar o anônimo de `collection_exports_test` e `deck_export_test`.
**Where**: `config/routes.rb`
**Depends on**: T17, T2, T3, T4, T5, T7, T9, T14
**Reuses**: `LegacyPath` (T8), `SpaController`
**Requirement**: STRO-11, STRO-12, STRO-13, STRO-15, STRO-19, STRO-24, STRO-25, STRO-26, STRO-28, STRO-30, STRO-33

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Por linha da checklist, `/app`, `/app/pasta?order=code`, `/app/cartas/P-029`, `/app/entrar?return_to=%2Fapp%2Fpasta`, `/catalog?colors[]=Red&colors[]=Green&sort=name`, `/cards/P.029`: `301` e `Location` exato; zero consultas SQL; `HEAD` igual
- [x] `/decks/<id>` de deck alheio redireciona sem consultar
- [x] `/app//evil.com` → `404`; `/app/_app/x.js` → `404`
- [x] `POST /collection_items/1/increment`, `DELETE /wishlist/1`, `DELETE /session`, `PATCH /decks/1` → `404` com `collection_items`, `wishlist_items`, `decks` e `sessions` iguais
- [x] Anônimo em `/collection/export` → `302` para `/entrar?return_to=%2Fcollection%2Fexport`; em `/decks/5.txt` → `/entrar?return_to=%2Fdecks%2F5.txt`
- [x] Sessão aberta antes do corte lida pelo mesmo cookie em `GET /api/session` (STRO-24)
- [x] `/`, `/catalog` já não respondem HTML do Rails; `GET /` é a entrada da SPA
- [x] Nenhum `new_session_path`, `return_to_after_authenticating` nem `after_authentication_url` em `app/`
- [x] Cada arquivo removido consta do inventário; os testes de `api/`, `models/`, `queries/`, `services/`, `lib/` e de imagem não mudam nesta task
- [x] Gate check passes: Rails quick

**Tests**: integration
**Gate**: quick

**Commit**: `feat(spa-troca): redirecionar as URLs antigas e tirar o HTML do Rails`

---

### T19: Helpers, CSS, JavaScript e testes de design

**What**: Remover `app/helpers/`, `app/assets/`, `app/javascript/`, `vendor/javascript/`, `test/design/`, `test/helpers/`, `app/mailers/application_mailer.rb`.
**Where**: `app/helpers/catalog_helper.rb`
**Depends on**: T18
**Reuses**: inventário (`test/design/`, `test/helpers/`)
**Requirement**: STRO-25, STRO-30

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] `git ls-files app/helpers app/assets app/javascript vendor/javascript test/design test/helpers app/views | grep -v '^app/views/api/'` vazio
- [x] Gate check passes: Rails quick

**Tests**: none
**Gate**: quick

**Commit**: `chore(spa-troca): remover helpers, CSS e JavaScript do Hotwire`

---

### T20: Gems e configuração do Hotwire

**What**: Tirar do `Gemfile` `propshaft`, `importmap-rails`, `turbo-rails`, `stimulus-rails` e `hotwire-spark`; remover `config/importmap.rb`, `bin/importmap`, `config/initializers/assets.rb` e as linhas `config.hotwire.spark.*` de `development.rb`; `bundle install` no volume.
**Where**: `Gemfile`
**Depends on**: T19
**Reuses**: verificação do P16 no design
**Requirement**: STRO-27

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] `bundle list` sem as cinco gems; `grep -rn "assets\|importmap\|hotwire\|turbo\|stimulus" config` sem uso vigente
- [x] App sobe em dev (`docker compose up app`, `GET /up` 200)
- [x] Gate check passes: Rails quick

**Tests**: none
**Gate**: quick

**Commit**: `chore(spa-troca): remover propshaft, importmap e Hotwire do Gemfile`

---

### T21: Build de produção na raiz

**What**: `Dockerfile` sem `assets:precompile`, estágio Node conferindo que `build/` só tem `_app` e `200.html`, estágio final copiando `build/_app` → `/rails/public/_app` e `build/200.html` → `/rails/spa/200.html`.
**Where**: `Dockerfile`
**Depends on**: T20
**Reuses**: estágio `frontend-build` atual
**Requirement**: STRO-05, STRO-06, STRO-07, STRO-35

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] `docker build -f Dockerfile .` passa
- [x] Contêiner da imagem: `/` e `/pasta` com `no-cache`, `/_app/<chunk real>` com `max-age` longo, `/_app/x.js` `404`, `/200.html` `no-cache`
- [x] Gate check passes: Build

**Tests**: none
**Gate**: build

**Commit**: `build(spa-troca): empacotar a SPA na raiz sem pipeline de assets`

---

### T22: e2e de catálogo e carta sem o HTML

**What**: Em `catalogo.spec.ts`, `carta.spec.ts`, `catalogo-interacao.spec.ts` e `catalogo-layout.spec.ts`, trocar o oráculo HTML por `GET /api/catalog` e `GET /api/cards/:n`, e o registro de posse por `/cards/<n>` pela API; caminhos na raiz.
**Where**: `frontend/e2e/catalogo.spec.ts`
**Depends on**: T21
**Reuses**: `request` do Playwright com o cookie da página
**Requirement**: STRO-34

**Tools**:

- MCP: `playwright` (depuração)
- Skill: NONE

**Done when**:

- [x] Nenhum `goto('/catalog…')` ou `/cards/` nesses specs; paridade contra a API com a mesma query
- [x] Teste novo: `/catalog?colors[]=Red&sort=name` e `/cards/OP01-001?variant=…` abrem a tela da SPA na raiz com o mesmo resultado
- [x] Gate check passes: Full

**Tests**: e2e
**Gate**: full

**Commit**: `test(spa-troca): comparar catálogo e carta com a API no e2e`

---

### T23: e2e de pasta, desejos, baralhos e import sem o HTML

**What**: Em `pasta.spec.ts`, `pasta-desejos.spec.ts`, `baralhos.spec.ts`, `baralhos-montagem.spec.ts` e `importar.spec.ts`, trocar os oráculos HTML pela API (tabela do inventário) e cobrir as URLs antigas e o download pós-login.
**Where**: `frontend/e2e/pasta.spec.ts`
**Depends on**: T22
**Reuses**: helpers de T22
**Requirement**: STRO-19, STRO-22, STRO-34

**Tools**:

- MCP: `playwright`
- Skill: NONE

**Done when**:

- [x] Nenhum `goto` para `/progress`, `/wishlist`, `/decks` (salvo `.txt`), `/collection/import`
- [x] `/app/entrar?return_to=%2Fapp%2Fpasta` → login → `/pasta`; anônimo em `/decks/<id>.txt` → login → download por página inteira
- [x] Gate check passes: Full

**Tests**: e2e
**Gate**: full

**Commit**: `test(spa-troca): comparar pasta, baralhos e import com a API no e2e`

---

### T24: Notas de emenda e `CLAUDE.md`

**What**: Nota de emenda apontando para o Req. 23 em cada critério superado (16.17, 17.4, 17.26, 19.49, 20.46, 21.61, 22.45, a frase do 12.2 e a cláusula "sem JavaScript" de 9.7, 13.11, 13.30, 13.40); `CLAUDE.md` sem Hotwire vigente, com rotas e comandos na raiz.
**Where**: `.context/requirements.md`
**Depends on**: T23
**Reuses**: formato `*(emendado em …)*` do documento
**Requirement**: STRO-36, STRO-37

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Cada critério da lista com a nota
- [x] `grep -n "/app/\|Hotwire" CLAUDE.md` só em contexto histórico
- [x] Gate check passes: Rails quick

**Tests**: none
**Gate**: quick

**Commit**: `docs(spa-troca): emendar os critérios superados e o CLAUDE.md`

---

### T25: Fechamento

**What**: Rodar o gate Build completo, conferir `db/structure.sql` sem diff, registrar o *Handoff* do `STATE.md` e marcar a §18 do `.context/tasks.md`.
**Where**: `.specs/STATE.md`
**Depends on**: T24
**Reuses**: -
**Requirement**: STRO-29, STRO-35

**Tools**:

- MCP: NONE
- Skill: `superpowers:verification-before-completion`

**Done when**:

- [x] `bin/rails test`, `bin/rubocop`, `bin/brakeman`, Front quick, e2e e `docker build -f Dockerfile .` passam, com as contagens registradas
- [x] `git diff --stat <base>..HEAD -- db/` vazio
- [x] Gate check passes: Build

**Tests**: none
**Gate**: build

**Commit**: `docs(spa-troca): registrar o fechamento da troca`

---

## Phase Execution Map

```
Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6

Phase 1:  sete tasks independentes (garantias)
Phase 2:  T8 → T9
Phase 3:  T10 → T11, depois T12, T13 e T14 sobre a T11
Phase 4:  T15 → T16 → T17 → T18 → T19 (dependências cruzadas nos diagramas da phase)
Phase 5:  T20 → T21
Phase 6:  T22 → T23 → T24 → T25
```

---

## Task Granularity Check

| Task | Scope | Status |
|---|---|---|
| T1–T7 | 1 arquivo de teste cada | ✅ |
| T8 | 1 módulo puro | ✅ |
| T9 | 1 rota + config da entrada | ✅ coeso |
| T10 | 1 módulo + config do Vite/Playwright/compose | ✅ coeso |
| T11 | substituição mecânica de prefixo | ⚠️ muitos arquivos, uma regra só |
| T12 | 1 módulo + uso em 2 páginas | ✅ coeso |
| T13, T14 | 1 arquivo cada | ✅ |
| T15, T16 | edição mecânica de login em testes | ⚠️ vários arquivos, uma regra só |
| T17 | 1 controller + rota | ✅ |
| T18 | corte atômico: rotas, `Authentication` e remoção do que elas servem | ⚠️ grande por necessidade: as rotas HTML e os testes que as usam só podem sair juntos para a suíte ficar verde |
| T19, T20 | remoção mecânica | ⚠️ vários arquivos, uma regra só |
| T21 | 1 arquivo | ✅ |
| T22, T23 | specs e2e de um domínio | ✅ coeso |
| T24, T25 | docs | ✅ |

## Diagram-Definition Cross-Check

| Task | Depends On (task body) | Diagram Shows | Status |
|---|---|---|---|
| T1–T7 | None | sem arestas | ✅ |
| T8 | None | — | ✅ |
| T9 | T8 | T8 → T9 | ✅ |
| T10 | None | — | ✅ |
| T11 | T10 | T10 → T11 | ✅ |
| T12 | T11 | T11 → T12 | ✅ |
| T13 | T11 | T11 → T13 | ✅ |
| T14 | T11 | T11 → T14 | ✅ |
| T15 | T1 | T1 → T15 | ✅ |
| T16 | T15, T6 | T15 → T16, T6 → T16 | ✅ |
| T17 | T16 | T16 → T17 | ✅ |
| T18 | T17, T2, T3, T4, T5, T7, T9, T14 | as oito arestas | ✅ |
| T19 | T18 | T18 → T19 | ✅ |
| T20 | T19 | T19 → T20 | ✅ |
| T21 | T20 | T20 → T21 | ✅ |
| T22 | T21 | T21 → T22 | ✅ |
| T23 | T22 | T22 → T23 | ✅ |
| T24 | T23 | T23 → T24 | ✅ |
| T25 | T24 | T24 → T25 | ✅ |

## Test Co-location Validation

| Task | Code Layer Created/Modified | Matrix Requires | Task Says | Status |
|---|---|---|---|---|
| T1, T2, T4, T5, T6 | garantias migradas (API) | integration | integration | ✅ |
| T3 | garantias migradas (service) | unit | unit | ✅ |
| T7 | superfície de rotas | unit | unit | ✅ |
| T8 | função pura Rails | unit | unit | ✅ |
| T9, T17, T18 | controllers e rotas | integration | integration | ✅ |
| T10, T12 | funções e config do front | unit | unit | ✅ |
| T11, T13 | páginas e componentes | unit | unit | ✅ |
| T14 | varredura do front | unit | unit | ✅ |
| T15, T16 | testes existentes (só login e HTML) | integration | integration | ✅ |
| T19, T20, T21 | remoção, gems, Dockerfile | none (build) | none | ✅ |
| T22, T23 | jornadas | e2e | e2e | ✅ |
| T24, T25 | docs | none | none | ✅ |

## Plano de delegação

25 tasks → 4 lotes de phases inteiras: lote 1 = Phase 1 (T1–T7, garantias; tier alto na T3 e na T4 pela corrida e pela atomicidade), lote 2 = Phases 2 e 3 (T8–T14, raiz no Rails e no front; tier alto), lote 3 = Phases 4 e 5 (T15–T21, corte; tier alto, a T18 é a mais arriscada), lote 4 = Phase 6 (T22–T25, e2e e fechamento; tier alto). Revisões: `ecc:security-reviewer` na T8 e na T18 (redirecionamento aberto, `return_to`, `404` sem escrita) e na T12 (`safeReturnTo`); `ecc:pr-test-analyzer` no fim da Phase 1 (força das garantias migradas contra o inventário). O Verifier roda depois da T25, em contexto novo, e confere o inventário por amostragem com mutação nas regras de isolamento e de corrida.

---

## Tasks de correção (iteração 1 do Verifier, 2026-10-12)

### T26: Teste do proxy de dev que roda e discrimina (G2)

**What**: Mover `frontend/rails-paths.test.ts` para `frontend/src/rails-paths.test.ts` (import ajustado) e cobrir cada caminho do STRO-08 e cada rota do STRO-09.
**Where**: `frontend/src/rails-paths.test.ts` (remove `frontend/rails-paths.test.ts`)
**Depends on**: T10
**Requirement**: STRO-04, STRO-08, STRO-09

**Done when**:

- [x] O teste entra no `npm test` (82 → 83 arquivos) e encaminha ao Rails `/progress`, `/wishlist`, `/session/new`, `/registration/new`, `/collection/import`, `/robots.txt`, `/icon.svg`, `/200.html`, `/decks`, `/decks/5/edit`
- [x] As 14 rotas do STRO-09 ficam na SPA
- [x] Remover qualquer prefixo do padrão faz algum teste falhar
- [x] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick
**Commit**: `test(spa-troca): fazer o teste do proxy de dev rodar e discriminar`

### T27: Lacunas Minor do Verifier (G3, G4, G5, G6)

**What**: Teste de `user_id` em `GET /api/cards/:card_number`; cache de `/_app/immutable/*` por request test; `302` exato nos downloads; `/app/200.html` em `REDIRECTS`; tirar "(a confirmar no T25 da `spa-troca`)" do `CLAUDE.md`.
**Where**: `test/integration/api/cards_test.rb`, `test/integration/spa_test.rb`, `test/integration/collection_exports_test.rb`, `test/integration/deck_export_test.rb`, `test/integration/legacy_redirects_test.rb`, `CLAUDE.md`
**Depends on**: T25
**Requirement**: STRO-06, STRO-11, STRO-18, STRO-31

**Done when**:

- [x] `?user_id=` em `GET /api/cards/:n` não muda a posse (a mutação I11c morre)
- [x] `/_app/immutable/*` com `Cache-Control` de `max-age` longo em teste
- [x] Downloads anônimos afirmam `302` e `Location` exatos
- [x] `/app/200.html` → `/200.html` no request test
- [x] `CLAUDE.md` sem "a confirmar no T25"
- [x] Gate check passes: Rails quick

**Tests**: integration
**Gate**: quick
**Commit**: `test(spa-troca): fechar as lacunas Minor do Verifier`
