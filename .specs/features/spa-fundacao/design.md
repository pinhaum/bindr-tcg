# Design — Fundação da SPA SvelteKit

**Spec**: `.specs/features/spa-fundacao/spec.md`
**Status**: Approved (dono, 2026-10-10)

Restrições ativas: AD-005 (`.context/` vence), AD-023 (SPA na mesma origem, `/app`
na transição), AD-024 (contrato de payload da API), AD-025 (temas claro e escuro).
Abordagem de entrega em produção escolhida pelo dono em 2026-10-10: build em
`public/app/` com rota de fallback.

---

## Architecture Overview

Três camadas no front, cada uma dona de uma regra:

- **Cliente HTTP** (`$lib/api`): fala o contrato da `api-fundacao`. É o único lugar
  que conhece CSRF, envelope, `401`, `422 invalid_csrf_token`, tempo limite e rede.
- **Estado** (`*.svelte.ts` com `$state`): sessão, tema e mensagens. Cada módulo
  expõe funções; as telas não mexem no estado cru.
- **Telas e casco** (`src/routes`, `$lib/components`): consomem estado e cliente,
  sem `fetch` próprio (SPA-06, imposto por lint).

Os temas não passam por JavaScript em tempo de renderização. Um script inline em
`app.html` resolve o tema efetivo antes da pintura e grava `data-theme` no
`<html>`. Os tokens têm um bloco por tema, selecionado por esse atributo.

```mermaid
graph TD
    subgraph Navegador
      H[app.html<br/>script inline de tema] --> R[+layout.ts<br/>ssr=false, carrega sessão]
      R --> LY[+layout.svelte<br/>casco + Toaster + onNavigate]
      LY --> P1[/app]
      LY --> P2[/app/entrar]
      LY --> P3[/app/criar-conta]
      P2 & P3 & LY --> S[session.svelte.ts]
      S --> C[api/client.ts]
      LY --> T[theme.svelte.ts]
      LY --> N[toasts.svelte.ts]
    end
    C -- "/api/* (mesma origem)" --> V
    subgraph Dev
      V[Vite :5173<br/>base /app] -- "tudo fora de /app" --> RA[Rails :3000]
    end
    subgraph Produção
      RS[ActionDispatch::Static<br/>public/app/**] --> RT[rota app/*path<br/>SpaController → 200.html no-cache]
    end
```

### Estrutura de diretórios

```
frontend/
  package.json, package-lock.json
  svelte.config.js | vite.config.ts      # ver Risks: local da config do Kit
  eslint.config.js, playwright.config.ts
  src/
    app.html                             # script inline de tema
    app.d.ts
    lib/
      api/client.ts, api/errors.ts, api/index.ts, api/types.ts
      session.svelte.ts
      theme.svelte.ts
      toasts.svelte.ts
      motion.ts
      navigation/return-to.ts, navigation/nav-entries.ts
      styles/tokens.css, styles/base.css
      components/AppShell.svelte, MainNav.svelte, ThemeSelect.svelte,
                 Toaster.svelte, TextField.svelte, Button.svelte, FormError.svelte
    routes/
      +layout.ts, +layout.svelte
      +page.svelte                        # /app
      entrar/+page.ts, entrar/+page.svelte
      criar-conta/+page.ts, criar-conta/+page.svelte
  e2e/                                   # Playwright; Vitest fica em *.test.ts junto do módulo
```

---

## Code Reuse Analysis

### Existing Components to Leverage

| Component | Location | How to Use |
|---|---|---|
| Tokens do tema escuro | `app/assets/stylesheets/catalog.css:9-78` (cópia normativa em `design.md` §11.3–11.5) | Valores do bloco `[data-theme="dark"]` e dos tokens de tipo, espaço, raio e navegação, copiados com os mesmos nomes. O arquivo Rails não muda (§11.7: ele é objeto de teste) |
| Pares de contraste | `test/design/contrast_test.rb` | Mesma lista de pares e mesma fórmula WCAG 2.2 (limiar 0.04045), portada para Vitest e aplicada aos dois blocos de tema |
| Contrato de sessão, CSRF e erro | `.specs/features/api-fundacao/spec.md` API-01..17 (Verified, `d1e90b5`); implementação em `app/controllers/api/base_controller.rb`, `sessions_controller.rb`, `registrations_controller.rb` e `app/views/api/sessions/_session.json.jbuilder` | Tipos de `api/types.ts` escritos à mão a partir do spec e conferidos contra esses arquivos (AD-024: sem tipos gerados). `fields` é `user.errors.to_hash`: atributo → lista de mensagens. Ordem dos `before_action` no `Api::BaseController`: `verify_authenticity_token` → `require_authentication`/`resume_session` → `allow_browser`. Logo, numa mutação o `422` de CSRF vence o `401`, e o `406` de navegador só aparece antes deles num `GET` público, como o `GET /api/session` inicial |
| Regra de navegação | Req. 13.1–13.3, 13.9, 13.10, 13.15 | Ordem das entradas, 44px, barra inferior e coluna lateral, já validadas no Hotwire |
| Mesma origem e cookie | `app/controllers/concerns/authentication.rb` | Nada a mudar: a sessão da SPA é o mesmo cookie; entrar pela SPA também autentica o Hotwire |

### Integration Points

| System | Integration Method |
|---|---|
| API Rails `/api/*` | `fetch` com `credentials: "same-origin"` via `api/client.ts`; em dev, pelo proxy do Vite |
| Páginas Hotwire (`/catalog`, `/progress`, `/decks`) | Links com `data-sveltekit-reload` (navegação de página inteira), SPA-26 |
| Rails produção | `public/app/` (estáticos) + `get "app(/*path)"` → `SpaController#show` |
| Docker | Serviço `frontend` no compose (dev); estágio `frontend-build` no `Dockerfile`; serviço `e2e` com perfil próprio |

---

## Components

### Entrega em dev — serviço `frontend` (SPA-01)

- **Purpose**: subir o Vite junto do Rails com `docker compose up`.
- **Location**: `docker-compose.yml` (serviço novo), `frontend/vite.config.ts`.
- **Interfaces**:
  - Serviço `frontend`: imagem `node:<LTS fixada>-slim`, `command: sh -c "npm ci && npm run dev -- --host 0.0.0.0 --port 5173"`, volume do código + volume nomeado `frontend_node_modules` (mesmo padrão do `bundle`, para não sombrear com o `node_modules` do host), porta `5173:5173`, `depends_on: app`.
  - Proxy do Vite: chave regex `^/(?!app(/|$))` → `http://app:3000`, **sem `changeOrigin`**. O `Host` chega ao Rails como `localhost:5173`; a checagem de origem do CSRF compara `Origin` com `request.base_url`, e os dois batem.
  - `server.allowedHosts`: `localhost` e `frontend` (o serviço `e2e` acessa pelo nome do serviço).
- **Dependencies**: `config/environments/development.rb` ganha `config.hosts << "frontend"` (o Rails recusa por padrão host fora de `localhost`).
- **Reuses**: padrão de volume nomeado do `bundle` e o comentário de "comando único" do `app`.

### Entrega em produção — build + `SpaController` (SPA-02, 03, 05)

- **Purpose**: servir a SPA em `/app/*` no mesmo processo Rails.
- **Location**: `Dockerfile` (estágio novo), `config/routes.rb`, `app/controllers/spa_controller.rb`, `config/application.rb`, `.gitignore`, `.dockerignore`.
- **Interfaces**:
  - Estágio `frontend-build` (`FROM node:<LTS>-slim`): `npm ci && npm run build && test -f build/200.html`. O `test -f` faz o build falhar sem a página de entrada (edge case). A imagem final faz `COPY --from=frontend-build /frontend/build /rails/public/app`; Node não entra na imagem final.
  - Rota, **última** do arquivo: `get "app(/*path)" => "spa#show", format: false, constraints: ->(req) { !req.path.start_with?("/app/_app/") }`. Um caminho sob `/app/_app/` sem arquivo cai no 404 padrão do Rails (edge case do chunk antigo).
  - `SpaController < ActionController::Base`. Não herda `ApplicationController`: sem `Authentication`, porque a página é pública e a sessão é decidida pela API; sem `allow_browser`, que responderia HTML 406. Action `show`: `send_file Rails.configuration.x.spa_entry_path, type: "text/html", disposition: "inline"` com `Cache-Control: no-cache`; sem o arquivo, `head :not_found`.
  - `config.x.spa_entry_path` vale `Rails.public_path.join("app/200.html")`; o teste aponta para um arquivo temporário. É costura de teste, não configuração de produto: os testes rodam em paralelo (`parallelize(workers: :number_of_processors)`) e não podem escrever em `public/`.
  - Os assets com hash ficam sob `/app/_app/immutable/` e são servidos pelo `ActionDispatch::Static` com o cabeçalho global atual (`public, max-age=1 ano`). Não existe `public/app/index.html`, então `GET /app` não é atendido pelo estático e chega à rota.
  - `.gitignore`: `/public/app`. `.dockerignore`: `frontend/node_modules`, `frontend/build`.
- **Dependencies**: `adapter-static` com `fallback: "200.html"` e `paths.base = "/app"`.
- **Reuses**: o `public_file_server` existente.

### Cliente HTTP — `$lib/api/client.ts` (SPA-06..13)

- **Purpose**: porta única para a API, dona das regras do contrato.
- **Interfaces**:
  - `createApiClient(deps: { fetch: typeof fetch; onUnauthenticated: () => void; currentUserEmail: () => string | null; onSessionChanged: (user: SessionUser) => void; timeoutMs?: number }): ApiClient` (padrão `timeoutMs = 15000`). `currentUserEmail` e `onSessionChanged` vêm da sessão; o cliente continua sem importar a sessão, e os testes os passam como funções falsas.
  - `ApiClient.get<T>(path, query?)`, `.post<T>(path, body?)`, `.patch<T>`, `.put<T>`, `.delete<T>` → `Promise<T>` com o `data` do envelope; falha lança `ApiError`.
  - `ApiClient.setCsrfToken(token: string | null)`.
- **Comportamento**:
  - Corpo JSON (`Content-Type` e `Accept: application/json`), `credentials: "same-origin"`, `X-CSRF-Token` só em mutação (SPA-07).
  - Toda resposta de sucesso com `data.csrf_token` em string troca o token (SPA-08). Isso cobre as quatro rotas do spec sem lista fixa de caminhos.
  - `401` com `code === "unauthenticated"` → `onUnauthenticated()` e lança o erro (SPA-09), exceto em `DELETE /api/session`, que só lança: o `signOut()` trata esse `401` como saída concluída (edge case da sessão já encerrada). Um `401 invalid_credentials` só lança (edge case do login).
  - `422 invalid_csrf_token` numa mutação → `GET /api/session` (troca o token) e compara `data.user?.email ?? null` com `currentUserEmail()` (SPA-10). Igual: um reenvio, marcado por parâmetro interno `retried`, sem estado global; o segundo `422` lança. `null` onde havia usuário: `onUnauthenticated()` e lança o `ApiError` `unauthenticated` (status 401, "Faça login para continuar.", a mensagem da API); em `DELETE /api/session`, só lança, sem `onUnauthenticated()`, pela mesma exceção do `401` (SPA-22). Este é o caminho real do "Sair" depois de um logout em outra aba: o `Api::BaseController` roda `verify_authenticity_token` antes de `require_authentication` (ordem dos `before_action`, conferida com `bin/rails runner` no Rails 8.0.5.1), e o `reset_session` da outra aba já invalidou o token, então a resposta é `422`, não `401`. Outro e-mail: `onSessionChanged(user)` (a sessão troca `user` e navega para `/app`) e lança `ApiError` `session_changed` (status 422, "A sessão mudou em outra aba. Confira a conta e tente de novo."). O e-mail é a identidade disponível: o `user` da API só tem `email`, que é único (índice do `users`).
  - Tempo limite com `AbortSignal.timeout(timeoutMs)`; `TypeError` do `fetch` e `TimeoutError`/`AbortError` viram `network_error` (SPA-12).
  - JSON inválido ou sem `data`/`error` no topo vira `unexpected_response` (SPA-13).
- **`$lib/api/errors.ts`**: `class ApiError extends Error { status: number; code: string; fields: Record<string, string[]> }`, com `message` vindo da API sem alteração (SPA-11).
- **`$lib/api/index.ts`**: instância única `api`, ligada ao `fetch` global e ao `handleUnauthenticated` da sessão.
- **SPA-06 por construção**: `eslint.config.js` proíbe `fetch` com `no-restricted-globals`, liberado só em `src/lib/api/client.ts`. O gate de lint falha em qualquer outra chamada.

### Sessão — `$lib/session.svelte.ts` (SPA-14..24)

- **Purpose**: estado de sessão e as quatro transições.
- **Interfaces**:
  - `session`: objeto `$state` `{ status: "loading" | "ready" | "error"; user: { email: string } | null; error: ApiError | null }`.
  - `loadSession(): Promise<void>`, `signIn(email, password)`, `signUp({ email, password, password_confirmation })`, `signOut()`: cada uma chama a API, atualiza `session.user` e devolve `void` ou lança `ApiError`.
  - Corpos, conforme a API implementada: `signIn` → `POST /api/session` com `{ email, password }` no topo (`app/controllers/api/sessions_controller.rb`); `signUp` → `POST /api/registration` com `{ user: { email, password, password_confirmation } }` (`app/controllers/api/registrations_controller.rb`). Sem o envelope `user`, a API trata o cadastro como vazio e responde `422` com todos os campos em branco, uma falha que parece erro do usuário. Teste unitário fixa os dois corpos.
  - `signOut()` trata como saída concluída (SPA-22) tanto o `200` quanto o `ApiError` `unauthenticated` vindo de `DELETE /api/session`, seja o `401` direto, seja o `user` nulo na renovação do SPA-10: nos dois casos põe `user = null`, navega para `base` e emite "Sessão encerrada.". Qualquer outro erro chega à tela.
  - `handleUnauthenticated()`: põe `user = null` e navega para `` `${base}/entrar?return_to=${encodeURIComponent(atual)}` ``, sem navegar se a rota atual já é `/entrar` ou `/criar-conta`.
- **Carga inicial (SPA-14, 15)**: `routes/+layout.ts` exporta `ssr = false`, `prerender = false` e um `load` que chama `loadSession()` e captura qualquer `ApiError` em `session.status = "error"` (SPA-15): `network_error`, `unexpected_response` e erros da API como `406 unsupported_browser`, que o `allow_browser :modern` do `Api::BaseController` devolve a navegador antigo mesmo com a página da SPA servida. O `+layout.svelte` só renderiza `children` com `status === "ready"`; com `"error"`, mostra a mensagem e o botão "Tentar novamente", que chama `refreshAll()` (ver Tech Decisions). O `load` do layout raiz não depende de URL, então roda uma vez por carga de página.
- **Guarda de já autenticado (SPA-24)**: `entrar/+page.ts` e `criar-conta/+page.ts` fazem `await parent()` e lançam `redirect(307, base)` com `session.user`.
- **Destino pós-login (SPA-23)**: `$lib/navigation/return-to.ts` exporta `safeReturnTo(raw: string | null): string`. Decodifica com `decodeURIComponent` dentro de `try`; aceita só se começa por `${base}/` e não contém `//` nem `\`; senão, `base`.

### Formulários — `TextField`, `Button`, `FormError` e as duas páginas (SPA-16..21)

- **`TextField.svelte`**: props `name`, `label`, `type`, `autocomplete`, `value` (`$bindable`), `errors: string[]`. Renderiza `<label>`, `<input>` e uma lista de erros com id estável; com erro, `aria-invalid="true"` e `aria-describedby` apontando para a lista. Expõe `focus()`.
- **`Button.svelte`**: props `pending`, `variant: "primary" | "secondary"`. Com `pending`, `disabled` e `aria-busy="true"`; alvo de 44px.
- **`FormError.svelte`**: bloco com `tabindex="-1"`, `role="alert"`, rótulo escrito "Erro:" e `focus()`.
- **Páginas**: estado local `$state` `{ pending, formError, fieldErrors }`. `onsubmit` com `preventDefault`; se `pending`, retorna (SPA-21). No erro: `invalid_credentials` → `formError`, limpa a senha e foca o `FormError` (SPA-17); `validation_failed` → distribui `fields` entre os campos conhecidos (`email`, `password`, `password_confirmation`), junta o resto em `formError` (SPA-20) e foca o primeiro campo inválido na ordem do formulário depois de `tick()` (SPA-19); `network_error` e outros → `formError` com `message`. No sucesso: `goto(safeReturnTo(page.url.searchParams.get("return_to")))`.
- **Validação nativa**: `required` e `type="email"`; `novalidate` **não** é usado.
- **Chaves de `fields` no cadastro**, conferidas no `User` e no `has_secure_password` do activemodel 8.0.5.1: só `email` (`blank`, `taken`), `password` (`blank`, `too_short`, `password_too_long`) e `password_confirmation` (`confirmation`). `password_challenge` só aparece quando o atributo é atribuído, e o controller não o permite; `password_digest` nunca é chave. O SPA-20 é um ramo defensivo, inalcançável com o model atual. As mensagens vêm sem o nome do atributo (`errors.to_hash`, por exemplo "não pode ficar em branco" e "não é igual a Senha"), então o rótulo do campo dá o contexto. O `message` do envelope ("Dados inválidos.") não é exibido quando todo `fields` tem campo.

### Casco — `AppShell`, `MainNav`, `ThemeSelect` (SPA-25..30)

- **`AppShell.svelte`**: grade CSS com três áreas, `brand` (marca + `ThemeSelect`), `nav` e `main`. Abaixo de 64rem: `brand` em cabeçalho no topo, `nav` fixa embaixo, `main` com `padding-bottom: calc(var(--nav-height) + env(safe-area-inset-bottom))`. A partir de 64rem: coluna lateral de `--sidebar-width` com `brand` e `nav` empilhados no topo, superfície `surface-raised` com `border`. O mesmo DOM nas duas larguras; só o CSS muda, então cruzar 64rem não remonta nada nem perde o foco (edge case).
- **`$lib/navigation/nav-entries.ts`**: `navEntries(user)` devolve a lista ordenada de entradas, cada uma link (`label`, `href`, `reload`) ou a ação "Sair". Catálogo, Minha pasta e Baralhos com `reload: true` e href Hotwire enquanto a fatia não existe (SPA-26); cada fatia troca a sua entrada. Teste unitário fixa a ordem do Req. 13.1 (SPA-25).
- **`MainNav.svelte`**: `<nav aria-label="Principal">` com lista; `aria-current="page"` pela rota de `page.url.pathname` (`$app/state`); a entrada atual tem fundo `surface-sunken` e `font-weight: var(--nav-current-weight)` (SPA-27). "Sair" é `<button>` com fundo `transparent`, chama `signOut()` e emite o sucesso "Sessão encerrada.".
- **`ThemeSelect.svelte`**: `<label>Tema</label>` + `<select>` nativo com "Sistema", "Claro" e "Escuro", 44px, ligado a `theme.preference`.

### Temas — `tokens.css`, script inline e `theme.svelte.ts` (SPA-31..40)

- **`styles/tokens.css`**: `:root` com tipo, espaço, raio, navegação, duração e easing (iguais nos dois temas); `:root[data-theme="dark"]` com `color-scheme: dark` e os dez tokens de cor do §11.3; `:root[data-theme="light"]` com `color-scheme: light` e os mesmos dez nomes (SPA-32, 39). Nenhum componente usa seletor de tema: o gate procura `data-theme` fora de `tokens.css` e `app.html`.
- **Script inline em `app.html`** (antes de `%sveltekit.head%`): lê `localStorage["bindr-theme"]` em `try`; valor fora de `light`/`dark` vira `system`; resolve `system` por `matchMedia("(prefers-color-scheme: dark)")`; grava `data-theme` e `data-theme-preference` no `<html>` (SPA-37, 38). Não escreve no console.
- **`theme.svelte.ts`**: `theme` `$state` `{ preference: "system" | "light" | "dark" }`, iniciado de `data-theme-preference`. `setPreference(p)` grava `localStorage` em `try` e reaplica `data-theme` (SPA-36). Com `system`, um ouvinte de `matchMedia(...).change` reaplica (SPA-35); o ouvinte é removido ao sair de `system`.
- **Anel de foco (SPA-40)**: em `base.css`, `:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }`.

#### Paleta clara proposta (valores verificados, OKLCH L/C/H e WCAG)

| Token | Escuro (§11.3, inalterado) | Claro proposto | OKLCH do claro |
|---|---|---|---|
| `surface-base` | `#051b23` | `#f2f8fb` | 0.975 / 0.008 / 229 |
| `surface-raised` | `#102b36` | `#ffffff` | 1.000 / 0 / — |
| `surface-sunken` | `#011018` | `#e3edf2` | 0.940 / 0.013 / 229 |
| `border` | `#1c3a47` | `#cedadf` | 0.881 / 0.015 / 225 |
| `border-strong` | `#717e84` | `#69777e` | 0.560 / 0.020 / 229 |
| `ink` | `#e9f0f3` | `#0b222c` | 0.239 / 0.035 / 229 |
| `ink-muted` | `#9ba7ad` | `#475860` | 0.449 / 0.025 / 228 |
| `accent` | `#ff9e14` | `#995b00` | 0.530 / 0.118 / 66 |
| `on-accent` | `#051b23` | `#ffffff` | 1.000 / 0 / — |
| `danger` | `#ff5448` | `#be241f` | 0.520 / 0.190 / 28 |

Contrastes do claro (base / raised / sunken): `ink` 15.32 / 16.41 / 13.80; `ink-muted`
6.92 / 7.41 / 6.24; `accent` 5.09 / 5.45 / 4.59; `danger` 5.66 / 6.07 / 5.10;
`border-strong` 4.32 / 4.62 / 3.89; `on-accent` sobre `accent` 5.45 e sobre `danger`
6.07. O escuro passa nos mesmos pares sem mudança (menor folga: `danger` sobre
`raised`, 4.65). O claro não reproduz o 1.20:1 entre `raised` e `base` (fica em
1.07:1); a regra do §11.3 de sempre delimitar com borda continua valendo.

O `accent` claro é um âmbar escuro (L 0.53): um âmbar claro como o do tema escuro
dá cerca de 2:1 sobre branco e reprova até o anel de foco. A matiz 66° se mantém (Req. 12.4).

- **Teste de contraste (SPA-33)**: Vitest lê `tokens.css`, extrai os dois blocos e
  aplica os pares de `test/design/contrast_test.rb` a cada um.
- **Teste de matiz (SPA-34)**: converte cada token de cor para OKLCH; com croma
  ≥ 0.01, a matiz precisa cair em 228° ± 8 (petróleo), 66° ± 8 (âmbar) ou 28° ± 8
  (só `danger`). Croma abaixo de 0.01 é acromático e passa (branco do claro).

### Movimento — tokens, corte e View Transitions (SPA-41..43)

- **Tokens** em `tokens.css`: `--duration-fast: 120ms`, `--duration-base: 200ms`, `--duration-slow: 320ms`, `--ease-standard: cubic-bezier(0.2, 0, 0, 1)`, `--ease-exit: cubic-bezier(0.3, 0, 1, 1)`.
- **Corte em CSS** (`base.css`): `@media (prefers-reduced-motion: reduce)` zera os três tokens de duração e força `transition-duration`/`animation-duration` em `0s` para `*`, `::before`, `::after` e `::view-transition-*`.
- **Corte nas transições do Svelte**: as do Svelte 5 não leem CSS. `$lib/motion.ts` exporta `duration(ms: number): number`, que devolve `0` com `prefersReducedMotion.current` (`svelte/motion`, desde 5.7). Toda transição do Svelte passa por ela.
- **Propriedades animadas**: só `transform` e `opacity`, conferido por `grep` no gate sobre `transition:` e `@keyframes` em `src/`.
- **View Transitions (SPA-43)**: no `+layout.svelte`, `onNavigate` retorna sem nada quando `!document.startViewTransition` ou com movimento reduzido; senão, devolve a `Promise` que chama `startViewTransition` e espera `navigation.complete`, como na doc do `$app/navigation`.

### Mensagens — `toasts.svelte.ts` e `Toaster.svelte` (SPA-44..46)

- **`toasts.svelte.ts`**: `toasts` `$state` lista `{ id; kind: "success" | "error"; message }`; `notifySuccess(msg)` agenda a remoção em 5000 ms; `notifyError(msg)` não agenda; `dismiss(id)`.
- **`Toaster.svelte`**: duas regiões sempre montadas no DOM, porque uma live region criada junto com a mensagem não é anunciada: `<div aria-live="polite">` para sucesso e `<div role="alert">` para erro. A camada é fixa (`position: fixed`), acima da barra inferior no mobile e no canto inferior direito no desktop, então não desloca conteúdo (SPA-46). O erro tem rótulo escrito "Erro:" e botão "Fechar" de 44px (SPA-45). Nenhuma chamada de `focus()`.

---

## Data Models

```typescript
// $lib/api/types.ts — espelho manual do spec da api-fundacao (AD-024)
export type ApiEnvelope<T> = { data: T; meta?: Record<string, unknown> };
export type ApiErrorBody = {
  error: { code: string; message: string; fields: Record<string, string[]> };
};
export type SessionUser = { email: string };
export type SessionPayload = { user: SessionUser | null; csrf_token: string };

// $lib/theme.svelte.ts
export type ThemePreference = "system" | "light" | "dark";
export type EffectiveTheme = "light" | "dark";
```

`localStorage["bindr-theme"]`: string `"system" | "light" | "dark"`; qualquer outro valor é lido como `"system"`.

---

## Error Handling Strategy

| Error Scenario | Handling | User Impact |
|---|---|---|
| Rede ausente ou > 15 s | `ApiError` `network_error` | Formulário: mensagem acima dele; carga inicial: tela com "Tentar novamente" |
| `401 unauthenticated` fora do login | `handleUnauthenticated()` | Vai para `/app/entrar?return_to=…` e volta depois de entrar |
| `401 invalid_credentials` | Só lança | "E-mail ou senha inválidos." acima do formulário, foco nela |
| `422 invalid_csrf_token`, mesmo usuário | Renova e reenvia uma vez | Nenhum, se o reenvio passar; senão, a mensagem da API ("Token de segurança inválido.") |
| `422 invalid_csrf_token` no "Sair", sessão encerrada em outra aba | Renova; `user` nulo; `signOut()` conclui | Vai para `/app` com "Sessão encerrada.", sem passar por `/app/entrar` |
| `422 invalid_csrf_token`, outra conta entrou em outra aba | Renova, não reenvia, `session_changed` | Vai para `/app` com a conta nova e o erro "A sessão mudou em outra aba. Confira a conta e tente de novo." |
| `422 validation_failed` | `fields` por campo, resto no topo | Mensagem junto do campo, foco no primeiro inválido |
| `400 bad_request`/`invalid_json`, `500 internal_error` | Só lança | Formulário: `message` da API acima dele; carga inicial: tela com "Tentar novamente" |
| `406 unsupported_browser`/`not_acceptable` | Só lança | Carga inicial: a `message` da API ("Navegador não suportado. Atualize para uma versão recente." ou "Formato não suportado.") com "Tentar novamente"; nunca HTML, porque a API não o devolve. O `not_acceptable` só nasce de `UnknownFormat`: as rotas têm `format: false` e `format: :json` fixo, então o `Accept` do cliente não o provoca (`contract_test.rb`, "Accept text/html não muda o formato") |
| Resposta fora do envelope | `unexpected_response` | "Erro inesperado. Tente novamente." |
| `localStorage` indisponível | `try/catch` silencioso | Tema segue o sistema; a escolha não persiste |
| `GET /app/_app/<chunk antigo>` em produção | Constraint da rota exclui `_app/` | `404` no chunk. Se o Kit recarrega a página sozinho nessa falha é ⚠️ VERIFICAR na versão instalada |
| `200.html` ausente em produção | `test -f` no estágio de build; em runtime `head :not_found` | Build falha antes do deploy |

---

## Risks & Concerns

| Concern | Location (file:line) | Impact | Mitigation |
|---|---|---|---|
| Cache de 1 ano para todo `public/` | `config/environments/production.rb:19` | Uma página de entrada servida pelo estático ficaria presa no cache após deploy | Não gerar `index.html` (fallback `200.html`) e servir a entrada pelo `SpaController` com `no-cache`. Teste de request confirma o cabeçalho |
| Proxy de dev e checagem de origem do CSRF | `config/environments/development.rb` (hosts) | Com `changeOrigin` o `Host` viraria `app:3000`, e o CSRF falharia por origem diferente: `forgery_protection_origin_check` está ligado (padrão do Rails, conferido com `bin/rails runner`) e o `development.rb` não declara `config.hosts`, então só os hosts padrão (`localhost`) passam hoje | Proxy sem `changeOrigin`; `config.hosts << "frontend"` só em development; teste E2E de login cobre o caminho |
| Script inline e CSP | `config/initializers/content_security_policy.rb` (todo comentado) | Se um dia a CSP for ligada, o script de tema é bloqueado e a tela pisca | Registrado aqui; quem ligar a CSP precisa do hash do script. Fora do escopo |
| E2E escreve no banco de desenvolvimento | serviço `e2e` → `frontend` → `app` | Contas de teste acumulam no banco de dev | E-mail único por execução (`e2e-<timestamp>@exemplo.test`); sem limpeza automática, registrado |
| Versão do SvelteKit e local da config | doc atual mostra `sveltekit({ adapter })` no `vite.config` | Exemplos podem não bater com a versão instalada | A task de scaffold fixa a versão no lockfile e segue a doc daquela versão (MCP `plugin:svelte`). ⚠️ VERIFICAR na instalação |
| Internos do Vite sob `base` | `vite.config.ts` | Se o cliente do Vite (`/@vite/client`) ficar fora de `/app`, o proxy regex o mandaria ao Rails e o HMR quebraria | Conferir no scaffold que os internos ficam sob `/app/`; se não, excluir `^/(@vite|@fs|@id|node_modules)` da regex. ⚠️ VERIFICAR |
| Sem navegador no container `app` | CLAUDE.md, dívidas | O teste de UI no Rails continua textual | O serviço `e2e` com a imagem do Playwright resolve para a SPA; o Hotwire segue como está |

---

## Tech Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Tema por atributo resolvido no script inline | `data-theme="light|dark"` sempre presente; CSS com dois blocos | Uma fonte da verdade (o atributo), sem `light-dark()` (Safari só a partir de 17.5, abaixo do `allow_browser :modern`) e sem `@media` duplicando cada token |
| Seletor de tema | `<select>` nativo | Acessível sem código, 44px fácil, cabe no cabeçalho de 360px |
| Troca de token CSRF | Qualquer `data.csrf_token` em string | Cobre as quatro rotas do SPA-08 sem lista de caminhos para manter |
| Retry da carga de sessão | `refreshAll()` de `$app/navigation` | `invalidateAll` está marcado como deprecated na doc atual; se a versão instalada não tiver `refreshAll`, usar `invalidateAll` |
| Sem lib de formulário nem de store | Runes + componentes próprios | Decisão do dono (sem lib de store); dois formulários não justificam dependência |
| Vitest | Ambiente `jsdom`, `@testing-library/svelte`, `resolve.conditions: ["browser"]` | Padrão de teste de componente do Svelte 5 no cliente. ⚠️ VERIFICAR as opções na versão instalada |
| Serviço `e2e` | Perfil `e2e` do compose, imagem `mcr.microsoft.com/playwright:v<mesma versão do @playwright/test>-noble`, `baseURL: http://frontend:5173/app/` | Não sobe no `docker compose up` (o Req. 11.6 continua um comando); a versão da imagem igual à do pacote evita navegador incompatível. O User-Agent do Chromium headless (`HeadlessChrome/131`) não é bloqueado pelo `allow_browser :modern` (conferido com `ActionController::AllowBrowser::BrowserBlocker` no Rails 8.0.5.1) |
| Gates do front | quick = `npm run check && npm run lint && npm test` (no serviço `frontend`); e2e = `docker compose --profile e2e run --rm e2e`; Rails = gate full da feature, em série com o e2e (flake D-10 do relógio do host) | Mesmo formato dos gates do CLAUDE.md |
| Mensagens nos testes | Todo teste que cobre um critério com texto fixo (SPA-12, 13, 15, 17, 45) compara a mensagem exata, não só o `code` | Lição L-064 da `api-fundacao`: o Verifier achou lacuna de precisão onde só o código era conferido |

Nenhuma decisão aqui é de projeto além da AD-025, já registrada.
