# Conformidade com o canvas — Validation

**Date**: 2026-09-29
**Spec**: `.specs/features/conformidade/spec.md` (CNF-01..CNF-41)
**Diff range**: `61a0e03^..c78fd80` (HEAD = `c78fd80`; 41 commits, 64 arquivos, +6314 −1294; testes: 32 arquivos, +2347 −555)
**Verifier**: sub-agente independente (autor ≠ verificador), Sonnet, **ciclo 2** — novo, não fez o ciclo 1 nem escreveu a feature. Checagem re-derivada do zero a partir de `spec.md`, `tasks.md` e `canvas-conformance.md`; o relatório do ciclo 1 foi comparado só depois.

**Veredito: FAIL ❌** — uma lacuna real de critério: **CNF-41** exige "Limpar filtros" do estado vazio com altura mínima de 44px, e `.catalog__empty-reset` resolve `min-height: 24px` (`app/assets/stylesheets/catalog.css:362-366`), sem teste que o cubra (o mutante h sobreviveu à suíte inteira). As lacunas do ciclo 1 (CNF-12, CNF-04, CNF-23, CNF-18, CNF-08) estão fechadas e os mutantes correspondentes agora morrem. Gate verde (1348 runs, 0 falhas, RuboCop limpo).

## Histórico: ciclo 1 = FAIL, ver git a5dd965

`git show a5dd965:.specs/features/conformidade/validation.md`. Range `61a0e03^..dca1413`, 17 mutantes (15 mortos, M3 equivalente, M4 real). Lacunas: F1 CNF-12 (`auto-fill` abaixo de 1024px), F2 CNF-04 (limite de duas impressões), F3 CNF-23 (posição de "Voltar"), F4 CNF-18 (peso 600 e ordem do trigger), F5 CNF-08 (recuo por `include?`), spec-precision CNF-17 e CNF-36. A Phase 7 (T18–T21) as tratou; T22 foi descartada de propósito (`tasks.md:851`) e **não é lacuna**.

| Lacuna do ciclo 1 | Fechada? | Evidência do ciclo 2 |
|---|---|---|
| F1 CNF-12 | ✅ | `catalog.css:215` agora `repeat(2, minmax(0, 1fr))`; `test/design/catalog_grid_canvas_test.rb:44` `assert_equal "repeat(2, minmax(0, 1fr))", grid["grid-template-columns"]` sobre `@narrow_rules`; mutante (a) morre |
| F2 CNF-04 | ✅ | `test/integration/catalog_tile_test.rb:174` `assert_equal "2 impressões", …`; mutante (b) morre |
| F3 CNF-23 | ✅ | `test/integration/card_detail_layout_test.rb:69` `assert_select ".site-header__aside a.site-header__back", count: 1` e `:73`; mutante (d) morre |
| F4 CNF-18 | ✅ | `test/integration/card_detail_header_test.rb:144-145` (peso resolve `"600"`) e `:152` (rótulo depois do texto) |
| F5 CNF-08 | ✅ | `test/integration/catalog_status_line_test.rb:291` `assert_equal "30rem", search_rule.fetch("width")` e `:333-336` `assert_equal` do recuo; mutante (e) morre |
| spec-precision CNF-36 | ✅ | spec emendada (`spec.md:204`, 155×217 e 320×448); `test/design/card_detail_media_test.rb:19-20`, `:69` e `:74` (`5 / 7` ⇒ 448) |
| spec-precision CNF-17 | ⚠️ aberto | "forma compacta" segue sem medida em `spec.md:143`; o canvas não desenha os campos (`canvas-conformance.md:48`). **DECISÃO-DO-DONO já sinalizada; não reprova** |

---

## Task Completion

| Task | Status | Notes |
| ---- | ------ | ----- |
| T1–T11, T13–T17 | ✅ Done | Todos os "Done when" marcados em `tasks.md`; re-derivados abaixo pelos CNF |
| T12 | ⚠️ Partial (por decisão do dono) | Único item aberto: `tasks.md:694` "O dono comparou as capturas … e aprovou". **Pendência adiada pelo dono; não reprova.** Capturas e `canvas-conformance.md` existem (CNF-34/35) |
| T18 | ✅ Done | Ver CNF-12 |
| T19 | ✅ Done | Ver CNF-04, CNF-02 (isolamento), CNF-16 |
| T20 | ✅ Done | Ver CNF-23, CNF-18, CNF-08 |
| T21 | ⚠️ Partial | CNF-06, 08, 36 emendados e CNF-41 criado; CNF-17 fica DECISÃO-DO-DONO. O CNF-41 criado aqui ficou sem implementação do 44px (G1) |
| T22 | ⏭️ Descartada | `tasks.md:851`: descartada em 2026-09-29, motivo registrado; não é lacuna |

---

## Spec-Anchored Acceptance Criteria

Evidência lida nos testes e na folha, não nas mensagens de commit. Caminhos de teste relativos a `test/`; `catalog.css` = `app/assets/stylesheets/catalog.css`.

| CNF | Spec-defined outcome | `file:line` + assertion | Result |
| --- | -------------------- | ----------------------- | ------ |
| 01 | Sem form/botão/incremento de posse em tile | `integration/catalog_tile_test.rb:41` `assert_select ".card-tile form", 0`; `:42` `button`; `:43` `.ownership`; `:54-55` anônimo | ✅ PASS |
| 02 | Selo com total das variantes, "N cópias"/"1 cópia", accent/on-accent, sobre o canto superior direito | `integration/catalog_tile_test.rb:74-76` `"3"`, `"3 cópias"`, `role=img`; `:90` `"1 cópia"`; `:138` e `:151` `assert_nil …badge` (isolamento); `design/ownership_badge_test.rb:51-52` `var(--accent)` / `var(--on-accent)`. **Posição (`top/right`, `catalog.css:321-325`) sem nenhuma asserção** | ⚠️ PASS parcial (posição sem evidência, G2) |
| 03 | Sem selo anônimo, sem cópia ou com zero | `integration/catalog_tile_test.rb:102` `assert_select ".card-tile__badge", 0`; `:113`; `:125` `assert_nil` | ✅ PASS |
| 04 | 1 variante → raridade; >1 → "N impressões" (2 e 3) | `integration/catalog_tile_test.rb:163` `"SR"`; `:174` `"2 impressões"`; `:184` `"3 impressões"`; `:208` | ✅ PASS (mutante b morto) |
| 05 | "N cartas [· M filtros ativos]", total do resultado | `integration/catalog_status_line_test.rb:240` `/^3 cartas$/`; `:231` `/^\s*36 cartas\s*·\s*1 filtro ativo\s*$/`; `:122`; `:196` | ✅ PASS |
| 06 | Com filtro e ≥1 resultado: "Limpar filtros" bordado, ≥44px, preserva sort/dir | `integration/catalog_status_line_test.rb:135-137` `include?("sort=name")`, `include?("dir=desc")`, `refute colors`; `:249` `assert_operator …min-height, :>=, 44`; `:250` borda | ✅ PASS |
| 07 | Convite anônimo uma vez, na linha de status | `integration/catalog_status_line_test.rb:259` `count: 1`; `:260-261` `a[href=new_session_path]`; `:267` com sessão `count: 0` | ✅ PASS |
| 08 | ≥1024px: busca+status na mesma linha; recuo igual; busca `30rem` | `integration/catalog_status_line_test.rb:288` `assert_equal "flex"`; `:291` `assert_equal "30rem", search_rule.fetch("width")`; `:333` e `:335` `assert_equal head_*_px, body_*_px` | ✅ PASS (mutante e morto) |
| 09 | Rótulo e placeholder do canvas | `integration/catalog_status_line_test.rb:275` `label[for=catalog-q]` "Buscar por nome ou card_number"; `:276` placeholder `OP01-024` | ✅ PASS |
| 10 | Sem "Sua coleção" | `integration/catalog_status_line_test.rb:341-349`; `:352` sem stream `catalog_owned_total` | ✅ PASS |
| 11 | Cores e raridades na ordem; tipo capitalizado, URL crua | `queries/catalog_filter_options_test.rb:186` (`assert_equal expected_order, result[:colors]`), `:227` (raridades), `:254`; `integration/catalog_filter_controls_test.rb:373-376` `"Character"`, `href*='card_types%5B%5D=character'` | ✅ PASS (mutante i morto) |
| 12 | ≥1024px: 5 colunas/16px; <1024px: duas colunas/8px | `design/catalog_grid_canvas_test.rb:44` `assert_equal "repeat(2, minmax(0, 1fr))"`, `:45` `8.0`; `:51` `"repeat(5, minmax(0, 1fr))"`, `:52` `16.0`. Guardas de 360px `integration/catalog_grid_test.rb` e `design/layout_test.rb` verdes | ✅ PASS (mutante a morto) |
| 13 | Tile 16px, arte sunken 8px, divisor 1px `--border` | `design/catalog_grid_canvas_test.rb:55-62`, `:63-68`, `:70-77` | ✅ PASS |
| 14 | <1024px: miniatura ao lado do título + `<details>` sem JS | `integration/card_detail_hero_image_test.rb:25-26`, `:33` `assert_operator head_pos, :<, data_pos`, `:42-45`, `:51` (`scripts_before` igual); `design/card_detail_media_test.rb:19-20` 155×217 | ✅ PASS |
| 15 | ≥1024px: coluna de 320px sempre visível | `design/card_detail_media_test.rb:52` `"none"` (miniatura), `:58` `"contents"`, `:62` `content-visibility: visible`, `:68-69` `grid-column "1"` e `320.0`, `:101` `align-self "start"` | ✅ PASS |
| 16 | Selo da 1ª variante (não a soma); legenda "Ilustração: {nome}" | `integration/card_detail_image_test.rb:32-34` (`"2"`, `"2 cópias"`), `:68-70` (1 cópia, nunca 4), `:79` `"Ilustração: Eiichiro Oda"` | ✅ PASS (mutante c morto) |
| 17 | Chips tipo/raridade(1ª)/cor(es)/counter; "set · código"; demais campos "compactos" | `integration/card_detail_header_test.rb:32-34`, `:48-49`, `:62-63`, `:76`, `:87`, `:101` `"Romance Dawn · OP01"`; `integration/card_detail_test.rb:122`, `:137` (Req. 5.5). "Forma compacta" sem medida na spec | ⚠️ Spec-precision gap (DECISÃO-DO-DONO, não reprova) |
| 18 | Trigger em "Efeito", depois do efeito, rótulo peso 600, quebras | `integration/card_detail_header_test.rb:115-118`, `:144-145` `assert_equal "600", resolved_weight`, `:152` `assert_operator trigger_label_pos, :>, effect_text_pos`; `integration/card_detail_test.rb` `assert_match(/<br/, html…)` | ✅ PASS |
| 19 | Título "Variantes na pasta" + divisor 1px `--border` | `integration/card_detail_variants_test.rb:37`; `design/card_detail_variants_grid_test.rb:89-90` | ✅ PASS |
| 20 | Código, "{raridade} · {arte}", set, miniatura menor, rótulos fora da vista | `integration/card_detail_variants_test.rb:45-50`, `:56-58`; `design/card_detail_variants_grid_test.rb:57-58` 80×112 (< 320×448), `:77-83` recorte sem `display` | ✅ PASS |
| 21 | `−` `[n]` `+`, 44×44, "não tenho" + `aria-disabled` em zero | `integration/card_detail_variants_test.rb:79`, `:92-93`, `:102-103`, `:111-112`; `design/card_detail_ownership_buttons_test.rb:27-28`, `:43-44` | ✅ PASS |
| 22 | +/− atualiza sem recarregar (Turbo Stream) | `integration/card_detail_variants_test.rb:164-165` `turbo-stream[action=update][target=…]`, `.ownership__step` "1" | ✅ PASS |
| 23 | "Voltar": bordado ≥44px, sem seta; ≥1024px na coluna lateral abaixo de divisor 1px | `integration/card_detail_layout_test.rb:69` `.site-header__aside a.site-header__back` `count: 1`, `:71` sem "←", `:73` `main.card-detail a.site-header__back` `0`; `design/navigation_canvas_test.rb:141` `"44px"`, `:143` borda, `:173` `"1px solid var(--border)"` | ✅ PASS (mutante d morto) |
| 24 | Marca 28/32/700 em ≥1024px | `design/navigation_canvas_test.rb:157-161` `var(--display-size)`, `-line-height`, `-weight` no bloco largo | ✅ PASS |
| 25 | Código + nome-link (`sets: [código]`), contagem à direita, barra abaixo | `integration/progress_ui_test.rb:442-448`; `design/progress_line_test.rb:56-70` (nowrap, ellipsis, sem sublinhado), `:83-90`, `:91-101` | ✅ PASS |
| 26 | Percentual junto da contagem; parallels em legenda; sem "Ver no catálogo"/"N sets" | `integration/progress_ui_test.rb:122` `"4 / 7 · 60%"`, `:125` `"3 de 5 do set base · 1 de 2 parallels"`, `:451-452`, `:460-465` | ✅ PASS |
| 27 | `recent` por `updated_at` do usuário; `code`; sem posse no fim; isolamento | `integration/progress_order_test.rb:65-66`, `:86-88`, `:147`; `queries/set_progress_query_test.rb:742`, `:760`, `:770`, `:806` (quantity 0), `:827` | ✅ PASS (mutantes f1, f2 mortos) |
| 28 | Ordem inválida → recent e 200 | `integration/progress_order_test.rb:96-99` (xyz), `:106-109`, `:116-119`; `queries/set_progress_query_test.rb:780`, `:786` | ✅ PASS |
| 29 | Chips "Recentes"/"Por código" com `aria-current` | `integration/progress_order_test.rb:167-168`, `:175-176`, `:183-184`, `:195-196` | ✅ PASS |
| 30 | ≥1024px: 4 colunas/16px; sets + coluna de 420px | `design/progress_add_cards_test.rb:52-53`, `:62-64` `"minmax(0, 1fr) 420px"`, `:68-71` | ✅ PASS |
| 31 | "Todas" atual, sem "×" nem nome de remoção | `integration/catalog_filter_controls_test.rb:405-406`, `:407` `assert_nil todas_chip["aria-label"]` | ✅ PASS |
| 32 | <1024px fixo, accent, ≥44px; ≥1024px na coluna lateral abaixo de divisor | `design/progress_add_cards_test.rb:78-82`, `:85`, `:114-118`, `:123-126`, `:130` | ✅ PASS |
| 33 | Campo de arquivo: surface, borda, ≥44px | `design/progress_add_cards_test.rb:147-149` | ✅ PASS |
| 34 | Capturas 390/1280, com e sem sessão, lado a lado | `canvas-conformance.md:3-6`; PNGs em `tmp/comparacao/` (fora do git, AD-015). Aprovação do dono **pendente por decisão dele** | ⚠️ PASS (dono pendente, não reprova) |
| 35 | Cada item da checklist com resultado, sem órfão | `canvas-conformance.md:17-74` (três tabelas; cada linha = conforme / CNF / Out of Scope) | ⚠️ PASS (dono pendente, não reprova) |
| 36 | Placeholder na mesma medida: 155×217 e 320×448 | `design/card_detail_media_test.rb:19-20` (155/217), `:69` (320), `:74` `"5 / 7"` (⇒448), `:43-45` placeholder `position:absolute; inset:0`; `integration/card_detail_image_test.rb:99-102` | ✅ PASS |
| 37 | Sem ilustrador → sem legenda | `integration/card_detail_image_test.rb:88` `assert_select ".card-detail__illustrator", count: 0` | ✅ PASS |
| 38 | Coleção vazia: por código, "Recentes" atual | `integration/progress_order_test.rb:130-132`, `:175` | ✅ PASS |
| 39 | Um chip por cor | `integration/card_detail_header_test.rb:62-63` | ✅ PASS |
| 40 | Raridade fora da lista depois das conhecidas | `queries/catalog_filter_options_test.rb:258` `assert_equal [ "C", "X", "Z" ]` | ✅ PASS |
| 41 | Zero resultados: "Limpar filtros" em `.catalog__empty`, **altura mínima 44px**, nenhum link em `.catalog__status` | Presença e posição: `integration/catalog_status_line_test.rb:155` `assert_select ".catalog__status a", count: 0`, `:156` `".catalog__empty a", text: "Limpar filtros", count: 1`, `:178-180` sort/dir. **44px: `catalog.css:362-366` `.catalog__empty-reset { min-height: 24px }`; nenhum teste toca `catalog__empty-reset`** (`grep -rn empty-reset test` = vazio) | ❌ GAP (G1) |

**Status**: ❌ Gaps presentes — 36 ✅ PASS, 4 ⚠️ (CNF-02 posição sem evidência; CNF-17 spec-precision; CNF-34 e CNF-35 com dono pendente), 1 ❌ GAP (CNF-41, 44px). Total 41.

---

## Discrimination Sensor

Cópia em `/tmp/claude-1000/bindr-verify` (rsync sem `.git`, `tmp`, `log`, `node_modules`, `.playwright-mcp`), projeto Docker `bindr-verify` sem portas publicadas, banco de teste próprio, gems pelo volume externo `bindr-tcg_bundle`. Mutação por substituição exata do trecho, testes em escopo, restauração e conferência de igualdade byte a byte após cada rodada (`restored True` nas 11).

| Mutation | File:line | Description | Killed? |
| -------- | --------- | ----------- | ------- |
| a | `catalog.css:215` | Grade fora do bloco largo volta a `repeat(auto-fill, minmax(var(--tile-min), 1fr))` (CNF-12) | ✅ Killed — `catalog_grid_canvas_test.rb:44` |
| b | `app/views/catalog/_card_tile.html.erb:54` | `variants.one?` → `variants.size < 3` (duas variantes mostrariam raridade, CNF-04) | ✅ Killed — `catalog_tile_test.rb:174` |
| c | `app/views/catalog/show.html.erb:10` | Selo do detalhe usa `owned_quantity_for_card(@card)` (soma) em vez da variante (CNF-16) | ✅ Killed — `card_detail_image_test.rb:68` |
| d | `app/views/catalog/show.html.erb:2-4` | "Voltar ao catálogo" sai de `content_for :sidebar_actions`, fora de `.site-header__aside` (CNF-23) | ✅ Killed — `card_detail_layout_test.rb:69` (+2 erros em `navigation_canvas_test.rb`) |
| e | `catalog.css:2167` | Largura da busca `30rem` → `28rem` (CNF-08) | ✅ Killed — `catalog_status_line_test.rb:291` |
| f1 | `app/queries/set_progress_query.rb:211` | `recent`: `DESC` → `ASC` (ordem da pasta, T1/CNF-27) | ✅ Killed — `progress_order_test.rb:76`, `:109` e outros |
| f2 | `app/queries/set_progress_query.rb:209` | `code`: sem posse deixa de ir ao fim, `IS NULL` removido (T1/CNF-27) | ✅ Killed — `set_progress_query_test.rb:776` (2 falhas) |
| g | `app/views/catalog/index.html.erb:261` | Remove "Limpar filtros" de `.catalog__empty` (CNF-41) | ✅ Killed — `catalog_status_line_test.rb:156` (5 falhas) |
| h | `catalog.css:362-366` | `.catalog__empty-reset` `min-height: 24px` → `0` (CNF-41, 44px) | ❌ **Survived** — suíte inteira, 1348 runs, 0 falhas → G1 |
| i | `app/queries/catalog_query.rb:172` | `KNOWN_RARITIES` troca `C` e `UC` (T2/CNF-11) | ✅ Killed — `catalog_filter_options_test.rb:254` |
| j | `app/helpers/collection_helper.rb:47` | Selo do tile soma só a 1ª variante (CNF-02) | ✅ Killed — `catalog_tile_test.rb:74` |

**Sensor depth**: lightweight ampliado — 11 mutações (as 7 pedidas, com (f) em f1/f2, mais g, h, i, j), cobrindo grade, tile, selo, voltar, busca, ordem da pasta, estado vazio e ordem dos chips.
**Result**: 11 injetadas, **10 mortas, 1 sobrevivente real (h)** — ❌ FAIL por h.

Os mutantes que o ciclo 1 deixou vivos (a e b) e os de evidência frouxa (d, e) agora morrem. O mutante h é novo e vem do CNF-41, criado na T21.

**Isolamento**: `git status --porcelain` da árvore real igual ao baseline (`?? .playwright-mcp/`) antes e depois. Nenhuma mutação tocou a árvore real. `docker compose -p bindr-verify down -v` executado e a cópia apagada (os arquivos de cache do `bootsnap` pertenciam ao root do contêiner e foram removidos com um contêiner descartável). Nenhum volume `bindr-verify*` restou.

---

## Interactive UAT Results

Não realizado: a aprovação do dono das capturas (T12, `tasks.md:694`) foi adiada por decisão dele. Registrada como pendência.

---

## Code Quality

| Principle | Status |
| --------- | ------ |
| Minimum code | ✅ — sem abstração nova além de `owned_quantity_for_card` e `in_known_order` |
| Surgical changes | ✅ — os 64 arquivos do diff caem nos `Where` das tasks |
| No scope creep | ✅ |
| Matches patterns | ✅ — `Stylesheet.resolved`, `wide_block` reaproveitado (`catalog_status_line_test.rb:284`), lista fechada como em `CatalogQuery` |
| Spec-anchored outcome check | ❌ — CNF-41: a spec pede 44px e a folha entrega 24px (`catalog.css:365`); ⚠️ CNF-02: posição do selo sem asserção |
| Per-layer Coverage Expectation | ⚠️ — query 1:1 com CNF-11/27/28/38/40; views cobrem com e sem sessão; faltam a medida de CNF-41 e a posição de CNF-02 |
| Every test in scope maps to an AC, edge case or Done-when — spot-check da história "Minha pasta" | ✅ — `progress_order_test.rb`, `progress_line_test.rb` e `progress_add_cards_test.rb` apontam cada teste a CNF-25..33 ou a um Done-when de T10/T11/T15–T17; `catalog_status_line_test.rb:161` (≥24px) é o NAV-27 mantido. Ruído sem assertar nada novo em `minha_pasta_test.rb` (já apontado no ciclo 1), não bloqueia |
| Test integrity | ✅ — `collection_total_test.rb` (−287) removido por CNF-10 com motivo; sem queda líquida (ver Gate) |
| Documented guidelines followed | ✅ — `CLAUDE.md` do projeto: `card_path(card_number)`, `assert_response :success` no detalhe, sem fixtures YAML |

---

## Edge Cases

- [x] CNF-36 placeholder sem `image_url` — `integration/card_detail_image_test.rb:99-102`; medida em `design/card_detail_media_test.rb:19-20`, `:69`, `:74`
- [x] CNF-37 sem ilustrador — `integration/card_detail_image_test.rb:88`
- [x] CNF-38 coleção vazia — `integration/progress_order_test.rb:130-132`, `:175`
- [x] CNF-39 mais de uma cor — `integration/card_detail_header_test.rb:62-63`
- [x] CNF-40 raridade desconhecida — `queries/catalog_filter_options_test.rb:258`

---

## Gate Check

- **Gate command**: `docker compose exec -T app bin/rails test && docker compose exec -T app bin/rubocop` (árvore real)
- **Result**: **1348 runs, 5639 assertions, 0 failures, 0 errors, 0 skips**; RuboCop: 163 files inspected, no offenses (ambos `exit=0`)
- **Test count before feature**: 1214 (base declarada em `tasks.md:55`)
- **Test count after feature**: 1348
- **Delta**: +134 runs (o ciclo 1 tinha 1343; T19/T20 acrescentaram 5)
- **Skipped tests**: nenhum
- **Failures**: nenhuma
- **Remoções**: `test/integration/collection_total_test.rb` (287 linhas, CNF-10) e os testes de posse na grade migrados para o detalhe (T3); sem queda líquida

---

## Fix Plans

### G1: "Limpar filtros" do estado vazio com 24px, não 44px (CNF-41) — Major

- **Root cause**: a T21 criou CNF-41 em `spec.md:114` ("com altura mínima de 44px"), mas a regra do link do estado vazio continua a herdada da `navegacao`, `min-height: 24px` (`catalog.css:362-366`, classe `catalog__empty-reset`, view `app/views/catalog/index.html.erb:261`). O irmão da linha de status (`.catalog__clear-filters`, `catalog.css:2454-2466`) tem 44px e teste (`catalog_status_line_test.rb:249`); o do estado vazio não tem nem um nem outro. O mutante h prova a falta de discriminação.
- **Fix task**: **Where** `app/assets/stylesheets/catalog.css`, `test/integration/catalog_status_line_test.rb`. **What** dar ao `.catalog__empty-reset` altura mínima de 44px e a borda de botão, no desenho do `.catalog__clear-filters` (ou reaproveitar a classe). **Verify** teste novo: `Stylesheet.resolved("catalog__empty-reset")` com `min-height` ≥ 44px. **Done when** o mutante h morre e o gate full passa.
- **Priority**: Major

### G2: Posição do selo sem asserção (CNF-02, CNF-16) — Minor

- **Root cause**: `catalog.css:321-325` posiciona `.card-tile__badge` e `.card-detail__badge` em `top/right: var(--space-2)`, mas nenhum teste lê a posição; só cor e raio (`design/ownership_badge_test.rb:51-52`). Não medi mutante porque a cópia já estava desmontada; é raciocínio, não medição.
- **Fix task**: **Where** `test/design/ownership_badge_test.rb`. Afirmar `position: absolute`, `top` e `right` resolvidos em 8px para os dois selos.
- **Priority**: Minor

### Fora de código (não reprovam)

- Aprovação do dono das capturas: `tasks.md:694`, adiada por decisão dele.
- CNF-17 "forma compacta" sem medida: DECISÃO-DO-DONO; o canvas não desenha os campos (`canvas-conformance.md:48`).

---

## Requirement Traceability Update

| Requirement | Previous Status | New Status |
| ----------- | --------------- | ---------- |
| CNF-01, 03–16, 18–33, 36–40 | Implemented | ✅ Verified |
| CNF-02 | Implemented | ⚠️ Verified com ressalva (posição do selo sem asserção, G2) |
| CNF-17 | Implemented | ⚠️ Spec-precision (DECISÃO-DO-DONO) |
| CNF-34, CNF-35 | Implemented (dono pendente) | ⚠️ Verified, aprovação do dono pendente |
| CNF-41 | Implemented | ❌ Needs Fix (G1) |

(`spec.md` não foi editado: o Verifier só grava `validation.md` e as lições.)

---

## Summary

**Overall**: ❌ Not Ready

**Spec-anchored check**: 36 ✅ PASS de 41; 1 ❌ (CNF-41, 44px); 4 ⚠️ (CNF-02 posição, CNF-17 spec-precision do dono, CNF-34/35 dono pendente)
**Sensor**: 10/11 mutações mortas (1 sobrevivente real: h)
**Gate**: 1348 passed, 0 failed, RuboCop limpo

**What works**: grade de duas colunas abaixo de 1024px e cinco acima; "N impressões" no limite de duas; selo por variante no detalhe; "Voltar" dentro de `.site-header__aside`; peso e ordem do trigger; recuo e largura da busca; ordem da pasta e isolamento entre usuários; stepper e Turbo Stream; regra de 360px; suíte inteira verde. As cinco lacunas do ciclo 1 estão fechadas.

**Issues found**: G1 (44px do "Limpar filtros" do estado vazio), G2 (posição do selo).

**Next steps**: uma task de correção para G1 (folha + teste) e, se o dono quiser, G2 (só teste); depois o ciclo 3 (de no máximo 3) e, por fim, a aprovação das capturas pelo dono.
