# Validação — spa-fundacao (iteração 2)

**Veredito**: PASS
**Data**: 2026-10-10
**Spec**: `.specs/features/spa-fundacao/spec.md` (SPA-01..46, 9 edge cases, 3 Success Criteria)
**Diff range**: `59d5654..HEAD` (HEAD = `7a9af01`; correções T23–T26)
**Verifier**: sub-agente independente (autor ≠ verificador)

## Validation: spa-fundacao - PASS ✅

## Histórico

- **Iteração 1** (`59d5654`): FAIL. 43/46 ACs com asserção no resultado exato do spec e 9/9 edge cases; 39 mutações, 2 sobreviventes de teste (M6c, M7c) e 2 guardas ausentes (G3, G4). Nenhuma lacuna de implementação. Gates: Rails 1912/0, Vitest 281/0, e2e 26, brakeman só com o aviso aceito.
- **Iteração 2** (este arquivo): reverifica só o que mudou, reexecuta os gates e roda o sensor sobre os 4 gaps mais uma amostra dos mortos da iteração 1.

**Superfície do diff desde a iteração 1** (`git diff --stat 59d5654..HEAD`, fora `.specs/`): `frontend/e2e/sessao.spec.ts`, `frontend/src/lib/components/ThemeSelect.svelte`, `frontend/src/lib/styles/guard.test.ts` (novo), `frontend/src/lib/styles/tokens.test.ts`. Nenhum teste existente foi removido ou enfraquecido (só acréscimos: +4 linhas em `tokens.test.ts`, +7 em `sessao.spec.ts`); nenhum arquivo do Rails ou do `Dockerfile` mudou. Por isso as citações da iteração 1 para os demais ACs seguem válidas (apenas as linhas de `tokens.test.ts` após :110 e de `sessao.spec.ts` após :71 deslocaram), e a revalidação deles é pela repetição integral dos gates e pela amostra do sensor.

---

## Conclusão das tasks

T1–T26 `[x]` em `tasks.md` (26 cabeçalhos `### T`, 0 checkboxes `[ ]`). `validate_spec.py`: 0 erros, 0 avisos. `validate_tasks.py`: 0 erros (5 avisos já existentes, não de conteúdo).

---

## Critérios revalidados (correções T23–T26)

Caminhos relativos a `frontend/`.

| AC | Resultado definido no spec | `arquivo:linha` + asserção | |
|---|---|---|---|
| SPA-33 | 4.5:1 em todo par de texto sobre superfície, nos dois temas | `src/lib/styles/tokens.test.ts:113-115` `it.each(SURFACES)('danger como texto tem 4.5:1 sobre %s', …) expect(contrast(t['--danger'], t[`--${surface}`])).toBeGreaterThanOrEqual(4.5)` (3 superfícies × 2 temas = 6 testes; total do arquivo 30 → 36); `:110` `danger` × `surface-base` já existia; mutante M6c reprova `tema dark > danger como texto tem 4.5:1 sobre surface-raised` | ✅ (G1 fechada) |
| SPA-31 | tokens num único arquivo; nenhum componente repete valor literal que exista como token | `src/lib/components/ThemeSelect.svelte:26` `min-height: var(--touch-target)` e `:29` `border-radius: var(--radius-md)` (sem literal nem fallback); `src/lib/styles/guard.test.ts:61-64` `it.each(files)('$file não repete valor px de token nem hex')` com `expect(css.match(TOKEN_PX)?.[0]).toBeUndefined()` e `expect(css.match(HEX)?.[0]).toBeUndefined()`; `TOKEN_PX` vem dos px de `tokens.css` (`:9-11`), varre `src/**/*.{svelte,css}` exceto `tokens.css` (`:15-19`); `44px` de volta em `ThemeSelect.svelte` reprova o guarda | ✅ (G3 fechada; ver D8: o guarda vê px e hex, não `rem`) |
| SPA-41 | durações/easing só como tokens; transições animam só `transform` e `opacity` | `guard.test.ts:66-69` `it.each(files)('$file anima só transform e opacity')` com `expect(offenders).toEqual([])` (`ANIMATABLE` em `:13`; `animatedProperties` cobre `transition`, `transition-property` e o corpo de `@keyframes`, `:30-50`); `tokens.test.ts:135-146` tokens de movimento; `transition: width …` num `.svelte` reprova o guarda | ✅ (G4 fechada) |
| SPA-46 | exibe a mensagem sem mover o foco nem deslocar o conteúdo | foco: `src/lib/components/Toaster.test.ts:87` `expect(document.activeElement).toBe(button)`; deslocamento: `e2e/sessao.spec.ts:81` `await expect(page.locator('.layer')).toHaveCSS('position', 'fixed')` e `:84` `expect(await main.boundingBox(), 'a mensagem não desloca o conteúdo (SPA-46)').toEqual(withMessage)` (box de `main#conteudo` com a mensagem visível × depois que some, nos 4 combos 360/1280 × claro/escuro, contra a API real); mutante M7c reprova em `sessao.spec.ts:81` (esperado `fixed`, recebido `static`) | ✅ (G2 fechada) |
| SPA-05 | `docker build -f Dockerfile .` gera a SPA num estágio Node e copia para a imagem final, sem Node nela | `spec.md:83` com o texto emendado; `.specs/STATE.md` AD-026; `Dockerfile:55` `FROM … node:24.21.0-slim AS frontend-build`, `:63` `RUN npm run build && test -f build/200.html`, `:74` `COPY --from=frontend-build /frontend/build /rails/public/app`; meu `docker build -f Dockerfile .` → exit 0; imagem final: `/rails/public/app/200.html` e `_app/immutable/` presentes, `command -v node` vazio | ✅ (D6 fechada) |

### Success Criteria

| Critério | Evidência | |
|---|---|---|
| 1. Playwright contra a API real: criar conta → sair → senha errada → entrar → sair a 360px e 1280px, nos dois temas, sem scroll horizontal | `e2e/sessao.spec.ts:54-131` (4 combos), `:20` `scrollWidth ≤ clientWidth` em toda etapa; e2e: 26 passed (`sessao.spec.ts` 5 + `casco.spec.ts` 21) | ✅ |
| 2. O teste de contraste reprova se qualquer par de tokens de qualquer tema cair abaixo do Req. 12.3 | `tokens.test.ts:94-115` cobre ink, ink-muted, accent, border-strong, on-accent e `danger` (agora também sobre `surface-raised` e `surface-sunken`) nas 3 superfícies, nos 2 temas; M6c (o par que sobrevivia) agora é morto; M6a (ink-muted claro) morto na amostra | ✅ |
| 3. `docker compose up` sobe a SPA sem passo manual, e a suíte Rails continua verde sem edição | `docker compose up -d app frontend` → `app` e `frontend` `healthy`, `curl` `:3000/api/session` 200 e `:5173/app/entrar` 200; Rails 1912 runs, 0 failures; `git diff --name-status 59d5654..HEAD` sem nenhum `test/` ou `app/` | ✅ |

### Demais ACs (SPA-01..04, 06..30, 32, 34..45) e edge cases

Sem mudança de código nem de teste que os afete desde a iteração 1 (diff acima). Seguem verdes pela reexecução integral: Vitest 26 arquivos / 312 testes, e2e 26, Rails 1912, e por 9 mutantes da iteração 1 mortos de novo (tabela abaixo). Tabela de evidência `arquivo:linha` da iteração 1: histórico git de `.specs/features/spa-fundacao/validation.md` em `59d5654`.

---

## Gate de build

`DOCKER_CONFIG` temporário (`{}` em `config.json`) por causa do `credsStore` do host; tudo em série.

| Etapa | Comando | Resultado |
|---|---|---|
| 1 | `docker compose run --rm --no-deps frontend sh -c "npm ci && npm run check && npm run lint && npm test -- --run"` | exit 0: `svelte-check found 0 errors and 0 warnings`; lint limpo; **Vitest 26 arquivos, 312 testes, 0 falhas** |
| 2 | `docker compose up -d app frontend && docker compose --profile e2e run --rm e2e` | `app` e `frontend` healthy; **26 passed** (45.9 s) |
| 3 | `docker compose exec -T app bash -c "bin/rails test; bin/rubocop"` | **1912 runs, 7800 assertions, 0 failures, 0 errors, 0 skips**; RuboCop 247 arquivos, 0 ofensas |
| 4 | `docker build -f Dockerfile .` | exit 0; imagem com `200.html` e `_app/immutable/`, sem `node` |

Ao fim: `docker compose stop frontend app` (o `db` já estava de pé antes, não é meu). Não rodei `brakeman` nem `spec/verify_fixture.py`: nenhum arquivo Ruby, Gemfile ou fixture mudou desde a iteração 1 (que registrou só o aviso aceito `EOLRails` e 19 verificações passando).

**Integridade de testes** (iteração 1 → agora): Vitest 281 → 312 (+6 de `danger`, +25 do `guard.test.ts`, nenhum removido); e2e 26 → 26 (asserções acrescentadas ao passo existente); Rails 1912 → 1912. Nenhum skip.

---

## Sensor de discriminação

Cópia isolada `/tmp/spa-sensor2` (`rsync` sem `.git`, `node_modules` recriado por `npm ci` no container; sem `git worktree`, sem `git stash`, nenhum comando git dentro da cópia). Baseline `git status --porcelain` da árvore real: vazio antes e vazio depois (idêntico). Cada mutação aplicada num arquivo da cópia (`old` deve ocorrer exatamente 1×), testada com a suíte Vitest inteira e restaurada a partir da árvore real; a cópia foi apagada ao fim. M7c rodou com o front da cópia (Vite) apontando para o `app` real, e o Playwright sobre a cópia.

| # | Arquivo | Mutação | Teste que reprovou | Resultado |
|---|---|---|---|---|
| **M6c** | `tokens.css:72` | `--danger` escuro `#ff5448`→`#e84b3f` | `tokens.test.ts` › `tema dark > danger como texto tem 4.5:1 sobre surface-raised` (1 falha) | ✅ Morto |
| **M7c** | `Toaster.svelte:30` | `.layer` `position: fixed`→`static` | `e2e/sessao.spec.ts:81` `toHaveCSS('position','fixed')` (recebido `static`) | ✅ Morto |
| **G3** | `ThemeSelect.svelte:26` | `var(--touch-target)` → `44px` | `guard.test.ts` › `ThemeSelect.svelte não repete valor px de token nem hex` | ✅ Morto |
| **G4** | `ThemeSelect.svelte:26` | acrescenta `transition: width var(--duration-fast)` | `guard.test.ts` › `ThemeSelect.svelte anima só transform e opacity` | ✅ Morto |
| G3b | `ThemeSelect.svelte:29` | `var(--radius-md)` → `var(--radius-md, 0.5rem)` (fallback em `rem`, extra meu) | nenhum | ⚠️ Sobreviveu: o guarda só conhece px e hex (D8) |
| S1 (M1a) | `client.ts:75` | `X-CSRF-Token` também em GET | `client.test.ts` (CSRF renewal) | ✅ Morto |
| S2 (M4a) | `return-to.ts:27` | aceita `//` | `return-to.test.ts` (`/app/%2f%2fevil` …) | ✅ Morto |
| S3 (M5a) | `session.svelte.ts:49` | `signOut` não zera `user` | `session.test.ts` › `signOut` (2 falhas) | ✅ Morto |
| S4 (M6a) | `tokens.css:84` | `ink-muted` claro `#475860`→`#8a9aa2` | `tokens.test.ts` › `tema light > ink e ink-muted têm 4.5:1 …` | ✅ Morto |
| S5 (M7d) | `toasts.svelte.ts:3` | sucesso some aos 6000 ms | `Toaster.test.ts` e `toasts.test.ts` (5000 ms) | ✅ Morto |
| S6 (M7a) | `Toaster.svelte:18` | remove `role="alert"` do erro | `Toaster.test.ts` (2 falhas) | ✅ Morto |
| S7 (M10) | `MainNav.svelte:33` | remove `aria-current` | `MainNav.test.ts` (2 falhas) | ✅ Morto |
| S8 (M13) | `view-transition.ts:5` | View Transition também com movimento reduzido | `view-transition.test.ts` | ✅ Morto |
| S9 (M12) | `entrar/+page.ts:8` | remove a guarda de já autenticado | `entrar/page.test.ts` › `com sessão ativa lança redirect para /app` | ✅ Morto |

**Profundidade**: caminho crítico (autenticação, CSRF, sessão), manual ≥ 5: 13 mutações do escopo pedido (4 alvo + 9 da amostra, 6 camadas: tokens/contraste, mensagens, guarda de estilo, cliente, sessão/`return_to`, navegação/transições) mais 1 extra.
**Resultado**: 13/13 mortas, cada uma pelo teste certo; 1 sobrevivente extra (G3b), de baixa gravidade e fora da lacuna original (ver D8) — ✅ **PASS**.

---

## Qualidade do código (das mudanças da iteração 2)

| Princípio | Status |
|---|---|
| Sem funcionalidade além do pedido | ✅ (só testes e 2 linhas de CSS; nenhum token novo) |
| Sem abstração de uso único | ✅ (`guard.test.ts` deriva `TOKEN_PX` de `tokens.css`, sem lista duplicada) |
| Só arquivos necessários / sem "melhorar" código alheio | ✅ (4 arquivos de `frontend/` + docs) |
| Casa com os padrões do código | ✅ (tabs, aspas simples, `it.each` como em `tokens.test.ts`) |
| Spec-anchored: asserção no valor do spec | ✅ (4.5; `fixed` + box estável; `[]` de propriedades fora de `transform`/`opacity`) |
| Todo teste mapeia a um AC | ✅ (`guard.test.ts` → SPA-31/41; `describe` cita os IDs) |
| Diretrizes seguidas | `CLAUDE.md` (gates quick/e2e/build), L-064 (mensagem exata): seguidas |

---

## Débitos aceitos

- **D1–D7**: inalterados, ver `59d5654` (D6, a emenda do SPA-05, foi fechada pela T26; `tasks.md:699`, o "Done when" histórico da T22, ainda cita `docker compose build`: texto de task já encerrada, sem efeito).
- **D8 (novo, baixo).** `guard.test.ts` compara só valores em `px` e hex: um fallback como `var(--radius-md, 0.5rem)` (mesmo valor em `rem`) passaria. Hoje nenhum token é declarado em `rem` e os `rem` literais do código (`28rem`, `24rem`, breakpoints `64rem` em media query, onde `var()` não vale) não repetem token, então não há violação. Reforço opcional: normalizar `rem`→`px` no guarda.

---

## Requirement Traceability Update

| Requisito / critério | Status anterior | Novo status |
|---|---|---|
| SPA-01..46 | Implemented | ✅ Verified (SPA-31, 33, 41, 46 pelas correções T23–T26; SPA-05 pela emenda; os demais seguem verdes) |
| Success Criteria 1, 2, 3 | desmarcados | `[x]` |

---

## Resumo

**Overall**: ✅ Ready (PASS).

**Spec-anchored check**: 46/46 ACs com asserção no resultado exato do spec (⚠️ de precisão do spec só nos já registrados em D6 para SPA-01/11/12/13); 9/9 edge cases ✅; 3/3 Success Criteria ✅.
**Sensor**: 13/13 mutações do escopo mortas pelo teste certo; 1 extra (G3b) sobreviveu, registrado como D8.
**Gate**: Vitest 312/0, e2e 26/0, Rails 1912/0, RuboCop limpo, `docker build -f Dockerfile .` exit 0.

**What works**: tudo da iteração 1 mais as quatro lacunas de teste fechadas (contraste de `danger` nas 3 superfícies, deslocamento da mensagem provado em e2e, guarda de tokens e de propriedades animadas, gate de build do SPA-05 no `Dockerfile` de produção).

**Issues found**: nenhuma bloqueante; D8 (guarda sem `rem`).

**Next steps**: feature encerrada; próxima fatia (`spa-catalogo`). Opcional: normalizar `rem` no guarda (D8) e os débitos D1–D5 da iteração 1.
