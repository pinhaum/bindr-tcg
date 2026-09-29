# Fechamento do MVP — Validation

**Date**: 2026-09-29
**Spec**: `.specs/features/fechamento/spec.md`
**Diff range**: `de99cab^..HEAD` (`de99cab` = `docs(fechamento): escrever o roteiro do teste manual da §7.1`, primeiro commit da feature; HEAD = `8b9a46a`). Commits da feature: `de99cab`, `f6a2a23`, `f216901`, `051d06a`, `130a667`, `0dd8b31`, `ad7c2a0`, `c78fd80`, `830b8ad`, `eebced8`, `b9b6f6f`, `0ea612d`, `a33a7d1`, `3b61fe9`, `40e9485`, `9800d85`, `f6b958f`, `9fc7419`, `37d2050`, `a5d79a0`, `95fb4e6`, `078c3de`, `ace175a`, `23d1e1c`, `5062de8`, `8b9a46a`. Os commits de `conformidade` intercalados (`cead276`, `4ca730a`, `c1ebaf1`, `1085994`, `dec1dd9`, `df26d1d`, `ca53302` etc.) não são desta feature.
**Verifier**: independente, novo (autor ≠ verificador; não escreveu a feature nem fez os ciclos 1 e 2), Sonnet, **ciclo 3 de no máximo 3 (último)**
**Histórico**: ciclo 1 = FAIL (git eebced8), ciclo 2 = FAIL (git a5d79a0)

**Veredito: FAIL ❌** — resta **um fato errado** de nível Minor num documento da feature, que nenhum dos dois ciclos anteriores pegou: `verificar-resolvidos.md:20-21` cita o marcador das regras de deck como `.context/design.md:628`, mas o marcador está na linha **627** (`grep -n VERIFICAR .context/design.md` → `527`, `537`, `627`). A regra do ciclo é que Minor com fato errado reprova. Todo o resto fecha: 23/24 FEC com evidência (FEC-20 pendente por construção), os 8 Fix do ciclo 1 e os 3 do ciclo 2 fechados, gate verde (1350 runs, 0 falhas, RuboCop limpo), sensor com 12 faltas injetadas e todas mortas por alguma verificação. Um segundo achado, de gravidade menor (exemplo numérico do roteiro), está em "Fix Plans".

---

## Task Completion

| Task | Status | Notes |
| ---- | ------ | ----- |
| T1 | ✅ Done | README: `docker compose up` único (`README.md:15-17`), `.env` opcional (`:29-38`), catálogo vazio (`:23`), ingestão (`:40-70`), gates (`:72-97`), contorno Docker intacto (`:120-129`); commit `f216901`, ajuste `130a667` |
| T2 | ✅ Done | Req. 10.2/10.5/10.6 com AD-006/007/008 (`requirements.md:257-269`); commit `051d06a` |
| T3 | ✅ Done | `design.md` §3 (`:215-236`), §6 (`:472-476`), §8.1 (`:563-582`), §9 (`:589`); commit `0dd8b31` |
| T4 | ⚠️ Partial | Marcadores removidos com fonte (`verificar-resolvidos.md:11-12`), mas a linha do marcador de deck em `:21` está errada (628, real 627) — ver Fix 1 |
| T5 | ✅ Done | `decisoes-do-dono.md` com Req. 5.1 (`:9-34`), "Corrigidos por AD" (`:44-59`) |
| T6 | ✅ Done (um checkbox pendente por desenho) | §7.2 `[x]` (`.context/tasks.md:314`), §7.1 `[ ]` (`:307`), Handoff (`STATE.md:151`). O checkbox `tasks.md:279` (`validate_state.py fechamento`) fica pendente até o PASS; **o supervisor o marca após o PASS** — não reprova |
| T7 | ✅ Done | `README.md:65` com `-e`; `:68-70` com `storage/ingestion/`, código 1, `(AD-001)` |
| T8 | ✅ Done | `design.md:601` termina em "Req. 12.11 (emenda de 2026-09-29)" |
| T9 | ✅ Done | `requirements.md:513-518` (P1–P4 resolvidas), `:522-524` (P8 aberta) |
| T10 | ✅ Done | `STATE.md:151` sem "confirmado fora de spec"; números = gate |
| T11 | ✅ Done | `spec.md:54` reescrita; `tasks.md:279` cita `validate_state.py fechamento`; rótulo `Done` |
| T12 | ✅ Done | superado pela T14 |
| T13 | ✅ Done | `decisoes-do-dono.md:17` (banco de dev), sem "(contexto)" (`grep` → vazio) |
| T14 | ⚠️ Partial (Minor) | Total 121, textos de tela e classe `catalog__filters-toggle` corretos; o exemplo numérico `15 / 154` + `15 de 121 · 2 de 33` é aritmeticamente incoerente com a view — ver Fix Plans #2 |
| T15 | ✅ Done | `requirements.md:518` "task 0.3"; sem "bloqueiam"; `:524` com emenda |
| T16 | ✅ Done | `design.md:589` `(emenda de 2026-09-29)` e `(AD-001..AD-004; tasks 0.1–0.3)` |
| T17 | ✅ Done | `grep -n "design.md:[0-9]" spec.md` → vazio |

---

## Spec-Anchored Acceptance Criteria

Evidência re-derivada do zero por `ls`/`grep`/`sed`/execução nesta sessão (nenhuma linha copiada dos relatórios anteriores).

| Critério | Resultado definido na spec | `file:line` + evidência | Result |
| -------- | -------------------------- | ----------------------- | ------ |
| FEC-01 | `docker compose up` único; `cp .env.example .env` opcional | `README.md:15-17`; `:29-38`. `docker-compose.yml:5-7,28-31` usa `${VAR:-default}`; `grep -n env_file docker-compose.yml` → vazio; `docker-compose.yml:25` `db:prepare && rails server` | ✅ PASS |
| FEC-02 | catálogo vazio + `ingestion:import` | `README.md:23-24`, `:47`. `db/seeds.rb`: 0 linhas não comentadas; `lib/tasks/ingestion.rake:2-3` | ✅ PASS |
| FEC-03 | revisão de `config/ingestion.yml`, imutável, `(AD-001)`, `storage/ingestion/` ignorado, `REUSE_PAYLOAD=1` | `README.md:42-44,65,68-70`; `.gitignore:20` `/storage/ingestion/`; `config/ingestion.yml:3-7` (rejeita `main`/`HEAD`/`latest`); `docker compose exec -T -e REUSE_PAYLOAD=1 app sh -c 'echo $REUSE_PAYLOAD'` → `1`; `grep -n "REUSE_PAYLOAD=1 docker" README.md` → vazio; `grep -n "storage/ingestion\|código 1\|AD-001" README.md` → 3 linhas (68, 69, 70) | ✅ PASS |
| FEC-04 | gates quick/full/build + `verify_fixture.py` com comando exato | `README.md:78,81,84` = `CLAUDE.md:78-79` (quick, full, build); `:90` brakeman (`CLAUDE.md:70`); `:96` `python3 spec/verify_fixture.py` (`CLAUDE.md:85`); `ls spec/verify_fixture.py` existe; execução → "Todas as verificações passaram" | ✅ PASS |
| FEC-05 | comando/arquivo citado existe | rake `ingestion:import` (`lib/tasks/ingestion.rake:3`); `.github/workflows/ci.yml` (lint `:22,29`, postgres `:36`, `POSTGRES_TEST_DB` `:58`); `config/brakeman.ignore`; `docs/adr/{001,002}`; `ls` de todos ok. Roteiro: classes `progress-set__owned-line` (`app/views/progress/index.html.erb:204`), `catalog__filters-toggle` (`app/views/catalog/index.html.erb:70`), `site-header__back`, `ownership__button--increment`, `card-detail__variants`, `progress__list` existem em `app/views` | ✅ PASS |
| FEC-06 | AD ativa que altera `requirements.md` é citada na linha | `requirements.md:258` (AD-006), `:266` (AD-007), `:269` (AD-008); as demais AD já refletidas: `:290` (AD-012), `:360,:439` (AD-016), `:410` (AD-015) | ✅ PASS |
| FEC-07 | `design.md` cita `(AD-NNN)` na linha alterada | `design.md:223,231,472` (AD-007), `:563,567` (AD-009), `:571` (AD-010), `:575` (AD-017), `:579` (AD-018), `:589` (AD-001..AD-004 e emenda), `:601` (emenda); `requirements.md:524` (emenda) | ✅ PASS |
| FEC-08 | AD já refletida não é reescrita | `grep -c AD-011\|AD-013` em ambos os documentos → 0 (refletidas no conteúdo, `design.md` §11 e `requirements.md` Req. 13); `spec.md:54` diz isso; `git diff` dos commits de documento só acrescenta | ✅ PASS |
| FEC-09 | Req. 10: substituição (AD-006), staging com expiração (AD-007), 10.000 linhas (AD-008) | `requirements.md:257-259,264-267,268-270`; código: `app/services/collection_csv/parser.rb:28` `MAX_LINHAS = 10_000`, `:151` `return nil if tabela.size <= MAX_LINHAS`; `app/models/collection_import.rb:36,59-60,94`; `grep -c "AD-00[678]" requirements.md` → 3 | ✅ PASS |
| FEC-10 | §3/§6 staging; §8 regras AD-009/010/017/018 | `design.md:215-226,231-237` × `db/structure.sql:156-166,759-761` (colunas, `CHECK`, `ON DELETE RESTRICT`); `:472-476` × `collection_import.rb:75` `find_by_token_for`, `collection_imports_controller.rb:102,104`; §8.1 `:563-582` × `upsert.rb:16` `clock:`, `catalog_search_test.rb:109` `gin_clean_pending_list`, `:408` `SemTransacaoTest`, `set_progress_plan_test.rb:368,525,530`; `grep -c "AD-009\|AD-010\|AD-017\|AD-018" design.md` → 5 | ✅ PASS |
| FEC-11 | §9: P6 revista pela AD-012; P8 aberta, coerente com o Rastreamento | `design.md:599` (P6/AD-012), `:601` (P8, Req. 12.11) = `requirements.md:333` (o critério 11 das seis cores é o 12.11) e `:524`; `design.md:589` | ✅ PASS |
| FEC-12 | marcador resolvido removido com local, texto e fonte no log | `verificar-resolvidos.md:11-12`: fontes abertas por mim — `db/migrate/20260919120100_add_catalog_indexes.rb:2-19` (unaccent STABLE, wrapper) e `:6-12`; `test/models/catalog_indexes_test.rb:127-128,160`. `git show ad7c2a0^:.context/design.md` tinha 5 linhas de marcador (349, 374, 531, 541, 632); hoje 3 | ✅ PASS |
| FEC-13 | não resolvido permanece e é listado | `design.md:527,537` (Req. 5.1), `:627` (deck) permanecem; `verificar-resolvidos.md:20-21` os lista — **mas cita `:628` para o deck, e o marcador está em `:627`** (ver Fix 1) | ❌ GAP (Minor, fato errado) |
| FEC-14 | conferir a fonte na mesma task | fontes conferidas e verdadeiras (ver FEC-12); `image_url_large` NULL nas 4933 variantes (`bin/rails runner`: `CardVariant.count` = 4933, `where(image_url_large: nil).count` = 4933); `spec/fixtures/optcgjson-subset.json`: 0 ocorrências de `image_url_large`/`imageUrlLarge`; `card_detail_test.rb:21` `image_url_large: image` | ✅ PASS |
| FEC-15 | contagem do `requirements.md` depois da task | `verificar-resolvidos.md:27-28`: design 3 linhas / 2 pendências; requirements 0; `grep -c "⚠️ VERIFICAR"` → design 3, requirements 0 | ✅ PASS |
| FEC-16 | requisito errado não alterado, vira decisão | `decisoes-do-dono.md:38-40` (nenhum devolvido); `git diff` de `051d06a` e `0dd8b31` só acrescenta | ✅ PASS |
| FEC-17 | correção inequívoca citada em "Corrigidos por AD" | `decisoes-do-dono.md:44-59`: commits `051d06a`/`0dd8b31` existem (`git show -s`), Req. 10.2/10.5/10.6 conferem em `requirements.md:257-269`; AD-011 contém P8 (`STATE.md:88`) | ✅ PASS |
| FEC-18 | Req. 5.1 aberto com evidência de §7 | `decisoes-do-dono.md:9-34`; `design.md:526-540` (§7 "Pendência aberta"); Req. 5.1 em `requirements.md` | ✅ PASS |
| FEC-19 | §7.2 marcada; Handoff com ponto de retomada | `.context/tasks.md:314` `[x]`, `:307` `[ ]`; `STATE.md:151` (fechamento T1–T6 "com Verifier pendente"; Req. 5.1 aberto; próximo passo Verifier e depois §7.1); sem "concluída" indevida; números = gate (`1350`, `0 falhas`, `10/10`, `conformidade/validation.md:8,139-140,174,204-205`) | ✅ PASS |
| FEC-20 | `validate_state.py` sai 0 | pendente do PASS por construção (rodado ao fim deste relatório; sai ≠ 0 enquanto o veredito for FAIL) | ⏳ Pendente do PASS |
| FEC-21 | ordem subida → ingestão | `README.md:15-24` antes de `:47` | ✅ PASS |
| FEC-22 | fonte indisponível aborta antes de escrever; `REUSE_PAYLOAD=1` | `README.md:60-65`; `requirements.md` Req. 1.8 | ✅ PASS |
| FEC-23 | contorno `DOCKER_CONFIG` mantido | `README.md:120-129`; `git diff f216901^ HEAD -- README.md \| grep -n "DOCKER_CONFIG\|credential"` → nenhuma linha removida | ✅ PASS |
| FEC-24 | nada fora do `Where` | ver "Code Quality" — cada commit da feature só tocou o `Where` da task (mais o checkbox de `tasks.md`, permitido pelo protocolo) | ✅ PASS |

**Status**: ❌ Gaps present — 22/24 FEC com evidência que casa; FEC-13 com fato errado (Minor) e FEC-20 pendente por construção.

### Fechamento dos 8 Fix do ciclo 1 (`git show eebced8:.specs/features/fechamento/validation.md`)

| Fix ciclo 1 | Estado | Evidência |
| ----------- | ------ | --------- |
| 1 (Major) reuso do payload | ✅ Fechado | `README.md:65`; execução `-e` → `1` |
| 2 (Major) `storage/ingestion/`, código 1, AD-001 | ✅ Fechado | `README.md:68-70` |
| 3 (Major) P8 "Req. 13.7" | ✅ Fechado | `design.md:601` "Req. 12.11"; `13.7` na linha → 0 |
| 4 (Major) Rastreamento P1–P4 | ✅ Fechado | `requirements.md:513-518` (P1 task 0.1, P2 0.2, P3/P4 0.3, conferido em `.context/tasks.md:14-39`) |
| 5 (Minor) frase do Handoff | ✅ Fechado | `grep -c "confirmado fora de spec" STATE.md` → 0; `STATE.md:151` "Req. 5.1 continua aberto" |
| 6 (Minor) roteiro | ✅ Fechado (resíduo de exemplo, Fix Plans #2) | 121 (`roteiro-7-1.md:72,115`), `<details>` (`:54,151`) |
| 7 (Minor) `spec.md:54` | ✅ Fechado | `spec.md:54` diz "Refletidas no conteúdo, sem citação nominal" |
| 8 (Cosmetic) redação/origem | ✅ Fechado | `tasks.md:279`; `Done` nos dois arquivos; `decisoes-do-dono.md:17`; `grep -n "(contexto)"` → vazio |

### Fechamento dos gaps do ciclo 2 (`git show a5d79a0:.specs/features/fechamento/validation.md`)

| Fix ciclo 2 | Estado | Evidência |
| ----------- | ------ | --------- |
| 1 roteiro (48, "concluído", classe do filtro) | ✅ Fechado | `grep -n "48\|concluído" roteiro-7-1.md` → vazio; `roteiro-7-1.md:98,107` = `index.html.erb:204-212`, `:230,:237-241`; `:151` `catalog__filters-toggle` = `catalog/index.html.erb:70`; `catalog__filters` só em `:81` (painel) |
| 2 Rastreamento (guia velho, P8, P4) | ✅ Fechado | `grep -n bloqueiam requirements.md` → vazio; `:518` task 0.3; `:524` emenda |
| 3 spec.md e design.md:589 | ✅ Fechado | `grep -n "design.md:[0-9]" spec.md` → vazio; `design.md:589` com as duas citações |

**Novo achado que os dois ciclos deixaram passar:** `verificar-resolvidos.md:21` (`:628`, real `:627`) — ver Fix 1.

---

## Discrimination Sensor

Feature de documentos: o sensor mede se as **verificações dos Done-when** detectam falta. Cópia em `/tmp/claude-1000/bindr-verify/` (`rsync -a --exclude .git --exclude tmp --exclude log --exclude node_modules --exclude .playwright-mcp`); cada falta injetada e revertida; verificação-base passou em todas antes (exceto a `l`, que já falha na árvore real e é o Fix 1).

| # | Falta injetada (arquivo) | Verificação correspondente | Killed? |
| - | ------------------------ | -------------------------- | ------- |
| a | `ingestion:import` → `ingestion:importar` (`README.md`) | cada `bin/rails ns:task` do README existe em `lib/tasks/*.rake` (T1 Done-when 7) | ✅ Killed |
| b | `⚠️ VERIFICAR` reinserido em `design.md` §4.1.1 | `grep -c "⚠️ VERIFICAR" design.md` = nº registrado em `verificar-resolvidos.md:27` (T4 Done-when 5) | ✅ Killed |
| c | `(AD-007)` removido de `requirements.md:266` | `grep -c "AD-00[678]"` ≥ 3 e cada AD presente (T2 Done-when 6) | ✅ Killed |
| d | `collection_imports` → `collection_import` (`design.md:215`) | cada nome `collection_*` de §3 existe em `db/structure.sql` (`grep -qw`; T3 Done-when 1). Uma 1ª versão da checagem (regex que exigia `s` final) deixou a falta passar — erro do meu script, não da verificação; corrigido | ✅ Killed |
| e | linha do gate full apagada (`README.md`) | cada gate do `CLAUDE.md` aparece com comando exato (T7 Done-when 6) | ✅ Killed |
| f | `1350 runs` → `1349 runs` (`STATE.md` Handoff) | número do Handoff = saída do gate (T10 Done-when 2) | ✅ Killed |
| g | `exec -e REUSE_PAYLOAD=1 app` → `exec REUSE_PAYLOAD=1 app` e → `exec app` | grep positivo do comando exato (T7 Done-when 1, 1ª frase) mata as duas; o `grep -n "REUSE_PAYLOAD=1 docker"` sozinho **não** pega | ✅ Killed (pela forma positiva; a negativa isolada é fraca) |
| h | `154` → `164` (`roteiro-7-1.md`) | comparação do total com `OP01 card_variants.count` (= 154, `bin/rails runner`) mata; as verificações que a **T14 declara** (grep dos textos na view, `grep 48`, 121 vs fixture) **não** | ✅ Killed pela comparação com o banco; ⚠️ o Done-when da T14 não a exige (lacuna, Nit) |
| i | `` `storage/ingestion/` `` removido (`README.md:68`) | `grep -n "storage/ingestion\|código 1\|AD-001"` ≥ 3 linhas (T7 Done-when 5) | ✅ Killed |
| j | P8 de `design.md:601` volta a "13.7" | `grep "^| P8" \| grep -c 12.11` = 1 e `13.7` = 0 (T8 Done-when 2) | ✅ Killed |
| k | `design.md:330` reinserido em `spec.md` | `grep -n "design.md:[0-9]" spec.md` vazio (T17 Done-when 2) | ✅ Killed |
| l | `527, 537` → `531, 541` em `verificar-resolvidos.md` | linhas citadas × `grep -n VERIFICAR design.md` — **na árvore real já falha (`628` ≠ `627`)** | ✅ Killed (e revelou o Fix 1) |

**Sensor depth**: lightweight ampliado (12 faltas; ≥ 6 pedidas)
**Result**: 12/12 killed — PASS ✅. **Ressalva**: duas verificações persistentes fracas — (g) o grep negativo isolado da T7; (h) o Done-when da T14 não compara o total `154` com a fonte. Nenhuma foi promovida a fix bloqueante (a g é coberta pela forma positiva; a h é Nit). Note também que **a verificação `l` não existe em nenhum Done-when**: o de T4 exige "fonte com arquivo e linha" mas nenhum passo recomputa a linha citada — é a causa do Fix 1.
**Isolamento**: cópia apagada; `git status --porcelain` da árvore real = `?? .playwright-mcp/` (igual ao baseline).

---

## Code Quality

| Principle | Status |
| --------- | ------ |
| Minimum code / nenhum código mudou | ✅ (fora de `conformidade`, os commits da feature só tocam `README.md`, `.context/*.md`, `.specs/**`; gate = 1350 runs) |
| Surgical changes — cada commit só tocou o `Where` da sua task | ✅ `f216901`/`130a667`/`3b61fe9` (README); `051d06a`/`9800d85`/`23d1e1c` (`requirements.md` + checkbox); `0dd8b31`/`ad7c2a0`/`40e9485`/`078c3de` (`design.md` [+ `verificar-resolvidos.md` na T4] + checkbox); `c78fd80`/`0ea612d`/`37d2050` (`decisoes-do-dono.md` [+ checkbox]); `830b8ad` (T6: 4 arquivos do `Where`); `f6b958f` (`STATE.md`); `a33a7d1`/`8b9a46a` (`spec.md`, `tasks.md`); `9fc7419`/`ace175a` (`roteiro-7-1.md`). Único arquivo extra recorrente: `tasks.md` (checkbox, permitido pelo protocolo "o orquestrador marca no commit") |
| No scope creep | ✅ |
| Matches patterns (`(AD-NNN)`/`(emenda de …)` na linha) | ✅ |
| Spec-anchored outcome check | ⚠️ 22/24 (ver tabela) |
| Every check maps to a spec requirement | ✅ |
| Documented guidelines followed | `CLAUDE.md` (gates), `.context/README.md` (convenção `⚠️ VERIFICAR`); Português do Brasil ✅ |

---

## Edge Cases

- [x] FEC-21 ordem subida → ingestão (`README.md:15` antes de `:47`)
- [x] FEC-22 fonte indisponível (`README.md:60-65`; Req. 1.8)
- [x] FEC-23 `DOCKER_CONFIG` intacto (`README.md:120-129`)
- [x] FEC-24 nada fora do `Where`

---

## Gate Check

- **Gate command**: `DOCKER_CONFIG=/tmp/claude-1000/bindr-dockercfg docker compose exec -T app bin/rails test && docker compose exec -T app bin/rubocop`
- **Result**: 1350 runs, 5656 assertions, 0 failures, 0 errors, 0 skips; RuboCop: 163 files inspected, no offenses detected (executado uma vez)
- **Outros**: `python3 spec/verify_fixture.py` → "Todas as verificações passaram"; `validate_spec.py` da feature → 0; `validate_tasks.py` da feature → 0
- **Test count before feature**: 1350 (`dca1413`, último commit de `conformidade`); **after**: 1350; **Delta**: 0 (nenhum código mudou pela feature)
- **Skipped tests**: 0
- **Failures**: nenhum

---

## Fix Plans

### Fix 1 (Minor, bloqueia o PASS): `verificar-resolvidos.md` cita a linha errada do marcador de deck
- **Root cause**: `.specs/features/fechamento/verificar-resolvidos.md:21` diz `.context/design.md:628` e `:27` diz "linha 628"; `grep -n "VERIFICAR" .context/design.md` → `527`, `537`, `627`. O número foi escrito na T4 e nunca recomputado; os ciclos 1 e 2 conferiram a contagem (3) mas não a linha.
- **Fix task**: trocar `628` por `627` nas duas ocorrências (`:21` e `:27`) — ou, melhor, citar a seção ("`design.md` §10, regras de deck") como a T17 já fez na spec (lição L-049).
- **Where**: `.specs/features/fechamento/verificar-resolvidos.md`.
- **Verify**: `grep -n "VERIFICAR" .context/design.md` e conferir cada número citado em `verificar-resolvidos.md`; ou `grep -n "628" .specs/features/fechamento/verificar-resolvidos.md` → vazio.

### Fix 2 (Minor/Nit, não bloqueia sozinho): exemplo numérico incoerente no roteiro
- `roteiro-7-1.md:98,107-108,115` apresentam, como saída do mesmo cartão, `15 / 154 · 12%` e `15 de 121 do set base · 2 de 33 parallels`. Na view, a primeira linha é `owned_variants / total_variants` (`app/queries/set_progress_query.rb:219,221-224`: `owned_variants` conta base **e** parallel possuídas) e a legenda mostra `base_owned de base_size · parallel_owned de parallels`. Com 15 base e 2 parallels possuídos o cartão mostraria `17 / 154 · 12%`. Os textos e formatos são reais; só o exemplo é impossível. Total 154 = 121 + 33 confere no banco (`OP01`: 154 variantes, 121 base, 33 parallels).
- **Fix task** (opcional, junto com o Fix 1): `15 / 154` → `17 / 154` em `:98,:107`, ajustar `:115`, ou rotular o exemplo como "ilustrativo". **Where**: `roteiro-7-1.md`.

### Nits (forma; não reprovam)
- `tasks.md:13` diz `Status: In Progress (… T1–T13 Done)` com T14–T17 marcadas `[x]`; o supervisor atualiza após o PASS.
- `STATE.md:151` lista os marcadores abertos por assunto e arquivo (`verificar-resolvidos.md`), não pelo local (`design.md` §7, §10) que o Done-when da T6 cita.
- `decisoes-do-dono.md:20` diz que `design.md` registra a frase entre aspas "na linha 527"; a frase está em `:528` (a 527 é o título com o marcador).

---

## Requirement Traceability Update

| Requirement | Previous Status | New Status |
| ----------- | --------------- | ---------- |
| FEC-01..12, 14..19, 21..24 | Done | ✅ Verified |
| FEC-13 | Done | ❌ Needs Fix (Fix 1: `verificar-resolvidos.md:21,27`) |
| FEC-20 | Done | ⏳ Pendente do PASS (`validate_state.py`) |

(A spec não foi editada por este relatório.)

---

## Summary

**Overall**: ❌ **Not Ready** (FAIL, ciclo 3 de 3) — um Minor com fato errado; a regra de 3 iterações manda escalar ao usuário se persistir.

**Spec-anchored check**: 22/24 FEC com evidência que casa; 1 com fato errado (FEC-13), 1 pendente por construção (FEC-20). Fix 1–8 do ciclo 1 e 1–3 do ciclo 2: fechados.
**Sensor**: 12/12 faltas mortas; 2 verificações persistentes fracas (g, h)
**Gate**: 1350 runs, 0 falhas, RuboCop limpo; `verify_fixture.py` 0; `validate_spec.py` 0; `validate_tasks.py` 0

**What works**: subida e ingestão executáveis e completas; Req. 10 e `design.md` §3/§6/§8.1 fiéis ao código e a `db/structure.sql`; Rastreamento e §9 coerentes com P1–P8, AD e tasks 0.1–0.3; Handoff honesto e numericamente igual ao gate; `decisoes-do-dono.md` correto (origem das 4933 variantes, AD reais); textos de tela do roteiro iguais à view; nenhum arquivo fora do `Where`; nenhum código mudou.

**Issues found**: Fix 1 (`verificar-resolvidos.md:21,27`, linha 628 → 627) bloqueia; Fix 2 (exemplo do roteiro) e os três Nits não bloqueiam sozinhos.

**Next steps**: corrigir o Fix 1 (troca de dois números, ou citar a seção), opcionalmente o exemplo do roteiro; o supervisor marca `tasks.md:279` após o PASS. Como este foi o 3º ciclo, **escalar ao usuário**: aceitar a correção de dois números sem um 4º ciclo completo, ou reexecutar o Verifier só sobre o Fix 1.
