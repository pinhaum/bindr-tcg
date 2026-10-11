# Detalhe da carta na SPA (`spa-carta`) — Validação

**Veredito**: PASS
**Data**: 2026-10-11
**Spec**: `.specs/features/spa-carta/spec.md` (SCAR-01..49 e Edge Cases)
**Diff range**: `7b84e6c..HEAD` (HEAD = `a546303`, 27 commits); delta desta iteração: `4be2c37..a546303` (`ccd93fe`, `66b5e5e`, `a546303`; 16 arquivos, +396/−58)
**Verifier**: sub-agente independente (autor ≠ verificador; não é o autor nem o verificador da iteração 1)
**Iteração**: 2

## Validation: spa-carta - PASS ✅

Resumo: o Major da iteração 1 (G1) está corrigido e medido no Chromium — `transition.ready` de catálogo → Criar conta depois de abrir uma carta caiu de ~520 ms para **6,5–22 ms**, e o morph tile ↔ detalhe segue funcionando nos dois sentidos (`::view-transition-group(carta-OP18-001)` presente, `ready` 36–41 ms na ida e 76–80 ms na volta). Os 4 sobreviventes do sensor (M19, M21, M22, M23) morrem, os mutantes novos também (**14/14 no Vitest, 4/4 no e2e**), o gate de build está todo verde (Vitest 756, e2e 168, Rails 1966, rubocop e brakeman limpos) e a árvore real só mudou em `validation.md` e `spec.md`. Restam só lacunas Minor/Info (seção 7).

---

## 1. G1 (Major) — correção e medição

**Código** (`frontend/src/lib/view-transition.ts`):

- `:6` `MORPH_ROUTES = new Set(['/', '/cartas/[card_number]'])`; `:14` `awaitsArrival = MORPH_ROUTES.has(navigation.to?.route.id)`; `:21` `if (awaitsArrival && hasMark()) await awaitArrival(ARRIVAL_TIMEOUT_MS)`. A espera é decidida pelo destino (`navigation.to?.route.id`), não pela marca. `/entrar`, `/criar-conta` e qualquer rota futura (e `route.id` nulo/ausente) seguem o caminho original do SPA-43 (callback resolve após `navigation.complete`). O resto do arquivo é igual ao da iteração 1 (`git diff 4be2c37..HEAD -- view-transition.ts`: 1 constante, 1 linha de decisão, 1 condição).
- `frontend/src/lib/components/CardTile.svelte:16-19,27`: `onclick` só marca com `event.button === 0` e sem `ctrl/meta/shift/alt`; clique com modificador (nova aba/janela) e botão do meio não marcam mais. Enter no link gera `click` com `button 0`, então o teclado continua marcando.

**Medição no Chromium** (dev server `:5173`, API real, viewport 1280×800, `startViewTransition` instrumentado; imagens `/card_images/*` stubadas, como o e2e faz — sem o stub o CDN responde 403/502 e as requisições seguram a fila de conexões, ver Info I1):

| Navegação | `transition.ready` | Grupos de transição | it.1 |
|---|---|---|---|
| catálogo → `/app/criar-conta` **depois de abrir uma carta** (3 rodadas) | **20, 22, 20 ms** (outra série: 6,5 ms) | só `root` | ~520 ms |
| `/app/criar-conta` → `/app/entrar` | 14,7 ms | — | — |
| catálogo → `/app/criar-conta` sem marca | 14,2 ms | — | 19 ms |
| tile → detalhe (3 rodadas) | 41, 36, 40 ms | `carta-OP18-001` + `root` | morfava |
| detalhe → catálogo, "Voltar ao catálogo" (3 rodadas) | 79, 76, 80 ms | `carta-OP18-001` + `root` | morfava |

Meta do contrato (< 200 ms) cumprida com folga de uma ordem de grandeza; o morph não regrediu. Reforço de teste: `frontend/e2e/carta-morph.spec.ts:176-201` (a 360 e 1280 px) mede `readyMs` por transição (`:51`) e exige `toBeLessThan(200)` (`:199`) para catálogo → Entrar → Criar conta depois de abrir uma carta e voltar.

---

## 2. G2–G9 — correção e prova de que o teste discrimina

Mutação em cópia (`/tmp/claude-1000/spa-carta-mutation2`, sem `git worktree`, sem `git stash`); baseline da cópia verde (Vitest 756) antes dos mutantes; cópia de `src` idêntica à árvore real depois (`diff -rq`).

| Gap | Correção | Teste novo (`arquivo:linha`) | Mutante | Resultado |
|---|---|---|---|---|
| G1 | espera por rota (acima) | `view-transition.test.ts:158-168` `it.each(['/entrar'],['/criar-conta'],[null])` com carta marcada: `done` `toBe(true)` sem avançar o relógio; `:147-156` catálogo espera 499 ms (`done false`) e libera em 500; e2e `carta-morph.spec.ts:176-201` | **M31** `if (hasMark())` (sem guarda de rota) | ✅ morto (3 falhas, `destino /entrar…`, `/criar-conta…`, `null…`) |
| G1 | idem | idem | **M31d** `awaitsArrival = true` | ✅ morto |
| G1 | idem | `:147-156` | **M31b** tira `'/'` do conjunto | ✅ morto (`espera a chegada também quando o destino é o catálogo`) |
| G1 | idem | `:106-115,125-145` | **M31c** tira `'/cartas/[card_number]'` | ✅ morto (3 falhas) |
| G2 | teste com relógio falso | `view-transition.test.ts:170-179` `vi.useFakeTimers(); markCard(null); … expect(update.done).toBe(true)` sem avançar além de 0 ms; `:180-` versão em tempo real mantida | **M23** `if (awaitsArrival)` (espera sem marca) | ✅ morto (a versão com relógio falso e a de tempo real) |
| G2 | clique com modificador | `CardTile.test.ts:49-62` `it.each([Ctrl, Meta, Shift, Alt, botão do meio])` `hasMark()` `toBe(false)`; `:64-70` clique simples `isMarked('OP01-001')` `toBe(true)` | **M32a** `if (true) markCard` | ✅ morto (Ctrl, Meta, Shift, Alt, meio) |
| G2 | idem | idem | **M32b** sem `event.button === 0` | ✅ morto (`botão do meio`) |
| G2 | idem | idem | **M32c** tira `altKey` | ✅ morto (`Alt`) |
| G2 | idem | idem | **M32d** tira `metaKey` | ✅ morto (`Meta`) |
| G3(a) | — (já correto) + teste | `page.test.ts:214-224` 404 da B esconde a A (`queryByRole('heading',{name:'Luffy'})` ausente, título `'Carta não encontrada — Bindr'`); `:226-235` erro da B idem | **M21a** `notFound !== null && !result`; **M21b** `error && !result` | ✅ mortos |
| G3(b) | `+page.svelte:111-113` o skeleton passou a vir **antes** de `notFound`/`error` no `{#if}` | `page.test.ts:237-258` retry: em 199 ms o botão "Tentar novamente" segue e "Carregando carta…" não existe; em 200 ms `aria-busy` `'true'`, texto presente e botão ausente; `:260-275` idem vindo de 404; `card-detail.svelte.test.ts:193-215,217-234` (erro/notFound permanecem até a resposta, skeleton liga em 200 ms) | **M33** skeleton só sem erro/notFound (ordem antiga) | ✅ morto (2 testes de rota + loader) |
| G4 | — (já correto) + teste | `page.test.ts:610-627` troca direta A→B (`session.user` muda sem passar por nulo), resposta `9` da fila de A: `getByText('2 cópias')` de B e `queryByText('9 cópias')` nulo | **M22** `{#key 0}` | ✅ morto (`SCAR-9: troca direta de A para B…`) |
| G5 | asserção de CSS | `CardFields.test.ts:96-98` lê a regra `.effect-text` do fonte e exige `white-space:\s*pre-line` | **M19** remove `white-space: pre-line` | ✅ morto (`preserva quebras de linha…`) |
| G6 | teste de rota | `page.test.ts:629-659` `+` pendente, `wideQuery.cross(true)`: valor otimista mantido, resposta `4` aplicada, `[thumb, expand, media, total]` `toEqual([0,0,1,1])` (largo) e `[1,1,0,2]` (estreito), `client.get`/`client.post` 1× cada | (mutante da `{#if wide.current}` não aplicado: asserção estrutural direta) | ✅ |
| G7 | e2e | `carta.spec.ts:229-257,351-355` paridade a 360 px (`registerParityTests(true)`, sem o chip "Counter" abaixo de 64rem) e `:400-409` Leader/Character/Event sem scroll horizontal nos 4 combos viewport × tema | — | ✅ (SC-1 completo) |
| G8 | `OwnershipResult` consolidado | `grep` em `frontend/src`: uma só definição, `api/types.ts:85` `{ variant_code; owned_quantity }`; `ownership-queue.svelte.ts:1`, `OwnershipStepper.svelte:5`, `VariantRow.svelte:4` importam de lá; `svelte-check 0 errors`; `VariantRow.svelte:103` agora com motivo (`-- loginHref parte de appPath`); fixture de `page.test.ts:76` agora `'character'` | "ainda duplicado": **não é mutável por teste** (tipo apagado em tempo de execução); provado por `grep` + `svelte-check` | ✅ — sobra o fixture `CardTile.test.ts:30` `'Leader'` (L1, sem efeito em asserção) |
| G9 | e2e de medidas | `carta-posse.spec.ts:120-137` `boundingBox().height >= 44` e `width >= 44` para `−` e `+`; `carta.spec.ts:503-527` `expect(withoutImage).toEqual(withImage)` (quadro da arte igual com e sem imagem); `:425` largura do "Voltar" ≥ 44 | **E2** remove `min-block-size`; **E3** remove `min-inline-size` (stepper); **E4** tira `aspect-ratio` e `position: absolute` do `.image` | ✅ mortos (`carta-posse.spec.ts:120`, `carta.spec.ts:513`) |

Mutantes de e2e rodados no Chromium do host (headless shell 1243) contra um Vite da cópia na porta 5199 (proxy para o `app` real); **E1** = M31 contra `carta-morph.spec.ts -g G1`: ✅ morto (as duas variantes, 360 e 1280 px, falham). Baseline da cópia: as mesmas execuções passam sem mutante.

---

## 3. Spec-anchored: ACs tocados pelas correções (re-ancorados)

Os 49 ACs e os edge cases da iteração 1 seguem de pé (apêndice, ancorados em `4be2c37`; os números de linha dos arquivos que a iteração 2 tocou — `page.test.ts`, `CardTile.test.ts`, `view-transition.test.ts`, `card-detail.svelte.test.ts`, `CardFields.test.ts`, `carta*.spec.ts` — deslocaram e valem pela citação desta tabela). Todas as asserções existentes passam sem edição de expectativa (756 verdes, 0 removidos: `git diff 4be2c37..HEAD` só tem `+` nos testes, salvo o fixture `card_type` e o `to.route.id` adicionado ao helper `between`).

| AC | Resultado definido no spec | `arquivo:linha` + asserção | Result |
|---|---|---|---|
| SCAR-03 | tile → `/app/cartas/<n>` sem recarregar; clique comum | `CardTile.test.ts:64-70` clique simples `isMarked('OP01-001')` `toBe(true)`; `:49-62` modificadores não marcam; `:73` o `href` segue `/app/cartas/<n>` (inalterado); e2e sem recarga `carta.spec.ts:262` (a 360 e 1280 px) | ✅ |
| SCAR-04 | botão bordado ≥ 44 px, sem seta | `carta.spec.ts:411-426` `found!.height >= 44`, `found!.width >= 44`, `borderTopStyle` `'solid'` (4 combos) | ✅ (divisor: ver L2) |
| SCAR-05 | `message` da API + "Voltar ao catálogo", título "Carta não encontrada — Bindr" | `page.test.ts:214-224` `findByRole('heading',{level:1,name:'Carta não encontrada.'})`, Luffy ausente, `document.title` `'Carta não encontrada — Bindr'` | ✅ |
| SCAR-06 | `message` do erro + "Tentar novamente" | `page.test.ts:226-235` botão `Tentar novamente` presente, Luffy ausente | ✅ |
| SCAR-07 | > 200 ms: `aria-busy="true"` e "Carregando carta…"; antes, conteúdo anterior | `page.test.ts:237-258` `advanceTimersByTimeAsync(199)` botão presente e texto ausente; `(1)` `aria-busy` `'true'` e `getByText('Carregando carta…')`; `:260-275` idem vindo de 404; `card-detail.svelte.test.ts:193-234` `skeleton` `false` em 199, `true` em 200, `error`/`notFound` mantidos até a resposta | ✅ (lacuna G3(b) fechada) |
| SCAR-09 | troca de sessão repete o `GET` e descarta a fila da sessão anterior | `page.test.ts:610-627` `client.get` `toHaveBeenCalledTimes(2)`, `getByText('2 cópias')` e `queryByText('9 cópias')` nulo | ✅ |
| SCAR-10 | quadro da arte não muda de tamanho sem imagem | `carta.spec.ts:513-527` `expect(withoutImage, 'quadro sem imagem').toEqual(withImage)` (com 403 do CDN, 0 `<img>`, `.placeholder` presente) | ✅ (lacuna de precisão fechada) |
| SCAR-12 | ≥ 64rem: coluna própria; < 64rem: miniatura + `<details>` | `page.test.ts:629-659` `[thumb,expand,media,total]` `toEqual([1,1,0,2])` estreito e `[0,0,1,1]` largo, nos dois sentidos de travessia | ✅ |
| SCAR-13/17/19/21/24 | paridade com `/cards` a 360 e 1280 px | `carta.spec.ts:229-257` + `:351-355`: `expect(spa.chips).toEqual(hotwireChips)`, `spa.variants`, `spa.fields`, `featured`, para leader/character/event × 3 casos de `?variant=` a 360 px | ✅ |
| SCAR-18 | efeito em texto puro com quebras (`pre-line`) | `CardFields.test.ts:92-99` `textContent` `'a\nb'` e regra `.effect-text` com `white-space: pre-line` | ✅ (M19 morto) |
| SCAR-25 | `−`/`+` ≥ 44 px | `carta-posse.spec.ts:120-137` `box.height >= 44`, `box.width >= 44` no navegador (`OwnershipStepper.test.ts:66-73` segue como prova de fonte) | ✅ (lacuna de raso fechada) |
| SCAR-39 | ida: arte do tile vira a imagem principal | `carta-morph.spec.ts` `groupNames toContain(morphName(number))` (360 e 1280 px; testes existentes, sem edição de expectativa); medição manual: `::view-transition-group(carta-OP18-001)`, `ready` 36–41 ms | ✅ |
| SCAR-40 | volta: arte vira a do tile | idem, "Voltar ao catálogo", `goBack` e link direto; medição manual `ready` 76–80 ms | ✅ |
| SCAR-41 | sem suporte/`reduced-motion`: sem erro | `view-transition.test.ts:18-37` (sem edição) e `carta-morph.spec.ts` `transitions(page)` `toEqual([])` | ✅ |
| SPA-43 (fundação) | transição entre as demais rotas sem regressão | `view-transition.test.ts:158-168` (`/entrar`, `/criar-conta`, `null`) + `:49` `chama startViewTransition entre rotas diferentes` com `route.id` nulo (`between`, `:35`) + medição manual 6,5–22 ms | ✅ |

**Status**: ✅ 49/49 ACs com resultado exato provado (it.1 + re-ancoragem acima); lacunas de precisão do spec remanescentes são só as já listadas na it.1 (título "Carta — Bindr" de loading, divisor do SCAR-04), ambas sem defeito.

### Success Criteria

- **SC-1** (paridade com `/cards`, Leader/Character 3 variantes/Event, 360 e 1280 px, dois temas, sem scroll horizontal) — ✅ `carta.spec.ts:229-257,351-355,400-409` (G7 fechada) mais o layout dos 4 combos; 168 e2e verdes contra a API real.
- **SC-2** (+5 em série e número final = `GET`; rede cortada no 3º volta ao confirmado com "Sem conexão com o servidor. Tente novamente.") — ✅ `carta-posse.spec.ts:139-189` (cinco `+`) e `:191-213` (rede cortada no 3º), verdes no gate.
- **SC-3** (desejo marcado na SPA aparece em `/wishlist` Hotwire com o mesmo alvo) — ✅ prova viva desta iteração: conta nova, `PUT /api/cards/OP18-001/variants/tcgplayer%3A718692/wishlist` `{"target_quantity":3}` → `200 {"data":{"variant_code":"tcgplayer:718692","wishlist_target":3}}`, e `GET /wishlist` (HTML) lista "Karoo tcgplayer:718692 0 de 3 cópia(s) Faltam 3"; Rails: `test/integration/api/card_variants_wishlist_test.rb:64-99` afirma o `WishlistItem` gravado; `carta-posse.spec.ts:215` persiste após recarregar. (Sem teste automatizado da página `/wishlist`: L3.)
- **SC-4** (suíte Rails sem edição + request tests novos + corrida soma) — ✅ `git diff --name-status 213f0bc..HEAD -- test/` só `A` (4 arquivos); 1966 runs, 0 falhas; `test/integration/api/card_variants_concurrency_test.rb:139-196`.

---

## 4. Gate de build (de `tasks.md`), em série, pilha de pé

| Passo | Resultado |
|---|---|
| Front quick: `docker compose stop frontend`; `docker compose run --rm --no-deps frontend sh -c "npm ci && npx svelte-kit sync && npm run check && npm run lint && npm test -- --run && npm run build"` | ✅ exit 0: `svelte-check found 0 errors and 0 warnings`; lint sem saída; **Vitest 756 passed (51 arquivos)**; build `✔ done` |
| `docker compose up -d app frontend` e e2e `docker compose --profile e2e run --rm e2e` | ✅ **168 passed (4,3 m)**, 0 falhas, 0 flaky (`sessao.spec.ts:84` passou nas 4 combinações; `carta-morph` "voltar do navegador 1280px" passou; sem necessidade de reexecução isolada) |
| `docker compose exec app bin/rails test` | ✅ **1966 runs, 8040 assertions, 0 failures, 0 errors, 0 skips** |
| `bin/rubocop` | ✅ 255 arquivos, nenhuma ofensa |
| `bin/brakeman` | ✅ 0 erros; único aviso `Support for Rails 8.0.5.1 ends on 2026-11-07` (calendário) |
| `docker build -f Dockerfile .` | ✅ exit 0 (a 1ª tentativa falhou por `docker-credential-desktop.exe` ausente; com `DOCKER_CONFIG` temporário `{}` passou) |
| `git diff --name-status 213f0bc..HEAD -- test/` | ✅ só `A` (4 arquivos novos) |

- **Contagens**: Vitest 548 (7b84e6c) → 737 (it.1) → **756** (+19 nesta iteração, todos novos); e2e 58 → 143 → **168** (+25); Rails 1912 → **1966** (sem mudança desde a it.1). Nenhum teste removido; asserções só acrescentadas.
- **Pulados**: 0. Depois do gate a pilha ficou de pé (`app`, `db`, `frontend` healthy).
- **Efeito colateral no banco de dev**: o e2e cria contas `e2e-<timestamp>@exemplo.test` (conhecido) e a prova do SC-3 criou duas contas `verifier-<timestamp>@exemplo.test`, uma com 1 item na lista de desejos.

---

## 5. Discrimination Sensor (iteração 2)

**Profundidade**: lightweight ampliado. Vitest: 14 mutantes na cópia, suíte inteira por mutante (756 testes). e2e: 4 mutantes no Chromium do host contra o Vite da cópia. Isolamento: `git status --porcelain` da árvore real **idêntico** antes e depois (comparado com `diff`); `src` da cópia idêntico ao real depois de cada rodada; sem `git worktree`, sem `git stash`, sem escrita fora de `/tmp/claude-1000`.

| # | Arquivo | Mutação | Morto por | Killed? |
|---|---|---|---|---|
| M19 | `CardFields.svelte` | remove `white-space: pre-line` (sobrevivente it.1) | `CardFields.test.ts:92` | ✅ Morto |
| M21a | `+page.svelte` | `notFound` só vale sem `result` antigo (sobrevivente it.1) | `page.test.ts:214` (SCAR-5 404 da B) | ✅ Morto |
| M21b | `+page.svelte` | `error` só vale sem `result` antigo | `page.test.ts:226` (SCAR-6) | ✅ Morto |
| M22 | `+page.svelte` | `{#key 0}` (sobrevivente it.1) | `page.test.ts:610` (SCAR-9 troca direta) | ✅ Morto |
| M23 | `view-transition.ts` | espera a chegada sem carta marcada (sobrevivente it.1) | `view-transition.test.ts:170,180` | ✅ Morto |
| M31 | `view-transition.ts` | remove a guarda do `route.id` (espera por qualquer destino com marca) | `view-transition.test.ts:158-168` (3 falhas) | ✅ Morto |
| M31b | idem | tira `'/'` do conjunto de rotas | `view-transition.test.ts:147` | ✅ Morto |
| M31c | idem | tira `'/cartas/[card_number]'` | `view-transition.test.ts:106,125,136` | ✅ Morto |
| M31d | idem | `awaitsArrival = true` | `view-transition.test.ts:158-168` | ✅ Morto |
| M32a | `CardTile.svelte` | `markCard` sempre (clique modificado marca) | `CardTile.test.ts:49-62` (Ctrl/Meta/Shift/Alt/meio) | ✅ Morto |
| M32b | idem | sem `event.button === 0` | `CardTile.test.ts` `botão do meio` | ✅ Morto |
| M32c | idem | sem `altKey` | `CardTile.test.ts` `Alt` | ✅ Morto |
| M32d | idem | sem `metaKey` | `CardTile.test.ts` `Meta` | ✅ Morto |
| M33 | `+page.svelte` | skeleton escondido por erro/notFound (ordem antiga) | `page.test.ts:237,260` | ✅ Morto |
| E1 | `view-transition.ts` | = M31, no navegador | `carta-morph.spec.ts:176` (360 e 1280 px) | ✅ Morto |
| E2 | `OwnershipStepper.svelte` | remove `min-block-size: var(--touch-target)` | `carta-posse.spec.ts:120` | ✅ Morto |
| E3 | idem | remove `min-inline-size: var(--touch-target)` | `carta-posse.spec.ts:120` | ✅ Morto |
| E4 | `CardArt.svelte` | quadro depende da imagem (sem `aspect-ratio`, `.image` estático) | `carta.spec.ts:513` | ✅ Morto (por `toBeVisible` do quadro colapsado, antes da comparação de caixa) |
| — | `OwnershipResult` duplicado | tipo apagado em execução: **não mutável por teste** | provado por `grep` (uma definição, `api/types.ts:85`) e `svelte-check` 0 erros | n/a (justificado) |

**Resultado**: **14/14 mortos no Vitest, 4/4 no e2e**; os 4 sobreviventes da it.1 (M19, M21, M22, M23) mortos; nenhum sobrevivente. Os 34 mortos da it.1 (M01–M30, R01–R07) seguem cobertos pelos mesmos testes (sem edição de expectativa; 756/756 verdes). **PASS ✅**

---

## 6. Qualidade e decisões

| Princípio | Status |
|---|---|
| Correção mínima (G1 em 3 linhas de produção; G2 em 4 linhas; G3(b) só reordena o `{#if}`) | ✅ |
| Matches patterns / só arquivos necessários | ✅ (`git diff --stat`: 6 de produção, 10 de teste/e2e) |
| Nenhum teste removido ou enfraquecido | ✅ |
| `fetch` só em `client.ts`; sem hex/px fora de `tokens.css`; sem `{@html}`; sem `eslint-disable` sem motivo novo | ✅ (lint verde) |
| Spec-anchored: asserção = resultado exato do spec | ✅ |
| Sem regressão por causa das correções | ✅ (ver abaixo) |
| Diretrizes seguidas | `CLAUDE.md` (gates, Kit 3), `guard.test.ts` |

**Decisões do supervisor, à luz das correções**

- **D2** (stepper cria a fila) — aceita; o papel do `{#key}` agora tem teste (M22 morto, `page.test.ts:610`).
- **D3** (`OwnershipResult` duplicado) — **fechada**: uma definição em `api/types.ts:85`.
- **D4, D5** — aceitas, sem mudança.
- **D6** — (a)–(e) seguem aceitos como débitos; o "médio" do ts-reviewer (`result` não limpo em 404/erro) agora tem teste (M21a/b).
- **D7** — corrigida e agora completa para o fixture de rota (`page.test.ts:76` `'character'`); sobra `CardTile.test.ts:30` (L1).
- **D8** — mecanismo aceito **e a implementação agora também**: a espera por chegada só vale para catálogo/detalhe; teto de 500 ms preservado; sem congelar as demais rotas (medido).
- **D9** (achados do code review): o "médio" (morph congela navegações não relacionadas; clique com modificador marca sem navegar) está corrigido e provado (M31/M32). Baixos #2, #3, #4 seguem como registrados.

**Regressão por causa das correções?** Verifiquei os três pontos tocados: (1) `route.id` correto com `paths.base = '/app'` — `'/'` e `'/cartas/[card_number]'` casam (prova viva: o morph ocorre na ida e na volta); (2) a nova ordem do `{#if}` só afeta erro/notFound × skeleton — o skeleton já vinha antes do `result`; o título do `<head>` continua derivado de `notFound`/`error` (ver I2); (3) o `onclick` do tile não tira o `href`, o teclado continua marcando. Nada novo ficou sem prova.

---

## 7. Lacunas restantes (ranqueadas)

Sem Blocker, sem Major.

| ID | Severidade | Lacuna | Evidência |
|---|---|---|---|
| L1 | Minor | Fixture `card_type: 'Leader'` capitalizado em `CardTile.test.ts:30` (o tile não usa `card_type`; nenhuma asserção depende) — resto do G8. | `frontend/src/lib/components/CardTile.test.ts:30` |
| L2 | Minor (precisão do spec) | O divisor acima do "Voltar" (SCAR-04) é do `AppShell` (`AppShell.svelte:125` `border-block-start: 1px solid var(--border)`) e nenhum teste o afirma; o spec não dá número observável. | `frontend/src/lib/components/AppShell.svelte:125` |
| L3 | Minor | SC-3 só tem prova viva desta verificação e o teste Rails do `WishlistItem`; não existe teste automatizado que abra a página Hotwire `/wishlist` depois do `PUT` da SPA. | `test/integration/api/card_variants_wishlist_test.rb:64-99` |
| I1 | Info | Em dev, com o CDN respondendo 403 (502 no `/card_images/*`) e **sem** stub, tile ↔ detalhe bate o teto de 500 ms sem morph (`ready` 514–524 ms, só `root`; a busca do detalhe disputa a fila de conexões com dezenas de imagens 502 — hipótese não isolada). É o teto por desenho da D8; com imagens servidas (e2e/prod) `ready` fica em 36–80 ms. Documentado em `CLAUDE.md` (imagens 502 em dev). Sem AC. | medição manual |
| I2 | Info | Durante um skeleton vindo de `notFound`, o `<title>` fica "Carta não encontrada — Bindr" até a resposta (`+page.svelte:42-48` não olha o skeleton). Cosmético, sem AC; o SCAR-05 só define o título para o 404 exibido. | `frontend/src/routes/cartas/[card_number]/+page.svelte:42-48` |
| I3 | Info | `tasks.md` mantém `**Status**: Draft` (o Verifier não escreve em `tasks.md`; o orquestrador atualiza); `frontend/e2e/carta.spec.ts:227-228` tem uma linha em branco dupla. | — |

Débitos aceitos desde a it.1 inalterados (SPA-21 foco no botão pendente, `announce` com `tick`, sem teto em `increment_for!`, `"007"` como 7; `CardImagesController` por `variant_code`; `WishlistItemsController` HTML com a corrida de criação; flake e2e `sessao.spec.ts:84`, que não ocorreu).

---

## 8. Requirement Traceability Update

`spec.md`: SCAR-01..49 de `Implemented` → `Verified`; checkboxes de Goals e Success Criteria marcados (SC-1..4 provados acima).

| Requirement | Previous Status | New Status |
|---|---|---|
| SCAR-01..49 | Implemented | ✅ Verified |

## Summary

**Overall**: ✅ Ready.

**Spec-anchored check**: 49/49 ACs com resultado exato provado; 2 lacunas de precisão do spec sem defeito (título de loading; divisor do SCAR-04).
**Sensor**: 14/14 mortos (Vitest) + 4/4 (e2e); 4/4 sobreviventes da it.1 mortos; 0 sobreviventes.
**Gate**: Vitest 756, e2e 168, Rails 1966 (0 falhas), rubocop e brakeman limpos (só o aviso de calendário), `npm run build` e `docker build` OK; `git diff 213f0bc..HEAD -- test/` só `A`.
**G1**: `transition.ready` catálogo → Criar conta depois de abrir carta: ~520 ms → 20 ms; morph ida/volta íntegro.

**What works**: tudo da it.1 mais a espera do morph restrita a catálogo/detalhe, clique com modificador no tile sem marcar, skeleton sobre erro/notFound, tipo único de `OwnershipResult`, provas de layout/medidas no navegador.

**Issues found**: só Minor/Info (L1–L3, I1–I3).

**Next steps**: orquestrador atualiza `tasks.md` (`Status: Verified`) e o `CLAUDE.md`/`STATE.md`; L1–L3 podem ir como débito.

---

## Iteração 1 (histórico)

**Veredito**: FAIL (2026-10-11, `7b84e6c..4be2c37`, Vitest 737, e2e 143, Rails 1966). 49/49 ACs provados, mas **1 Major (G1)**: `markCard` nunca é limpo, então depois de qualquer carta aberta toda navegação para rota que não sinaliza chegada (catálogo → Entrar/Criar conta) segurava a View Transition por 500 ms (`ready` 519,8 ms contra 18,8 ms sem marca). Sensor: 34/38 mortos; sobreviventes M19 (`pre-line`), M21 (precedência `notFound`), M22 (`{#key}`) e M23 (esperar chegada sem marca — o teste usava `vi.waitFor` de 1000 ms contra o teto de 500 ms). Lacunas: G1 (Major), G2 (teste de M23; clique modificado marca sem navegar), G3 (precedência notFound/erro × `result` e skeleton escondido por erro), G4 (`{#key}` na troca de sessão), G5 (`pre-line`), G6 (cruzar 64rem com operação pendente), G7 (paridade/layout só a 1280 px para Leader/Event), G8 (`OwnershipResult` duplicado, fixtures capitalizados, `eslint-disable` sem motivo), G9 (44 px lido do fonte, divisor e quadro da arte sem teste). Todas tratadas nos commits `ccd93fe`, `66b5e5e`, `a546303` (seções 1–2).

### Apêndice — ACs e edge cases da iteração 1 (ancorados em `4be2c37`)

Inalterados e válidos; as linhas dos arquivos tocados pela it.2 foram re-ancoradas na seção 3.

## 2. ACs ancorados (spec-anchored)

Siglas: **RT** = `frontend/src/routes/cartas/[card_number]/page.test.ts`; **CH** = `frontend/src/lib/components/CardHeader.test.ts`; **CF** = `…/CardFields.test.ts`; **CA** = `…/CardArt.test.ts`; **VR** = `…/VariantRow.test.ts`; **OS** = `…/OwnershipStepper.test.ts`; **WF** = `…/WishlistForm.test.ts`; **Q** = `frontend/src/lib/cards/ownership-queue.svelte.test.ts`; **CD** = `…/cards/card-detail.svelte.test.ts`; **E-C** = `frontend/e2e/carta.spec.ts`; **E-P** = `…/carta-posse.spec.ts`; **E-M** = `…/carta-morph.spec.ts`; **R-V** = `test/integration/api/card_variants_test.rb`; **R-W** = `…/card_variants_wishlist_test.rb`; **R-C** = `…/card_variants_concurrency_test.rb`.

### P1 — Detalhe em `/app/cartas`

| AC | Resultado definido no spec | `arquivo:linha` + asserção | Result |
|---|---|---|---|
| SCAR-01 | título "<nome> (<card_number>) — Bindr"; h1 com o nome | RT:139-144 `expect(document.title).toBe('Luffy (OP01-001) — Bindr')` + `findByRole('heading',{level:1,name:'Luffy'})`; E-C:220-258 `toHaveTitle(\`${name} (${n}) — Bindr\`)` | ✅ |
| SCAR-02 | `GET /api/cards/:n` com `card_number` codificado e `variant` repassado sem alteração | RT:146-157 `toHaveBeenCalledWith('/api/cards/OP01-001?variant=tcgplayer%3A2')` (+ sem variant e `?variant=` vazio); RT:159-164 `'/api/cards/P%20029%2Fx'`; CD:33-41 `'/api/cards/P-029?variant=tcgplayer%3A1'`; `frontend/src/lib/cards/url.test.ts:25-35` | ✅ (M17 morto) |
| SCAR-03 | tile → `/app/cartas/<n>` sem recarregar | `frontend/src/lib/components/CardTile.test.ts:50-56` `href` `'/app/cartas/OP01-001'` e `not.toHaveAttribute('rel','external')`; E-C:220-258 `readDocumentMark … toBe('mesmo-documento')` a 360 e 1280 px | ✅ (M18 morto) |
| SCAR-04 | botão bordado ≥44 px, sem seta, → `/app` sem recarga; na coluna a partir de 64rem | E-C:384-399 `height ≥ 44` e `borderTopStyle === 'solid'` (4 combinações viewport×tema); RT:340-390 `toHaveAttribute('href','/app')`, `toHaveTextContent(/^Voltar ao catálogo$/)`, `shell.aside` ≠ nulo na coluna; E-C:220-258 clique sem recarga | ✅ (⚠️ o divisor acima do botão é do `AppShell` — `frontend/src/lib/components/AppShell.svelte:125 border-block-start` — e nenhum teste o afirma: lacuna de precisão, G9) |
| SCAR-05 | `message` da API + "Voltar ao catálogo", título "Carta não encontrada — Bindr" | RT:166-174 `findByText('Carta não encontrada.')`, `document.title` `'Carta não encontrada — Bindr'`; E-C:401-421 `getByRole('heading',{name:error.message})` + `toHaveTitle('Carta não encontrada — Bindr')` contra a API real | ✅ |
| SCAR-06 | `message` do erro + "Tentar novamente" repete a consulta | RT:176-187 `toHaveBeenCalledTimes(2)`, `toHaveBeenLastCalledWith('/api/cards/OP01-001')` | ✅ |
| SCAR-07 | >200 ms: `aria-busy="true"` e "Carregando carta…"; antes, conteúdo anterior | RT:189-212 `advanceTimersByTimeAsync(199)` → `aria-busy 'false'` + h1 "Luffy"; `(1)` → `'true'` + `getByText('Carregando carta…')`; CD:71-92 `skeleton` false em 199, true em 200 | ✅ (M24 morto; ⚠️ G3: no retry/troca vindo de erro o texto não aparece) |
| SCAR-08 | resposta de carta antiga descartada | RT:214-229 `heading Zoro` mantido após `first.resolve(Luffy)`; CD:103-118 | ✅ (M20 morto) |
| SCAR-09 | troca de sessão repete `GET` da carta atual | RT:317-328 `toHaveBeenCalledTimes(2)` ao entrar e `(3)` ao sair; E-P:220-255 sair pelo casco e `goBack` reabre sem sessão (refetch real) | ✅ (o spec exige só o refetch; `Sair` navega a `/app`, então ao vivo o refetch só é provado indiretamente — coberto no Vitest, débito aceito) |

### P1 — Cabeçalho e dados

| AC | Resultado | `arquivo:linha` + asserção | Result |
|---|---|---|---|
| SCAR-10 | imagem da variante em destaque, `alt` "<nome> <variant_code>", placeholder atrás sem mudar o quadro | CH:183-187 `toHaveAttribute('alt','Monkey.D.Luffy tcgplayer:1')`; CA:17-42 sem `<img>` com `image_url` nulo/erro e `.placeholder` presente; E-C:423-473 `.media img` `alt` troca com o destaque; verificado no navegador: quadro `384×537,59` igual com imagem e com 502 do CDN | ✅ (M13 morto; a igualdade de tamanho do quadro não tem teste: G9) |
| SCAR-11 | <64rem: miniatura ao lado do título + `<details>` "Ver imagem maior" fechado | CH:108-116 `details` sem `open`, `summary` "Ver imagem maior"; E-C:346-382 `el.open === false`, `summary` `toHaveText('Ver imagem maior')`, abre e `img` visível | ✅ |
| SCAR-12 | ≥64rem: coluna própria sempre visível | CH:118-125 `details` nulo, 1 `<img>`; E-C:346-382 `.media img` visível, `details` count 0, `header .thumb` count 0 | ✅ |
| SCAR-13 | chips: tipo capitalizado, raridade, cores, "Counter N" ≥64rem; linha "<set> · <código>" | CH:62-68 `['Character','SR','red','green']`; CH:86-106 `'Counter 1000'` só wide, `'Counter 0'`, nulo/Event sem chip; CH:70-74 `'Awakening · OP05'`; paridade E-C:267-289 `expect(spa.chips).toEqual(hotwire.chips)` | ✅ (M09b morto) |
| SCAR-14 | "Variante fora da fonte" | CH:127-134 `getByText('Variante fora da fonte')` só com `in_source:false` | ✅ |
| SCAR-15 | selo `role="img"` "1 cópia"/"N cópias", segue o valor otimista | CH:145-161; RT:487-510 `getByRole('img',{name:'3 cópias'})` após `+`, depois `'4 cópias'` com a resposta; `'1 cópia'` ao ir de 0 a 1 | ✅ (M26 morto) |
| SCAR-16 | "Ilustração: <illustrator>" | CH:136-143; RT:411-430 `getByText('Ilustração: Autor Dois')` | ✅ |
| SCAR-17 | campos por tipo, `0` exibido, listas por ", " | CF:31-76 `labels()` `toEqual(['Power','Life','Attribute','Traits','Block'])` (leader), `['Custo','Power','Counter','Attribute','Traits','Block']` (character), event/stage; `0` → `/^0$/`; `'Slash, Strike'`; E-C:314-344 contra a API real | ✅ (M09a, M10 mortos) |
| SCAR-18 | seção "Efeito" em texto puro, quebras, `Trigger` em `<strong>`, trigger sem efeito aparece | CF:80-123 `textContent` `'<script>alert(1)</script>\n[On Play] Draw 1.'`, `container.querySelector('script')` nulo, `strong.tagName` `'STRONG'`, ordem efeito<Trigger<texto; trigger sem efeito CF:107-112 | ✅ (M11 morto; `white-space: pre-line` correto no navegador — computado `pre-line` em OP18-001 — mas sem asserção: **M19 sobreviveu**, G5) |

### P1 — Variantes, preço e destaque

| AC | Resultado | `arquivo:linha` + asserção | Result |
|---|---|---|---|
| SCAR-19 | linha por variante na ordem, miniatura `alt=""` `loading="lazy"`, `<code>`, "<rarity> · <tipo>", "<set> (<código>)" | VR:53-74 `toHaveAttribute('alt','')`, `('loading','lazy')`, `'R · arte base'`, `'SR · parallel'`, `'SEC · alternativa'`, `'Romance Dawn (OP01)'`; RT:570-581 ordem `['Mostrar tcgplayer:2…','Mostrar tcgplayer:1…']`; paridade E-C:267-289 | ✅ |
| SCAR-20 | "fora da fonte" na linha | VR:76-82 | ✅ |
| SCAR-21 | `US$ 1.234,56`, "TCGplayer · market · dd/mm/aaaa" em São Paulo, "Sem preço" | `frontend/src/lib/format.test.ts:6` `toBe('US$ 1.234,56')`, `:19-20` `'BRL 12,00'`/`'EUR 1.234,56'`, `:26-27` `'04/10/2026'` para `02:00Z`; VR:84-102 `'TCGplayer · market · 05/10/2026'`, `'Sem preço'`; E-C:291-312 regex `/^(Sem preço\|US\$ \d{1,3}(\.\d{3})*,\d{2} TCGplayer · market · \d{2}\/\d{2}\/\d{4})$/` | ✅ (M07, M08 mortos) |
| SCAR-22 | miniatura é link `/app/cartas/<n>?variant=<código>`, nome "Mostrar <código> na imagem principal", `aria-current="true"` só no destaque | VR:104-114 `href '/app/cartas/OP01-001?variant=tcgplayer%3A1'`, `aria-current 'true'`/ausente; E-C:423-473 `a[aria-current="true"]` count 1 | ✅ (M25 morto) |
| SCAR-23 | troca de destaque local, `replaceState`, sem API | RT:411-440 `nav.replaceState` `toHaveBeenCalledWith('/app/cartas/OP01-001?variant=tcgplayer%3A2', {})`, `client.get` 1 vez; E-C:423-473 `history.length` igual, `apiReads` `toEqual([])` | ✅ (M29 morto) |
| SCAR-24 | `variant` ausente/inválido → 1ª `in_source`, senão 1ª listada | `frontend/src/lib/cards/featured.test.ts:21-39`; RT:442-485; E-C:267-289 paridade com `?variant=` inválido (`expectedFeatured`) | ✅ (M06 morto) |

### P1 — Posse com stepper otimista

| AC | Resultado | `arquivo:linha` + asserção | Result |
|---|---|---|---|
| SCAR-25 | quantidade ("não tenho"/"1 cópia"/"N cópias"), `−` `[n]` `+`, `[n]` `aria-hidden`, ≥44 px, nomes acessíveis | OS:47-54 `'não tenho'`,`'1 cópia'`,`'3 cópias'`; OS:56-64 `[aria-hidden="true"]` com `3` entre os botões; OS:31-32 nomes exatos "Remover/Adicionar uma cópia de <nome> <variant_code>"; OS:66-73 verifica `min-block-size: var(--touch-target)` **no texto-fonte** (⚠️ raso: nenhum teste mede 44 px no navegador, G9) | ✅ |
| SCAR-26 | sem sessão: link "Entrar para registrar posse" → `/app/entrar?return_to=…` | VR:141-150 `href` `/app/entrar?return_to=${encodeURIComponent('/app/cartas/OP01-001?variant=tcgplayer:1')}`; E-P:220-255 `searchParams.get('return_to')` `toBe(detailUrl.pathname + detailUrl.search)` | ✅ (M30 morto) |
| SCAR-27 | `+` soma 1 antes da resposta e envia incremento | Q:32-52 `queue.displayed` `toBe(5)` com `send` 1×; OS:75-83; E-P:120-170 `.step` `'1'..'5'` antes de qualquer resposta (`log.completed` `toBe(0)`) | ✅ |
| SCAR-28 | `−` com valor >0 subtrai antes e envia decremento | Q:54-72 `displayed` 1 após `tap('decrement')` de 2; OS:85-92 `send` `toHaveBeenCalledExactlyOnceWith('decrement')` | ✅ |
| SCAR-29 | em zero: `aria-disabled="true"`, focável, não envia, anuncia "Você não tem cópias desta variante para remover." | OS:94-105 `toHaveAttribute('aria-disabled','true')`, `not 'disabled'`, `send` não chamado, `live()` `toHaveTextContent('Você não tem cópias desta variante para remover.')`, `toHaveFocus()`; Q:74-90; E-P:120-170 `calls toEqual([])` | ✅ (M03, M27 mortos) |
| SCAR-30 | uma operação por toque, em ordem, próxima só após a resposta | Q:32-52 `calls[n-1].op` e `send` 5×; Q:54-72 ordem `['decrement','increment','decrement']`; E-P:120-170 `log.maxActive` `toBe(1)`, `log.started` 5, banco +5 | ✅ (M01 morto) |
| SCAR-31 | ao esvaziar, vale o `owned_quantity` da última resposta | Q:92-110 `displayed` `toBe(7)`, `onSettled` `toHaveBeenCalledWith(7)`; E-P:120-170 `ownedQuantity(...) toBe(5)` = número da tela | ✅ (M05 morto) |
| SCAR-32 | falha: descarta o não enviado, volta ao confirmado, mostra a `message` | Q:112-132 `displayed` `toBe(2)`, `send` 3×, `onError` com o erro; OS:133-145 `toasts` `message: 'Algo deu errado. Tente novamente.'`; E-P:172-194 `alert` "Sem conexão com o servidor. Tente novamente.", `.step` `'2'`, `log.started` 3, `GET` `toBe(2)` | ✅ (M02 morto) |
| SCAR-33 | anuncia a quantidade com nome e código só ao fim da fila | OS:112-131 `toHaveTextContent('2 cópias Monkey D. Luffy tcgplayer:12345')` só após a resposta; `'não tenho …'` | ✅ |
| SCAR-34 | foco fica no botão, sem desabilitar | OS:147-162 `add()` `toHaveFocus()`, `not.toHaveAttribute('disabled')` durante e depois | ✅ |

### P1 — Desejo por variante

| AC | Resultado | `arquivo:linha` + asserção | Result |
|---|---|---|---|
| SCAR-35 | `role="group"` "Marcar <nome> <código> como desejada", campo "Quero" (`min=1`,`step=1`), botão "Quero esta"/"Atualizar desejo"; sem sessão não exibe | WF:23-39; VR:124-132 e 141-150 `queryByRole('group')` ausente sem sessão | ✅ |
| SCAR-36 | "<nome> <código> na lista de desejos: 1 cópia." / "…: N cópias.", campo com o alvo devolvido, botão "Atualizar desejo" | WF:41-63 `toasts` `['Luffy tcgplayer:1 na lista de desejos: 1 cópia.']`, `'…: 4 cópias.'`, `field() toHaveValue(4)`; E-P:196-218 persiste após `reload` | ✅ |
| SCAR-37 | mensagem de `fields.target_quantity` junto do campo, `aria-describedby`, `aria-invalid="true"`, foco, valor mantido | WF:65-81 `aria-invalid 'true'`, `aria-describedby` = id do `<ul>`, `toHaveFocus()`, `toHaveValue(7)`; WF:83-98 `novalidate` e `target_quantity: 0` chega à API | ✅ (M15, M28 mortos) |
| SCAR-38 | envio pendente: botão desabilitado, novo envio ignorado | WF:129-143 `toBeDisabled()`, `put` `toHaveBeenCalledTimes(1)` | ✅ (M16 morto) |

### P2 — Transição grade → detalhe

| AC | Resultado | `arquivo:linha` + asserção | Result |
|---|---|---|---|
| SCAR-39 | arte do tile vira a imagem principal visível, na transição de rota | E-M:133-144 `groupNames` `toContain(morphName(number))` (360 e 1280 px), nenhuma transição `skipped`; CH:163-175 um só elemento com `view-transition-name` (wide e narrow, fora do `<details>`); `CardTile.test.ts:67-73` | ✅ (M12 morto) |
| SCAR-40 | volta (botão ou voltar do navegador) vira a arte do tile | E-M:146-200 três cenários (botão, `goBack`, link direto) `toContain(morphName(number))`; RT:288-315 marca ao carregar e ao trocar | ✅ |
| SCAR-41 | sem suporte ou `reduced-motion`: troca sem transformação e sem erro | `frontend/src/lib/view-transition.test.ts:18-37` sem `startViewTransition` não lança, com `reduced` não chama; E-M:202-229 `transitions(page)` `toEqual([])`, `groupNames` `toEqual([])`, `errors` `toEqual([])` | ✅ |

### P1 — API

| AC | Resultado | `arquivo:linha` + asserção | Result |
|---|---|---|---|
| SCAR-42 | `200 { data: { variant_code, owned_quantity } }`, cria com 1, soma | R-V:57-74 `assert_equal({ "data" => { "variant_code" => "tcgplayer:123", "owned_quantity" => 1 } }, response.parsed_body)`; segundo → `2`, `assert_no_difference CollectionItem.count` | ✅ |
| SCAR-43 | decremento: subtrai >0; em zero ou sem registro `200` `owned_quantity: 0` sem criar/alterar | R-V:76-108 `quantity_of … 1`; zero: `assert_equal 0, item.reload.quantity`; sem registro: `assert_no_difference CollectionItem.count` + corpo `owned_quantity => 0`; `test/models/collection_item_atomic_test.rb:48-63` `assert_nil` | ✅ (R06 morto) |
| SCAR-44 | concorrência sem perda nem negativo | R-C:139-196 três incrementos de 0 → `assert_equal [3], quantities` e `[1,2,3]`; de 1 → 4; três decrementos de 1 → `[0,0,0]`/`[0]`; dois de 2 → `[0]`; inc+dec → `[1]`; sobreposição forçada por lock (`wait_until_blocked`, `pg_stat_activity wait_event_type='Lock'`) | ✅ (R01, R02 mortos) |
| SCAR-45 | `PUT` cria/atualiza, `200 { data: { variant_code, wishlist_target } }` | R-W:64-99 `assert_equal({ "data" => { "variant_code" => "tcgplayer:123", "wishlist_target" => 2 } }, …)`; 3 atualiza o mesmo registro; mesmo alvo sem duplicar; `"3"` aceito (101-109); corrida de criação R-W:240-261 | ✅ |
| SCAR-46 | `422 validation_failed`, "Dados inválidos.", `fields.target_quantity == ["Informe um número inteiro maior ou igual a 1."]`, sem gravar | R-W:111-143 `assert_equal INVALID_TARGET, response.parsed_body` para `0,-1,1.5,2147483648,"abc","","0","1.5","-2"," 2",nil,true,[2],{a:1}`, ausente e sem corpo; `assert_equal 2, target_of(...)` (não gravou) | ✅ (R03, R07 mortos) |
| SCAR-47 | carta inexistente / variante de outra carta → `404 not_found` nos três | R-V:120-143 `assert_equal NOT_FOUND` (increment e decrement); R-W:164-182 (desejo) | ✅ (R04 morto) |
| SCAR-48 | sem sessão `401`, sem token `422 invalid_csrf_token`, só `Current.user`, ignora `user_id` | R-V:145-191 `assert_response :unauthorized`/`:unprocessable_entity`, `"invalid_csrf_token"` com `allow_forgery_protection = true` (setup:9), `user_id` na query e no corpo ignorado; R-W:184-223 idem | ✅ (R05 morto) |
| SCAR-49 | HTML inalterado; `CollectionItemsController` delega o SQL ao model | `git diff --name-status 213f0bc..HEAD -- test/` → só 4 linhas `A`; `git diff … collection_items_controller.rb` remove o SQL e chama `CollectionItem.increment_for!`/`decrement_for!` (SQL movido idêntico); Rails 1966 runs, 0 failures | ✅ |

**Status dos ACs**: 49/49 com resultado exato provado. Lacunas de precisão do spec (⚠️, sem defeito): título de página dos estados carregando/erro ("Carta — Bindr", `frontend/src/routes/cartas/[card_number]/+page.svelte:47`) não definido no spec; "divisor" do SCAR-04 e "sem mudar a largura nem a altura" do SCAR-10 definidos sem número observável; SCAR-09 vivo só indiretamente.

---

## 3. Edge cases

- [x] `card_number` com caractere reservado — RT:159-164 `'/api/cards/P%20029%2Fx'`; `url.test.ts:18-20 '/app/cartas/A%20B%2FC'`; Rails `P.029`: R-V:110-118, R-W:155-162.
- [x] `variant_code` com `:` — `url.test.ts:44-47 '/api/cards/A%20B%2FC/variants/x%2Fy/increment'`; R-V:110-118; VR:138 `'/api/cards/OP01-001/variants/tcgplayer%3A1/increment'`.
- [x] Sair com o detalhe aberto — RT:527-547 `queryByRole('img',{name:/cópia/})` ausente, 2 links "Entrar para registrar posse", sem botão "Adicionar"; E-P:220-255.
- [x] Sair com operações pendentes — RT:527-547 resposta tardia `9` não aparece na tela anônima (`queryByText('9 cópias')` nulo).
- [x] Trocar de variante com operações pendentes noutra — RT:512-525 `within(rowOf('tcgplayer:1')).findByText('7 cópias')`, `client.post` 1 vez.
- [x] Navegar para outra carta com operações pendentes — RT:231-252 `queryByText('9 cópias')` nulo; fila antiga descartada (`discard()` no desmonte, `OwnershipStepper.svelte:47`).
- [x] Outra aba muda a posse — Q:92-110 `displayed 7`.
- [x] Decremento chega com a posse já em zero — R-V:88-108 (`200`, `0`); OS:123-131 anuncia "não tenho …".
- [x] Imagem `403`/`404` mantém o placeholder — CA:24-31; verificado no navegador (502 do CDN: 0 `<img>`, placeholder visível, mesmo quadro).
- [x] Carta sem variante — RT:559-568 sem `<img>` e sem "Variantes na pasta"; mostra `card_number`.
- [x] Mesmo alvo de desejo — R-W:89-99 `assert_no_difference WishlistItem.count`.
- [x] `PUT` com JSON malformado → `400 invalid_json` — R-W:145-153.
- [~] Viewport cruza 64rem sem refazer consulta nem perder operações pendentes — RT:367-381 só prova o botão "Voltar" e `client.get` 1×; o movimento da imagem e as filas pendentes não têm teste (as linhas ficam fora do `{#if wide.current}`, então o comportamento é correto por construção). **G6 (Minor)**.
