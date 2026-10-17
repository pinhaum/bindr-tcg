# Validação — spa-troca (iteração 2)

**Veredito**: PASS, com **G1 pendente de decisão do dono** (única pendência; é pré-condição externa da `spa-catalogo`, não defeito da `spa-troca`)
**Data**: 2026-10-12
**Spec**: `.specs/features/spa-troca/spec.md` (STRO-01..37, 15 edge cases, 6 Success Criteria)
**Diff range**: `880f3c0..HEAD` (HEAD = `c1ce81a`); delta desta iteração `6793c50..c1ce81a` (9 arquivos, +154/−43: só testes, `CLAUDE.md` e `tasks.md`; nenhum arquivo sob `app/`, `lib/`, `config/` ou `db/` mudou)
**Verifier**: worker independente (autor ≠ verificador; não escreveu código nem relatório desta feature; reverificação da iteração 1, preservada abaixo)
**Iteração**: 2 (de no máximo 3)

## Validation: spa-troca - PASS ✅ (G1 pendente de decisão do dono)

**Spec-anchored check**: G2, G3, G4, G5 e G6 fechados com asserção que bate com o desfecho do spec; STRO-04 e STRO-08 (proxy) deixam de ter cobertura nula; STRO-06 ganha o caso positivo. STRO-01 segue contradito pela evidência da `spa-catalogo` (G1).
**Gate**: Rails **1231 runs, 4487 assertions, 0 failures, 0 errors, 0 skips** (na 2ª rodada; ver nota do flake); Vitest **83 arquivos, 1170 passed** (= os 83 `*.test.ts` versionados); rubocop **204 arquivos, 0 offenses**; `svelte-check` **0 errors, 0 warnings**; `eslint` sem problemas. e2e e brakeman não reexecutados por mim (nada em `app/`, `config/` ou `frontend/src` fora de testes mudou desde a iteração 1).
**Sensor**: **66 mutações (25 no front, 41 no Rails), 65 mortas, 1 sobrevivente** (G4d, Info: magnitude do `max-age` do ambiente de teste; ver abaixo). Todos os sobreviventes da iteração 1 (I11c, F8–F14) morrem.
**Report**: `.specs/features/spa-troca/validation.md`

### G1 — pendente de decisão do dono (não alterado por esta iteração)

`python3 ~/.claude/skills/tlc-spec-driven/scripts/validate_state.py spa-catalogo` ainda reporta **1 erro** (`spa-catalogo: validation.md verdict is FAIL`); `.specs/features/spa-catalogo/validation.md:3` diz `**Veredito**: FAIL` (iteração 3, só o flake e2e `sessao.spec.ts`, G12 da própria `spa-catalogo`). As outras quatro fatias (`spa-carta`, `spa-pasta`, `spa-decks`, `spa-portabilidade`) saem com 0 erros. STRO-01 exige as cinco fatias com PASS, então **o AC segue sem cumprimento literal**. A decisão é do dono (recomendação do supervisor: (b), dispensa do G12 registrada no `validation.md` da `spa-catalogo` e `STATE.md:267` reconciliado). Nada na `spa-catalogo` foi tocado.

### Gaps da iteração 1: situação

| Gap | Antes | Agora | Evidência |
| --- | --- | --- | --- |
| G1 (Major) | `validate_state.py spa-catalogo` sai 1 | **aberto, decisão do dono** | `.specs/features/spa-catalogo/validation.md:3` |
| G2 (Major) | `frontend/rails-paths.test.ts` fora do `include`; F8–F14 sobreviviam | ✅ fechado | `frontend/src/rails-paths.test.ts:52` e `:56`; 18 mutações do padrão mortas |
| G3 (Minor) | I11c sobrevivia | ✅ fechado | `test/integration/api/cards_test.rb:115` e `:118` |
| G4 (Minor) | cache de `/_app/immutable/*` sem teste | ✅ fechado (nota de magnitude, Info) | `test/integration/spa_test.rb:54-65` |
| G5 (Minor) | `assert_redirected_to` frouxo; "a confirmar" no `CLAUDE.md` | ✅ fechado (resíduo Info: linhas do inventário do `design.md`) | `test/integration/collection_exports_test.rb:97-98`; `test/integration/deck_export_test.rb:78-79`; `CLAUDE.md` sem "a confirmar" |
| G6 (Info) | `/app/200.html` fora do request test | ✅ fechado | `test/integration/legacy_redirects_test.rb:14` |

---

## Task Completion (iteração 2)

| Task | Status | Notas |
| ---- | ------ | ----- |
| T26 (proxy de dev) | ✅ Done | arquivo roda no `npm test` (83 arquivos); `frontend/rails-paths.test.ts` removido |
| T27 (G3–G6) | ✅ Done | quatro testes ajustados, `CLAUDE.md` sem "a confirmar" |
| T1–T25 | ✅ Done | ver iteração 1, abaixo; código de produção sem diff desde então |

---

## Spec-Anchored Acceptance Criteria (iteração 2)

Só mudam as linhas abaixo; as demais (STRO-02, 03, 05, 07, 09..33, 35..37) valem como na tabela da iteração 1, porque `git diff 6793c50..HEAD -- app lib config db` é vazio e as asserções delas não foram editadas.

| STRO | Spec-defined outcome | `file:line` + assertion | Result |
| --- | --- | --- | --- |
| 01 | cinco fatias com PASS e `validate_state` saindo 0 | `.specs/features/spa-catalogo/validation.md:3` `**Veredito**: FAIL`; `validate_state.py spa-catalogo` → 1 erro; as outras quatro → 0 | ⏳ pendente de decisão do dono (G1) |
| 04 | Vite serve `/` e encaminha só a lista do Rails | `frontend/src/rails-paths.test.ts:52` `expect(pattern.test(path)).toBe(true)` para 22 caminhos do Rails (inclui `/progress`, `/wishlist`, `/session/new`, `/registration/new`, `/collection/import`, `/robots.txt`, `/icon.svg`, `/200.html`, `/decks`, `/decks/5/edit`); `:57` `.toBe(false)` para 17 da SPA | ✅ PASS |
| 06 | `/_app/` com cache longo; inexistente 404 | `test/integration/spa_test.rb:65` `assert_match(/max-age=\d+/, response.headers["Cache-Control"])` + `assert_no_match(/no-cache/, …)` para arquivo real em `public/_app/immutable/`; inexistente: `spa_test.rb:49` (iteração 1); G4a–G4c mortos | ✅ PASS (magnitude não afirmada: G4d, Info) |
| 08 | lista fechada de caminhos do Rails | `frontend/src/rails-paths.test.ts:72` `expect(RAILS_PATHS.some((path) => !without.test(path))).toBe(true)` por alternativa do padrão (cada uma necessária); `config/routes.rb:1-12,20-21,62-68` + `spa_test.rb:55-69` (iteração 1) | ✅ PASS |
| 09 | 14 rotas da SPA na raiz | `frontend/src/rails-paths.test.ts:57` `.toBe(false)` para `/`, `/entrar`, `/criar-conta`, `/cartas/OP01-001`, `/pasta`, `/pasta/desejos`, `/pasta/importar`, `/pasta/importar/abc`, `/baralhos`, `/baralhos/novo`, `/baralhos/importar`, `/baralhos/7`, `/baralhos/7/renomear`, `/baralhos/7/excluir` | ✅ PASS |
| 11 | `301` para o destino da checklist | `test/integration/legacy_redirects_test.rb:14` `"/app/200.html" => "/200.html"` (entra no loop de `301` + `Location` exato, e no de `HEAD`); mutação G6 morta só por este arquivo | ✅ PASS |
| 18 | deck alheio/inexistente 404; anônimo `302` | `test/integration/deck_export_test.rb:78-79` `assert_response :found` / `assert_equal "#{request.base_url}/entrar?return_to=%2Fdecks%2F#{@deck.id}.txt", response.headers["Location"]` | ✅ PASS |
| 19 | anônimo → `302 /entrar?return_to=<caminho codificado>` | `test/integration/collection_exports_test.rb:97-98` `assert_response :found` / `assert_equal "#{request.base_url}/entrar?return_to=%2Fcollection%2Fexport", response.headers["Location"]` | ✅ PASS |
| 31 | garantia migrada com equivalente que discrimina | `test/integration/api/cards_test.rb:115` `assert_equal 2, variant_json(fetch(user_id: @other.id), "tcgplayer:1")["owned_quantity"]` (logado) e `:118` `assert_nil …` (anônimo, `user_id` do outro com 7 unidades); mutação I11c morta | ✅ PASS |
| 37 | `CLAUDE.md` sem Hotwire vigente | `CLAUDE.md:44` (linha de contagens sem "a confirmar"); `grep "a confirmar" CLAUDE.md` → 0 ocorrências | ✅ PASS |

**Status**: ✅ todos os ACs cobertos exceto STRO-01 (G1), que é decisão do dono e não depende de código.

**Spec-precision gap (Info)**: STRO-06 diz "o cache de longa duração que ele aplica" sem número. O teste afirma `max-age=\d+` sob a configuração de teste (`config/environments/test.rb:19`, `max-age=3600`); com `max-age=0` ele passa (G4d). O valor de produção (`config/environments/production.rb:19`, `1.year`) não tem diff desde `880f3c0` e foi sondado na imagem na iteração 1 (`max-age=31556952`).

---

## Edge Cases (iteração 2)

- [x] `/app/200.html` → `/200.html`: agora também em request test (`legacy_redirects_test.rb:14`); era só `LP:22`
- [x] `changeOrigin` no proxy do Vite: **continua sem teste unitário** (Info). A garantia segue no e2e (o Rails responde `403 Blocked hosts: app:3000`, sonda da iteração 1); e2e não reexecutado por mim
- [x] Demais edge cases: sem mudança desde a iteração 1

---

## Discrimination Sensor (iteração 2)

**Método**: cópia de `HEAD` (sem `.git`) em `/tmp/spa-troca-mut2`, `docker compose -p troca-verify2` com portas 35433/33001/35174, banco próprio e volumes `bundle`/`frontend_node_modules` reaproveitados como `external`. Uma mutação por vez por substituição exata (o harness aborta se o trecho não ocorre o número esperado de vezes; nenhum abortou), restauração imediata. "Killed" = alguma falha na suíte completa (Rails 1231 ou Vitest 1170) com a base verde na cópia. Cópia, containers e volume `troca-verify2_pgdata` removidos ao fim (`down -v`); `git status --porcelain` da árvore original igual ao baseline (só `?? .specs/features/spa-troca/validation.md`).

### G2: padrão do proxy (`frontend/rails-paths.ts`), mortas por `frontend/src/rails-paths.test.ts`

| # | Mutação | Resultado |
|---|---------|-----------|
| F8 | padrão sem `progress` | ✅ Killed |
| F9 | sem `wishlist` | ✅ Killed |
| F10 | sem `registration` | ✅ Killed |
| F11 | sem `up` | ✅ Killed |
| F12 | sem `robots\.txt` | ✅ Killed |
| F13 | sem `icon\.svg` | ✅ Killed |
| F14 | sem a âncora final `(/\|\?\|$)` | ✅ Killed (2 falhas: `/cardsx` na SPA e o caminho "necessário") |
| F17–F27 | sem `session`, `collection_items`, `decks`, `[0-9]{3}…\.html`, `catalog`, `cards`, `app`, `api`, `card_images`, `collection`, `icon\.png` | ✅ 11/11 Killed |

### G3, G4, G5, G6

| # | Arquivo | Mutação | Resultado (teste que mata) |
|---|---------|---------|------|
| I11c | `app/controllers/api/cards_controller.rb` | posse lida de `params[:user_id]` | ✅ Killed (`Api::CardsTest#test_user_id_nos_parâmetros_não_muda_a_posse_lida`, `cards_test.rb:115`) |
| G4a | `config/environments/test.rb` | estáticos com `no-cache` | ✅ Killed (`SpaTest` do arquivo real, `spa_test.rb:65`) |
| G4b | `config/routes.rb` | fallback engole `/_app/` | ✅ Killed (`spa_test.rb:49`) |
| G4c | `app/controllers/spa_controller.rb` | entrada com `max-age=31536000` | ✅ Killed (`spa_test.rb:41`) |
| **G4d** | `config/environments/test.rb` | estáticos com `max-age=0` | ❌ **Survived** (Info: configuração de teste, regex `\d+`; ver spec-precision gap) |
| M8c | `authentication.rb` | download anônimo com `301` | ✅ Killed só pelos dois testes de download (`collection_exports_test.rb:97`, `deck_export_test.rb:78`) |
| M8d | idem | `303` | ✅ Killed (os mesmos dois) |
| M8e | idem | `return_to` sem codificação | ✅ Killed (os mesmos dois) |
| M8f | idem | sem `return_to` | ✅ Killed (os mesmos dois) |
| G6 | `lib/legacy_path.rb` | `/app/200.html` vira 404 | ✅ Killed só por `legacy_redirects_test.rb` (GET e HEAD, `:14`) |

### Amostragem do que a iteração 1 já matava (isolamento, corrida, redirecionamento aberto)

| # | Mutação | Resultado (teste que mata) |
|---|---------|------|
| M1 | `unsafe?` sem `PROTOCOL_RELATIVE` | ✅ Killed (`LegacyPathTest` `//` e `\`, `LegacyRedirectsTest` `/app//evil.com`) |
| M1b | query com controle aceita | ✅ Killed (`LegacyPathTest` caractere de controle) |
| M2 | `request.path` no lugar de `original_fullpath` | ✅ Killed (`LegacyRedirectsTest` `/app//evil.com`) |
| M3 | `301` → `302` | ✅ Killed (53 falhas) |
| M4 | controller herda `ApplicationController` | ✅ Killed (54 falhas, 1 erro) |
| M5 | rotas legadas aceitam qualquer método | ✅ Killed (`LegacyRedirectsTest` "não grava nada") |
| M6 | `/app/_app/` redireciona | ✅ Killed (4 falhas) |
| M7 | descarta a query | ✅ Killed (12 falhas) |
| S4, S5, S6 | `match "/"` do `/api` removido; fallback engole tudo; fallback aceita qualquer método | ✅ Killed (`SpaTest`) |
| I1 | `Deck.find` em update/destroy/select | ✅ Killed (`DecksWriteTest`, `DecksDestroySelectTest`) |
| I3 | `EditingDeck` sem revalidar o dono | ✅ Killed (`DeckGuaranteesTest`, `deck_guarantees_test.rb:89`) |
| I4 | token do import sem dono | ✅ Killed (6 falhas) |
| I6, I7, I10 | progresso, desejos e catálogo por `params[:user_id]` | ✅ Killed (`ProgressTest`, `WishlistTest`, `CatalogTest` "API-20") |
| I9 | `unwish` apaga de todos | ✅ Killed (`CardVariantsUnwishTest`) |
| I15, I16 | download de deck alheio; CSV por `params[:user_id]` | ✅ Killed (`DeckExportTest`, `CollectionExportsTest`) |
| S1, S2 | sessão por `params[:session_id]`; cookie não assinado | ✅ Killed (`SessionCookieTest`; 189 falhas) |
| S8 | base sem `resume_session` | ✅ Killed (13 falhas, 2 erros) |
| S9, S10 | login e logout sem `reset_session` | ✅ Killed (`RegistrationsTest`/`SessionsTest`) |
| A1, A2 | `RECLAIM_SQL` sem `status = 'pendente'`; sem `expires_at > now()` | ✅ Killed (`CollectionImportsConcurrencyTest`, `CommitTest`) |
| A5 | decremento de posse sem `quantity > 0` | ✅ Killed (`CardVariantsConcurrencyTest`) |
| A6, A7 | deck sem teto no `WHERE`; sem `FOR UPDATE` | ✅ Killed (`DeckEntriesConcurrencyTest`) |
| A8 | incremento de posse não soma | ✅ Killed (`CardVariantsConcurrencyTest`) |
| R1–R7 | `safeReturnTo`: aceita `//`, `\`, não remove `/app`, aceita `/api`/`/_app`/`/card_images`, aceita `..`, aceita controle; `isFileRoute` sempre falso | ✅ 7/7 Killed (`return-to.test.ts`, `entrar/page.test.ts`, `criar-conta/page.test.ts`) |

**Contagem**: 66 mutações; 65 mortas; 1 sobrevivente (G4d, Info, ambiente de teste).
**Sensor depth**: P0 completo (autenticação, isolamento por usuário e corrida; mais de 5 mutações por ramo).
**Result**: ✅ PASS (65/66 mortas; o sobrevivente é magnitude de configuração de teste, sem ramo de comportamento da aplicação)

Notas de execução: em M3, M6, I15 e S2 houve falhas colaterais em testes de task de ingestão (`IngestionRemapTaskTest`, `IngestionCompareSnapshotsTaskTest`, `IngestionImportTaskTest`), que sobem subprocesso e rodaram com o lote do front em paralelo; a suíte completa na cópia, depois de todas as restaurações e sem carga, ficou verde (1231 runs, 0 falhas), e cada mutação acima também foi morta por um teste da própria garantia.

---

## Code Quality (iteração 2)

| Principle | Status |
|---|---|
| Minimum code | ✅ (`rails-paths.test.ts` com duas listas e um laço por alternativa; teste de cache com `ensure` que remove o que criou) |
| Surgical changes | ✅ (9 arquivos; nada sob `app/`, `lib/`, `config/`, `db/`) |
| No scope creep | ✅ |
| Matches patterns | ✅ (`it.each` como nos testes vizinhos; `assert_response :found` + `Location` como em `legacy_redirects_test.rb`) |
| Spec-anchored outcome check | ✅ (STRO-04/08/09 com asserção viva; STRO-06 com o positivo; ⚠️ magnitude do `max-age`, Info) |
| Teste não vacuoso | ✅ (o teste "alternativa necessária" falha quando a alternativa sai: F8–F14 e F17–F27 mortos; o de cache falha com `no-cache`) |
| Documented guidelines followed | `CLAUDE.md` (gates, testes de integração Rails, Vitest em `src/**`) ✅ |

Resíduos Info, sem impacto no veredito: (1) as linhas citadas no inventário do `design.md` (ex.: `api/catalog_test:130`) seguem derivadas após a T15; o destino existe; (2) o `changeOrigin` do proxy segue sem teste unitário; (3) a tabela de rastreabilidade do `spec.md` (STRO-01..37) ainda mostra `Pending`/`-` e é do supervisor atualizar (fora do meu escopo de escrita).

---

## Gate Check (iteração 2)

- **Gate command**: Rails full (`docker compose exec -T app bin/rails test`) + Front (`docker compose run --rm --no-deps frontend sh -c "npm test -- --run"`), árvore original
- **Rails**: 1ª rodada **1231 runs, 4485 assertions, 1 failure** (`Api::SessionsTest#test_login_de_quem_já_está_logado_troca_a_sessão`, `test/integration/api/sessions_test.rb:183`, `Expected: 9925 / Actual: 9924`: `Session.order(:created_at).last` empata ou anda para trás com o relógio do host; arquivo e teste sem diff desde `api-fundacao` (`65a362d`), fora do diff desta feature); 2ª rodada **1231 runs, 4487 assertions, 0 failures, 0 errors, 0 skips**; o teste isolado, 15 execuções seguidas: 15 verdes. Mesma classe do flake do relógio do host (D-10), já registrado no `STATE.md` e na 1ª rodada do supervisor. Rails 1227 → 1231 = os 4 testes novos desta iteração
- **Front**: **83 arquivos, 1170 passed** (82/1113 na iteração 1; +1 arquivo e +57 testes do `rails-paths.test.ts`); `git ls-files 'frontend/**/*.test.ts'` = 83
- **rubocop**: 204 arquivos, 0 offenses; **svelte-check**: 0 errors, 0 warnings; **eslint**: sem problemas
- **Skipped tests**: 0 no Rails
- **Test count**: Rails 1227 → 1231; Vitest 1113 → 1170; nenhuma redução, nenhuma asserção enfraquecida (o único teste Rails editado em asserção, `assert_redirected_to` → `assert_response :found` + `Location` exato, ficou mais estrito)
- **`db/`**: sem diff desde `880f3c0`

---

## Requirement Traceability Update (iteração 2)

| Requirement | Previous Status | New Status |
|---|---|---|
| STRO-02, 03, 05, 07, 09..33, 35..37 | Verified | ✅ Verified |
| STRO-04, STRO-08 | Needs Fix (G2) | ✅ Verified |
| STRO-06 | Verified por sonda (G4) | ✅ Verified (teste do caso positivo; magnitude Info) |
| STRO-34 | Verified por leitura estática | ✅ Verified por leitura estática; e2e não reexecutado por mim |
| STRO-01 | Needs Fix (G1) | ⏳ pendente de decisão do dono |

(O `spec.md` não foi editado por esta verificação.)

---

## Summary (iteração 2)

**Overall**: ✅ Ready, com G1 pendente de decisão do dono

**Spec-anchored check**: STRO-02..37 batem com o desfecho do spec; STRO-01 contradito e pendente do dono
**Sensor**: 65/66 mutações mortas; sobrevivente: G4d (Info)
**Gate**: Rails 1231 / Vitest 1170 / rubocop 0 / svelte-check 0 / eslint 0

**What works**: o teste do proxy roda e discrimina cada alternativa do padrão, a âncora e as 14 rotas da SPA; `user_id` não desloca a posse em `GET /api/cards`; o cache de `/_app/immutable/*` e a exclusão do fallback têm teste automatizado; os downloads anônimos afirmam `302` e `Location` exatos; `/app/200.html` entra no request test; o `CLAUDE.md` não tem mais "a confirmar". Isolamento, atomicidade e redirecionamento aberto seguem mortos sob mutação.

**Issues found**: G1 (decisão do dono); Info: magnitude do `max-age` na configuração de teste (G4d), `changeOrigin` sem teste unitário, linhas do inventário do `design.md`, flake de relógio em `sessions_test.rb:183`.

**Next steps**: o dono decide o G1 (a ou b); o supervisor atualiza a tabela do `spec.md`.

---

# Histórico — iteração 1 (FAIL)

Preservado como estava em `tmp/validation-it1.md`. Só dois rótulos foram renomeados, para o `validate_state.py` não ler o FAIL antigo como o veredito atual: o título "Validation: …" virou "Resumo da iteração 1: …" e "**Result**" virou "**Resultado**". Os demais títulos desceram um nível.

## Validação — spa-troca (iteração 1)

**Veredito**: FAIL
**Data**: 2026-10-12
**Spec**: `.specs/features/spa-troca/spec.md` (STRO-01..37, 15 edge cases, 6 Success Criteria)
**Diff range**: `880f3c0..HEAD` (HEAD = `6793c50`; 29 commits, 256 arquivos: 18 A, 97 M, 141 D)
**Verifier**: worker independente (autor ≠ verificador; não escreveu código nem relatório desta feature)
**Iteração**: 1

### Resumo da iteração 1: spa-troca - FAIL ❌

**Spec-anchored check**: 35/37 STRO com asserção que bate com o desfecho do spec; 1 GAP (STRO-01, a evidência contradiz o spec) e 1 cobertura nula no lado do proxy (STRO-04/STRO-08, o teste nunca roda). STRO-06 tem só a metade negativa em teste Rails (G4).
**Gate**: Rails **1227 runs, 4473 assertions, 0 failures, 0 errors, 0 skips**; Vitest **82 arquivos, 1113 passed**; rubocop **204 arquivos, 0 offenses**; brakeman **0 erros, 1 aviso (fim de suporte do Rails 8.0.5.1, o conhecido)**; `docker build -f Dockerfile .` **exit 0**; `git diff 880f3c0..HEAD -- db/` vazio. e2e, `npm run check` e `npm run lint` **não foram rodados por mim**; as contagens do e2e (224) são do supervisor e não foram verificadas aqui.
**Sensor**: **70 mutações, 62 mortas, 8 sobreviventes**: I11c no Rails (Minor) e F8–F14 no padrão do proxy (Major: o teste não roda; mesmo forçado a rodar, F8, F9, F10, F12 e F13 sobrevivem). Detalhe na seção do sensor.
**Report**: `.specs/features/spa-troca/validation.md`

**Ranked gaps** (FAIL):

1. **G1 — Major — STRO-01 não está cumprido como escrito.** O AC exige as cinco fatias com `validation.md` PASS e `validate_state.py <feature>` saindo 0. `python3 …/validate_state.py spa-catalogo` sai **1** (`validation.md verdict is FAIL`), `.specs/features/spa-catalogo/validation.md:3` diz `**Veredito**: FAIL` (iteração 3; o FAIL é só o flake e2e `sessao.spec.ts:119`, G12 da própria `spa-catalogo`), e `:29` registra que outro agente havia escrito um "iteração 3, PASS" concorrente e que o relatório do Verifier prevaleceu. Já `.specs/STATE.md:267`, o `design.md` (pré-condições) e o `CLAUDE.md` afirmam "PASS na iteração 3; `validate_state.py spa-catalogo` sai 0". As outras quatro (`spa-carta`, `spa-pasta`, `spa-decks`, `spa-portabilidade`) saem 0. Correção: reverificar a `spa-catalogo` (e fechar o G12) ou o dono registrar a dispensa do G12 no `validation.md` dela e reconciliar o STATE; a escolha é do dono.
2. **G2 — Major — o teste do proxy de dev nunca roda.** `frontend/rails-paths.test.ts` está fora do `include` do Vitest (`frontend/vite.config.ts:25`, `include: ['src/**/*.test.ts']`); `npm test` lista 82 arquivos e nenhum é ele (`npx vitest run rails-paths.test.ts` → "No test files found"). A mitigação do `design.md` ("Vitest do padrão contra a lista do STRO-08 e contra as rotas da SPA") e o plano da T10 (`tasks.md:31`, padrão `frontend/src/**/*.test.ts`) são, na prática, vacuosos. Rodando o arquivo com uma config temporária ele passa (20 testes), **mas** não discrimina: sem `progress`, `wishlist`, `registration`, `robots.txt` ou `icon.svg` no padrão, 20/20 seguem verdes (F8, F9, F10, F12, F13); só `/up` e a âncora final matam (F11, F14). Correção: mover para `frontend/src/` (ou ampliar o `include`) e acrescentar cada caminho do STRO-08 e as 14 rotas do STRO-09.
3. **G3 — Minor — `?user_id=` em `GET /api/cards/:card_number` sem teste.** A mutação I11c (`user: params[:user_id] ? User.find_by(id:…) : Current.user`) sobrevive em `test/integration/api/cards_test.rb`; o catálogo tem o equivalente (`catalog_test`, "API-20") e a posse alheia pela sessão é provada (`cards_test.rb:95-106`, I11b morta). Lacuna herdada da `api-fundacao`, não regressão da troca.
4. **G4 — Minor — STRO-06 sem teste Rails do caso positivo.** `spa_test.rb:45-52` prova o `404` de `/_app/inexistente` e `/app/_app/x.js`; que `/_app/immutable/*` sai com cache de longa duração depende do `ActionDispatch::Static` + `Dockerfile` e só foi provado por mim na imagem de produção (sonda abaixo), sem teste automatizado.
5. **G5 — Minor — deriva de documentação e asserções frouxas.** O `CLAUDE.md` ainda diz "(a confirmar no T25 da `spa-troca`)" em três lugares (`CLAUDE.md:44`, `:154` e a linha de contagens do front), apesar de a T25 estar fechada. As linhas citadas no inventário do `design.md` (ex.: `api/catalog_test:130`) derivaram depois da T15: o destino existe, a linha não bate. Os testes de download (`collection_exports_test.rb:97`, `deck_export_test.rb:78`) usam `assert_redirected_to`, que aceita qualquer redirecionamento; a exatidão do `302` só é afirmada por `legacy_redirects_test.rb:156` (mutação M8c morta apenas por ele).
6. **G6 — Info — `/app/200.html`** (edge case do spec) tem teste de unidade (`legacy_path_test.rb:22`) mas não entra em `REDIRECTS` do request test (`legacy_redirects_test.rb:11-36`).

Desvios já conhecidos e documentados (não contados como lacuna): T10 e T18 com testes vermelhos temporários entre commits, T6 emendada, `/app/` com barra final → 404 (D1 em `tmp/orchestration-decisions.md`), flakes e2e conhecidos.

---

### Task Completion

| Task | Status | Notas |
| ---- | ------ | ----- |
| T1–T7 (garantias migradas, Phase 1) | ✅ Done | testes novos presentes: `session_cookie_test`, `collection_csv_roundtrip_test`, `commit_test`, `deck_guarantees_test`, `wishlist_fulfillment_test`, `progress_plan_test`, `authorization_surface_test` |
| T8, T9 (Rails na raiz) | ✅ Done | `lib/legacy_path.rb`, `legacy_redirects_controller.rb`, `routes.rb` |
| T10–T14 (front na raiz) | ⚠️ Partial | **T10: o teste do proxy não roda (G2)**; T11–T14 ✅ |
| T15–T17 (login pela API, downloads) | ✅ Done | |
| T18, T19 (corte) | ✅ Done | `git ls-files` sem views, helpers, assets, controllers HTML |
| T20, T21 (gems, Dockerfile) | ✅ Done | `docker build` exit 0 |
| T22–T25 (e2e, docs, fechamento) | ✅ Done | e2e não reexecutado por mim; resíduo de doc em G5 |

---

### Spec-Anchored Acceptance Criteria

Convenção: `RT` = `test/integration/legacy_redirects_test.rb`; `LP` = `test/lib/legacy_path_test.rb`; `SP` = `test/integration/spa_test.rb`; `RTO` = `frontend/src/lib/navigation/return-to.test.ts`. "Sonda" = verificação minha na imagem de produção (`docker build` + `bin/rails server` com `X-Forwarded-Proto: https`) ou no Vite da cópia.

| STRO | Spec-defined outcome | `file:line` + assertion | Result |
| --- | --- | --- | --- |
| 01 | cinco fatias com `validation.md` PASS e `validate_state` saindo 0 | `.specs/features/spa-catalogo/validation.md:3` `**Veredito**: FAIL`; `validate_state.py spa-catalogo` → exit 1; as outras quatro → exit 0 | ❌ GAP (G1) |
| 02 | SCAT-03 emendado e Verified | `.specs/features/spa-catalogo/spec.md:261` `\| SCAT-03 \| … tile leva ao detalhe da SPA (Req. 18.3, emendado) \| Tasks (T12) \| Verified \|` | ✅ PASS |
| 03 | nenhum `href`/`goto` para rota removida | `frontend/src/no-removed-routes.test.ts:35` `expect(found).toEqual([])`; mutação real (`goto('/progress')` num `.ts` novo) falha com `./lib/zz-mut.ts: /progress` | ✅ PASS |
| 04 | Vite serve `/` e encaminha só a lista do Rails | `frontend/rails-paths.test.ts:8-37` **não executa** (G2); sonda no Vite da cópia: `/`→200, `/api/session`→200, `/catalog`→301 `Location: …/`, `/pasta`→200 (SPA) | ⚠️ cobertura nula no gate; comportamento confirmado por sonda |
| 05 | `200`, `text/html`, `no-cache` | `SP:38-41` `assert_equal FIXTURE_BODY, response.body` / `assert_equal "text/html", response.media_type` / `assert_includes response.headers["Cache-Control"], "no-cache"` para `/`, `/entrar`, `/pasta/desejos`, `/qualquer/coisa?x=1`, `/200.html`; sonda na imagem: `/` e `/pasta/desejos` → 200 `cache-control: no-cache` `content-type: text/html` | ✅ PASS |
| 06 | `/_app/` com cache longo; arquivo inexistente 404 | `SP:49` `assert_response :not_found, path` (+`:50` corpo ≠ entrada); sonda: `/_app/immutable/entry/app.VfsIShKX.js` → 200 `cache-control: public, max-age=31556952`, inexistente → 404 | ⚠️ positivo só por sonda (G4) |
| 07 | `/200.html` `no-cache` | `SP:35,41` (`/200.html` na lista); sonda: `/200.html` → `no-cache`, e `/rails/public/200.html` não existe na imagem | ✅ PASS |
| 08 | lista fechada de caminhos do Rails | `config/routes.rb:1-12,20-21,62-68`; `SP:55-61` (`/api`, `/api/` → JSON 404), `SP:65-69` (POST → 404); proxy sem teste vivo (G2) | ✅ Rails / ⚠️ proxy (G2) |
| 09 | rotas da SPA na raiz | `git ls-files frontend/src/routes` traz `+page.svelte` das 14 rotas (`/`, `entrar`, `criar-conta`, `cartas/[card_number]`, `pasta`, `pasta/desejos`, `pasta/importar`, `pasta/importar/[token]`, `baralhos`, `baralhos/novo`, `baralhos/importar`, `baralhos/[id]`, `…/renomear`, `…/excluir`); `frontend/e2e/pasta.spec.ts:350` `expect(new URL(page.url()).pathname, 'o prefixo /app saiu do caminho').toBe('/entrar')`; `frontend/playwright.config.ts:11` `baseURL: 'http://frontend:5173/'` (e2e não reexecutado) | ✅ PASS |
| 10 | h1, título e link "Ir para o catálogo" | `frontend/src/routes/error-page.test.ts:19-23` `getByRole('heading', { level: 1, name: 'Página não encontrada' })` / `expect(document.title).toBe('Página não encontrada — Bindr')` / `toHaveAttribute('href', '/')`; mutantes F15, F16 mortos | ✅ PASS |
| 11 | `301`, destino da checklist, query intacta | `RT:71-76` `assert_response :moved_permanently` + `assert_equal "#{request.base_url}#{expected}", response.headers["Location"]` para 23 origens (`RT:11-36`); `RT:78-83` HEAD; `LP:4-8,10-35`; sonda: `/catalog?colors[]=Red&sort=name` → 301 `…/?colors[]=Red&sort=name` | ✅ PASS |
| 12 | `/app`, `/app/<caminho>` → `/`, `/<caminho>` com `301` | `RT:12-16` (`/app`, `/app/pasta?order=code`, `/app/cartas/P-029`, `/app/entrar?return_to=…`, `/app/pasta/importar/abc123`); `LP:19-23`; sonda: `/app/pasta?order=code` → 301 `…/pasta?order=code` | ✅ PASS |
| 13 | sem sessão e sem banco | `RT:86-95` `assert_equal 0, count_queries { get origin }` (anônimo e com sessão, 23 origens); `RT:97-106` deck alheio e id 0 → 0 consultas; `app/controllers/legacy_redirects_controller.rb:21` herda de `ActionController::Base`; mutante M4 (herda `ApplicationController`) morto | ✅ PASS |
| 14 | mesma codificação percentual | `RT:19-21,35` (`/cards/P.029`, `…variant=tcgplayer%3A123`, `/cards/a%3Ab`, `/app/%2F%2Fevil.com` → `/%2F%2Fevil.com`); `RT:115-121`; `LP:33-37`; mutante M2 (`request.path`) morto por `RT:111` | ✅ PASS |
| 15 | `404` sem gravar para não-`GET` | `RT:170-202` `assert_response :not_found` ×9 e `assert_equal before.fetch(model), model.order(:id).pluck(:id, :updated_at)` + `assert_not User.exists?(email: "novo-t18@example.com")`; mutante M5 morto por `RT:186`; sonda: `POST /collection_items/1/increment` → 404 | ✅ PASS |
| 16 | downloads fora de `/api`; `/api` só JSON | `config/routes.rb:19-21`; `test/integration/api/end_to_end_test.rb:78` `API-17: nenhuma resposta sob /api … é HTML ou redirect` (passa no gate) | ✅ PASS |
| 17 | CSV com mesmo conteúdo, tipo, `Content-Disposition`, nome | `test/integration/collection_exports_test.rb:120-131` `assert_equal "text/csv", response.media_type` / `assert_match(/\Aattachment;/, disposition)`; `collection_exports_controller.rb` sem diff desde `880f3c0`; mutantes M10, M10b, M12, M12b mortos | ✅ PASS |
| 18 | lista do deck; deck alheio/inexistente `404` | `test/integration/deck_export_test.rb:38-49` `assert_equal Deck::ListText.format(@deck.reload), response.body` + `"1xDT16-001\n3xDT16-010\n4xDT16-011\n2xDT16-030"`; `:58-65` alheio → `assert_response :not_found`; `:67-73` `/decks/0.txt` → 404; mutantes M9, M11, S7 mortos | ✅ PASS |
| 19 | anônimo → `302 /entrar?return_to=<caminho com query codificado>` | `collection_exports_test.rb:97` `assert_redirected_to "/entrar?return_to=%2Fcollection%2Fexport"`; `deck_export_test.rb:78` idem com `%2Fdecks%2F<id>.txt`; `RT:153-161` `assert_response :found` + `Location` exato com `x=%0D%0A//y` codificado e `assert_no_match(/[\r\n]/, location)`; sonda: `/decks/5.txt` → 302 `…/entrar?return_to=%2Fdecks%2F5.txt`; M8, M8b, M8c mortos | ✅ PASS |
| 20 | `return_to` seguro vai ao destino, senão `/` | `RTO:8-32` (`it.each` de aceitos e recusados `//`, `\`, controle, `.`/`..`); mutantes F1, F2, F5, F6 mortos | ✅ PASS |
| 21 | `/app` e `/app/...` perdem o prefixo | `RTO:33-36` `lê %2Fapp%2Fpasta … como /pasta`; mutante F3 morto | ✅ PASS |
| 22 | rota de arquivo → página inteira; `/api/`, `/_app/`, `/card_images/` → `/` | `frontend/src/routes/entrar/page.test.ts:83` `expect(assign).toHaveBeenCalledWith('/decks/5.txt')`, `:98` `expect(assign).not.toHaveBeenCalled()` (rota `/pasta`); `RTO:102-120` (`isFileRoute`); mutantes F4, F7 mortos (F7 também em `criar-conta/page.test.ts`) | ✅ PASS |
| 23 | deck em edição na sessão, revalidado, limpo no login e logout | `test/integration/api/deck_guarantees_test.rb:89` (id que mudou de dono não vale e a chave sai da sessão), `:101`; `session_cookie_test.rb:151` (não sobrevive a logout e login); mutantes I3, S9, S10 mortos | ✅ PASS |
| 24 | mesma sessão, sem novo login | `RT:205-215` `assert_equal @user.email, response.parsed_body.dig("data", "user", "email")` com cookie assinado montado à mão | ✅ PASS |
| 25 | sem controllers HTML, views fora de `api/`, helpers, `app/javascript`, importmap, assets | `git ls-files` sem `app/helpers`, `app/javascript`, `app/assets`, `app/views` fora de `api/`, `config/importmap.rb`, `bin/importmap`, `vendor/javascript`, `config/initializers/assets.rb`, `app/mailers`; `git ls-files app/controllers` só `api/*`, `application_controller`, `card_images_controller`, `collection_exports_controller`, `deck_exports_controller`, `legacy_redirects_controller`, `spa_controller`, concerns | ✅ PASS |
| 26 | concerns enxutos | `app/controllers/concerns/authentication.rb:50-52` (`redirect_to "/entrar?return_to=…"`); `grep` de `new_session_path`, `return_to_after_authenticating`, `helper_method`, `importmap`, `turbo`, `stimulus`, `propshaft`, `config.assets`, `hotwire` em `app config lib` → vazio (só um comentário de CSP) | ✅ PASS |
| 27 | sem `importmap-rails`, `turbo-rails`, `stimulus-rails`, `propshaft` | `Gemfile`/`Gemfile.lock` sem as quatro (nem `hotwire-spark`); `bundle list` sem elas; suíte sobe e `docker build` passa (P16 fechado) | ✅ PASS |
| 28 | API, imagens, `/up`, ingestão sem mudança | `card_images_test.rb:286-293` (só o login trocou para `/api/session`); `card_images_controller.rb` sem diff; suítes de API, imagens e ingestão verdes no gate; sonda: `/up` → 200 | ✅ PASS |
| 29 | sem migração nem dado alterado | `git diff --stat 880f3c0..HEAD -- db/` vazio | ✅ PASS |
| 30 | testes só de HTML saem | `git ls-files test/design test/helpers` vazio; `git ls-files test/integration` só `api/`, `card_images*`, `collection_exports`, `deck_export`, `legacy_redirects`, `spa` | ✅ PASS |
| 31 | garantia com equivalente e inventário | `design.md:272-376` (inventário); amostra de 25 destinos conferida (`catalog_test`, `cards_test`, `wishlist_test`, `progress_test`, `sessions_test`, `*_concurrency_test`, `collection_item_atomic_test`, `card_variants_test`, `set_progress_query_test` existem e tratam da garantia citada); mutantes de isolamento e corrida mortos (tabelas do sensor) | ✅ PASS (linhas do inventário derivaram: G5) |
| 32 | testes de domínio sem edição, salvo login e HTML | `git diff 880f3c0..HEAD` em `api/cards_test` (+5/−0 login), `catalog_test` (login; `/catalog`→`/api/catalog`), `collection_imports_confirm_test`, `decks_test`, `decks_write_test`, `decks_destroy_select_test`, `card_images_test` (login), `collection_csv_plan_test` (login e `POST /api/collection/imports`), `set_progress_plan_test` (−462, só requisição HTML e CSS), `upload_test` (−6, teste da constante do controller removido): nenhuma asserção sobre API/model/query mudou; `CLOSED_MESSAGE` idêntica à `MENSAGEM_JA_CONFIRMADA` de `880f3c0` | ✅ PASS |
| 33 | teste de cada redirecionamento e do `404` | `RT:71-76,170-202`; `LP` inteiro | ✅ PASS |
| 34 | e2e na raiz, oráculo API/banco | `frontend/e2e/catalogo.spec.ts:142-149`, `carta.spec.ts:308-318`, `pasta.spec.ts:343,363`, `pasta-desejos.spec.ts:207`; `baseURL` na raiz; `grep '/app'` em `e2e/` só em testes de redirecionamento (não reexecutei o e2e) | ✅ PASS (leitura estática) |
| 35 | gates finais | seção Gate Check abaixo | ✅ PASS, exceto e2e/check/lint não rodados por mim |
| 36 | nota de emenda nos 12 critérios superados | `.context/requirements.md:264,357,451,529,573,879,957,1023,1403,1602,1874,2098` (`*(emendado em 2026-10-12, spa-troca, Req. 23: …)*`) = 9.7, 12.2, 13.11, 13.30, 13.40, 16.17, 17.4, 17.26, 19.49, 20.46, 21.61, 22.45 | ✅ PASS |
| 37 | `CLAUDE.md` sem Hotwire vigente, rotas e comandos na raiz | `CLAUDE.md:5,36,155` ("sem Hotwire"; "Hotwire saiu do código"; "Sem pipeline de assets nem Hotwire"); `/app` só em contexto histórico (`:44,:76,:237,:251`) | ✅ PASS (resíduo "a confirmar": G5) |

**Status**: ❌ gaps presentes (G1 reprova um AC; G2 deixa STRO-04/08 sem cobertura automatizada no lado do proxy).

---

### Edge Cases

- [x] `GET /catalog?colors[]=Red&colors[]=Green&sort=name` → `/?…` byte a byte: `RT:18`
- [x] `/cards/OP01-001?variant=tcgplayer%3A123`: `RT:20`
- [x] `/cards/P.029` sem tratar `.029` como formato: `RT:19`, `LP:10-18`
- [x] `/decks/<id>` → `/baralhos/<id>`; `/decks/<id>.txt` não redireciona: `RT:32`, `deck_export_test.rb:38`; mutante S7 morto
- [x] deck alheio redireciona sem consultar: `RT:97-106`
- [x] token vencido/alheio redireciona: `RT:28` (a tela é da `spa-portabilidade`)
- [x] `/app/entrar?return_to=%2Fapp%2Fpasta` → `/entrar?return_to=…` e login a `/pasta`: `RT:15`, `RTO:33`, `pasta.spec.ts:343-350`
- [x] `/app/_app/immutable/x.js` → `404`, nunca redireciona: `RT:163-168`, `SP:46`; M6 morto
- [x] `/app/200.html` → `/200.html`: `LP:22` (G6: sem request test)
- [x] `/session/new` e `/registration/new`: `RT:22-23`
- [x] formulário Hotwire antigo → `404` sem gravar: `RT:170-202`
- [x] proxy do Vite sem `changeOrigin`: **nenhum teste unitário**; sonda no Vite da cópia: com `changeOrigin: true` o Rails responde `403 Blocked hosts: app:3000` (até em `GET /api/session`), então qualquer e2e (e o healthcheck) o mataria; sem ele, `POST /api/session` com Origin e CSRF chega a `401 invalid_credentials`
- [x] anônimo em `/decks/5.txt` → `302 /entrar?return_to=%2Fdecks%2F5.txt` e depois baixa por página inteira: `deck_export_test.rb:78`, `entrar/page.test.ts:83`
- [x] caminho novo de primeiro nível exige emenda do STRO-08: registrado no cabeçalho de `config/routes.rb:2-4`
- [x] `/` com parâmetro desconhecido ignorado: herdado do SCAT-05 (`spa-catalogo`), sem mudança aqui
- [x] `/app//evil.com` → 404, nunca `Location: //evil.com`: `RT:108-113`; M1 e M2 mortos; sonda: `/app//evil.com` → 404 sem `Location`

---

### Discrimination Sensor

**Método**: cópia em `/tmp/spa-troca-mut` (sem `.git`), `docker compose -p troca-verify` com portas 35433/33001/35174, volumes `bundle` e `frontend_node_modules` reaproveitados como `external` e `pgdata` próprio; uma mutação por vez por substituição exata (o harness aborta se o trecho ocorre 0 vezes), restauração imediata. Nada foi gravado na árvore original (`git status --porcelain` vazio antes e depois). "Killed" = pelo menos uma falha nos testes da própria feature. Cópia, containers e volume `troca-verify_pgdata` removidos ao fim (`docker compose -p troca-verify down -v`).

#### Redirecionamento aberto, roteamento, métodos (`test/lib/legacy_path_test.rb`, `legacy_redirects_test.rb`, `spa_test.rb`)

| # | Arquivo | Mutação | Resultado (teste que mata) |
|---|---------|---------|------|
| M1 | `lib/legacy_path.rb` | tira `PROTOCOL_RELATIVE` do `unsafe?` | ✅ Killed (`LP:39`, `LP:44`, `RT:108` `UnsafeRedirectError`) |
| M2 | `legacy_redirects_controller.rb` | `request.path` no lugar de `original_fullpath` | ✅ Killed (`RT:111`) |
| M3 | idem | `301` → `302` | ✅ Killed (`RT:75`, `RT:81`) |
| M4 | idem | herda `ApplicationController` (exige sessão) | ✅ Killed (`RT:78-83`) |
| M5 | `config/routes.rb` | rotas legadas aceitam qualquer método | ✅ Killed (`RT:186`) |
| M6 | idem | `/app/_app/` deixa de ser excluído do redirecionamento | ✅ Killed (`SP:49`, `RT:166`) |
| M7 | `lib/legacy_path.rb` | descarta a query | ✅ Killed (`RT:75`, `RT:81`) |
| S3 | `spa_controller.rb` | `Cache-Control` longo no lugar de `no-cache` | ✅ Killed (`SP:41`) |
| S4 | `config/routes.rb` | remove `match "/"` do escopo `/api` (cai na SPA) | ✅ Killed (`SP:55-61`) |
| S5 | idem | fallback engole `/_app/` | ✅ Killed (`SP:49`) |
| S6 | idem | fallback aceita qualquer método | ✅ Killed (`SP:65-69`) |
| S7 | idem | `decks/:id.txt` perde a precedência | ✅ Killed (`deck_export_test.rb:44,78`) |

#### Downloads e anônimo (`collection_exports_test.rb`, `deck_export_test.rb`, `legacy_redirects_test.rb`)

| # | Mutação | Resultado |
|---|---------|------|
| M8 | `request_authentication` sem `return_to` | ✅ Killed (`collection_exports_test.rb:97`, `deck_export_test.rb:78`) |
| M8b | `return_to` sem query (`request.path`) | ✅ Killed (só `RT:158`) |
| M8c | download anônimo com `301` | ✅ Killed (só `RT:156`; ver G5) |
| M9 | `DeckExportsController` com `Deck.find` | ✅ Killed (`deck_export_test.rb:64`) |
| M10 | CSV de `params[:user_id]` | ✅ Killed (`collection_exports_test.rb:207,233`) |
| M10b | CSV do primeiro usuário | ✅ Killed (`:188`) |
| M11 | lista do deck como `html` | ✅ Killed (`deck_export_test.rb:44`) |
| M12 | CSV `inline` | ✅ Killed (`collection_exports_test.rb:128`) |
| M12b | nome do arquivo com id do usuário | ✅ Killed (`:144`) |

#### Isolamento por usuário e sessão (`test/integration/api`, `test/queries`, `test/services`)

| # | Mutação | Resultado (teste que mata) |
|---|---------|------|
| I1a/b/c | `Deck.find` em `update`, `destroy`, `select` | ✅ Killed (`decks_write_test`, `decks_destroy_select_test`) |
| I1d | `DeckDetail` sem `@user.decks` (show) | ✅ Killed (`deck_detail_test`, `decks_test`) |
| I2, I14 | `Deck.find` em `DeckEntriesController` | ✅ Killed (`deck_entries_test` "deck alheio … é 404 e não grava") |
| I3 | `EditingDeck` sem revalidar o dono | ✅ Killed (`deck_guarantees_test.rb:89`) |
| I4 | `find_by_token_for` sem dono | ✅ Killed (6 falhas; `collection_import_test`) |
| I5 | progresso de outro usuário | ✅ Killed (8 falhas) |
| I6 | progresso por `params[:user_id]` ou `X-User-Id` | ✅ Killed (`progress_plan_test`, `session_cookie_test.rb:117`) |
| I7 | desejos de `params[:user_id]` | ✅ Killed (`wishlist_test`) |
| I8 | posse gravada para o primeiro usuário | ✅ Killed (`session_cookie_test.rb:96`) |
| I9 | `unwish` apaga de todos | ✅ Killed (`card_variants_unwish_test`) |
| I10 | catálogo com posse de `params[:user_id]` | ✅ Killed (`catalog_test` "API-20") |
| I11b | `GET /api/cards` com posse de outro usuário | ✅ Killed (`cards_test`) |
| **I11c** | `GET /api/cards` com posse de `params[:user_id]` | ❌ **Survived** (0 falhas em 15; **G3**) |
| I12b | import de deck no último usuário | ✅ Killed (`deck_imports_test`) |
| I13 | `GET /api/decks` de todos os usuários | ✅ Killed (`decks_test`) |
| S1 | sessão por `params[:session_id]` | ✅ Killed (`session_cookie_test.rb:62`) |
| S2 | cookie não assinado aceito | ✅ Killed (`session_cookie_test.rb:72`) |
| S8 | `Api::BaseController` sem `resume_session` | ✅ Killed (13 falhas) |
| S9 | login sem `reset_session` | ✅ Killed (`registrations_test`, `sessions_test`) |
| S10 | logout sem `reset_session` | ✅ Killed (`sessions_test`) |

(Na primeira passada, I1, I11 e I12 saíram com falso "survived": o trecho de I1 ocorria 0 vezes e, em I12, `User.order(:id).first` é equivalente porque o usuário da sessão é o primeiro. O harness passou a abortar com 0 ocorrências, e I1a–d e I12b substituíram as versões ruins.)

#### Corrida e atomicidade (`collection_csv/commit_test`, `*_concurrency_test`, `*_atomic_test`, `collection_csv_roundtrip_test`)

| # | Mutação | Resultado |
|---|---------|------|
| A1 | `RECLAIM_SQL` sem `status = 'pendente'` | ✅ Killed (`commit_test.rb:131,144`) |
| A2 | `RECLAIM_SQL` sem `expires_at > now()` | ✅ Killed (`commit_test.rb:165`) |
| A3 | upsert da coleção soma em vez de substituir | ✅ Killed (13 falhas, `collection_csv_roundtrip_test`) |
| A4 | incremento de posse como leitura+escrita em Ruby (com `sleep`) | ✅ Killed (`card_variants_concurrency_test`) |
| A5 | decremento de posse sem `quantity > 0` | ✅ Killed (`card_variants_test`, `card_variants_concurrency_test`) |
| A6 | `deck_entries` sem o teto 50 no `WHERE` | ✅ Killed (`deck_entry_atomic_test`, `deck_entries_test`) |
| A7 | decremento de deck sem `FOR UPDATE` | ✅ Killed (`deck_entries_concurrency_test.rb:201`) |
| A8 | incremento de deck não atômico (`EXCLUDED.quantity`) | ✅ Killed (7 falhas) |

#### Front (`return-to.test.ts`, `error-page.test.ts`, `no-removed-routes.test.ts`, `rails-paths.test.ts`)

| # | Mutação | Resultado |
|---|---------|------|
| F1 | `safeReturnTo` aceita `//` | ✅ Killed (6 falhas) |
| F2 | aceita barra invertida | ✅ Killed (7) |
| F3 | não remove `/app` | ✅ Killed (6) |
| F4 | aceita `/api`, `/_app`, `/card_images` | ✅ Killed (11) |
| F5 | aceita segmento `..` | ✅ Killed (13) |
| F6 | aceita caractere de controle | ✅ Killed (5) |
| F7 | `isFileRoute` sempre falso | ✅ Killed (`return-to.test.ts`, `criar-conta/page.test.ts`) |
| F15, F16 | `+error.svelte`: título fixo; link para `/pasta` | ✅ Killed |
| (varredura) | `goto('/progress')` num `.ts` real | ✅ Killed (`no-removed-routes.test.ts`) |
| changeOrigin | `changeOrigin: true` no proxy | ✅ morto por e2e (sonda: `403 Blocked hosts: app:3000`); sem teste unitário |
| **F8, F9, F10, F12, F13** | padrão do proxy sem `progress`, `wishlist`, `registration`, `robots.txt`, `icon.svg` | ❌ **Survived** (**G2**: o arquivo nem roda; rodando-o com config temporária, segue 20/20) |
| **F11, F14** | padrão sem `up`; sem a âncora `(/\|\?\|$)` | ❌ **Survived no gate** (o arquivo não roda); só morrem com o arquivo forçado a rodar |

**Contagem**: 70 mutações distintas; 62 mortas; 8 sobreviventes no gate real (I11c e F8–F14).
**Sensor depth**: P0 completo (isolamento de usuário, corrida/atomicidade e autenticação são dado insubstituível; mais de 5 mutações por ramo).
**Resultado**: ❌ FAIL — sobreviventes: I11c (G3, Minor) e F8–F14 (G2, Major).

---

### Sondas na imagem de produção (`docker build -f Dockerfile .`, `RAILS_ENV=production`, `X-Forwarded-Proto: https`)

| Pedido | Resposta |
|---|---|
| `GET /`, `/pasta/desejos`, `/200.html` | 200, `cache-control: no-cache`, `content-type: text/html` |
| `GET /_app/immutable/entry/app.VfsIShKX.js` | 200, `cache-control: public, max-age=31556952`, `text/javascript` |
| `GET /_app/immutable/nao-existe.js`, `/app/_app/immutable/x.js` | 404 |
| `GET /api` | 404 `application/json` |
| `GET /catalog?colors[]=Red&sort=name` | 301 `…/?colors[]=Red&sort=name` |
| `GET /app/pasta?order=code` | 301 `…/pasta?order=code` |
| `GET /app//evil.com` | 404 sem `Location` |
| `GET /collection/export`, `/decks/5.txt` (anônimo) | 302 `…/entrar?return_to=%2Fcollection%2Fexport`, `…%2Fdecks%2F5.txt` |
| `POST /collection_items/1/increment` | 404 |
| conteúdo da imagem | `/rails/spa/200.html` presente; `/rails/public/200.html` ausente; `public/` só com páginas de erro, ícones, `robots.txt` e `_app` |

(Container e imagem de sonda removidos ao fim.)

---

### Code Quality

| Principle | Status |
|---|---|
| Minimum code | ✅ (`LegacyPath` é tabela pura; controller de 8 linhas) |
| Surgical changes | ✅ (diff só do inventário e do corte; nenhum teste de domínio com asserção alterada) |
| No scope creep | ✅ |
| Matches patterns | ✅ |
| Spec-anchored outcome check | ⚠️ STRO-04/08 (proxy) sem teste vivo; STRO-06 positivo sem teste (G2, G4) |
| Per-layer Coverage Expectation (`tasks.md:25-34`) | ⚠️ "Funções puras e config do front: padrão do proxy contra cada caminho do STRO-08 e cada rota do STRO-09" não atendida (G2); demais camadas ✅ |
| Every test maps to a spec requirement | ✅ (`rails-paths.test.ts` mapeia, mas não executa) |
| Documented guidelines followed | `CLAUDE.md` (gates, `allow_forgery_protection` no `setup`, `use_transactional_tests = false` só nos testes de corrida) ✅; resíduo "a confirmar no T25" (G5) |

---

### Gate Check

- **Gate command**: Rails quick + Front quick (`npm test`) + brakeman + `docker build` + `git diff --stat 880f3c0..HEAD -- db/`
- **Rails** (`docker compose exec -T app bin/rails test`, árvore original): **1227 runs, 4473 assertions, 0 failures, 0 errors, 0 skips**, exit 0
- **Front** (`docker compose run --rm --no-deps frontend sh -c 'npm test -- --run'`): **82 arquivos, 1113 passed**, exit 0 (sem `rails-paths.test.ts`, G2)
- **rubocop**: 204 arquivos, 0 offenses
- **brakeman**: 0 erros, 1 aviso (fim de suporte do Rails 8.0.5.1, de calendário), 1 ignorado
- **`docker build -f Dockerfile .`**: exit 0
- **`db/`**: sem diff desde `880f3c0`
- **Não rodei**: `npm run check`, `npm run lint`, e2e (o supervisor registrou 224 verdes no fechamento; não verificado por mim)
- **Skipped tests**: 0 no Rails
- **Contagem antes da feature**: Rails 2176 verdes após a T8 (`tmp/supervisor-state.md`, antes do corte), Vitest 1113 na T15; depois: Rails 1227, Vitest 1113
- **Delta Rails**: −949 testes, explicados pelo inventário (HTML e design removidos; garantias migradas para os arquivos novos, todas com mutante morto)

---

### Fix Plans

#### Fix 1 (G1, Major): reconciliar a pré-condição da `spa-catalogo`
- **Root cause**: o PASS escrito concorrentemente foi sobrescrito pelo FAIL do Verifier (`spa-catalogo/validation.md:29`); STATE, design e CLAUDE.md ficaram com a versão otimista.
- **Fix task**: decisão do dono — (a) reverificar a `spa-catalogo` com o e2e estabilizado (`sessao.spec.ts:119`, SPA-46, L-069) e regravar o veredito, ou (b) registrar no `validation.md` dela a dispensa do G12 pelo dono e corrigir `STATE.md:267`. Depois `validate_state.py spa-catalogo` deve sair 0.
- **Priority**: Major

#### Fix 2 (G2, Major): fazer o teste do proxy rodar e discriminar
- **Fix task**: mover `frontend/rails-paths.test.ts` para `frontend/src/rails-paths.test.ts` (ajustando o import) ou acrescentar o arquivo ao `include`; incluir como "encaminha ao Rails" `/progress`, `/wishlist`, `/session/new`, `/registration/new`, `/collection/import`, `/robots.txt`, `/icon.svg`, `/200.html`, `/decks`, `/decks/5/edit`; e como "fica na SPA" as 14 rotas do STRO-09 (`/pasta/desejos`, `/pasta/importar/abc`, `/baralhos/importar`, `/baralhos/7/excluir` …). Re-rodar F8–F14: todas devem morrer.
- **Priority**: Major

#### Fix 3 (G3, Minor): teste de `user_id` em `GET /api/cards/:card_number`
- **Fix task**: em `cards_test.rb`, com `@other` com posse e sessão do `@user`, `get "/api/cards/…", params: { user_id: @other.id }` e assertar o `owned_quantity` do `@user`. I11c deve morrer.
- **Priority**: Minor

#### Fix 4 (G4, Minor): fixar o cache de `/_app/`
- **Fix task**: request test que cria `public/_app/immutable/x.js` temporário e assere `Cache-Control` com `max-age` (ou etapa do `docker build` que cheque o cabeçalho).
- **Priority**: Minor

#### Fix 5 (G5/G6, Minor/Info)
- **Fix task**: remover "(a confirmar no T25 da `spa-troca`)" do `CLAUDE.md` (3 ocorrências); trocar `assert_redirected_to` por `assert_response :found` + `Location` nos dois testes de download; acrescentar `"/app/200.html" => "/200.html"` a `REDIRECTS`.
- **Priority**: Minor/Info

---

### Requirement Traceability Update

| Requirement | Previous Status | New Status |
|---|---|---|
| STRO-02, 03, 05, 07, 09..33, 35..37 | Implementing | ✅ Verified |
| STRO-01 | Implementing | ❌ Needs Fix (G1) |
| STRO-04, STRO-08 | Implementing | ❌ Needs Fix (G2; Rails verificado, proxy sem teste vivo) |
| STRO-06 | Implementing | ⚠️ Verified por sonda; teste do caso positivo ausente (G4) |
| STRO-34 | Implementing | ✅ Verified por leitura estática; e2e não reexecutado |

(O `spec.md` não foi editado por esta verificação: a tabela acima é a proposta para o supervisor aplicar quando o veredito virar PASS.)

---

### Lessons (propostas, não gravadas)

Fora do escopo de escrita desta tarefa (`lessons.py add` grava em `.specs/lessons.json`); sugestão ao supervisor, ancorada em evidência:
1. Todo arquivo de teste novo deve aparecer na lista do runner: contar arquivos do `npm test` contra `git ls-files '*.test.ts'` (origem: `frontend/rails-paths.test.ts` fora do `include` de `frontend/vite.config.ts:25`).
2. Pré-condição "PASS" de fatias anteriores exige rodar `validate_state.py` de cada uma na hora, não citar o STATE (origem: `spa-catalogo/validation.md:3` FAIL × `STATE.md:267`).
3. Mutante cujo trecho ocorre 0 vezes é "survived" falso: o harness de mutação deve abortar (origem: I1 desta rodada).

---

### Summary

**Overall**: ❌ Not Ready (por G1 e G2; o comportamento está correto e comprovado)

**Spec-anchored check**: 35/37 STRO batem com o desfecho do spec; STRO-01 contradito; STRO-04/08 sem cobertura viva no proxy
**Sensor**: 62/70 mutações mortas; sobreviventes: I11c (Minor) e F8–F14 (Major, teste morto)
**Gate**: Rails 1227 passed / Vitest 1113 passed / rubocop 0 / brakeman 0 erros / docker build ok

**What works**: redirecionamento sem sessão e sem banco, recusa de `//`, `\` e bytes inválidos; `404` sem gravar nos outros métodos; downloads com sessão e `302` exato no anônimo; fallback e cache da entrada confirmados na imagem de produção; isolamento por usuário, atomicidade de posse/deck e confirmação única do import morrem todos sob mutação; `db/` intacto; Hotwire e as quatro gems fora do repositório.

**Issues found**: G1 (pré-condição da `spa-catalogo`), G2 (teste do proxy nunca roda e é fraco), G3–G6 menores.

**Next steps**: Fix 1 e Fix 2 (baratos, front e docs); Fix 3–5 opcionais; reverificar (iteração 2) e então `validate_state.py spa-troca`.
