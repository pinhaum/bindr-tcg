# Pasta e lista de desejos na SPA (`spa-pasta`) — Validação

**Veredito**: PASS
**Data**: 2026-10-11
**Spec**: `.specs/features/spa-pasta/spec.md` (SPAS-01..46 e Edge Cases; com a edição não commitada de SPAS-11, 26 e 34)
**Diff range**: `8e6c92d..HEAD` (HEAD = `6c2c357`)
**Verifier**: sub-agente independente (autor ≠ verificador; verificador novo na iteração 3)
**Iteração**: 3

## Validation: spa-pasta - PASS ✅

**Resumo da iteração 1** (FAIL): 43/46 ACs, 1 GAP (SPAS-36, M3 sobreviveu), 2 spec-precision gaps (SPAS-11, SPAS-26), gate verde (Rails 1995, Vitest 856, e2e 193), SPAS-46 provado, sensor 4/5.

**Resumo da iteração 2** (FAIL, Minor): o commit `769c7d5` fechou SPAS-36 (M3 morre) e o spec editado fechou a precisão de SPAS-11 e SPAS-26; sobrou F4: a cláusula "o foco só é movido quando ficou no `body`" do SPAS-34 não tinha teste (M7 sobreviveu). Vitest 858.

**Iteração 3**: o commit `6c2c357` ("test(spa-pasta): cobrir o foco que não é roubado na remoção") acrescentou `desejos/page.test.ts:181-198`. Refiz o M7 numa cópia nova: **morre** (1 falhou, 13 passaram, `Received element with focus: … Carta 3`). Front quick: `check` e `lint` limpos, Vitest 59 arquivos, **859** testes, 0 falhas. Rails (1995) e e2e (193) não foram rerodados: `git diff --stat 7002c44..HEAD -- app frontend/e2e test` vazio, e o único arquivo de código/teste alterado desde a iteração 1 é `frontend/src/routes/pasta/desejos/page.test.ts` (outros arquivos alterados são só `.context/requirements.md`, `.specs/STATE.md` e `.specs/features/spa-decks/spec.md`). Sem lacuna restante: 46/46 ACs, 0 spec-precision gaps, sensor sem sobreviventes na versão atual.

SPAS-46 reconferido: `git diff --name-status 8e6c92d..HEAD -- test/` só com `A`; `git diff --stat 8e6c92d..HEAD -- app/views/progress app/views/wishlist_items app/controllers/progress_controller.rb app/controllers/wishlist_items_controller.rb` vazio.

---

## Task Completion

| Task | Status | Notes |
| ---- | ------ | ----- |
| T1–T17 | ✅ Done | Todos os checkboxes de `tasks.md` marcados; o diff cobre API (T1–T3), cliente e rotas (T4–T8), componentes (T9–T12), páginas (T13–T14), e2e (T15–T16) e fechamento (T17). |

---

## Spec-Anchored Acceptance Criteria

Convenção: `arquivo:linha` – expressão. Vitest sob `frontend/`, e2e em `frontend/e2e/`, Rails em `test/integration/api/`. Onde cito um intervalo de linhas, a asserção está dentro dele. `api.get` já devolve o `data` desempacotado: os mocks de página (`frontend/src/routes/pasta/page.test.ts:121`, `frontend/src/routes/pasta/desejos/page.test.ts:77`) devolvem o dado **sem** envelope, então o defeito que a T14 só achou pelo e2e não fica mais mascarado pelo teste unitário (risco levantado pelo supervisor: refutado).

### P1: Pasta em `/app/pasta` (SPAS-01..07)

| # | Spec-defined outcome | `file:line` + assertion | Result |
|---|---|---|---|
| 1 | Título "Minha pasta — Bindr", h1 "Minha pasta" | `frontend/src/routes/pasta/page.test.ts:136` – `expect(document.title).toBe('Minha pasta — Bindr')`; `frontend/e2e/pasta.spec.ts:134` – `getByRole('heading', { name: 'Minha pasta', level: 1 })` visível | ✅ PASS |
| 2 | Entrada da navegação aponta para `/app/pasta`, sem recarga, `aria-current` com qualquer query | `frontend/src/lib/components/MainNav.test.ts:73-82` – `it.each(["/app/pasta", "/app/pasta?order=code"])` … `toHaveAttribute("aria-current","page")`; `frontend/src/lib/navigation/nav-entries.test.ts:34-37` (href e navegação sem recarga); `frontend/e2e/pasta.spec.ts:316-322` (título e `aria-current` após o clique) | ✅ PASS |
| 3 | Anônimo vai a `/app/entrar?return_to=…` sem chamar a API | `frontend/src/routes/pasta/page.test.ts:107` – `location: '/app/entrar?return_to=%2Fapp%2Fpasta%3Forder%3Dcode'` e `apiMock.get` `not.toHaveBeenCalled()` (`:110`); `frontend/src/routes/pasta/desejos/page.test.ts:56-58` – `rejects.toMatchObject({ status: 307, location: '/app/entrar?return_to=%2Fapp%2Fpasta%2Fdesejos' })`; `frontend/e2e/pasta.spec.ts:295,298` – `return_to` igual a `/app/pasta?order=code`, `calls` igual a `[]` | ✅ PASS |
| 4 | Chama `GET /api/progress` repassando só `order` | `frontend/src/routes/pasta/page.test.ts:145` – `toHaveBeenCalledWith('/api/progress')`; `:161` – `toHaveBeenCalledWith('/api/progress?order=code')` | ✅ PASS |
| 5 | Resposta de URL antiga descartada | `frontend/src/routes/pasta/page.test.ts:164-178` – `first.resolve(payload('recent'))` depois de `second`; `expect(getByRole('link',{ name: 'Por código', current: 'page' }))` continua | ✅ PASS |
| 6 | Mais de 200 ms: `aria-busy="true"` e "Carregando …" | `frontend/src/routes/pasta/page.test.ts:185-191` – `queryByText('Carregando pasta…')` ausente e `[aria-busy="true"]` nulo antes; presente e não nulo depois; `frontend/src/routes/pasta/desejos/page.test.ts:100,103` – idem com "Carregando lista de desejos…". A parte "mantendo até lá o conteúdo anterior" **não** foi verificada por mim com uma asserção própria nesta rodada | ✅ PASS (cláusula "conteúdo anterior" sem asserção dedicada: Info) |
| 7 | Erro ≠ 401: `message` como veio e "Tentar novamente" repete | `frontend/src/routes/pasta/page.test.ts:200,205` – mensagem exibida e `apiMock.get` chamado 2 vezes; `frontend/src/routes/pasta/desejos/page.test.ts:110-118` – `click('Tentar novamente')`. O `401` da carga segue o SPA-09 (cliente da fundação) | ✅ PASS |

### P1: Indicadores (SPAS-08..11)

| # | Spec-defined outcome | `file:line` + assertion | Result |
|---|---|---|---|
| 8 | Três cartões na ordem, plurais 0/1/2 | `frontend/src/lib/components/PastaSummary.test.ts:52` – `expect(cards(container)).toEqual([...])`; `:68-69` – `toContain(copiesText)`, `toContain(distinctText)` | ✅ PASS |
| 9 | Nota "N cópias sem preço" só com `unpriced_copies > 0` | `PastaSummary.test.ts:77` – `expect(cards(container)[2]).toContain(note)`; `:82` – `not.toContain('sem preço')` | ✅ PASS |
| 10 | `"0.00"` vira `US$ 0,00` | `PastaSummary.test.ts:89` – `toContain('US$ 0,00 valor estimado')` | ✅ PASS |
| 11 | ≥64rem: cada cartão com um quarto da coluna, **descontados os vãos** (trilha de `repeat(4, 1fr)`), sem esticar (spec editado) | `frontend/e2e/pasta.spec.ts:376-379` – `expect(Math.abs(width - quarter)).toBeLessThanOrEqual(1)` com `quarter = (column - 3*gap)/4` (`:362-372`); CSS `frontend/src/lib/components/PastaSummary.svelte:70-72` – `repeat(4, 1fr)` | ✅ PASS |


### P1: Número interpolado (SPAS-12..16)

| # | Spec-defined outcome | `file:line` + assertion | Result |
|---|---|---|---|
| 12 | Primeira exibição de 0 ao valor em 320 ms (`--duration-slow`), curva `--ease-standard` | `frontend/src/lib/components/AnimatedNumber.test.ts:58-68` – 0 ms `toHaveTextContent('0')`, 160 ms `mid > 0` e `mid < 42`, 360 ms `toHaveTextContent('42')`; tokens em `frontend/src/lib/styles/tokens.css:58-59` (`320ms`, `cubic-bezier(0.2, 0, 0, 1)`); `frontend/src/lib/motion.test.ts:6,64-72` lê `tokens.css` e confere `easeStandard` | ✅ PASS (a curva é conferida contra o token em `motion.test.ts`, não ponto a ponto no componente) |
| 13 | Mudança de valor anima do exibido ao novo; mesmo valor não anima; interpolação em **centavos** (10,00 → 12,50) | `frontend/src/lib/components/PastaSummary.test.ts:108` – `toHaveTextContent('US$ 10,00')`; `:116-118` – `mid` casa `/US\$\s10,\d\d\|US\$\s11,\d\d\|US\$\s12,\d\d/`, `not.toMatch(/,00$/)`, `not.toContain('12,50')`; `:122` – `toHaveTextContent('US$ 12,50')`; `AnimatedNumber.test.ts:75-91` (mesmo valor não anima; `mid` ≠ `US$ 10,00` e ≠ `US$ 12,50`); `:119-135` (redireciona no meio do caminho). **O sensor M2 prova que o quadro intermediário discrimina** | ✅ PASS |
| 14 | Reduced motion: primeiro quadro já final | `AnimatedNumber.test.ts:94-97` – `reduced.current = true`, `visible` com `'US$ 12,50'`; `frontend/e2e/pasta.spec.ts:509-510` – todo quadro amostrado `toEqual(finals)` no Chromium com `reducedMotion: 'reduce'` | ✅ PASS |
| 15 | Intermediários fora da árvore de acessibilidade; texto acessível = final + rótulo; sem região viva | `PastaSummary.test.ts:95-97` – `.number` com `aria-hidden="true"`, `accessibleText(first)` igual a `'10 cartas na pasta'`; `AnimatedNumber.test.ts:148-150` – `aria-hidden`, `[aria-live]` e `[role="status"]` nulos | ✅ PASS |
| 16 | Formato igual ao final, tabulares, sem deslocar, termina em `US$ 1.234,56` | `AnimatedNumber.test.ts:142-143` – `toHaveTextContent('US$ 1.234,56')`; `:155` – `toContain('font-variant-numeric: tabular-nums')`; `:103-107` – cópia reservada `aria-hidden` e `visibility: hidden`; `PastaSummary.test.ts:130`; `frontend/e2e/pasta.spec.ts:482-494` – largura do cartão constante e último quadro `toEqual(finals)` | ✅ PASS |

### P1: Progresso por set (SPAS-17..23)

| # | Spec-defined outcome | `file:line` + assertion | Result |
|---|---|---|---|
| 17 | Chips-link com URLs e `aria-current` de `data.order`, não da query | `frontend/src/routes/pasta/page.test.ts:214-223` – `setUrl('?order=xyz')`, `recent` `toHaveAttribute('aria-current','page')`, hrefs `/app/pasta?order=recent` e `?order=code`, `data-sveltekit-reset="false"` | ✅ PASS |
| 18 | Sets na ordem de `data.sets`, lista nomeada pelo título, sem contagem | `page.test.ts:228-234` – `items[0]` contém `OP02`, `items[1]` contém `OP01`, `queryByText(/\b2 sets\b/)` ausente; `frontend/e2e/pasta.spec.ts:249-250` – cada linha `toEqual(expected)` contra `/progress` | ✅ PASS |
| 19 | Linha com `code` em `<code>` e link `/app?sets[]=<code codificado>` | `frontend/src/lib/components/SetProgressRow.test.ts:28-30` – `href '/app?sets[]=OP01'` e `querySelector('code')`; `:35` – `'/app?sets[]=A%26B%231'` | ✅ PASS |
| 20 | Com `base_size`: "3 / 7 · 43%", barra `aria-hidden` `value`/`max`, legenda | `SetProgressRow.test.ts:40-45` – `getByText('3 / 7 · 43%')`, `bar` `aria-hidden="true"`, `value="3"`, `max="7"`, `getByText('3 de 7 do set base')` | ✅ PASS |
| 21 | Sem `base_size`: só `owned_numbers`, sem barra nem `%`, legenda de indisponível | `SetProgressRow.test.ts:52-56` – `querySelector('progress')` nulo, `textContent` sem `/%/` e sem `'0%'`, legenda exata | ✅ PASS |
| 22 | "N de M parallel(s)", irmão do percentual | `SetProgressRow.test.ts:64-69` – `one.tagName` `'P'`, `not.toContainElement` nos dois sentidos, `'0 de 2 parallels'` | ✅ PASS |
| 23 | "valor" + `US$ 1.234,56`, inclusive `US$ 0,00` | `SetProgressRow.test.ts:74` – `getByText('valor US$ 1.234,56')`; `:77` – `getByText('valor US$ 0,00')` | ✅ PASS |

### P1: Ações da pasta (SPAS-24..26)

| # | Spec-defined outcome | `file:line` + assertion | Result |
|---|---|---|---|
| 24 | "Adicionar cartas à pasta" para `/app` sem recarga; fixa acima da barra <64rem; na lateral ≥64rem, abaixo de divisor | `frontend/src/routes/pasta/page.test.ts:237-254` – `add` `toHaveAttribute('href','/app')` e sem `data-sveltekit-reload`; `:256-` – `shell.aside` recebe "Adicionar cartas" e volta a `null` ao desmontar (AD-028); `frontend/e2e/pasta.spec.ts:402-407` – `inAside`, `border` 1, `position` ≠ `fixed`, `belowDivider`; `:422-435` – `position` `fixed`, ação acima da barra, último set acima da ação, `toBeInViewport({ ratio: 1 })` | ✅ PASS |
| 25 | CSV `/collection/export` e Importar `/collection/import` com página inteira; Desejos `/app/pasta/desejos` sem recarga | `page.test.ts:237-254` – `csv` `href '/collection/export'` + `data-sveltekit-reload`; `imp` `href '/collection/import'` + `data-sveltekit-reload`; `wishlist` `href '/app/pasta/desejos'` e `not.toHaveAttribute('data-sveltekit-reload')` | ✅ PASS |
| 26 | Composição da `/progress` a 390px e 1280px, sem scroll horizontal a 360px; **capturas geradas pelo e2e, comparação feita pelo dono** (spec editado) | `frontend/e2e/pasta.spec.ts:343,347` – `data-theme` e `expectNoHorizontalScroll` nos dois temas e viewports; `:516-530` – o teste `capturas de /app/pasta e /progress a ${width}px para o dono (SPAS-26)` grava `spa-pasta-${width}.png` e `hotwire-progress-${width}.png` em `CAPTURES_DIR` (não versionadas, `frontend/.gitignore:5`); paridade de conteúdo em `pasta.spec.ts:244-262` | ✅ PASS |


### P1: Lista de desejos (SPAS-27..36)

| # | Spec-defined outcome | `file:line` + assertion | Result |
|---|---|---|---|
| 27 | Título "Lista de desejos — Bindr", h1, `GET /api/wishlist` | `frontend/src/routes/pasta/desejos/page.test.ts:87-90` – `document.title` `'Lista de desejos — Bindr'`, h1, `apiMock.get` `toHaveBeenCalledWith('/api/wishlist')`; `frontend/e2e/pasta-desejos.spec.ts:193` – `toHaveTitle` | ✅ PASS |
| 28 | Vazio: duas frases e "catálogo" como link para `/app` | `desejos/page.test.ts:126-127` – `getByRole('link',{ name: 'catálogo' })` `toHaveAttribute('href','/app')`; `frontend/e2e/pasta-desejos.spec.ts:294` – `getByText(EMPTY_MESSAGE)` | ✅ PASS |
| 29 | "1 item"/"N itens", ordem de `data` | `desejos/page.test.ts:133-145` – `'1 item'`, `'2 itens'`, `names[0]` contém `Carta 2`, `names[1]` contém `Carta 1`; `pasta-desejos.spec.ts:203-205` – `spa.count` igual a `html.count` e `spa.rows` `toEqual(html.rows)` | ✅ PASS |
| 30 | `card_name` + `variant_code` em `<code>` como link para `/app/cartas/<card_number codificado>`; "N de M cópia(s)" | `frontend/src/lib/components/WishlistItem.test.ts:24-25` – `href '/app/cartas/OP01-001'`, `getByText('tcgplayer:1').tagName` `'CODE'`; `:30-31` – href codificado; `:43,46` – `'1 de 1 cópia'`, `'0 de 2 cópias'`; `pasta-desejos.spec.ts:220-222` – navega sem recarga | ✅ PASS |
| 31 | "Atendido" ou "Faltam N", N = alvo − posse | `WishlistItem.test.ts:51-52,57-58` – `getByText('Atendido')` e `queryByText(/Faltam/)` nulo; `getByText('Faltam 2')` e `queryByText('Atendido')` nulo; `pasta-desejos.spec.ts:206` – `toEqual(['Atendido','Faltam 2','Faltam 2'])` | ✅ PASS |
| 32 | Botão "Remover", alvo ≥44px, nome acessível com estado | `WishlistItem.test.ts:63-71` – nome `Remover … da lista de desejos (atendido)` / `(faltam N)`; `:79-80` – `min-block-size: var(--touch-target)` e `min-inline-size` | ✅ PASS |
| 33 | `200` tira o item, atualiza contagem, anuncia "Item removido da lista de desejos." | `desejos/page.test.ts:147-159` – `apiMock.delete` `toHaveBeenCalledWith('/api/cards/OP01-002/variants/tcgplayer%3A2/wishlist')`, `'2 itens'`, `queryByText('Carta 2')` ausente, `notifySuccess` com o texto; `pasta-desejos.spec.ts:261-262` | ✅ PASS |
| 34 | Foco: seguinte, senão anterior, senão h1; **só quando o foco ficou no `body`** (spec editado) | `desejos/page.test.ts:167` – `removeButton(3)` `toHaveFocus()`; `:171` – `removeButton(1)`; `:176` – h1 `toHaveFocus()`; **novo (commit 6c2c357)** `:181-198` 'foco já levado a outro controle não é roubado' – `removeButton(1).focus()` durante a remoção pendente, depois `expect(removeButton(1)).toHaveFocus()` (`:196`) e `expect(removeButton(3)).not.toHaveFocus()` (`:197`); `pasta-desejos.spec.ts:263-264` – `toBeFocused()` e `document.activeElement === document.body` falso; `:295` – h1 `toBeFocused()`. **M7 (tirar `&& focusLost()`) morre** | ✅ PASS |
| 35 | Pendente: botão do item desabilitado e novo acionamento ignorado; demais acionáveis | `desejos/page.test.ts:180-199` – `removeButton(1)` `toBeDisabled()`, `removeAttribute('disabled')` + clique, `apiMock.delete` `toHaveBeenCalledTimes(1)`, `removeButton(3)` `toBeEnabled()`; `WishlistItem.test.ts:94-96`. **O sensor M4 (remover o guard `removing.has(id)`) morre** | ✅ PASS |
| 36 | Falha: item mantido e `message` como veio; `401` ou sessão trocada segue SPA-09/10 | `desejos/page.test.ts:201-215` – ramo `500`: `notifyError` `toHaveBeenCalledWith('Algo deu errado. Tente de novo.')`, `'3 itens'`, `removeButton(2)` `toBeEnabled()`/`toHaveFocus()`; **novo (commit 769c7d5)** `desejos/page.test.ts:218-236` – `it.each` com `ApiError(401,'unauthenticated')` e `ApiError(422,'session_changed')`: `removeButton(2)` `toBeEnabled()`, `expect(toast.notifyError).not.toHaveBeenCalled()` (`:231`), `notifySuccess` não chamado, `'3 itens'` e `'Carta 2'` presentes. **M3 morre** (2 falhas). O redirecionamento em si é do cliente da fundação (SPA-09/10) | ✅ PASS |

### P1: API da pasta e da lista de desejos (SPAS-37..46)

| # | Spec-defined outcome | `file:line` + assertion | Result |
|---|---|---|---|
| 37 | `GET /api/progress` com sessão: `200` e `{ data: { order, summary, sets } }` sobre a coleção do usuário da sessão | `test/integration/api/progress_test.rb:41-42` – `assert_response :ok`, `assert_equal "application/json", response.media_type`; `:50-81` – dois usuários, `data["summary"]` e `data["sets"]` contra `collection_stats_for` e `SetProgressQuery`; `:188-196` – `user_id` alheio na query ignorado (`total_copies` 0, `owned_numbers` 0) | ✅ PASS |
| 38 | `order` ausente/desconhecido/vazio/lista → `recent`; `code` → `code` | `progress_test.rb:110` – `assert_equal "recent", progress(query)["order"], query`; `:126-127` – `"code"` e `%w[OP01 OP09]` (com `recent` em `:122` = `%w[OP09 OP01]`) | ✅ PASS |
| 39 | `summary` com `total_copies`, `distinct_variants`, `estimated_value {amount, currency "USD"}`, `unpriced_copies`, iguais ao Hotwire | `progress_test.rb:68-70` – `assert_equal({ "total_copies" => …, "estimated_value" => money(…), "unpriced_copies" => … }, data["summary"])`; `:91-92,103` – `0.00` sem cópia com preço, `unpriced_copies` 1, moeda ≠ USD fora do valor | ✅ PASS |
| 40 | Campos de `sets`; `base_size` nulo se ausente/zero; percentual meio para cima, ≤100, nulo sem base; `value` `"0.00"` | `progress_test.rb:73-78` – `name`, `owned_numbers`, `base_size`, `parallel_owned`, `parallel_total`, `value`; `:136-138` – `assert_nil set["base_size"]`, `assert_nil set["completion_percent"]`; `:150-152` – `base_size` 1, `owned_numbers` 1, `completion_percent` 100; `:161,164` – `assert_equal 13` (12,5%) e `88` (87,5%); `:90` – `money(0)` | ✅ PASS |
| 41 | Consultas SQL constantes com sets, variantes e itens | `progress_test.rb:177` – `assert_equal baseline, count_queries { progress }` após mais 18 sets e 9 itens | ✅ PASS |
| 42 | `GET /api/wishlist`: campos, `owned_quantity` 0 sem posse, `fulfilled`, ordem por criação e id, consultas constantes | `test/integration/api/wishlist_test.rb:55-66` – `assert_equal [ {…"owned_quantity" => 0,"fulfilled" => false}, {…3,true}, {…2,true} ], wishlist` (ordem por `created_at`); `:97` – `assert_equal baseline, count_queries { wishlist }`; `:71` – `[]` | ✅ PASS |
| 43 | `DELETE …/wishlist` com sessão e CSRF: apaga só o do usuário e responde `200 { data: { variant_code, wishlist_target: null } }`; sem desejo, o mesmo `200` | `test/integration/api/card_variants_unwish_test.rb:62-68` – `assert_difference -> { WishlistItem.count }, -1`, `assert_equal REMOVED, response.parsed_body`, `assert_nil target_of(@user, @variant)`; `:75-79` – `assert_no_difference` e o mesmo corpo; `:88-89` – repetir continua `200`; `:134-137` – `tcgplayer:456` codificado; `frontend/e2e/pasta-desejos.spec.ts:270-275` – desejo de outro usuário intacto. **O sensor M1 (tirar o `for_user`) morre** | ✅ PASS |
| 44 | Carta inexistente ou `variant_code` de outra carta → `404 not_found`, sem apagar | `card_variants_unwish_test.rb:147-148` – `assert_response :not_found`, `assert_equal NOT_FOUND, response.parsed_body`; `:158-159` – idem com variante de outra carta, com `assert_no_difference` | ✅ PASS |
| 45 | Sem sessão `401`, sem CSRF `422`; só registros de `Current.user`, `user_id` ignorado | `progress_test.rb:183-185` – `:unauthorized`, `"unauthenticated"`; `wishlist_test.rb:103-105` – idem; `card_variants_unwish_test.rb:169-170` – `:unauthorized` sem apagar; `:180-181` – `:unprocessable_entity`, `"invalid_csrf_token"`; `:101-102,114-115` – `target_of(@user)` nulo e `assert_equal 4, target_of(@other, @variant)`; `wishlist_test.rb:85-87` – lista só `[ shared.variant_code ]` com `owned_quantity` 0 | ✅ PASS |
| 46 | Controllers e rotas HTML inalterados; suíte existente passa sem edição | `git diff --name-status 8e6c92d..HEAD -- test/` só com `A` (3 arquivos); `git diff --stat 8e6c92d..HEAD -- app/views/progress app/views/wishlist_items app/controllers/progress_controller.rb app/controllers/wishlist_items_controller.rb` vazio; `rails test` 1995 runs, 0 failures | ✅ PASS |

**Status**: ✅ 46 PASS, 0 GAP, 0 spec-precision gaps (iteração 3)

---

**Julgamento dos ACs editados (iteração 2, atualizado na 3)** (`git diff HEAD -- .specs/features/spa-pasta/spec.md`, ainda não commitado):

- **SPAS-11**: o texto agora diz "descontados os vãos entre os quatro cartões (trilha de `repeat(4, 1fr)`)", que é exatamente o que o e2e mede (`quarter = (column - 3*gap)/4`). Deixa de ser spec-precision gap. Resíduo Info: o *Independent Test* (linha 116) ainda diz "igual a um quarto da coluna (tolerância de 1px)", sem a ressalva dos vãos; o AC, que manda, está preciso.
- **SPAS-26**: o texto agora diz que as capturas são "geradas pelo e2e" e a comparação "feita pelo dono". O e2e as gera de fato (`pasta.spec.ts:516-530`). Deixa de ser spec-precision gap. A pasta `frontend/test-results/pasta-capturas/` **não existe em disco agora** (o `test-results` do Playwright é recriado a cada rodada e não é versionado); o AC não exige o arquivo persistido, só que o e2e o gere.
- **SPAS-34** (iteração 3): o texto traz "o foco só é movido quando ficou no `body`" (`spec.md:189`), que descreve `focusLost()`; a cláusula agora tem teste (`page.test.ts:181-198`) e M7 morre. PASS.
- **SPAS-36**: GAP fechado pelos dois casos novos; M3 morre.

---

## Discrimination Sensor

**Iteração 1** (cópia em `tmp/sensor-spa-pasta/`): M1 (`for_user` removido em `Api::CardVariantsController`) killed; M2 (interpolação em centavos desfeita) killed; M3 (cláusula `401`/`session_changed`) **survived**; M4 (guard `removing.has(id)`) killed; M5 (vizinho invertido) killed.

**Iteração 2** (cópia do `frontend/` em `tmp/sensor2-spa-pasta/`, sem `node_modules`/`.git`/`storage`; vitest em `node:24.21.0-slim` com o volume `node_modules` do compose; nenhum `git stash`, nenhum `git worktree`):

| Mutation | File:line (cópia) | Description | Killed? |
| -------- | ----------------- | ----------- | ------- |
| M3 (refeito) | `src/routes/pasta/desejos/+page.svelte:72` | `if (cause.status !== 401 && cause.code !== 'session_changed') notifyError(cause.message);` → `notifyError(cause.message);` | ✅ **Killed**: `page.test.ts:231` `expect(toast.notifyError).not.toHaveBeenCalled()` falha nos dois casos (`Received: ["A sessão mudou."]`); 2 failed, 11 passed |
| M6 | `src/routes/pasta/desejos/+page.svelte:63` | `else heading?.focus();` removido (lista vazia sem foco no h1) | ✅ **Killed**: "foco vai ao seguinte, ao anterior e ao h1 (SPAS-34)"; 1 failed, 12 passed |
| M7 | `src/routes/pasta/desejos/+page.svelte:62` | `if (index >= 0 && focusLost()) {` → `if (index >= 0) {` (move o foco mesmo se ele já foi a outro controle) | ❌ **Survived**: 13/13 passam → F4 |

**Iteração 3** (cópia nova do `frontend/` em `tmp/sensor3-spa-pasta/`, sem `node_modules`/`.git`/`storage`/`.svelte-kit`; vitest em `node:24.21.0-slim` com o volume `node_modules` do compose montado na cópia, de modo que os imports relativos resolvem; nenhum `git stash`, nenhum `git worktree`):

| Mutation | File:line (cópia) | Description | Killed? |
| -------- | ----------------- | ----------- | ------- |
| M7 (refeito) | `src/routes/pasta/desejos/+page.svelte:62` | `if (index >= 0 && focusLost()) {` → `if (index >= 0) {` (move o foco mesmo se ele já foi a outro controle) | ✅ **Killed**: `page.test.ts:196` `expect(removeButton(1)).toHaveFocus()` falha (`Received element with focus: … Carta 3`); 1 failed, 13 passed |

**Sensor depth**: lightweight (1 mutação na iteração 3; 9 no total nas três iterações)
**Result**: iteração 3: 1/1 killed — PASS ✅. M3 (iteração 1) e M7 (iteração 2), os sobreviventes anteriores, estão mortos; M1, M2, M4, M5 e M6 morreram antes.

Isolamento (iteração 3): `git status --porcelain` da árvore real salvo em `tmp/status-before3.txt` antes e comparado depois do sensor e do Front quick: **idêntico**. A cópia `tmp/sensor3-spa-pasta/` foi removida por inteiro (limpeza feita num container, sem deixar o diretório). O código real nunca foi mutado.

Isolamento (iteração 2): `git status --porcelain` da árvore real capturado antes (`M .specs/LESSONS.md`, ` M .specs/features/spa-pasta/spec.md`, ` M .specs/lessons.json`, `?? .playwright-mcp/`, `?? .specs/features/spa-pasta/validation.md`, `?? .specs/features/spa-portabilidade/`, `?? .specs/features/spa-troca/`) e depois do sensor: **idêntico** (`diff` sem saída). A cópia ficou em `tmp/sensor2-spa-pasta/` (ignorada, `.gitignore:5`; o `.svelte-kit` dentro dela pertence a root e o `rm` não o removeu, como na iteração 1). O código real nunca foi mutado.

---

## Code Quality

| Principle | Status |
| --------- | ------ |
| Minimum code | ✅ O novo é o pedido: 3 actions Rails + jbuilders finas sobre `SetProgressQuery`, `collection_stats_for` e escopos de `WishlistItem` existentes; `createLoader` reutilizado pelas duas páginas |
| Surgical changes | ✅ No Rails mudam só `card_variants_controller.rb` e `routes.rb`; o front toca `nav-entries`, `motion`, `view-transition` e a página da carta nos pontos necessários |
| No scope creep | ✅ Sem histórico de preço, sem outra moeda, sem endpoint extra de desejos |
| Matches patterns | ✅ Controllers filhos de `Api::BaseController`, envelope `{ data }`, rota do `DELETE` igual à do `PUT`; no front `api.get`/`api.delete` e `notifySuccess`/`notifyError`. Menor: `desejos/+page.svelte` chama `removing.delete(id)` no `catch` **e** no `finally` (o do `catch` reabilita o botão antes do `tick()` que devolve o foco; parece deliberado, mas pede um comentário) |
| Spec-anchored outcome check (asserted values match spec) | ✅ 46/46 |
| Per-layer Coverage Expectation met (domain 1:1 ACs; routes happy+edge+error) | ✅ As três rotas têm happy, `401` e isolamento; o `DELETE` tem ainda `422`, `404` e `400 invalid_json` (`unwish_test.rb:184-192`) |
| Every test maps to a spec requirement - no unclaimed tests | ✅ Nos testes novos que li. Não abri `loader.svelte.test.ts` nem `require-session.test.ts` linha a linha (mapeiam SPAS-03..06 pelo nome) |
| Documented guidelines followed | `CLAUDE.md` do projeto: gates em série, `api.get` desempacotado, `fetch` só em `client.ts` (ESLint limpo), mensagens pt-BR |

SPAS-34: o spec registra a condição `focusLost()` e ela é testada (`page.test.ts:181-198`); F3 e F4 fechados.

---

## Edge Cases

- [x] Coleção vazia: `0`, `0`, `US$ 0,00` sem animar: `AnimatedNumber.test.ts:111-116` e `PastaSummary.test.ts:89`; sets por código: `progress_test.rb:126-127`.
- [x] Posse acima do `base_size`: limitada e `100%`: `progress_test.rb:150-152`.
- [x] `base_size` zero tratado como ausente: `progress_test.rb:136-138`.
- [x] `code` de set com caractere reservado codificado: `SetProgressRow.test.ts:35`.
- [x] `variant_code` com `:` e `card_number` reservado codificados no `DELETE` e no link: `unwish_test.rb:134-137`; `desejos/page.test.ts:147-159` (`tcgplayer%3A2`); `WishlistItem.test.ts:30-31`; `frontend/src/lib/cards/url.test.ts:50-55`.
- [x] Desejo já removido em outra aba → `200` comum: `unwish_test.rb:75-79` e `:88-89`.
- [x] Posse acima do alvo → "Atendido": `WishlistItem.test.ts:51` e `wishlist_test.rb:55-66` (3 de 2).
- [x] Desejo de variante ausente da fonte listado: o `GET /api/wishlist` não filtra por presença (`app/controllers/api/wishlist_controller.rb`, `WishlistItem.for_user(...).with_fulfillment`); sem teste dedicado.
- [x] Duas remoções em seguida, foco pela lista do momento: `desejos/page.test.ts:180-199`.
- [x] Ordem muda com a interpolação em curso sem reiniciar (mesmo valor): `AnimatedNumber.test.ts:75-81`.
- [x] Sair pelo casco com a pasta ou a lista aberta: segue o SPA-22 da fundação; **não verifiquei nesta rodada**; `page.test.ts:148` prova só que sem sessão a pasta não consulta a API.
- [x] Sessão expirada com a lista aberta e "Remover" → `401`/`session_changed` não mostra mensagem de erro: `desejos/page.test.ts:218-236` (o redirecionamento em si é do cliente da fundação).
- [x] Preço em moeda ≠ `USD` fora de `estimated_value` e `value`: `progress_test.rb:103-104`.
- [x] 85 sets a 360px sem scroll horizontal: `frontend/e2e/pasta.spec.ts:343,347` (todos os sets do catálogo importado, dois temas, 360px e 1280px).
- [x] `DELETE` com JSON malformado → `400 invalid_json`: `unwish_test.rb:191-192`.

---
## Gate Check

- **Gate command**: Front quick `docker compose run --rm --no-deps frontend sh -c "npm ci && npm run check && npm run lint && npm test -- --run"` (depois `docker compose restart frontend`, feito). Rails e e2e não foram rerodados (instrução do brief; confirmado que não mudaram).
- **Result (iteração 3)**: `check` e `lint` limpos; Vitest 59 arquivos, **859** testes, 0 falhas (858 + o caso novo do SPAS-34); `docker compose restart frontend` feito.
- **Gate da iteração 1 (herdado)**: Rails 1995 runs, 8204 assertions, 0 falhas, rubocop limpo, brakeman só com o aviso de calendário; e2e 193 passed.
- **Confirmação de que Rails/e2e não mudaram**: `git diff --stat 7002c44..HEAD -- app frontend/e2e test` vazio; o único arquivo de código/teste alterado desde a iteração 1 é `frontend/src/routes/pasta/desejos/page.test.ts` (só adições: 2 casos do SPAS-36 e 1 do SPAS-34).
- **Skipped tests**: nenhum.
- **Não rodado**: `docker build -f Dockerfile .`.

---

## Fix Plans

Nenhum aberto.

### Fechados

- **F1** (SPAS-36, 401/`session_changed`): coberto por `desejos/page.test.ts:218-236`; M3 morre.
- **F2** (SPAS-11 e SPAS-26): o spec editado fecha a precisão. Resíduo Info: o *Independent Test* da linha 116 do spec ainda diz "um quarto da coluna" sem a ressalva dos vãos (o AC, que manda, está preciso).
- **F3** (SPAS-34, condição `focusLost()` no spec): registrada em `spec.md:189`.
- **F4** (SPAS-34, teste da condição): coberto por `desejos/page.test.ts:181-198` (commit `6c2c357`); M7 morre.

---

## Requirement Traceability Update

| Requirement | Previous Status | New Status |
| ----------- | --------------- | ---------- |
| SPAS-01..46 (incl. 11, 26, 34 e 36) | Implemented / com gap nas iterações 1 e 2 | ✅ Verified |

Não editei `spec.md`. Residual Info (não bloqueia): *Independent Test* do SPAS-11 (spec linha 116) sem a ressalva dos vãos; cláusula "conteúdo anterior" do SPAS-6 sem asserção dedicada; `docker build` não rodado.

---

## Summary

**Overall**: ✅ Ready

**Spec-anchored check**: 46/46 ACs casam com o resultado do spec; 0 GAP; 0 spec-precision gaps
**Sensor**: iteração 3: M7 killed; M3 (iteração 2) killed; iteração 1: 4/5 com M3 vivo, depois morto; nenhum sobrevivente na versão atual
**Gate**: Rails 1995 e e2e 193 (iteração 1, inalterados: `git diff --stat 7002c44..HEAD -- app frontend/e2e test` vazio); Front quick desta iteração: `check` e `lint` limpos, Vitest 59 arquivos, **859** testes, 0 falhas

**What works**: API (`progress`, `wishlist`, `unwish`) isolada por usuário e com consultas constantes; páginas `/app/pasta` e `/app/pasta/desejos`; interpolação em centavos; foco após remoção (seguinte, anterior, h1, e sem roubar o foco já levado a outro controle); SPAS-46 provado.

**Issues found**: nenhum bloqueante.

**Next steps**: o supervisor commita `validation.md` e `spec.md`, e marca `spa-pasta` como encerrada.
