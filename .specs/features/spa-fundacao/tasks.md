# Fundação da SPA SvelteKit — Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Design**: `.specs/features/spa-fundacao/design.md`
**Status**: Draft

---

## Test Coverage Matrix

> Generated from codebase, project guidelines, and spec - confirm before Execute. Guidelines found: `CLAUDE.md` (gates da `fonte-apitcg`; "toda task termina com código que roda e teste que passa"; sem navegador no container `app`), `design.md` da feature (Tech Decisions: Vitest + `@testing-library/svelte`, Playwright no serviço `e2e`, L-064), `.specs/LESSONS.md` (L-063, L-064). Não há teste JS no repo: o padrão do front nasce aqui, e o piso de profundidade vem dos ACs do spec (strong default). Padrões Rails lidos em `test/integration/api/contract_test.rb` e `test/integration/authentication_test.rb`.

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| ---------- | ------------------ | -------------------- | ---------------- | ----------- |
| Cliente HTTP (`$lib/api/*`) | unit | Todos os ramos, 1:1 com SPA-06..13: header CSRF por método, troca do token, `401` (com e sem a exceção do `DELETE /api/session` e do `invalid_credentials`), os três ramos do `422 invalid_csrf_token` (mesmo usuário, `null`, outra conta) e o segundo `422`, rede, tempo limite, envelope inválido; mensagem exata (L-064) | `frontend/src/lib/api/*.test.ts` | quick |
| Estado (`*.svelte.ts`) e funções puras (`return-to.ts`, `nav-entries.ts`, `motion.ts`) | unit | Todos os ramos, 1:1 com os ACs: corpos de `signIn`/`signUp`, `signOut` com `200` e com `unauthenticated`, `handleUnauthenticated` em `/entrar`; cada edge case do `return_to`; ordem das entradas por sessão; tema com e sem `localStorage` e valor desconhecido | `frontend/src/lib/**/*.test.ts` | quick |
| Tokens (`tokens.css`) | unit | Pares de `test/design/contrast_test.rb` nos dois blocos; matiz OKLCH de cada cor; mesmos nomes nos dois temas; `color-scheme` por bloco | `frontend/src/lib/styles/tokens.test.ts` | quick |
| Componentes e páginas (`.svelte`) | unit (componente, jsdom) | Cada AC de tela: ARIA (`aria-invalid`, `aria-describedby`, `aria-current`, `aria-live`, `role="alert"`), foco, botão pendente, erro por campo e no topo, mensagem exata | `frontend/src/**/*.test.ts` | quick |
| Rails: `SpaController` e rota | integration | `GET /app` e `/app/<caminho>` com `200.html` de fixture (corpo, `Content-Type`, `no-cache`); `/app/_app/<inexistente>` dá `404`; arquivo ausente dá `404`; rotas fora de `/app` intactas (suíte existente sem edição) | `test/integration/spa_test.rb` | full |
| Jornadas no navegador | e2e (Playwright contra a API real) | Jornada de sessão do Independent Test do P1; casco a 360px e 1280px; temas sem flash; reduced motion; View Transition sem erro | `frontend/e2e/*.spec.ts` | e2e |
| Compose, Dockerfile, configs, docs | none | - | - | build gate only |

## Gate Check Commands

> Generated from codebase - confirm before Execute. O projeto `deskansa` ocupa as portas 3000 e 5432 do host: use o override de compose sem portas ou `run --rm` no lugar de `exec`. Rodar as suítes em série, nunca em paralelo (flake D-10).

| Gate Level | When to Use | Command |
| ---------- | ----------- | ------- |
| Quick | Tasks do front com teste de unidade | `docker compose run --rm --no-deps frontend sh -c "npm ci && npm run check && npm run lint && npm test -- --run"` |
| Full | Tasks que tocam o Rails; tasks e2e (depois do quick) | `docker compose exec app bin/rails test && docker compose exec app bin/rubocop`; nas tasks e2e, também `docker compose up -d app frontend && docker compose --profile e2e run --rm e2e` |
| Build | Fim de phase e fechamento | `docker compose build && docker compose run --rm --no-deps frontend sh -c "npm ci && npm run check && npm run lint && npm test -- --run && npm run build"` + Full + `docker compose exec app bin/brakeman -q --no-pager && python3 spec/verify_fixture.py` |

---

## Execution Plan

Phases are ordered and run sequentially - each phase completes before the next begins, and tasks within a phase execute in order. Cada diagrama traz todas as dependências da task da phase, inclusive as que vêm de phases anteriores.

### Phase 1: Scaffold e entrega

```
T1 → T2
T1 → T4
T3 → T4
```

T3 não depende de nada.

### Phase 2: Cliente HTTP

```
T1 → T5
T5 → T6
T6 → T7
```

### Phase 3: Temas e movimento

```
T1 → T8
T8 → T9
T1 → T10
```

### Phase 4: Sessão e mensagens

```
T8 → T11
T10 → T11
T1 → T12
T7 → T13
T11 → T13
T13 → T14
```

### Phase 5: Formulários e casco

```
T8 → T15
T15 → T16
T16 → T17
T13 → T18
T18 → T19
```

### Phase 6: Ponta a ponta e fechamento

```
T2 → T20
T17 → T20
T19 → T20
T20 → T21
T4 → T22
T21 → T22
```

---

## Task Breakdown

### T1: Scaffold do `frontend/` e serviço `frontend` no compose

**What**: Projeto SvelteKit 2 + Svelte 5 (TypeScript) em `frontend/` com `adapter-static` (`fallback: "200.html"`), `paths.base = "/app"`, Vitest (`jsdom`, `@testing-library/svelte`), ESLint com `no-restricted-globals` para `fetch` liberado só em `src/lib/api/client.ts`, scripts `check`, `lint`, `test`, `build`, `package-lock.json` versionado; serviço `frontend` no `docker-compose.yml` (imagem `node:<LTS fixada>-slim`, volume nomeado `frontend_node_modules`, porta 5173) para os gates rodarem no container.
**Where**: `frontend/` (novo), `docker-compose.yml`
**Depends on**: None
**Reuses**: padrão do volume nomeado `bundle` no `docker-compose.yml`
**Requirement**: SPA-06

**Tools**:

- MCP: `plugin:svelte` (`list-sections`, `get-documentation`) para a versão instalada do Kit; local da config (`svelte.config.js` ou `vite.config.ts`) segue a doc dessa versão (Risks)
- Skill: NONE

**Done when**:

- [x] Versões do Kit, do Svelte, do Vitest e do `@playwright/test` fixadas no lockfile
- [x] Um teste de fumaça do Vitest passa (prova o ambiente `jsdom` e o `resolve.conditions`)
- [x] `npm run lint` falha num arquivo de prova com `fetch(...)` fora de `src/lib/api/client.ts` e passa sem ele (prova registrada no commit, arquivo removido)
- [x] `npm run build` gera `build/200.html` e nenhum `build/index.html`
- [x] Gate check passes: quick
- [x] Test count: 1 teste Vitest

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-fundacao): criar o projeto SvelteKit em frontend/ com o serviço no compose`

---

### T2: Proxy do Vite e host do Rails em dev

**What**: Proxy do Vite com a chave regex `^/(?!app(/|$))` → `http://app:3000` sem `changeOrigin`, `server.allowedHosts` com `localhost` e `frontend`, `config.hosts << "frontend"` no `development.rb`; confere no scaffold se os internos do Vite (`/@vite/client`) ficam sob `/app/` e, se não, exclui `^/(@vite|@fs|@id|node_modules)` da regex (Risks).
**Where**: `frontend/vite.config.ts`, `config/environments/development.rb`
**Depends on**: T1
**Reuses**: nada
**Requirement**: SPA-01

**Tools**:

- MCP: `plugin:svelte`
- Skill: NONE

**Done when**:

- [x] `docker compose up` sobe `db`, `app` e `frontend` sem comando adicional
- [x] `curl -i localhost:5173/app` devolve a página da SPA; `curl -i localhost:5173/api/session` devolve o JSON da API com `csrf_token`; `curl -i localhost:5173/catalog` devolve o HTML do Hotwire (saídas registradas no commit)
- [x] HMR funciona sob `/app` (cliente do Vite não vai ao Rails)
- [x] Gate check passes: full (a suíte Rails continua verde com o `development.rb` alterado)

**Tests**: none
**Gate**: full

**Commit**: `feat(spa-fundacao): encaminhar ao Rails pelo proxy do Vite tudo fora de /app`

---

### T3: `SpaController` e rota `app(/*path)`

**What**: `SpaController < ActionController::Base` com `show` que faz `send_file` de `Rails.configuration.x.spa_entry_path` (`text/html`, `inline`, `Cache-Control: no-cache`) ou `head :not_found` sem o arquivo; rota `get "app(/*path)"` como última do arquivo, `format: false`, com constraint que exclui `/app/_app/`; `config.x.spa_entry_path = Rails.public_path.join("app/200.html")`; `/public/app` no `.gitignore`.
**Where**: `app/controllers/spa_controller.rb`
**Depends on**: None
**Reuses**: nada; não herda `ApplicationController` (sem `Authentication` nem `allow_browser`)
**Requirement**: SPA-02, SPA-04

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] `test/integration/spa_test.rb` cobre: `GET /app`, `GET /app/entrar` e `GET /app/qualquer/coisa?x=1` dão `200` com o corpo da fixture, `text/html` e `Cache-Control` com `no-cache`; `GET /app/_app/immutable/velho.js` dá `404` e não o corpo da fixture; arquivo de entrada ausente dá `404`; sem sessão, nenhum redirect para login
- [x] O teste aponta `config.x.spa_entry_path` para um arquivo temporário e restaura no `teardown` (nunca escreve em `public/`)
- [x] A suíte existente passa sem edição (SPA-04)
- [x] Gate check passes: full
- [x] Test count: suíte anterior + novos, nenhum removido

**Tests**: integration
**Gate**: full

**Commit**: `feat(spa-fundacao): servir a página de entrada da SPA em /app com no-cache`

---

### T4: Estágio `frontend-build` no `Dockerfile` de produção

**What**: Estágio `FROM node:<LTS fixada>-slim AS frontend-build` que roda `npm ci && npm run build && test -f build/200.html`; a imagem final faz `COPY --from=frontend-build /frontend/build /rails/public/app`, sem Node; `.dockerignore` ganha `frontend/node_modules` e `frontend/build`.
**Where**: `Dockerfile`
**Depends on**: T1, T3
**Reuses**: estrutura de estágios do `Dockerfile` gerado pelo Rails (não unificar com o `Dockerfile.dev`)
**Requirement**: SPA-03, SPA-05

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] `docker build -f Dockerfile .` termina e a imagem final tem `/rails/public/app/200.html` e `/rails/public/app/_app/immutable/`
- [x] A imagem final não tem `node` no `PATH`
- [x] Com `200.html` removido do build (prova local, sem commit), o `docker build` falha no estágio Node
- [x] Na imagem final em modo produção, `GET /app/_app/immutable/<arquivo existente>` sai com `Cache-Control` de 1 ano e `GET /app/x` com `no-cache` (saídas registradas no commit)
- [x] Gate check passes: build

**Tests**: none
**Gate**: build

**Commit**: `build(spa-fundacao): gerar a SPA num estágio Node e copiá-la para public/app`

---

### T5: Tipos do contrato e `ApiError`

**What**: `$lib/api/types.ts` (`ApiEnvelope`, `ApiErrorBody`, `SessionUser`, `SessionPayload`) escrito à mão contra `_session.json.jbuilder` e o `Api::BaseController`, e `$lib/api/errors.ts` com `ApiError extends Error { status; code; fields }` e as fábricas de `network_error`, `unexpected_response` e `session_changed` com as mensagens exatas do spec.
**Where**: `frontend/src/lib/api/errors.ts`
**Depends on**: T1
**Reuses**: `app/views/api/sessions/_session.json.jbuilder`, `app/controllers/api/base_controller.rb`
**Requirement**: SPA-11, SPA-12, SPA-13

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Testes fixam `status`, `code`, `fields` e `message` de cada fábrica, com o texto exato ("Sem conexão com o servidor. Tente novamente.", "Erro inesperado. Tente novamente.", "A sessão mudou em outra aba. Confira a conta e tente de novo.")
- [x] `ApiError` montado de um corpo da API preserva `message` e `fields` sem alteração
- [x] Gate check passes: quick
- [x] Test count: anteriores + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-fundacao): tipar o contrato da API e o erro do cliente`

---

### T6: `createApiClient` — envelope, CSRF, rede e tempo limite

**What**: `createApiClient(deps)` com `get`/`post`/`patch`/`put`/`delete` e `setCsrfToken`: JSON com `credentials: "same-origin"`, `X-CSRF-Token` só em mutação, troca do token por qualquer `data.csrf_token` em string, erro da API como `ApiError` sem reescrita, `AbortSignal.timeout(timeoutMs)` com padrão de 15000 ms, `TypeError`/`TimeoutError`/`AbortError` como `network_error`, corpo fora do envelope como `unexpected_response`. Sem `401` e `422` especiais ainda.
**Where**: `frontend/src/lib/api/client.ts`
**Depends on**: T5
**Reuses**: `ApiError` (T5)
**Requirement**: SPA-06, SPA-07, SPA-08, SPA-11, SPA-12, SPA-13

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Testes com `fetch` falso cobrem: `X-CSRF-Token` presente em `POST`, `PATCH`, `PUT`, `DELETE` e ausente em `GET`; `credentials: "same-origin"`; token trocado após resposta com `csrf_token` e mantido sem ele; `data` devolvido do envelope; erro `{ error }` vira `ApiError` com os campos exatos; `fetch` rejeitado com `TypeError` e tempo limite (timer falso) viram `network_error` com a mensagem exata; HTML, JSON inválido e JSON sem `data`/`error` viram `unexpected_response`
- [x] Gate check passes: quick
- [x] Test count: anteriores + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-fundacao): criar o cliente HTTP único com CSRF e erros tipados`

---

### T7: Cliente — `401` e renovação do CSRF com comparação de usuário

**What**: No cliente, `401 unauthenticated` chama `onUnauthenticated()` e lança, exceto em `DELETE /api/session`; `401 invalid_credentials` só lança; `422 invalid_csrf_token` em mutação faz `GET /api/session`, troca o token e compara `data.user?.email ?? null` com `currentUserEmail()`: igual → um reenvio (parâmetro interno `retried`); `null` onde havia usuário → `onUnauthenticated()` (salvo no `DELETE /api/session`) e lança `unauthenticated` com a mensagem da API; outro e-mail → `onSessionChanged(user)` e lança `session_changed`.
**Where**: `frontend/src/lib/api/client.ts` (modify)
**Depends on**: T6
**Reuses**: fábricas de erro (T5)
**Requirement**: SPA-09, SPA-10, SPA-22

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Testes cobrem: `401 unauthenticated` num `GET` e num `POST` chamam `onUnauthenticated` uma vez; em `DELETE /api/session` não chamam e lançam `unauthenticated`; `401 invalid_credentials` não chama; `422` com o mesmo e-mail gera exatamente um `GET /api/session` e um reenvio com o token novo; anônimo nos dois lados também reenvia; segundo `422` lança "Token de segurança inválido." sem terceiro envio; `null` onde havia usuário chama `onUnauthenticated`, não reenvia e lança `unauthenticated` com "Faça login para continuar."; o mesmo no `DELETE /api/session` não chama `onUnauthenticated`; outro e-mail chama `onSessionChanged` com o usuário novo, não reenvia e lança `session_changed` com a mensagem exata; `422` em `GET` não renova
- [x] Gate check passes: quick
- [x] Test count: anteriores + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-fundacao): tratar sessão expirada e renovar o CSRF só para o mesmo usuário`

---

### T8: Tokens dos dois temas e estilos base

**What**: `styles/tokens.css` com `:root` (tipo, espaço, raio, navegação, duração, easing), `:root[data-theme="dark"]` e `:root[data-theme="light"]` com `color-scheme` e os dez tokens de cor (escuro igual ao §11.3; claro da tabela do design); `styles/base.css` com o anel de foco e o corte de `prefers-reduced-motion` (inclusive `::view-transition-*`); teste de contraste e de matiz.
**Where**: `frontend/src/lib/styles/tokens.css`
**Depends on**: T1
**Reuses**: `app/assets/stylesheets/catalog.css:9-78` (valores e nomes), pares e fórmula de `test/design/contrast_test.rb`
**Requirement**: SPA-31, SPA-32, SPA-33, SPA-34, SPA-39, SPA-40, SPA-41, SPA-42

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] `tokens.test.ts` lê `tokens.css`, extrai os dois blocos e aplica os pares de `contrast_test.rb` com a mesma fórmula (limiar 0.04045): 4.5:1 texto, 3:1 borda de controle e `accent` como anel, nas três superfícies
- [x] Teste de matiz: toda cor com croma ≥ 0.01 cai em 228° ± 8, 66° ± 8 ou 28° ± 8 (só `danger`)
- [x] Teste confere os mesmos dez nomes nos dois blocos e `color-scheme` coerente em cada um
- [x] Teste confere que `base.css` declara `:focus-visible` com `2px solid var(--accent)` e `outline-offset: 2px`, e o bloco de `prefers-reduced-motion` com os tokens de duração em zero
- [x] `catalog.css` não muda
- [x] Gate check passes: quick
- [x] Test count: anteriores + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-fundacao): declarar os tokens dos temas claro e escuro com contraste verificado`

---

### T9: Tema antes da pintura e escolha manual

**What**: Script inline em `app.html` (antes de `%sveltekit.head%`) que lê `localStorage["bindr-theme"]` em `try`, resolve `system` por `matchMedia` e grava `data-theme` e `data-theme-preference` no `<html>`; `theme.svelte.ts` com `theme.preference`, `setPreference(p)` (grava em `try`, reaplica) e ouvinte de `matchMedia(...).change` só enquanto `system`.
**Where**: `frontend/src/lib/theme.svelte.ts`
**Depends on**: T8
**Reuses**: nada
**Requirement**: SPA-35, SPA-36, SPA-37, SPA-38

**Tools**:

- MCP: `plugin:svelte` (runes em `.svelte.ts`)
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Testes do script inline (executado em `jsdom` a partir do `app.html`) cobrem: `light`, `dark`, `system` com `matchMedia` claro e escuro, valor desconhecido e `localStorage` que lança → `system` sem `console.error`
- [x] Testes de `theme.svelte.ts` cobrem: `setPreference("light")` grava e aplica `data-theme="light"`; `localStorage.setItem` que lança não quebra a troca; com `system`, um evento `change` do `matchMedia` reaplica; ao sair de `system`, o ouvinte é removido
- [x] Gate check passes: quick
- [x] Test count: anteriores + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-fundacao): aplicar o tema antes da pintura e guardar a escolha`

---

### T10: `motion.ts` — corte do movimento nas transições do Svelte

**What**: `duration(ms)` que devolve `0` com `prefersReducedMotion.current` (`svelte/motion`) e `ms` sem ela.
**Where**: `frontend/src/lib/motion.ts`
**Depends on**: T1
**Reuses**: `prefersReducedMotion` do Svelte (⚠️ VERIFICAR a disponibilidade na versão instalada, desde 5.7)
**Requirement**: SPA-42

**Tools**:

- MCP: `plugin:svelte`
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Testes cobrem `duration(200)` com e sem `prefers-reduced-motion: reduce` (`matchMedia` falso)
- [x] Gate check passes: quick
- [x] Test count: anteriores + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-fundacao): zerar a duração das transições com movimento reduzido`

---

### T11: Mensagens transitórias — `toasts.svelte.ts` e `Toaster.svelte`

**What**: Estado `toasts` com `notifySuccess` (remove após 5000 ms), `notifyError` (fica) e `dismiss`; `Toaster.svelte` com as duas regiões sempre montadas (`aria-live="polite"` e `role="alert"`), camada fixa, rótulo escrito "Erro:" e botão "Fechar" de 44px, sem `focus()`; transições pela `duration()` de T10.
**Where**: `frontend/src/lib/components/Toaster.svelte`
**Depends on**: T8, T10
**Reuses**: tokens (T8), `duration` (T10)
**Requirement**: SPA-44, SPA-45, SPA-46

**Tools**:

- MCP: `plugin:svelte` (`svelte-autofixer`)
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Testes cobrem: as duas regiões existem antes de qualquer mensagem; sucesso aparece na região `polite` e some aos 5000 ms com timer falso (e não antes); erro aparece com `role="alert"` e "Erro:" escrito e só some com "Fechar"; `document.activeElement` não muda ao emitir
- [x] Gate check passes: quick
- [x] Test count: anteriores + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-fundacao): exibir mensagens de sucesso e erro sem mover o foco`

---

### T12: `safeReturnTo` — destino pós-login

**What**: `safeReturnTo(raw)` que decodifica com `decodeURIComponent` em `try` e aceita só caminho que começa por `${base}/` sem `//` nem `\`; senão, `base`.
**Where**: `frontend/src/lib/navigation/return-to.ts`
**Depends on**: T1
**Reuses**: `base` de `$app/paths`
**Requirement**: SPA-23

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Testes cobrem: `null`, vazio, `/app/x?y=1` aceito, `/app` sozinho e `/catalog` → `/app`, `//evil.com`, `/app//evil`, `%2F%2Fevil.com`, `/app/%2F%2Fevil`, `https://evil.com/app/x`, `/app\evil`, `%E0%A4%A` (decodificação inválida) → `/app`
- [x] Gate check passes: quick
- [x] Test count: anteriores + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-fundacao): validar o destino pós-login vindo do return_to`

---

### T13: Estado de sessão e instância do cliente

**What**: `session.svelte.ts` com `session` (`status`, `user`, `error`), `loadSession`, `signIn`, `signUp`, `signOut` e `handleUnauthenticated`, e `$lib/api/index.ts` com a instância `api` ligada ao `fetch` global, a `handleUnauthenticated`, a `currentUserEmail` e a `onSessionChanged` (troca `user` e navega para `base`).
**Where**: `frontend/src/lib/session.svelte.ts`
**Depends on**: T7, T11
**Reuses**: `createApiClient` (T7), `notifySuccess` (T11)
**Requirement**: SPA-09, SPA-10, SPA-14, SPA-16, SPA-18, SPA-22

**Tools**:

- MCP: `plugin:svelte`
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Testes com cliente falso cobrem: `loadSession` guarda `user` e token; `signIn` envia `{ email, password }` no topo; `signUp` envia `{ user: { email, password, password_confirmation } }`; `signOut` com `200` e com `ApiError` `unauthenticated` põe `user = null`, navega para `base` e emite "Sessão encerrada."; `signOut` com outro erro relança sem mudar `user`; `handleUnauthenticated` navega para `/app/entrar?return_to=<caminho com query codificado>` e não navega a partir de `/entrar` nem de `/criar-conta`; `onSessionChanged` troca `user` e navega para `base`
- [x] Gate check passes: quick
- [x] Test count: anteriores + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-fundacao): guardar a sessão e ligar o cliente às transições de login`

---

### T14: Layout raiz — carga da sessão, erro e View Transitions

**What**: `routes/+layout.ts` com `ssr = false`, `prerender = false` e `load` que chama `loadSession()` e captura qualquer `ApiError` em `session.status = "error"`; `+layout.svelte` que só renderiza `children` com `ready`, mostra a mensagem e "Tentar novamente" (`refreshAll()`, ou `invalidateAll` se a versão não tiver) com `error`, monta o `Toaster` e registra `onNavigate` com `startViewTransition` quando suportado e sem movimento reduzido.
**Where**: `frontend/src/routes/+layout.svelte`
**Depends on**: T13
**Reuses**: `session` (T13), `Toaster` (T11), `prefersReducedMotion`
**Requirement**: SPA-14, SPA-15, SPA-43

**Tools**:

- MCP: `plugin:svelte` (`$app/navigation`: `refreshAll`, `onNavigate`; ⚠️ VERIFICAR na versão instalada)
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Testes cobrem: com `loading` nada da rota aparece; com `ready` o `children` aparece; com erro `network_error`, `unexpected_response`, `406 unsupported_browser` e `500` aparecem a mensagem exata e "Tentar novamente", sem o `children`; o botão chama o recarregamento; o `load` chama `GET /api/session` uma vez
- [x] `onNavigate` sem `document.startViewTransition` não lança e não chama nada; com movimento reduzido também não
- [x] Gate check passes: quick
- [x] Test count: anteriores + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-fundacao): carregar a sessão antes da primeira rota com tela de nova tentativa`

---

### T15: Componentes de formulário — `TextField`, `Button`, `FormError`

**What**: `TextField` (`label`, `input`, lista de erros com id estável, `aria-invalid` e `aria-describedby` com erro, `focus()`), `Button` (`pending` → `disabled` + `aria-busy`, 44px, `primary`/`secondary`) e `FormError` (`tabindex="-1"`, `role="alert"`, "Erro:" escrito, `focus()`).
**Where**: `frontend/src/lib/components/TextField.svelte`
**Depends on**: T8
**Reuses**: tokens (T8)
**Requirement**: SPA-17, SPA-19, SPA-21

**Tools**:

- MCP: `plugin:svelte` (`svelte-autofixer`)
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Testes cobrem: rótulo associado ao campo; sem erro, sem `aria-invalid` nem `aria-describedby`; com erro, os dois presentes e apontando para a lista com as mensagens; `focus()` foca o input; `Button` pendente desabilitado com `aria-busy="true"`; `FormError` com "Erro:" e `focus()` que o torna o `activeElement`
- [x] Gate check passes: quick
- [x] Test count: anteriores + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-fundacao): criar os componentes de formulário acessíveis`

---

### T16: Página `/app/entrar`

**What**: `entrar/+page.ts` (guarda de já autenticado com `redirect(307, base)`) e `entrar/+page.svelte` com e-mail e senha (`required`, `type="email"`, sem `novalidate`), envio que ignora repetição pendente, `invalid_credentials` no `FormError` com senha limpa e foco, outros erros no topo, sucesso para `safeReturnTo(return_to)`.
**Where**: `frontend/src/routes/entrar/+page.svelte`
**Depends on**: T15
**Reuses**: `signIn` (T13), `safeReturnTo` (T12), componentes (T15)
**Requirement**: SPA-16, SPA-17, SPA-21, SPA-23, SPA-24

**Tools**:

- MCP: `plugin:svelte` (`svelte-autofixer`)
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Testes com sessão falsa cobrem: envio chama `signIn` com os valores; sucesso navega para o `return_to` seguro e para `/app` sem ele; `invalid_credentials` mostra "E-mail ou senha inválidos.", mantém o e-mail, limpa a senha e foca a mensagem; `network_error` mostra a mensagem exata no topo; segundo envio pendente não chama `signIn` de novo e o botão fica desabilitado; com `session.user`, o `load` lança redirect para `/app`
- [x] Gate check passes: quick
- [x] Test count: anteriores + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-fundacao): criar a tela de entrar`

---

### T17: Página `/app/criar-conta`

**What**: `criar-conta/+page.ts` (mesma guarda) e `criar-conta/+page.svelte` com e-mail, senha e confirmação; `validation_failed` distribui `fields` em `email`, `password` e `password_confirmation`, junta o resto no topo e foca o primeiro campo inválido na ordem do formulário depois de `tick()`; sucesso para `safeReturnTo(return_to)`.
**Where**: `frontend/src/routes/criar-conta/+page.svelte`
**Depends on**: T16
**Reuses**: `signUp` (T13), padrão da página de T16, componentes (T15)
**Requirement**: SPA-18, SPA-19, SPA-20, SPA-21, SPA-23, SPA-24

**Tools**:

- MCP: `plugin:svelte` (`svelte-autofixer`)
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Testes cobrem: envio chama `signUp` com os três campos; erro em `password` e `password_confirmation` mostra cada mensagem junto do campo, com `aria-invalid` e `aria-describedby`, e foca `password` (primeiro inválido na ordem); erro só em `email` foca `email`; atributo desconhecido (`base`) aparece no topo e não é descartado; "Dados inválidos." não aparece quando todo `fields` tem campo; envio pendente ignorado; `return_to` preservado após o cadastro; guarda de já autenticado
- [x] Gate check passes: quick
- [x] Test count: anteriores + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-fundacao): criar a tela de criar conta com erro por campo`

---

### T18: Entradas e navegação principal — `nav-entries.ts` e `MainNav.svelte`

**What**: `navEntries(user)` com a ordem do Req. 13.1 e destinos Hotwire com `reload: true`; `MainNav` com `<nav aria-label="Principal">`, `aria-current="page"` pela rota atual, entrada atual com fundo `surface-sunken` e peso de fonte, links Hotwire com `data-sveltekit-reload` e "Sair" como `<button>` que chama `signOut()`.
**Where**: `frontend/src/lib/components/MainNav.svelte`
**Depends on**: T13
**Reuses**: `signOut` (T13), Req. 13.1–13.2
**Requirement**: SPA-25, SPA-26, SPA-27

**Tools**:

- MCP: `plugin:svelte` (`$app/state`)
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Testes de `navEntries` fixam a ordem com sessão ("Catálogo", "Minha pasta", "Baralhos", "Sair") e sem ("Catálogo", "Entrar", "Criar conta") e os destinos `/catalog`, `/progress`, `/decks` com `reload`
- [x] Testes do componente cobrem: `aria-current="page"` só na entrada da rota atual; links Hotwire com `data-sveltekit-reload`; "Sair" é botão e chama `signOut`
- [x] Gate check passes: quick
- [x] Test count: anteriores + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-fundacao): criar a navegação principal na ordem do Req. 13`

---

### T19: Casco — `AppShell`, `ThemeSelect` e página inicial

**What**: `AppShell` com as áreas `brand`, `nav` e `main` (barra inferior abaixo de 64rem com reserva de altura e `safe-area`; coluna lateral a partir de 64rem com `surface-raised` e borda; mesmo DOM nas duas larguras); `ThemeSelect` com `<select>` nativo "Sistema", "Claro", "Escuro" ligado a `theme`; `routes/+page.svelte` (`/app`) com o e-mail do usuário ou o convite para entrar; o layout raiz passa a envolver as rotas no `AppShell`.
**Where**: `frontend/src/lib/components/AppShell.svelte`
**Depends on**: T18
**Reuses**: `MainNav` (T18), `theme` (T9), layout (T14)
**Requirement**: SPA-28, SPA-29, SPA-30, SPA-36

**Tools**:

- MCP: `plugin:svelte` (`svelte-autofixer`)
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Testes cobrem: `ThemeSelect` com rótulo "Tema", as três opções na ordem, valor inicial de `theme.preference` e troca chamando `setPreference`; `AppShell` renderiza marca, `MainNav` e conteúdo; `/app` mostra o e-mail com sessão e os links de entrar sem ela
- [x] Nenhum componente usa `data-theme` nem cor literal fora de `tokens.css` e `app.html` (`grep` registrado no gate)
- [x] Gate check passes: quick
- [x] Test count: anteriores + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `feat(spa-fundacao): montar o casco responsivo com o seletor de tema`

---

### T20: Serviço `e2e` e jornada de sessão no navegador

**What**: Perfil `e2e` no compose com `mcr.microsoft.com/playwright:v<mesma versão do @playwright/test>-noble`, `playwright.config.ts` com `baseURL: http://frontend:5173/app/`, e a jornada contra a API real: criar conta → sair → entrar com senha errada → entrar → ver o e-mail em `/app`, com e-mail único por execução.
**Where**: `frontend/e2e/sessao.spec.ts`
**Depends on**: T2, T17, T19
**Reuses**: serviço `frontend` (T1, T2)
**Requirement**: SPA-01, SPA-14, SPA-16, SPA-17, SPA-18, SPA-22, SPA-23, SPA-24

**Tools**:

- MCP: `playwright` (depuração local, se preciso)
- Skill: NONE

**Done when**:

- [ ] `docker compose up` não sobe o `e2e` (Req. 11.6 continua um comando)
- [ ] Jornada passa com as mensagens exatas ("E-mail ou senha inválidos.", "Sessão encerrada."); `/app/entrar?return_to=/app/criar-conta` com sessão volta a `/app`; nenhuma resposta `406` (User-Agent headless)
- [ ] Gate check passes: quick, depois full (com o e2e)
- [ ] Test count: anteriores + novos, nenhum removido

**Tests**: e2e
**Gate**: full

**Commit**: `test(spa-fundacao): provar a jornada de sessão no navegador contra a API real`

---

### T21: E2E de casco, temas e movimento

**What**: Specs Playwright a 360px e 1280px (posição da navegação, `scrollWidth <= clientWidth`, alvos ≥ 44px por `boundingBox`, `aria-current`, cruzar 64rem sem recarregar nem perder foco), temas (`emulateMedia({ colorScheme })` e `localStorage` pré-carregado: fundo do `body` no primeiro quadro e após troca no seletor; persistência após recarregar) e movimento (`reducedMotion: "reduce"` → duração `0s`; navegação com View Transition sem erro no console).
**Where**: `frontend/e2e/casco.spec.ts`
**Depends on**: T20
**Reuses**: configuração do Playwright (T20)
**Requirement**: SPA-27, SPA-28, SPA-29, SPA-30, SPA-35, SPA-36, SPA-37, SPA-42, SPA-43

**Tools**:

- MCP: `playwright`
- Skill: NONE

**Done when**:

- [ ] Specs passam nas duas larguras e nos dois temas, com o tema certo já no primeiro quadro (atributo e cor lidos num `addInitScript` que observa o `<html>` antes do primeiro script do Kit)
- [ ] Gate check passes: quick, depois full (com o e2e)
- [ ] Test count: anteriores + novos, nenhum removido

**Tests**: e2e
**Gate**: full

**Commit**: `test(spa-fundacao): provar casco, temas e movimento no navegador`

---

### T22: Fechamento — documentação e gate de build

**What**: `CLAUDE.md` com a seção do front (`frontend/`, serviço, gates, armadilhas do proxy e do `200.html`), traceability do `spec.md` atualizada, §12 do `.context/tasks.md` fechada e bloco de *Handoff* no `STATE.md`; gate de build completo em série.
**Where**: `CLAUDE.md`
**Depends on**: T4, T21
**Reuses**: formato da seção "API JSON" do `CLAUDE.md`
**Requirement**: SPA-01, SPA-05

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] Traceability do `spec.md` com todos os SPA-01..46 apontando para a task que os cobre
- [ ] `docker compose build` e o gate de build passam em série
- [ ] `validate_spec.py` da feature sai 0

**Tests**: none
**Gate**: build

**Commit**: `docs(spa-fundacao): documentar o front e fechar a feature`

---

## Phase Execution Map

Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6, em série; dentro de cada phase, as tasks rodam na ordem numérica.

| Phase | Tasks |
| ----- | ----- |
| 1 | T1, T2, T3, T4 |
| 2 | T5, T6, T7 |
| 3 | T8, T9, T10 |
| 4 | T11, T12, T13, T14 |
| 5 | T15, T16, T17, T18, T19 |
| 6 | T20, T21, T22 |

Lotes de ~7 tasks em phases inteiras: **A** = Phases 1–2 (T1–T7), **B** = Phases 3–4 (T8–T14), **C** = Phases 5–6 (T15–T22, 8 tasks). Os lotes rodam em série.

---

## Task Granularity Check

| Task | Scope | Status |
| ---- | ----- | ------ |
| T1: Scaffold + serviço `frontend` | 1 projeto novo + 1 serviço; o serviço existe para os gates rodarem | ⚠️ Coeso (sem o serviço, nenhum gate roda) |
| T2: Proxy e host | 1 chave de config em cada lado do mesmo fluxo | ⚠️ Coeso (um sem o outro não sobe) |
| T3: `SpaController` + rota | 1 endpoint | ✅ Granular |
| T4: Estágio Docker | 1 arquivo (+ `.dockerignore`) | ✅ Granular |
| T5: Tipos e `ApiError` | 1 módulo de tipos | ✅ Granular |
| T6: Cliente base | 1 função | ✅ Granular |
| T7: `401`/`422` | 1 ramo da mesma função | ✅ Granular |
| T8: Tokens + base | 1 arquivo de tokens + seu CSS base | ⚠️ Coeso |
| T9: Tema | script inline + módulo de estado da mesma regra | ⚠️ Coeso |
| T10: `motion.ts` | 1 função | ✅ Granular |
| T11: Toasts | 1 estado + 1 componente | ⚠️ Coeso |
| T12: `safeReturnTo` | 1 função | ✅ Granular |
| T13: Sessão | 1 módulo + a instância que o liga ao cliente | ⚠️ Coeso |
| T14: Layout raiz | 1 rota (`+layout.ts` + `.svelte`) | ✅ Granular |
| T15: Componentes de formulário | 3 componentes pequenos | ⚠️ Coeso (mesmo contrato ARIA) |
| T16: `/entrar` | 1 rota | ✅ Granular |
| T17: `/criar-conta` | 1 rota | ✅ Granular |
| T18: Navegação | 1 função pura + 1 componente | ⚠️ Coeso |
| T19: Casco | 2 componentes + página inicial | ⚠️ Coeso |
| T20: E2E de sessão | 1 spec + infraestrutura do serviço | ⚠️ Coeso |
| T21: E2E de casco | 1 spec | ✅ Granular |
| T22: Fechamento | docs | ✅ Granular |

---

## Diagram-Definition Cross-Check

| Task | Depends On (task body) | Diagram Shows | Status |
| ---- | ---------------------- | ------------- | ------ |
| T1 | None | — | ✅ Match |
| T2 | T1 | T1 → T2 | ✅ Match |
| T3 | None | — | ✅ Match |
| T4 | T1, T3 | T1 → T4, T3 → T4 | ✅ Match |
| T5 | T1 | T1 → T5 | ✅ Match |
| T6 | T5 | T5 → T6 | ✅ Match |
| T7 | T6 | T6 → T7 | ✅ Match |
| T8 | T1 | T1 → T8 | ✅ Match |
| T9 | T8 | T8 → T9 | ✅ Match |
| T10 | T1 | T1 → T10 | ✅ Match |
| T11 | T8, T10 | T8 → T11, T10 → T11 | ✅ Match |
| T12 | T1 | T1 → T12 | ✅ Match |
| T13 | T7, T11 | T7 → T13, T11 → T13 | ✅ Match |
| T14 | T13 | T13 → T14 | ✅ Match |
| T15 | T8 | T8 → T15 | ✅ Match |
| T16 | T15 | T15 → T16 | ✅ Match |
| T17 | T16 | T16 → T17 | ✅ Match |
| T18 | T13 | T13 → T18 | ✅ Match |
| T19 | T18 | T18 → T19 | ✅ Match |
| T20 | T2, T17, T19 | T2 → T20, T17 → T20, T19 → T20 | ✅ Match |
| T21 | T20 | T20 → T21 | ✅ Match |
| T22 | T4, T21 | T4 → T22, T21 → T22 | ✅ Match |

---

## Test Co-location Validation

| Task | Code Layer Created/Modified | Matrix Requires | Task Says | Status |
| ---- | --------------------------- | --------------- | --------- | ------ |
| T1: Scaffold | config + teste de fumaça | none (config) | unit | ✅ OK (acima do mínimo) |
| T2: Proxy | config de dev | none | none | ✅ OK |
| T3: `SpaController` | Rails controller e rota | integration | integration | ✅ OK |
| T4: Dockerfile | build | none | none | ✅ OK |
| T5: Tipos e `ApiError` | Cliente HTTP | unit | unit | ✅ OK |
| T6: Cliente base | Cliente HTTP | unit | unit | ✅ OK |
| T7: `401`/`422` | Cliente HTTP | unit | unit | ✅ OK |
| T8: Tokens | Tokens | unit | unit | ✅ OK |
| T9: Tema | Estado | unit | unit | ✅ OK |
| T10: `motion.ts` | Função pura | unit | unit | ✅ OK |
| T11: Toasts | Estado + componente | unit | unit | ✅ OK |
| T12: `safeReturnTo` | Função pura | unit | unit | ✅ OK |
| T13: Sessão | Estado | unit | unit | ✅ OK |
| T14: Layout | Componente/rota | unit | unit | ✅ OK |
| T15: Formulário | Componentes | unit | unit | ✅ OK |
| T16: `/entrar` | Página | unit | unit | ✅ OK |
| T17: `/criar-conta` | Página | unit | unit | ✅ OK |
| T18: Navegação | Função pura + componente | unit | unit | ✅ OK |
| T19: Casco | Componentes + página | unit | unit | ✅ OK |
| T20: E2E de sessão | Jornada | e2e | e2e | ✅ OK |
| T21: E2E de casco | Jornada | e2e | e2e | ✅ OK |
| T22: Fechamento | docs | none | none | ✅ OK |

---

## Plano de delegação

- **Lotes**: A (T1–T7), B (T8–T14), C (T15–T22), em série, cada um num worker que commita task a task e devolve o resumo compacto. Tier: A e B em alto raciocínio (contrato do cliente e sessão); C em médio, exceto T20–T21 (e2e) em alto.
- **Revisão**: `ecc:typescript-reviewer` no cliente (T6–T7) e na sessão (T13); `ecc:security-reviewer` no fluxo de CSRF e `return_to` (T7, T12, T13) e no `SpaController` (T3); `ecc:a11y-architect` em formulários, casco e mensagens (T11, T15–T19); `svelte:svelte-file-editor` para todo `.svelte`.
- **Verifier** ao fim de T22, autor ≠ verificador, sensor em cópia isolada, nunca `git stash`.
