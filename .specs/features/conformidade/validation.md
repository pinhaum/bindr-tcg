# Conformidade com o canvas — Validation

**Date**: 2026-09-28
**Spec**: `.specs/features/conformidade/spec.md`
**Diff range**: `61a0e03^..dca1413` (26 commits, 56 arquivos, +4765 −1270; testes +2215 −555)
**Verifier**: sub-agente independente (autor ≠ verificador), Sonnet, ciclo 1

**Veredito: FAIL ❌** — duas lacunas reais de critério (CNF-12 abaixo de 1024px e CNF-04 no limite de duas impressões, esta provada por mutante sobrevivente) e uma de evidência (CNF-23). O gate está verde e 15 dos 17 mutantes morreram.

---

## Task Completion

| Task | Status | Notes |
| ---- | ------ | ----- |
| T1 | ✅ Done | Ordem `recent`/`code`; `set_progress_plan_test.rb` só com a edição aceita na AD-017/AD-018 |
| T2 | ✅ Done | — |
| T3 | ✅ Done | Testes de posse na grade migraram para o detalhe (`collection_ownership_ui_test.rb`) |
| T4 | ✅ Done | `collection_total_test.rb` removido (287 linhas): "Sua coleção" sai do catálogo (CNF-10); o total na pasta segue coberto em `minha_pasta_test.rb:89-114` |
| T5 | ⚠️ Partial | Done-when "fora [de 1024px], duas colunas" não cumprido literalmente — ver CNF-12 |
| T6 | ✅ Done | — |
| T7 | ✅ Done | Peso 600 do rótulo "Trigger" sem asserção (ver CNF-18) |
| T8 | ✅ Done | — |
| T9 | ⚠️ Partial | "Voltar ao catálogo" na coluna lateral sem teste de posição (ver CNF-23) |
| T10 | ✅ Done | — |
| T11 | ✅ Done | — |
| T12 | ⚠️ Partial | Único item aberto no `tasks.md:675`: "O dono comparou as capturas ... e aprovou". Capturas existem em `tmp/comparacao/` (6 PNGs) e `canvas-conformance.md` cobre as 3 telas |
| T13 | ✅ Done | — |
| T14 | ✅ Done | — |
| T15 | ✅ Done | Edição do guarda de 360px registrada na AD-018 |
| T16 | ✅ Done | — |
| T17 | ✅ Done | — |

---

## Spec-Anchored Acceptance Criteria

Evidência lida nos testes, não nas mensagens de commit. Todos os arquivos em `test/`.

| CNF | Spec-defined outcome | `file:line` + assertion | Result |
| --- | -------------------- | ----------------------- | ------ |
| 01 | Sem controle de posse no tile | `integration/catalog_tile_test.rb:41` `assert_select ".card-tile form", 0`; `:42` `button`; `:54` anônimo | ✅ PASS |
| 02 | Selo com total das variantes, "N cópias"/"1 cópia", accent/on-accent | `integration/catalog_tile_test.rb:74-76` texto "3", `aria-label` "3 cópias", `role=img`; `:90` "1 cópia"; `design/ownership_badge_test.rb:40-41` accent/on-accent | ✅ PASS |
| 03 | Sem selo anônimo ou com zero | `integration/catalog_tile_test.rb:102` (anônimo com posse alheia), `:113`, `:125` `assert_nil ...badge` | ✅ PASS |
| 04 | 1 variante → raridade; >1 → "N impressões" | `integration/catalog_tile_test.rb:137` "SR", `:147` "3 impressões" — **só 1 e 3 variantes; duas nunca testadas** (mutante M4 sobreviveu) | ❌ GAP |
| 05 | "N cartas [· M filtros ativos]", total do resultado | `integration/catalog_status_line_test.rb:61`, `:188` `/^\s*·\s*2 filtros ativos\s*$/`, `:196`, `:231` "36 cartas · 1 filtro ativo" | ✅ PASS |
| 06 | "Limpar filtros" ≥44px, bordado, preserva sort/dir | `integration/catalog_status_line_test.rb:135-136`, `:249` `assert_operator ..., :>=, 44`, `:250` borda | ✅ PASS |
| 07 | Convite anônimo uma vez, na linha de status | `integration/catalog_status_line_test.rb:258` `count: 1`, `:259` href `new_session_path`, `:267` com sessão `count: 0` | ✅ PASS |
| 08 | Busca e status na mesma linha; recuo igual | `integration/catalog_status_line_test.rb:283` `flex`; `:296-297` `assert_includes ...padding, "var(--space-4)"` — compara por `include?`, não o recuo resolvido igual | ⚠️ PASS fraco (asserção frouxa) |
| 09 | Rótulo e placeholder do canvas | `integration/catalog_status_line_test.rb:275-276` | ✅ PASS |
| 10 | Sem "Sua coleção" | `integration/catalog_status_line_test.rb:306` `"#catalog_owned_total", 0`; `:326` sem stream | ✅ PASS |
| 11 | Cores e raridades na ordem; tipo capitalizado, URL crua | `queries/catalog_filter_options_test.rb:204`, `:254`; `integration/catalog_filter_controls_test.rb:373-376` | ✅ PASS |
| 12 | ≥1024px: 5 colunas/16px; <1024px: **duas colunas/8px** | `design/catalog_grid_canvas_test.rb:51-52` `"repeat(5, minmax(0, 1fr))"`, gap 16 ✅; `:43-44` afirma `\Arepeat\(auto-fill,` — não "duas colunas". `catalog.css:215` usa `auto-fill, minmax(150px, 1fr)`: 3+ colunas entre ~480 e 1023px | ❌ GAP |
| 13 | Tile 16px, arte sunken 8px, divisor 1px | `design/catalog_grid_canvas_test.rb:60-62`, `:67-68`, `:76-77` | ✅ PASS |
| 14 | <1024px miniatura + `<details>` sem JS | `integration/card_detail_hero_image_test.rb:23-28`, `:42-51` (sem `<script>` novo); `design/card_detail_media_test.rb:19-21` 155×217 | ✅ PASS |
| 15 | ≥1024px coluna de 320px sempre visível | `design/card_detail_media_test.rb:52`, `:58-62` `content-visibility: visible`, `:69` 320px, `:87` | ✅ PASS |
| 16 | Selo da 1ª variante; legenda "Ilustração: {nome}" | `integration/card_detail_image_test.rb:32-34`, `:44`, `:54`, `:63`, `:72` | ✅ PASS |
| 17 | Chips tipo/raridade(1ª)/cor(es)/counter; "set · código"; demais campos "compactos" | `integration/card_detail_header_test.rb:32-34`, `:48-49`, `:76`, `:87`, `:101`, `:150-156`; `integration/card_detail_test.rb:123-124` | ⚠️ spec-precision gap ("forma compacta" sem medida) |
| 18 | Trigger em "Efeito", depois do efeito, rótulo peso 600, quebras | `integration/card_detail_header_test.rb:116-119`; `integration/card_detail_test.rb:284-286` `<br`. `catalog.css:443` declara `var(--body-strong-weight)` (600) mas **nenhum teste asserta peso nem ordem "depois do efeito"** | ⚠️ PASS parcial |
| 19 | Título "Variantes na pasta" + divisor 1px | `integration/card_detail_variants_test.rb:37`; `design/card_detail_variants_grid_test.rb:89-90` | ✅ PASS |
| 20 | Código, "{raridade} · {arte}", set, miniatura menor, rótulos fora da vista | `integration/card_detail_variants_test.rb:45-50`, `:56-58`; `design/card_detail_variants_grid_test.rb:57-58` 80×112, `:77-83` recorte | ✅ PASS |
| 21 | `−` `[n]` `+`; 44×44; "não tenho" + `aria-disabled` em zero | `integration/card_detail_variants_test.rb:79-83` ordem, `:92-93`, `:102-103`, `:111-112`; `design/card_detail_ownership_buttons_test.rb:27-28`, `:43-44` | ✅ PASS |
| 22 | +/− atualiza sem recarregar (Turbo Stream) | `integration/card_detail_variants_test.rb:164-165` `turbo-stream[action=update][target=...]`, `.ownership__step` "1" | ✅ PASS |
| 23 | "Voltar ao catálogo": bordado ≥44px, sem seta; ≥1024px na coluna lateral abaixo de divisor | `integration/card_detail_layout_test.rb:66-68`; `design/navigation_canvas_test.rb:141-145`, `:173`. **Sem teste de que o link está dentro de `.site-header__aside`** (só o botão da pasta tem, `integration/minha_pasta_test.rb:421`) | ⚠️ sem evidência da posição |
| 24 | Marca 28/32/700 em ≥1024px | `design/navigation_canvas_test.rb:157-162` (regra resolvida dentro do bloco largo) | ✅ PASS |
| 25 | Código + nome-link (`sets: [código]`), contagem à direita, barra abaixo | `integration/progress_ui_test.rb:360`, `:447-448`; `design/progress_line_test.rb:22-24`, `:61-66`, `:93-98` | ✅ PASS |
| 26 | Percentual junto da contagem; parallels como legenda; sem "Ver no catálogo"/"N sets" | `integration/progress_ui_test.rb:122` "4 / 7 · 60%", `:125`, `:456`, `:465-466` | ✅ PASS |
| 27 | `recent` por `updated_at` do usuário; `code`; sem posse no fim; isolamento | `integration/progress_order_test.rb:65-66`, `:86-88`, `:147`; `queries/set_progress_query_test.rb:776` | ✅ PASS (mutantes M1, M2, M13 mortos) |
| 28 | Ordem inválida → recent e 200 | `integration/progress_order_test.rb:96-99` (xyz), `:106-109` (vazio), `:116-119` (array) | ✅ PASS (M11 morto) |
| 29 | Chips "Recentes"/"Por código" com `aria-current` | `integration/progress_order_test.rb:167-168`, `:175-176`, `:183-184`, `:195-196` | ✅ PASS |
| 30 | ≥1024px: 4 colunas/16px; sets + coluna de 420px | `design/progress_add_cards_test.rb:52-53`, `:62-64`, `:68-71` | ✅ PASS |
| 31 | "Todas" atual, sem "×" nem nome de remoção | `integration/catalog_filter_controls_test.rb:405-406`, `:417` | ✅ PASS |
| 32 | <1024px fixo, accent, ≥44px; ≥1024px na coluna lateral | `design/progress_add_cards_test.rb:78-85`, `:97`, `:114-118`, `:123-126`, `:130`; `integration/minha_pasta_test.rb:421` | ✅ PASS |
| 33 | Campo de arquivo: surface, borda, ≥44px | `design/progress_add_cards_test.rb:147-149` | ✅ PASS |
| 34 | Capturas 390/1280, com e sem sessão | `canvas-conformance.md:3-6`; `tmp/comparacao/{catalogo,detalhe,pasta}-{390,1280}.png` existem. Evidência de revisão (AD-015), aprovação do dono pendente | ⚠️ PASS (dono pendente) |
| 35 | Cada item da checklist com resultado | `canvas-conformance.md:17-74` (três tabelas, sem item órfão) | ⚠️ PASS (dono pendente) |
| 36 | Placeholder "na mesma medida" da imagem | `integration/card_detail_image_test.rb:83-86`; medida só via `position:absolute; inset:0` (`design/card_detail_media_test.rb:43-45`) | ⚠️ spec-precision gap ("mesma medida") |
| 37 | Sem ilustrador → sem legenda | `integration/card_detail_image_test.rb:72` | ✅ PASS (M16 morto) |
| 38 | Coleção vazia: por código, "Recentes" atual | `integration/progress_order_test.rb:130-132`, `:175` | ✅ PASS |
| 39 | Um chip por cor | `integration/card_detail_header_test.rb:62-63` | ✅ PASS |
| 40 | Raridade fora da lista depois das conhecidas | `queries/catalog_filter_options_test.rb:274` `["C","X","Z"]` | ✅ PASS |

**Status**: ❌ Gaps presentes — 2 ❌ GAP (CNF-04, CNF-12), 1 ⚠️ sem evidência da posição (CNF-23), 2 spec-precision gaps (CNF-17, CNF-36), 3 PASS parciais (CNF-08, CNF-18, CNF-34/35 com dono pendente); os demais CNF casam com a spec.

---

## Discrimination Sensor

Cópia em `/tmp/claude-1000/bindr-verify` (projeto Docker `bindr-verify`, portas 3100/5433), mutação por substituição exata com restauração e `diff` contra a árvore real após cada rodada.

| Mutation | File:line | Description | Killed? |
| -------- | --------- | ----------- | ------- |
| M1 | `app/queries/set_progress_query.rb:211` | `recent`: `DESC` → `ASC` (ordem da pasta, CNF-27) | ✅ Killed (7 falhas) |
| M2 | `app/queries/set_progress_query.rb:209` | `code`: remove `IS NULL` (sem posse deixa de ir ao fim) | ✅ Killed (2) |
| M3 | `app/views/catalog/_card_tile.html.erb:42` | Remove `authenticated? &&` do selo (CNF-03) | ❌ Survived — **equivalente**: `owned_quantities` é vazio para o anônimo, o guard é redundante |
| M4 | `app/views/catalog/_card_tile.html.erb:54` | `variants.one?` → `variants.size < 3` (duas variantes mostrariam raridade) | ❌ Survived → fix task F2 |
| M5 | `app/helpers/collection_helper.rb:47` | Selo soma só a 1ª variante (CNF-02) | ✅ Killed (`catalog_tile_test.rb:74`) |
| M6 | `app/views/catalog/_card_tile.html.erb:49` | Renderiza o stepper de posse no tile (T8, posse só no detalhe) | ✅ Killed (2) |
| M7 | `app/assets/stylesheets/catalog.css:70` | `--body-grid-columns: minmax(0,1fr)` → `1fr` (regra de 360px, T16) | ✅ Killed (`navigation_canvas_test.rb:89`) |
| M8 | `app/views/progress/index.html.erb:187` | Link do nome do set perde `sets: [código]` (T10) | ✅ Killed (4) |
| M9 | `app/assets/stylesheets/catalog.css:2210` | `repeat(5,…)` → `repeat(4,…)` (CNF-12) | ✅ Killed (`catalog_grid_canvas_test.rb:51`) |
| M10 | `app/queries/catalog_query.rb:172` | `KNOWN_RARITIES` troca `C`/`UC` (CNF-11) | ✅ Killed (`:254`) |
| M11 | `app/queries/set_progress_query.rb:163` | Ordem inválida cai em `code` em vez de `recent` (CNF-28) | ✅ Killed (8) |
| M12 | `app/views/collection_items/_ownership.html.erb:103` | `aria-disabled` sempre falso em zero (CNF-21) | ✅ Killed (2) |
| M13 | `app/queries/set_progress_query.rb:240` | Junta a coleção sem `.owned` (quantidade 0 conta) | ✅ Killed (10) |
| M14 | `app/views/catalog/show.html.erb:9` | `hero` = última variante em vez da primeira (CNF-16/17) | ✅ Killed (4) |
| M15 | `app/views/catalog/index.html.erb:28` | "N cartas" usa o tamanho da página, não o total (CNF-05) | ✅ Killed (`:231`) |
| M16 | `app/views/catalog/show.html.erb:88` | Legenda de ilustrador sempre renderizada (CNF-37) | ✅ Killed (`:72`) |
| M17 | `app/assets/stylesheets/catalog.css:1428` | Remove `min-width: 0` do link do set (T16, 360px) | ✅ Killed (`progress_line_test.rb:65`) |

**Sensor depth**: P0-full manual (≥5; cobre os cinco obrigatórios: ordem da pasta M1/M2, selo M3/M5, stepper só no detalhe M6, 360px M7/M17, link do set M8)
**Result**: 17 injetadas, 15 mortas, 2 sobreviventes (1 equivalente, 1 real) — ❌ FAIL por M4

Isolamento: o `git status --porcelain` da árvore real **não é idêntico** ao baseline, por causa de `?? .specs/features/fechamento/spec.md`, criado às 22:48:43 por outro agente enquanto o sensor rodava. Nenhuma mutação tocou a árvore real (todas em `/tmp/claude-1000/bindr-verify`, já removido com `down -v`). Diferença fora do meu controle, mas registrada.

---

## Code Quality

| Principle | Status |
| --------- | ------ |
| Minimum code | ✅ — sem abstração nova além de `owned_quantity_for_card` e `in_known_order` |
| Surgical changes | ✅ — os 56 arquivos do diff estão nos `Where` das tasks |
| No scope creep | ✅ |
| Matches patterns | ✅ — `Stylesheet.resolved`, lista fechada como em `CatalogQuery`, `nav_link_to` reaproveitado |
| Spec-anchored outcome check | ❌ — CNF-12 (`:43-44` afirma `auto-fill`, a spec pede duas colunas) e CNF-04 (só 1 e 3 variantes) |
| Per-layer Coverage Expectation | ⚠️ — query 1:1 com CNF-11/27/28/38/40; views cobrem com e sem sessão; faltam CNF-04 (2 variantes) e a posição de CNF-23 |
| Every test maps to a spec requirement | ✅ — spot-check da história "Minha pasta": cada teste de `progress_order_test.rb`, `progress_line_test.rb` e `progress_add_cards_test.rb` aponta um CNF ou Done-when; `minha_pasta_test.rb:276-302` ("remover o link ... faria o teste falhar") repete asserções sem afirmar nada novo (ruído, não bloqueia) |
| Documented guidelines followed | ✅ — `CLAUDE.md` do projeto: rota `card_path(card_number)`, `assert_response :success` no detalhe, sem fixtures YAML |

---

## Edge Cases

- [x] CNF-36 placeholder sem `image_url` — `integration/card_detail_image_test.rb:83-86`
- [x] CNF-37 sem ilustrador — `:72`
- [x] CNF-38 coleção vazia — `integration/progress_order_test.rb:130-132`
- [x] CNF-39 mais de uma cor — `integration/card_detail_header_test.rb:62-63`
- [x] CNF-40 raridade desconhecida — `queries/catalog_filter_options_test.rb:274`

---

## Gate Check

- **Gate command**: `docker compose exec -T app bin/rails test && docker compose exec -T app bin/rubocop`
- **Result**: 1343 runs, 5629 assertions, 0 failures, 0 errors, 0 skips; RuboCop: 163 files, no offenses (ambos `exit 0`)
- **Test count before feature**: 1214 (base declarada em `tasks.md:55`); contagem estática de blocos `test "..."` em `test/`: 1199 em `61a0e03^` → 1324 em `dca1413`
- **Test count after feature**: 1343
- **Delta**: +129 runs (+125 blocos estáticos; a diferença são testes `def test_` que o grep não vê)
- **Skipped tests**: nenhum
- **Failures**: nenhuma
- **Remoções**: `test/integration/collection_total_test.rb` (287 linhas) por CNF-10, mais testes de posse na grade migrados por CNF-01/T3; sem queda líquida

---

## Fix Plans

### F1: Grade abaixo de 1024px não tem duas colunas (CNF-12) — Major

- **Root cause**: `catalog.css:215` mantém `repeat(auto-fill, minmax(var(--tile-min), 1fr))`; a spec revoga "número fixo de colunas" (D7) e a checklist da T5 pede `repeat(2, minmax(0, 1fr))`. O teste `catalog_grid_canvas_test.rb:43-44` foi escrito contra a implementação (`auto-fill`), não contra a spec. Em 360/390px dá duas colunas por coincidência; entre ~480 e 1023px dá três ou mais.
- **Fix task**: **Where** `app/assets/stylesheets/catalog.css`, `test/design/catalog_grid_canvas_test.rb`. **Verify** o teste `:43` passa a afirmar `repeat(2, minmax(0, 1fr))` e gap 8px fora do bloco largo, e o guarda de 360px continua verde. **Done when** o mutante "voltar a `auto-fill`" morre. Se o dono preferir manter o reflow, corrigir a spec (CNF-12, T5) antes.
- **Priority**: Major

### F2: Limite de duas impressões sem teste (CNF-04) — Major

- **Root cause**: `catalog_tile_test.rb:130-171` só cobre 1 e 3 variantes; `variants.size < 3` passa.
- **Fix task**: **Where** `test/integration/catalog_tile_test.rb`. **Verify** novo caso com duas variantes assertando "2 impressões" e ausência da raridade. **Done when** M4 morre.
- **Priority**: Major

### F3: Posição do "Voltar ao catálogo" sem asserção (CNF-23) — Minor

- **Root cause**: `card_detail_layout_test.rb:66-68` conta o link em qualquer lugar; nada exige `.site-header__aside .site-header__back`. Mover o link para o `<main>` passaria os testes (raciocínio, não medido no sensor).
- **Fix task**: **Where** `test/integration/card_detail_layout_test.rb`. **Done when** `assert_select ".site-header__aside a.site-header__back", count: 1`.
- **Priority**: Minor

### F4: Peso 600 e ordem do trigger sem asserção (CNF-18) — Minor

- **Fix task**: **Where** `test/design/` e `test/integration/card_detail_header_test.rb`. Afirmar `font-weight: var(--body-strong-weight)` em `.card-detail__trigger-label` e que o rótulo vem depois do texto do efeito.
- **Priority**: Minor

### F5: Recuo de `.catalog__head` × `.catalog__body` por `include?` (CNF-08) — Cosmetic

- **Fix task**: **Where** `test/integration/catalog_status_line_test.rb:290-297`. Comparar o padding lateral resolvido das duas regras com `assert_equal`.
- **Priority**: Cosmetic

### Fora de código

- Aprovação do dono das capturas (`tasks.md:675`): pendente por definição; não é lacuna de implementação.

---

## Requirement Traceability Update

| Requirement | Previous Status | New Status |
| ----------- | --------------- | ---------- |
| CNF-01..03, 05..07, 09..11, 13..16, 19..22, 24..33, 37..40 | Implemented | ✅ Verified |
| CNF-08, 17, 18, 34, 35, 36 | Implemented | ⚠️ Verified com ressalva (asserção frouxa, spec-precision ou dono pendente) |
| CNF-23 | Implemented | ⚠️ Posição sem evidência |
| CNF-04 | Implemented | ❌ Needs Fix (F2) |
| CNF-12 | Implemented | ❌ Needs Fix (F1) |

(`spec.md` não foi editado: o Verifier não grava fora de `validation.md` e das lições.)

---

## Summary

**Overall**: ❌ Not Ready

**Spec-anchored check**: 2 ❌ GAP (CNF-04, CNF-12); 1 sem evidência de posição (CNF-23); 2 spec-precision gaps (CNF-17, CNF-36); 3 PASS parciais (CNF-08, CNF-18, CNF-34/35); os demais casam com a spec
**Sensor**: 15/17 mutações mortas (1 sobrevivente equivalente, 1 real)
**Gate**: 1343 passed, 0 failed, RuboCop limpo

**What works**: ordem da pasta e isolamento entre usuários, selo e ausência de controle no tile, stepper e Turbo Stream no detalhe, regra de 360px, link do set, ordem de chips e a suíte inteira verde.

**Issues found**: F1 (colunas <1024px), F2 (duas impressões), F3, F4, F5.

**Next steps**: implementar F1 e F2 (ou emendar CNF-12 se o dono quiser o reflow), F3 e F4 no mesmo lote; re-verificar (ciclo 2 de no máximo 3); depois a aprovação do dono das capturas.
