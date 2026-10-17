# Pasta e lista de desejos na SPA (`spa-pasta`) — Validação

**Veredito**: PASS
**Data**: 2026-10-11
**Spec**: `.specs/features/spa-pasta/spec.md` (SPAS-01..46 e Edge Cases, na versão de `8c89d5f`, com as emendas de SPAS-11, 26 e 34)
**Diff range desta iteração**: `8c89d5f..9e0b095` (HEAD): `80baee3` (T18) e `9e0b095` (T19), 4 arquivos de `frontend/` (`WishlistItem.svelte`, `WishlistItem.test.ts`, `AnimatedNumber.test.ts`, `e2e/pasta-desejos.spec.ts`) mais os checkboxes de `tasks.md` e `.context/tasks.md`. Nenhum arquivo de `app/` ou `test/` mudou
**Verifier**: sub-agente independente (autor ≠ verificador; não escreveu código, teste nem spec desta feature, nem as iterações 1–4 deste relatório)
**Iteração**: 5 (re-verificação das duas correções da iteração 4)

## Validation: spa-pasta - PASS ✅

Resumo: os 2 GAPs da iteração 4 estão fechados no HEAD `9e0b095`, com evidência `arquivo:linha` e mutantes mortos. **SPAS-30**: o `<code>{variantCode}</code>` está dentro do `<a>` (`WishlistItem.svelte:39`), o nome acessível do link é "Luffy tcgplayer:1" e o e2e de paridade compara o texto do link inteiro sem normalizar o `<code>`. **SPAS-12/13**: um teste novo amostra o valor a 80 ms e a 240 ms e prova a curva `--ease-standard`; o F4 (linear), que sobrevivia, agora morre. Os 44 ACs restantes foram reconferidos por amostragem e não mudaram. Gate verde: Rails 1995/0, rubocop limpo, Front quick 860/860 (`svelte-check` 0/0, lint limpo), e2e 193/193 numa rodada só, sem flake.

---

## Histórico das iterações

- **Iteração 1** (outro Verifier): FAIL. SPAS-36 sem teste (mutante M3 vivo) e SPAS-11/26 imprecisos no spec.
- **Iteração 2** (outro Verifier): FAIL. A condição de foco do SPAS-34 sem teste (M7 vivo).
- **Iteração 3** (outro Verifier): PASS, com M3 e M7 mortos por `769c7d5` e `6c2c357`.
- **Iteração 4** (este relatório, segunda verificação independente, em paralelo com as 1–3): FAIL só Minor. SPAS-30: o link do item da lista de desejos não tinha o `variant_code` (o teste travava o desvio e o e2e normalizava o `<code>` do HTML). SPAS-12: o mutante F4 (curva linear no lugar de `easeStandard`) sobrevivia. 23 de 24 mutantes mortos no HEAD `8c89d5f`. Gate verde em `8c89d5f` (Rails 1995/0, rubocop limpo, Vitest 859/859, e2e 193 cobertos em várias rodadas por causa de `npm ci` concorrente). Fix 1 = T18, Fix 2 = T19.
- **Iteração 5** (esta): T18 e T19 confirmadas no HEAD `9e0b095`; PASS.

### Concorrência (iteração 4, mantida como registro)

Esta verificação começou com o HEAD em `945fdcd`. Enquanto ela corria, outro processo fez, na mesma árvore e nos mesmos containers: as iterações 1–3; os commits `769c7d5`, `6c2c357` e `8c89d5f`; as emendas de SPAS-11, 26 e 34 no `spec.md`; e várias rodadas de `npm ci` + `docker compose restart frontend`. Isso derrubou duas rodadas de e2e (`Cannot find module …/playwright/lib/worker/workerProcessEntry.js`, `ERR_CONNECTION_REFUSED http://frontend:5173`), que foram repetidas até cobrir os 193. Não era falha de produto. **Nesta iteração 5 não houve concorrência**: antes de cada `npm ci` e do e2e, `docker ps` não mostrava nenhum `e2e-run` (os containers `bindr-tcg-spa-decks-*` são de outro projeto compose e foram ignorados); todos os gates rodaram em série e o e2e passou em uma rodada só.

---

## Task Completion

| Task | Status | Notes |
| ---- | ------ | ----- |
| T1–T17 | ✅ Done | Todos os checkboxes de `tasks.md` marcados. T7 registrou o reuso de `variantApiPath(…, 'wishlist')` no lugar de `variantWishlistPath`; T12 registrou um `<button>` próprio no lugar de `Button`. |
| T18 | ✅ Done | `80baee3`: `<code>` dentro do `<a>`, teste e e2e ajustados (checkbox marcado em `tasks.md` e `.context/tasks.md`). |
| T19 | ✅ Done | `9e0b095`: teste da curva em `AnimatedNumber.test.ts:146-163`. |

---

## Spec-Anchored Acceptance Criteria

Convenção: `arquivo:linha` – asserção. Vitest sob `frontend/src/`, e2e sob `frontend/e2e/`, Rails sob `test/integration/api/`. Os números de linha são do HEAD `9e0b095` para os arquivos tocados por T18/T19 (`WishlistItem.*`, `AnimatedNumber.test.ts`, `pasta-desejos.spec.ts`); para os demais, valem os de `8c89d5f`, que não mudaram (`git diff 8c89d5f..HEAD --stat` só lista os 4 arquivos de frontend acima e os dois `tasks.md`). Linhas marcadas **[it.5]** foram reescritas nesta iteração; as outras foram reconferidas por amostragem (SPAS-01, 03, 17, 24, 33, 34, 37, 43, 46: asserções e linhas conferidas contra o HEAD, sem mudança).

### P1: Pasta em `/app/pasta` (SPAS-01..07)

| AC | Resultado definido no spec | Evidência | Result |
|---|---|---|---|
| 01 | `<title>` "Minha pasta — Bindr", h1 "Minha pasta" | `routes/pasta/page.test.ts:135-136` – `getByRole('heading',{level:1,name:'Minha pasta'})`, `document.title` `toBe('Minha pasta — Bindr')`; `e2e/pasta.spec.ts:318` – `toHaveTitle('Minha pasta — Bindr')` | ✅ |
| 02 | "Minha pasta" → `/app/pasta` sem recarga; `aria-current="page"` com qualquer query | `lib/navigation/nav-entries.test.ts:34-41` – `toEqual({ kind:'link', label:'Minha pasta', href:'/app/pasta', reload:false })`; `lib/components/MainNav.test.ts:73-84` – `it.each(['/app/pasta','/app/pasta?order=code'])` `toHaveAttribute('aria-current','page')`; `:86-93` ausente em `/app/pasta/desejos`; `e2e/pasta.spec.ts:302-325` – clique no casco, URL `/app/pasta`, `aria-current` | ✅ |
| 03 | Anônimo → `/app/entrar?return_to=<caminho+query codificados>` sem `GET` | `lib/navigation/require-session.test.ts:22-26` – `status` 307, `location` `'/app/entrar?return_to=%2Fapp%2Fpasta%3Forder%3Dcode'`; `routes/pasta/page.test.ts:100-110` – mesmo `location` e `apiMock.get` `not.toHaveBeenCalled()`; `routes/pasta/desejos/page.test.ts:52-62` – `'%2Fapp%2Fpasta%2Fdesejos'`; `e2e/pasta.spec.ts:295,298` – `return_to` `'/app/pasta?order=code'`, `calls` `toEqual([])`. Mutante F3 morre | ✅ |
| 04 | `GET /api/progress`, repassando só `order` quando existe | `routes/pasta/page.test.ts:144-145` – 1 chamada, `toHaveBeenCalledWith('/api/progress')`; `:161` – `'/api/progress?order=code'` | ✅ |
| 05 | Resposta de URL antiga descartada sem alterar a tela | `lib/api/loader.svelte.test.ts:72-88` – `toMatchObject({ result: null, pending: true, seq: 0 })` depois da resposta velha; `:90-101` idem para erro. Mutante F1 morre por `:72-88`. **Info**: o teste de página `routes/pasta/page.test.ts:164-178` **não** discrimina sozinho (F1b sobrevive a ele: a asserção roda após um único `await Promise.resolve()`); a cobertura vem do teste do carregador | ✅ |
| 06 | > 200 ms: `aria-busy="true"` + "Carregando pasta…"/"…lista de desejos…"; até lá, conteúdo anterior | `routes/pasta/page.test.ts:180-192` – ausente antes, `getByText('Carregando pasta…')` e `[aria-busy="true"]` após 250 ms; `routes/pasta/desejos/page.test.ts:94-109` – `aria-busy` `'false'`→`'true'`→`'false'`; `lib/api/loader.svelte.test.ts:49-70` – `slow` `false` em 199 ms, `true` em 200, `result` `'antigo'` mantido. Mutante F2 morre. **Info de precisão**: o spec diz "exibir", e o texto é `.visually-hidden` (`routes/pasta/+page.svelte:60`); sem skeleton, a carga lenta não tem sinal visual | ✅ |
| 07 | Erro ≠ 401: `message` como veio + "Tentar novamente" que repete; 401 segue SPA-09 | `routes/pasta/page.test.ts:194-207` – `findByText('Algo deu errado. Tente de novo.')`, clique, `apiMock.get` 2×, mensagem some; `routes/pasta/desejos/page.test.ts:111-119`; 401 da carga é do cliente da fundação (`onUnauthenticated`) | ✅ |

### P1: Indicadores (SPAS-08..11)

| AC | Resultado definido no spec | Evidência | Result |
|---|---|---|---|
| 08 | Três cartões na ordem; plurais "carta(s) na pasta", "carta(s) diferente(s)"; "valor estimado" | `lib/components/PastaSummary.test.ts:50-57` – `toEqual([…'10 cartas na pasta', …'4 cartas diferentes', …'US$ 1.234,56 valor estimado'])`; `:59-70` – 0/1/2 | ✅ |
| 09 | "1 cópia sem preço"/"N cópias sem preço"; omitida com zero | `PastaSummary.test.ts:72-78` – `toContain(note)` com 1 e 2; `:80-83` – `not.toContain('sem preço')` | ✅ |
| 10 | `"0.00"` → `US$ 0,00` | `PastaSummary.test.ts:85-90` – `toContain('US$ 0,00 valor estimado')` | ✅ |
| 11 | ≥ 64rem: um quarto da coluna descontados os vãos (`repeat(4, 1fr)`), sem esticar | `e2e/pasta.spec.ts:354-380` – `Math.abs(width - quarter)` `≤ 1` com `quarter = (coluna − 3·gap)/4`; CSS `lib/components/PastaSummary.svelte:69-73` | ✅ |

### P1: Número interpolado (SPAS-12..16)

| AC | Resultado definido no spec | Evidência | Result |
|---|---|---|---|
| 12 | Primeira exibição: de 0 ao valor em `--duration-slow` (320 ms) **com a curva `--ease-standard`** | Duração: `lib/components/AnimatedNumber.test.ts:51-69` – `'0'` em 0 ms, `0 < mid < 42` em 160 ms, `'42'` em 360 ms; F5 e F13 morrem. **[it.5] Curva**: `AnimatedNumber.test.ts:146-163` – com `value: 1000`, `format: String`, relógio falso, a 80 ms (t = 0,25) o visível está entre 550 e 680 (`:156-157`; `easeStandard(0,25) ≈ 0,64`, a linear daria 250) e a 240 ms (t = 0,75) entre 930 e 1000 (`:161-162`); a curva vem de `lib/motion.ts:28` (`cubicBezier(0.2, 0, 0, 1)`, já conferida contra `tokens.css` em `motion.test.ts`) e é passada em `AnimatedNumber.svelte:19`. F4 (linear) e F4b (ease-in quadrático) morrem | ✅ |
| 13 | Mudança de valor anima do exibido ao novo, mesma duração/curva; mesmo valor não anima | `AnimatedNumber.test.ts:71-92` – `'US$ 10,00'` estável após `rerender` com o mesmo valor; intermediário ≠ 10,00 e ≠ 12,50; final `'US$ 12,50'`; `:119-136` – retarget no meio; `PastaSummary.test.ts:100-123` – intermediário em centavos (`not.toMatch(/,00$/)`). F9 (interpolar em dólares) morre. A curva é a do SPAS-12 (mesmo `tween.set`, `AnimatedNumber.svelte:19`) e agora tem prova (`AnimatedNumber.test.ts:146-163`) | ✅ |
| 14 | Reduced motion: direto no valor final | `AnimatedNumber.test.ts:94-98` – primeiro quadro `'US$ 12,50'`; `e2e/pasta.spec.ts:498-512` – todo quadro amostrado `toEqual(finals)` com `reducedMotion: 'reduce'` | ✅ |
| 15 | Intermediários fora da árvore de a11y; texto acessível = final + rótulo; sem região viva | `AnimatedNumber.test.ts:146-151` – `.number` `aria-hidden="true"`, `[aria-live]` e `[role="status"]` nulos; `PastaSummary.test.ts:92-98` – `accessibleText(first)` `toBe('10 cartas na pasta')`; `AnimatedNumber.test.ts:59,65,88` – `.visually-hidden` já com o final durante a animação | ✅ |
| 16 | Formato igual ao final, algarismos tabulares, sem deslocar; termina exatamente no `amount` | `AnimatedNumber.test.ts:138-144` – `'US$ 1.234,56'`; `:153-156` – `font-variant-numeric: tabular-nums`; `:100-109` – reserva `aria-hidden` com o texto final; `e2e/pasta.spec.ts:478-494` – largura de cada cartão varia ≤ 0,5 px durante a animação e o último quadro `toEqual(finals)` | ✅ |

### P1: Progresso por set (SPAS-17..23)

| AC | Resultado definido no spec | Evidência | Result |
|---|---|---|---|
| 17 | Chips "Recentes"/"Por código" na lista "Ordenar sets", hrefs `?order=recent`/`code`, sem recarga, `aria-current` por `data.order` | `routes/pasta/page.test.ts:209-223` – URL `?order=xyz`, `recent` `aria-current="page"`, `byCode` sem, hrefs exatos, `data-sveltekit-reset="false"`. F8 (marcar pela query) morre | ✅ |
| 18 | Sets na ordem de `data.sets`, lista nomeada "Progresso por set", sem contagem | `routes/pasta/page.test.ts:225-235` – `findByRole('list',{name:'Progresso por set'})`, `OP02` antes de `OP01`, `queryByText(/\b2 sets\b/)` ausente; `e2e/pasta.spec.ts:229-266` – sequência e números de cada linha `toEqual` os da `/progress` para os dois usuários e as duas ordens | ✅ |
| 19 | `code` em `<code>`, nome como link `/app?sets[]=<code codificado>`, nome acessível "<name> (<code>): ver no catálogo" | `lib/components/SetProgressRow.test.ts:25-31` – `getByRole('link',{name:'Romance Dawn (OP01): ver no catálogo'})`, `href '/app?sets[]=OP01'`; `:33-36` – `'/app?sets[]=A%26B%231'` | ✅ |
| 20 | "<owned> / <base> · <pct>%", `<progress aria-hidden value max>`, legenda "<owned> de <base> do set base" | `SetProgressRow.test.ts:38-46` – texto, `aria-hidden`, `value="3"`, `max="7"`, legenda | ✅ |
| 21 | Sem `base_size`: só `owned_numbers`, sem barra nem %, frase de indisponível | `SetProgressRow.test.ts:48-59` – `progress` nulo, sem `%`, `getByText('5')`, frase exata | ✅ |
| 22 | "parallel" com total 1, "parallels" nos demais (inclusive 0), irmão do percentual | `SetProgressRow.test.ts:61-70` – `'1 de 1 parallel'` e `'0 de 2 parallels'` em `<p>`, `not.toContainElement` nos dois sentidos. O caso total = 0 não tem teste unitário (F11 sobrevive ao Vitest), mas **morre no e2e** de paridade `e2e/pasta.spec.ts:250` (`"0 de 0 parallels"` × `"0 de 0 parallel"`): 73 dos 85 sets do banco de dev não têm parallel | ✅ |
| 23 | "valor" + `US$ 1.234,56`, inclusive `US$ 0,00` | `SetProgressRow.test.ts:72-78` | ✅ |

### P1: Ações da pasta (SPAS-24..26)

| AC | Resultado definido no spec | Evidência | Result |
|---|---|---|---|
| 24 | "Adicionar cartas à pasta" → `/app` sem recarga; fixa acima da barra < 64rem sem cobrir o fim; lateral abaixo do divisor com "Adicionar cartas" ≥ 64rem | `routes/pasta/page.test.ts:237-254` – `href '/app'` sem `data-sveltekit-reload`; `:256-267` – `shell.aside` preenchido e `null` ao desmontar; `e2e/pasta.spec.ts:383-407` – texto `'Adicionar cartas'`, `inAside`, `border` 1, não fixa, `belowDivider`; `:411-436` – `position` `fixed`, acima da barra, último set acima da ação, `toBeInViewport({ ratio: 1 })` | ✅ |
| 25 | CSV `/collection/export` e Importar `/collection/import` com página inteira; Lista de desejos `/app/pasta/desejos` sem recarga; grupo separado | `routes/pasta/page.test.ts:241-253` – hrefs e `data-sveltekit-reload` exatos | ✅ |
| 26 | Composição da `/progress` a 390/1280 px; sem scroll horizontal a 360 px; capturas geradas pelo e2e, comparação pelo dono | `e2e/pasta.spec.ts:333-350` – `scrollWidth ≤ clientWidth` em 360/1280 × claro/escuro × duas ordens; `:517-` gera as capturas (comparação visual: dono) | ✅ |

### P1: Lista de desejos (SPAS-27..36)

| AC | Resultado definido no spec | Evidência | Result |
|---|---|---|---|
| 27 | `<title>` "Lista de desejos — Bindr", h1, `GET /api/wishlist` | `routes/pasta/desejos/page.test.ts:85-92`; `e2e/pasta-desejos.spec.ts:193`; sem scroll a 360 px `:231-249` | ✅ |
| 28 | Vazio: as duas frases, "catálogo" como link para `/app` | `desejos/page.test.ts:121-132` – link `href '/app'` e `textContent` exato da frase | ✅ |
| 29 | "1 item"/"N itens", ordem de `data` | `desejos/page.test.ts:134-146`; `e2e/pasta-desejos.spec.ts:203-205` – `spa.count` = `html.count`, `spa.rows` `toEqual(html.rows)` | ✅ |
| 30 | `card_name` e `variant_code` (em `code`) **como um link** para `/app/cartas/<card_number codificado>`; "N de M cópia(s)" | **[it.5]** `lib/components/WishlistItem.svelte:39` – `<a href={cardDetailHref(cardNumber)}>{cardName} <code>{variantCode}</code></a>` (o `<code>` está dentro do `<a>`); `lib/components/WishlistItem.test.ts:23` – `getByRole('link', { name: 'Luffy tcgplayer:1' })`, `:24` – `href '/app/cartas/OP01-001'`, `:25-27` – o `<code>` é `CODE` e `expect(link).toContainElement(code)`; `:32` – o href codificado `'/app/cartas/A%2FB%3FC'` pelo mesmo nome; plural em `WishlistItem.test.ts:38-47` (`'1 de 1 cópia'`, `'0 de 2 cópias'`). e2e de paridade **sem normalizar o `<code>`**: `e2e/pasta-desejos.spec.ts:127-128` (SPA: `name` = texto do `<a>` inteiro, `code` = `a code`) × `:146-151` (HTML: `link = .wishlist-item__link`, `name: squash(link?.textContent)`, `code: link?.querySelector('code')`; sem o `cloneNode`/`remove()` de antes), comparados com `toEqual` em `:203-205`. F16 (inverso: `<code>` fora do `<a>`) quebra 2 testes de Vitest e o e2e de paridade (`pasta-desejos.spec.ts:186`) | ✅ |
| 31 | "Atendido" com `fulfilled`, senão "Faltam N" (N = alvo − posse) | `WishlistItem.test.ts:49-59`; `e2e/pasta-desejos.spec.ts:206` – `['Atendido','Faltam 2','Faltam 2']`. **Info**: o componente deriva o estado de `owned`/`target` (`WishlistItem.svelte:27-28`) e não lê o `fulfilled` do payload; é equivalente pela regra da API (`owned >= target`) | ✅ |
| 32 | Botão "Remover" ≥ 44 px, nome "Remover <name> <code> da lista de desejos (atendido)"/"(faltam N)" | `WishlistItem.test.ts:61-75` (nomes exatos), `:77-81` (`min-block-size`/`min-inline-size: var(--touch-target)`) | ✅ |
| 33 | `DELETE` (SPAS-43); com 200 tira o item, atualiza a contagem e anuncia "Item removido da lista de desejos." | `desejos/page.test.ts:148-160` – `apiMock.delete` com `'/api/cards/OP01-002/variants/tcgplayer%3A2/wishlist'`, `'2 itens'`, `notifySuccess('Item removido da lista de desejos.')`; `e2e/pasta-desejos.spec.ts:261-271`. F12 e F15 morrem | ✅ |
| 34 | Foco: seguinte; senão anterior; lista vazia, h1; só quando o foco ficou no `body` | `desejos/page.test.ts:162-179` (`:168`, `:172`, `:177`); `:181-198` (`:196-197`, foco já movido não é roubado); `e2e/pasta-desejos.spec.ts:263-266,291,295`. F6 e F14 morrem | ✅ |
| 35 | Pendente: só o botão do item desabilitado, novo acionamento ignorado | `desejos/page.test.ts:200-219` – `toBeDisabled()`, clique forçado não chama o cliente (`toHaveBeenCalledTimes(1)`), item 3 `toBeEnabled()` e conclui; `WishlistItem.test.ts:90-97`. F7 morre | ✅ |
| 36 | Falha mantém o item e mostra a `message`; 401/sessão trocada seguem SPA-09/10 | `desejos/page.test.ts:221-237` – `notifyError('Algo deu errado. Tente de novo.')`, `'3 itens'`, foco de volta; `:239-` – `it.each` 401 e `session_changed`: `notifyError` `not.toHaveBeenCalled()` (`:251`). F10 morre no HEAD (sobrevivia antes de `769c7d5`) | ✅ |

### P1: API da pasta e da lista de desejos (SPAS-37..46)

| AC | Resultado definido no spec | Evidência | Result |
|---|---|---|---|
| 37 | `200` `{ data: { order, summary, sets } }` da coleção da sessão | `test/integration/api/progress_test.rb:39-44` – `:ok` e `application/json`; `:50-81` – dois usuários contra `collection_stats_for` e `SetProgressQuery` | ✅ |
| 38 | `order` ausente/xyz/vazio/lista → `recent`; `code` → `code` | `progress_test.rb:107-112` – os quatro casos `assert_equal "recent"`; `:114-128` – `"code"` e `%w[OP01 OP09]`. R2 morre | ✅ |
| 39 | `summary` com os 4 campos, `{amount, currency:"USD"}`, iguais ao HTML | `progress_test.rb:68-70` – `assert_equal({…}, data["summary"])`; `:83-93` – `0.00` e `unpriced_copies` 1; `:95-105` – EUR fora | ✅ |
| 40 | Campos de `sets`; `base_size` nulo se ausente/zero; % inteiro meio para cima, ≤ 100, nulo sem base; `value` `"0.00"` | `progress_test.rb:72-79`; `:130-140` – `assert_nil` `base_size` e `completion_percent` (nulo e zero); `:142-153` – 1/1/100; `:155-165` – 13 e 88. R1 e R5 morrem | ✅ |
| 41 | Consultas constantes com sets, variantes e itens | `progress_test.rb:167-178` – `assert_equal baseline, count_queries { progress }` após +18 sets e +9 itens | ✅ |
| 42 | `GET /api/wishlist`: campos, `owned_quantity` 0, `fulfilled`, ordem por criação e id, consultas constantes | `test/integration/api/wishlist_test.rb:46-66` – lista exata (0/2 falso, 3/2 e 2/2 verdadeiros); `:68-72` – `[]`; `:90-98` – `count_queries` igual com 1 e 10. R6 morre. **Info**: desempate por `id` com `created_at` igual sem teste (achado já registrado na T2) | ✅ |
| 43 | `DELETE` apaga o do usuário e responde `200 { data: { variant_code, wishlist_target: null } }`; sem desejo, o mesmo 200 | `test/integration/api/card_variants_unwish_test.rb:58-69` – `assert_difference … -1`, `assert_equal REMOVED`; `:71-80` – `assert_no_difference` + mesmo corpo; `:82-91` – repetir; `:128-138` – `tcgplayer:456` com `:` codificado e `P.029`; `e2e/pasta-desejos.spec.ts:252-282` | ✅ |
| 44 | Carta inexistente ou variante de outra carta → `404 not_found`, sem apagar | `card_variants_unwish_test.rb:140-149`, `:151-160` – `assert_no_difference`, `:not_found`, `assert_equal NOT_FOUND` | ✅ |
| 45 | Sem sessão 401; sem CSRF 422; só `Current.user`; `user_id` ignorado | `progress_test.rb:180-186,188-197`; `wishlist_test.rb:74-88,100-106`; `card_variants_unwish_test.rb:93-103,105-116` (outro usuário intacto, `user_id` no corpo e na query), `:162-171` (401 sem apagar), `:173-182` (422 com `allow_forgery_protection` ligado no `setup`, `:9-10`). R3 e R4 morrem | ✅ |
| 46 | Controllers e rotas HTML inalterados; suíte existente sem edição | `git diff --name-status 8e6c92d..HEAD -- test/` = 3 × `A`; `git diff --stat 8e6c92d..HEAD -- app/views/progress app/views/wishlist_items app/controllers/progress_controller.rb app/controllers/wishlist_items_controller.rb` vazio; `config/routes.rb` só ganhou 3 linhas dentro do `scope "api"`, acima do catch-all; Rails 1995/0 | ✅ |

**Status**: ❌ 44/46 com evidência que bate com o spec; 1 GAP (SPAS-30) e 1 GAP de sensor (SPAS-12, curva); 0 spec-precision gaps bloqueantes (Info: "exibir" do SPAS-06 com texto só para leitor de tela).

**Payload/conjunção**: as asserções de API comparam o corpo inteiro (`assert_equal REMOVED`, `assert_equal [ {…} ], wishlist`, `assert_equal({…}, data["summary"])`), não só o status. No front, `apiMock.delete` é conferido pelo caminho exato e o toast pelo texto exato. As conjunções do spec (item some **e** contagem atualiza **e** anuncia, SPAS-33; desabilitado **e** ignora **e** os outros acionáveis, SPAS-35) têm uma asserção por termo.

---

## Discrimination Sensor

Nível expandido. **Cópia** de `frontend/` em `tmp/sensor-it5/` (sem `build/`, `test-results/`; `npm ci` próprio dentro da cópia, num container `node:24.21.0-slim` descartável). Vitest: `docker run --rm -v <cópia>:/f -w /f node:24.21.0-slim npx vitest --run <arquivo>`; a baseline da cópia passou antes (245/245 em `src/lib/components`). e2e: um Vite da cópia (`sens-vite`) na rede `bindr-tcg-svelt-front_default` e o Playwright 1.64.0 com `--add-host frontend:<ip>`; baseline da cópia `pasta-desejos.spec.ts` 8/8 antes do mutante. Nenhum `git worktree`, `git stash` ou git de escrita. A cópia foi apagada ao fim (`ls tmp` sem `sensor-it5`) e o container `sens-vite` foi parado.

Mutantes desta iteração (nos arquivos tocados por T18/T19):

| # | Arquivo:linha (cópia) | Mutação | Camada | Killed? |
|---|---|---|---|---|
| **F4** | `AnimatedNumber.svelte:19` | `easing: easeStandard` → `(t) => t` | Vitest | ✅ (1 falha: o teste `segue a curva --ease-standard…`) |
| F4b | `AnimatedNumber.svelte:19` | `easing: (t) => t * t` (ease-in) | Vitest | ✅ (1 falha) |
| F13 | `AnimatedNumber.svelte:18` | `duration(320)` → `duration(500)` | Vitest | ✅ (5 falhas) |
| F5 | `AnimatedNumber.svelte:14` | nasce no valor final (não conta de zero) | Vitest | ✅ (4 falhas) |
| F9 | `PastaSummary.svelte` | interpola em dólares, não em centavos | Vitest | ✅ (1 falha) |
| **F16** (inverso) | `WishlistItem.svelte:39` | `<code>` fora do `<a>` | Vitest | ✅ (2 falhas: nome acessível e `toContainElement`) |
| F16-e2e | idem | idem | e2e | ✅ (`pasta-desejos.spec.ts:186` paridade, 1 falha) |
| M-no-code | `WishlistItem.svelte:39` | remove o `<code>` do link | Vitest | ✅ (2 falhas) |
| M-aria-label | `WishlistItem.svelte:47` | tira o `variantCode` do `aria-label` do botão | Vitest | ✅ (1 falha) |
| M-seletor-e2e | `pasta-desejos.spec.ts:128` | `li.querySelector('a code')` → `li.querySelector('code')` | e2e | ⚠️ sobrevive **com o código correto**, e é equivalente: com o `<code>` dentro do `<a>` os dois seletores acham o mesmo nó. O desvio que importa é o F16-e2e, que morre pela comparação do `name` (o `textContent` do `<a>` perde o código) e pelo seletor `a code` vazio |

Mutantes das iterações 1–4 não tocados por T18/T19 (`loader.svelte.ts`, `require-session.ts`, `desejos/+page.svelte`, `SetProgressRow.svelte`, `progress_test.rb` e afins): arquivos **sem mudança** entre `8c89d5f` e o HEAD (`git diff --stat 8c89d5f..HEAD -- app test frontend/src` só lista os 3 arquivos de T18/T19); o resultado da iteração 4 (23/24 mortos, F4 sobrevivente) vale para eles, e o F4 está agora morto. Total: **todos os 24 mutantes de comportamento da iteração 4 estão mortos no HEAD** (F11 só pelo e2e de paridade, como antes).

**Resultado do sensor**: ✅ 0 sobreviventes de comportamento.

**Isolamento**: `git status --porcelain` antes e depois do sensor idêntico (`M .specs/LESSONS.md`, `M .specs/features/spa-pasta/validation.md`, `M .specs/lessons.json`, `?? .playwright-mcp/`, `?? .specs/features/spa-portabilidade/`, `?? .specs/features/spa-troca/`); as mutações só existiram na cópia, e `diff -rq` de `src` e `e2e` da cópia contra `frontend/` ficou vazio depois dos mutantes.

---

## Code Quality

| Princípio | Status |
|---|---|
| Código mínimo | ✅ 3 actions finas sobre `SetProgressQuery`, `collection_stats_for` e `WishlistItem.for_user(…).with_fulfillment`; `createLoader` usado pelas duas páginas; T18 mexeu em 1 linha do componente |
| Mudança cirúrgica | ✅ Rails: só `card_variants_controller.rb` (+5) e `routes.rb` (+5) em arquivos existentes; T18/T19: 4 arquivos de frontend |
| Sem scope creep | ✅ |
| Segue os padrões | ✅ `Api::BaseController`, envelope `{ data }`, rota do `DELETE` com as constraints do `PUT`; ⚠️ desvios conscientes registrados (T7 reuso de `variantApiPath`, T12 `<button>` próprio) |
| Outcome ancorado no spec | ✅ SPAS-30 e SPAS-12 agora afirmam o que o spec define |
| Cobertura por camada | ✅ O e2e de paridade não normaliza mais o `<code>`; a curva do SPAS-12 é observável por teste |
| Testes mapeados a ACs | ✅ |
| Diretrizes | `CLAUDE.md` do projeto: `fetch` só em `client.ts` (lint limpo), `api.get` desempacotado, mensagens pt-BR |

Menor (sem bloqueio): `desejos/+page.svelte:69,74` chama `removing.delete(id)` no `catch` e no `finally`; é deliberado (reabilita o botão antes do `tick()` que devolve o foco) e pede um comentário. O teste da curva usa janelas (550–680 e 930–1000) em vez de valores exatos: robusto contra arredondamento, e discrimina linear e ease-in.

---

## Edge Cases

- [x] Coleção vazia → `0`, `0`, `US$ 0,00` sem animar: `AnimatedNumber.test.ts:111-117`, `PastaSummary.test.ts:85-90`.
- [x] Posse acima do `base_size` → limitada e 100%: `progress_test.rb:142-153`.
- [x] `base_size` zero = ausente: `progress_test.rb:130-140`.
- [x] `code` com caractere reservado: `SetProgressRow.test.ts:33-36`.
- [x] `variant_code` com `:` e `card_number` reservado no `DELETE` e no link: `card_variants_unwish_test.rb:128-138`, `desejos/page.test.ts:154-156`, `lib/cards/url.test.ts`, `WishlistItem.test.ts:30-36`.
- [x] Desejo já removido em outra aba → 200 comum: `card_variants_unwish_test.rb:71-91`.
- [x] Posse acima do alvo → "Atendido": `WishlistItem.test.ts:49-59`, `wishlist_test.rb:46-66`.
- [x] Variante ausente da fonte listada: o endpoint não filtra presença (`app/controllers/api/wishlist_controller.rb:6`); sem teste dedicado (Info).
- [x] Duas remoções seguidas: `desejos/page.test.ts:200-219`.
- [x] Troca de ordem sem mudar o valor não reinicia a animação: `AnimatedNumber.test.ts:77-81`.
- [x] Sessão expirada e "Remover" → 401 sem toast de erro: `desejos/page.test.ts:239-`.
- [x] Moeda ≠ USD fora: `progress_test.rb:95-105`.
- [x] 85 sets a 360 px sem scroll: `e2e/pasta.spec.ts:333-350`.
- [x] JSON malformado no `DELETE` → 400: `card_variants_unwish_test.rb:184-193`.
- [ ] Sair pelo casco com a pasta aberta (SPA-22): não verificado por teste desta feature (Info, herdado da iteração 4; é da fundação).

---

## Gate Check

Em série, por este Verifier, com a pilha de pé e sem nenhum container `e2e-run` alheio (`docker ps` conferido antes do `npm ci` e do e2e).

- **Rails**: `docker compose exec app bin/rails test` → **1995 runs, 8204 assertions, 0 failures, 0 errors, 0 skips** (126 s).
- **Rubocop**: `docker compose exec app bin/rubocop` → 263 arquivos, **no offenses**.
- **Front quick**: `docker compose run --rm --no-deps frontend sh -c "npm ci && npm run check && npm run lint && npm test -- --run"` → `svelte-check found 0 errors and 0 warnings`, lint limpo, **59 arquivos, 860/860** (859 + o teste da curva). Depois, `docker compose restart frontend`.
- **e2e**: `docker compose up -d app frontend && docker compose --profile e2e run --rm e2e` → **193 passed (5,3 min)**, uma rodada só, sem flake (o SPA-46 passou junto).
- **Contagem de testes**: Rails 1995 (sem edição de teste existente); Vitest 859 → 860 (+1, T19); e2e 193 (T18 só editou seletores).
- **Não rodados** (fora do pedido): `docker build -f Dockerfile .` e `bin/brakeman`.

---

## Fix Plans

Nenhum. Os Fix 1 (SPAS-30) e Fix 2 (SPAS-12/13) da iteração 4 foram entregues por T18 e T19 e confirmados acima.

---

## Requirement Traceability Update

| Requirement | Antes (iteração 4) | Agora |
|---|---|---|
| SPAS-01..11, 13..29, 31..46 | ✅ Verified | ✅ Verified |
| SPAS-12 | ❌ Needs Fix (Fix 2) | ✅ Verified (T19) |
| SPAS-30 | ❌ Needs Fix (Fix 1) | ✅ Verified (T18) |

Não editei `spec.md` nem `STATE.md` (fora da permissão desta verificação).

---

## Summary

**Overall**: ✅ Ready (PASS)

**Spec-anchored check**: 46/46; Info: SPAS-06 "exibir" com texto só para leitor de tela, SPAS-05 discriminado só no teste do carregador, `fulfilled` derivado no componente, SPA-22 sem teste desta feature.
**Sensor**: 0 sobreviventes de comportamento (F4 e F16 mortos; mutantes novos M-no-code, M-aria-label, F4b, F16-e2e mortos; o seletor do e2e é equivalente).
**Gate**: Rails 1995/0, rubocop limpo, Front quick 860/0, e2e 193/193 em uma rodada.

**O que funciona**: os três endpoints (contrato, isolamento por `Current.user`, CSRF, 404, consultas constantes), a pasta com paridade numérica com a `/progress`, o número interpolado (duração, curva, reduced motion, acessibilidade, largura estável), e a lista de desejos com o `variant_code` no link, remoção não otimista e foco.

**Próximo passo**: nenhum para a feature. `STATE.md` (*Handoff*) deve refletir o PASS da iteração 5 (fora do escopo deste Verifier).
