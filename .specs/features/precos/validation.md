# Preços — Validation

**Date**: 2026-10-05
**Spec**: `.specs/features/precos/spec.md` (PRC-01..16; `.context/requirements.md` Req. 15.1–15.16)
**Diff range**: `284e25c..9b7fbe9` (12 commits, de `5dae3e5` a `9b7fbe9`)
**Verifier**: subagente independente (autor ≠ verificador), evidence-or-zero

## Validation verdict: PASS

**Result**: PASS na iteração 2. 16/16 critérios têm evidência `file:line` com o valor do spec. Sensor: 17/17 mutantes mortos (M15 morto pelo teste novo de `9b7fbe9`). Suíte completa: 1807 runs, 0 falhas.

## Histórico de iterações

| Iteração | HEAD | Veredito | Detalhe |
| -------- | ---- | -------- | ------- |
| 1 | `94ed82d` | FAIL | M15 sobreviveu: nenhum cenário da pasta tinha cópia com preço `0`. Gate build verde (1806 runs, RuboCop, Brakeman, fixture, imagem) |
| 2 | `9b7fbe9` | PASS | `test(precos): provar que preço zero não conta como sem preço` acrescenta `collection_item_test.rb:377`. M15 reaplicado em cópia isolada: morto. Suíte completa 1807 runs, 0 falhas. Só arquivo de teste mudou, então RuboCop, Brakeman e build não foram repetidos |

---

## Task Completion

| Task | Status | Notes |
| ---- | ------ | ----- |
| T1–T8 | ✅ Done | Todos os checkboxes marcados em `tasks.md`; Status `Done` |

---

## Spec-Anchored Acceptance Criteria

Testes citados pela linha do `test "..."`; a asserção vem entre crases.

### P1: Preço da variante vindo da ingestão

| Critério | Resultado definido no spec | `file:line` + asserção | Result |
| -------- | -------------------------- | ---------------------- | ------ |
| PRC-01 grava valor, `USD` e a data do início do import | `1.7`, `"USD"`, `started_at` do import | `test/services/ingestion/upsert_test.rb:382` — `assert_equal [ BigDecimal("1.7"), "USD", run.started_at ], preco(1)`; `test/services/ingestion/apitcg/normalize_test.rb:558` — fixture `tcgplayer:541058` dá `BigDecimal("1.7")` e `"USD"`; `upsert_test.rb:388` — segundo import troca valor e data | ✅ PASS |
| PRC-02 sem `market` válido → três nulos, sem falhar | `[nil, nil, nil]`; registro não falha | `upsert_test.rb:396` — `assert_equal [ nil, nil, nil ], preco(1)` depois de perder o `market`; `upsert_test.rb:404` — `"succeeded"`, `failed_count 0`, três nulos com `"1.70"`; `normalize_test.rb:574,580,584,590,595,600` — ausente, nulo, string, negativo, `Infinity`, `NaN`, `prices` lista/texto, acima do teto, sem `tcgplayer` → `[ nil, nil ]` | ✅ PASS |
| PRC-03 só `prices`, nunca `printings` | `prices` de topo `0.18`; `printings` sozinho → sem preço | `normalize_test.rb:607` — `assert_equal [ BigDecimal("0.18"), "USD" ], preco_de(tcgplayer)`; `normalize_test.rb:620` — `[ nil, nil ]` | ✅ PASS |
| PRC-04 ausente da fonte mantém preço, moeda e data | valor, moeda e data do primeiro import | `upsert_test.rb:412` — `assert_equal [ BigDecimal("1.7"), "USD", primeiro.started_at ], preco(1)` | ✅ PASS |
| PRC-05 tudo-ou-nada e não negativo no banco | `StatementInvalid` em cada violação; estados válidos gravam | `test/models/card_variant_price_test.rb:40,46,52` — valor sem moeda, sem data, moeda e data sem valor → `assert_raises(ActiveRecord::StatementInvalid)`; `:78` — `-0.01` recusado; `:25,34` — três preenchidos e zero gravam; `:60,72` — ISO 4217 e `NaN` (AD-022) | ✅ PASS |
| PRC-06 formato só no Normalize | nenhum outro arquivo de `app/` lê `prices`/`market` | `normalize_test.rb:626` — `assert_equal [ ...normalize.rb ], leitores` | ✅ PASS |
| PRC-07 mesmo snapshot duas vezes: mesmos preços, coleção intacta | `1.7 USD` e `nil` iguais; `quantity 3` e mesmo `card_variant_id` | `upsert_test.rb:420` — `assert_equal [ BigDecimal("1.7"), "USD" ], preco(1).first(2)`, `assert_equal 3, item.reload.quantity`, `assert_equal variante(1).id, item.card_variant_id` | ✅ PASS |

### P1: Preço no detalhe da carta

| Critério | Resultado definido no spec | `file:line` + asserção | Result |
| -------- | -------------------------- | ---------------------- | ------ |
| PRC-08 valor `US$ 1.234,56` e rótulo `TCGplayer · market · dd/mm/aaaa` | `US$ 1,70 TCGplayer · market · 01/10/2026` | `test/integration/card_detail_price_test.rb:35` — `assert_equal "US$ 1,70 TCGplayer · market · 01/10/2026", price_text(@priced)`; `test/helpers/prices_helper_test.rb:6` — `"US$ 1.234,56"`; `:22` — data em `America/Sao_Paulo` (`05/10/2026` para `2026-10-06 01:30 UTC`) | ✅ PASS |
| PRC-09 "Sem preço" | `"Sem preço"` | `card_detail_price_test.rb:49` — `assert_equal "Sem preço", price_text(@unpriced)`; `:55` — zero aparece `US$ 0,00`, não "Sem preço" | ✅ PASS |
| PRC-10 visível sem sessão | 200 sem login, com o preço | `card_detail_price_test.rb:35` — `get` sem `post session_path`, `assert_response :success` e o texto do preço; `:75` — o número de consultas não cresce de 2 para 6 variantes | ✅ PASS |

### P1: Valor estimado da pasta

| Critério | Resultado definido no spec | `file:line` + asserção | Result |
| -------- | -------------------------- | ---------------------- | ------ |
| PRC-11 valor estimado = Σ quantidade × preço, `US$ 1.234,56` | `US$ 15,10` no cenário do spec | `test/integration/progress_value_test.rb:45` — `assert_equal "US$ 15,10", ...` e `"valor estimado"`; `test/models/collection_item_test.rb:287` — `BigDecimal("15.10")`; `:365` — preço em BRL fica fora da soma em USD | ✅ PASS |
| PRC-12 "N cópias sem preço" | `2 cópias sem preço` | `progress_value_test.rb:56` — `assert_equal "2 cópias sem preço", ...`; `collection_item_test.rb:294` — `assert_equal 2, ...[:unpriced_copies]`; `collection_item_test.rb:377` — 3 cópias a `0` e 1 sem preço → `assert_equal 1, stats[:unpriced_copies]` | ✅ PASS |
| PRC-13 subtotal por set da variante | `US$ 5,10` no A, `US$ 10,00` no B | `progress_value_test.rb:74` — `assert_equal "US$ 5,10", set_value(@set_a)`, `"US$ 10,00"` no B; `collection_item_test.rb:301` — hash por `set_id`; `:318` — cópia de variante ausente entra e a soma dos subtotais é o total | ✅ PASS |
| PRC-14 só a coleção da sessão | outro usuário não altera; vê só o próprio | `progress_value_test.rb:93` — zoro vê `US$ 40,00`, `US$ 0,00` no A; `collection_item_test.rb:330` — `15.10` intacto com 50 cópias do outro, e o outro dá `85` | ✅ PASS |
| PRC-15 nenhuma cópia com preço → `US$ 0,00` | `US$ 0,00`, sem aviso | `progress_value_test.rb:106` — `assert_equal "US$ 0,00", ...`, `assert_empty ... .progress__stat-note`; `collection_item_test.rb:343,354` — `0`, `{}` para usuário vazio e `nil` | ✅ PASS |
| PRC-16 uma consulta agregada | 1 consulta no model; página continua com 3 (AD-021) | `collection_item_test.rb:375` — `assert_equal 1, queries.size`; `test/queries/set_progress_plan_test.rb:180,190` — `assert_equal 3, restantes.size`, arquivo sem edição no diff | ✅ PASS |

**Status**: 16/16 com evidência e valor do spec. Nenhum spec-precision gap.

Observações (não são gaps):

- PRC-12: a view escreve "1 cópia sem preço" no singular (`progress_value_test.rb:65`). O spec só dá a forma "N cópias sem preço"; o singular segue o padrão dos indicadores vizinhos.
- PRC-01: `numeric(10,2)` arredonda em silêncio um `market` com três casas. O snapshot medido tem no máximo duas (design, Data Models), então o valor gravado é o da fonte hoje.

---

## Edge Cases

- [x] `market` string `"1.70"` → sem preço: `normalize_test.rb:580`, `upsert_test.rb:404`.
- [x] `market` `0` → `US$ 0,00`, distinto de "Sem preço": `normalize_test.rb:570`, `card_variant_price_test.rb:34`, `card_detail_price_test.rb:55`; na pasta, `collection_item_test.rb:377` (iteração 2).
- [x] Soma exata, arredonda só na exibição: soma em `numeric` no SQL e `BigDecimal` no Ruby (`app/models/collection_item.rb:80-97`); `collection_item_test.rb:287` compara `BigDecimal("15.10")` exato.
- [x] Preço de variante ausente com data antiga aparece com a data: `card_detail_price_test.rb:63` — `"US$ 12,50 TCGplayer · market · 12/08/2026"`.
- [x] Set sem cópia com preço → `US$ 0,00`: `progress_value_test.rb:84`; `collection_item_test.rb:343` (`{ set.id => 0 }`).

---

## Discrimination Sensor

Cópia isolada por `git archive HEAD | tar -x` no scratchpad, montada em `/rails` no container (`-v <cópia>:/rails`). Sem worktree, sem `git stash`. Suíte por mutante: `test/models test/services test/helpers test/queries` + `card_detail_price_test.rb`, `progress_value_test.rb`, `minha_pasta_test.rb` (821 runs). M0, a cópia sem mutação, passou: 821 runs, 0 falhas.

| # | File | Mutação | Killed? | Por qual teste |
| - | ---- | ------- | ------- | -------------- |
| M1 | `app/services/ingestion/apitcg/normalize.rb:253` | lê `printings[0].prices` antes de `prices` | ✅ Killed | `normalize_test.rb:607`, `:620` |
| M2 | `app/services/ingestion/upsert.rb:108` | mantém o preço antigo quando a fonte perde `market` | ✅ Killed | `upsert_test.rb:396` |
| M3 | `app/models/collection_item.rb:96` | remove o `FILTER (WHERE price_currency = 'USD')` | ✅ Killed | `collection_item_test.rb:365` |
| M4 | `app/models/collection_item.rb:80` | remove `.owned` | ✅ Killed | testes de quantidade zero de `collection_item_test.rb` e `minha_pasta_test.rb` |
| M5 | `app/models/collection_item.rb:80` | troca `for_user(user)` por todos os itens | ✅ Killed | `collection_item_test.rb:330` e outros 8 |
| M6 | `app/helpers/prices_helper.rb:12` | milhar sem separador | ✅ Killed | `prices_helper_test.rb:6` |
| M7 | `db/structure.sql` | remove `card_variants_price_complete_check` | ✅ Killed | `card_variant_price_test.rb:40`, `:46`, `:52` |
| M8 | `db/structure.sql` | remove `card_variants_price_amount_check` | ✅ Killed | `card_variant_price_test.rb:78` |
| M9 | `app/services/ingestion/upsert.rb:119` | `price_observed_at = Time.current` em vez do início do import | ✅ Killed | `upsert_test.rb:382`, `:388`, `:412` |
| M10 | `app/helpers/prices_helper.rb:16` | data em UTC | ✅ Killed | `prices_helper_test.rb:22` |
| M11 | `normalize.rb:255` | aceita `market` negativo | ✅ Killed | `normalize_test.rb:584` |
| M12 | `normalize.rb:255` | converte string numérica com `Float()` | ✅ Killed | `normalize_test.rb:580`, `upsert_test.rb:404` |
| M13 | `app/views/catalog/show.html.erb:290` | preço zero vira "Sem preço" | ✅ Killed | `card_detail_price_test.rb:55` |
| M14 | `app/views/progress/index.html.erb:266` | subtotal do set mostra o total da pasta | ✅ Killed | `progress_value_test.rb:74`, `:84`, `:93` |
| M15 | `app/models/collection_item.rb:97` | `unpriced_copies` também conta `price_amount = 0` | ✅ Killed (iteração 2) | `collection_item_test.rb:377`. Na iteração 1 sobreviveu |
| M16 | `normalize.rb:258` | remove o teto `MAX_PRICE` | ✅ Killed | `normalize_test.rb:595` |
| M17 | `normalize.rb:239` | moeda `USD` mesmo sem valor | ✅ Killed | 20 falhas e 4 erros, entre eles `normalize_test.rb:574` e `upsert_test.rb:404` |

**Sensor depth**: P0 (integridade do dado da ingestão e valor da coleção), 17 mutantes manuais.
**Result**: 17/17 killed na iteração 2 — PASS. Na iteração 2, M0 (cópia sem mutação) passou com 822 runs.

Isolamento: `git status --porcelain` da árvore real antes e depois é igual (`?? .playwright-mcp/`). A cópia foi apagada; os arquivos de cache criados como root foram removidos pelo próprio container. M7 e M8 recarregaram o banco de teste com o `structure.sql` mutado. A rodada seguinte o recarregou com o original, e `card_variant_price_test.rb` passou de novo na árvore real (9 runs, 0 falhas).

---

## Code Quality

| Principle | Status |
| --------- | ------ |
| Minimum code | ✅ — helper de 2 métodos, uma consulta reaproveitada, sem tabela nova |
| Surgical changes | ✅ — `set_progress_plan_test.rb` intacto; NAV-37 emendado com aval do dono, registrado no teste |
| No scope creep | ✅ — nada de BRL, histórico, wishlist ou deck |
| Matches patterns | ✅ — `CHECK` no banco como `art_kind`, relógio injetado (AD-009), formato da fonte só no Normalize |
| Spec-anchored outcome check | ✅ — asserções em strings e valores exatos do spec |
| Per-layer Coverage Expectation | ✅ — preço zero coberto na agregação desde a iteração 2 |
| Every test maps to a spec requirement | ✅ — `MAX_PRICE`, ISO 4217 e `NaN` derivam de PRC-02/PRC-05 e da AD-022 |
| Documented guidelines followed | ✅ — `CLAUDE.md` (gates, Docker, integração no lugar de system test), AD-021, AD-022 |

---

## Gate Check

- **Gate command** (build, com o override sem portas): `docker compose build && bin/rails test && bin/rubocop && bin/brakeman -q --no-pager && python3 spec/verify_fixture.py`
- **Result (iteração 1)**: 1806 runs, 7373 assertions, 0 failures, 0 errors, 0 skips; RuboCop 218 arquivos, 0 ofensas; Brakeman sem avisos; `verify_fixture.py`: "todas as verificações passaram"; imagem `bindr-tcg-app` construída (exit 0).
- **Test count before feature**: 1751 (`tasks.md`, T1)
- **Result (iteração 2)**: `bin/rails test` 1807 runs, 7376 assertions, 0 failures, 0 errors, 0 skips
- **Test count after feature**: 1807
- **Delta**: +56
- **Skipped tests**: nenhum
- **Failures**: nenhuma

---

## Fix Plans

### Fix 1: cópia de preço zero na pasta sem teste (M15)

- **Root cause**: nenhum cenário de `collection_stats_for` nem de `progress_value_test.rb` tem cópia de variante com `price_amount = 0`. O edge case do spec diz que zero é preço válido, distinto de "Sem preço". A pasta conta certo hoje, mas nenhum teste protege isso.
- **Fix task**: em `test/models/collection_item_test.rb`, acrescentar um teste com uma cópia de variante a `0` USD ao lado de uma sem preço. Asserir `unpriced_copies` igual só às cópias sem preço, `estimated_value` inalterado e o subtotal do set. Opcional: o mesmo na integração (`progress_value_test.rb`), asserindo o texto "N cópias sem preço".
- **Verify**: reaplicar M15 (`FILTER (WHERE card_variants.price_amount IS NULL OR card_variants.price_amount = 0)`) numa cópia isolada; o teste novo precisa falhar.
- **Priority**: Minor
- **Status**: ✅ resolvido em `9b7fbe9`, M15 morto na iteração 2

---

## Requirement Traceability Update

| Requirement | Previous Status | New Status |
| ----------- | --------------- | ---------- |
| PRC-01..PRC-16 | Implemented | ✅ Verified |

---

## Summary

**Overall**: ✅ Ready

**Spec-anchored check**: 16/16 critérios com o valor do spec; 0 spec-precision gaps.
**Sensor**: 17/17 killed.
**Gate**: 1807 passed, 0 failed.

**What works**: ingestão do preço com data do import, tudo-ou-nada no banco, ausente mantém o preço, idempotência com coleção intacta, detalhe público com formato e rótulo, valor da pasta e subtotais numa consulta, isolamento por usuário.

**Issues found**: nenhum aberto. M15 foi resolvido na iteração 2.

---

## Fechamento do Verifier

- Iteração 1: `validate_state.py precos` → exit 1 (veredito FAIL). Lição L-062 registrada como candidata (`surviving_mutant`, `app/models/collection_item.rb:97 (M15)`).
- Iteração 2: `validate_state.py precos` → **exit 0** (0 erros).
