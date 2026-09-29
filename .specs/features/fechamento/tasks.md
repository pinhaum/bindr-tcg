# Fechamento do MVP — Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Spec**: `.specs/features/fechamento/spec.md` (FEC-01..FEC-24)
**Design**: inline (sem `design.md`: a feature só escreve documentos; nenhum padrão novo)
**Status**: In Progress (Phase 5: correções do ciclo 1 da validação; T1–T6 Done)

Todas as tasks escrevem **só documentos**. Regras que valem para todas:

- Não inventar fato. Nome de arquivo, tarefa rake, tabela, método ou comando citado num documento é aberto e conferido (`ls`, `grep`) na mesma task; se não existir, não entra.
- Mudança mínima: só entra o que uma AD (`.specs/STATE.md`) ou emenda justifica, com `(AD-NNN)` ou `(emenda de AAAA-MM-DD)` na linha alterada. AD já refletida e coerente com o código não se reescreve (FEC-08).
- Português do Brasil; identificadores em inglês.
- Requisito que contradiga o código ou uma AD e não tenha correção inequívoca: não alterar e devolver `blocked` com o requisito e a evidência (a T5 o registra).
- Editar fora do `Where`: parar com `blocked` e nomear o arquivo (FEC-24).
- Proibido `git add -A`, `git add .`, `git stash`, `reset`, `rebase`, `checkout`, worktree; não marcar checkbox neste arquivo (o orquestrador marca no commit).

---

## Test Coverage Matrix

> Generated from codebase, project guidelines, and spec. Guidelines found: `CLAUDE.md` (gates quick/full/build), `.context/README.md` (convenções de `⚠️ VERIFICAR`), `.github/workflows/ci.yml`. A feature não cria nem altera código, então nenhuma camada exige teste novo.

| Camada | Tipo de teste | Cobertura esperada | Onde | Comando |
|---|---|---|---|---|
| Documentação (README, `requirements.md`, `design.md`, planos, STATE, `roteiro-7-1.md`, `decisoes-do-dono.md`; T1–T13) | none (evidência por `grep` e `ls`) | Cada critério da task é conferido por comando de leitura registrado no commit; o gate full prova que nenhum código mudou | `README.md`, `.context/*.md`, `.specs/**` | `grep`, `ls`, `validate_*.py` |
| Aplicação Rails (regressão) | integration + unit (suíte existente) | A suíte inteira continua verde e a contagem de runs não muda | `test/**` | `docker compose exec -T app bin/rails test` |

## Gate Check Commands

Todos com `DOCKER_CONFIG=/tmp/claude-1000/bindr-dockercfg` na frente (diretório com `config.json` contendo `{}`).

| Gate | Quando | Comando |
|---|---|---|
| quick | Não usado nesta feature | `docker compose exec -T app bin/rails test test/models test/queries` |
| full | Toda task (prova que nenhum código mudou) | `docker compose exec -T app bin/rails test && docker compose exec -T app bin/rubocop` |
| build | Fechamento (T6), opcional | `docker compose build` |

Toda task registra a contagem de runs do gate full e ela **não muda**: se mudar,
a task tocou código e volta como `blocked`. A base é a contagem do último commit
de `conformidade` (`dca1413`).

---

## Execution Plan

As fases rodam em sequência. Dentro da Fase 1 as tasks não compartilham arquivo
e podem rodar juntas; `design.md` é editado por T3 e depois por T4, por isso T4
espera T3.

### Phase 1: Atualizar os documentos

```
T1 ∥ T2 ∥ T3
```

### Phase 2: Reconciliar os marcadores do design

```
T3 → T4
```

### Phase 3: Decisões do dono

```
T2 → T5
T4 → T5
```

### Phase 4: Fechamento

```
T1 → T6
T5 → T6
```

### Phase 5: Correções da validação (ciclo 1)

Fonte: `validation.md`, seções "Fix 1" a "Fix 8". As sete tasks têm `Where`
disjuntos e dependem só de T6: rodam em paralelo. Um `blocked` numa não trava as
outras.

```
T6 → T7
T6 → T8
T6 → T9
T6 → T10
T6 → T11
T6 → T12
T6 → T13
```

---

## Task Breakdown

### T1: README com subida em um comando e ingestão

**What**: O README apresenta `docker compose up` como único comando, avisa que o catálogo sobe vazio, documenta `ingestion:import` (revisão fixada, payload em disco, `REUSE_PAYLOAD=1`, falha da fonte) e lista os gates do `CLAUDE.md`.
**Where**: `README.md`
**Depends on**: None
**Reuses**: as seções "Subir o projeto", "Testes e verificações" e "Se o build falhar…" que já existem; `docker-compose.yml`, `lib/tasks/ingestion.rake`, `config/ingestion.yml`, `app/services/ingestion/run.rb`
**Requirement**: FEC-01, FEC-02, FEC-03, FEC-04, FEC-05, FEC-21, FEC-22, FEC-23

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] "Subir o projeto" abre com `docker compose up` como o único comando; `cp .env.example .env` aparece como opcional e só para personalizar (FEC-01). Conferido: `docker-compose.yml` usa `${VAR:-default}` e não tem `env_file`
- [x] O README diz que a primeira subida entrega o catálogo vazio e mostra, na ordem, `docker compose exec app bin/rails ingestion:import` (FEC-02, FEC-21). Conferido: `db/seeds.rb` só tem comentário e a tarefa existe em `lib/tasks/ingestion.rake`
- [x] Seção "Ingestão do catálogo": a revisão vem de `config/ingestion.yml`, é imutável e referência móvel é rejeitada na carga (AD-001); o hash não é copiado; o payload bruto vai para `storage/ingestion/` (ignorado pelo git); `REUSE_PAYLOAD=1` reprocessa sem rede; a saída resume revisão, status, criados/atualizados/falhados e sai com código 1 se o status não for `succeeded` (FEC-03)
- [x] Fonte indisponível: o README diz que o processo aborta antes de escrever no banco (Req. 1.8) e cita `REUSE_PAYLOAD=1` quando já houver payload (FEC-22)
- [x] "Testes e verificações" lista quick, full e build do `CLAUDE.md`, mais `bin/brakeman` e `python3 spec/verify_fixture.py`, cada um com comando exato (FEC-04)
- [x] O contorno de `docker-credential-desktop.exe` fica como está (FEC-23)
- [x] Todo comando, arquivo e tarefa citados existem: `ls`/`grep` de cada um registrado no commit; um que não exista sai do README (FEC-05)
- [x] Gate full passa e a contagem de runs não muda

**Tests**: none
**Gate**: full
**Commit**: `docs(fechamento): documentar subida em um comando e execução da ingestão`

---

### T2: `requirements.md` com o que mudou na execução

**What**: O Req. 10 passa a registrar a substituição da quantidade (AD-006), o staging com expiração (AD-007) e o limite de linhas (AD-008); as demais AD já refletidas são só conferidas.
**Where**: `.context/requirements.md`
**Depends on**: None
**Reuses**: `.specs/STATE.md` AD-001..AD-018; as citações `(AD-012)`, `(AD-016)` que o documento já usa; `app/services/collection_csv/`; `db/structure.sql`
**Requirement**: FEC-06, FEC-08, FEC-09

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Req. 10 acrescenta critérios ou notas, cada um com `(AD-NNN)` na linha: linha cuja variante já é possuída substitui a quantidade, sem somar (AD-006); arquivo entre pré-visualização e confirmação vive em staging dono do usuário, com expiração (AD-007); mais de 10.000 linhas de dado, sem contar o cabeçalho, recusa o arquivo inteiro, com mensagem em português que diz o limite (AD-008)
- [x] Antes de escrever cada nota: nome da tabela de staging, mensagem e constante do limite conferidos por `grep` em `app/`, `db/structure.sql` e `test/`; o que não existir não entra
- [x] Conferidas e, se coerentes, deixadas como estão (FEC-08): AD-001 (fonte, Req. 1), AD-003 (Req. 9), AD-005, AD-011/012/013/015/016 (Req. 11.7, 12, 13). Uma incoerente é corrigida se a AD for inequívoca, senão devolve `blocked` com o requisito
- [x] AD-009, AD-010, AD-014, AD-017 e AD-018 não entram em `requirements.md` (são método ou teste; vão para `design.md` na T3 ou não entram)
- [x] "Rastreamento de pendências" segue coerente: P8 aberto; nenhuma pendência que a execução já resolveu fica como aberta
- [x] `grep -c "⚠️ VERIFICAR" .context/requirements.md` continua 0; `grep -c "AD-00[678]"` ≥ 3
- [x] Gate full passa e a contagem de runs não muda

**Tests**: none
**Gate**: full
**Commit**: `docs(fechamento): registrar no requirements.md as decisões do import`

---

### T3: `design.md` com o que mudou na execução

**What**: `design.md` registra a tabela de staging do import (§3, §6), as regras de teste das AD-009, AD-010, AD-017 e AD-018 (§8) e mantém §9 coerente com P6 revista (AD-012) e P8 aberto.
**Where**: `.context/design.md`
**Depends on**: None
**Reuses**: `.specs/STATE.md`; `db/structure.sql`; `test/queries/catalog_search_test.rb`; `test/queries/set_progress_plan_test.rb`; as citações `(AD-012)`, `(AD-005)` que o documento já usa
**Requirement**: FEC-07, FEC-08, FEC-10, FEC-11

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] §3 (modelo de dados) descreve a tabela de staging do import: dono, expiração e por que existe (AD-007), com o nome real conferido em `db/structure.sql`
- [x] §6 (autorização) diz que a leitura do staging parte de `Current.user` e que uma pré-visualização alheia não é confirmável (AD-007)
- [x] §8 (estratégia de testes) ganha uma linha por regra, cada uma com `(AD-NNN)`: relógio monotônico injetado para asserção de ordem entre marcas de tempo e drenagem da pending list GIN antes de `ANALYZE` para asserção de plano (AD-009); execução de suíte em série por causa do único teste não-transacional (AD-010); guardas protegidos `set_progress_plan_test.rb` e a edição aceita (AD-017) e a regra de `nowrap` com reticências (AD-018)
- [x] Nomes de arquivo, método e parâmetro (`clock:`, `gin_clean_pending_list`) conferidos por `grep` antes de citados
- [x] §9: P6 continua marcada como revista pela AD-012; P8 (cores do jogo) aparece como pendência aberta, coerente com `requirements.md`; a frase "Nenhuma [decisão pendente]. P1–P7…" segue verdadeira
- [x] AD-011, AD-012 e AD-016 conferidas em §7 e §11 e deixadas como estão se coerentes (FEC-08)
- [x] Os `⚠️ VERIFICAR` não são tocados nesta task (são da T4)
- [x] Gate full passa e a contagem de runs não muda

**Tests**: none
**Gate**: full
**Commit**: `docs(fechamento): registrar no design.md staging e regras de teste`

---

### T4: `⚠️ VERIFICAR` resolvidos removidos do `design.md`

**What**: Remove os marcadores resolvidos de `design.md` e cria o `verificar-resolvidos.md` com a fonte de cada remoção e a lista dos que permanecem abertos.
**Where**: `.context/design.md`, `.specs/features/fechamento/verificar-resolvidos.md` (novo)
**Depends on**: T3
**Reuses**: `design.md` §4.1.1; `db/migrate/20260919120100_add_catalog_indexes.rb`; `test/models/catalog_indexes_test.rb`; `db/structure.sql`; `spec/fixtures/optcgjson-subset.json`
**Requirement**: FEC-12, FEC-13, FEC-14, FEC-15

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Marcadores achados por `grep -n "VERIFICAR" .context/design.md .context/requirements.md` e classificados um a um, sem usar a lista da spec como prova (a spec prevê `:330` e `:355` resolvidos, `:506`/`:516` e `:579` abertos)
- [x] Para cada remoção, a fonte foi aberta nesta task: `:330` (menção histórica) pela §4.1.1 e por `pg_proc` na migração `20260919120100`; `:355` (`gin_trgm_ops`, `to_tsvector` de dois argumentos) pela migração e por `test/models/catalog_indexes_test.rb`. O texto verificado permanece; sai só o marcador (FEC-12, FEC-14)
- [x] Marcador cuja fonte não fecha (regra de deck; Req. 5.1 com `image_url_large` vazio) permanece no documento, sem alteração de significado (FEC-13)
- [x] `verificar-resolvidos.md` tem: tabela "Resolvidos" (local original, texto resumido, fonte com arquivo e linha, data), tabela "Permanecem abertos" (local, assunto, por que segue aberto) e a contagem de marcadores de `requirements.md` depois da task (FEC-15)
- [x] `grep -c "⚠️ VERIFICAR" .context/design.md` igual ao número de marcadores abertos registrados no arquivo; `requirements.md` com 0
- [x] Nenhuma linha de `design.md` fora dos marcadores muda nesta task
- [x] Gate full passa e a contagem de runs não muda

**Tests**: none
**Gate**: full
**Commit**: `docs(fechamento): remover os verificar resolvidos do design.md`

---

### T5: Requisitos errados registrados como decisão do dono

**What**: Cria `decisoes-do-dono.md` com o Req. 5.1 e qualquer requisito que T2, T3 e T4 tenham devolvido como errado ou incoerente.
**Where**: `.specs/features/fechamento/decisoes-do-dono.md` (novo)
**Depends on**: T2, T4
**Reuses**: `verificar-resolvidos.md`; `design.md` §7 ("Pendência aberta — Req. 5.1"); `.context/requirements.md` Req. 5.1; `.specs/features/conformidade/spec.md` CNF-14 e CNF-15
**Requirement**: FEC-16, FEC-17, FEC-18

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Seção "Decisões abertas" com a entrada do Req. 5.1: texto do requisito, evidência (`image_url_large` vazio nas 4933 variantes, fixture só com `imageUrl`, `design.md` §7), duas opções (relaxar o requisito para "imagem maior de layout", ou procurar fonte com resolução maior) e a pergunta ao dono (FEC-18)
- [x] Uma entrada para cada requisito devolvido `blocked` pelas T2 e T3, com requisito, evidência e pergunta; nenhum desses requisitos foi alterado (FEC-16)
- [x] Seção "Corrigidos por AD" lista cada correção inequívoca feita em T2 ou T3, com o commit e a AD citada na linha alterada (FEC-17); vazia se não houve
- [x] Verificado por `git diff` dos commits de T2 e T3 que nenhum requisito mudou de sentido sem AD na linha
- [x] Gate full passa e a contagem de runs não muda

**Tests**: none
**Gate**: full
**Commit**: `docs(fechamento): registrar as decisões que cabem ao dono`

---

### T6: Fechamento no plano e no STATE

**What**: Marca a §7.2 em `.context/tasks.md`, atualiza a rastreabilidade das duas peças da feature e escreve o bloco *Handoff* no `STATE.md`; `validate_state.py` sai com 0.
**Where**: `.context/tasks.md`, `.specs/STATE.md`, `.specs/features/fechamento/spec.md`, `.specs/features/fechamento/tasks.md`
**Depends on**: T1, T5
**Reuses**: o formato dos blocos *Handoff* anteriores em `.specs/STATE.md`; `~/.claude/skills/tlc-spec-driven/scripts/validate_state.py`
**Requirement**: FEC-19, FEC-20

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] §7.2 de `.context/tasks.md` marcada `[x]`; a §7.1 fica `[ ]` (fora do escopo)
- [x] Traceability de `spec.md` com FEC-01..24 em `Done` e a coluna Task conferida; checkboxes das tasks T1–T5 marcados neste `tasks.md`; `Status: Done`
- [x] Bloco novo no *Handoff* do `STATE.md`: o que a feature fez, os `⚠️ VERIFICAR` abertos (com o local), as decisões abertas de `decisoes-do-dono.md`, e a §7.1 como próxima etapa do dono
- [ ] `python3 ~/.claude/skills/tlc-spec-driven/scripts/validate_state.py fechamento` sai com 0
- [x] `validate_spec.py` e `validate_tasks.py` desta feature saem com 0
- [x] Gate full passa e a contagem de runs não muda; gate build (`docker compose build`) opcional

**Tests**: none
**Gate**: full
**Commit**: `docs(fechamento): fechar a 7.2 e registrar o handoff`

---

## Phase 5: Correções da validação (ciclo 1)

Mesmas regras do topo do arquivo. Toda task confere a linha citada em
`validation.md` contra o arquivo real antes de editar (a numeração de linhas pode
ter mudado) e registra o `grep` de prova no commit. Proibido editar fora do `Where`.

### T7: README com reuso do payload executável e ingestão completa

**What**: O README passa a usar `docker compose exec -e REUSE_PAYLOAD=1 app bin/rails ingestion:import`, cita `storage/ingestion/` (ignorado pelo git), o código de saída 1 e `(AD-001)`, e traz cada gate do `CLAUDE.md` com comando exato.
**Where**: `README.md`
**Depends on**: T6
**Reuses**: `README.md` seção da ingestão (linha do comando de reuso, hoje `REUSE_PAYLOAD=1 docker compose exec …`); `.gitignore` (`/storage/ingestion/`); `lib/tasks/ingestion.rake` (`exit(1) unless run.status == "succeeded"`); `CLAUDE.md` (gates); `validation.md` Fix 1, Fix 2, Fix 8 (sensor)
**Requirement**: FEC-03, FEC-04, FEC-22 (Fix 1, Fix 2 e a verificação inversa do Fix 8)

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] O comando de reuso é `docker compose exec -e REUSE_PAYLOAD=1 app bin/rails ingestion:import`; a forma antiga (variável antes de `docker compose`) não existe mais: `grep -n "REUSE_PAYLOAD=1 docker" README.md` sai vazio (Fix 1)
- [x] O README diz que o payload bruto fica em `storage/ingestion/` e que o diretório é ignorado pelo git, conferido em `.gitignore` (Fix 2)
- [x] O README diz que a tarefa sai com código 1 quando o status não é `succeeded`, conferido em `lib/tasks/ingestion.rake` (Fix 2)
- [x] A revisão imutável de `config/ingestion.yml` é citada com `(AD-001)`; o hash não é copiado (Fix 2)
- [x] `grep -n "storage/ingestion\|código 1\|AD-001" README.md` devolve ≥ 3 linhas
- [x] Verificação inversa (sensor): cada gate do `CLAUDE.md` (quick, full, build, `bin/brakeman`, `python3 spec/verify_fixture.py`) aparece no README com o comando exato, comparado um a um e registrado no commit
- [x] Todo comando, arquivo e tarefa citados existem (`ls`/`grep` registrados); o contorno `DOCKER_CONFIG` continua como está (FEC-23)
- [x] Gate full passa e a contagem de runs não muda (1350)

**Tests**: none
**Gate**: full
**Commit**: `docs(fechamento): corrigir o reuso do payload e completar a ingestão no readme`

---

### T8: P8 do `design.md` cita o requisito certo

**What**: A linha P8 da tabela §9 passa de "Req. 13.7" para "Req. 12.11" e cita a fonte da mudança.
**Where**: `.context/design.md`
**Depends on**: T6
**Reuses**: `.context/design.md` §9 (linha `| P8`, hoje termina em "Req. 13.7."); `.context/requirements.md` (linha P8 do Rastreamento: "Req. 12.11"); `validation.md` Fix 3
**Requirement**: FEC-07, FEC-11 (Fix 3)

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Conferido em `.context/requirements.md` que o critério das seis cores é o Req. 12.11 antes de editar; se não for, a task devolve `blocked` com a evidência
- [x] `grep -n "^| P8" .context/design.md | grep -c "12.11"` → 1 e `grep -n "^| P8" .context/design.md | grep -c "13.7"` → 0
- [x] A linha P8 (e a frase de §9 logo acima, se repetir a referência) termina com `(AD-NNN)` ou `(emenda de 2026-09-29)`, conforme FEC-07; a AD citada foi aberta em `.specs/STATE.md` e trata do assunto, senão usa a emenda
- [x] Nenhuma outra linha de `design.md` muda: `git diff --stat` mostra só esse arquivo e ≤ 3 linhas alteradas
- [x] Gate full passa e a contagem de runs não muda (1350)

**Tests**: none
**Gate**: full
**Commit**: `docs(fechamento): corrigir a referência do p8 no design`

---

### T9: Rastreamento de pendências do `requirements.md` sem P1–P4 bloqueadoras

**What**: A seção "Rastreamento de pendências" marca P1–P4 como resolvidas, com a referência da decisão, e mantém só P8 como aberta.
**Where**: `.context/requirements.md`
**Depends on**: T6
**Reuses**: `.context/requirements.md` "Itens que **bloqueiam** o início da implementação" (tabela P1–P4 e P8); `.context/design.md` §9 (P1–P7 decididas); `.context/tasks.md` 0.1–0.3; `.specs/STATE.md` AD-001..AD-004; `docs/adr/`; `validation.md` Fix 4
**Requirement**: FEC-06, FEC-11 (Fix 4)

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Cada decisão é conferida na fonte aberta nesta task: P1 (AD-001, task 0.1), P2 (task 0.2), P3 (AD-003, task 0.3, `docs/adr/002-…`), P4 (AD-002); `ls docs/adr` registrado
- [x] P1–P4 saem do texto "bloqueiam o início da implementação": ficam como resolvidas (tabela ou nota separada) com a referência `(AD-NNN)` na linha; P8 continua como a única aberta, com `(AD-NNN)` ou `(emenda de 2026-09-29)` (FEC-07/FEC-06)
- [x] Se a redação certa exigir decisão do dono (ex.: a AD não cobre a pendência), a task não altera o trecho e devolve `blocked` com a pendência, a evidência e a pergunta; o orquestrador a registra em `decisoes-do-dono.md`
- [x] `grep -c "⚠️ VERIFICAR" .context/requirements.md` continua 0
- [x] Nenhum requisito numerado (Req. 1..13) muda; só a seção de rastreamento
- [x] Gate full passa e a contagem de runs não muda (1350)

**Tests**: none
**Gate**: full
**Commit**: `docs(fechamento): marcar p1 a p4 como resolvidas no rastreamento`

---

### T10: Handoff do `STATE.md` sem a frase enganosa sobre o Req. 5.1

**What**: O bloco de Handoff de 2026-09-29 diz que o Req. 5.1 continua aberto e cada número dele confere com o gate.
**Where**: `.specs/STATE.md`
**Depends on**: T6
**Reuses**: `.specs/STATE.md` bloco "Estado em 2026-09-29" (frase "Req. 5.1 confirmado fora de spec, em `verificar-resolvidos.md`"); `.specs/features/fechamento/verificar-resolvidos.md` (tabela "Permanecem abertos"); `validation.md` seção Gate Check e Fix 5
**Requirement**: FEC-19 (Fix 5, sensor do Fix 8)

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] A frase é reescrita: os dois marcadores resolvidos saem de `design.md`, e o Req. 5.1 continua aberto (`verificar-resolvidos.md`, "Permanecem abertos", e `decisoes-do-dono.md`); `grep -n "confirmado fora de spec" .specs/STATE.md` sai vazio
- [x] Sensor: cada número do bloco (1350 runs, 0 falhas, RuboCop limpo, 10 mutações injetadas/10 mortas, contagem de tasks T1–T6) é comparado com o gate de `validation.md` ("1350 runs, 5656 assertions, 0 failures") e com `conformidade/validation.md`; a comparação fica no commit e número divergente é corrigido
- [x] Nenhum bloco anterior do Handoff é reescrito; só o de 2026-09-29
- [x] Gate full passa e a contagem de runs não muda (1350)

**Tests**: none
**Gate**: full
**Commit**: `docs(fechamento): corrigir a frase do req 5.1 no handoff`

---

### T11: `spec.md` e `tasks.md` da fechamento sem afirmações que o repositório não sustenta

**What**: Corrige a linha de `spec.md` que afirma que `grep` mostra citações de AD-011/013 e alinha a redação do Done-when da T6 e o rótulo `Implemented`/`Done` entre `tasks.md` e `spec.md`.
**Where**: `.specs/features/fechamento/spec.md`, `.specs/features/fechamento/tasks.md`
**Depends on**: T6
**Reuses**: `spec.md` linha "AD-011, AD-012, AD-013, AD-015, AD-016" (coluna "`grep` mostra as citações") e a Requirement Traceability (`Done`); `tasks.md` T6 (Done-when do `validate_state.py` e da rastreabilidade em `Implemented`); `~/.claude/skills/tlc-spec-driven/scripts/validate_state.py` (recebe o nome da feature); `validation.md` Fix 7 e Fix 8
**Requirement**: FEC-08, FEC-19 (Fix 7, Fix 8)

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] `grep -c "AD-011" .context/design.md .context/requirements.md` e o mesmo para `AD-013` reexecutados e registrados; a linha de `spec.md` deixa de dizer que o `grep` mostra as citações e passa a dizer o que é verdade (as AD estão refletidas no conteúdo, sem citação nominal), sem editar `design.md` nem `requirements.md` (fora do `Where`)
- [x] O Done-when da T6 em `tasks.md` cita `python3 ~/.claude/skills/tlc-spec-driven/scripts/validate_state.py fechamento` (nome da feature, não `.specs/STATE.md`); conferido em `validate_state.py --help` ou no `argparse` do script
- [x] O rótulo da rastreabilidade é o mesmo nos dois arquivos: o Done-when da T6 cita o status que `spec.md` usa (`Done`) e a legenda de `spec.md` o confirma; `grep -n "Implemented" .specs/features/fechamento/tasks.md .specs/features/fechamento/spec.md` sem contradição
- [x] As tasks T7..T13 e a Phase 5 deste arquivo ficam intactas: `git diff` de `tasks.md` só toca as linhas de T6 (e o `Status`, se necessário)
- [x] `validate_spec.py` e `validate_tasks.py` desta feature saem com 0
- [x] Gate full passa e a contagem de runs não muda (1350)

**Tests**: none
**Gate**: full
**Commit**: `docs(fechamento): corrigir afirmações sem fonte na spec e nas tasks`

---

### T12: Roteiro da 7.1 com números e textos reais

**What**: O `roteiro-7-1.md` usa o `baseSetSize` real do OP01 (ou marca o número como ilustrativo), copia os textos reais da tela de progresso e diz como abrir o filtro abaixo de 1024px.
**Where**: `.specs/features/fechamento/roteiro-7-1.md`
**Depends on**: T6
**Reuses**: `roteiro-7-1.md` (exemplos "15 de 48", "15 / 48", "não colapsado" e "Em celular, expansível por padrão"); `app/views/progress/index.html.erb` e `app/views/progress/_set.html.erb` (se existir; confirmar por `ls`); `app/views/catalog/` (o `<details>` de filtros); `spec/fixtures/optcgjson-subset.json` ou o banco de dev (`baseSetSize` do OP01); `validation.md` Fix 6
**Requirement**: FEC-05 (Fix 6)

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] O total do OP01 vem de fonte aberta nesta task (fixture ou `docker compose exec -T app bin/rails runner` de leitura); o roteiro usa esse número, ou marca o exemplo como "ilustrativo" em todas as linhas onde aparece (98, 107, 115, 155 na numeração atual); `grep -n "48" roteiro-7-1.md` sem ocorrência não justificada
- [x] Os textos de tela do roteiro são copiados de `app/views/progress/*.erb` (frases como "N de M variantes", "N% concluído", "N de M parallels"), e `grep` de cada frase na view é registrado; formato "15 / 48" que a view não produz sai
- [x] O roteiro diz que abaixo de 1024px o filtro do catálogo é um `<details>` fechado por padrão e o usuário o abre com um toque em "Filtros"; a frase "não colapsado" some; conferido no HTML/ERB do catálogo e no CSS do breakpoint de 1024px
- [x] Nenhum passo do roteiro afirma comportamento que o código não tem
- [x] Gate full passa e a contagem de runs não muda (1350)

**Tests**: none
**Gate**: full
**Commit**: `docs(fechamento): alinhar o roteiro da 7.1 aos textos e números reais`

---

### T13: `decisoes-do-dono.md` com a origem certa das 4933 variantes e sem linha sem AD

**What**: Corrige a origem das 4933 variantes (banco de dev, não fixture) e a linha "(contexto)" da tabela "Corrigidos por AD".
**Where**: `.specs/features/fechamento/decisoes-do-dono.md`
**Depends on**: T6
**Reuses**: `decisoes-do-dono.md` (evidência 1 do Req. 5.1 e a tabela "Corrigidos por AD"); `.specs/features/fechamento/verificar-resolvidos.md`; `.specs/STATE.md` (AD-012 e a linha P8 de `design.md` §9 para decidir a citação); `validation.md` Fix 8
**Requirement**: FEC-16, FEC-17 (Fix 8, cosmético)

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] A evidência 1 diz que as 4933 variantes com `image_url_large` NULL vêm do banco de dev (`CardVariant.count` ou `psql`, registrado no commit) e que a fixture não traz o campo; a frase que atribui a contagem à fixture some
- [ ] A linha `design.md §9 (P8 como aberta)` da tabela "Corrigidos por AD" cita uma AD real (aberta em `STATE.md`) ou sai da tabela e vira nota abaixo dela, sem a coluna AD; nenhuma célula fica com "(contexto)"
- [ ] `grep -n "(contexto)" decisoes-do-dono.md` sai vazio
- [ ] O texto do Req. 5.1 e a pergunta ao dono não mudam de sentido
- [ ] Gate full passa e a contagem de runs não muda (1350)

**Tests**: none
**Gate**: full
**Commit**: `docs(fechamento): corrigir a origem das 4933 variantes e a linha sem ad`

---

## Plano de delegação

| Task | Worker | Revisão |
|---|---|---|
| T1 | Haiku (mecânica: os comandos vêm prontos do repositório) | o orquestrador segue o README do zero no host |
| T2, T3 | Sonnet (decidem o que uma AD muda no documento) | o orquestrador lê o `git diff` contra as AD |
| T4 | Haiku, com leitura obrigatória das fontes | o orquestrador reabre a fonte de cada remoção |
| T5 | Haiku (formato fechado) | o orquestrador lê a pergunta ao dono |
| T6 | Orquestrador | Dono |
| T7 | Haiku (comandos e citações vêm prontos; prompt fechado com a lista de `grep`) | o orquestrador segue o README do zero e compara os gates com o `CLAUDE.md` |
| T8 | Haiku (troca de uma referência conferida em `requirements.md`) | o orquestrador lê o `git diff` (≤ 3 linhas) |
| T9 | Sonnet (decide o que fica como aberto; pode devolver `blocked`) | o orquestrador lê o `git diff` contra `design.md` §9 |
| T10 | Haiku (reescrita de uma frase e comparação de números com o gate) | o orquestrador confere os números contra `validation.md` |
| T11 | Sonnet (decide a redação de duas afirmações e não pode tocar T7..T13) | o orquestrador lê o `git diff` só das linhas de T6 e da linha da spec |
| T12 | Haiku, com leitura obrigatória das views e do banco | o orquestrador reabre cada frase na view |
| T13 | Haiku (formato fechado) | o orquestrador lê as duas correções |

As tasks T7..T13 têm `Where` disjuntos e podem rodar em paralelo (um worker por
task, sem `git add -A`, sem `git stash`). Quem escreve T7..T13 é o worker de
planejamento; o worker de execução de T11 não as edita.

Regras que todo prompt de worker repete: não usar `git add -A` nem `git add .`
(o index é compartilhado); não marcar checkbox em `tasks.md`; não editar arquivo
fora do `Where`; não inventar fato; parar com `blocked` diante de decisão de design.

## Task Granularity Check

| Task | Escopo | Status |
|---|---|---|
| T1 | um documento (README) | ✅ |
| T2 | uma seção de um documento (Req. 10) | ✅ |
| T3 | três seções de um documento, mesma natureza | ✅ |
| T4 | remoção de marcadores e o log que a prova | ✅ |
| T5 | um arquivo novo de registro | ✅ |
| T6 | fechamento em quatro arquivos de planejamento | ⚠️ 2-3 arquivos afins; cohesivo (só marcas de status e um bloco de texto) |
| T7 | um documento (README), 2 correções na seção da ingestão + conferência de gates | ✅ |
| T8 | uma linha de uma tabela de `design.md` | ✅ |
| T9 | uma seção de `requirements.md` (Rastreamento) | ✅ |
| T10 | um bloco de Handoff em `STATE.md` | ✅ |
| T11 | duas linhas de `spec.md` e `tasks.md` (mesma natureza: afirmação sem fonte) | ⚠️ 2 arquivos afins; cohesivo |
| T12 | um roteiro | ✅ |
| T13 | um arquivo de registro, duas correções cosméticas | ✅ |

## Diagram-Definition Cross-Check

| Task | Depends on (definição) | Diagrama | Status |
|---|---|---|---|
| T1 | None | Phase 1: `T1 ∥ T2 ∥ T3` | ✅ |
| T2 | None | Phase 1: `T1 ∥ T2 ∥ T3` | ✅ |
| T3 | None | Phase 1: `T1 ∥ T2 ∥ T3` | ✅ |
| T4 | T3 | Phase 2: `T3 → T4` | ✅ |
| T5 | T2, T4 | Phase 3: `T2 → T5`, `T4 → T5` | ✅ |
| T6 | T1, T5 | Phase 4: `T1 → T6`, `T5 → T6` | ✅ |
| T7 | T6 | Phase 5: `T6 → T7` | ✅ |
| T8 | T6 | Phase 5: `T6 → T8` | ✅ |
| T9 | T6 | Phase 5: `T6 → T9` | ✅ |
| T10 | T6 | Phase 5: `T6 → T10` | ✅ |
| T11 | T6 | Phase 5: `T6 → T11` | ✅ |
| T12 | T6 | Phase 5: `T6 → T12` | ✅ |
| T13 | T6 | Phase 5: `T6 → T13` | ✅ |

## Test Co-location Validation

| Task | Camada tocada | Tipo exigido pela matriz | Tests da task | Status |
|---|---|---|---|---|
| T1 | documentação | none | none | ✅ |
| T2 | documentação | none | none | ✅ |
| T3 | documentação | none | none | ✅ |
| T4 | documentação | none | none | ✅ |
| T5 | documentação | none | none | ✅ |
| T6 | documentação | none | none | ✅ |
| T7 | documentação (`README.md`) | none | none | ✅ |
| T8 | documentação (`design.md`) | none | none | ✅ |
| T9 | documentação (`requirements.md`) | none | none | ✅ |
| T10 | documentação (`STATE.md`) | none | none | ✅ |
| T11 | documentação (`spec.md`, `tasks.md`) | none | none | ✅ |
| T12 | documentação (`roteiro-7-1.md`) | none | none | ✅ |
| T13 | documentação (`decisoes-do-dono.md`) | none | none | ✅ |
