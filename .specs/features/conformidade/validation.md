# Conformidade com o canvas — Validation

**Date**: 2026-09-29
**Spec**: `.specs/features/conformidade/spec.md` (CNF-01..CNF-41)
**Diff range**: `61a0e03^..dec1dd9` (HEAD = `dec1dd9`; 45 commits, 64 arquivos, +6542 −1296; testes: 32 arquivos, +2401 −556)
**Verifier**: sub-agente independente (autor ≠ verificador), Sonnet, **ciclo 3** (último permitido) — novo, não escreveu a feature nem fez os ciclos 1 e 2. Checagem re-derivada do zero a partir de `spec.md`, `tasks.md` e `canvas-conformance.md`; os relatórios dos ciclos 1 e 2 foram comparados só no fim.

**Veredito: PASS ✅** — os 41 CNF têm evidência `arquivo:linha` que casa com o resultado definido na spec, exceto duas observações que **não reprovam**: CNF-17 (⚠️ spec-precision, "forma compacta" sem medida, DECISÃO-DO-DONO já sinalizada) e a aprovação das capturas pelo dono na T12 (pendência adiada por decisão dele). Gate verde (1350 runs, 0 falhas, RuboCop limpo) e o sensor injetou 10 mutantes na cópia, 10 mortos, 0 sobreviventes. As lacunas G1 (CNF-41, 44px) e G2 (posição do selo) do ciclo 2 estão fechadas pelos commits `1085994` (T23) e `dec1dd9` (T24).

## Histórico: ciclo 1 = FAIL (git a5dd965), ciclo 2 = FAIL (git 136a253)

- **Ciclo 1** (`git show a5dd965:.specs/features/conformidade/validation.md`, range `61a0e03^..dca1413`): 17 mutantes, 15 mortos, M3 equivalente e M4 real. Lacunas: F1 CNF-12 (`auto-fill` abaixo de 1024px), F2 CNF-04 (limite de duas impressões), F3 CNF-23 (posição de "Voltar"), F4 CNF-18 (peso 600 e ordem do trigger), F5 CNF-08 (recuo por `include?`), spec-precision CNF-17 e CNF-36.
- **Ciclo 2** (`git show 136a253:.specs/features/conformidade/validation.md`, range `61a0e03^..c78fd80`, 1348 runs): as lacunas do ciclo 1 estavam fechadas; reprovou por G1 (CNF-41: `.catalog__empty-reset` com `min-height: 24px`, mutante h sobrevivia) e G2 (posição do selo sem asserção, CNF-02/CNF-16).
- **Ciclo 3 (este)**: G1 e G2 fechadas (T23 `1085994`, T24 `dec1dd9`), cada uma com mutante que agora morre (h e i abaixo). T22 foi **descartada de propósito** (`tasks.md:869`) e não é lacuna.

---

## Task Completion

| Task | Status | Notes |
| ---- | ------ | ----- |
| T1–T11 | ✅ Done | Checkboxes marcados em `tasks.md:163-513`; `set_progress_plan_test.rb` só com as edições aceitas em AD-017/AD-018 |
| T12 | ⚠️ Partial | Único item aberto (`tasks.md:712`): "O dono comparou as capturas com os artboards e aprovou". **Pendência adiada por decisão do dono; não reprova.** Capturas e `canvas-conformance.md:17-74` existem |
| T13–T17 | ✅ Done | Correções da conferência de 2026-09-28 |
| T18 | ✅ Done | CNF-12 abaixo de 1024px: `catalog.css:215` `repeat(2, minmax(0, 1fr))` |
| T19 | ✅ Done | CNF-04 (2 variantes), isolamento do selo, selo do detalhe por variante |
| T20 | ✅ Done | CNF-23, CNF-18, CNF-08 sem asserção frouxa |
| T21 | ✅ Done | Emendas de spec (CNF-06, 08, 17, 36, 41) |
| T22 | ⏭️ Descartada | De propósito (`tasks.md:869`): não é lacuna |
| T23 | ✅ Done | `catalog.css:365` `min-height: 44px`; teste `catalog_status_line_test.rb:216-224` |
| T24 | ✅ Done | `ownership_badge_test.rb:94-115` |

---

## Spec-Anchored Acceptance Criteria

Evidência lida nos testes e na folha, não em mensagens de commit. Arquivos de teste em `test/`; CSS em `app/assets/stylesheets/catalog.css`. "Resolved" = `Stylesheet.resolved` (última declaração vence; `@narrow_rules`/`wide_block` recortam o bloco de 1024px).

| CNF | Spec-defined outcome | `file:line` + assertion | Result |
| --- | -------------------- | ----------------------- | ------ |
| 01 | Nenhum controle de posse no tile | `integration/catalog_tile_test.rb:41-44` `assert_select ".card-tile form", 0` / `button` / `.ownership`; `:54-56` anônimo | ✅ PASS |
| 02 | Selo com o total das variantes, accent/on-accent, "N cópias"/"1 cópia", canto superior direito | `integration/catalog_tile_test.rb:74-76` `assert_equal "3 cópias", badge["aria-label"]`, `:90` "1 cópia"; `design/ownership_badge_test.rb:69-70` accent/on-accent; `:97-101` `position` `absolute`, `top`/`right` `var(--space-2)`, `assert_nil` de `bottom`/`left` (G2 fechada) | ✅ PASS |
| 03 | Sem selo: anônimo ou quantidade zero | `integration/catalog_tile_test.rb:102`, `:113`, `:125` (`assert_nil ...badge`); isolamento `:138`, `:151` | ✅ PASS |
| 04 | 1 variante → raridade; >1 → "N impressões" | `integration/catalog_tile_test.rb:163` `"SR"`, `:174` `"2 impressões"`, `:184` `"3 impressões"`, `:196`, `:208` | ✅ PASS |
| 05 | "N cartas [· M filtros ativos]", total do resultado | `integration/catalog_status_line_test.rb:62`, `:93`, `:189`, `:244` `/^\s*36 cartas\s*·\s*1 filtro ativo\s*$/`, `:252-253` | ✅ PASS |
| 06 | Com filtro e resultado: "Limpar filtros" bordado ≥44px, preserva `sort`/`dir` | `integration/catalog_status_line_test.rb:81-85`, `:128-147` (preserva), `:262` `assert_operator ... :>=, 44`, `:263` borda presente | ✅ PASS |
| 07 | Convite anônimo uma vez, na linha de status | `integration/catalog_status_line_test.rb:271` `count: 1`, `:272` href `new_session_path` dentro de `.catalog__status`, `:280` com sessão `count: 0` | ✅ PASS |
| 08 | ≥1024px: busca e status na mesma linha, recuo igual, busca `30rem` | `integration/catalog_status_line_test.rb:300` `assert_equal "flex"`, `:303` `assert_equal "30rem", search_rule.fetch("width")`; `:345-347` `assert_equal head_left_px, body_left_px` e direita | ✅ PASS |
| 09 | Rótulo "Buscar por nome ou card_number", placeholder "OP01-024" | `integration/catalog_status_line_test.rb:288-289` | ✅ PASS |
| 10 | Sem "Sua coleção" | `integration/catalog_status_line_test.rb:357` `"#catalog_owned_total", 0`; `:377` sem turbo-stream | ✅ PASS |
| 11 | Cores Red…Yellow, raridades C, UC, R, SR, SEC, L + alfabético, tipo capitalizado, URL crua | `queries/catalog_filter_options_test.rb:185-225`, `:226-256`; `integration/catalog_filter_controls_test.rb:370-388` | ✅ PASS |
| 12 | ≥1024px: 5 colunas/16px; abaixo: 2 colunas/8px; 360px sem scroll | `design/catalog_grid_canvas_test.rb:44-45` `assert_equal "repeat(2, minmax(0, 1fr))"`, gap 8; `:51-52` `repeat(5, ...)`, gap 16; `design/layout_test.rb:36`; `catalog.css:215` (F1 do ciclo 1 fechada) | ✅ PASS |
| 13 | Tile 16px, arte sunken com 8px, divisor 1px `--border` | `design/catalog_grid_canvas_test.rb:58-60`, `:66-67`, `:73-74` | ✅ PASS |
| 14 | <1024px: miniatura ao lado do título, `<details>`, sem JS | `integration/card_detail_hero_image_test.rb:24-33`, `:42-51` (nº de `<script>` igual); `design/card_detail_media_test.rb:19-20` 155×217 | ✅ PASS |
| 15 | ≥1024px: coluna de 320px sempre visível | `design/card_detail_media_test.rb:52`, `:58-62` `content-visibility: visible`, `:69` `320.0`, `:87` `\A320px` | ✅ PASS |
| 16 | Selo da 1ª variante sobre a imagem; legenda "Ilustração: {nome}" | `integration/card_detail_image_test.rb:32-34`, `:68-70` (1 cópia, não a soma 4), `:79`, `:88`; `design/ownership_badge_test.rb:105-114` posição, `top`/`right` `var(--space-3)` em ≥1024px | ✅ PASS |
| 17 | Chips tipo/raridade(1ª)/cor + counter ≥1024px; "{set} · {código}"; demais campos "compactos" | `integration/card_detail_header_test.rb:32-34`, `:48-49`, `:76`, `:87`, `:101`, `:184` (counter oculto <1024px), `:190` (visível ≥1024px). **"Forma compacta" sem medida na spec** | ⚠️ Spec-precision gap (DECISÃO-DO-DONO já sinalizada; não reprova) |
| 18 | Trigger em "Efeito", depois do efeito, rótulo 600, quebras | `integration/card_detail_header_test.rb:115-119`, `:144` `assert_equal "600", resolved_weight`, `:152` `assert_operator trigger_label_pos, :>, effect_text_pos`; `integration/card_detail_test.rb:262`, `:283` `<br` | ✅ PASS |
| 19 | "Variantes na pasta" + divisor 1px `--border` | `integration/card_detail_variants_test.rb:37`; `design/card_detail_variants_grid_test.rb:90` `"1px solid var(--border)"` | ✅ PASS |
| 20 | Linha: código, "{raridade} · {arte}", set, miniatura menor, rótulos fora da vista | `integration/card_detail_variants_test.rb:45-50`, `:56-58`; `design/card_detail_variants_grid_test.rb:57-58` 80×112 (vs 320), `:77-83` recorte sem `display:none` | ✅ PASS |
| 21 | `−` `[n]` `+` na ordem; 44×44; "não tenho" e `aria-disabled` em zero | `integration/card_detail_variants_test.rb:79-83`, `:92-93`, `:102-103`, `:111-112`; `design/card_detail_ownership_buttons_test.rb:27-28`, `:43-44` | ✅ PASS |
| 22 | +/− atualiza sem recarregar | `integration/card_detail_variants_test.rb:164-165` `turbo-stream[action=update][target=...]` com `.ownership__step` "1" | ✅ PASS |
| 23 | "Voltar" bordado ≥44px sem seta; ≥1024px na coluna lateral abaixo de divisor 1px | `integration/card_detail_layout_test.rb:69-71` `.site-header__aside a.site-header__back` `count: 1`, sem "←", `:73` fora de `main`; `design/navigation_canvas_test.rb:141-145` (44px, borda), `:173` divisor `1px solid var(--border)` | ✅ PASS |
| 24 | Marca 28/32/700 em ≥1024px | `design/navigation_canvas_test.rb:157-162` (tokens `--display-*` na regra do bloco largo); `design/tokens_test.rb:22-24` `28px` / `32px` / `700` | ✅ PASS |
| 25 | Código e nome-link à esquerda, "possuídas / total" à direita, barra abaixo | `integration/progress_ui_test.rb:327-364`, `:442-448`; `design/progress_line_test.rb:20-31`, `:56-70`, `:83-100` | ✅ PASS |
| 26 | Percentual junto da contagem; parallels como legenda; sem "Ver no catálogo" nem contagem de sets | `integration/progress_ui_test.rb:116-128`, `:451-457`, `:460-466` | ✅ PASS |
| 27 | `recent` por `updated_at` do usuário; `code`; sem posse no fim; isolamento | `integration/progress_order_test.rb:58-67`, `:79-90`, `:135-150`; `queries/set_progress_query_test.rb:706-780` | ✅ PASS |
| 28 | Ordem inválida → "Recentes" e 200 | `integration/progress_order_test.rb:92-121` (xyz, vazio, array) | ✅ PASS |
| 29 | Chips "Recentes"/"Por código", `aria-current` na ordem aplicada | `integration/progress_order_test.rb:157-196`; `design/progress_line_test.rb:104-120` | ✅ PASS |
| 30 | ≥1024px: 4 colunas/16px; sets + coluna de 420px | `design/progress_add_cards_test.rb:50-53` `repeat(4, ...)`, 16; `:60-65` `minmax(0, 1fr) 420px`; `integration/minha_pasta_test.rb:481-490` | ✅ PASS |
| 31 | "Todas" atual, sem "×" nem nome de remoção | `integration/catalog_filter_controls_test.rb:398-406` `aria-current` `"true"`, `assert_nil ...["aria-label"]` | ✅ PASS |
| 32 | <1024px fixo, accent, ≥44px; ≥1024px na coluna lateral sob divisor | `design/progress_add_cards_test.rb:76-99`, `:111-127`, `:129-131` (divisor `1px solid var(--border)`) | ✅ PASS |
| 33 | Campo de arquivo: surface, borda, ≥44px | `design/progress_add_cards_test.rb:142-149` | ✅ PASS |
| 34 | Capturas 390/1280, com e sem sessão, ao lado do artboard | `canvas-conformance.md:3-6`; `tmp/comparacao/` (evidência de revisão, AD-015). **Aprovação do dono pendente (T12), adiada por decisão dele** | ✅ PASS (pendência do dono registrada, não reprova) |
| 35 | Cada item da checklist com resultado (conforme / CNF / Out of Scope) | `canvas-conformance.md:17-74` (três tabelas, nenhum item sem resultado) | ✅ PASS (pendência do dono registrada, não reprova) |
| 36 | Placeholder na mesma medida: 155×217 na miniatura; 320×448 na coluna | `design/card_detail_media_test.rb:19-20` (155×217), `:36-47` (placeholder `absolute` sobre a moldura), `:69` `320.0` com `:74` `5 / 7` (320×7/5 = 448, exato); `integration/card_detail_image_test.rb:99-102`; `integration/card_detail_hero_image_test.rb:74-77` | ✅ PASS |
| 37 | Sem ilustrador, sem legenda | `integration/card_detail_image_test.rb:88` `count: 0` | ✅ PASS |
| 38 | Coleção vazia: por código, "Recentes" atual | `integration/progress_order_test.rb:122-131`, `:171-178` | ✅ PASS |
| 39 | Um chip por cor | `integration/card_detail_header_test.rb:62-63` | ✅ PASS |
| 40 | Raridade fora da lista depois das conhecidas | `queries/catalog_filter_options_test.rb:257-275` | ✅ PASS |
| 41 | Com filtro e zero resultados: "Limpar filtros" em `.catalog__empty`, ≥44px, nenhum link em `.catalog__status` | `integration/catalog_status_line_test.rb:155` `.catalog__status a` `count: 0`, `:156` `.catalog__empty a` `count: 1`, `:211`, `:223` `assert_operator ... :>=, 44`; `catalog.css:365` `min-height: 44px` (G1 do ciclo 2 fechada) | ✅ PASS |

**Status**: ✅ 40/41 CNF casam com o resultado definido na spec; ⚠️ 1 spec-precision gap (CNF-17, DECISÃO-DO-DONO). Nenhum ❌.

### Done-when de T1–T21, T23 e T24

Itens que só existem como "Done when" (sem CNF próprio) e suas evidências:

| Task | Done-when | `file:line` | Result |
| ---- | --------- | ----------- | ------ |
| T1 | Item com `quantity: 0` não conta na ordem; `set_progress_plan_test.rb` só com edição aceita | `queries/set_progress_query_test.rb:706-780`; AD-017/AD-018 | ✅ |
| T4 | Sort/dir preservados; convite anônimo sem duplicar | `integration/catalog_status_line_test.rb:128-147`, `:271` | ✅ |
| T5 | Guarda de 360px continua passando | `design/layout_test.rb:36`, `:60`; gate full verde | ✅ |
| T13 | Código sem quebra, rótulo da busca 13/18 muted, topo sem vão | `design/catalog_grid_canvas_test.rb:79-134` | ✅ |
| T14 | Imagem `align-self: start`; `[n]` 44px; linha em ≥1024px `flex`/`center`/16px | `design/card_detail_media_test.rb:98-103`; `design/card_detail_ownership_buttons_test.rb:40-44`; `design/card_detail_variants_grid_test.rb:105-117` | ✅ |
| T15 | Nome do set com reticências; chips de ordem 44px; `.progress__add-cards` accent em ≥1024px | `design/progress_line_test.rb:56-70`, `:114-120`; `design/progress_add_cards_test.rb:111-119` | ✅ |
| T16 | `.progress-set` e `body` com `minmax(0, 1fr)` | `design/progress_line_test.rb:71-75`; `design/layout_test.rb`; medição de `scrollWidth` em `canvas-conformance.md:13-15` | ✅ |
| T17 | "à pasta" só abaixo de 1024px, link único | `design/progress_add_cards_test.rb:121-127`; `integration/minha_pasta_test.rb:518-525` (um link no DOM) | ✅ |
| T18 | Teste falha se a regra voltar a `auto-fill` | `design/catalog_grid_canvas_test.rb:44` (mutante a, morto) | ✅ |
| T19 | Duas variantes; isolamento; selo por variante | `integration/catalog_tile_test.rb:166-175`, `:128-152`; `integration/card_detail_image_test.rb:57-72` | ✅ |
| T20 | Voltar dentro de `.site-header__aside`; peso e ordem do trigger; recuo e largura por `assert_equal` | `integration/card_detail_layout_test.rb:69`; `integration/card_detail_header_test.rb:144`, `:152`; `integration/catalog_status_line_test.rb:303`, `:345-347` | ✅ |
| T21 | Spec emendada | `spec.md:113-116`, `:143`, `:204` (CNF-06, 41, 08, 17, 36) | ✅ (CNF-17 aberto por omissão do canvas, registrado) |
| T23 | `.catalog__empty-reset` 44px; teste falha com 24px e com 0 | `catalog.css:365`; `integration/catalog_status_line_test.rb:216-224` (mutante h, morto) | ✅ |
| T24 | Posição do selo afirmada; falha sem `top`/`right` | `design/ownership_badge_test.rb:94-115` (mutante i, morto) | ✅ |

### Comparação com os ciclos anteriores

| Lacuna anterior | Situação no ciclo 3 | Evidência |
| --- | --- | --- |
| Ciclo 1 F1: CNF-12 abaixo de 1024px | ✅ fechada | `catalog.css:215`; `catalog_grid_canvas_test.rb:44`; mutante a morto |
| Ciclo 1 F2: CNF-04, duas impressões | ✅ fechada | `catalog_tile_test.rb:174`; mutante b morto |
| Ciclo 1 F3: CNF-23, posição de "Voltar" | ✅ fechada | `card_detail_layout_test.rb:69`; mutante d morto |
| Ciclo 1 F4: CNF-18, peso e ordem do trigger | ✅ fechada | `card_detail_header_test.rb:144`, `:152` |
| Ciclo 1 F5: CNF-08, recuo por `include?` | ✅ fechada | `catalog_status_line_test.rb:303`, `:345-347`; mutante e morto |
| Ciclo 1: CNF-36 spec-precision | ✅ fechada (spec define 155×217 e 320×448) | `spec.md:204`; `card_detail_media_test.rb:19-20`, `:69`, `:74` |
| Ciclo 1: CNF-17 spec-precision | ⚠️ **aberta** (canvas omisso; DECISÃO-DO-DONO) | `spec.md:143`; `canvas-conformance.md:48` |
| Ciclo 2 G1: CNF-41, 44px em `.catalog__empty-reset` | ✅ fechada | `catalog.css:365`; `catalog_status_line_test.rb:216-224`; mutantes g e h mortos |
| Ciclo 2 G2: posição do selo (CNF-02, 16) | ✅ fechada | `ownership_badge_test.rb:94-115`; mutante i morto |

---

## Discrimination Sensor

Cópia em `/tmp/claude-1000/bindr-verify` (rsync sem `.git`, projeto Docker `bindr-verify`, db em 5433 por `docker-compose.override.yml` só na cópia). Cada mutação editada na cópia, só os testes do comportamento rodados, arquivo restaurado a partir da árvore real. Nada tocou a árvore real.

| Mutação | File:line | Description | Killed? |
| ------- | --------- | ----------- | ------- |
| a (CNF-12) | `catalog.css:215` | `repeat(2, minmax(0, 1fr))` → `repeat(auto-fill, minmax(var(--tile-min), 1fr))` fora do bloco largo | ✅ Killed (`catalog_grid_canvas_test.rb:44`) |
| b (CNF-04) | `_card_tile.html.erb:54` | `variants.one?` → `variants.size < 3` (duas variantes mostram raridade) | ✅ Killed (`catalog_tile_test.rb:174`) |
| c (CNF-16) | `show.html.erb:10` | `owned_quantity(hero)` → `owned_quantity_for_card(@card)` (soma da carta) | ✅ Killed (`card_detail_image_test.rb`, teste "1 cópia, não a soma") |
| d (CNF-23) | `show.html.erb:2-4` | "Voltar ao catálogo" movido para fora de `.site-header__aside` (para dentro do `<main>`) | ✅ Killed (`card_detail_layout_test.rb:69`) |
| e (CNF-08) | `catalog.css:2167` | `.catalog__search` `30rem` → `28rem` | ✅ Killed (`catalog_status_line_test.rb:303`) |
| f1 (CNF-27, T1) | `set_progress_query.rb:211` | `recent`: `DESC NULLS LAST` → `ASC NULLS LAST` | ✅ Killed (7 falhas, `set_progress_query_test.rb:747`, `progress_order_test.rb:65,99`) |
| f2 (CNF-27, T1) | `set_progress_query.rb:209` | `code`: remove `MAX(...) IS NULL` (sem posse deixa de ir ao fim) | ✅ Killed (2 falhas, `progress_order_test.rb:88`, `set_progress_query_test.rb:776`) |
| g (CNF-41) | `index.html.erb:261` | Remove "Limpar filtros" de `.catalog__empty` | ✅ Killed (4 falhas, `catalog_status_line_test.rb:156`, `:176`, `:220`) |
| h (CNF-41) | `catalog.css:365` | `.catalog__empty-reset` `min-height: 44px` → `0` | ✅ Killed (`catalog_status_line_test.rb:223`) |
| i (CNF-02, 16) | `catalog.css:324-325` | Remove `top`/`right` do selo (posição) | ✅ Killed (`ownership_badge_test.rb:98`) |

**Sensor depth**: P0-full manual (10 mutações; cobre os itens a–i pedidos)
**Result**: 10/10 killed — PASS ✅

**Isolamento**: `git status --porcelain` da árvore real antes: `?? .playwright-mcp/`; depois do `down -v` e da remoção da cópia: `?? .playwright-mcp/` — **igual ao baseline**. Nota operacional: o `rm` comum não removeu arquivos de cache criados como root pelo contêiner na cópia; limpei com um contêiner descartável e o diretório e o projeto `bindr-verify` não existem mais.

---

## Code Quality

| Principle | Status |
| --------- | ------ |
| Minimum code | ✅ |
| Surgical changes | ✅ — T23 mexeu em `catalog.css` e num teste; T24 só em `ownership_badge_test.rb` |
| No scope creep | ✅ |
| Matches patterns | ✅ — `Stylesheet.resolved`, `wide_block`, `nav_link_to`, lista fechada de ordem como no `CatalogQuery` |
| Spec-anchored outcome check (asserted values match spec) | ✅ — as asserções usam o valor da spec (`repeat(2…)`, `30rem`, 44, `600`), não o da implementação; exceção registrada: CNF-17 (spec sem medida) |
| Per-layer Coverage Expectation | ✅ — query 1:1 com CNF-11/27/28/38/40 e isolamento entre dois usuários; views com e sem sessão; folha lida com `Stylesheet.resolved` recortado |
| Every test in scope maps to an AC, edge case or Done-when | ✅ — spot-check da história "Minha pasta": cada teste de `progress_order_test.rb`, `progress_line_test.rb` e `progress_add_cards_test.rb` aponta CNF-25..33 ou Done-when de T10/T11/T15/T17. Ruído sem risco: `minha_pasta_test.rb` repete asserções de posição já dadas por `progress_add_cards_test.rb:129-131` |
| Documented guidelines followed | ✅ — `CLAUDE.md` do projeto: `card_path(card_number)`, `assert_response :success` no detalhe, sem fixtures YAML, autorização a partir de `Current.user` (`catalog_tile_test.rb:141-151`) |

---

## Edge Cases

- [x] CNF-36 placeholder sem `image_url`: `integration/card_detail_image_test.rb:99-102`, `integration/card_detail_hero_image_test.rb:74-77`
- [x] CNF-37 sem ilustrador: `integration/card_detail_image_test.rb:88`
- [x] CNF-38 coleção vazia: `integration/progress_order_test.rb:122-131`
- [x] CNF-39 mais de uma cor: `integration/card_detail_header_test.rb:62-63`
- [x] CNF-40 raridade desconhecida: `queries/catalog_filter_options_test.rb:257-275`

---

## Gate Check

- **Gate command**: `docker compose exec -T app bin/rails test && docker compose exec -T app bin/rubocop` (com `DOCKER_CONFIG` apontando para `{}`)
- **Result**: 1350 runs, 5656 assertions, 0 failures, 0 errors, 0 skips; RuboCop: 163 files inspected, no offenses detected
- **Test count before feature**: 1214 (base declarada em `tasks.md:55`; contagem estática de `test "..."`/`def test_` em `61a0e03^`: 1214)
- **Test count after feature**: 1350 (estática em `HEAD`: 1350)
- **Delta**: +136 testes (32 arquivos de teste tocados, +2401 −556 linhas); a contagem não caiu
- **Skipped tests**: nenhum
- **Failures**: nenhuma

---

## Fix Plans

Nenhum. Sem lacuna de critério e sem mutante sobrevivente.

---

## Requirement Traceability Update

| Requirement | Previous Status | New Status |
| ----------- | --------------- | ---------- |
| CNF-01..16, 18..33, 36..41 | Implemented | ✅ Verified |
| CNF-17 | Implemented | ⚠️ Verified com spec-precision gap ("forma compacta"; DECISÃO-DO-DONO) |
| CNF-34, CNF-35 | Implemented (aprovação do dono pendente) | ✅ Verified; aprovação do dono segue pendente (T12) |

---

## Summary

**Overall**: ✅ Ready (com duas pendências do dono que não reprovam)

**Spec-anchored check**: 40/41 CNF casam com o resultado da spec; 1 spec-precision gap (CNF-17)
**Sensor**: 10/10 mutantes mortos
**Gate**: 1350 passed, 0 failed, RuboCop limpo

**What works**: grade de duas e cinco colunas, selo por total e por variante com posição afirmada, "N impressões" no limite de duas, status em frase única, "Limpar filtros" com 44px na linha e no estado vazio, detalhe com miniatura/coluna, stepper, "Voltar" na coluna lateral, pasta ordenada por atividade com isolamento entre usuários.

**Issues found (não bloqueiam)**:
1. CNF-17: a spec pede "forma compacta" para custo, power, life, attribute, traits e block sem medida, e o canvas não os desenha (`canvas-conformance.md:48`). Fica como DECISÃO-DO-DONO; nenhum teste consegue discriminar um valor que a spec não define.
2. T12: aprovação das capturas pelo dono adiada por decisão dele (`tasks.md:712`).

**Next steps**: o dono decide a medida de CNF-17 e aprova as capturas; depois marcar `tasks.md:712`.
