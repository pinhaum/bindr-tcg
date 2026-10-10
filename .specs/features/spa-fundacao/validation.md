# Validação — spa-fundacao

**Veredito**: FAIL
**Data**: 2026-10-10
**Spec**: `.specs/features/spa-fundacao/spec.md` (SPA-01..46 e 9 edge cases)
**Diff range**: `02f0f05..HEAD` (31 commits; HEAD = `59d5654`)
**Verifier**: sub-agente independente (autor ≠ verificador)

Implementação conforme em todos os 46 critérios e nos 9 edge cases (comportamento provado por teste e, onde o teste usa `fetch` falso, também por probe contra a API real). O FAIL vem **só do sensor**: 2 mutantes sobreviveram (G1, G2), e há 2 lacunas menores de guarda (G3, G4). Nenhuma lacuna é de implementação; as quatro são de teste. Testes existentes não foram editados nem removidos: `git diff --name-status 02f0f05..HEAD -- test` mostra só `A test/integration/spa_test.rb`; fora de `.specs/`, `.context/`, `CLAUDE.md`, `frontend/` e configs, o diff toca apenas `app/controllers/spa_controller.rb` (SPA-04). `catalog.css`, `app/views` e os controllers do Hotwire não mudaram.

---

## Conclusão das tasks

T1–T22 estão `[x]` em `tasks.md` (84 checkboxes `[x]`, 0 `[ ]`; 22 cabeçalhos `### T`). Nenhuma task parcial ou bloqueada.

---

## Critérios de aceitação ancorados na spec

Legenda: ✅ asserção no resultado exato do spec; ⚠️ lacuna de precisão do spec (sem lacuna de implementação); ❌ lacuna. Caminhos relativos a `frontend/` exceto onde indicado. "Probe" = spec Playwright que eu escrevi só na cópia do sensor (descartada), contra a API real.

| AC | Resultado definido no spec | `arquivo:linha` + asserção | |
|---|---|---|---|
| SPA-01 | SPA em `:5173/app`; tudo fora de `/app` vai ao Rails pelo proxy, sem comando extra | `vite.config.ts:19` chave `'^/(?!app(/|$))': { target: 'http://app:3000' }`; `e2e/sessao.spec.ts:66` `await expect(page).toHaveURL(/\/app\/?$/)` (criar conta passa por `/api/*` via proxy); curl meu com a stack real: `/api/session` 200 JSON com `csrf_token`, `/catalog` 200 HTML do Hotwire, `/app/entrar` 200 SPA, `/app/@vite/client` 200 | ⚠️ `GET /app` responde `308 → ./app/` (base do Vite) e termina em 200; o spec diz "em `/app`" sem tratar a barra final |
| SPA-02 | `GET /app` e `/app/<qualquer>` sem arquivo → 200, `200.html`, `Cache-Control: no-cache` | `test/integration/spa_test.rb:25-27` `assert_equal FIXTURE_BODY, response.body`; `assert_equal "text/html", response.media_type`; `assert_includes response.headers["Cache-Control"], "no-cache"` (3 caminhos, `:21`); imagem de produção (meu `docker build -f Dockerfile .`): `/app`, `/app/x`, `/app/entrar` → `200`, `cache-control: no-cache`, `content-type: text/html` | ✅ |
| SPA-03 | arquivo do build sob `/app/` pelo estático, `max-age` de 1 ano | sem teste automatizado; imagem de produção: `/app/_app/immutable/entry/app.Di7zYheh.js` → `200`, `cache-control: public, max-age=31556952` | ✅ (evidência de execução, sem teste no repo) |
| SPA-04 | suíte Rails existente passa sem edição | `git diff --name-status 02f0f05..HEAD -- test` → só `A test/integration/spa_test.rb`; gate Rails 1912 runs, 0 failures | ✅ |
| SPA-05 | `docker compose build` gera a SPA num estágio Node do `Dockerfile` de produção, sem Node na final | `Dockerfile:63` `RUN npm run build && test -f build/200.html`; `Dockerfile:74` `COPY --from=frontend-build /frontend/build /rails/public/app`; meu `docker build -f Dockerfile .` terminou, imagem final tem `/rails/public/app/200.html` e `_app/immutable/`, `command -v node` vazio | ⚠️ `docker compose build` constrói `Dockerfile.dev` (`docker-compose.yml:21`), não o de produção: o gate literal não exercita o estágio Node. Verifiquei com `docker build -f Dockerfile .` |
| SPA-06 | um módulo cliente, `credentials: "same-origin"`, nenhuma tela chama `fetch` | `src/lib/api/client.test.ts:41` `expect(lastCall(fetch).init.credentials).toBe('same-origin')`; `eslint.config.js:18-25` `no-restricted-globals` em `fetch` com exceção só em `client.ts`; `grep` de `fetch(`: só `client.ts:79` e `index.ts:6` (injeção) | ✅ (ver D3: `globalThis.fetch` escapa da regra) |
| SPA-07 | `X-CSRF-Token` em POST/PATCH/PUT/DELETE | `client.test.ts:158` `expect(lastCall(fetch).headers.get('X-CSRF-Token')).toBe('tok-1')` (`it.each` dos 4 verbos, `:152`); ausente em GET `:167` `.has('X-CSRF-Token')).toBe(false)` | ✅ |
| SPA-08 | `data.csrf_token` troca o token antes da próxima requisição | `client.test.ts:190,194` `expect(...get('X-CSRF-Token')).toBe('tok-2')` / `'tok-3'`; mantém sem string `:205` `.toBe('tok-1')`; fluxo real nas quatro rotas: `e2e/sessao.spec.ts:54-129` (criar conta → sair → entrar → sair com CSRF real) | ✅ (teste unitário genérico, não por rota) |
| SPA-09 | `401 unauthenticated` → sessão anônima + `/app/entrar?return_to=<caminho atual com query>`; exceto `DELETE /api/session` | `client.test.ts:437` `expect(onUnauthenticated).toHaveBeenCalledTimes(1)` (GET e POST, `:429`); exceção `:448` `.not.toHaveBeenCalled()`; `api/index.test.ts:58` `expect(goto).toHaveBeenCalledWith('/app/entrar?return_to=%2Fapp%2Fx%3Fy%3D1')`; `session.test.ts:205-206` `expect(session.user).toBeNull()` + mesmo `goto` | ✅ |
| SPA-10 | 422 `invalid_csrf_token`: 1 `GET /api/session` + 1 reenvio (mesmo usuário/anônimo); `null` → como SPA-09 sem reenviar (DELETE → SPA-22); outro usuário → `session_changed` + mensagem exata, sem reenviar; 2º 422 sem novo reenvio | `client.test.ts:481-485` `toEqual([POST tok-old, GET /api/session csrf null, POST tok-new])`; `:519` `.toBe('Token de segurança inválido.')` + `:520` `calls()).toHaveLength(3)`; `:541-546` null (`onUnauthenticated` 1×, `'Faça login para continuar.'`, 2 chamadas); `:554-558` DELETE+null; `:570-576` outro e-mail (`onSessionChanged` com `{email:'outro@b.c'}`, `.toBe('A sessão mudou em outra aba. Confira a conta e tente de novo.')`, 2 chamadas); `errors.test.ts:56` idem; probe P2/P3 reais (abas trocando sessão) passaram | ✅ |
| SPA-11 | erro tipado com `status`, `code`, `message`, `fields` como vieram | `client.test.ts:238-241` `.status 422`, `.code 'validation_failed'`, `.message 'Dados inválidos.'`, `.fields toEqual({email:['não pode ficar em branco']})`; `:253` `'Faça login para continuar.'` | ✅ |
| SPA-12 | sem resposta ou >15 s → `network_error`, "Sem conexão com o servidor. Tente novamente." | `client.test.ts:304,313,343,358` `expect(error.message).toBe('Sem conexão com o servidor. Tente novamente.')` (TypeError, Timeout/Abort, sinal real, abort ao ler o corpo); `:100` `AbortSignal.timeout` com `15000`; `errors.test.ts:36-44` | ✅ (⚠️ `status 0` do erro não é definido pelo spec; escolha aceita S-04) |
| SPA-13 | corpo fora do envelope → `unexpected_response`, "Erro inesperado. Tente novamente." | `client.test.ts:377-378` `.code 'unexpected_response'` / `.message 'Erro inesperado. Tente novamente.'` (9 corpos: HTML, JSON inválido, vazio, sem `data`/`error`, não-objeto, null, erro com 200, data com 500, erro malformado, `:381-399`) | ✅ |
| SPA-14 | `GET /api/session` 1× antes da 1ª rota; guarda `user` e `csrf_token` | `src/routes/layout.test.ts:28` `expect(loadSession).toHaveBeenCalledOnce()` e `:29` `statusDuringCall).toBe('loading')`; `src/lib/session.test.ts:55-58` `api.get` com `/api/session`, `session.user` `toEqual(ana)`, `status 'ready'`; `src/routes/layout.svelte.test.ts:41` rota não aparece em `loading`; probe P1: 1 chamada na carga | ✅ |
| SPA-15 | falha inicial (qualquer erro) → mensagem do erro + "Tentar novamente" que repete a chamada, sem a rota | `layout.svelte.test.ts:83-85` (4 erros: `network_error`, `unexpected_response`, `406 unsupported_browser`, `500`) `getByText(error.message)`, botão, `queryByText('conteúdo da rota')` ausente; `:95` `expect(nav.refreshAll).toHaveBeenCalledOnce()`; probe P1 real: após falha, "Tentar novamente" faz exatamente +1 `GET /api/session` e o casco aparece | ✅ |
| SPA-16 | enviar `/app/entrar` → `POST /api/session`; 200 → sessão + destino pós-login | `src/routes/entrar/page.test.ts:60-61` `expect(nav.goto).toHaveBeenCalledWith('/app')`, `expect(signIn).toHaveBeenCalledWith('ana@example.com','segredo123')`; `session.test.ts:87` corpo `{ email, password }` no topo; `e2e/sessao.spec.ts:94-100` | ✅ |
| SPA-17 | `401 invalid_credentials` → `error.message` acima do formulário, e-mail mantido, senha limpa, foco na mensagem | `entrar/page.test.ts:91-95` `toHaveTextContent('E-mail ou senha inválidos.')`, `alert).toHaveFocus()`, E-mail `.toHaveValue('ana@example.com')`, Senha `.toHaveValue('')`; `e2e/sessao.spec.ts:85-89` `toBeFocused()` | ✅ |
| SPA-18 | enviar `/app/criar-conta` → `POST /api/registration`; 201 → sessão + destino | `criar-conta/page.test.ts:62-67` `signUp` com os 3 campos, `goto('/app')`; `session.test.ts:107-109` corpo `{ user: { email, password, password_confirmation } }`; `e2e/sessao.spec.ts:58-69` | ✅ |
| SPA-19 | `422 validation_failed`: mensagem por campo, `aria-describedby`, `aria-invalid="true"`, foco no 1º inválido | `criar-conta/page.test.ts:103-107` `password).toHaveFocus()`, `aria-invalid 'true'` (password e confirmação), `toHaveAccessibleDescription('é muito curto (mínimo: 8 caracteres)')` / `'não é igual a Senha'`; `:121-122` e-mail; `:108` e-mail sem `aria-invalid`; `TextField.test.ts:31-32` `aria-describedby 'field-email-errors'` | ✅ |
| SPA-20 | atributo sem campo → mensagem acima do formulário, nunca descartada | `criar-conta/page.test.ts:134,147` `alert).toHaveTextContent('Cadastro indisponível.')` / `'role: é inválido'`; `:135` "Dados inválidos." ausente | ✅ (⚠️ formato `chave: mensagem` para chave ≠ `base` não é definido pelo spec; já registrado como decisão aberta do dono) |
| SPA-21 | envio pendente: botão desabilitado, novo envio ignorado | `entrar/page.test.ts:118-120` `button).toBeDisabled()`, `signIn).toHaveBeenCalledTimes(1)`; `criar-conta/page.test.ts:192-194` idem; `Button.test.ts:24` `aria-busy 'true'` | ✅ |
| SPA-22 | "Sair" → `DELETE`; 200 (ou `401 unauthenticated`, ou `user` nulo na renovação) → anônimo, `/app`, "Sessão encerrada.", sem `/app/entrar` | `session.test.ts:132-136` `goto).toHaveBeenCalledTimes(1)` `'/app'`, `toasts[0]).toMatchObject({kind:'success', message:'Sessão encerrada.'})` (200 `:139` e `unauthenticated` `:147`); `client.test.ts:554-558`; `MainNav.test.ts:81-82`; `e2e/sessao.spec.ts:72-77`; probe P2/P5 reais (aba que já saiu; 401 simulado) | ✅ |
| SPA-23 | destino = `return_to` decodificado se começa por `/app/` sem `//` nem `\`; senão `/app` | `navigation/return-to.test.ts:19` `safeReturnTo(raw)).toBe(raw)` (9 aceitos) e `:63` `.toBe('/app')` (38 descartados: `//evil.com`, `/app//evil`, `%2F%2F`, `https:`, `\`, controle, `..`/`%2e%2e`, decodificação inválida); `entrar/page.test.ts:71,81`; `criar-conta/page.test.ts:77,87`; `e2e/sessao.spec.ts:146-148` `toHaveURL(/^http:\/\/frontend:5173\/app\/?$/)` | ✅ |
| SPA-24 | com sessão, `/app/entrar` e `/app/criar-conta` → `/app` sem formulário | `entrar/page.test.ts:130-133` `rejects.toMatchObject({status:307, location:'/app'})`; `criar-conta/page.test.ts:209-212`; `e2e/sessao.spec.ts:104-110` `toHaveURL(/\/app\/?$/)` e `getByLabel('Confirmação da senha')).toHaveCount(0)` | ✅ |
| SPA-25 | navegação: com sessão "Catálogo, Minha pasta, Baralhos, Sair"; sem "Catálogo, Entrar, Criar conta" | `navigation/nav-entries.test.ts:11-16` `toEqual(["Catálogo","Minha pasta","Baralhos","Sair"])`; `:20` `toEqual(["Catálogo","Entrar","Criar conta"])`; `AppShell.test.ts:25` | ✅ |
| SPA-26 | telas não migradas → destino Hotwire (`/catalog`, `/progress`, `/decks`), página inteira | `nav-entries.test.ts:26-28` `{ href: "/catalog", reload: true }`…; `MainNav.test.ts:69-71` `toHaveAttribute('data-sveltekit-reload')` | ✅ |
| SPA-27 | `aria-current="page"` na rota atual, distinção por fundo e peso | `MainNav.test.ts:45-47` `toHaveLength(1)`, `toHaveAttribute('aria-current','page')`; `e2e/casco.spec.ts:180-181` `expect(current.background).not.toBe(other.background)`, `expect(current.weight).toBeGreaterThan(other.weight)` | ✅ |
| SPA-28 | <64rem: barra fixa na borda inferior, entradas de largura igual, alvo ≥44px, reserva de altura | `e2e/casco.spec.ts:131-140` `nav.y + nav.height` `toBeCloseTo(viewport.height)`, `navPosition).toBe('fixed')`, larguras iguais, `reserved).toBeGreaterThanOrEqual(nav.height)`; `:155-156` `box.height/width).toBeGreaterThanOrEqual(44)` | ✅ |
| SPA-29 | ≥64rem: coluna lateral de largura fixa, abaixo da marca, superfície elevada com borda | `e2e/casco.spec.ts:119-129` `nav.x).toBe(0)`, `nav.width).toBeLessThanOrEqual(280)`, `nav.y ≥ brand.y+brand.height-1`, `borderRight).toBe('1px')`, fundo ≠ do body | ✅ |
| SPA-30 | 360px sem scroll horizontal | `e2e/casco.spec.ts:110` `expect(overflow.scrollWidth).toBeLessThanOrEqual(overflow.clientWidth)` (3 rotas, 360px); `e2e/sessao.spec.ts:20` em toda etapa da jornada nos 4 combos | ✅ |
| SPA-31 | tokens num único arquivo; nenhum componente repete valor literal que exista como token | `src/lib/styles/tokens.test.ts:133-148` tokens de movimento/tipo/espaço/raio/nav presentes; `base.css` sem cor literal `:169`; **mas** `components/ThemeSelect.svelte:26` `min-height: 44px` (= `--touch-target`) e `:29` fallback `0.5rem` (= `--radius-md`); nenhum teste/`grep` do repo cobre valores não-cor | ❌ G3 |
| SPA-32 | cada cor com valor claro e escuro, mesmos nomes; nenhum componente escolhe cor por tema | `tokens.test.ts:129-130` `toEqual(expected)` (mesmos 10 nomes + `color-scheme` nos dois blocos); `grep data-theme`/hex fora de `tokens.css`: só `theme.svelte.ts:11,25,26` (atributo, não cor) e `app.html` | ✅ |
| SPA-33 | 4.5:1 em todo par texto/superfície; 3:1 em borda de controle e anel nas 3 superfícies | `tokens.test.ts:94-95` ink e ink-muted × 3 superfícies; `:99-100` accent 4.5 e 3 × 3 superfícies; `:104` border-strong 3 × 3; `:108-110` on-accent/accent, on-accent/danger, **danger só sobre `surface-base`** | ❌ G1 (`danger` × `surface-raised`/`sunken` ausente; mutante M6c sobreviveu; Success Criterion 2 não se sustenta) |
| SPA-34 | só azul-petróleo, âmbar e `danger` | `tokens.test.ts:113-123` matiz OKLCH 228°/66° (e 28° só `danger`) ±8, croma ≥0.01, nos dois temas | ✅ |
| SPA-35 | "Sistema"/ausente segue `prefers-color-scheme` e acompanha mudança sem recarregar | `theme.test.ts:79` `data-theme` `toBe('dark')` após `change`; `e2e/casco.spec.ts:232-234` `poll(dataTheme).toBe('dark')`, `bodyBackground).toBe(DARK_BG)`, `marker).toBe('mesma-pagina')` | ✅ |
| SPA-36 | escolher Claro/Escuro aplica já, grava em `localStorage`, mantém após recarregar | `theme.test.ts:56-59` `setItem` com `('bindr-theme','light')`, `data-theme 'light'`; `ThemeSelect.test.ts` troca → `setPreference('light')`; `e2e/casco.spec.ts:265-272` fundo `LIGHT_BG`, `localStorage 'light'`, após `reload` `toHaveValue('light')` | ✅ |
| SPA-37 | tema efetivo no documento antes da 1ª pintura, sem exibir o outro tema | `app-theme-script.test.ts:38` `indexOf('<script>')).toBeLessThan(indexOf('%sveltekit.head%'))`; `e2e/casco.spec.ts:218` `expect(probe.themes).toEqual([scheme])` (observador desde antes do 1º script); `build/200.html` (meu cálculo): script inline em `idx 129`, 1º `<link rel="stylesheet">` em `idx 1637` | ✅ (em dev o CSS chega depois do 1º quadro: limitação registrada, S-14; em produção a ordem do `<head>` está correta) |
| SPA-38 | `localStorage` que lança ou valor desconhecido → "Sistema", sem erro no console | `app-theme-script.test.ts:67-68` `{theme:'dark', preference:'system'}` + `expect(error).not.toHaveBeenCalled()`; `:62` desconhecido; `theme.test.ts:66-68` `setItem` que lança não quebra; `e2e/casco.spec.ts:241-242` | ✅ |
| SPA-39 | `color-scheme` coerente com o tema efetivo | `tokens.test.ts:90` `expect(t['color-scheme']).toBe(name)`; `e2e/casco.spec.ts:63` `colorScheme` do 1º quadro ∈ `[theme,'normal']` | ✅ |
| SPA-40 | anel de foco 2px sólido `accent`, offset 2px, em todo focável | `tokens.test.ts:154-155` regex `:focus-visible { outline: 2px solid var(--accent) }` e `outline-offset: 2px` | ✅ (declaração exata; nenhum e2e lê o `outline` computado) |
| SPA-41 | durações/easing só como tokens; transições animam só `transform` e `opacity` | `tokens.test.ts:135-146` `--duration-*`, `--ease-*`; `grep transition|@keyframes|animation` em `src/`: só `fly` em `Toaster.svelte:13,20` (transform+opacity) e o corte em `base.css:34-35`; sem teste que imponha "só transform/opacity" | ✅ implementação / ⚠️ G4 (sem guarda automatizada) |
| SPA-42 | `prefers-reduced-motion: reduce` zera durações, inclusive transições do Svelte | `tokens.test.ts:177-182` `--duration-*: 0ms`, `::view-transition-*`, `transition-duration: 0s !important`; `motion.test.ts:31` `expect(duration(200)).toBe(0)`; `e2e/casco.spec.ts:316` `toEqual({transition:'0s',animation:'0s',fast:'0ms',base:'0ms',slow:'0ms'})`; controle `:323` | ✅ |
| SPA-43 | View Transition via `onNavigate` quando suportada; sem suporte, troca sem erro | `view-transition.test.ts:18-19` `not.toThrow()` e `toBeUndefined()` sem suporte; `:23-27` movimento reduzido; `:41` `start).toHaveBeenCalledOnce()`; `layout.svelte.test.ts:103` `onNavigate` com `viewTransitionOnNavigate`; `e2e/casco.spec.ts:338,339` `viewTransitions ≥ 1`, `errors).toEqual([])`; `:353,370` sem VT e sem erro | ✅ |
| SPA-44 | sucesso em `aria-live="polite"`, some em 5 s | `Toaster.test.ts:49,52,57` visível a 0 e 4999 ms, ausente após 5000; `toasts.test.ts:20-24` `toHaveLength(1)` a 4999, `(0)` a 5000 | ✅ |
| SPA-45 | erro com `role="alert"`, rótulo escrito, até fechar | `Toaster.test.ts:66,70,74` `getByText('Erro:')`, permanece após 60 000 ms, some só após clicar "Fechar"; `toasts.test.ts:31` | ✅ |
| SPA-46 | exibe a mensagem sem mover o foco nem deslocar o conteúdo | foco: `Toaster.test.ts:87` `expect(document.activeElement).toBe(button)`; deslocamento: **nenhuma asserção** (`Toaster.svelte:30` `position: fixed` sem teste). Probe P4 real: `getComputedStyle(.layer).position` = `fixed` e `scrollHeight` 720→720 | ❌ G2 (implementação conforme; sem teste) |

**Status**: 43 ✅ (alguns com ⚠️ de precisão do spec/gate: SPA-01, SPA-05, SPA-12/13), 3 ❌ de **teste** (SPA-31 G3, SPA-33 G1, SPA-46 G2), mais 1 ⚠️ de guarda (SPA-41, G4). Nenhum ❌ de implementação.

### Edge cases

- [x] Duas abas, sair numa: o `422` da outra segue o SPA-10 (`client.test.ts:532-559`: sem reenvio, `onUnauthenticated`; no "Sair" conclui pelo SPA-22); próximo `401` pelo SPA-09 (`:429-441`). Probe P2 real: com a aba A já deslogada, "Sair" na aba B mostra "Sessão encerrada.", fica em `/app`, sem passar por `/entrar`.
- [x] Troca de conta em outra aba: `client.test.ts:570-576` (`session_changed`, mensagem exata, 2 chamadas); `api/index.test.ts:73-85` (`session.user` = nova conta, `goto('/app')`). Probe P3 real: alerta "A sessão mudou em outra aba. Confira a conta e tente de novo.", URL `/app`, e-mail da conta B no `main`, nenhum "Sessão encerrada.".
- [x] `return_to` com `%2F%2F` ou esquema: `return-to.test.ts:32-35,62-63` → `/app`.
- [x] `401` no próprio `POST /api/session` é `invalid_credentials`, sem navegar: `client.test.ts:460-463` (`onUnauthenticated` não chamado, `code 'invalid_credentials'`, mensagem exata); `entrar/page.test.ts:95` `goto` não chamado.
- [x] `DELETE /api/session` com `401 unauthenticated` é saída concluída: `client.test.ts:448-449`; `session.test.ts:147-153` (`goto` 1× em `/app`, toast).
- [x] Recarregar `/app/criar-conta?return_to=/app/x` mantém o `return_to`: `criar-conta/page.test.ts:77` `goto('/app/x')` (o parâmetro vem da URL, que sobrevive ao reload por construção; nenhum e2e recarrega a página com `return_to`).
- [x] Cruzar 64rem sem recarregar nem perder foco: `e2e/casco.spec.ts:197-204` `navPosition` troca, `link).toBeFocused()`, `marker).toBe('mesma-pagina')`.
- [x] `GET /app/_app/<inexistente>` → `404`: `spa_test.rb:40` `assert_response :not_found` e `:41` `assert_not_equal FIXTURE_BODY`; produção real: `/app/_app/immutable/velho.js` → `404`. (Débito D1: `%5F` escapa da constraint.)
- [x] Build sem `200.html` falha o build, não o 1º request: `Dockerfile:63` `test -f build/200.html`; mutante M-B1 (guarda trocada por `build/index.html`) fez `docker build --target frontend-build` sair com `exit 1`.

---

## Gate de build

Comandos do `tasks.md` (Gate Check Commands → Build), em série, com `DOCKER_CONFIG` temporário (`credsStore` do host):

| Etapa | Comando | Resultado |
|---|---|---|
| 1 | `docker compose build` | exit 0 (imagem `app` de `Dockerfile.dev`) |
| 2 | `docker compose run --rm --no-deps frontend sh -c "npm ci && npm run check && npm run lint && npm test -- --run && npm run build"` | exit 0: `svelte-check found 0 errors and 0 warnings`; lint limpo; **Vitest 25 arquivos, 281 testes, 0 falhas**; build gera `build/200.html` |
| 3 | `docker compose run --rm app bash -c "bin/rails test && bin/rubocop"` | exit 0: **1912 runs, 7800 assertions, 0 failures, 0 errors, 0 skips**; RuboCop 247 arquivos, 0 ofensas |
| 4 | `docker compose run --rm app bin/brakeman -q --no-pager` | exit 3 por **1 aviso**, o aceito: `EOLRails`, "Support for Rails 8.0.5.1 ends on 2026-11-07" (`Gemfile.lock:218`); 0 erros |
| 5 | `python3 spec/verify_fixture.py` | exit 0, "todas as verificações passaram" |
| 6 | `docker compose up -d app frontend && docker compose --profile e2e run --rm e2e` | exit 0: **26 passed** (`sessao.spec.ts` 5 + `casco.spec.ts` 21); `docker compose down` limpo |

Conferências do build: `frontend/build/200.html` existe e `frontend/build/index.html` não; no `<head>` de `build/200.html` o script inline de tema vem no índice 129 e o primeiro `<link rel="stylesheet">` no 1637.

Extra (o gate literal não cobre o `Dockerfile` de produção, ver SPA-05): `docker build -f Dockerfile .` exit 0; imagem final com `/rails/public/app/200.html` e `_app/immutable/`, sem `node`; servida em `RAILS_ENV=production` respondeu os cabeçalhos da tabela de SPA-02/03.

**Integridade de testes** (antes da feature → depois): Rails 1908 → 1912 (+4 de `spa_test.rb`, nenhum removido); Vitest 0 → 281; e2e 0 → 26. Nenhum teste foi pulado (`0 skips`; Playwright sem `skipped`; `forbidOnly: true` em `playwright.config.ts`). Nenhuma asserção enfraquecida: nenhum teste preexistente foi editado.

---

## Sensor de discriminação

Cópia isolada: `cp -a /home/pho/lab/bindr-tcg-svelt-front /tmp/spa-sensor` (sem `git worktree`, sem `git stash`, sem nenhum comando git dentro da cópia). `git status --porcelain` da árvore real: vazio antes e vazio depois (idêntico). Cada mutação foi aplicada num arquivo da cópia, testada e revertida; ao fim `diff -rq` confirmou a cópia idêntica à árvore real antes de ser apagada (`down -v` do projeto `spa-sensor`, `/tmp/spa-sensor` removido). Front: `node:24.21.0-slim` com `npx vitest run <arquivos>`; Rails: `docker compose -p spa-sensor ... bin/rails test test/integration/spa_test.rb`; CSS/layout: `playwright test casco` na stack da cópia (baseline 21 passed); build: `docker build --target frontend-build`.

**Front, Vitest (26 mutações):**

| # | Arquivo | Mutação | Testes | Resultado |
|---|---|---|---|---|
| M1a | `src/lib/api/client.ts:75` | `X-CSRF-Token` também em GET | `client.test.ts` | ✅ Morto (5 falhas) |
| M1b | `client.ts:75` | `X-CSRF-Token` ausente em POST | `client.test.ts` | ✅ Morto (6 falhas) |
| M2a | `client.ts:123` | reenvia sem comparar o e-mail | `client.test.ts` | ✅ Morto |
| M2b | `client.ts:123` | reenvio com `retried=false` (2º reenvio permitido) | `client.test.ts` | ✅ Morto (1 falha) |
| M3 | `client.ts:103` | `onUnauthenticated` também no `DELETE /api/session` (401) | `client.test.ts` | ✅ Morto (1 falha) |
| M3b | `client.ts:126` | `onUnauthenticated` no `DELETE` com `user` nulo (422 renovado) | `client.test.ts` | ✅ Morto (1 falha) |
| M4a | `src/lib/navigation/return-to.ts:27` | aceita `//` | `return-to.test.ts` + 2 páginas | ✅ Morto (3 falhas) |
| M4b | `return-to.ts:28` | aceita segmento `..` | idem | ✅ Morto (12 falhas) |
| M5a | `src/lib/session.svelte.ts:49` | `signOut` não zera `user` | `session.test.ts` | ✅ Morto (2 falhas) |
| M5b | `session.svelte.ts:39` | `signUp` sem o envelope `user` | `session.test.ts` | ✅ Morto (1 falha) |
| M5c | `session.svelte.ts:58` | `handleUnauthenticated` navega a partir de `/entrar` | `session.test.ts` | ✅ Morto (4 falhas) |
| M6a | `src/lib/styles/tokens.css:83` | `ink-muted` claro `#475860`→`#8a9aa2` | `tokens.test.ts` | ✅ Morto |
| M6b | `tokens.css:70` | `accent` escuro recebe o valor do claro (troca entre temas) | `tokens.test.ts` | ✅ Morto |
| **M6c** | `tokens.css:72` | `danger` escuro `#ff5448`→`#e84b3f` (4.64:1 sobre `surface-base`, **3.88:1 sobre `surface-raised`**, 5.06:1 sobre `surface-sunken`) | `tokens.test.ts` (30 testes) | ❌ **Sobreviveu → G1** |
| M6d | `tokens.css:89` | `color-scheme` do claro = `dark` | `tokens.test.ts` | ✅ Morto (1 falha) |
| M7a | `src/lib/components/Toaster.svelte:18` | remove `role="alert"` da região de erro | `Toaster.test.ts` | ✅ Morto (3 falhas) |
| M7b | `Toaster.svelte` (script) | `focus()` no botão "Fechar" ao emitir erro | `Toaster.test.ts` | ✅ Morto (1 falha) |
| **M7c** | `Toaster.svelte:30` | `.layer` de `position: fixed` para `static` (a mensagem passa a empurrar o conteúdo) | `Toaster.test.ts` + `layout.svelte.test.ts` (19 testes) | ❌ **Sobreviveu → G2** |
| M7d | `src/lib/toasts.svelte.ts:3` | sucesso some aos 6000 ms | `toasts.test.ts` + `Toaster.test.ts` | ✅ Morto (2 falhas) |
| M8 | `src/routes/+layout.svelte:30` | renderiza `children` com `status` `loading` | `layout.svelte.test.ts` | ✅ Morto (2 falhas) |
| M8b | `+layout.svelte:32` | some a tela de erro e o "Tentar novamente" | `layout.svelte.test.ts` | ✅ Morto (6 falhas) |
| M10 | `src/lib/components/MainNav.svelte:33` | remove `aria-current` | `MainNav.test.ts` | ✅ Morto (2 falhas) |
| M11 | `src/app.html:15` | script inline inverte o tema do sistema | `app-theme-script.test.ts` | ✅ Morto (5 falhas) |
| M12 | `src/routes/entrar/+page.ts:8` | remove a guarda de já autenticado | `entrar/page.test.ts` | ✅ Morto (1 falha) |
| M13 | `src/lib/view-transition.ts:5` | View Transition também com movimento reduzido | `view-transition.test.ts` | ✅ Morto (1 falha) |
| M14 | `src/lib/theme.svelte.ts:34` | ouvinte do `matchMedia` não é removido ao sair de "Sistema" | `theme.test.ts` | ✅ Morto |

**Rails, `spa_test.rb` (6 mutações):**

| # | Arquivo | Mutação | Resultado |
|---|---|---|---|
| R1 | `app/controllers/spa_controller.rb:7` | remove a linha `Cache-Control = "no-cache"` | ⚪ Equivalente: o `send_file` do Rails já devolve `Cache-Control: no-cache` (probe na cópia: `"no-cache"` sem a linha). Não é fraqueza de teste |
| R1b | `spa_controller.rb:7` | `Cache-Control` vira `public, max-age=31536000` | ✅ Morto (1 falha) |
| R2 | `config/routes.rb:168` | remove a constraint de `/app/_app/` | ✅ Morto (1 falha) |
| R3 | `spa_controller.rb:1` | herda `ApplicationController` (exige sessão) | ✅ Morto (3 falhas) |
| R4 | `spa_controller.rb:8` | `type: "text/plain"` | ✅ Morto (1 falha) |
| R5 | `spa_controller.rb:5` | arquivo ausente responde `200` | ✅ Morto (1 falha) |

**Layout/CSS, e2e Playwright (`casco`, 6 mutações) e build (1):**

| # | Arquivo | Mutação | Resultado |
|---|---|---|---|
| E1 | `AppShell.svelte:88` | breakpoint `64rem`→`80rem` | ✅ Morto (1 falha) |
| E2 | `AppShell.svelte:66` | barra inferior `fixed`→`sticky` | ✅ Morto (2 falhas) |
| E3 | `base.css:34` | corte de movimento sem `!important` | ✅ Morto (1 falha) |
| E4 | `app.html:18` | script inline sempre aplica `dark` | ✅ Morto (5 falhas) |
| E5 | `MainNav.svelte:80` | entrada atual sem peso de fonte | ✅ Morto (2 falhas) |
| E6 | `ThemeSelect.svelte:26` | seletor de tema de 44px→30px | ✅ Morto (2 falhas) |
| M-B1 | `Dockerfile:63` | guarda `test -f build/200.html` trocada por `build/index.html` | ✅ Morto: `docker build --target frontend-build` → `exit 1` |

**Profundidade**: caminho crítico (autenticação, CSRF, sessão), então manual ≥ 8; fiz 39 mutações cobrindo 9 camadas (cliente, sessão, `return_to`, tokens, tema, mensagens, layout, Rails, build).
**Resultado**: 36 mortas, 2 sobreviventes reais (M6c, M7c), 1 equivalente (R1) — ❌ **FAIL**.

### Probes contra a API real (descartados com a cópia)

Specs Playwright escritos só na cópia, contra a stack real dela: P1 (falha na carga inicial → mensagem exata de rede → "Tentar novamente" faz +1 `GET /api/session` e o casco aparece), P1b (`500` com `message` da API), P2 (sair em outra aba + "Sair" aqui), P3 (troca de conta em outra aba), P4 (camada de mensagens `fixed`, `scrollHeight` 720→720), P5 (`401 unauthenticated` no `DELETE` → saída concluída). 6/6 passaram. Esses fluxos hoje só têm teste com `fetch` falso (suficiente pelo "Independent Test" do spec), mas valem como e2e permanentes (D2).

---

## Qualidade do código

| Princípio | Status |
|---|---|
| Sem funcionalidade além do pedido | ✅ (`Button` aceita `type`/`variant` além do mínimo; o `variant="secondary"` nenhuma tela usa ainda, mas o design o prevê) |
| Sem abstração de uso único | ✅ (`view-transition.ts` e `motion.ts` são pequenos, testados e exigidos pelo design) |
| Sem "flexibilidade" extra | ✅ |
| Só arquivos necessários / sem "melhorar" código alheio | ✅ (nenhum arquivo do Hotwire, `catalog.css` nem teste existente tocado; Rails: `spa_controller.rb`, `config/{application,routes}.rb`, `development.rb` e `spa_test.rb`) |
| Casa com os padrões do código | ⚠️ `nav-entries.ts`, `nav-entries.test.ts` e `MainNav.test.ts` usam aspas duplas e 2 espaços; o resto do front usa tabs e aspas simples (cosmético, sem Prettier no repo) |
| Spec-anchored: asserção no valor do spec | ✅ em quase tudo, com as mensagens pt-BR exatas (L-064) em SPA-10, 12, 13, 15, 17, 22, 45; ❌ nos 3 casos G1–G3 |
| Cobertura por camada (domínio 1:1; rotas/e2e feliz+borda+erro) | ✅ cliente (todos os ramos), estado, componentes e Rails; e2e cobre jornada, casco, tema e movimento |
| Todo teste mapeia a um AC/edge/Done-when | ✅ (`smoke.test.ts` é o fumaça da T1) |
| Diretrizes documentadas seguidas | `CLAUDE.md` (gates, "toda task termina com teste que passa"), `design.md` Tech Decisions e L-064 (mensagem exata): seguidas |

Checagens do `design.md`:

- `fetch` só em `client.ts`: ✅ (`client.ts:79`; `index.ts:6` apenas injeta `globalThis.fetch`; ver D3).
- `data-theme` / cor literal fora de `tokens.css`, `app.html`, `theme.svelte.ts` e testes: ✅ para cor e `data-theme`; ❌ valor literal de tamanho/raio (G3).
- `transition:`/`@keyframes` só `transform`/`opacity`: ✅ por inspeção (`fly` em `Toaster.svelte:13,20`; `base.css:31-36` só zera durações); sem guarda automatizada (G4).
- `focus()` no `Toaster`: ✅ nenhum (`grep focus Toaster.svelte` vazio; M7b mutante morto prova o teste).
- `catalog.css` e arquivos do Hotwire: ✅ inalterados.
- `tmp/supervisor-decisions.md` (S-01..S-15) × spec: nenhuma contradiz o spec. S-09 (sem pausa nos 5000 ms) segue o SPA-44 literal; S-12 (`disabled` + `aria-busy`) segue o SPA-21 literal; S-07/S-08 (Kit 3 sem `base` e sem `$lib`) estão nas "Emendas da execução"; S-14 (1º quadro em dev) e S-05/S-03 (cache de `/app/200.html`, `%5F`) são débitos registrados e conferidos por mim.

---

## Lacunas ranqueadas

**G1 — Major (de teste) — SPA-33 e Success Criterion 2.** O teste de contraste não cobre `danger` como texto sobre `surface-raised` e `surface-sunken`: `tokens.test.ts:110` só mede `danger` × `surface-base`. A lista foi portada de `test/design/contrast_test.rb:202`, que tem o mesmo recorte, mas o spec exige "todo par" e o Success Criterion 2 diz "reprova se **qualquer** par de tokens de **qualquer** tema cair abaixo do Req. 12.3". Prova: mutante M6c (`--danger` escuro `#e84b3f`, 3.88:1 sobre `surface-raised`) passa nos 30 testes. Correção: em `tokens.test.ts`, acrescentar `it.each(SURFACES)('danger tem 4.5:1 sobre %s', ...)` (valores atuais: escuro 5.57 / 4.65 / 6.08; claro 5.66 / 6.07 / 5.10, todos ≥ 4.5, o teste passa sem mexer em `tokens.css`) e reexecutar M6c.

**G2 — Médio (de teste) — SPA-46.** A segunda metade do critério ("nem deslocar o conteúdo da página") não tem asserção. Mutante M7c (`.layer` de `fixed` para `static`) passa em `Toaster.test.ts` e `layout.svelte.test.ts`. A implementação está correta (probe P4: `position: fixed`, `scrollHeight` 720→720). Correção: um e2e (em `sessao.spec.ts`, no passo "sair mostra a mensagem") que leia `getComputedStyle(.layer).position === 'fixed'` e compare `boundingBox` de `main#conteudo` antes/depois de emitir a mensagem; reexecutar M7c.

**G3 — Menor (de teste e de código) — SPA-31.** `ThemeSelect.svelte:26` `min-height: 44px` repete `--touch-target: 44px` e `:29` `var(--radius-md, 0.5rem)` repete o valor de `--radius-md` num fallback; o spec proíbe "valor literal que exista como token" e nenhum teste ou grep do repo olha valor que não seja cor (o grep da T19 era só de cor e `data-theme`). Correção: trocar por `var(--touch-target)` e `var(--radius-md)`; acrescentar um teste Vitest que varra `src/**/*.svelte` e `src/**/*.css` (exceto `tokens.css`) e falhe com `\b(4|8|16|24|28|44|56|280)px\b` ou hex.

**G4 — Menor (de teste) — SPA-41.** "As transições animam apenas `transform` e `opacity`" é conferido por inspeção, sem guarda: nada impede um `transition: width` futuro. Correção: no mesmo teste-guarda de G3, falhar se `src/**/*.{svelte,css}` declarar `transition:`/`@keyframes` com propriedade fora de `transform`/`opacity` (as transições `fly` já qualificam).

---

## Débitos aceitos

- **D1 (S-03).** `GET /app/%5Fapp/...` e `/app//_app/...` escapam da constraint e devolvem o HTML da SPA com `200` em vez de `404`; `/app/200.html` sai com cache de 1 ano (S-05); `Content-Type` sem `charset` (o `app.html` declara `<meta charset>`); sem teste de traversal; CSP ausente. Baixos, já registrados.
- **D2.** O e2e não cobre SPA-10 (CSRF entre abas), SPA-15 ("Tentar novamente" real) nem SPA-09 (`401` real); só têm teste com `fetch` falso. Os 6 probes desta validação passaram e podem virar specs permanentes.
- **D3.** `api/index.ts:6` chama `globalThis.fetch(...)`, forma que `no-restricted-globals` não pega: o lint garante SPA-06 só para `fetch` solto, não para `globalThis.fetch` numa tela.
- **D4 (S-06, S-10, S-13).** `data as T` sem validar o payload de login/cadastro (um `200` sem `user` deixaria `session.user = undefined`); `void navigate` ignora rejeição do `goto`; e-mail como identidade da sessão; chave desconhecida de `fields` vira `chave: mensagem`; sem dica de formato da senha antes do erro.
- **D5.** `Button` pendente com `disabled` + `aria-busy` (S-12): o foco do botão se perde e leitores não anunciam o estado; sucesso de 5000 ms sem pausa (S-09, WCAG 2.2.1). Seguem o spec literal; decisão do dono.
- **D6 (⚠️ precisão do spec/gate).** SPA-05 diz `docker compose build`, que constrói `Dockerfile.dev`; sugiro trocar o texto do AC e o "Build" do `tasks.md` por `docker build -f Dockerfile .`. SPA-01 diz `/app`, mas em dev o Vite responde `308 → ./app/`. SPA-11/12/13 não fixam o `status` dos erros sem resposta (a implementação usa `0`).
- **D7.** `frontend/build`, `.svelte-kit`, `node_modules` e `test-results` na árvore real são artefatos ignorados pelo git, gravados pelos gates como root; `git status --porcelain` segue vazio.

---

## Requirement Traceability Update

Não atualizado: o veredito é FAIL, então `spec.md` permanece com "Implemented" e os 3 Success Criteria desmarcados. Estado proposto de cada um:

| Requisito / critério | Status proposto |
|---|---|
| SPA-01..30, 32, 34..45 | Verified (nenhuma correção a fazer neles) |
| SPA-31 | Needs Fix (G3) |
| SPA-33 | Needs Fix (G1) |
| SPA-46 | Needs Fix (G2) |
| Success Criterion 1 (Playwright, jornada a 360px e 1280px, 2 temas, sem scroll horizontal) | provado: `sessao.spec.ts:50-131`, 26 passed |
| Success Criterion 2 (contraste reprova qualquer par) | **não provado** (G1, M6c) |
| Success Criterion 3 (`docker compose up` sem passo manual, suíte Rails verde sem edição) | provado: stack sobe com `--wait`, Rails 1912/0 |

---

## Resumo

**Overall**: ❌ Not Ready (FAIL), por 2 mutantes sobreviventes de teste e 2 guardas ausentes; sem defeito de implementação.

**Spec-anchored check**: 43/46 ACs com asserção no resultado exato (⚠️ de precisão do spec/gate em SPA-01, SPA-05, SPA-11..13); 3 ❌ de teste (SPA-31, SPA-33, SPA-46); 9/9 edge cases ✅.
**Sensor**: 36/39 mutações mortas; 2 sobreviveram (M6c, M7c); 1 equivalente (R1).
**Gate**: Rails 1912 runs / 0 falhas; Vitest 281 / 0 falhas; e2e 26 passed; brakeman só com o aviso aceito.

**What works**: cliente HTTP, CSRF com comparação de usuário, `return_to`, sessão, formulários, casco, temas, movimento, mensagens e entrega em dev e em produção; comportamento confirmado também contra a API real.

**Issues found**: G1 (contraste de `danger`), G2 (SPA-46 sem teste de deslocamento), G3 (`44px` literal e sem guarda), G4 (sem guarda de propriedades animadas).

**Next steps**: fix tasks para G1–G4 (todas em testes, mais 2 linhas de CSS em `ThemeSelect.svelte`), nova rodada do sensor só sobre M6c e M7c (1 iteração de fix→re-verify); na revalidação, marcar `Verified` e os 3 Success Criteria.
