# Troca da fonte do catálogo para a apitcg (`fonte-apitcg`) Validation

**Date**: 2026-10-02 (re-verificação focada no SRC-31, ciclo 2 de 3; ciclo 1 em 2026-10-01)
**Spec**: `.specs/features/fonte-apitcg/spec.md` (SRC-01..SRC-36 + Success Criteria)
**Diff range**: `b026f3b..HEAD` (`43b62ae`), 35 commits, 86 arquivos
**Verifier**: sessão nova e independente (author ≠ verifier). Nada do código ou dos testes foi escrito por este verifier; evidência re-derivada do spec e do código. Árvore real só lida; sensor em cópia descartada.

**Result**: PASS ✅ (com ressalva menor). Nenhuma lacuna de comportamento nem de evidência: Fix 1–6 do ciclo anterior fecham de fato, o gate build sai 0 e o sensor P0 matou 39/39 mutantes. SRC-31 re-verificado de forma independente em 2026-10-02 (ver *Re-verificação SRC-31*): fechado com a emenda de 20h (D-14), 7.252 comuns, 0 mudados. Ressalvas, nenhuma bloqueante: (1) Fix 7 só parcial, débito Minor aceito (asserções vacuosas restantes); (2) housekeeping de checkboxes (ver *Task Completion*).

---

## Ciclo anterior

O ciclo 0 deu FAIL por lacunas de evidência, sem defeito de comportamento (38/38 mutantes mortos, 1534 runs verdes): Fix 1 `brakeman` saía 5 por versão defasada (8.0.6 contra 8.1.0), Fix 2 SRC-36 sem teste de `failed_count`/status, Fix 3 SRC-02/04/32 (timeout real, rake com busca `failed`/401, catálogo vazio), Fix 4 SRC-05 (saída do rake com a chave definida, `Fetch#inspect`), Fix 5 SRC-17 (dono por wishlist, item de terceiros), Fix 6 documentação, Fix 7 higiene de testes. O commit de correção `43b62ae` (T25) foi o alvo desta re-verificação.

### Fix 1–6: fecham a lacuna? (evidência própria)

| Fix | Veredito | Evidência `arquivo:linha` |
| --- | -------- | ------------------------- |
| 1 brakeman | ✅ fecha | `Gemfile.lock` `brakeman (8.1.0)` (único hunk do arquivo em `43b62ae`); `bin/brakeman --no-pager --ensure-ignore-notes --ensure-no-obsolete-ignore-entries` **saída 0**, "Brakeman Version: 8.1.0", Security Warnings 0, Errors 0, Ignored 2; mesmo comando em `.github/workflows/ci.yml:29`; `bin/brakeman --no-pager` simples também saída 0 |
| 2 SRC-36 | ✅ fecha | `test/services/ingestion/upsert_test.rb:218-231`: `assert_equal "succeeded", run.status` (:225), `assert_equal 0, run.failed_count` (:226), `error_log` exato com `"message" => "sem code"` e `"sem CardType"` (:227-229). Mutante n3 (descarte conta em `failed_count`) morto por 5 testes; n7 (guarda de `CardType` desligada) morto |
| 3 SRC-02/04/32 | ✅ fecha | timeout real: `test/services/ingestion/run_test.rb:175-193` (`assert_equal 7, captured[:options][:open_timeout]` :190, `read_timeout` :191, `assert captured[:options][:use_ssl]` :192) sobre `fetch.rb:56`; mutante n2 (timeouts 60) morto. Rake com busca `failed`: `test/lib/ingestion_import_task_test.rb:96-108` (`assert_equal 1, status` :99, `"status: failed"` :100, contagens zeradas :108); 401: `:111-119` (`assert_equal "chave da apitcg recusada (401)", ImportRun.sole.error_log.sole["message"]` :118). SRC-02 sem banco: `run_test.rb:216` `assert_equal [ 0, 0, 0 ], catalog_counts` |
| 4 SRC-05 | ✅ fecha | rake com a chave **definida** (`ENV["APITCG_API_KEY"] = CHAVE`, `ingestion_import_task_test.rb:38`): `refute_includes out, CHAVE` (:102, :116) e `refute_includes err, CHAVE` (:103, :117); `Fetch#inspect` sem headers `app/services/ingestion/apitcg/fetch.rb:93`, teste `run_test.rb:168-173` (`refute_includes fetch.inspect, CHAVE`). Mutantes n1 (remove o `inspect`) e n4 (rake imprime a chave) mortos |
| 5 SRC-17 | ✅ fecha | dono por wishlist: `test/integration/card_detail_absent_variant_test.rb:138-147` (`assert_response :success` :144, `assert_equal [ "OP01-016" ], variant_codes` :145, `"fora da fonte"` :146); terceiros sem sessão: `:51-59` (item de coleção e de wishlist de `@outro` na ausente; `assert_equal [ "tcgplayer:101" ], variant_codes` :58, `count: 0` :59). Mutantes n5 (wishlist fora de `held_variant_ids`) e n6 (ausente visível a todos) mortos |
| 6 documentação | ✅ fecha | `.context/requirements.md:26` cita `GET /api/products?tcg=one-piece&type=card`; `tasks.md:11` "SRC-01..SRC-36", T24 (SRC-36, `64b9474`) e T25 (`43b62ae`) criadas; §8.6 do `.context/tasks.md:340` segue `[ ]` de propósito, até o item de 24h |
| 7 higiene | ⚠️ parcial (aceito, Minor) | feitos: `run_test.rb:79,236` (`assert_equal FIXTURE_COUNTS, catalog_counts`), `:235` (SHA exato), `ingestion_import_task_test.rb:73` (SHA exato). Restam `test/lib/ingestion_remap_task_test.rb:59` (`refute_includes out, @user.email`, implicado pela linha 57), `test/lib/ingestion_compare_snapshots_task_test.rb:85-86` (`ENV["A"]`/`["B"]` não restaurados) e `test/queries/set_progress_numbers_test.rb:112-122` (3 possuídos para `base_size` 3 não exercita o teto; o teto está em `set_progress_query_test.rb:544`). Não reprovam: o comportamento tem mutante morto em cada um |

---

## Task Completion

Conferido contra `tasks.md` e `git log b026f3b..HEAD` (35 commits; os hashes das 25 tasks existem).

| Task | Commit | Status | Notas |
| ---- | ------ | ------ | ----- |
| T1 | `d28ba18` | ✅ Done | `CardVariant.present`, `card_variant.rb:15-18` |
| T2 | `ea486c1` (+`3c2b15e`) | ✅ Done | `CatalogQuery` só com presentes |
| T3 | `212be19` | ✅ Done | detalhe com "fora da fonte" |
| T4 | `656662d` | ✅ Done | progresso por números distintos |
| T5 | `edb146e` | ✅ Done | `Ingestion::Remap` |
| T6 | `09c8a61` | ✅ Done | rake `ingestion:remap` |
| T7 | `8088f66` | ✅ Done | `CardImageCache` tcgplayer |
| T8 | `d1c0ff3` | ✅ Done | `SourceConfig` apitcg |
| T9 | `4d1ca1c` | ✅ Done | `Apitcg::Fetch` |
| T10 | `5689467` | ✅ Done | fixture + `verify_fixture.py` |
| T11 | `4e1c6a6` | ✅ Done | `Apitcg::Normalize` |
| T12 | `32805f7` | ✅ Done | Upsert: descartes, `source_revision`, presença no `finish` |
| T13 | `46e57ba` | ✅ Done | `Run` + `SNAPSHOT=` |
| T14 | `6f00669` | ✅ Done | optcgjson removida; queda de testes justificada (Gate) |
| T15 | `8faae47` | ✅ Done | `compare_snapshots` |
| T16 | `c58a14a` | ✅ Done | documentação |
| T17 | `4573bc0` | ⚠️ Partial | troca real feita; **item de 24h `[ ]` em `tasks.md:603`, bloqueado (D-04)** |
| T18..T23 | `78a8d9d` `54f83e7` `bde019b` `db91511` `f1f7892` `c7e80fd` | ✅ Done | |
| T24 | `64b9474` | ✅ Done | SRC-36, T-id dado depois do fato |
| T25 | `43b62ae` | ✅ Done | Fix 1–6; `tasks.md:827` (Fix 7) e `:828` ("Gate full e build, a cargo do supervisor") ainda `[ ]` |

Housekeeping (Minor, não bloqueia): `tasks.md:828` fica fechável com o gate deste relatório (1540 runs × 3, rubocop, brakeman estrito, fixture, build, todos saída 0); `tasks.md:827` é o Fix 7 parcial; `spec.md:257` ainda cita 1534 runs (hoje 1540).

---

## Spec-Anchored Acceptance Criteria

Siglas: `FT` `test/services/ingestion/apitcg/fetch_test.rb`, `NT` `.../apitcg/normalize_test.rb`, `UT` `test/services/ingestion/upsert_test.rb`, `RuT` `.../run_test.rb`, `GT` `.../guarantees_test.rb`, `RM` `.../remap_test.rb`, `RK` `test/lib/ingestion_remap_task_test.rb`, `IK` `test/lib/ingestion_import_task_test.rb`, `CK` `test/lib/ingestion_compare_snapshots_task_test.rb`, `CS` `.../apitcg/compare_snapshots_test.rb`, `CP` `test/queries/catalog_presence_test.rb`, `SN` `test/queries/set_progress_numbers_test.rb`, `AB` `test/integration/card_detail_absent_variant_test.rb`. Os arquivos fora de `43b62ae` mantêm as linhas do ciclo anterior, relidas por amostragem.

### P1: Ingestão a partir da apitcg

| Critério | Spec-defined outcome | `file:line` + assertion | Result |
| -------- | -------------------- | ----------------------- | ------ |
| SRC-01 busca com `x-api-key` | todas as páginas de `/products?tcg=one-piece&type=card` e `/sets`, header = chave | `FT:81` `assert_equal 4, http.calls.size`; `FT:82` `assert_equal CHAVE, call[:headers]["x-api-key"]`; `FT:98` `assert_equal %w[1 2 3 5], snapshot["cards"].pluck("_id")` | ✅ PASS (host real só em `config/ingestion.yml:9`, não asserido) |
| SRC-02 sem chave | aborta antes de requisição, "APITCG_API_KEY não configurada", sem banco | `FT:235` `assert_equal "APITCG_API_KEY não configurada", error.message`; `FT:236` `assert_empty http.calls`; `RuT:214` `assert_equal 0, ImportRun.count`; `RuT:216` `assert_equal [ 0, 0, 0 ], catalog_counts`; rake `IK:81` `assert_equal "APITCG_API_KEY não configurada\n", err`, `IK:79` `assert_equal 1, status`; ordem em `run.rb:30` (`@config.api_key` antes do Fetch) | ✅ PASS (Fix 3c fechado) |
| SRC-03 snapshot antes de normalizar | `storage/ingestion/apitcg-<UTC>.json` | `FT:88` `assert_equal snapshot_file, result.path`; ordem `run.rb:31-32` | ✅ PASS |
| SRC-04 3 tentativas e `failed` | 3 chamadas, 3ª falha ⇒ `failed`, nada gravado; 30 s | `FT:205` `assert_equal 3, http.calls.count { … page(2) }`; `FT:206` `assert_equal [ 2, 4 ], @waits`; `RuT:131` `assert_equal "failed", run.status`; `RuT:141` `assert_equal before, catalog_counts`; timeout aplicado ao cliente `RuT:190-191` `assert_equal 7, captured[:options][:open_timeout]`/`[:read_timeout]`; config `source_config_test.rb:19` `assert_equal 30, carregada.timeout`; rake `IK:99-108` | ✅ PASS (Fix 3 fechado; mutantes c2, n2 mortos) |
| SRC-05 chave nunca vaza | nunca em snapshot, `error_log`, rake, log | snapshot `FT:242` `refute_includes result.path.read, CHAVE`; erro `FT:264`; `error_log` `RuT:164` `assert_equal "falhou com [FILTRADA] no meio", …`, `RuT:165` `refute_includes run.error_log.to_json, CHAVE`; `inspect` `RuT:172`; rake `IK:102-103,116-117`, `IK:107`; config `source_config.rb:40-48` (`inspect`/`to_s`/`as_json`). Varredura por valor (chave de 64 chars) em app, test, spec, config, lib, .specs, docs, CLAUDE.md, README, `storage/ingestion` e `log`: **limpa** | ✅ PASS (Fix 4 fechado; mutantes d1, d2, n1, n4 mortos). Sem teste de log: não há código de log na ingestão |
| SRC-06 `<arquivo> sha256:<hex>` | formato exato | `UT:281` `assert_equal "apitcg-subset.json sha256:#{hex}", run.source_revision`; `UT:287`; `RuT:78`, `RuT:235` `assert_equal "#{saved.basename} sha256:#{Digest::SHA256.file(saved).hexdigest}", run.source_revision`; `IK:73` | ✅ PASS · ⚠️ Spec-precision gap: o spec diz "quando a ingestão terminar", a revisão é gravada na criação do run (`upsert.rb:52`) |
| SRC-07 `SNAPSHOT=` sem rede | nenhuma requisição | `RuT:93` `test "com snapshot o Fetch nem chega a ser construído"`; `IK:65-73` sem chave ⇒ `assert_equal 0, status` (:70) | ✅ PASS (mutante h1 morto; `RuT:77` `assert_equal 0, http.calls` é fraco, o que vale é `RuT:93`) |
| SRC-08 idempotência | contagens idênticas | `RuT:89` `assert_equal first, catalog_counts`; `GT:65` `assert_equal({ sets: 10, cards: 11, variants: 13 }, depois)` | ✅ PASS |
| SRC-09 `variant_code` | `tcgplayer:<id>` / `apitcg:<_id>` | `NT:71` (códigos da fixture), `NT` caso `apitcg:4321` | ✅ PASS |
| SRC-10 `DON!!` | descartado sem falha | `NT:63` `assert_nil variant("tcgplayer:624351")`; `NT:64` `assert_not_includes @resultado.discarded.map { … }, 7547` | ✅ PASS |
| SRC-11 sem `code` | descarte no `error_log` com `_id`, fora de `failed_count`, status inalterado | `NT:59` `assert_equal [ { "_id" => 6117, "reason" => "sem code" } ], @resultado.discarded`; `UT:211` `"succeeded"`; `UT:212` `assert_equal 0, run.failed_count`; `UT:213` `[ { "identifier" => "900", "error" => "discarded", "message" => "sem code" } ]` | ✅ PASS (⚠️ gap de precisão: o spec não fixa o texto "sem code" nem o formato do `error_log`) |
| SRC-12 impressão da carta, efeito, trigger | base de estreia; senão set mais recente; empate menor `variant_code`; efeito limpo; `trigger_text` | `NT:317` `assert_equal 2000, carta.counter`, `NT:318`; `NT:291` `assert_equal 1000, …counter`; `NT:189` `assert_equal "Activate this card's [Counter] effect.", carta.trigger_text`; `NT:190,196` efeito sem HTML; `normalize.rb:151-158` | ✅ PASS |
| SRC-13 `art_kind` | tabela de Assumptions | `NT:78-` (13 códigos da fixture), `NT:379` `assert_equal nomes.values, obtido` (tabela), `NT:365` set promo | ✅ PASS (mutantes e1, e2, e3 mortos) · ⚠️ gap: precedência de `promo` sobre `Reprint`/outros e a detecção de "set de promoção" não estão no spec |
| SRC-14 código do set, `released_on` | `ST-01`→`ST01`, `OP07 PRE`→`OP07-PRE`, nulo→prefixo/slug | `NT:411` `assert_equal %w[OP07-PRE OP15-EB04 PRB01 ST01], …`; `NT:421` `[ "OP18" ]`; `NT:431` `%w[OP01 set-sail-deck-set]`; `NT:466` `assert_equal [ Date.new(2024, 6, 28), nil ], resultado.sets.map(&:released_on)` | ✅ PASS |

### P1: Catálogo mostra só o que a fonte atual tem

| Critério | Spec-defined outcome | `file:line` + assertion | Result |
| -------- | -------------------- | ----------------------- | ------ |
| SRC-15 ordem padrão | abre pelo set com `released_on` mais recente | `CP:123` `assert_equal "OP02-013", CatalogQuery.new.call.records.first.card_number`; `catalog_query.rb:69,77` | ✅ PASS (mutante x3 morto) · ⚠️ gap: "set presente" não diz se é o set de estreia da carta (`cards.set_id`) ou o das variantes presentes |
| SRC-16 só presentes | grade, busca, filtros, lista de sets, progresso | grade `CP:57` `assert_equal %w[OP01-001 OP01-016], numbers`; busca `CP:61-62`; filtros `CP:66-69`; sets `CP:105` `assert_equal %w[OP01 ST01], codes`; opções `CP:111-113`; progresso `SN:142` `assert_not_includes progress.keys, "OLD01"`; definição `card_variant_presence_test.rb:31,38,47-48,56,63` | ✅ PASS (mutantes x1, x2 mortos) |
| SRC-16/18 presença só avança em `succeeded` | run `failed` não altera `present` | `UT:329-334` (`assert_nil variante(3).last_seen_at`, `assert_equal primeiro.started_at, variante(1).last_seen_at`); `GT:252` | ✅ PASS (mutante a1 morto) |
| SRC-17 "fora da fonte" só ao dono | rótulo literal; dono por coleção ou wishlist; sem item não vê; carta só com ausentes: 200 ao dono, 404 aos demais | `AB:79` `assert_equal [ "OP01-001_p1", "tcgplayer:101" ], variant_codes`; `AB:81` `assert_includes ausente.text, "fora da fonte"`; `AB:135` `assert_equal "fora da fonte", par.at_css("dd").text.strip`; wishlist `AB:94,144-146`; terceiros `AB:58-59`; 404 `AB:155,161` | ✅ PASS (Fix 5 fechado; mutantes n5, n6 mortos) · ⚠️ gap: o spec não diz se `quantity = 0` conta como "ter" (implementação: conta, `catalog_controller.rb:118`) |
| SRC-18 ingestão não toca coleção | nem apaga nem altera `quantity` | `GT:102` `assert_equal 3, item.quantity`; `GT:216` `assert_equal 2, item.reload.quantity` (variante ausente); `GT:250` `assert_equal 5, desejo.reload.target_quantity` (run failed); `GT:332` sem operação de exclusão | ✅ PASS (mutantes b1, b2, b3 mortos por 2, 5 e 4 testes) |

### P1: Remapeamento

| Critério | Spec-defined outcome | `file:line` + assertion | Result |
| -------- | -------------------- | ----------------------- | ------ |
| SRC-19 candidato único | mesmo `card_number`, classe de arte, código de set | `RM:66` `assert_equal @luffy_new_base.id, item.card_variant_id`; arte `RM:100`; set `RM:133` `assert_equal old_st01.id, item.reload.card_variant_id` | ✅ PASS (mutantes f5, f6 mortos) |
| SRC-20 preserva quantidades | `quantity`/`target_quantity` | `RM:67` `assert_equal 3, item.quantity`; `RM:77` `assert_equal 4, item.target_quantity`; `RM:355` `assert_equal antes_movido.merge("card_variant_id" => @luffy_new_base.id), movido.reload.attributes` | ✅ PASS (mutante f7 morto) |
| SRC-21 motivos e colisão | "sem candidato"/"ambíguo"/"colisão"; todos os envolvidos ficam | `RM:147` `[ { card_number: "OP01-004", old_variant_code: "OP01-004", reason: "sem candidato" } ]`; `RM:158` `{ "OP01-001" => "ambíguo" }`; `RM:170` `{ "OP01-001_p1" => "colisão", "OP01-001_p2" => "colisão" }`; `RK:57` linhas exatas | ✅ PASS (mutantes f1–f4 mortos) |
| SRC-22 idempotência | 2ª execução move 0 | `RM:218` `assert_empty segunda.moved`; `RK:88` `[ "movidos: 0 \| pulados: 1", … ]` | ✅ PASS |
| SRC-23 sem run `succeeded` | mensagem exata, nada movido | `RM:230` `assert_equal "nenhuma ingestão concluída; rode ingestion:import antes", erro.message`; `RK:106` `assert_equal 1, status`; `RK:108` mensagem + `\n` | ✅ PASS (mutante x4 morto) |

### P1: Progresso por set

| Critério | Spec-defined outcome | `file:line` + assertion | Result |
| -------- | -------------------- | ----------------------- | ------ |
| SRC-24 `base_set_size` | prefixo em maioria estrita; senão todos os distintos | `NT:478` `assert_equal 2, resultado.base_set_size`; `NT:486` (metade não é maioria) `assert_equal 2, …`; `NT:495` `assert_equal 3, resultado.base_set_size`; `normalize.rb:174` | ✅ PASS (mutante x6 morto) |
| SRC-25 numerador | números distintos do universo, com variante presente não-parallel | `SN:70` `assert_equal 1, op01.owned_numbers`, `SN:71` `assert_equal 3, op01.base_size`; `SN:81-82` | ✅ PASS (mutantes g3, g5 mortos) · ⚠️ gap: o spec não diz como derivar o universo (`set_progress_query.rb:216` `UNIVERSE_SQL`) |
| SRC-26 teto 100% | nunca acima de 100% (percentual e texto) | `set_progress_query_test.rb:544` `assert_equal 100.0, h.completion_percent`; `set_progress_bar_test.rb:127` `assert_equal "7 / 7 · 100%", …`; `SN:132` `assert_equal 2, op01.displayed_owned_numbers` | ✅ PASS (mutantes g1, g2 mortos) |
| SRC-27 parallels separados | métrica própria | `SN:108-110` (`owned_numbers` 0, `parallel_owned_variants` 1); `progress_ui_test.rb:248` `assert_select "#progress_set_OPp5a .progress-set__parallel-owned", text: "1"` | ✅ PASS (⚠️ gap: parallel fora do universo entra na métrica) |
| SRC-28 base + Box Topper uma vez | conta 1 | `SN:91` `assert_equal 1, progress["OP01"].owned_numbers`; `SN:99-100` | ✅ PASS (mutante g4 morto) |

### P1: Fixture offline · P2: estabilidade · Edge cases

| Critério | Spec-defined outcome | `file:line` + assertion | Result |
| -------- | -------------------- | ----------------------- | ------ |
| SRC-29 fixture | 10 casos | `spec/fixtures/apitcg-subset.json`; casos (a)–(j) conferidos por `spec/verify_fixture.py:63-77` | ✅ PASS |
| SRC-30 `verify_fixture.py` | um check por caso, sem Docker/Ruby | `spec/verify_fixture.py:63-77` (checks `SRC-29 (a)…(j)`); **executado**: 19 `OK`, "todas as verificações passaram", saída 0 | ✅ PASS |
| SRC-31 serviço + rake | informa quantos produtos presentes nos dois mudaram de `tcgplayer.id` para o mesmo `_id` | `CS:20-22` `assert_equal 1, result.changed`, `assert_equal 2, result.common`; só de um lado `CS:41,44`; `CK:30-31` `assert_equal "comuns: 2", lines[0]`, `assert_equal "mudados: 1", lines[1]`; sem `A`/`B` `CK:56` `assert_equal 1, status` | ✅ PASS (mutante x5 morto) |
| SRC-31 comparação real ≥24h | `changed` entre dois snapshots reais com ≥24h | não executável: só existem `apitcg-20261001T024920Z.json` e `apitcg-20261001T033437Z.json` (45 min; informativo: 7.252 comuns, 0 mudados) | ✅ fechado pela emenda de 20h (D-14), ver *Re-verificação SRC-31*. (Histórico: antes bloqueado por tempo, D-04.) Retomada antiga, a partir de 2026-10-02T03:35Z: `docker compose exec app bin/rails ingestion:import` e depois `docker compose exec app bin/rails ingestion:compare_snapshots A=storage/ingestion/apitcg-20261001T024920Z.json B=storage/ingestion/<snapshot-novo>.json`; se `mudados > 0`, reabrir SRC-31 com o dono antes de confiar em `tcgplayer.id` como chave |
| SRC-32 401 | `failed`, "chave da apitcg recusada (401)", sem repetir | `FT:224` `assert_equal "chave da apitcg recusada (401)", error.message`; `FT:225` `assert_equal 1, http.calls.size`; `RuT:150-153`; rake `IK:114-118` | ✅ PASS (Fix 3b fechado; mutante c1 morto) |
| SRC-33 dedup | deduplicar por `variant_code` antes de normalizar | `FT:98` (dedup por `_id` no Fetch); `NT:289` (dedup por `variant_code` no Normalize, `normalize.rb:86`) | ✅ PASS · ⚠️ gap: o spec não diz em que estágio |
| SRC-34 variante em dois sets | fica no primeiro | `NT:289` `assert_equal [ [ "tcgplayer:10", "AA" ] ], resultado.variants.map { … }`; `UT:89` | ✅ PASS |
| SRC-35 sem prefixo próprio | todos os distintos, sem divisão por zero | `NT:495-496` `assert_equal 3, resultado.base_set_size`, `assert_equal 3, resultado.total_set_size`; `SN:81-83` | ✅ PASS |
| SRC-36 sem `CardType` | descarte `{_id, "sem CardType"}`, fora de `failed_count`, status inalterado; `CardType` desconhecido é erro | `NT:235` `assert_equal [ { "_id" => 2, "reason" => "sem CardType" }, { "_id" => 3, … } ], resultado.discarded`; `NT:219` `assert_raises(Normalize::UnknownCardType)`; `UT:225-229` `"succeeded"`, `assert_equal 0, run.failed_count`, `error_log` com `"sem CardType"` | ✅ PASS (Fix 2 fechado; mutantes n3, n7 mortos) |

**Status**: ✅ 36/36 SRCs com asserção que bate com o resultado do spec; SRC-31 com a parte de ≥24h ⏳ (bloqueio externo, D-04). 12 spec-precision gaps, nenhum bloqueante e todos da classe já registrada em L-057: SRC-06, SRC-11, SRC-13, SRC-15, SRC-17, SRC-25, SRC-27, SRC-31 (id → ausente conta como mudança), SRC-33 e, vistos no ciclo anterior, SRC-19, SRC-21 e SRC-24.

---

## Discrimination Sensor

Profundidade **P0-full** (integridade de dados da coleção + chave da API). Baseline `git status --porcelain` da árvore real: ` M .specs/LESSONS.md`, ` M .specs/features/fonte-apitcg/spec.md`, ` M .specs/lessons.json`, `?? .playwright-mcp/`, `?? .specs/features/fonte-apitcg/validation.md` (do ciclo anterior); **idêntico ao final**. Cópia em `/tmp/claude-1000/verifier-scratch` (sem `.git`, `storage`, `tmp`, `log`, `.env`), montada com `docker compose run --rm --no-deps -v …:/rails app bin/rails test`; montagem confirmada sem mutação (42 runs, 0 falhas) e diff cópia-restaurada == real. Um mutante por vez, restaurado do original a cada execução; scratch apagado (resíduo root removido por container descartável).

| # | File:line | Mutação | Testes executados | Killed? |
| - | --------- | ------- | ----------------- | ------- |
| a1 (a) | `app/services/ingestion/upsert.rb:131` | `if status == "succeeded"` → `if true` (presença também em run `failed`) | upsert, guarantees, presence (51 runs) | ✅ 1 falha |
| b1 (b) | `upsert.rb:129` | `CollectionItem…delete_all` no `finish` | idem | ✅ 1 falha + 1 erro |
| b2 (b) | `upsert.rb:129` | `CollectionItem.update_all(quantity: 0)` | idem | ✅ 5 falhas |
| b3 (b) | `upsert.rb:129` | `WishlistItem.update_all(target_quantity: 1)` | idem | ✅ 4 falhas |
| c1 (c) | `apitcg/fetch.rb:172` | remove `raise KeyRejected … if status == 401` (401 vira retry) | fetch, run, rake import (42) | ✅ 3 falhas |
| c2 | `fetch.rb:179` | `attempt < attempts` → `attempts - 1` | idem | ✅ 2 falhas + 1 erro |
| d1 (d) | `fetch.rb:195` | tira o `gsub(api_key, "[FILTRADA]")` da razão da falha | idem | ✅ 1 falha |
| d2 (d) | `run.rb:61` | tira o `gsub` do `error_log` da falha de busca | idem | ✅ 1 falha |
| e1 (e) | `apitcg/normalize.rb:258` | sufixo desconhecido (`Reprint`) → `base` | normalize, upsert (81) | ✅ 2 falhas |
| e2 (e) | `normalize.rb:249` | `promo` vence `Parallel`/`Alternate Art`/`Manga` | idem | ✅ 1 falha |
| e3 | `normalize.rb:257` | sufixo numérico deixa de ser `base` | idem | ✅ 3 falhas |
| f1 (f) | `remap.rb:95` | colisão ignorada | remap, rake remap (34) | ✅ 1 falha + 4 erros |
| f2 (f) | `remap.rb:92` | ambiguidade ignorada | idem | ✅ 3 erros |
| f3 (f) | `remap.rb:95` | colisão só por "já ocupado" | idem | ✅ 2 erros |
| f4 (f) | `remap.rb:95` | colisão só por "dois itens" | idem | ✅ 1 falha + 2 erros |
| f5 (f) | `remap.rb:88` | classe de arte ignorada | idem | ✅ 20 falhas |
| f6 (f) | `remap.rb:88` | código de set ignorado | idem | ✅ 1 falha |
| f7 (f) | `remap.rb:107` | movimento zera `quantity` | idem | ✅ 6 falhas |
| g1 (g) | `app/queries/set_progress_query.rb:130` | sem teto de 100% no percentual | progresso (99) | ✅ 2 falhas |
| g2 (g) | `set_progress_query.rb:144` | sem teto no texto | idem | ✅ 2 falhas |
| g3 (g) | `set_progress_query.rb:216` | universo sem o prefixo do set | idem | ✅ 2 falhas |
| g4 (g) | `set_progress_query.rb:223` | numerador conta variantes, não números distintos | idem | ✅ 2 falhas |
| g5 (g) | `set_progress_query.rb:225` | `parallel` entra no numerador | idem | ✅ 9 falhas |
| h1 (h) | `run.rb:27` | `Run` constrói o `Fetch` mesmo com `snapshot:` | fetch, run, rake (42) | ✅ 1 erro |
| n1 (ciclo) | `fetch.rb:93` | remove `Fetch#inspect` (volta a imprimir os headers) | idem | ✅ 1 falha |
| n2 (ciclo) | `fetch.rb:56` | `open_timeout`/`read_timeout` fixos em 60 | idem | ✅ 1 falha |
| n3 (ciclo) | `upsert.rb:141` | `failed_count` passa a contar descartes | upsert, guarantees, presence (51) | ✅ 5 falhas |
| n4 (ciclo) | `lib/tasks/ingestion.rake:6` | rake imprime `ENV["APITCG_API_KEY"]` | `ingestion_import_task_test.rb` (6) | ✅ 2 falhas |
| n5 (ciclo) | `catalog_controller.rb:124` | wishlist fora de `held_variant_ids` | `card_detail_absent_variant_test.rb` (12) | ✅ 2 falhas |
| n6 | `catalog_controller.rb:51-52` | variante ausente visível a todos | idem | ✅ 4 falhas |
| n7 | `normalize.rb:81` | guarda de `CardType` desligada (SRC-36) | normalize, upsert | ✅ 2 erros |
| n8 | `upsert.rb:120` | descartes cortados do `error_log` | upsert, guarantees | ✅ 3 falhas + 2 erros |
| x1 | `card_variant.rb:16` | presença conta run `failed` | presence, upsert, catálogo (106) | ✅ 4 falhas |
| x2 | `catalog_query.rb:232` | grade sem filtro de presença | catálogo (55) | ✅ 5 falhas |
| x3 | `catalog_query.rb:77` | ordem padrão "recent" `desc` → `asc` | idem | ✅ 2 falhas |
| x4 | `remap.rb:45` | sem a guarda "nenhuma ingestão concluída" | remap, rake remap | ✅ 2 falhas |
| x5 | `apitcg/compare_snapshots.rb:42` | `!=` → `==` | compare (service + rake, 9) | ✅ 5 falhas |
| x6 | `normalize.rb:174` | maioria estrita `>` → `>=` | normalize, upsert | ✅ 3 falhas |
| x7 | `upsert.rb:52` | SHA de outra coisa | upsert, fetch, run, rake (93) | ✅ 5 falhas |

**Sensor depth**: P0-full (≥5 mutações; as 8 famílias a–h pedidas, as 5 novas do ciclo n1–n5 e mais SRC-02..36 selecionados).
**Result**: 39/39 killed, 0 survived — PASS ✅. (n7, h1, f2 e f3 morrem por erro em vez de falha de asserção, mas o erro é o teste exercitando o ramo mutado.)

---

## Interactive UAT Results

Não aplicável: feature de ingestão/CLI; as telas tocadas ("fora da fonte" e linha de progresso) são cobertas por teste de integração sobre HTML renderizado (projeto sem navegador no container, `SPEC_DEVIATION` do projeto).

---

## Code Quality

| Principle | Status |
| --------- | ------ |
| Minimum code | ✅ O único código de produção novo no ciclo é `Fetch#inspect` (1 linha, `fetch.rb:93`) |
| Surgical changes | ✅ `43b62ae` toca só testes, `Gemfile.lock` (1 linha), `fetch.rb` (`inspect`), docs |
| No scope creep | ✅ (⚠️ herdado: descarte "set desconhecido" `normalize.rb:98` e `MAX_LOGGED_ERRORS`, registrados em D-08) |
| Matches patterns | ✅ dublês `FakeHttp`/`swap` no padrão do projeto |
| Spec-anchored outcome check (asserted values match spec) | ✅ tabela acima |
| Per-layer Coverage Expectation (domain 1:1; rake happy+edge+error) | ✅ rake `import`: sucesso, sem chave, snapshot inexistente, busca `failed`, 401 |
| Every test maps to a spec requirement — no unclaimed tests | ✅ (testes sem SRC são do Req. 11.1/11.3, lock/`FOR UPDATE`, `ConcurrentChange`) |
| Asserções vacuosas | ⚠️ Minor/aceito (Fix 7 parcial): `RuT:77` `assert_equal 0, http.calls` (cliente que o `Run` nunca recebe), `RK:59`, `SN:112-122`, `CK:85-86` sem restaurar `ENV`. Nenhum `assert x if x` nem `assert_nothing_raised` solto |
| `SPEC_DEVIATION` | ✅ nenhum marcador novo no diff (a única ocorrência é texto de `tasks.md`) |
| Documented guidelines followed | `CLAUDE.md` (gates, `verify_fixture.py`), `.github/workflows/ci.yml` |

---

## Edge Cases

- [x] SRC-32 (401): `FT:224-225`, `RuT:150-153`, `IK:114-118`
- [x] SRC-33 (dedup): `FT:98`, `NT:289`
- [x] SRC-34 (variante em dois sets): `NT:289`, `UT:89`
- [x] SRC-35 (sem prefixo): `NT:495-496`, `SN:81-83`
- [x] SRC-36 (sem `CardType`): `NT:235`, `UT:225-229`
- [x] Colisão no remap, rollback total e `ConcurrentChange`: `RM:170`, `RM:355`, `RK:112-125`
- [x] Success Criteria 1–3 (grade abre por OP18, contagem/soma de coleção idênticas, nenhum set >100%): evidência registrada em `spec.md:254-256` (execução real da T17), não re-derivada (exigiria rede, chave real e escrita no banco de dev). Coleção intacta e teto de 100% re-provados por mutação (b1–b3, g1–g2).
- [x] Success Criterion 4 (suíte sem rede e sem chave; rubocop limpo): re-derivado, ver Gate.
- [x] Success Criterion 5 (SRC-31 ≥20h, emenda D-14): re-verificado em 2026-10-02, ver *Re-verificação SRC-31*.

---

## Gate Check

- **Gate command** (`tasks.md:47`, build): `docker compose exec -T app bin/rails test && … bin/rubocop && … bin/brakeman --no-pager && python3 spec/verify_fixture.py` e `docker compose build`, com `DOCKER_CONFIG=/tmp/claude-1000/bindr-dockercfg`, em série, sem outro job concorrente. Brakeman também na forma estrita do CI.
- **`bin/rails test`**: **1540 runs, 6331 assertions, 0 failures, 0 errors, 0 skips**, em 3 execuções completas seguidas (29 s, 28 s, 42 s).
- **Flake D-10** (`CatalogSearchTest#test_o_match_exato_de_card_number_usa_o_índice_único`): **0 de 3** execuções completas falharam; a taxa histórica (2 de 5 na suíte inteira, 0 de 8 isolado) não foi reproduzida. Nenhuma outra falha.
- **`bin/rubocop`**: 179 arquivos, 0 offenses, saída 0.
- **`bin/brakeman --no-pager --ensure-ignore-notes --ensure-no-obsolete-ignore-entries`**: **saída 0** (Brakeman 8.1.0; 0 Security Warnings, 0 Errors, 2 Ignored). A forma simples também sai 0.
- **`python3 spec/verify_fixture.py`**: 19 `OK`, saída 0.
- **`docker compose build`**: saída 0 (`Image bindr-tcg-app Built`).
- **Varredura de segredo** (valor da chave, sem imprimi-lo): app, test, spec, config, lib, .specs, docs, CLAUDE.md, README.md, `storage/ingestion`, `log`: **limpa**.
- **Test count before feature** (`git archive b026f3b`, `test "` + `def test_`): 1353 (94 arquivos). **After**: 1540 (108 arquivos; coincide com os runs). **Delta**: +187. Quedas por arquivo: `normalize_test.rb` (23) e `fetch_test.rb` (7) da optcgjson, removidos com o código na T14 (`6f00669`), justificadas no commit; nenhuma asserção afrouxada nos arquivos migrados.
- **Skipped tests**: nenhum.
- **Failures**: nenhuma.

---

## Fix Plans

Nenhum Fix bloqueante. Débitos aceitos, em ordem:

### Fix 7 (resto): higiene de testes (Minor, aceito)
- **Root cause**: o ciclo 1 não podia editar `ingestion_remap_task_test.rb`, `ingestion_compare_snapshots_task_test.rb` e `set_progress_numbers_test.rb`.
- **Fix task**: trocar `RK:59`, `SN:112-122` por valor exato e restaurar `ENV` em `CK:85-86`; `RuT:77` por `assert_equal 0, http.calls` sobre um dublê que o `Run` receba de fato.
- **Priority**: Minor.

### Housekeeping (Minor)
- Marcar `tasks.md:828` (gate full e build, coberto por este relatório) e, quando o prazo vencer, `tasks.md:603` e `.context/tasks.md:340` (§8.6); atualizar `spec.md:257` (1534 → 1540 runs).

### Fora do código, depende do dono
- **SRC-31 ≥24h (D-04)**: comando de retomada em *Spec-Anchored*, a partir de 2026-10-02T03:35Z. **D-03** (SRC-19, parallel ausente para `alternate_art`/`manga`).

---

## Requirement Traceability Update

| Requirement | Previous Status | New Status |
| ----------- | --------------- | ---------- |
| SRC-01 | ✅ Verified | ✅ Verified |
| SRC-02 | ✅ Verified | ✅ Verified (Fix 3c fechado) |
| SRC-03 | ✅ Verified | ✅ Verified |
| SRC-04 | ⚠️ Verified parcial (Fix 3) | ✅ Verified |
| SRC-05 | ⚠️ Verified parcial (Fix 4) | ✅ Verified |
| SRC-06 | ✅ Verified | ✅ Verified |
| SRC-07 | ✅ Verified | ✅ Verified |
| SRC-08 | ✅ Verified | ✅ Verified |
| SRC-09 | ✅ Verified | ✅ Verified |
| SRC-10 | ✅ Verified | ✅ Verified |
| SRC-11 | ✅ Verified | ✅ Verified |
| SRC-12 | ✅ Verified | ✅ Verified |
| SRC-13 | ✅ Verified | ✅ Verified |
| SRC-14 | ✅ Verified | ✅ Verified |
| SRC-15 | ✅ Verified | ✅ Verified |
| SRC-16 | ✅ Verified | ✅ Verified |
| SRC-17 | ⚠️ Verified parcial (Fix 5) | ✅ Verified |
| SRC-18 | ✅ Verified | ✅ Verified |
| SRC-19 | ✅ Verified | ✅ Verified |
| SRC-20 | ✅ Verified | ✅ Verified |
| SRC-21 | ✅ Verified | ✅ Verified |
| SRC-22 | ✅ Verified | ✅ Verified |
| SRC-23 | ✅ Verified | ✅ Verified |
| SRC-24 | ✅ Verified | ✅ Verified |
| SRC-25 | ✅ Verified | ✅ Verified |
| SRC-26 | ✅ Verified | ✅ Verified |
| SRC-27 | ✅ Verified | ✅ Verified |
| SRC-28 | ✅ Verified | ✅ Verified |
| SRC-29 | ✅ Verified | ✅ Verified |
| SRC-30 | ✅ Verified | ✅ Verified |
| SRC-31 | ✅ Verified (emenda D-14) | ✅ serviço, rake, testes e comparação real de 20h27m verificados (2026-10-02) |
| SRC-32 | ✅ Verified | ✅ Verified |
| SRC-33 | ✅ Verified | ✅ Verified |
| SRC-34 | ✅ Verified | ✅ Verified |
| SRC-35 | ✅ Verified | ✅ Verified |
| SRC-36 | ⚠️ Verified parcial (Fix 2) | ✅ Verified |

---

## Summary

**Overall**: ✅ Ready (PASS; SRC-31 fechado e re-verificado em 2026-10-02; resta o débito Minor do Fix 7).

**Spec-anchored check**: 36/36 SRCs batem com o resultado do spec (35 completos + SRC-31 com a parte ≥24h ⏳); 12 spec-precision gaps listados, nenhum bloqueante.
**Sensor**: 39/39 mutations killed (P0-full), 0 survived.
**Gate**: 1540 runs × 3, 0 failed, 0 skipped; rubocop, brakeman estrito, `verify_fixture.py` e `docker compose build` saída 0; flake D-10 0/3.

**What works**: Fix 1–6 fecham com evidência própria; ingestão idempotente; presença só no fechamento de run `succeeded`; coleção e wishlist intocadas em todas as mutações; remap com colisão/ambíguo/rollback; 401 sem repetir; chave filtrada em todas as camadas e ausente de stdout/stderr do rake, `inspect`, snapshots e `log`; progresso com teto de 100%; descartes fora de `failed_count`.

**Issues found**: nenhuma lacuna real. Débitos: Fix 7 parcial; checkboxes `tasks.md:828`, `:603`, `.context/tasks.md:340`; `spec.md:257` com a contagem antiga.

**Next steps**: decidir D-03 (SRC-19). Opcional: repetir `compare_snapshots` numa janela maior (dias, com lançamento de set) para endurecer a evidência do SRC-31.

---

## Re-verificação SRC-31 (2026-10-02)

Verifier independente (author ≠ verifier). Git só leitura; `git status --porcelain` antes e depois idêntico (`?? .playwright-mcp/`). Sem `ingestion:import` nem `remap`; sensor de mutação opcional não executado.

| # | Verificação | Evidência | Veredito |
| - | ----------- | --------- | -------- |
| 1 | Comparação real refeita | `bin/rails ingestion:compare_snapshots A=storage/ingestion/apitcg-20261001T024920Z.json B=storage/ingestion/apitcg-20261001T231649Z.json` → `comuns: 7252`, `mudados: 0` | ✅ |
| 1b | Intervalo | nomes: 02:49:20Z → 23:16:49Z = 20h27m29s (≥ 20h) | ✅ |
| 1c | ImportRun#4 | `rails runner`: `status=succeeded`, `source_revision="apitcg-20261001T231649Z.json sha256:f0e29004…"` (arquivo B), 23:20:04→23:20:17Z | ✅ |
| 2 | Teste cobre `changed > 0` e `== 0` | `compare_snapshots_test.rb:21` `assert_equal 1, result.changed`, `:76` idem (id → ausente); `:42` e `:60` `assert_equal 0, result.changed`; serviço `compare_snapshots.rb:42-45`; `bin/rails test` nos 2 arquivos (`compare_snapshots_test.rb`, `test/lib/ingestion_compare_snapshots_task_test.rb`): 9 runs, 39 assertions, 0 falhas | ✅ |
| 3 | Coerência documental | `spec.md:187` ("ao menos 20h", D-14), `:235` SRC-31 ✅, `:242` Coverage 36/36, `:258` Success Criterion `[x]`; `tasks.md:603` `[x]`, Status (`tasks.md:13`) "Done pending verification"; `.context/tasks.md:340` §8.6 `[x]`; `design.md:432` e `CLAUDE.md:179-181` citam 20h27m, sem "VERIFICAR" sobre `tcgplayer.id`; `STATE.md:157` AD-020, `:167` bloco 2026-10-02 | ✅ |
| 4 | Emenda legítima | `tmp/orchestration-decisions.md:73` "Resposta do dono (D-14): opção 1 — fechar com 20h27m"; AD-020 `STATE.md:157-164` | ✅ |
| 5 | `validate_state.py fonte-apitcg` | `0 error(s)`, saída 0 | ✅ |

Incoerências menores (não bloqueantes): `STATE.md:169` (bloco 2026-10-01) ainda diz "24h+" e "§8.6 fica aberta", mas é bloco superado pelo de 2026-10-02 (que declara vencer os de baixo); `tasks.md:13` Status ainda "pending verification", a atualizar para Done por quem tem a escrita do arquivo (este verifier só altera `validation.md`).

**O que 20h27m sustenta:** os 7.252 produtos comuns mantiveram `markets.tcgplayer.id` entre duas buscas independentes, então a chave `variant_code = tcgplayer:<id>` é estável entre buscas consecutivas e a idempotência (Req. 1.4) não se perde nesse horizonte; coleção/wishlist intactas.
**O que NÃO prova:** estabilidade em janelas longas (dias/semanas), reimportações de produto pela apitcg, lançamento de set novo ou limpeza da fonte; uma única janela de um par de snapshots; a saída do rake só informa comuns/mudados (produtos só de um lado, `only_in_a/b`, não aparecem). Risco residual aceito pelo dono em D-14; mitigado por `ingestion:remap`.

**Veredito: PASS ✅.** Ressalva do SRC-31 removida do **Result**.
