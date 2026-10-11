# Import e export da coleção na SPA — Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Design**: `.specs/features/spa-portabilidade/design.md`
**Status**: Approved (dono, 2026-10-11)

**Pré-condição:** `spa-pasta` encerrada (é). O commit-pai da T1 é a **base da feature**
(`<base>` abaixo) e é registrado na própria T1. Nenhum arquivo de
`app/controllers/collection_imports_controller.rb`, `app/views/collection_imports/` ou
`app/services/collection_csv/{parser,resolver,commit}.rb` muda nesta feature (SPOR-45).

---

## Test Coverage Matrix

> Generated from codebase, project guidelines, and spec - confirm before Execute. Guidelines found: `CLAUDE.md` (gates do front e do Rails, armadilhas do Kit 3, teste de CSRF com `allow_forgery_protection` ligado no `setup`, corrida com `use_transactional_tests = false`, "toda task termina com código que roda e teste que passa", e2e exige o catálogo importado), `frontend/src/lib/styles/guard.test.ts` (hex, px de token e animação fora de `transform`/`opacity` reprovam), ESLint que proíbe `fetch` fora de `client.ts`. Amostras lidas: `test/integration/collection_import_commit_test.rb`, `test/integration/api/card_variants_concurrency_test.rb`, `test/integration/api/progress_test.rb`, `test/services/collection_csv/export_test.rb` (`count_queries`), `frontend/src/lib/api/client.test.ts`, `frontend/src/routes/pasta/page.test.ts`, `frontend/e2e/pasta.spec.ts`. O piso é o da `spa-pasta`; o alvo vem dos ACs do spec (strong default).

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| ---------- | ------------------ | -------------------- | ---------------- | ----------- |
| Serviço Rails (`CollectionCsv::Upload`) | unit | Todos os ramos: corpo acima de 12 MB sem `read`, arquivo ausente/string, parser recusando (`;`, vazio, Latin-1, > 10.000 linhas), aceito cria um staging e não muda `collection_items`; nome saneado (basename, caracteres, ponto inicial, 120, `colecao.csv`); paridade de frases e teto com o controller HTML | `test/services/collection_csv/upload_test.rb` | Rails quick |
| Controller da API (`Api::CollectionImportsController`) | integration (request test) | Cada endpoint: corpo exato do contrato; 401 sem sessão; 422 `invalid_csrf_token` com `allow_forgery_protection` ligado; `user_id` ignorado; 404 igual para alheio, inexistente e malformado; 409; corrida; consultas constantes com 2 e 200 linhas; nunca HTML nem redirect | `test/integration/api/collection_imports_*_test.rb` | Rails quick |
| Funções puras e cliente (`lib/imports/*.ts`, `client.ts`) | unit | Todos os ramos, 1:1 com os ACs; plurais 0/1/2; codificação de token com caractere reservado; `FormData` e tempo limite por chamada com fetch e relógio falsos | `frontend/src/lib/**/*.test.ts` | Front quick |
| Componentes e páginas (`.svelte`) | unit (componente, jsdom) | Cada AC de tela: texto exato pt-BR com plurais, `href` exato, ARIA (`role="alert"`, `aria-busy`, `aria-invalid`, `aria-describedby`), foco depois de `tick()`, pendência, carga lenta e erros | `frontend/src/**/*.test.ts` | Front quick |
| Jornadas no navegador | e2e (Playwright contra a API real) | Paridade `/app/pasta/importar/<token>` × `/collection/import/<token>`; retrato da coleção (CSV do export) igual antes e depois do envio, da leitura e da recarga; confirmação igual à do HTML; 409 na recarga; ida e volta; 360px e 1280px nos dois temas sem scroll horizontal; alvos de 44px | `frontend/e2e/importar*.spec.ts` | e2e |
| Docs (`CLAUDE.md`, `STATE.md`, `.context/tasks.md`, specs) | none | - | - | build gate only |

## Gate Check Commands

> Generated from codebase - confirm before Execute. Rodar as suítes em série, nunca em paralelo (flake D-10). `npm ci` com o serviço `frontend` de pé troca o `node_modules` sob o Vite: parar o serviço antes do quick ou reiniciá-lo depois. O e2e exige o catálogo importado no banco de dev (`ingestion:import SNAPSHOT=…`). Se o pull de imagem falhar pelo `credsStore` do host, `export DOCKER_CONFIG=$(mktemp -d)` com `{}` em `config.json`.

| Gate Level | When to Use | Command |
| ---------- | ----------- | ------- |
| Rails quick | Tasks do Rails | `docker compose exec app bin/rails test test/models test/services test/integration && docker compose exec app bin/rubocop` |
| Front quick | Tasks do front com teste de unidade | `docker compose run --rm --no-deps frontend sh -c "npm ci && npm run check && npm run lint && npm test -- --run"` |
| Full | Tasks e2e e a última task do Rails | Front quick + `docker compose up -d app frontend && docker compose --profile e2e run --rm e2e` + `docker compose exec app bin/rails test` |
| Build | Fechamento | `docker build -f Dockerfile .` + Full + `docker compose exec app bin/rubocop` + `docker compose exec app bin/brakeman` + `git diff --name-status <base>..HEAD -- test/` só com `A` e `git diff --stat <base>..HEAD -- app/controllers/collection_imports_controller.rb app/views/collection_imports app/services/collection_csv/parser.rb app/services/collection_csv/resolver.rb app/services/collection_csv/commit.rb` vazio, e a diff de `config/routes.rb` só dentro do `scope "api"` (SPOR-45) |

---

## Execution Plan

Phases are ordered and run sequentially - each phase completes before the next begins, and tasks within a phase execute in order. Cada diagrama traz todas as dependências das tasks da phase, inclusive as que vêm de phases anteriores.

### Phase 1: API do import (Rails)

```
T1 → T2
T2 → T3
T3 → T4
```

### Phase 2: Cliente, tipos e funções puras do front

T5, T6 e T7 não dependem de nada.

### Phase 3: Componentes

```
T6 → T8
T6 → T9
```

### Phase 4: Páginas

```
T5 → T10
T7 → T10
T5 → T11
T6 → T11
T7 → T11
T8 → T11
T9 → T11
T10 → T12
```

### Phase 5: Ponta a ponta e fechamento

```
T4 → T13
T11 → T13
T12 → T13
T13 → T14
T14 → T15
```

---

## Task Breakdown

### T1: `CollectionCsv::Upload`

**What**: Criar o serviço `CollectionCsv::Upload.new(user, file, content_length).call → Result(preview, error)` com o teto de 12 MB pelo `Content-Length` antes de `read`, arquivo ausente para qualquer `file` sem `read`, bytes com `force_encoding(UTF_8)`, `Parser` → `Resolver` → `CollectionImport.create!` e o nome saneado do HTML, sem gravar nada em recusa. Registrar na task o hash do commit-pai (base da feature).
**Where**: `app/services/collection_csv/upload.rb`
**Depends on**: None
**Reuses**: `CollectionCsv::Parser`, `CollectionCsv::Resolver`, `CollectionImport.create!`; regras e frases de `CollectionImportsController#create` (`MAX_CORPO_BYTES`, `MENSAGEM_SEM_ARQUIVO`, `MENSAGEM_CORPO_GRANDE`, `conteudo_utf8`, `nome_para_exibicao`)
**Requirement**: SPOR-36, SPOR-37
**Base da feature (`<base>`)**: `d5f13c6` (commit-pai da T1)

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Arquivo aceito cria um `collection_imports` do usuário com `linhas` iguais às do `Resolver` para o mesmo conteúdo e não muda o retrato de `collection_items` (SPOR-36)
- [x] `content_length` acima de 12 MB → frase do limite de 8 MB sem chamar `read` no arquivo (dublê que falha se lido); `nil`, string e objeto sem `read` → frase de arquivo ausente; `;`, vazio, Latin-1 e 10.001 linhas → frase do `Parser`; nenhum staging em recusa (SPOR-37, Edge Cases)
- [x] Nome: `..\x/../Minha Coleção!.csv` vira o mesmo valor que o controller HTML grava; nome só com caracteres descartados vira `colecao.csv`; 200 caracteres viram 120
- [x] Paridade: `MAX_BODY_BYTES`, `MISSING_FILE_MESSAGE` e `BODY_TOO_LARGE_MESSAGE` iguais às constantes do `CollectionImportsController`
- [x] Usuário que não é `User` levanta `ArgumentError` (herdado de `for_user`)
- [x] Gate check passes: Rails quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-portabilidade): criar o serviço de envio do CSV da coleção`

---

### T2: `POST /api/collection/imports`

**What**: Criar `Api::CollectionImportsController#create` com a constante `CLASSIFICATIONS`, a rota `post "collection/imports"` no `scope "api"` acima do catch-all, as views `_preview.json.jbuilder` e `create.json.jbuilder`, respondendo `201` com `{ data: { token, filename, rows } }` ou `422 validation_failed` com `fields.file`.
**Where**: `app/controllers/api/collection_imports_controller.rb`
**Depends on**: T1
**Reuses**: `CollectionCsv::Upload` (T1), `Api::BaseController#render_error`, helpers de sessão e CSRF de `test/integration/api/card_variants_wishlist_test.rb`, `count_queries` de `test/services/collection_csv/export_test.rb`
**Requirement**: SPOR-36, SPOR-37, SPOR-38, SPOR-43, SPOR-44

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Envio aceito → `201` com `token` do staging criado, `filename` saneado e `rows` na ordem do arquivo com as cinco classificações mapeadas (`removes`, `creates`, `updates`, `rejected`, `unchanged`), `line` = índice + 2, `quantity_before` `null` em `creates`, `quantity_after` e `message` conforme o SPOR-38; `collection_items` inalterada (SPOR-36, SPOR-38)
- [x] Sem `file`, corpo JSON, `file` como string, `;`, vazio, Latin-1 e `Content-Length` acima de 12 MB → `422 validation_failed`, `message` "O arquivo não foi importado. Sua coleção não foi alterada." e `fields.file` com a frase do HTML; nenhum staging (SPOR-37)
- [x] Sem sessão → `401 unauthenticated`; sem token CSRF com `allow_forgery_protection` ligado → `422 invalid_csrf_token`; `user_id` de outro usuário no corpo ou na query é ignorado (staging do usuário da sessão) (SPOR-43)
- [x] Número de consultas SQL igual com 2 e com 200 linhas de dado (SPOR-44)
- [x] Resposta `application/json`, nunca HTML nem redirect
- [x] Gate check passes: Rails quick

**Tests**: integration
**Gate**: quick

**Commit**: `feat(spa-portabilidade): receber o CSV da coleção pela API`

---

### T3: `GET /api/collection/imports/:token`

**What**: Acrescentar `show` ao `Api::CollectionImportsController`, a rota `get "collection/imports/:token"` com `constraints: { token: /[^\/]+/ }` e `show.json.jbuilder` sobre o partial da T2, lendo por `CollectionImport.find_by_token_for(Current.user, token)` sem filtro de prazo.
**Where**: `app/controllers/api/collection_imports_controller.rb`
**Depends on**: T2
**Reuses**: `_preview.json.jbuilder` (T2), `CollectionImport.find_by_token_for`, `ActiveRecord::RecordNotFound` → `404` do base
**Requirement**: SPOR-38, SPOR-39, SPOR-43, SPOR-44

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Leitura devolve o mesmo `data` do `201` da T2 para o mesmo staging; staging vencido (`travel` além de 2 h) continua `200` (SPOR-38)
- [x] Token de outro usuário, inexistente e malformado (`%2F..`) → o mesmo corpo `404 not_found` (SPOR-39)
- [x] Sem sessão → `401`; `?user_id=` alheio ignorado (SPOR-43)
- [x] Número de consultas igual com 2 e com 200 linhas (SPOR-44); `collection_items` inalterada depois da leitura (SPOR-20)
- [x] Gate check passes: Rails quick

**Tests**: integration
**Gate**: quick

**Commit**: `feat(spa-portabilidade): ler a pré-visualização do import pela API`

---

### T4: `POST /api/collection/imports/:token/confirm`

**What**: Acrescentar `confirm` ao `Api::CollectionImportsController`, a rota `post "collection/imports/:token/confirm"` e `confirm.json.jbuilder`, chamando só `CollectionCsv::Commit.new(Current.user, token).call`: `nil` → `404`, não reivindicada → `409 import_closed` com a frase do HTML, senão `200` com o resumo do SPOR-40. Medir o `Commit` com 10.000 linhas e registrar o tempo.
**Where**: `app/controllers/api/collection_imports_controller.rb`
**Depends on**: T3
**Reuses**: `CollectionCsv::Commit` (`Result#criadas/atualizadas/zeradas/inalteradas/rejeitadas_detalhadas/falhas`), `CollectionImportsController::MENSAGEM_JA_CONFIRMADA` como referência do teste, padrão de corrida de `test/integration/api/card_variants_concurrency_test.rb` e `com_upsert_falhando_em` de `test/integration/collection_import_commit_test.rb`
**Requirement**: SPOR-39, SPOR-40, SPOR-41, SPOR-42, SPOR-43, SPOR-45

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Para o mesmo conteúdo, confirmar pela API e pelo HTML (dois usuários com a mesma coleção inicial) deixa `collection_items` igual (SPOR-40)
- [x] Corpo `200`: `filename`, `created`, `updated` incluindo `removed`, `removed`, `unchanged`, `rejected` com `line`/`card_number`/`variant_code`/`card_name`/`message` e `failures` com `line`/`card_number`/`variant_code` (falha forçada no upsert); `file` ou `linhas` no corpo da confirmação são ignorados (SPOR-40)
- [x] Coleção alterada por `increment` entre a leitura e a confirmação → o resumo traz as contagens que o `Commit` gravou (Edge Case)
- [x] Segunda confirmação e staging vencido → `409 import_closed` com "Esta importação já foi confirmada ou expirou. Sua coleção não foi alterada; envie o arquivo de novo se quiser importar." e coleção inalterada (SPOR-41)
- [x] Duas threads confirmando o mesmo token (`use_transactional_tests = false`, arquivo próprio `collection_imports_concurrency_test.rb`) → uma `200` e uma `409`, coleção gravada uma vez (SPOR-42)
- [x] Token alheio e inexistente → o mesmo `404`, sem gravar (SPOR-39); sem sessão `401`; sem CSRF `422 invalid_csrf_token` (SPOR-43)
- [x] `docker compose exec app bin/rails test` inteiro passa sem editar teste existente (SPOR-45)
- [x] Tempo do `Commit` com 10.000 linhas medido no container e registrado no *Registro* desta task; acima de 30 s, parar e levar ao dono antes da T10
- [x] Gate check passes: Rails quick e `docker compose exec app bin/rails test`

**Tests**: integration
**Gate**: full

**Commit**: `feat(spa-portabilidade): confirmar o import da coleção pela API`

**Registro**: `Commit` com 10.000 linhas levou 7,91 s no container (RAILS_ENV=test), abaixo do teto de 30 s. Um flake isolado em `bin/rails test` (staging vencido) não se repetiu em 4 rodadas seguintes.

---

### T5: Cliente HTTP com `FormData` e tempo limite por chamada

**What**: Fazer o `client.ts` enviar `FormData` sem `Content-Type` próprio e aceitar `post(path, body?, { timeoutMs })`, mantendo 15 s como padrão e repassando corpo e opções no reenvio único do SPA-10.
**Where**: `frontend/src/lib/api/client.ts`
**Depends on**: None
**Reuses**: `send`, `requestEnvelope`, `recoverFromStaleCsrf` e os testes de `client.test.ts`
**Requirement**: SPOR-35, SPOR-32

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Mutação com `FormData` sai sem header `Content-Type`, com `X-CSRF-Token` e com o mesmo objeto `FormData` no `body` (SPOR-35)
- [x] `422 invalid_csrf_token` renova por `GET /api/session` e reenvia o mesmo `FormData` (com `file`) e o mesmo tempo limite uma vez; com outro e-mail na renovação não reenvia e lança `session_changed` (SPOR-35)
- [x] Relógio falso: `post` com `{ timeoutMs: 60000 }` não aborta em 15 s e aborta em 60 s como `network_error`; `get` continua abortando em 15 s (SPOR-32)
- [x] Corpo JSON segue com `Content-Type: application/json`; o ESLint continua recusando `fetch` fora de `client.ts`
- [x] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-portabilidade): enviar arquivo pelo cliente HTTP da SPA`

---

### T6: Tipos e frases do import

**What**: Acrescentar `ImportClassification`, `ImportRow`, `ImportPreview` e `ImportSummary` a `api/types.ts` e criar `lib/imports/groups.ts` com `groupRows` (ordem fixa, títulos, frases de apoio e rótulos, sem grupo vazio), `plural` e as frases com número do Req. 22.12, 22.18 e 22.24–22.27.
**Where**: `frontend/src/lib/imports/groups.ts`
**Depends on**: None
**Reuses**: `frontend/src/lib/format.ts` (padrão de função pura com teste)
**Requirement**: SPOR-12, SPOR-13, SPOR-14, SPOR-18, SPOR-24, SPOR-25, SPOR-26, SPOR-27

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Linhas das cinco classificações em ordem embaralhada → grupos `removes, creates, updates, rejected, unchanged` com títulos, frases de apoio do Req. 22.13 e rótulos do SPOR-14, linhas na ordem da resposta dentro do grupo; grupo vazio ausente (SPOR-13, SPOR-14)
- [x] "linha analisada"/"linhas analisadas" com 0, 1 e 2 (SPOR-12); aviso de remoção com 1 e 2 (SPOR-18); frases de removidas, inalteradas, recusas e falhas com 1 e 2, exatas do spec (SPOR-24–27)
- [x] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-portabilidade): agrupar as linhas e escrever as frases do import`

---

### T7: Caminhos da API do import

**What**: Criar `lib/imports/api.ts` com `IMPORTS_PATH`, `importPath(token)`, `confirmPath(token)` (token por `encodeURIComponent`) e `IMPORT_TIMEOUT_MS = 60000`.
**Where**: `frontend/src/lib/imports/api.ts`
**Depends on**: None
**Reuses**: padrão de `frontend/src/lib/cards/url.ts`
**Requirement**: SPOR-32, SPOR-38

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] `importPath('abc')` = `/api/collection/imports/abc`; `confirmPath('abc')` = `/api/collection/imports/abc/confirm`
- [x] Token com `/`, `?`, `#` e `%` sai codificado e o caminho continua começando por uma barra só (Edge Case de token com caractere reservado)
- [x] `IMPORT_TIMEOUT_MS` é 60000
- [x] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-portabilidade): montar os caminhos da API do import`

---

### T8: `ImportRowItem`

**What**: Criar o componente de uma linha da pré-visualização: rótulo escrito, `card_number`, `variant_code` em `<code>`, nome, "—" no código ausente, "Linha <line> do arquivo", antes e depois em elementos próprios e motivo, só com interpolação de texto.
**Where**: `frontend/src/lib/components/ImportRowItem.svelte`
**Depends on**: T6
**Reuses**: rótulos de `groups.ts` (T6), tokens de `tokens.css`
**Requirement**: SPOR-14, SPOR-15, SPOR-16, SPOR-17

**Tools**:

- MCP: `svelte` (autofixer)
- Skill: `svelte:svelte-core-bestpractices`

**Done when**:

- [x] Cada classificação mostra o rótulo e a frase do SPOR-15 (`creates` sem "antes"; recusada com a `message`), com antes e depois em elementos próprios (SPOR-14, SPOR-15)
- [x] `card_number` ou `variant_code` nulos aparecem como "—"; `variant_code` em `<code>` (SPOR-14)
- [x] `<script>alert(1)</script>` no nome aparece como texto e nenhum `<script>` nasce no DOM (SPOR-17)
- [x] Nome de 120 caracteres e `tcgplayer:1234567890` com `overflow-wrap: anywhere`; o estilo passa no `guard.test.ts`; a marca do grupo usa forma ou peso além da cor (SPOR-16)
- [x] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-portabilidade): exibir uma linha da pré-visualização do import`

---

### T9: `ImportSummary`

**What**: Criar o componente do resumo: `h1` "Importação concluída" focável com `focus()` exportado, "Arquivo: <filename> — sua coleção foi atualizada.", as três contagens com frases de apoio, as frases de removidas, inalteradas, recusas e falhas e os links finais.
**Where**: `frontend/src/lib/components/ImportSummary.svelte`
**Depends on**: T6
**Reuses**: frases de `groups.ts` (T6), padrão de `focus()` exportado de `FormError.svelte`, `resolve` de `$app/paths`
**Requirement**: SPOR-22, SPOR-23, SPOR-24, SPOR-25, SPOR-26, SPOR-27, SPOR-28, SPOR-29

**Tools**:

- MCP: `svelte` (autofixer)
- Skill: `svelte:svelte-core-bestpractices`

**Done when**:

- [x] "Importadas", "Atualizadas", "Recusadas" nesta ordem, número e rótulo em elementos próprios, com zero (SPOR-23); `updated` 3 e `removed` 1 → 3 em "Atualizadas" e a frase de remoção com 1 (SPOR-24)
- [x] Frases de inalteradas (SPOR-25), recusas com `card_number`, `variant_code`, nome, linha e motivo (SPOR-26) e falhas separadas (SPOR-27) só quando há
- [x] Sem recusa nem falha, o texto não contém "rejeitada", "falha" nem "erro" (SPOR-28)
- [x] "Ver minha coleção" → `/app/pasta` e "importar outro arquivo" → `/app/pasta/importar`, sem `data-sveltekit-reload` (SPOR-29); `focus()` põe o foco no `h1` (SPOR-22)
- [x] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-portabilidade): exibir o resumo do import`

---

### T10: Rota `/app/pasta/importar`

**What**: Criar `src/routes/pasta/importar/+page.ts` (`requireSession`) e `+page.svelte` com o formulário de envio, o envio `multipart` com guarda de pendência, a navegação para `/app/pasta/importar/<token>` no `201` e o resumo de erro focado com o campo marcado no `422`.
**Where**: `frontend/src/routes/pasta/importar/+page.svelte`
**Depends on**: T5, T7
**Reuses**: `requireSession`, `api.post` (T5), `IMPORTS_PATH`/`IMPORT_TIMEOUT_MS` (T7), `FormError`, `Button`, padrão de `src/routes/criar-conta/+page.svelte`
**Requirement**: SPOR-01, SPOR-03, SPOR-04, SPOR-05, SPOR-06, SPOR-07, SPOR-08, SPOR-32

**Tools**:

- MCP: `svelte` (autofixer)
- Skill: `svelte:svelte-core-bestpractices`

**Done when**:

- [x] Título "Importar coleção — Bindr", `h1` e texto do SPOR-01; campo "Arquivo CSV" `required` com `accept="text/csv,.csv"` e botão "Pré-visualizar importação" (SPOR-01, SPOR-04)
- [x] Sessão anônima no `load` → redirect para `/app/entrar?return_to=%2Fapp%2Fpasta%2Fimportar` sem chamar a API (SPOR-03)
- [x] Envio chama `api.post('/api/collection/imports', FormData com file, { timeoutMs: 60000 })` uma vez em duplo clique, com o botão pendente (SPOR-05, SPOR-32)
- [x] `201` com token `a/b` → `goto` para `/app/pasta/importar/a%2Fb` (SPOR-06)
- [x] `422` com `fields.file` de duas frases → `role="alert"` com a `message` e as duas frases na ordem, foco nele depois de `tick()`, input com `aria-invalid="true"` e `aria-describedby` apontando para ele, URL mantida (SPOR-07)
- [x] `network_error` → a `message` como veio; `401` não mostra erro local (o cliente cuida) (SPOR-08)
- [x] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-portabilidade): enviar o CSV da coleção pela SPA`

---

### T11: Rota `/app/pasta/importar/[token]`

**What**: Criar `src/routes/pasta/importar/[token]/+page.ts` (`requireSession`) e `+page.svelte` com a pré-visualização por `createLoader`, os grupos, o aviso de remoção, a confirmação com pendência e a troca pelo `ImportSummary` na mesma URL, com `409`, resposta perdida e erros de leitura.
**Where**: `frontend/src/routes/pasta/importar/[token]/+page.svelte`
**Depends on**: T5, T6, T7, T8, T9
**Reuses**: `createLoader`, `requireSession`, `groupRows` (T6), `importPath`/`confirmPath` (T7), `ImportRowItem` (T8), `ImportSummary` (T9), `Button`, `FormError`
**Requirement**: SPOR-03, SPOR-09, SPOR-10, SPOR-11, SPOR-12, SPOR-13, SPOR-16, SPOR-18, SPOR-19, SPOR-21, SPOR-22, SPOR-30, SPOR-31, SPOR-32

**Tools**:

- MCP: `svelte` (autofixer)
- Skill: `svelte:svelte-core-bestpractices`

**Done when**:

- [x] Sessão anônima → redirect com `return_to=%2Fapp%2Fpasta%2Fimportar%2Fabc` sem chamar a API (SPOR-03)
- [x] `GET` do token; título "Pré-visualização da importação — Bindr" e `h1` "Confira o que vai mudar"; após 200 ms `aria-busy="true"` e "Carregando pré-visualização…" (SPOR-09, SPOR-10)
- [x] `404` → `message` e "Enviar um arquivo" sem "Tentar novamente"; `500` → `message` e "Tentar novamente" que repete o `GET` (SPOR-11)
- [x] "Arquivo: … — N linhas analisadas.", aviso em destaque, grupos na ordem fixa com `h2` "<título> (<n>)", aviso de remoção antes do botão só com `removes`, botão "Confirmar e gravar na minha coleção" e frase final com link "envie outro arquivo" sem recarga; só cabeçalho → "0 linhas analisadas.", nenhum grupo e o botão (SPOR-12, SPOR-13, SPOR-18, SPOR-19)
- [x] Confirmar chama `api.post(confirmPath, undefined, { timeoutMs: 60000 })` uma vez em duplo clique (SPOR-21, SPOR-32)
- [x] `200` → resumo na mesma URL, título "Importação concluída — Bindr", foco no `h1` (SPOR-22)
- [x] `409 import_closed` → pré-visualização mantida e `message` com `role="alert"` (SPOR-30)
- [x] `network_error` na confirmação → frase do SPOR-31 com "Ver minha coleção", uma chamada só (SPOR-31)
- [x] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-portabilidade): pré-visualizar e confirmar o import na SPA`

---

### T12: "Importar coleção" da pasta para a SPA

**What**: Trocar o `href` de "Importar coleção" em `src/routes/pasta/+page.svelte` de `/collection/import` com `data-sveltekit-reload` para `/app/pasta/importar` sem recarga, mantendo "Baixar minha coleção (CSV)" como link de página inteira para `/collection/export`.
**Where**: `frontend/src/routes/pasta/+page.svelte`
**Depends on**: T10
**Reuses**: `resolve` de `$app/paths`, teste existente de `src/routes/pasta/page.test.ts`
**Requirement**: SPOR-02, SPOR-33

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] "Importar coleção" → `href="/app/pasta/importar"` sem `data-sveltekit-reload`; a expectativa do `page.test.ts` da pasta passa a este destino (SPOR-02 substitui o destino Hotwire do SPAS-25)
- [x] "Baixar minha coleção (CSV)" continua `/collection/export` com `data-sveltekit-reload` (SPOR-33)
- [x] Gate check passes: Front quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-portabilidade): levar a ação de importar da pasta para a SPA`

---

### T13: E2E do import

**What**: Criar `frontend/e2e/importar.spec.ts` contra a API real: paridade com o HTML para um arquivo das cinco classificações, coleção intacta antes da confirmação, confirmação igual à do HTML, `409` na recarga, recusa do arquivo, 360px e 1280px nos dois temas e o tempo de renderização com 10.000 linhas.
**Where**: `frontend/e2e/importar.spec.ts`
**Depends on**: T4, T11, T12
**Reuses**: helpers de conta e posse de `frontend/e2e/pasta.spec.ts`; CSV de `/collection/export` como retrato de `collection_items`
**Requirement**: SPOR-01, SPOR-02, SPOR-07, SPOR-13, SPOR-14, SPOR-15, SPOR-20, SPOR-22, SPOR-23, SPOR-30, SPOR-46

**Tools**:

- MCP: `playwright`
- Skill: `ecc:e2e-testing`

**Done when**:

- [ ] Mesmo arquivo enviado pelo HTML e pela SPA (mesma conta): grupos, ordem, linhas, números de linha, antes, depois e motivos iguais entre `/collection/import/<token>` e `/app/pasta/importar/<token>` (Goal 1)
- [ ] Export antes = export depois de enviar, abrir, recarregar e sair da pré-visualização (SPOR-20)
- [ ] Confirmar pela SPA: resumo com contagens e o export igual ao que a confirmação pelo HTML produz numa segunda conta com a mesma coleção inicial (Goal 2); recarregar e confirmar de novo → alerta de `409` e export inalterado (SPOR-30)
- [ ] Arquivo com `;` → alerta com a frase do separador e foco nele (SPOR-07)
- [ ] 360px e 1280px nos dois temas, nas três telas, com nome de 120 caracteres e `tcgplayer:1234567890`: `scrollWidth` = `clientWidth`; botões com caixa de 44px ou mais (SPOR-46)
- [ ] Pré-visualização de 10.000 linhas: tempo até o botão de confirmar visível registrado no *Registro* da task; acima de 5 s a 360px, parar e levar ao dono
- [ ] Gate check passes: Full

**Tests**: e2e
**Gate**: full

**Commit**: `test(spa-portabilidade): provar o import da coleção na SPA de ponta a ponta`

---

### T14: E2E da ida e volta com o export

**What**: Criar `frontend/e2e/importar-ida-e-volta.spec.ts`: usuário com posse em três sets e uma variante zerada baixa o CSV pelo link da pasta, envia sem edição pela SPA, vê só "Já está assim (N)", confirma e o export depois é igual ao de antes.
**Where**: `frontend/e2e/importar-ida-e-volta.spec.ts`
**Depends on**: T13
**Reuses**: helpers da T13
**Requirement**: SPOR-33, SPOR-34

**Tools**:

- MCP: `playwright`
- Skill: `ecc:e2e-testing`

**Done when**:

- [ ] O download sai do link "Baixar minha coleção (CSV)" da pasta, sem chamada a `/api` (SPOR-33)
- [ ] Pré-visualização só com o grupo "Já está assim (N)", N = linhas do CSV; depois de confirmar, export idêntico byte a byte ao anterior (SPOR-34)
- [ ] Gate check passes: Full

**Tests**: e2e
**Gate**: full

**Commit**: `test(spa-portabilidade): provar a ida e volta do CSV pela SPA`

---

### T15: Fechamento da documentação

**What**: Atualizar `CLAUDE.md` (estado da `spa-portabilidade`, três rotas e o código `import_closed` na tabela da API, módulos novos do front, `FormData` e `timeoutMs` no cliente, armadilhas), a traceability do spec para `Implemented`, a §17 do `.context/tasks.md`, o *Handoff* do `STATE.md`, e rodar o gate de build.
**Where**: `CLAUDE.md`
**Depends on**: T14
**Reuses**: formato dos blocos da `spa-pasta`
**Requirement**: SPOR-45

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] `CLAUDE.md` lista `POST /api/collection/imports`, `GET …/:token`, `POST …/:token/confirm` e `409 import_closed`, e o estado da feature
- [ ] Traceability SPOR-01..46 em `Implemented` com a task de cada um; §17 do `.context/tasks.md` marcada
- [ ] *Handoff* registra a duplicação temporária entre `CollectionCsv::Upload` e o controller HTML (sai na `spa-troca`), a P13 aberta e os tempos medidos nas T4 e T13
- [ ] `git diff --name-status <base>..HEAD -- test/` só com `A`; controller, views e serviços HTML do import intocados (SPOR-45)
- [ ] Gate check passes: Build

**Tests**: none
**Gate**: build

**Commit**: `docs(spa-portabilidade): registrar o import e o export na SPA`

---

## Phase Execution Map

```
Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5

Phase 1:  T1 → T2 → T3 → T4
Phase 2:  T5, T6, T7
Phase 3:  T8, T9
Phase 4:  T10 (T5, T7), T11 (T5–T9), T12 (T10)
Phase 5:  T13 → T14 → T15
```

---

## Task Granularity Check

| Task | Scope | Status |
|---|---|---|
| T1 | 1 serviço | ✅ |
| T2–T4 | 1 endpoint cada (controller + rota + view do endpoint) | ✅ coeso |
| T5 | 1 módulo (cliente) | ✅ |
| T6 | Tipos + 1 módulo puro | ✅ coeso |
| T7 | 1 módulo puro | ✅ |
| T8, T9 | 1 componente cada | ✅ |
| T10, T11 | 1 rota cada (`+page.ts` + `+page.svelte`) | ✅ coeso |
| T12 | 1 link | ✅ |
| T13, T14 | 1 spec e2e cada | ✅ |
| T15 | Docs | ✅ |

## Diagram-Definition Cross-Check

| Task | Depends On (task body) | Diagram Shows | Status |
|---|---|---|---|
| T1 | None | — | ✅ |
| T2 | T1 | T1 → T2 | ✅ |
| T3 | T2 | T2 → T3 | ✅ |
| T4 | T3 | T3 → T4 | ✅ |
| T5 | None | — | ✅ |
| T6 | None | — | ✅ |
| T7 | None | — | ✅ |
| T8 | T6 | T6 → T8 | ✅ |
| T9 | T6 | T6 → T9 | ✅ |
| T10 | T5, T7 | T5 → T10, T7 → T10 | ✅ |
| T11 | T5, T6, T7, T8, T9 | T5, T6, T7, T8, T9 → T11 | ✅ |
| T12 | T10 | T10 → T12 | ✅ |
| T13 | T4, T11, T12 | T4, T11, T12 → T13 | ✅ |
| T14 | T13 | T13 → T14 | ✅ |
| T15 | T14 | T14 → T15 | ✅ |

## Test Co-location Validation

| Task | Code Layer | Matrix Requires | Task Says | Status |
|---|---|---|---|---|
| T1 | Serviço Rails | unit | unit | ✅ |
| T2–T4 | Controller da API | integration | integration | ✅ |
| T5–T7 | Funções puras e cliente | unit | unit | ✅ |
| T8–T12 | Componentes e páginas | unit | unit | ✅ |
| T13, T14 | Jornadas no navegador | e2e | e2e | ✅ |
| T15 | Docs | none | none | ✅ |

---

## Plano de delegação

15 tasks → 3 lotes de phases inteiras: lote 1 = Phases 1 e 2 (T1–T7, Rails e funções puras; tier alto na T4 pela corrida, rápido no resto), lote 2 = Phases 3 e 4 (T8–T12, componentes e páginas; tier alto), lote 3 = Phase 5 (T13–T15, e2e e fechamento; tier alto). Revisões: `ecc:security-reviewer` nas T1 e T2 (arquivo hostil, nome saneado, CSRF em multipart), `ecc:database-reviewer` na T4 (corrida e consultas), `ecc:a11y-architect` nas T10 e T11 (foco do erro e do resumo, `aria-busy`, distinção sem cor). O Verifier roda depois da T15, em contexto novo.
