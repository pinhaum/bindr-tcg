# Navegação e layout das telas — Validação

**Date**: 2026-09-27
**Spec**: `.specs/features/navegacao/spec.md` (NAV-01..NAV-51, Success Criteria)
**Fonte de verdade**: `.context/requirements.md` Req. 4.9 e Req. 13.1–13.20 (AD-005)
**Diff range**: `dd3cafa..27971ed` (67 commits, `git log --oneline dd3cafa..HEAD`)
**Verifier**: sub-agente independente (autor ≠ verificador). Não escrevi nada desta feature.
**Fora do escopo desta validação**: semelhança com o canvas. A caixa "O dono comparou as capturas" da T33 está substituída pela feature `conformidade` (AD-016) de propósito e não conta como FAIL.

## Validation: navegacao — ❌ FAIL

O gate está verde e a maior parte dos critérios tem evidência discriminante: 35 de 45 mutantes foram mortos. Mesmo assim, o relatório fecha em FAIL por quatro motivos:

1. **10 mutantes sobreviveram.** Os testes não travam NAV-04 (detalhe), NAV-11 (set), NAV-18 (indicador renderizado), NAV-34 (× do chip de cor), NAV-35, NAV-38 (duas cláusulas), NAV-47 e NAV-49 (rótulos no HTML).
2. **Dois critérios são descumpridos pelo código atual**:
   - NAV-04 / Req. 13.2: "Entrar" e "Criar conta" não recebem `aria-current` na própria página.
   - NAV-36: com zero resultados, o único "Limpar filtros" perde a ordenação.
3. **Um Success Criterion está marcado com uma afirmação falsa**: os "sete testes que leem `catalog.css` sem edição". O `set_progress_plan_test.rb` foi editado em `6394755` sem justificativa registrada.
4. A rastreabilidade da spec ainda marca NAV-30..NAV-39 como `Pending`.

---

## Task Completion

| Task | Status | Notas |
|---|---|---|
| T1–T10 | ✅ Done | Checkboxes todos marcados; commits no range |
| T11 | ✅ Done | Revisão visual reprovada, virou a emenda NAV-30..39 (AD-013) |
| T12–T20 | ✅ Done | Histórico não atômico, confirmado (ver pendências herdadas) |
| T21 | ✅ Done | — |
| T22–T32 | ✅ Done | — |
| T33 | ✅ Done | Item do dono substituído pela `conformidade` (AD-016), fora do escopo |

Nenhum `- [ ]` aberto em `tasks.md`.

---

## Gate Check

- **full** (`docker compose exec -T app bin/rails test && bin/rubocop`, árvore real, HEAD `27971ed`): **1197 runs, 5155 assertions, 0 failures, 0 errors, 0 skips**. RuboCop: 156 arquivos, 0 ofensas.
- **build** (`DOCKER_CONFIG=<dir com {}> docker compose build`): imagem `bindr-tcg-app` construída sem erro.
- **Contagem antes da feature**: 951 runs (`tasks.md:158`). **Depois**: 1197. **Delta**: +246.
- **Testes existentes modificados no range** (`git diff --name-status --diff-filter=MD dd3cafa..HEAD -- test/`):
  - `wishlist_items_test.rb`: reescrita prevista na T5.
  - `collection_item_test.rb`: só acréscimo.
  - **`set_progress_plan_test.rb`: protegido.** Ver pendência P-1.
- Nenhum arquivo preexistente de `test/design/` foi editado.

---

## Spec-Anchored Acceptance Criteria

Legenda: ✅ PASS · ❌ GAP (sem evidência discriminante ou comportamento descumprido) · ⚠️ lacuna de precisão da spec.

### P1 Navegação principal

| Critério | Resultado exigido pela spec | Evidência | Resultado |
|---|---|---|---|
| NAV-01 | Um único `nav` principal em toda página, com "Catálogo" | `test/integration/navegacao_principal_test.rb:45` e `:53`: `assert_select "header.site-header nav[aria-label='Principal']", count: 1` (catálogo, pasta); `minha_pasta_test.rb:437` `assert_select "nav", count: 1` | ✅ (só duas páginas amostradas; o layout é único, `application.html.erb:29`) |
| NAV-02 | Com sessão: "Minha pasta" → `/progress` e "Sair" | `navegacao_principal_test.rb:68` (3 entradas), `:81` `a[href=progress_path]`, `:90-91` `form[action=session_path] button` | ✅ |
| NAV-03 | Sem sessão: "Entrar", "Criar conta" | `navegacao_principal_test.rb:105`, `:117`, `:124` | ✅ |
| NAV-04 | Entrada da página aberta com `aria-current="page"` e peso distinto | `navegacao_principal_test.rb:135`, `:141`, `:156-157`, `:175`, `:181`; `navigation_layout_test.rb:109` `refute_equal weight_value, body_weight` | ❌ **Dois problemas.** (a) M08 sobreviveu: nada impede o `aria-current` de vazar para o detalhe da carta. Era pendência de 2026-09-23 e continua aberta. (b) Defeito: em `/session/new` e `/registration/new`, "Entrar" e "Criar conta" são `link_to` simples (`application.html.erb:36-37`) e não recebem `aria-current`. Req. 13.2 diz "a entrada da página atual DEVE ser marcada". A T5 estreitou isso para Catálogo e Minha pasta (`tasks.md` T5, Done when 3) sem emendar a spec. A sonda M44, que corrige o defeito, também passa no gate: nenhum teste fixa um comportamento ou o outro. |
| NAV-05 | Abaixo de 1024px: fixa no pé, entradas ≥ 44px, reserva no fim do conteúdo | `navigation_layout_test.rb:48-50` (`fixed`, `bottom: 0`), `:60-63` (`to_pixels >= 44`), `:71` (`padding-bottom: var(--body-padding-bottom)`), `:34` (token) | ✅ (M23 morto) |
| NAV-06 | A partir de 1024px: coluna lateral à esquerda | `navigation_layout_test.rb:118-141`; `navigation_canvas_test.rb:90` `--body-grid-columns` | ✅ (M40 morto) |
| NAV-07 | Sem baralho, preço, cotação | `navegacao_principal_test.rb:198-242` (texto e `href`) | ✅ |

### P1 Filtrar a grade

| Critério | Resultado exigido pela spec | Evidência | Resultado |
|---|---|---|---|
| NAV-08 | Um controle por valor presente de cor, tipo e raridade, mais o `select` de set | `catalog_filter_controls_test.rb:77-97`; `test/queries/catalog_filter_options_test.rb:62-182` (`assert_equal [ "C", "L", "R", "SR", "UC" ]` etc., nulo fora em `:175`) | ✅ (M32 morto) |
| NAV-09 | A URL do controle dá o mesmo resultado da URL digitada | `catalog_filter_controls_test.rb:130` `assert_equal from_manual, from_chip`; `:146-147` (`"1 carta"`) | ✅ |
| NAV-10 | Preservar busca e filtros sem controle | `catalog_filter_controls_test.rb:191`, `:203-205`, `:212-213`, `:227-230`; `test/helpers/catalog_helper_test.rb:30-35`, `:68-73` | ✅ (M31 morto). `:220-221` só testa `include?("traits")`, uma checagem fraca. |
| NAV-11 | Controle ativo indicado por texto ou estado | Chips: `catalog_filter_controls_test.rb:152-158`. Set: **nenhuma** | ❌ M43 sobreviveu. Tirar o `selected` do set único ativo não derruba nada. A asserção existia ("set único ativo aparece selected no select") e caiu na reescrita da Fase 7, embora o set não tenha mudado de forma. |
| NAV-12 | Com sessão, posse "todas/tenho/não tenho" mapeada para `owned=all\|owned\|missing` | `catalog_ownership_filter_test.rb:61-63`, `:147-148` e `:169-170` (`assert_equal from_url, from_chip`, contagens exatas) | ✅ (M38 morto) |
| NAV-13 | Sem sessão, controle de posse não renderizado | `catalog_ownership_filter_test.rb:116`, `:123` `assert_empty ownership_chips` | ✅ (M09 morto) |
| NAV-14 | Sem JavaScript | `catalog_filter_controls_test.rb:296-297` (`[data-controller]`, `[data-action]` com `count: 0`); chips são `<a href>` (`:300-310`) | ✅ |
| NAV-15 | Cor sem preenchimento `accent`, anel de 2px `accent` | `test/design/filter_layout_test.rb:116-126` (`assert_equal "2px solid var(--accent)"`, exclusão `:not(.catalog__chip--color)`) | ✅ (M15 morto) |

### P1 Minha pasta

| Critério | Resultado exigido pela spec | Evidência | Resultado |
|---|---|---|---|
| NAV-16 | `h1` "Minha pasta", `h2` "Progresso por set" | `minha_pasta_test.rb:42-84` | ✅ |
| NAV-17 | Total de cópias igual ao `owned_total` do catálogo | `minha_pasta_test.rb:87-105`; `:164` `assert_equal pasta_total, catalog_total` | ✅ (M46 morto) |
| NAV-18 | Variantes distintas com quantidade ≥ 1 | `minha_pasta_test.rb:117-143` (`2 cartas diferentes`); `test/models/collection_item_test.rb:204-252` | ❌ M06 sobreviveu: tirar o `.owned` de `CollectionItem.collection_stats_for` (`app/models/collection_item.rb:89`) passa a contar variantes com quantidade 0 na tela, e nada falha. Os testes de modelo cobrem `distinct_variants_for` (`collection_item.rb:75`), que **nenhum código de produção chama**: a view usa `collection_stats_for` (`progress/index.html.erb:76`). E nenhum teste de integração cria um item com `quantity: 0`. |
| NAV-19 | Links para wishlist, import e export | `minha_pasta_test.rb:205-237` | ✅ (M37 morto) |
| NAV-20 | Zero cópias: os dois indicadores mostram 0 | `minha_pasta_test.rb:106-115`, `:135-143`, `:170-180` | ✅ |
| NAV-21 | Só o usuário da sessão, `user_id` do request ignorado | `minha_pasta_test.rb:182-192` | ✅ (M07 e M46 mortos, por outros testes do arquivo e pelo `set_progress_plan_test`). O teste `:182` em si é vazio: o "outro usuário" não tem item nenhum. |

### P2 Layout largo

| Critério | Resultado exigido pela spec | Evidência | Resultado |
|---|---|---|---|
| NAV-22 | ≥ 1024px: filtros em coluna ao lado da grade | `filter_layout_test.rb:78-90`; `catalog_subgrid_layout_test.rb:50-66` | ✅ (M36 morto) |
| NAV-23 | < 1024px: filtros acima da grade, em fluxo | `filter_layout_test.rb:26-60` | ✅ |
| NAV-24 | ≥ 1024px: arte ao lado dos dados | `card_detail_media_test.rb:62-103`; `detail_layout_test.rb:36-63` | ✅ |
| NAV-25 | Detalhe mantém campos e controles | `card_detail_layout_test.rb:17-52`; `card_detail_test.rb:40-68` (preexistente) | ✅ |

### P1 Telas no desenho do canvas (NAV-30..39)

| Critério | Resultado exigido pela spec | Evidência | Resultado |
|---|---|---|---|
| NAV-30 | Barra dividida em partes iguais; atual em `surface-sunken` sobre `surface-raised` | `navigation_canvas_test.rb:43`, `:50-55`, `:64-67` | ✅ (M30 morto) |
| NAV-31 | Coluna com `var(--sidebar-width)`, `surface-raised`, borda direita `border` | `navigation_canvas_test.rb:81`, `:90`, `:98-101` | ✅ (M35 morto) |
| NAV-32 | Filtros na coluna lateral, abaixo da navegação | `catalog_subgrid_layout_test.rb:50-57`, `:85-100`; `filters_toggle_layout_test.rb:37-39` | ✅ |
| NAV-33 | Link de alternância, sem `page`; "todas" remove `owned` | `catalog_helper_test.rb:4-66` (`assert_not_includes url, "page"` em `:40`); `catalog_filter_controls_test.rb:194-195` | ✅ (M01, M02 e M03 mortos) |
| NAV-34 | Ativo: "×" visível e nome "Remover filtro …" com o rótulo. Inativo: nome = rótulo | `catalog_filter_controls_test.rb:152-172`, `:192` | ❌ M41 sobreviveu: tirar o "×" do chip de **cor** ativo não derruba nada. `:156` aceita qualquer `span[aria-hidden]`, e a amostra de cor (`index.html.erb:156`) já é um. Ver também ⚠️ "Todas" abaixo. |
| NAV-35 | Chip de filtro com altura mínima de 44px | `filter_layout_test.rb:92-101`: `@stylesheet.include?("min-height: 44px")` na folha inteira | ❌ M14 sobreviveu: `.catalog__chip { min-height: 24px }` passa, porque outras regras da folha também têm `min-height: 44px`. É exatamente o `include?` solto apontado no Handoff de 2026-09-25. |
| NAV-36 | Contagem sempre; com filtro ativo, "N filtros ativos" e "Limpar filtros" que preserva só a ordenação | `catalog_status_line_test.rb:49`, `:65-71`, `:116-128` (sort/dir preservados), `:157-160` | ❌ **Defeito**: com filtro ativo e zero resultados, a linha de status esconde o link (`index.html.erb:94`) e o único "Limpar filtros" é o do vazio, `link_to … catalog_path` (`index.html.erb:313`), que **perde `sort` e `dir`**. O teste `:134-141` fixa o esconder, mas nada fixa a ordenação no vazio. A decisão da T17 contraria o texto do NAV-36. M04 e M05 mortos; M39 sobreviveu (`records.size` no lugar de `total_count`): nenhum fixture passa de uma página. |
| NAV-37 | Cartões com número em `display` e legenda em `caption` | `progress_canvas_test.rb:23-50`; `minha_pasta_test.rb:290-330` | ✅ (M29 morto) |
| NAV-38 | Barra com **os mesmos valores** da contagem; sem total conhecido, sem barra | `minha_pasta_test.rb:331-360`: só `assert bar["value"]` e `assert bar["max"]` | ❌ M12 sobreviveu (`max` trocado por `base_size`) e M13 também (barra renderizada sem total conhecido). Nenhuma das duas cláusulas é testada pelo valor. |
| NAV-39 | "Adicionar cartas" leva ao catálogo | `minha_pasta_test.rb:363-398` | ✅ |

### P1 Acabamento conferido na tela renderizada (NAV-40..51)

| Critério | Resultado exigido pela spec | Evidência | Resultado |
|---|---|---|---|
| NAV-40 | Marca e navegação empilhadas no topo, sem espaço distribuído | `navigation_layout_test.rb:160-178` | ✅ (M21 morto) |
| NAV-41 | Sem sublinhado; "Sair" transparente, sem borda nativa | `navigation_button_styling_test.rb:21-40` | ✅ (M19 e M20 mortos) |
| NAV-42 | Gap fixo `var(--space-4)`, sem esticar; mesma superfície | `catalog_subgrid_layout_test.rb:112-143` | ✅ (M16 morto) |
| NAV-43 | `<details>` fechado por padrão; `summary` "Filtros" + "N filtros ativos" | `catalog_filters_toggle_test.rb:45-91` | ✅ (M10 e M34 mortos) |
| NAV-44 | "Filtros ativos" fora do `<details>`, removível | `catalog_filters_toggle_test.rb:100-103` | ✅ |
| NAV-45 | ≥ 1024px: controles sempre visíveis, sem `summary` | `filters_toggle_layout_test.rb:23-32` | ✅ (M17 e M18 mortos). Depende de `::details-content`, verificado só no Chromium (premissa da spec, linha 72). |
| NAV-46 | Busca e botão com 44px, superfícies e bordas definidas | `catalog_search_styling_test.rb:9-43` (`assert_equal` exato) | ✅ (M24 morto) |
| NAV-47 | Linha de status rente à borda esquerda da grade | `catalog_search_styling_test.rb:45-49` (só `padding: 0` do status) | ❌ M42 sobreviveu: mudar o recuo horizontal de `.catalog__head` para diferir do de `.catalog__body` desalinha status e grade sem derrubar nada. Veja ⚠️. |
| NAV-48 | Imagem maior da primeira variante no topo; coluna de 320px no largo | `card_detail_hero_image_test.rb:22-29`, `:35-56`; `card_detail_media_test.rb:62-75` | ✅ (M26 e M33 mortos) |
| NAV-49 | Variantes em linha; rótulos "Código", "Raridade", "Set" no HTML e fora da vista | `card_detail_variants_grid_test.rb:30-67` (recorte do `dt`) | ❌ M45 sobreviveu: apagar o `<dt>Código</dt>` passa. A presença dos rótulos no HTML, metade do critério, não é testada. M27 morto (a parte "fora da vista"). |
| NAV-50 | Detalhe: posse com 44×44 | `card_detail_ownership_buttons_test.rb:22-28` | ✅ (M22 morto) |
| NAV-51 | Set sem moldura; contagem à direita; ações secundárias separadas | `progress_line_test.rb:13-36`; `minha_pasta_test.rb:403-458` | ✅ (M28 morto) |

### Edge cases

| Critério | Evidência | Resultado |
|---|---|---|
| NAV-26 | `catalog_filter_controls_test.rb:248-257` | ✅ Com ressalva: `:265` e `:274` usam seletores que nunca casariam (`href*='InvalidColor%5B%5D'`, o valor tomado por chave). São asserções vazias; o comportamento vale por construção (as opções vêm do banco). |
| NAV-27 | `catalog_filter_controls_test.rb:280-288`; `catalog_filters_toggle_test.rb:113-118` | ✅ Com ressalva: `:287-288` casam cruzado. O `href` do chip Red ativo contém `rarities[]=C` e vice-versa, então as asserções não provam qual chip está ativo. |
| NAV-28 | `navigation_canvas_test.rb:118-126`; `progress_canvas_test.rb:54-58`; `progress_line_test.rb:24-27`; guardas preexistentes de 360px | ✅ Só textual (sem navegador no container, conforme o CLAUDE.md) |
| NAV-29 | `minha_pasta_test.rb:196-201` (`assert_redirected_to new_session_path`) | ✅ |

**Status**: 41 ✅ · 10 ❌ (NAV-04, 11, 18, 34, 35, 36, 38, 47, 49 e o Success Criterion) · 6 ⚠️ (abaixo)

---

## Discrimination Sensor

**Isolamento**: cópia por `rsync` em `<scratchpad>/verify-copy` (sem `.git`, `tmp`, `log`, `storage`, `.playwright-mcp`) e projeto Compose `bindr-verify` sem portas publicadas. Suíte completa (`bin/rails test`) por mutante, uma falha de cada vez, restaurada logo depois. Nenhum `git stash`, nenhum worktree. Ao final, `docker compose -p bindr-verify down -v` e a cópia apagada. `git status --porcelain` da árvore real: só `?? .playwright-mcp/` antes e depois (mais este arquivo e o store de lições).

**Profundidade**: expandida (≥ 5 por área de risco): 45 mutantes de comportamento, mais 1 sonda.

| # | Local | Falha injetada | Resultado |
|---|---|---|---|
| M01 | `catalog_helper.rb:94` | `filter_toggle_url` mantém `page` | ✅ morto |
| M02 | `catalog_helper.rb:81` | valor ativo não é removido | ✅ morto |
| M03 | `catalog_helper.rb:74` | "todas" grava `owned=all` | ✅ morto |
| M04 | `catalog_helper.rb:99` | conta categorias em vez de chips | ✅ morto |
| M05 | `catalog_helper.rb:106` | "Limpar filtros" perde a ordenação | ✅ morto |
| M06 | `collection_item.rb:89` | indicadores sem `.owned` (conta quantidade 0) | ❌ **sobreviveu** |
| M07 | `collection_item.rb:89` | indicadores sem `for_user` | ✅ morto |
| M08 | `application.html.erb:31` | "Catálogo" corrente também em `/cards/*` | ❌ **sobreviveu** |
| M09 | `index.html.erb:281` | chips de posse para anônimo | ✅ morto |
| M10 | `index.html.erb:135` | `<details open>` | ✅ morto |
| M11 | `index.html.erb:155` | chip de cor ativo sem `aria-label` | ✅ morto |
| M12 | `progress/index.html.erb:166` | `max` da barra = `base_size` | ❌ **sobreviveu** |
| M13 | `progress/index.html.erb:163` | barra renderizada sem total conhecido | ❌ **sobreviveu** |
| M14 | `catalog.css:1937` | `.catalog__chip` com `min-height: 24px` | ❌ **sobreviveu** |
| M15 | `catalog.css` `.catalog__chip--active:not(...)` | chip de cor ativo preenchido de `accent` | ✅ morto |
| M16 | `catalog.css` media `.catalog__filters` | `align-content: space-between` | ✅ morto |
| M17 | media `.catalog__filters-summary` | `summary` visível no largo | ✅ morto |
| M18 | media `::details-content` | conteúdo do `<details>` fechado oculto no largo | ✅ morto |
| M19 | `.site-header__nav a` | `text-decoration: underline` | ✅ morto |
| M20 | `.site-header__nav button` | fundo `surface-sunken` no "Sair" | ✅ morto |
| M21 | media `.site-header` | `justify-content: space-between` | ✅ morto |
| M22 | `catalog.css:753` | posse do detalhe com 24px | ✅ morto |
| M23 | `catalog.css:83` | sem reserva no fim do conteúdo | ✅ morto |
| M24 | `catalog.css:143` | busca sem `min-height` | ✅ morto |
| M25 | `.catalog__status` | `padding: 0 var(--space-3)` | ✅ morto |
| M26 | media `.card-detail` | coluna de 280px | ✅ morto |
| M27 | `.variant__meta dt` | sem `position: absolute` | ✅ morto |
| M28 | `.progress-set` | borda própria | ✅ morto |
| M29 | `.progress__stat-value` | `title-size` | ✅ morto |
| M30 | `[aria-current]` da navegação | fundo `surface-raised` | ✅ morto |
| M31 | `index.html.erb:200` | formulário de set perde `q` | ✅ morto |
| M32 | `catalog_query.rb` `filter_options` | raridade NULL vira opção | ✅ morto |
| M33 | `show.html.erb` | imagem maior da **última** variante | ✅ morto |
| M34 | `index.html.erb:140-142` | `summary` sem a contagem | ✅ morto |
| M35 | media `:root` | coluna lateral fluida (`1fr 3fr`) | ✅ morto |
| M36 | media `.catalog__filters` | `grid-column: 2` | ✅ morto |
| M37 | `progress/index.html.erb:120` | wishlist aponta para o catálogo | ✅ morto |
| M38 | `index.html.erb:287` | `missing` → `absent` | ✅ morto |
| M39 | `index.html.erb:87` | contagem = `records.size` | ❌ **sobreviveu** |
| M40 | media `.site-header__nav` | continua `fixed` no largo | ✅ morto |
| M41 | `index.html.erb:158` | chip de cor ativo sem "×" | ❌ **sobreviveu** |
| M42 | media `.catalog__head` | recuo horizontal diferente do da grade | ❌ **sobreviveu** |
| M43 | `index.html.erb:263` | set único ativo sem `selected` | ❌ **sobreviveu** |
| M45 | `show.html.erb:142` | apaga `<dt>Código</dt>` | ❌ **sobreviveu** |
| M46 | `collection_item.rb:94` | total de cópias global | ✅ morto |
| sonda M44 | `application.html.erb:36` | "Entrar" via `nav_link_to` (a **correção** do NAV-04) | passa. Não conta como mutante: mostra que nenhum teste fixa o comportamento. |

**Resultado**: 35/45 mortos, 10 sobreviventes. **FAIL** ❌

Observação: em M30 também falhou `test/models/collection_import_test.rb`, que não tem relação com CSS. É provável que seja um teste instável sob os 8 workers paralelos. Não reproduzi.

---

## Pendências herdadas (Handoff 2026-09-23, 09-24, 09-25)

| # | Pendência | Veredito |
|---|---|---|
| P-1 | `6394755` (T3) editou o protegido `test/queries/set_progress_plan_test.rb` | **Procede, sem justificativa.** O commit, a T3 (`tasks.md:325-354`) e o `STATE.md` não registram motivo. A regra de `tasks.md:19-25` manda corrigir a view, não o teste. O conteúdo da edição é defensável: a página ganhou uma consulta legítima (os indicadores) e a contagem continua exata (`assert_equal 2`). Mas afrouxou a forma (`restantes.first` com `GROUP BY` virou "alguma tem `GROUP BY`"), e a segunda consulta ficou sem forma exigida. Pior: o Success Criterion (`spec.md:342-343`) afirma "os sete testes que leem `catalog.css` sem edição", e isso é falso. |
| P-2 | Histórico não atômico T12–T18 | **Confirmado**, sem efeito no estado final: `285cc7a` (T12) já traz regras `.catalog__chip`; `97db558` (T15, `feat`) só tem teste e `tasks.md`; a view de posse entrou em `9a3889d` (T14). Não houve rebase, e reescrever `main` agora não compensa. Fica como dívida registrada. |
| P-3 | Workers com testes que espelham a implementação; sensor sobre 4 arquivos | `filter_layout_test.rb`: M14 **sobreviveu** (`include?` global em `:92-110`); M15 e M36 mortos. `navigation_canvas_test.rb`: M30 e M35 mortos; `:70-77` passa em silêncio se a regra sumir (`if rule`). `catalog_subgrid_layout_test.rb`: M16 e M36 mortos; `:68-75` só confere presença de `row-gap`. `catalog_status_line_test.rb`: M04 e M05 mortos, M39 sobreviveu; `:145-155`, "≥ 24px", não mede nada. **Procede em parte.** |
| P-4 | `filter_toggle_url` depende de chave símbolo | **Confirmado, latente.** Sonda no runner da cópia: `filter_toggle_url({colors: ["Red"]}, "colors", "Red")` → `/catalog?colors%5B%5D=Red&colors%5B%5D=Red` (acrescenta em vez de remover); `({owned: "owned"}, "owned", "owned")` → `owned=owned&owned=owned`. A view só passa símbolo, por isso não há defeito visível hoje. O `key.to_sym == :owned` em `catalog_helper.rb:69` finge aceitar string e não aceita. |
| P-5 | Reescritas nas Fases 6–10 só onde o critério mudou | **Violada em um ponto.** Caíram sem substituto "set único ativo aparece selected" (NAV-11 do set, que não mudou; M43 sobreviveu) e o envio real com dois sets. As asserções de URL, preservação, isolamento, NAV-26 e NAV-27 foram mantidas com força equivalente. |
| P-6 | O teste "24px" da T4a não lê a folha | **Confirmado**: `minha_pasta_test.rb:248-255` só verifica a classe; `:386-391`, "44px", idem; os três "remover faria falhar" (`:258-286`) repetem `:205-227`. |
| P-7 | Falta teste de `nav` único e de ausência de `aria-current` no detalhe | O `nav` único está coberto (`navegacao_principal_test.rb:45`). A ausência no detalhe **continua sem teste** (M08 sobreviveu). |
| P-8 | T9 e T10 na mesma media query `64rem` | **Resolvida**: há uma única `@media (min-width: 64rem)` (`catalog.css:1789`). |

---

## Lacunas de precisão da spec (⚠️)

1. **NAV-04, escopo**: a spec (e o Req. 13.2) cobre "a entrada correspondente" para qualquer página da navegação, incluindo "Entrar" e "Criar conta"; a T5 cobriu só Catálogo e Minha pasta. É preciso escolher uma das duas e alinhar os dois documentos.
2. **NAV-11/NAV-34, "Todas" como valor ativo**: sem `owned`, "Todas" aparece ativo com "×" e nome "Remover filtro Posse: Todas" (`index.html.erb:283-294`), e o destino é a própria URL. O nome promete uma remoção que não acontece. A spec não diz se o default de uma categoria exclusiva conta como "valor ativo".
3. **NAV-38, denominadores**: a barra usa `owned_variants/total_variants` (todas as impressões), mas só é renderizada quando `base_size` é conhecido; o percentual ao lado usa a base. A spec amarra a barra à contagem "possuídas / total" sem dizer qual total. Hoje está coerente com o texto, mas mistura duas métricas do AD-003 na mesma linha.
4. **NAV-47**: "alinhar à borda esquerda da grade" não tem medida verificável sem navegador. O único proxy testado (`padding: 0` do status) não basta (M42).
5. **NAV-01**: "toda página" é verificada em duas páginas; é aceitável porque o layout é único, mas vale dizer isso na spec.
6. **NAV-45**: cumprido via `::details-content`, verificado só no Chromium (premissa da spec, linha 72). Em navegador sem suporte, os filtros ficam ocultos na tela larga com o `<details>` fechado. Risco aceito, mas não medido.

---

## Code Quality

| Princípio | Status |
|---|---|
| Código mínimo | ⚠️ `CollectionItem.distinct_variants_for` (`collection_item.rb:75`) não tem uso em produção; os testes de modelo cobrem o método que a tela não usa. |
| Mudanças cirúrgicas | ✅ `catalog.css` só recebeu acréscimos |
| Sem escopo além do pedido | ✅ |
| Segue os padrões | ⚠️ A view consulta o modelo direto (`progress/index.html.erb:76`); `.catalog__filters button[type="submit"]` recebe 44px (`catalog.css:1715`) e perde para 24px mais adiante. Regras mortas de checkbox/radio/`.catalog__color-option` ficaram da forma anterior dos filtros. |
| Resultado verificado contra a spec | ❌ NAV-18, 38, 49 e 35 testados por presença, não por valor |
| Todo teste mapeia um critério | ⚠️ Testes com nome que promete medida e não medem (P-6, `catalog_status_line_test.rb:145`) |
| Guias documentados | `CLAUDE.md` do projeto e `tasks.md` Execution Protocol; a regra dos protegidos foi violada (P-1) |

---

## Fix Plans

Em ordem de prioridade:

1. **[Major] Success Criterion falso e teste protegido editado (P-1)**
   - Registrar uma AD que ratifique a edição de `6394755`, com a decisão do dono, e corrigir `spec.md:342-343` para "seis dos sete, e o `set_progress_plan_test.rb` com a edição da AD-0xx".
   - Opcional: exigir que a consulta restante sem `GROUP BY` seja a agregação de `collection_items`.
2. **[Major] NAV-18: indicador renderizado sem teste de quantidade 0 (M06)**
   - Em `minha_pasta_test.rb`, criar um `CollectionItem` com `quantity: 0` e afirmar que os indicadores continuam em "4 cartas na pasta" e "2 cartas diferentes".
   - Apagar `distinct_variants_for`, ou fazer a view usá-lo, para que o teste de modelo cubra o código que a tela executa.
3. **[Major] NAV-04: "Entrar" e "Criar conta" sem `aria-current` (defeito)**
   - Trocar os dois `link_to` de `application.html.erb:36-37` por `nav_link_to`, ou emendar o Req. 13.2 e o NAV-04 se o dono preferir o escopo da T5.
   - Nos dois casos, testar `/session/new` e `/registration/new`, e a ausência de `aria-current` em `card_path` (M08).
4. **[Major] NAV-38: barra testada por presença (M12, M13)**
   - Afirmar `value == owned_variants` e `max == total_variants` com números do fixture.
   - Criar um set com `base_set_size: nil` e afirmar `.progress-set__bar` com `count: 0` naquele `li`.
5. **[Minor] NAV-36: "Limpar filtros" do vazio perde a ordenação (defeito)**
   - Fazer o link do estado vazio usar `clear_filters_url(@result.active_filters)` (`index.html.erb:313`) e testar `colors[]=Purple&sort=name&dir=desc`.
6. **[Minor] NAV-35: `include?` solto (M14)**
   - Trocar `filter_layout_test.rb:92-110` por `Stylesheet.resolved("catalog__chip")["min-height"]` com `assert_equal "44px"`, e o mesmo para borda, raio e o fundo do ativo.
7. **[Minor] NAV-11 do set (M43)**
   - Restaurar em `catalog_filter_controls_test.rb`: `get catalog_path(sets: ["OP02"])` → `option[value=OP02][selected]` e `option[value=OP01]:not([selected])`.
8. **[Minor] NAV-34 do chip de cor (M41)**
   - Afirmar o "×" pelo texto: `span[aria-hidden='true']`, `text: "×"`, no chip de cor ativo.
9. **[Minor] NAV-49: rótulos no HTML (M45)**
   - Afirmar `.variant__meta dt` com os textos "Código", "Raridade" e "Set".
10. **[Minor] NAV-47 (M42)**
    - Testar que o recuo horizontal de `.catalog__head` e o de `.catalog__body` são iguais na media larga, e na regra base para a tela estreita.
11. **[Minor] `filter_toggle_url` (P-4)**
    - Normalizar `key = key.to_sym` e `filters = active_filters.to_h.transform_keys(&:to_sym)` no início.
    - Acrescentar um teste com chave string.
12. **[Cosmetic] Rastreabilidade**
    - `spec.md:304-313`: NAV-30..NAV-39 estão `Pending`; atualizar depois das correções.
    - Renomear ou reescrever os testes vazios de P-6 e `catalog_status_line_test.rb:145`.
    - Corrigir os seletores sem efeito de `catalog_filter_controls_test.rb:265,274,287-288`.
13. **[Cosmetic] Spec**: resolver as lacunas ⚠️ 2 e 3 ("Todas" ativo; denominador da barra) numa emenda.

---

## Requirement Traceability Update

| Requisito | Status na spec | Status verificado |
|---|---|---|
| NAV-01..03, 05..10, 12..17, 19..33, 37, 39..46, 48, 50, 51 | Implemented/Done/Pending | ✅ Verified |
| NAV-04, NAV-36 | Implemented/Pending | ❌ Needs Fix (defeito) |
| NAV-11, NAV-18, NAV-34, NAV-35, NAV-38, NAV-47, NAV-49 | Implemented/Pending/Done | ❌ Needs Fix (teste não discrimina) |

---

## Summary

**Overall**: ❌ Not Ready

**Checagem contra a spec**: 41/51 critérios com evidência que discrimina; 10 com lacuna, dos quais 2 são defeitos de comportamento; 6 lacunas de precisão da spec.
**Sensor**: 35/45 mutantes mortos.
**Gate**: 1197 passaram, 0 falharam, RuboCop limpo, build verde.

**O que funciona**:
- A URL de alternância e a preservação de filtros.
- O isolamento da posse.
- O `<details>` e a coluna lateral.
- Toda a folha coberta por asserções exatas: navegação, busca, detalhe e pasta.

**Próximo passo**: rotear o Fix Plan 1–11 a um implementador e redespachar o Verifier (iteração 1 de 3).

---

## Iteração 1 do loop de correção (2026-09-27)

Correções T34–T41, uma por commit, de `6358b96` a `86c3d21`. Gate full: 1214 runs, 0 falhas, RuboCop limpo.

| Lacuna | Task | Commit |
|---|---|---|
| P-1, Success Criterion falso | T34 (AD-017, decisão do dono) | `6358b96` |
| NAV-04, M08 (defeito) | T35 | `e2e1f5a` |
| NAV-18, M06 | T36 | `3c167a8` |
| NAV-38, M12 e M13 | T37 | `271db5d` |
| NAV-36 (defeito), M39, `catalog_status_line_test.rb:145` | T38 | `f389169` |
| P-4, `filter_toggle_url` com chave string | T39 | `ac956c5` |
| NAV-35, M14 | T40 | `5adc70e` |
| NAV-11 (M43), NAV-34 (M41), seletores sem efeito | T41 | `86c3d21` |

**Não viraram correção aqui**: M42 (NAV-47) e M45 (NAV-49). A `conformidade` reescreve a linha de status do catálogo (inventário §5) e a linha da variante no detalhe (D8–D10). Por isso a medida do alinhamento da linha de status e a asserção dos rótulos "Código", "Raridade" e "Set" entram na spec nova como critério. Testar agora uma forma que vai ser trocada não compensa. O NAV-47 e o NAV-49 continuam cumpridos pelo que já existe. O que fica pendente é só a prova discriminante.

**Lacunas de precisão**: as seis foram resolvidas na spec na T34. O "Todas" ativo com nome "Remover filtro" vai para a `conformidade` como critério.

O próximo Verifier confere esta iteração.
