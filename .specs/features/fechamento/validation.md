# Fechamento do MVP — Validation

**Date**: 2026-09-29
**Spec**: `.specs/features/fechamento/spec.md`
**Diff range**: `de99cab^..HEAD` (`de99cab` = `docs(fechamento): escrever o roteiro do teste manual da §7.1`, primeiro commit da feature; HEAD = `830b8ad`). Commits da feature nesse intervalo: `de99cab`, `f6a2a23`, `f216901`, `051d06a`, `130a667`, `0dd8b31`, `ad7c2a0`, `c78fd80`, `830b8ad`. Os commits `conformidade` intercalados não são desta feature.
**Verifier**: independente (autor ≠ verificador; não escreveu nada desta feature)
**Veredito**: ❌ **FAIL** (ciclo 1)

Feature só de documentos: a "evidência" é `arquivo:linha` ou saída de `grep`/`ls`/`git`/comando real. Nada foi editado fora de `validation.md` e das lições.

---

## Task Completion

| Task | Status | Notas |
| ---- | ------ | ----- |
| T1 README | ⚠️ Partial | Falham: `storage/ingestion/` ausente do README e `sai com código 1` ausente (`README.md:42-66`; `grep -n "storage\|código 1" README.md` → 0 linhas); o comando `REUSE_PAYLOAD=1 docker compose exec …` (`README.md:65`) não repassa a variável ao container. O checkbox `[x]` do item 3 está marcado sem o texto (`tasks.md:104`) |
| T2 requirements.md | ⚠️ Partial | Req. 10 correto (`requirements.md:257-269`, três `AD-00[678]`). O item "Rastreamento de pendências segue coerente" (`tasks.md:136`) não se sustenta: `requirements.md:513-519` ainda lista P1–P4 como bloqueadoras, decididas desde 2026-09-19 (`design.md:589`) |
| T3 design.md | ⚠️ Partial | §3, §6, §8.1 conferidos contra o repositório. Falha: P8 cita "Req. 13.7" (`design.md:602`), que trata de 360px; o Req. correto é 12.11 (`requirements.md:519`, `:338`) |
| T4 VERIFICAR | ✅ Done | 2 resolvidos com fonte aberta e conferida; 3 linhas abertas (`design.md:527, 537, 628`) = "3 ocorrências / 2 pendências" de `verificar-resolvidos.md:27` |
| T5 decisões | ✅ Done | Req. 5.1 com evidência conferida; ressalvas de forma em Fix 8 |
| T6 fechamento | ⚠️ Partial | §7.2 `[x]` e §7.1 `[ ]` (`.context/tasks.md:314,307`); Handoff escrito sem "concluída" indevido. `tasks.md:250` continua `[ ]` (o Done-when cita `validate_state.py .specs/STATE.md`, mal redigido) e o Handoff contém uma frase enganosa (Fix 5) |

---

## Spec-Anchored Acceptance Criteria

| Critério | Resultado definido na spec | Evidência (`arquivo:linha` / comando) | Result |
| -------- | -------------------------- | ------------------------------------- | ------ |
| FEC-01 | `docker compose up` único; `.env` opcional | `README.md:15-17` (comando), `:29-38` (opcional). `docker-compose.yml:5-7` usa `${VAR:-default}`; `grep -c env_file docker-compose.yml` → 0 | ✅ PASS |
| FEC-02 | catálogo vazio; próximo passo `ingestion:import` | `README.md:23-24`, `:47`. `db/seeds.rb` só tem comentário; `lib/tasks/ingestion.rake:2-3` define `ingestion:import` | ✅ PASS |
| FEC-03 | revisão de `config/ingestion.yml` imutável (AD-001); payload em `storage/ingestion/` ignorado pelo git; `REUSE_PAYLOAD=1` reprocessa sem rede | Revisão: `README.md:42-44` ✓ (`app/services/ingestion/source_config.rb:8` rejeita `main/head/latest`). **`grep -n "storage\|ignorad" README.md` → nenhuma linha**. `README.md:65` `REUSE_PAYLOAD=1 docker compose exec app …`: medido, `REUSE_PAYLOAD=1 docker compose exec -T app sh -c 'echo [${REUSE_PAYLOAD}]'` → `REUSE_PAYLOAD=[]`; só com `-e REUSE_PAYLOAD=1` → `[1]`. `docker-compose.yml` não declara a variável. O comando documentado não ativa o reuso | ❌ GAP |
| FEC-04 | quick, full, build e `verify_fixture.py`, comando exato | `README.md:73-81`, `:86` (brakeman), `:92`. `CLAUDE.md` traz os mesmos; `python3 spec/verify_fixture.py` → exit 0 | ✅ PASS |
| FEC-05 | comando citado inexistente é corrigido | `ls spec/verify_fixture.py .env.example .github/workflows/ci.yml config/brakeman.ignore config/ingestion.yml docs/adr docs/pesquisa` → todos existem; `lib/tasks/ingestion.rake:3`. Existência ✓ (mas ver FEC-03: existe e não funciona) | ✅ PASS |
| FEC-06 | AD ativa que altera requisito → `(AD-NNN)` na linha | `requirements.md:258` (AD-006), `:266` (AD-007), `:269` (AD-008). Valores casam o código: `app/services/collection_csv/parser.rb:28` (`MAX_LINHAS = 10_000`), `:150-154` (mensagem em português com o limite; contagem sem cabeçalho, `headers: true` `:107`) | ✅ PASS |
| FEC-07 | idem em design.md | `design.md:223, 231, 472` (AD-007), `:563, 567` (AD-009), `:571` (AD-010), `:575` (AD-017), `:579` (AD-018). `db/structure.sql:156-166,675,682,689,760` casam colunas, índices, CHECK e `ON DELETE RESTRICT`; `app/models/collection_import.rb:94` `limpar_expiradas`; `app/controllers/collection_imports_controller.rb:102-104` `find_by_token_for` + `RecordNotFound`; `app/services/ingestion/upsert.rb:16` `clock:`; `test/queries/catalog_search_test.rb:109` `gin_clean_pending_list`, `:408` `SemTransacaoTest`. **Exceção**: §9 mudou de "Nenhuma." para "Uma aberta (P8)." (`design.md:589`) e a linha P8 (`:602`) sem `(AD-NNN)` nem emenda | ⚠️ Spec-precision gap (forma da citação; Fix 3) |
| FEC-08 | AD já refletida não se reescreve | `git show 051d06a 0dd8b31 ad7c2a0` só acrescentam/removem marcadores; nenhuma linha refletida foi reescrita. **Mas** `spec.md:54` diz que "`grep` mostra as citações" de AD-011/012/013/015/016: `grep -c "AD-011\|AD-013"` em `requirements.md` e `design.md` → 0 e 0 (AD-012 tem citações; AD-015/016 só em `requirements.md:410,360,439`). O conteúdo está refletido (`design.md:639` §11; `requirements.md:349` Req. 13), sem a citação que a definição de FEC-08 exige ("citada e coerente") | ⚠️ Spec-precision gap (Fix 7) |
| FEC-09 | Req. 10: substituição, staging com expiração, 10.000 linhas | `requirements.md:257-259, 264-267, 268-270`; `git show 051d06a` só acrescenta | ✅ PASS |
| FEC-10 | §3/§6 staging e §8 regras AD-009/010/017/018 | `design.md:214-227` (§3.2), `:231-236` (§3.3), `:472-477` (§6), `:562-585` (§8.1). Todos os nomes conferidos (linha FEC-07) | ✅ PASS |
| FEC-11 | §9 mantém P6 revista (AD-012) e lista P8 coerente com "Rastreamento" de requirements.md | P6: `design.md:600` ✓ (AD-012). P8 listado: `design.md:602`, **mas cita "Req. 13.7"** (o Req. 13.7 trata das verificações de 360px), enquanto o Rastreamento cita "Req. 12.11" (`requirements.md:519`, `:338`). Além disso o Rastreamento (`requirements.md:511-519`) mantém P1–P4 como "bloqueiam o início", contradizendo `design.md:589` | ❌ GAP |
| FEC-12 | remoção registrada com local, texto e fonte | `verificar-resolvidos.md:9-13` (2 linhas com fonte e data). `git show ad7c2a0 -- .context/design.md` remove só os 2 marcadores (`design.md:346-374`) | ✅ PASS |
| FEC-13 | não resolvidos permanecem, listados | `grep -n VERIFICAR .context/design.md` → `:527`, `:537`, `:628`; `verificar-resolvidos.md:17-21` lista os 2 assuntos; ambos sem fonte primária (nenhum regulamento no repositório; `image_url_large` só em `db/migrate/20260919120000_create_catalog_tables.rb:65`, nenhum `app/` escreve) | ✅ PASS |
| FEC-14 | remoção só com fonte conferida | Reabri as fontes: `db/migrate/20260919120100_add_catalog_indexes.rb:4-19` (unaccent STABLE, `to_tsvector` 2 args IMMUTABLE), `:6-12`; `test/models/catalog_indexes_test.rb:127`, `:160` (`gin_trgm_ops`). Casam `verificar-resolvidos.md:11-12` | ✅ PASS |
| FEC-15 | contagem em requirements.md depois da task | `verificar-resolvidos.md:28`; `grep -c "VERIFICAR" .context/requirements.md` → 0 | ✅ PASS |
| FEC-16 | requisito errado → decisão do dono, sem alterar | `decisoes-do-dono.md:38-40` ("Nenhum"). **Contradição**: os achados de FEC-11 (P8 com Req. errado; P1–P4 no Rastreamento) são incoerências que a task devia ter devolvido ou corrigido | ⚠️ Spec-precision gap (Fix 3, 4) |
| FEC-17 | correção inequívoca registrada | `decisoes-do-dono.md:44-58`; a linha `(contexto)` de `:56` contradiz a frase de `:46` ("cada adição citando a AD") | ⚠️ Spec-precision gap (Fix 8) |
| FEC-18 | Req. 5.1 aberto com evidência de §7 | `decisoes-do-dono.md:9-34`. Conferido: `requirements.md:132-133`, `design.md:527-539` (4933 vem do banco de dev, `.specs/features/imagens/spec.md:69`; a fixture tem 5 sets — `decisoes-do-dono.md:17` redige de forma ambígua), `test/integration/card_detail_test.rb:19-21`, `db/migrate/20260919120000_create_catalog_tables.rb:65`, `requirements.md:425` (Req. 13.19) | ✅ PASS |
| FEC-19 | §7.2 marcada; Handoff | `.context/tasks.md:314` `[x]`, `:307` `[ ]`; `.specs/STATE.md:151` novo bloco, "Verifier pendente", sem "concluída". Mas traz "(Req. 5.1 confirmado fora de spec, em `verificar-resolvidos.md`)" junto dos marcadores **resolvidos**; o Req. 5.1 está aberto — frase enganosa | ⚠️ Spec-precision gap (Fix 5) |
| FEC-20 | `validate_state.py` sai 0 sobre o STATE | Não verificável como redigido: o script recebe o nome da feature (`validate_state.py fechamento`), não o caminho | ⚠️ Spec-precision gap (Fix 8) |
| FEC-21 | ordem subida → ingestão | `README.md:15-24` antes de `:40-47` | ✅ PASS |
| FEC-22 | aborta antes de escrever; aponta `REUSE_PAYLOAD=1` | Texto: `README.md:60-62`; código: `app/services/ingestion/fetch.rb:67,74` lança `SourceUnavailable` antes do `Upsert` (`run.rb:14-20`). O comando apontado em `:65` não funciona (medição em FEC-03) | ❌ GAP |
| FEC-23 | contorno `DOCKER_CONFIG` intacto | `git show f216901 -- README.md` não toca `README.md:116-125` | ✅ PASS |
| FEC-24 | nada fora do `Where` | `git show --stat` de cada commit: só `README.md`, `.context/*.md`, `.specs/**` (ver Code Quality) | ✅ PASS |

**Status**: ❌ Gaps present. **Spec-anchored: 15/24 PASS**; 3 GAP (FEC-03, FEC-11, FEC-22); 6 spec-precision gaps (FEC-07, 08, 16, 17, 19, 20).

Conferências extras de fatos citados (verdadeiras salvo o listado): `docker-compose.yml` (`db:prepare` no `command`, `:26`), `lib/tasks/ingestion.rake`, `config/ingestion.yml`, `spec/verify_fixture.py`, `.gitignore:20` (`/storage/ingestion/`), `.github/workflows/ci.yml:22,29,35-36,58`, `db/structure.sql` (`collection_imports`), `MAX_LINHAS`, `CollectionImport.find_by_token_for`, `clock:`, `gin_clean_pending_list`, AD-001..AD-018 e Handoff contra STATE. `grep -n VERIFICAR`: `design.md` 3 linhas, `requirements.md` 0.

Roteiro (`roteiro-7-1.md`) contra as views: os botões e classes existem (`app/views/catalog/show.html.erb:3,193`, `app/views/collection_items/_ownership.html.erb:126`, `app/views/layouts/application.html.erb:31-37`, `app/views/sessions/new.html.erb:23`, `app/views/progress/index.html.erb`). Falhas: `roteiro-7-1.md:98,107,115,155` usam denominador **48** para o OP01, mas `baseSetSize` do OP01 é **121** (`spec/fixtures/optcgjson-subset.json`); `:107` mostra "OP01 · 15 / 48", formato que a view não gera (a view escreve "N de M variantes"); `:151` diz "não colapsado" mas `<details class="catalog__filters-toggle">` não tem `open` (`app/views/catalog/index.html.erb:70`; só fica aberto por CSS a partir de 1024px, `catalog.css:2193-2204`).

---

## Discrimination Sensor

Feature só de documentos: o sensor mede se as **verificações da própria feature** (grep/ls/validadores dos Done-when e do Independent Test) detectam a falta. Cópia em `/tmp/claude-1000/bindr-verify/` (rsync sem `.git`), restaurada após cada mutação e apagada no fim.

| # | Arquivo:linha | Falta injetada | Verificação testada | Killed? |
| - | ------------- | -------------- | ------------------- | ------- |
| a | `README.md:47,65` | `ingestion:import` → `ingestion:carregar` | T1: cada `bin/rails X` do README existe em `lib/tasks/*.rake` | ✅ Killed |
| b | `design.md:~369` | reinserir `⚠️ VERIFICAR` resolvido (`grep -c` 3 → 4) | T4: `grep -c "⚠️ VERIFICAR" design.md` = nº de abertos (3) | ✅ Killed |
| c | `requirements.md:266` | remover `(AD-007)` | T2: `grep -c "AD-00[678]"` ≥ 3 (3 → 2) | ✅ Killed |
| d | `design.md:214,231,472` | `collection_imports` → `collection_stagings` | T3: nome de tabela citado existe em `db/structure.sql` | ✅ Killed |
| e | `README.md:76-77` | apagar o gate full | (e1) Done-when T1: lista quick/full/build com comando exato; (e2) Independent Test da spec: cada comando do README aparece nas fontes | e1 ✅ Killed · e2 ❌ **Survived** (a checagem só vai README→fontes; apagar comando não a quebra) |
| f | `STATE.md:151` | `1350 runs` → `1349 runs` | verificações da feature (Done-when T6 + `validate_state.py fechamento`): o script só acusou a falta de `validation.md`, idêntico ao baseline; nenhum Done-when compara os números com o gate | ❌ **Survived** |
| g | `README.md:42` | `config/ingestion.yml` → `config/ingest.yml` | T1/FEC-05: `ls` de cada arquivo citado | ✅ Killed |

**Sensor depth**: lightweight (7 faltas; feature de documentos)
**Result**: **6/7 mortas**, 1 sobreviveu (f) e uma verificação (e2, Independent Test) é fraca — ❌ FAIL.

Observação: nenhuma dessas verificações detectou os defeitos reais achados acima (comando `REUSE_PAYLOAD` ineficaz, "Req. 13.7", P1–P4 no Rastreamento). Elas checam **existência** de nomes, não **comportamento** nem **coerência entre documentos**.

Isolamento: `git status --porcelain` da árvore real antes e depois → `?? .playwright-mcp/` (igual ao baseline); cópia removida (`ls /tmp/claude-1000/bindr-verify` → inexistente).

---

## Code Quality (validate.md §6 adaptado)

| Princípio | Status |
| --------- | ------ |
| Só arquivos do `Where` tocados | ✅ `git show --stat`: `f216901`, `130a667` só `README.md`; `051d06a` `requirements.md` (+ `tasks.md` só com checkboxes, permitido pelo protocolo "o orquestrador marca"); `0dd8b31` `design.md` (+ `tasks.md`); `ad7c2a0` `design.md`, `verificar-resolvidos.md` (+ `tasks.md`); `c78fd80` `decisoes-do-dono.md` (+ `tasks.md`); `830b8ad` `.context/tasks.md`, `STATE.md`, `spec.md`, `tasks.md`. Nenhum código, teste, migração ou folha |
| Sem escopo extra | ✅ nenhum arquivo fora do `Where`; `roteiro-7-1.md` (`de99cab`) é a §7.1, fora da spec (`spec.md:30`), mas versionado como apoio |
| Mudança mínima | ✅ diffs de `requirements.md` (+11/−2) e `design.md` só acrescentam/removem marcadores |
| Nenhum fato sem fonte | ❌ ver FEC-03, FEC-11, roteiro (48 vs 121) |
| Casa com o estilo existente | ✅ citações `(AD-NNN)` no estilo do documento |
| Tests mapeiam para AC | N/A — nenhum teste novo (Test Coverage Matrix: none); gate full prova que o código não mudou |
| Diretrizes documentadas seguidas | `CLAUDE.md` (gates) e `.context/README.md` (convenção de `⚠️ VERIFICAR`); "none - strong defaults applied" nas demais |

---

## Edge Cases

- [x] FEC-21 — ordem subida → ingestão (`README.md:15-47`)
- [ ] FEC-22 — fonte indisponível: texto ok (`README.md:60-62`), mas o comando de reuso (`:65`) não funciona
- [x] FEC-23 — contorno `DOCKER_CONFIG` intacto
- [x] FEC-24 — nada fora do `Where`

---

## Gate Check

- **Gate command**: `DOCKER_CONFIG=/tmp/claude-1000/bindr-dockercfg docker compose exec -T app bin/rails test && docker compose exec -T app bin/rubocop`
- **Result**: `1350 runs, 5656 assertions, 0 failures, 0 errors, 0 skips`; RuboCop `163 files inspected, no offenses detected`
- **Test count before feature**: 1350 (Handoff de `conformidade`, `STATE.md:151`)
- **Test count after feature**: 1350 — **Delta**: 0 (nenhum código mudou)
- **Skipped**: 0
- **`python3 spec/verify_fixture.py`**: exit 0 ("Todas as verificações passaram")
- **`validate_spec.py fechamento/spec.md`**: exit 0 (0 erros, 0 avisos)
- **`validate_tasks.py fechamento/tasks.md`**: exit 0 (0 erros, 8 avisos: "Tests: none" e `Where` com vários arquivos em T4/T6)

### Saída do validate_state

`python3 ~/.claude/skills/tlc-spec-driven/scripts/validate_state.py fechamento` roda depois deste relatório; o resultado vai no chat. Com veredito FAIL ele sai ≠ 0, como deve. O Done-when de `tasks.md:250` cita `validate_state.py .specs/STATE.md`, mas o script recebe o **nome da feature**: **spec-precision gap**, registrado sem reprovar por isso.

---

## Fix Plans

### Fix 1 (Major): README — comando de reuso do payload não funciona
- **Root cause**: `README.md:65` escreve `REUSE_PAYLOAD=1 docker compose exec app bin/rails ingestion:import`; a variável fica no processo do `docker compose` e não entra no container (medido: `REUSE_PAYLOAD=[]`).
- **Fix task**: trocar por `docker compose exec -e REUSE_PAYLOAD=1 app bin/rails ingestion:import`.
- **Where**: `README.md`. **Verify**: `docker compose exec -T -e REUSE_PAYLOAD=1 app sh -c 'echo $REUSE_PAYLOAD'` → `1`. **Done when**: FEC-03 e FEC-22 com o comando executável.

### Fix 2 (Major): README — faltam `storage/ingestion/`, "ignorado pelo git" e o código de saída
- **Root cause**: T1 marcada `[x]` sem o texto exigido (`tasks.md:104`; `spec.md:93`).
- **Fix task**: acrescentar onde o payload fica (`storage/ingestion/`, `.gitignore:20`), que a tarefa sai com código 1 se o status não for `succeeded` (`lib/tasks/ingestion.rake:9`) e a citação `(AD-001)` da revisão imutável.
- **Where**: `README.md`. **Verify**: `grep -n "storage/ingestion\|código 1\|AD-001" README.md` ≥ 3 linhas.

### Fix 3 (Major): design.md — P8 cita o requisito errado
- **Root cause**: `design.md:602` termina em "Req. 13.7"; a pendência é o Req. 12.11 (`requirements.md:519`). A linha nova também não traz `(AD-NNN)` ou emenda (FEC-07; `design.md:589` idem).
- **Fix task**: corrigir para "Req. 12.11" e citar a fonte da mudança. **Where**: `.context/design.md`. **Verify**: `grep -n "^| P8" .context/design.md | grep -c "12.11"` → 1.

### Fix 4 (Major): requirements.md — Rastreamento lista P1–P4 como bloqueadoras
- **Root cause**: `requirements.md:511-519` ("Itens que bloqueiam o início da implementação") mantém P1–P4, todas decididas (`design.md:589`, tasks 0.1–0.3). T2 marcou a coerência sem conferir.
- **Fix task**: marcar P1–P4 como resolvidas (com ADR/AD) e manter só P8 aberta, com `(AD-NNN)`/emenda; se a redação exigir decisão do dono, registrar em `decisoes-do-dono.md`. **Where**: `.context/requirements.md`, `decisoes-do-dono.md`.

### Fix 5 (Minor): Handoff enganoso
- **Root cause**: `STATE.md:151` "(Req. 5.1 confirmado fora de spec, em `verificar-resolvidos.md`)" aparece junto dos marcadores **resolvidos**; o Req. 5.1 está **aberto** (`verificar-resolvidos.md:19`).
- **Fix task**: reescrever a frase ("Req. 5.1 continua aberto"). **Where**: `.specs/STATE.md`.

### Fix 6 (Minor): roteiro com fatos não fundamentados
- **Root cause**: `roteiro-7-1.md:98,107,115,155` (48 em vez de 121 do OP01; "15 / 48" não é o formato da view); `:151` ("não colapsado").
- **Fix task**: usar `baseSetSize` real ou marcar o número como ilustrativo, copiar o texto real da tela (`progress/index.html.erb`) e dizer que em <1024px o usuário abre "Filtros" com um toque. **Where**: `roteiro-7-1.md`.

### Fix 7 (Minor): spec.md com afirmação sem fonte
- **Root cause**: `spec.md:54` diz que `grep` mostra as citações de AD-011/013; `grep -c` → 0 em ambos os documentos.
- **Fix task**: corrigir a linha (reflete o conteúdo, sem citação) ou citar as AD em `design.md` §11 / `requirements.md` Req. 13, coerente com FEC-08. **Where**: `spec.md` ou os documentos-fonte.

### Fix 8 (Cosmetic): forma e precisão
- `tasks.md:250` cita `validate_state.py .specs/STATE.md`; o script recebe o nome da feature — corrigir a redação. `tasks.md:248` pede `Implemented` e `spec.md:194-217` usa `Done`. `decisoes-do-dono.md:17` atribui as 4933 variantes à fixture (são do banco de dev) e `:56` traz "(contexto)" onde a tabela promete AD.
- Sensor: acrescentar ao Done-when de T1 a verificação inversa (cada gate do `CLAUDE.md` aparece no README) e a T6 uma comparação dos números do Handoff com o gate.

---

## Requirement Traceability Update

| Requirement | Previous Status | New Status |
| ----------- | --------------- | ---------- |
| FEC-01, 02, 04, 05, 06, 09, 10, 12, 13, 14, 15, 18, 21, 23, 24 | Done | ✅ Verified |
| FEC-03, FEC-22 | Done | ❌ Needs Fix (Fix 1, Fix 2) |
| FEC-11 | Done | ❌ Needs Fix (Fix 3, Fix 4) |
| FEC-07, 08, 16, 17, 19, 20 | Done | ⚠️ Spec-precision (Fix 3, 5, 7, 8) |

(A spec não foi editada por este relatório.)

---

## Summary

**Overall**: ❌ **Not Ready** (FAIL, ciclo 1 de no máximo 3)

**Spec-anchored check**: 15/24 FEC com evidência que casa; 3 GAP (FEC-03, FEC-11, FEC-22) e 6 spec-precision gaps
**Sensor**: 6/7 mutações mortas (1 sobreviveu; 1 verificação fraca)
**Gate**: 1350 passed, 0 failed, RuboCop limpo, `verify_fixture.py` 0, validadores da feature 0

**What works**: subida em um comando e ingestão descritas na ordem certa; Req. 10 fiel ao código (AD-006/007/008); `design.md` §3/§6/§8.1 conferem com `db/structure.sql`, model, controller e testes; os dois `⚠️ VERIFICAR` removidos têm fonte aberta e conferida, e os três abertos permanecem; nenhum arquivo fora do `Where`; nenhum código mudou (1350 runs).

**Issues found**: ver Fix 1–8. Os quatro primeiros bloqueiam o PASS: comando de reuso do payload ineficaz, README sem `storage/ingestion/`/código de saída, "Req. 13.7" errado em P8 e Rastreamento com P1–P4 como bloqueadoras.

**Next steps**: rotear Fix 1–4 (e 5–7) a um implementador; reexecutar o Verifier.
