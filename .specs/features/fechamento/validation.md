# Fechamento do MVP — Validation

**Date**: 2026-09-29
**Spec**: `.specs/features/fechamento/spec.md`
**Diff range**: `de99cab^..HEAD` (`de99cab` = `docs(fechamento): escrever o roteiro do teste manual da §7.1`, primeiro commit da feature; HEAD = `37d2050`). Commits da feature: `de99cab`, `f6a2a23`, `f216901`, `051d06a`, `130a667`, `0dd8b31`, `ad7c2a0`, `c78fd80`, `830b8ad`, `eebced8` (relatório do ciclo 1), `b9b6f6f`, `0ea612d`, `a33a7d1`, `3b61fe9`, `40e9485`, `9800d85`, `f6b958f`, `9fc7419`, `37d2050`. Os commits `conformidade` intercalados (`cead276`, `4ca730a`, `c1ebaf1`, `1085994`, `dec1dd9` etc.) não são desta feature.
**Verifier**: independente, novo (autor ≠ verificador; não escreveu a feature nem fez o ciclo 1), Sonnet, **ciclo 2 de no máximo 3**
**Veredito**: ❌ **FAIL** (ciclo 2) — os 4 Major do ciclo 1 estão fechados; sobram 2 Done-when não cumpridos (T12 e T9) e 1 lacuna cosmética.
**Result**: ❌ FAIL (ciclo 2)
**Histórico**: ciclo 1 = FAIL, git `eebced8`.

Feature só de documentos: a evidência é `arquivo:linha` ou saída de `grep`/`ls`/`git`/comando real, re-derivada do zero. Nada foi editado fora de `validation.md`, `.specs/LESSONS.md` e `.specs/lessons.json` (este só via `lessons.py`).

---

## Task Completion

| Task | Status | Notas |
| ---- | ------ | ----- |
| T1 README | ✅ Done | `README.md:16` (`docker compose up`), `:35` (`.env` opcional), `:23` (catálogo vazio), `:47`, `:60-70` (ingestão, `storage/ingestion/`, código 1, `(AD-001)`), `:78-96` (gates) |
| T2 requirements.md | ✅ Done | Req. 10: `requirements.md:258` (AD-006), `:266` (AD-007), `:269` (AD-008); `grep -c "AD-00[678]"` → 3; `grep -c VERIFICAR` → 0 |
| T3 design.md | ✅ Done | `design.md:215-231` (staging, AD-007), `:472`, `:563-579` (AD-009/010/017/018); nota de forma em `design.md:589` (FEC-07) |
| T4 VERIFICAR | ✅ Done | `grep -n VERIFICAR` → `design.md:527,537,628` = "3 ocorrências / 2 pendências" de `verificar-resolvidos.md` |
| T5 decisões | ✅ Done | `decisoes-do-dono.md` com Req. 5.1 |
| T6 fechamento | ⚠️ Partial (esperado) | §7.2 `[x]` (`.context/tasks.md:314`), §7.1 `[ ]` (`:307`); o único `[ ]` restante é o `validate_state.py fechamento` (`tasks.md:266`), que só sai 0 com PASS |
| T7 README | ✅ Done | `docker compose exec -T -e REUSE_PAYLOAD=1 app sh -c "echo $REUSE_PAYLOAD"` → `1` (sem `-e` → vazio); `grep -n "REUSE_PAYLOAD=1 docker" README.md` → 0; `grep -n "storage/ingestion\|código 1\|AD-001" README.md` → `:68,:69,:70`; os 5 gates do `CLAUDE.md` comparados um a um em `README.md:78,81,84,90,96` |
| T8 P8 no design | ✅ Done | `design.md:602` termina em "Req. 12.11 (emenda de 2026-09-29)"; `grep -n "^| P8" design.md \| grep -c 12.11` → 1, `13.7` → 0; `git show 40e9485` altera 1 linha |
| T9 Rastreamento | ⚠️ Partial | P1–P4 em "Resolvidas" com AD (`requirements.md:508-518`). **Falha o 2º Done-when**: P8 continua a única aberta mas sem `(AD-NNN)`/`(emenda de 2026-09-29)` (`requirements.md:526`); o texto-guia "bloqueiam o início da implementação" (`:522`) ficou valendo só para P8, que não bloqueia (`design.md:602`: chips neutros) |
| T10 Handoff | ✅ Done | `grep -c "confirmado fora de spec" .specs/STATE.md` → 0; `STATE.md:151` diz "Req. 5.1 continua aberto"; 1350 runs, 10/10 mutações e "ciclo 3: PASS" conferem com `conformidade/validation.md:8`; `validate_state.py conformidade` → 0 |
| T11 spec/tasks | ✅ Done | `spec.md:54` diz "sem citação nominal de AD-011/013" (`grep -c "AD-011\|AD-013"` → 0 nos dois documentos); T6 cita `validate_state.py fechamento` e `Done`; `validate_spec.py` → 0, `validate_tasks.py` → 0 |
| T12 roteiro | ⚠️ Partial | **Falha o 1º, 2º e 4º Done-when**: `grep -n "48" roteiro-7-1.md` → `:115` "o total (48)" (121 no resto do arquivo); "12% concluído" (`:98,:107`) não é texto da tela. Acertos: 121 (`baseSetSize` do OP01 na fixture e no banco), `<details>` fechado no celular (`:151`) |
| T13 decisões | ✅ Done | `grep -c "(contexto)" decisoes-do-dono.md` → 0; `:17` atribui as 4933 ao banco de dev (medido: `CardVariant.count` → 4933, `image_url_large` NULL → 4933) e diz que a fixture não traz o campo (chaves da fixture: sem `image_url_large`) |

---

## Spec-Anchored Acceptance Criteria

| Critério | Resultado definido na spec | Evidência (`arquivo:linha` / comando) | Result |
| -------- | -------------------------- | ------------------------------------- | ------ |
| FEC-01 | `docker compose up` único; `.env` opcional | `README.md:16`, `:35`; `docker-compose.yml` usa `${VAR:-default}`; `grep -c env_file docker-compose.yml` → 0 | ✅ PASS |
| FEC-02 | catálogo vazio; passo seguinte `ingestion:import` | `README.md:23`, `:47`; `lib/tasks/ingestion.rake:2-3` (`namespace :ingestion` / `task import`) | ✅ PASS |
| FEC-03 | revisão imutável de `config/ingestion.yml` (AD-001); payload em `storage/ingestion/` ignorado pelo git; `REUSE_PAYLOAD=1` sem rede | `README.md:42` e `:69-70` (AD-001); `:68`; `.gitignore:20` (`/storage/ingestion/`); `:65` executável — `docker compose exec -T -e REUSE_PAYLOAD=1 app sh -c "echo $REUSE_PAYLOAD"` → `1`; o hash de `config/ingestion.yml` não está copiado no README | ✅ PASS |
| FEC-04 | quick, full, build e `verify_fixture.py`, comando exato | `README.md:78` (quick), `:81` (full), `:84` (build), `:90` (brakeman), `:96` (`python3 spec/verify_fixture.py` → exit 0) | ✅ PASS |
| FEC-05 | comando citado inexistente é corrigido | `ls .env.example .github/workflows/ci.yml config/brakeman.ignore spec/verify_fixture.py config/ingestion.yml docs/adr docs/pesquisa` → todos existem; tarefa `ingestion:import` existe | ✅ PASS (README). Roteiro: ver seção abaixo |
| FEC-06 | AD ativa que altera requisito → `(AD-NNN)` na linha | `requirements.md:258`, `:266`, `:269`; valores casam o código: `app/services/collection_csv/parser.rb:28` (`MAX_LINHAS = 10_000`) | ✅ PASS |
| FEC-07 | idem em design.md | `design.md:223,231,472` (AD-007), `:563,567` (AD-009), `:571` (AD-010), `:575` (AD-017), `:579` (AD-018); `db/structure.sql:156` (`CREATE TABLE public.collection_imports`); `collection_imports_controller.rb:102` (`find_by_token_for`); `upsert.rb:16` (`clock:`); `catalog_search_test.rb:77` (`gin_clean_pending_list`), `:408` (`SemTransacaoTest`). Nota de forma: a frase "Uma aberta (P8)." (`design.md:589`) mudou em `0dd8b31` sem `(AD-NNN)`/emenda; a linha P8 (`:602`) traz a emenda e a T8 dispensa a frase | ⚠️ Spec-precision gap (baixo) |
| FEC-08 | AD já refletida não se reescreve | `git show 051d06a 0dd8b31 ad7c2a0` só acrescentam/removem; `spec.md:54` corrigido: `grep -c "AD-011\|AD-013" .context/requirements.md .context/design.md` → 0 e 0 | ✅ PASS |
| FEC-09 | Req. 10: substituição, staging com expiração, 10.000 linhas | `requirements.md:257-259` (AD-006), `:264-267` (AD-007), `:268-270` (AD-008) | ✅ PASS |
| FEC-10 | §3/§6 staging; §8 regras AD-009/010/017/018 | `design.md:215-236`, `:472-477`, `:563-583`; `grep -c "AD-009\|AD-010\|AD-017\|AD-018" design.md` → 5 (≥ 4) | ✅ PASS |
| FEC-11 | §9 mantém P6 revista (AD-012) e lista P8 coerente com o Rastreamento | `design.md:600` (P6, AD-012); `:602` P8 "Req. 12.11"; `requirements.md:526` P8 "Req. 12.11"; `requirements.md:338` é o critério 11 do Req. 12 (chips das seis cores); Rastreamento sem P1–P4 bloqueadoras (`:508-518`, cada uma com AD-001/AD-002/AD-003; `ls docs/adr` → 001 e 002) | ✅ PASS |
| FEC-12 | remoção registrada com local, texto e fonte | `verificar-resolvidos.md` tabela "Resolvidos" (2 linhas com fonte e data); `git show ad7c2a0` remove só os 2 marcadores | ✅ PASS |
| FEC-13 | não resolvidos permanecem, listados | `grep -n VERIFICAR .context/design.md` → `:527,:537,:628`; `verificar-resolvidos.md` "Permanecem abertos" (Req. 5.1; regras de deck) coerente com as 3 linhas / 2 pendências | ✅ PASS |
| FEC-14 | remoção só com fonte conferida | reaberto: `db/migrate/20260919120100_add_catalog_indexes.rb:6-12`, `test/models/catalog_indexes_test.rb:127,160` | ✅ PASS |
| FEC-15 | contagem em requirements.md depois da task | `verificar-resolvidos.md` "Contagem após task T4"; `grep -c "VERIFICAR" .context/requirements.md` → 0 | ✅ PASS |
| FEC-16 | requisito errado → decisão do dono, sem alterar | `decisoes-do-dono.md` seção "devolvidos como `blocked`": Nenhum; nenhum Req. numerado mudou de sentido nos commits da fase 5 (`9800d85` só mexe no Rastreamento) | ✅ PASS |
| FEC-17 | correção inequívoca registrada sob "Corrigidos por AD" | `decisoes-do-dono.md` tabela sem `(contexto)`; a nota sobre P8 cita AD-011, que trata de P8 (`STATE.md:88`, "pendência **P8**") | ✅ PASS |
| FEC-18 | Req. 5.1 aberto com evidência de `design.md` §7 | `decisoes-do-dono.md:9-34`; `design.md:527-539`; `db/migrate/20260919120000_create_catalog_tables.rb:65` (única menção a `image_url_large` fora de teste; `grep -rn image_url_large app lib` → 0); `test/integration/card_detail_test.rb:19-21` | ✅ PASS |
| FEC-19 | §7.2 marcada; Handoff sem "concluída" indevido, Req. 5.1 aberto | `.context/tasks.md:314` `[x]`, `:307` `[ ]`; `STATE.md:151` ("Verifier pendente"; "Req. 5.1 continua aberto") | ✅ PASS |
| FEC-20 | `validate_state.py` sai 0 | Comando agora certo (`tasks.md:266`, `validate_state.py fechamento`); sai ≠ 0 enquanto este relatório for FAIL — fecha com o PASS | ⏳ Pendente (portão de fechamento) |
| FEC-21 | ordem subida → ingestão | `README.md:16` antes de `:47` | ✅ PASS |
| FEC-22 | aborta antes de escrever; aponta `REUSE_PAYLOAD=1` | `README.md:60-65`; `app/services/ingestion/fetch.rb` lança `SourceUnavailable` antes do `Upsert`; comando de `:65` executável (medido, FEC-03) | ✅ PASS |
| FEC-23 | contorno `DOCKER_CONFIG` intacto | `git diff de99cab^..HEAD -- README.md \| grep -c "DOCKER_CONFIG\|credential"` → 0; bloco em `README.md:121-129` | ✅ PASS |
| FEC-24 | nada fora do `Where` | `git show --stat` por commit (ver Code Quality); nenhum commit `(fechamento)` toca `app lib db test config spec` (`git log --grep='(fechamento)' -- app lib db test config spec` → 0) | ✅ PASS |

**Status**: ⚠️ Spec-anchored **22/24 PASS**, 1 spec-precision gap baixo (FEC-07), 1 pendente por construção (FEC-20). Nenhum GAP de FEC. O FAIL vem de Done-when de tasks (T9, T12), abaixo.

### Roteiro `roteiro-7-1.md` contra o repositório (T12)

Confere: OP01 `baseSetSize` = **121**, `totalSetSize` 154 (`spec/fixtures/optcgjson-subset.json`; banco: `[121, 154]`); botões e rótulos existem — "Entrar para registrar posse" (`app/views/catalog/index.html.erb:49`, `_ownership.html.erb:126`), "Criar conta" (`sessions/new.html.erb:23`, `registrations/new.html.erb:35`), "Voltar ao catálogo" (`catalog/show.html.erb:3`), "Minha pasta"/"Catálogo" (`layouts/application.html.erb:31-32`), `ownership__button--increment` (`_ownership.html.erb:118`), `<details class="catalog__filters-toggle">` sem `open` (`catalog/index.html.erb:70`), rota `/cards/:id` (`config/routes.rb:15`), "15 de 121 do set base" e "2 de 33 parallels" no formato da view (`progress/index.html.erb:230,238-241`).

Falhas:
1. `roteiro-7-1.md:115` — "o total (**48**)": sobra do número antigo; contradiz o 121 de `:98,:107`. T12 Done-when 1 (`grep -n "48"` sem ocorrência injustificada) não cumprido.
2. `roteiro-7-1.md:98,107` — "**12% concluído**" não é texto que a tela produz. A view escreve o percentual na linha do set como `15 / 154 · 12%` (`progress/index.html.erb:204-212`, `number_to_percentage`) e a legenda `15 de 121 do set base · 2 de 33 parallels` (`:230,:238-241`); "N% concluído" só existe num comentário ERB (`:36`). T12 Done-when 2 e 4 não cumpridos.
3. (baixo) `roteiro-7-1.md:151` diz `<details>` "com classe `catalog__filters`"; a classe do `<details>` é `catalog__filters-toggle` (`catalog/index.html.erb:70`); `catalog__filters` é o `<div>` interno (`:81`).

---

## Discrimination Sensor

Feature só de documentos: o sensor mede se as **verificações dos Done-when** detectam a falta. Cópia em `/tmp/claude-1000/bindr-verify/` (rsync sem `.git`, `tmp`, `log`, `node_modules`, `.playwright-mcp`); cada arquivo restaurado da árvore real após a mutação; cópia apagada no fim.

| # | Arquivo | Falta injetada | Verificação testada | Killed? |
| - | ------- | -------------- | ------------------- | ------- |
| a | `README.md:47` | `ingestion:import` → `ingestion:carregar` | T1/FEC-05: cada `bin/rails ns:task` do README existe em `lib/tasks/*.rake` → `['ingestion:carregar']` | ✅ Killed |
| b | `.context/design.md` | reinserir um `⚠️ VERIFICAR` resolvido | T4: nº de marcadores × contagem de `verificar-resolvidos.md` → `design=4 declarado=3` | ✅ Killed |
| c | `.context/requirements.md:266` | remover `(AD-007)` | T2: `grep -c "AD-00[678]"` ≥ 3 → 2 | ✅ Killed |
| d | `.context/design.md:215,231` | `collection_imports` → `collection_stagings` | T3: tabela citada existe em `db/structure.sql` (`CREATE TABLE public.collection_imports`, `:156`) → `['collection_stagings']` | ✅ Killed |
| e | `README.md:80-81` | apagar o gate full | T7 (verificação inversa): cada gate do `CLAUDE.md` no README → faltam `bin/rubocop` e "full" | ✅ Killed (e1) · ❌ **Survived** (e2: Independent Test da spec vai README→fontes; apagar comando não a quebra) |
| f | `STATE.md:151` | `gate full 1350 runs` → `1349` | T10: comparar com o gate medido (1350) → `handoff=1349 gate=1350` | ✅ Killed pela comparação · ❌ **Survived** no validador automático (`validate_state.py fechamento` dá a mesma saída antes e depois: não compara números) |
| g | `README.md:65` | remover `-e` de `REUSE_PAYLOAD` | T7: `grep "REUSE_PAYLOAD=1 docker"` e presença de `exec -e`; execução real: `REUSE_PAYLOAD=1 docker compose exec -T app sh -c 'echo [${REUSE_PAYLOAD}]'` → `[]`, com `-e` → `[1]` | ✅ Killed |

**Sensor depth**: lightweight (7 faltas; feature de documentos)
**Result**: **7/7 faltas mortas** pelas verificações dos Done-when; 2 verificações persistentes são fracas (e2 na spec; validador automático em f): lacuna baixa, porque o Done-when de T7/T10 as cobre quando executado.

Observação: o sensor não pega o defeito real que sobrou (`roteiro-7-1.md:115`), porque o Done-when de T12 (`grep -n "48"`) foi marcado `[x]` sem ser reexecutado — falha de execução do Done-when, não de desenho.

Isolamento: `git status --porcelain` da árvore real antes e depois → `?? .playwright-mcp/` nos dois (igual ao baseline); `ls /tmp/claude-1000/bindr-verify` → inexistente.

---

## Code Quality (validate.md §6 adaptado)

| Princípio | Status |
| --------- | ------ |
| Só arquivos do `Where` tocados | ✅ `git show --stat` por commit: `f216901`, `130a667`, `3b61fe9` só `README.md`; `051d06a`, `9800d85` `requirements.md`; `0dd8b31`, `ad7c2a0`, `40e9485` `design.md`; `ad7c2a0` + `verificar-resolvidos.md`; `c78fd80`, `0ea612d` `decisoes-do-dono.md`; `830b8ad` `.context/tasks.md`, `STATE.md`, `spec.md`, `tasks.md`; `f6b958f` `STATE.md`; `a33a7d1` `spec.md`, `tasks.md`; `9fc7419` `roteiro-7-1.md`. Os `tasks.md` que acompanham são só checkboxes (protocolo: o orquestrador marca). Nenhum código, teste, migração ou folha |
| Sem escopo extra | ✅ `roteiro-7-1.md` (§7.1) fora da spec (`spec.md:30`), mas é o Where da T12 |
| Mudança mínima | ✅ `40e9485` altera 1 linha de `design.md`; `9800d85` só o Rastreamento |
| Nenhum fato sem fonte | ⚠️ ver roteiro `:115`, `:98,:107` |
| Casa com o estilo existente | ✅ `(AD-NNN)` e `(emenda de …)` no estilo do documento |
| Tests mapeiam para AC | N/A — nenhum teste novo (matriz: none); gate full prova que o código não mudou |
| Diretrizes documentadas | `CLAUDE.md` (gates) e `.context/README.md` (convenção `⚠️ VERIFICAR`) |

---

## Edge Cases

- [x] FEC-21 — ordem subida → ingestão (`README.md:16` → `:47`)
- [x] FEC-22 — fonte indisponível (`README.md:60-65`, comando executável)
- [x] FEC-23 — contorno `DOCKER_CONFIG` intacto
- [x] FEC-24 — nada fora do `Where`

---

## Gate Check

- **Gate command**: `DOCKER_CONFIG=/tmp/claude-1000/bindr-dockercfg docker compose exec -T app bin/rails test && docker compose exec -T app bin/rubocop`
- **Result**: `1350 runs, 5656 assertions, 0 failures, 0 errors, 0 skips`; RuboCop `163 files inspected, no offenses detected`
- **Test count before feature**: 1350 — **after**: 1350 — **Delta**: 0 (nenhum código mudou pela feature)
- **Skipped**: 0
- **`python3 spec/verify_fixture.py`**: exit 0 ("Todas as verificações passaram")
- **`validate_spec.py fechamento/spec.md`**: exit 0; **`validate_tasks.py fechamento/tasks.md`**: exit 0
- **`validate_state.py conformidade`**: exit 0

### Saída do validate_state

`python3 ~/.claude/skills/tlc-spec-driven/scripts/validate_state.py fechamento` roda depois deste relatório; com veredito FAIL sai ≠ 0 (esperado). O resultado está no chat.

---

## Fix Plans

### Fix 1 (Minor): roteiro — número antigo e texto que a tela não produz
- **Root cause**: T12 marcada `[x]` sem reexecutar `grep -n "48"`; "N% concluído" copiado de comentário ERB (`progress/index.html.erb:36`), não da renderização.
- **Fix task**: `roteiro-7-1.md:115` → total 121; `:98,:107` → texto real: linha do set `15 / 154 · 12%` (`progress/index.html.erb:204-212`) e legenda `15 de 121 do set base · 2 de 33 parallels` (`:230,:238-241`); `:151` → classe `catalog__filters-toggle`.
- **Where**: `.specs/features/fechamento/roteiro-7-1.md`. **Verify**: `grep -n "48\|concluído" roteiro-7-1.md` → vazio (ou só justificado).

### Fix 2 (Minor): Rastreamento — P8 sem citação e texto-guia velho
- **Root cause**: T9 deixou a linha P8 e o "bloqueiam o início da implementação" como estavam (`requirements.md:522-526`).
- **Fix task**: reescrever o texto-guia (P8 não bloqueia; chips neutros, `design.md:602`) e terminar a linha P8 com `(emenda de 2026-09-29)`; opcional: P4 "task 0.3" em vez de "task 0.1" (`requirements.md:518`; `.context/tasks.md:35` decide P4 na 0.3).
- **Where**: `.context/requirements.md`. **Verify**: `sed -n 520,526p .context/requirements.md`; `grep -c "⚠️ VERIFICAR"` segue 0.

### Fix 3 (Cosmetic): referências de linha velhas na spec e frase sem citação
- `spec.md:49,66-67,69` citam `design.md:330/355/506/516/579`; hoje os abertos estão em `:527/:537/:628` (usar o texto/título em vez do número). `design.md:589` ("Uma aberta (P8).") sem `(AD-NNN)`/emenda (FEC-07).
- **Where**: `spec.md`, `.context/design.md`.

---

## Requirement Traceability Update

| Requirement | Previous Status | New Status |
| ----------- | --------------- | ---------- |
| FEC-01..06, 08..19, 21..24 | Done | ✅ Verified |
| FEC-07 | Done | ⚠️ Spec-precision (Fix 3, baixo) |
| FEC-20 | Done | ⏳ Pendente do PASS (validate_state) |

(A spec não foi editada por este relatório.)

---

## Fechamento dos 8 Fix do ciclo 1 (`git show eebced8:.specs/features/fechamento/validation.md`)

| Fix ciclo 1 | Estado | Evidência |
| ----------- | ------ | --------- |
| 1 (Major) reuso do payload | ✅ Fechado | `README.md:65` com `-e`; execução → `1` |
| 2 (Major) `storage/ingestion/`, código 1, AD-001 | ✅ Fechado | `README.md:68-70` |
| 3 (Major) P8 "Req. 13.7" | ✅ Fechado | `design.md:602` "Req. 12.11 (emenda de 2026-09-29)" |
| 4 (Major) Rastreamento P1–P4 | ✅ Fechado (com resíduo, Fix 2 acima) | `requirements.md:508-518` |
| 5 (Minor) frase do Handoff | ✅ Fechado | `STATE.md:151`; `grep -c "confirmado fora de spec"` → 0 |
| 6 (Minor) roteiro | ⚠️ Parcial | 121 e `<details>` corrigidos; sobram `:115` (48) e "12% concluído" (Fix 1 acima). Nota: a afirmação do ciclo 1 de que a view não gera "15 / 48" era imprecisa — a view gera `N / M · P%` (`progress/index.html.erb:204-212`); o defeito real era o número e o rótulo "concluído" |
| 7 (Minor) `spec.md:54` | ✅ Fechado | `spec.md:54` |
| 8 (Cosmetic) redação/origem | ✅ Fechado | `tasks.md:266` (`validate_state.py fechamento`), `Done` nos dois arquivos, `decisoes-do-dono.md:17`, `(contexto)` → 0; verificação inversa de gates e comparação de números do Handoff feitas (sensor e, f) |

---

## Summary

**Overall**: ❌ **Not Ready** (FAIL, ciclo 2 de no máximo 3) — resíduos menores, nenhum Major.

**Spec-anchored check**: 22/24 FEC com evidência que casa; 1 spec-precision gap (FEC-07), 1 pendente por construção (FEC-20)
**Sensor**: 7/7 faltas mortas (2 verificações persistentes fracas: e2, validador automático em f)
**Gate**: 1350 runs, 0 falhas, RuboCop limpo; `verify_fixture.py` 0; `validate_spec.py` 0; `validate_tasks.py` 0

**What works**: subida em um comando e ingestão executáveis e completas; Req. 10 e `design.md` §3/§6/§8.1 fiéis ao código; P8 e Rastreamento coerentes com `requirements.md:338`; marcadores `⚠️ VERIFICAR` (3 linhas / 2 pendências) coerentes com `verificar-resolvidos.md`; Handoff honesto e numericamente igual ao gate; origem das 4933 variantes correta; nenhum código mudou pela feature.

**Issues found**: Fix 1 (`roteiro-7-1.md:115,:98,:107`), Fix 2 (`requirements.md:522-526`), Fix 3 (`spec.md:49,66-69`; `design.md:589`).

**Next steps**: rotear Fix 1 e Fix 2 a um implementador (Fix 3 opcional) e reexecutar o Verifier (ciclo 3, último).
