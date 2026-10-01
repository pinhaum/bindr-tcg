# Troca da fonte do catálogo para a apitcg — Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Spec**: `.specs/features/fonte-apitcg/spec.md` (SRC-01..SRC-36)
**Design**: `.specs/features/fonte-apitcg/design.md`
**Status**: Done pending verification (SRC-31 e o ciclo de correção 1 aguardam o Verifier; item de 24h da T17 bloqueado por tempo, D-04)

Regras que valem para todas as tasks:

- A numeração T1–T25 é **desta feature**, sem relação com as de `catalogo`, `colecao` e demais.
- A ingestão continua sem delete, e nenhum `collection_item` nem `wishlist_item` é apagado ou tem quantidade alterada por teste nenhum desta feature (Req. 1.7).
- `APITCG_API_KEY` nunca aparece em código, teste, fixture, log, commit ou saída de comando. Teste que precise de chave usa um valor sintético (`"chave-de-teste"`).
- **Requisição à apitcg real só na T10 e na T17**, e cada uma exige o aval explícito do dono no momento da execução (blast radius). Todas as outras tasks usam cliente HTTP falso injetado, como faz `fetch_test.rb` hoje.
- Proibido `git add -A`, `git add .`, `git stash`, `reset`, `rebase`, `checkout` e worktree. O worker não marca checkbox; o orquestrador marca neste arquivo e em `.context/tasks.md` §8 no commit da task.

---

## Test Coverage Matrix

> Generated from codebase, project guidelines, and spec. Guidelines found: `CLAUDE.md` (gates quick/full/build, `verify_fixture.py`, sem system test), `.github/workflows/ci.yml` (rubocop, brakeman, `bin/rails test`). Sem limiar de cobertura configurado; aplicados os defaults fortes.

| Camada | Tipo de teste | Cobertura esperada | Onde | Comando |
|---|---|---|---|---|
| Model (scope de presença) | unit (Minitest com banco) | Cada ramo: sem run `succeeded`, run `succeeded` mais recente, run `failed` depois de um `succeeded` | `test/models/*_test.rb` | `bin/rails test test/models` |
| Query object (`CatalogQuery`, `SetProgressQuery`) | unit (Minitest com banco) | 1:1 com os SRC da task, mais os edge cases listados; plano de execução quando a task mexe em consulta do catálogo (Req. 11.3) | `test/queries/*_test.rb` | `bin/rails test test/queries` |
| Serviço de ingestão e remapeamento | unit (Minitest com banco, HTTP falso) | Todos os ramos; 1:1 com os SRC; todo edge case (SRC-32..35) | `test/services/ingestion/*_test.rb` | `bin/rails test test/services` |
| `CardImageCache` | unit | Host, formato do código, nome saneado, path traversal | `test/services/card_image_cache_test.rb` | `bin/rails test test/services` |
| Controller + view | integration (HTML renderizado; sem navegador, `SPEC_DEVIATION` do projeto) | Caminho feliz, com e sem sessão, e o caso de erro da task | `test/integration/*_test.rb`, `test/design/*_test.rb` | `bin/rails test test/integration test/design` |
| Rake task | integration (carrega a task e verifica saída e código de saída) | Caminho feliz e cada saída de erro do spec | `test/lib/*_test.rb` | `bin/rails test test/lib` |
| Fixture | script offline | Um check por caso de SRC-29 | `spec/verify_fixture.py` | `python3 spec/verify_fixture.py` |
| Documentação (`CLAUDE.md`, `.context/`) | none | Conferência por `grep` registrada no commit | — | gate full |

## Gate Check Commands

Todos rodam com `DOCKER_CONFIG=/tmp/claude-1000/bindr-dockercfg` na frente (diretório com `config.json` contendo `{}`) e o container `app` no ar (`docker compose up -d`).

| Gate | Quando | Comando |
|---|---|---|
| quick | Tasks só de model ou query | `docker compose exec -T app bin/rails test test/models test/queries` |
| full | Qualquer task com serviço, controller, view, rake ou fixture | `docker compose exec -T app bin/rails test && docker compose exec -T app bin/rubocop && docker compose exec -T app bin/brakeman --no-pager && python3 spec/verify_fixture.py` |
| build | Fim da Phase 5 e T17 | `docker compose build` + gate full |

Toda task registra no commit a contagem de runs do gate. A contagem só cai onde
a task remove testes de código removido (T14), e a queda é justificada no commit.

---

## Execution Plan

As fases rodam em sequência, e as tasks dentro de cada fase também. As Phases 1–3
não dependem do snapshot da apitcg e podem ser executadas enquanto a API estiver
fora do ar. A Phase 5 depende da T10, que depende da API.

### Phase 1: Presença na fonte e leitura

```
T1 → T2
T1 → T3
T1 → T4
```

### Phase 2: Remapeamento da coleção

```
T1 → T5 → T6
```

### Phase 3: Imagens do tcgplayer

```
T7
```

### Phase 4: Busca e snapshot

```
T8 → T9 → T10
```

### Phase 5: Normalize e Upsert sobre a fixture nova

```
T10 → T11 → T12 → T13 → T14
T9 → T13
T10 → T15
```

### Phase 6: Fechamento

```
T14 → T16 → T17
```

### Phase 7: Correções da revisão do lote A

Roda **antes da Phase 4**, por exceção à ordem numérica: corrige código e testes
já commitados das Phases 1–3, e nenhuma task daqui depende das Phases 4–6. Sai
das revisões de banco, testes, segurança e a11y do lote A (F1–F5); não emenda o
spec.

```
T5 → T18
T6 → T18
T18 → T19
T18 → T20
T7 → T21
T3 → T22
T4 → T23
```

### Phase 8: Correções pós-verificação

SRC-36 (T24) e o ciclo de correção 1 do Verifier (T25), depois da Phase 6.

```
T11 → T24
T12 → T24
T24 → T25
```

---

## Task Breakdown

### T1: Scope `CardVariant.present`

**What**: Scope que define "presente na fonte": `last_seen_at >= max(started_at)` dos `import_runs` com status `succeeded`; sem run `succeeded`, nada é presente.
**Where**: `app/models/card_variant.rb`
**Depends on**: None
**Reuses**: `last_seen_at` gravado por `upsert.rb:77,93`
**Requirement**: SRC-16

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] `CardVariant.present` devolve só as variantes vistas no último run `succeeded`
- [x] Testes: sem nenhum run `succeeded` → vazio; variante vista no último `succeeded` → presente; variante vista só num run anterior → ausente; run `failed` depois do `succeeded` não altera a presença
- [x] Gate quick passa; contagem de runs registrada

**Tests**: unit
**Gate**: quick
**Commit**: `feat(fonte-apitcg): definir a presença da variante na fonte`

---

### T2: `CatalogQuery` só com o que está presente

**What**: Escopo base, filtros de set e raridade, EXISTS de posse e `filter_options` passam a considerar só variantes presentes; a ordem padrão "mais recentes" continua por `released_on` do set da carta.
**Where**: `app/queries/catalog_query.rb`
**Depends on**: T1
**Reuses**: `VARIANT_FILTERS` (`catalog_query.rb:41,345-358`), ordem padrão (`:66-77`)
**Requirement**: SRC-15, SRC-16

**Tools**:

- MCP: NONE
- Skill: NONE (revisão por `ecc:database-reviewer` no plano de execução)

**Done when**:

- [x] Carta cuja única variante está ausente não aparece na grade, na busca nem em nenhum filtro
- [x] Carta com variante presente num set e ausente em outro só casa o filtro do set presente
- [x] `filter_options` não lista set sem variante presente
- [x] Sem parâmetros, a primeira carta é do set presente com `released_on` mais recente (SRC-15)
- [x] `EXPLAIN` das consultas de filtro sem full table scan (Req. 11.3); se precisar, migração só de índice (`import_runs(status, started_at)`, `card_variants(last_seen_at)`) com `db:migrate` e `db/structure.sql` regenerado
- [x] Os testes existentes de `test/queries/catalog_*` continuam passando, com fixtures ajustadas para ter um run `succeeded`
- [x] Gate quick passa; contagem de runs registrada

**Tests**: unit
**Gate**: quick
**Commit**: `feat(fonte-apitcg): restringir o catálogo às variantes presentes na fonte`

---

### T3: Detalhe da carta com a variante "fora da fonte"

**What**: `CatalogController#index` pré-carrega só variantes presentes para o tile; `#show` lista as presentes e, com sessão, as ausentes que o usuário tem na coleção ou na wishlist, rotuladas "fora da fonte" na view.
**Where**: `app/controllers/catalog_controller.rb` (e `app/views/catalog/show.html.erb`, linha da raridade)
**Depends on**: T1
**Reuses**: `owned_quantities` / `wishlist_targets` (`catalog_controller.rb:69-106`); `authenticated?` antes de ler `Current.user`
**Requirement**: SRC-16, SRC-17, SRC-18

**Tools**:

- MCP: NONE
- Skill: NONE (revisão por `ecc:a11y-architect` no rótulo)

**Done when**:

- [x] Sem sessão, a variante ausente não aparece no detalhe
- [x] Com sessão, e o usuário sem item nela, a variante ausente não aparece
- [x] Com sessão, e o usuário com item de coleção ou de wishlist nela, a variante aparece com o texto visível "fora da fonte" e a quantidade intacta
- [x] Carta que só tem variantes ausentes, aberta por URL direta, responde 200 para o dono do item e 404 para os demais (o catálogo não a lista)
- [x] O tile da grade usa a primeira variante presente
- [x] Os testes de `test/integration/card_detail_*` e `test/design/card_detail_*` continuam passando
- [x] Gate full passa; contagem de runs registrada

**Tests**: integration
**Gate**: full
**Commit**: `feat(fonte-apitcg): mostrar ao dono a variante fora da fonte no detalhe`

---

### T4: Progresso por números de carta distintos

**What**: `SetProgressQuery` passa a contar números de carta distintos sobre variantes presentes, com o universo do numerador deduzido de `base_set_size`; a view de progresso exibe numerador e denominador (Req. 9.1 emendado).
**Where**: `app/queries/set_progress_query.rb` (e `app/views/progress/index.html.erb:205-217`)
**Depends on**: T1
**Reuses**: `Row#completion_percent` com teto (`set_progress_query.rb:139-150`); contagem de parallels existente
**Requirement**: SRC-25, SRC-26, SRC-27, SRC-28, SRC-35

**Tools**:

- MCP: NONE
- Skill: NONE (revisão por `ecc:database-reviewer`)

**Done when**:

- [x] Set com numeração própria (`base_set_size` < números distintos presentes): o numerador conta só os números com o prefixo do set
- [x] Set de reimpressão (`base_set_size` = números distintos presentes): o numerador conta todos os números do set
- [x] Base e Box Topper do mesmo número contam uma vez (SRC-28); `alternate_art`, `manga` e `promo` entram no numerador; `parallel` não entra
- [x] Nenhum set passa de 100% (SRC-26), inclusive com mais variantes possuídas que o denominador
- [x] Parallels possuídos continuam como métrica separada (SRC-27); set sem denominador continua sem percentual (PRG-10)
- [x] Set sem variante presente não aparece na lista
- [x] A linha do set e a barra usam numerador e denominador do percentual, não mais variantes
- [x] Testes de `test/queries/set_progress_*` e `test/design/progress_*` atualizados para a unidade nova, sem remover nenhum caso de teto, parallel ou ordem
- [x] Gate full passa; contagem de runs registrada

**Tests**: integration
**Gate**: full
**Commit**: `feat(fonte-apitcg): contar o progresso por números de carta distintos`

---

### T5: Serviço `Ingestion::Remap`

**What**: Serviço que move `collection_items` e `wishlist_items` de variantes ausentes para o candidato único presente (mesma carta, mesmo código de set, mesma classe de arte), numa transação única, e devolve o relatório dos pulados.
**Where**: `app/services/ingestion/remap.rb`
**Depends on**: T1
**Reuses**: `CardVariant.present`; índice único `(user_id, card_variant_id)` como barreira
**Requirement**: SRC-19, SRC-20, SRC-21, SRC-22, SRC-23

**Tools**:

- MCP: NONE
- Skill: NONE (revisão por `ecc:database-reviewer` e `ecc:pr-test-analyzer`)

**Done when**:

- [x] Item com candidato único é movido, com `quantity` / `target_quantity` iguais aos de antes
- [x] Item `base` não casa com candidato não-base, e vice-versa; um não-base antigo casa com qualquer não-base novo
- [x] Zero candidatos → "sem candidato"; mais de um → "ambíguo"; dois itens do mesmo usuário no mesmo candidato, ou item já existente do usuário no candidato → "colisão" para todos os envolvidos; nenhum destes é movido
- [x] Itens de usuários diferentes no mesmo candidato são movidos (a colisão é por usuário)
- [x] Segunda execução seguida não move nada (SRC-22)
- [x] Sem run `succeeded`, levanta erro com "nenhuma ingestão concluída; rode ingestion:import antes" e nada é movido (SRC-23)
- [x] Falha forçada no meio da aplicação faz rollback de todos os movimentos
- [x] Contagem de `collection_items`, `wishlist_items` e soma de quantidades idênticas antes e depois
- [x] Gate full passa; contagem de runs registrada

**Tests**: unit
**Gate**: full
**Commit**: `feat(fonte-apitcg): remapear coleção e wishlist para as variantes novas`

---

### T6: Rake `ingestion:remap`

**What**: Task rake que chama `Ingestion::Remap`, imprime o total movido e uma linha por item pulado (`card_number`, `variant_code` antigo, motivo) e sai com código 1 no erro de SRC-23.
**Where**: `lib/tasks/ingestion.rake`
**Depends on**: T5
**Reuses**: estilo de saída de `ingestion:import`
**Requirement**: SRC-19, SRC-21, SRC-23

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] A saída lista os pulados com os três campos e nenhum dado do usuário (e-mail, id)
- [x] Sem run `succeeded`, a saída traz a mensagem de SRC-23 e o código de saída é 1
- [x] Teste em `test/lib/` carrega a task e confere saída e código de saída nos dois casos
- [x] Gate full passa; contagem de runs registrada

**Tests**: integration
**Gate**: full
**Commit**: `feat(fonte-apitcg): expor o remapeamento como ingestion:remap`

---

### T7: `CardImageCache` com o host e os códigos do tcgplayer

**What**: `ALLOWED_HOST` passa a `tcgplayer-cdn.tcgplayer.com`; `VARIANT_CODE_FORMAT` aceita também `tcgplayer:<id>` e `apitcg:<id>`; o nome do arquivo em cache troca `:` por `-`.
**Where**: `app/services/card_image_cache.rb`
**Depends on**: None
**Reuses**: validação de https/porta/extensão existente; checagem de path traversal (`card_image_cache.rb:96`)
**Requirement**: Req. 11.7 (emendado), AD-012, AD-019

**Tools**:

- MCP: NONE
- Skill: NONE (revisão por `ecc:security-reviewer`)

**Done when**:

- [x] URL em `tcgplayer-cdn.tcgplayer.com` com https é aceita; o host antigo e qualquer outro são recusados
- [x] `tcgplayer:123` e `apitcg:abc123` são aceitos; `tcgplayer:../x`, `tcgplayer:` e códigos com `/` são recusados
- [x] O arquivo em cache de `tcgplayer:123` é `tcgplayer-123.<ext>`, dentro de `storage/card_images/` — nome substituído pela T21 (`tcgplayer__123.<ext>`)
- [x] Os códigos antigos (`OP01-001_p1`) continuam aceitos e o cache deles continua sendo lido
- [x] `GET /card_images/tcgplayer:123` responde como hoje responde um código antigo (teste de integração)
- [x] Gate full passa; contagem de runs registrada

**Tests**: integration
**Gate**: full
**Commit**: `feat(fonte-apitcg): servir as imagens do tcgplayer`

---

### T8: `SourceConfig` da apitcg

**What**: `SourceConfig` e `config/ingestion.yml` passam a descrever a apitcg (`base_url`, `page_size` 100, `timeout` 30, `attempts` 3) e a ler `APITCG_API_KEY` do ambiente, levantando erro com "APITCG_API_KEY não configurada" quando ausente ou vazia.
**Where**: `app/services/ingestion/source_config.rb` (e `config/ingestion.yml`)
**Depends on**: None
**Reuses**: `MissingSetting` existente
**Requirement**: SRC-02, SRC-05

**Tools**:

- MCP: NONE
- Skill: NONE (revisão por `ecc:security-reviewer`)

**Done when**:

- [x] Chave ausente e chave vazia levantam o erro com a mensagem de SRC-02
- [x] `inspect`, `to_s` e a mensagem de qualquer erro não contêm o valor da chave
- [x] As regras de revisão imutável (SHA, tag, referência móvel) e seus testes saem; o teste que exigia `optcgjson` no `config/ingestion.yml` passa a exigir `apitcg`
- [x] `.env.example` ganha `APITCG_API_KEY=` vazio
- [x] Gate full passa; contagem de runs registrada

**Tests**: unit
**Gate**: full
**Commit**: `feat(fonte-apitcg): configurar a apitcg como fonte e exigir a chave`

---

### T9: `Ingestion::Apitcg::Fetch`

**What**: Busca `/sets` e todas as páginas de `/products?type=card` (T10: `/cards` não existe) com `x-api-key`, em sequência, com timeout, 3 tentativas e espera crescente, deduplica por `_id` e grava `storage/ingestion/apitcg-<UTC>.json` atomicamente.
**Where**: `app/services/ingestion/apitcg/fetch.rb`
**Depends on**: T8
**Reuses**: `.part` + `rename` e cliente injetável de `app/services/ingestion/fetch.rb`
**Requirement**: SRC-01, SRC-03, SRC-04, SRC-05, SRC-32, SRC-33

**Tools**:

- MCP: NONE
- Skill: NONE (revisão por `ecc:security-reviewer` e `ecc:silent-failure-hunter`)

**Done when**:

- [x] Com cliente falso de 3 páginas, o snapshot tem `fetched_at`, `sets` e a união dos produtos, e toda requisição levou o header `x-api-key`
- [x] Produto repetido entre páginas aparece uma vez (SRC-33)
- [x] Timeout ou não-2xx repete até 3 tentativas, com esperas 2s e 4s no `sleeper` falso; a terceira falha levanta `SourceUnavailable` e nenhum arquivo final é gravado (SRC-04)
- [x] 401 levanta `KeyRejected` com "chave da apitcg recusada (401)" na primeira resposta, sem nova tentativa (SRC-32)
- [x] O valor da chave não aparece no arquivo gravado nem na mensagem de nenhum erro (SRC-05)
- [x] Arquivo com o mesmo nome já existente não é sobrescrito
- [x] Gate full passa; contagem de runs registrada

**Tests**: unit
**Gate**: full
**Commit**: `feat(fonte-apitcg): buscar a apitcg paginada e gravar o snapshot`

---

### T10: Snapshot real e fixture `apitcg-subset.json`

**What**: Com aval do dono, captura um snapshot real pela T9, recorta dele `spec/fixtures/apitcg-subset.json` com cada caso de SRC-29 e reescreve `spec/verify_fixture.py` para a forma nova.
**Where**: `spec/fixtures/apitcg-subset.json` (e `spec/verify_fixture.py`)
**Depends on**: T9
**Reuses**: verificações atuais de `verify_fixture.py` que continuam válidas (`counter` nulo ≠ 0, só líder tem `life`, líder sem custo, multicor, mais de um atributo)
**Requirement**: SRC-29, SRC-30

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] **Aval do dono** para a requisição real registrado no commit; a API precisa estar respondendo (AD-019, trade-off 6)
- [x] Snapshot completo em `storage/ingestion/` (fora do git), com o `grep` da chave sobre ele dando 0 ocorrências
- [x] Fixture versionada com cada caso de SRC-29, recortada por script no scratchpad, sem a chave
- [x] `python3 spec/verify_fixture.py` passa, com um check nomeado por caso de SRC-29
- [x] Os `⚠️ VERIFICAR` do design resolvidos sobre o snapshot e anotados no commit: forma de `images`, extensão da imagem `large`, separador de `[Trigger]`
- [x] Gate full passa (a fixture antiga continua no repositório até a T14); contagem de runs registrada

**Tests**: integration
**Gate**: full
**Commit**: `test(fonte-apitcg): versionar o recorte do snapshot da apitcg`

---

### T11: `Ingestion::Apitcg::Normalize`

**What**: Normalizador da apitcg que devolve os structs `Normalized*` e a lista de descartes, aplicando as regras de Assumptions para `variant_code`, `art_kind`, código do set, impressão que define a carta, limpeza do efeito, `trigger_text` e `base_set_size`.
**Where**: `app/services/ingestion/apitcg/normalize.rb`
**Depends on**: T10
**Reuses**: structs `NormalizedSet/Card/Variant` (`normalize.rb:27-37`), `CARD_TYPES`, deduplicação de traits
**Requirement**: SRC-09, SRC-10, SRC-11, SRC-12, SRC-13, SRC-14, SRC-24, SRC-34, SRC-35

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Sobre a fixture: contagens de sets, cartas e variantes batem com as do recorte menos os descartes
- [x] `variant_code` `tcgplayer:<id>` e, num produto sem `tcgplayer.id` montado no teste, `apitcg:<_id>` (SRC-09)
- [x] `DON!!` não aparece em nenhuma lista, nem nos descartes (SRC-10); produto sem `code` aparece nos descartes com o `_id` (SRC-11)
- [x] Um `art_kind` de cada valor da tabela de Assumptions, incluindo sufixo numérico e sufixo igual a um `card_number` → `base` (SRC-13)
- [x] Carta com errata entre impressões recebe os dados da impressão base do set de estreia; sem ela, do set mais recente; empate pelo menor `variant_code` (SRC-12)
- [x] Efeito sem HTML, `<br>` como `\n`, `trigger_text` preenchido e ausente do efeito; `block_icon` nil
- [x] Código do set: `ST-01` → `ST01`, `OP07 PRE` → `OP07-PRE`, `code` nulo com maioria estrita → prefixo, com colisão → slug sem `one-piece-` (SRC-14); `released_on` preenchido
- [x] `base_set_size` pelo prefixo num set de numeração própria, por todos os números num set de reimpressão e num set sem nenhum número com o prefixo (SRC-24, SRC-35)
- [x] Variante em dois sets fica no primeiro (SRC-34)
- [x] Gate full passa; contagem de runs registrada

**Tests**: unit
**Gate**: full
**Commit**: `feat(fonte-apitcg): normalizar o snapshot da apitcg`

---

### T12: Upsert com descartes, origem do snapshot e presença no fechamento

**What**: `Ingestion::Upsert` recebe os descartes, grava-os em `error_log` como `"discarded"` sem contá-los em `failed_count` nem mudar o status, grava em `source_revision` o nome do snapshot e o SHA-256, e passa a gravar `last_seen_at` só no `finish` de um run `succeeded`, a partir dos ids acumulados em memória (design, `Ingestion::Upsert`).
**Where**: `app/services/ingestion/upsert.rb`
**Depends on**: T11
**Reuses**: `apply`, `finish` e `MAX_LOGGED_ERRORS` existentes; `ImportRun.lock_presence!` da T18 (Phase 7, que roda antes da Phase 4)
**Requirement**: SRC-06, SRC-11, SRC-16

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Run só com descartes termina `succeeded`, com `failed_count` 0 e os descartes no `error_log`
- [x] Um erro real num registro continua levando a `failed` e ao `error_log` como hoje
- [x] `source_revision` é `"<arquivo> sha256:<hex>"`, com o hex conferido contra o arquivo
- [x] `upsert_test.rb` passa a usar a fixture nova e os nomes de campo da apitcg
- [x] Run `succeeded` grava `last_seen_at = started_at` em toda carta e variante que ele aplicou
- [x] Run `failed` depois de um `succeeded`: variante criada nele fica com `last_seen_at` nulo e fora de `CardVariant.present`; variante já existente que ele reaplicou mantém o `last_seen_at` do `succeeded`; o conjunto de `CardVariant.present` é idêntico antes e depois do run
- [x] Falha forçada ao gravar o status no `finish` não deixa `last_seen_at` avançado (status e presença na mesma transação)
- [x] `finish` toma `ImportRun.lock_presence!` (da T18) dentro da transação
- [x] `upsert_test.rb:158-159` e `guarantees_test.rb:252-260` continuam passando sem afrouxar asserção
- [x] Gate full passa; contagem de runs registrada

**Tests**: unit
**Gate**: full
**Commit**: `feat(fonte-apitcg): registrar descartes, a origem do snapshot e a presença no fechamento do upsert`

---

### T13: `Ingestion::Run` e `ingestion:import SNAPSHOT=`

**What**: `Run.call(snapshot:)` reprocessa um snapshot sem construir o Fetch; sem `snapshot`, busca pela T9; falha na busca gera `ImportRun` `failed` sem escrita no catálogo; o rake lê `SNAPSHOT=` e perde `REUSE_PAYLOAD`.
**Where**: `app/services/ingestion/run.rb` (e `lib/tasks/ingestion.rake`)
**Depends on**: T9, T12
**Reuses**: fluxo atual de `Run.call`
**Requirement**: SRC-02, SRC-04, SRC-06, SRC-07, SRC-08, SRC-32

**Tools**:

- MCP: NONE
- Skill: NONE (revisão por `ecc:silent-failure-hunter`)

**Done when**:

- [x] Com `SNAPSHOT`, a ingestão roda sem `APITCG_API_KEY` no ambiente e sem nenhuma chamada ao cliente HTTP (cliente falso que falha se chamado)
- [x] O mesmo snapshot processado duas vezes deixa contagens de cartas, variantes e sets idênticas (SRC-08)
- [x] Falha de busca (3 tentativas esgotadas, ou 401) grava `ImportRun` `failed` com o erro e sem nenhuma carta, variante ou set novos (SRC-04, SRC-32)
- [x] Chave ausente sem `SNAPSHOT` aborta antes de qualquer requisição e antes de escrever no banco, com a mensagem de SRC-02
- [x] Teste em `test/lib/` confere o rake com `SNAPSHOT` (sucesso, código 0) e sem chave (mensagem, código 1)
- [x] Gate full passa; contagem de runs registrada

**Tests**: integration
**Gate**: full
**Commit**: `feat(fonte-apitcg): reprocessar snapshot com ingestion:import SNAPSHOT`

---

### T14: Remover a optcgjson e migrar as garantias

**What**: Remove o normalizador, o Fetch e a fixture da optcgjson, e reescreve `guarantees_test.rb` sobre a fixture nova, incluindo o teste de duas ingestões com `collection_item` existente (task 2.6 do `catalogo`).
**Where**: `test/services/ingestion/guarantees_test.rb` (e remoção de `app/services/ingestion/normalize.rb`, `app/services/ingestion/fetch.rb`, `spec/fixtures/optcgjson-subset.json`)
**Depends on**: T13
**Reuses**: casos atuais de `guarantees_test.rb`
**Requirement**: SRC-08, SRC-18

**Tools**:

- MCP: NONE
- Skill: NONE (revisão por `ecc:pr-test-analyzer`)

**Done when**:

- [x] `grep -rn "optcgjson\|raw.githubusercontent\|5669eab" app lib config test spec` sem ocorrência de código (comentário histórico só com AD)
- [x] Duas ingestões seguidas da fixture nova com um `collection_item` e um `wishlist_item` existentes deixam ambos com a mesma quantidade (SRC-18)
- [x] Variante presente antes e ausente no snapshot seguinte continua no banco, ausente, com o item de coleção intacto
- [x] Nenhum caso de garantia foi removido sem equivalente; a queda da contagem de runs corresponde só aos testes do código removido, listados no commit
- [x] Gate build passa (fim da Phase 5 do lado do código de ingestão); contagem de runs registrada

**Tests**: unit
**Gate**: build
**Commit**: `refactor(fonte-apitcg): remover a optcgjson e migrar as garantias da ingestão`

---

### T15: `ingestion:compare_snapshots`

**What**: Serviço e rake que cruzam dois snapshots pelo `_id` e informam quantos produtos comuns mudaram de `markets.tcgplayer.id`, sem banco e sem rede.
**Where**: `app/services/ingestion/apitcg/compare_snapshots.rb` (e `lib/tasks/ingestion.rake`)
**Depends on**: T10
**Reuses**: formato do snapshot da T9
**Requirement**: SRC-31

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Dois snapshots sintéticos com um id trocado → `changed` = 1, com o `_id` e os dois ids
- [x] Produto presente só num dos lados não conta como mudança
- [x] Teste em `test/lib/` confere o rake com `A=` e `B=` (comuns e mudados na saída) e sem um dos argumentos (código 1 com mensagem)
- [x] Gate full passa; contagem de runs registrada

**Tests**: integration
**Gate**: full
**Commit**: `feat(fonte-apitcg): comparar snapshots para medir a estabilidade do tcgplayer.id`

---

### T16: Documentação da troca de fonte

**What**: `CLAUDE.md` e `README.md` passam a descrever a apitcg: tabela P1–P7 (P1, P5, P6 apontando para a AD-019), fixture nova, `APITCG_API_KEY`, `SNAPSHOT=`, `ingestion:remap` e `ingestion:compare_snapshots`.
**Where**: `CLAUDE.md` (e `README.md`)
**Depends on**: T14
**Reuses**: texto atual das seções "Decisões já tomadas" e "Comandos"
**Requirement**: AD-019

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Cada comando e arquivo citado conferido por `grep` ou `ls` na mesma task
- [x] Nenhuma menção à optcgjson como fonte vigente; a AD-001 aparece só como histórico
- [x] Gate full passa; contagem de runs igual à da T15

**Tests**: none
**Gate**: full
**Commit**: `docs(fonte-apitcg): documentar a apitcg como fonte do catálogo`

---

### T17: Troca real no banco de desenvolvimento

**What**: Com aval do dono, roda `ingestion:import` com a chave real no banco de desenvolvimento (depois de um dump dele), depois `ingestion:remap`, confere os Success Criteria do spec e, com um segundo snapshot 24h ou mais depois do primeiro, roda `ingestion:compare_snapshots`.
**Where**: `.specs/features/fonte-apitcg/spec.md` (Success Criteria e traceability)
**Depends on**: T16
**Reuses**: T6, T13, T15
**Requirement**: SRC-15, SRC-26, SRC-31

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] **Aval do dono** para a requisição real e para escrever no banco de desenvolvimento, com dump feito antes (`pg_dump` dentro do container), e o caminho do dump registrado
- [x] Contagem de `collection_items` e soma de `quantity` idênticas antes e depois de import + remap; relatório do remap registrado sem dado de usuário
- [x] Os 85 sets com carta têm `released_on`; a grade abre pelo set lançado por último; nenhum set acima de 100%
- [ ] **BLOQUEADO (D-04, precisa de 24h):** `compare_snapshots` entre os dois snapshots registrado; os snapshots do run têm 45 min de diferença (7.252 comuns, 0 mudados, só informativo); se `changed > 0`, parar e reabrir o SRC-31 com o dono antes do Verifier
- [x] Success Criteria do spec marcados com a evidência
- [x] Gate build passa; contagem de runs registrada

**Tests**: none
**Gate**: build
**Commit**: `docs(fonte-apitcg): registrar a troca real da fonte no banco de desenvolvimento`

---

### T18: `Ingestion::Remap` com o plano dentro da transação

**What**: O plano passa a ser montado dentro da transação, com os itens elegíveis travados por `FOR UPDATE` em ordem de `id` e um lock consultivo de presença (`ImportRun.lock_presence!`, `pg_advisory_xact_lock`) que o `Upsert#finish` também vai tomar na T12. `moved` sai do que a transação aplicou. Uma violação do índice único durante a aplicação vira `Remap::ConcurrentChange`, com rollback total, e o rake a imprime no stderr e sai com 1.
**Where**: `app/services/ingestion/remap.rb` (e `app/models/import_run.rb`, `lib/tasks/ingestion.rake`)
**Depends on**: T5, T6
**Reuses**: `plan`, `move` e `Report` existentes
**Requirement**: SRC-19, SRC-20, SRC-21

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] A leitura dos itens elegíveis acontece dentro da transação do movimento e com `FOR UPDATE`, ordenada por `id` (conferido no SQL capturado do teste)
- [x] `ImportRun.lock_presence!` é chamado dentro da transação, antes do plano
- [x] `RecordNotUnique` durante a aplicação levanta `Remap::ConcurrentChange` com "a coleção mudou durante o remapeamento; rode ingestion:remap de novo", e nenhum item fica movido
- [x] O rake imprime essa mensagem no stderr e sai com código 1
- [x] `moved` lista só os movimentos aplicados
- [x] Os testes de `remap_test.rb` e `ingestion_remap_task_test.rb` continuam passando sem afrouxar asserção
- [x] Gate full passa; contagem de runs registrada

**Tests**: unit
**Gate**: full
**Commit**: `fix(fonte-apitcg): montar o plano do remap dentro da transação`

---

### T19: Lacunas de teste do `Ingestion::Remap`

**What**: Testes que faltam em `remap_test.rb`, apontados pela análise de testes do lote A.
**Where**: `test/services/ingestion/remap_test.rb`
**Depends on**: T18
**Reuses**: helpers `own`, `want`, `variant`, `skipped_reasons`, `totals`
**Requirement**: SRC-19, SRC-20, SRC-21, SRC-22, SRC-23

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Outro usuário já com item no candidato não gera colisão: o item é movido para o candidato e `skipped` fica vazio (SRC-21)
- [x] Falha forçada no movimento da wishlist desfaz também o movimento de coleção já aplicado
- [x] Um run `succeeded` antigo seguido de um `failed` mais recente: o remap prossegue e move o item (SRC-23)
- [x] Colisão entre dois itens de wishlist do mesmo usuário e com item de wishlist já existente no candidato
- [x] "Ambíguo" com dois candidatos não-base
- [x] Idempotência com item pulado: a segunda execução repete o mesmo `skipped`, não move nada e o item movido continua na variante nova (SRC-22)
- [x] Item cuja variante está presente fica intocado, e o item movido não muda nenhum atributo além de `card_variant_id`, `updated_at` incluído (SRC-20)
- [x] Gate full passa; contagem de runs registrada

**Tests**: unit
**Gate**: full
**Commit**: `test(fonte-apitcg): cobrir colisão, rollback e idempotência do remap`

---

### T20: Lacunas de teste do rake `ingestion:remap`

**What**: Testes que faltam em `ingestion_remap_task_test.rb`, apontados pela análise de testes do lote A.
**Where**: `test/lib/ingestion_remap_task_test.rb`
**Depends on**: T18
**Reuses**: `run_task` existente
**Requirement**: SRC-19, SRC-21, SRC-22, SRC-23

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] No caminho de sucesso, o item movido aponta para a variante nova e o pulado continua na antiga
- [x] Sem run `succeeded`: stderr é exatamente a mensagem de SRC-23 com quebra de linha, e stdout fica vazio
- [x] A saída traz as linhas de "colisão" e "ambíguo" com o texto exato
- [x] Segunda execução imprime "movidos: 0 | pulados: N" com os mesmos pulados
- [x] Sem nada a mover, a saída é "movidos: 0 | pulados: 0"
- [x] A checagem de dado do usuário na saída não depende do valor do `id` (sai o `refute_match` por `\b<id>\b`, que casa com "1")
- [x] Gate full passa; contagem de runs registrada

**Tests**: integration
**Gate**: full
**Commit**: `test(fonte-apitcg): conferir efeito e saída do ingestion:remap`

---

### T21: Nome de cache sem colisão e extensão só do caminho

**What**: O `:` dos códigos da apitcg vira `__` no nome do arquivo (o formato antigo não admite `__`, logo `tcgplayer:123` e um eventual `tcgplayer-123` não dividem arquivo), e a extensão sai uma vez só de `uri.path`, usada na validação e no nome.
**Where**: `app/services/card_image_cache.rb`
**Depends on**: T7
**Reuses**: `file_stem`, `validate_extension`, `final_path_for`
**Requirement**: SRC-08

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] O arquivo em cache de `tcgplayer:123` é `tcgplayer__123.<ext>`, dentro de `storage/card_images/`
- [x] Gravado `tcgplayer:1`, a variante de código `tcgplayer-1` não é servida com o mesmo arquivo
- [x] URL `https://tcgplayer-cdn.tcgplayer.com/a.png?v=1.bar` grava `.png`; a query não muda a extensão nem gera arquivo duplicado
- [x] Os códigos antigos continuam com o mesmo nome de arquivo e o cache deles continua sendo lido
- [x] Gate full passa; contagem de runs registrada

**Tests**: unit
**Gate**: full
**Commit**: `fix(fonte-apitcg): separar o nome de cache dos códigos antigos`

---

### T22: Topo do detalhe com a variante presente

**What**: O topo do detalhe usa a primeira variante presente; só quando todas são ausentes usa a primeira e mostra "Variante fora da fonte" no cabeçalho. Na lista, o par vira `Situação` / `fora da fonte` (o texto literal de SRC-17).
**Where**: `app/views/catalog/show.html.erb` (e a regra de `.card-detail__status` em `app/assets/stylesheets/catalog.css`, que `class_coverage_test.rb` exige)
**Depends on**: T3
**Reuses**: `@absent_variant_ids`
**Requirement**: SRC-17

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Carta com variante ausente de `variant_code` menor que a presente: imagem, raridade e set do topo são os da presente
- [x] Carta com todas as variantes ausentes, aberta pelo dono: o cabeçalho mostra o texto visível "Variante fora da fonte"
- [x] Na lista, a variante ausente tem `dt` "Situação" e `dd` "fora da fonte"
- [x] Os testes de `test/integration/card_detail_*` e `test/design/card_detail_*` continuam passando
- [x] Gate full passa; contagem de runs registrada

**Tests**: integration
**Gate**: full
**Commit**: `fix(fonte-apitcg): mostrar a variante presente no topo do detalhe`

---

### T23: Numerador do progresso limitado ao denominador no texto

**What**: `Row#displayed_owned_numbers` devolve `[owned_numbers, base_size].min` quando há denominador, e a view usa esse valor no texto, no rótulo "N de M do set base" e na barra.
**Where**: `app/queries/set_progress_query.rb` (e `app/views/progress/index.html.erb`)
**Depends on**: T4
**Reuses**: `completion_percent_known?`
**Requirement**: SRC-26

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Set com `base_set_size` 7 e 8 números possuídos mostra "7 / 7 · 100%" e "7 de 7 do set base"
- [x] Set sem denominador mostra o numerador sem limite, como hoje (PRG-10)
- [x] Os testes de `test/queries/set_progress_*` e `test/design/progress_*` continuam passando
- [x] Gate full passa; contagem de runs registrada

**Tests**: integration
**Gate**: full
**Commit**: `fix(fonte-apitcg): limitar o numerador do progresso ao denominador`

---

### T24: Descartar produto sem `CardType`

**What**: Produto sem `CardType` na fonte entra nos descartes com o motivo "sem CardType", como o sem `code`, em vez de levantar `UnknownCardType` e derrubar a ingestão inteira. Um `CardType` presente e desconhecido continua sendo erro. Registrada depois do fato: o commit já existia sem T-id.
**Where**: `app/services/ingestion/apitcg/normalize.rb`, `test/services/ingestion/apitcg/normalize_test.rb`
**Depends on**: T11, T12
**Reuses**: lista de descartes do `Normalize` e `Upsert#error_log`
**Requirement**: SRC-36

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Produto sem `CardType` (ausente ou vazio) vai para os descartes com "sem CardType" e a ingestão continua (commit `64b9474`)
- [x] `CardType` presente e desconhecido continua levantando `UnknownCardType`
- [x] Gate full passa; 1534 runs, 0 falhas

**Tests**: unit
**Gate**: full
**Commit**: `fix(fonte-apitcg): descartar produto sem CardType em vez de derrubar a ingestão` (`64b9474`)

---

### T25: Ciclo de correção 1 do Verifier

**What**: Fix 1–7 do `validation.md`: `brakeman` 8.1.0 no `Gemfile.lock` (o gate saía com 5 por versão desatualizada); testes de borda que faltavam para SRC-02, SRC-04, SRC-05, SRC-17, SRC-32 e SRC-36; `Fetch#inspect` sem os headers; documentação.
**Where**: `Gemfile.lock`, `app/services/ingestion/apitcg/fetch.rb` (só `inspect`), `test/services/ingestion/upsert_test.rb`, `test/services/ingestion/run_test.rb`, `test/lib/ingestion_import_task_test.rb`, `test/integration/card_detail_absent_variant_test.rb`, `.context/requirements.md`, `tasks.md`
**Depends on**: T24
**Reuses**: dublês `FakeHttp` e helpers de cada arquivo de teste
**Requirement**: SRC-02, SRC-04, SRC-05, SRC-17, SRC-32, SRC-36

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Fix 1: `bin/brakeman --no-pager --ensure-ignore-notes --ensure-no-obsolete-ignore-entries` sai com 0 (brakeman 8.1.0; só essa linha muda no `Gemfile.lock`)
- [x] Fix 2: descarte sem `CardType` e sem `code` termina `succeeded`, `failed_count` 0, dois descartes no `error_log`; a mutação que faz `failed_count` contar descarte derruba 4 testes
- [x] Fix 3: `NetHttpClient` aplica `config.timeout` a `open_timeout` e `read_timeout` (mutação nos timeouts derruba o teste); rake `import` com busca `failed` e com 401 sai com 1 e escreve `status: failed`; SRC-02 confere catálogo vazio
- [x] Fix 4: chave fora de stdout e stderr do rake (mutação que a imprime derruba 2 testes); `Fetch#inspect` sem `@headers` (mutação que remove o `inspect` derruba o teste)
- [x] Fix 5: dono por wishlist de carta só com ausentes recebe 200 (mutação sem wishlist derruba 2 testes); item de terceiros na ausente não aparece sem sessão
- [x] Fix 6: `.context/requirements.md` e este arquivo corrigidos; a §8.6 do `.context/tasks.md` **não** é fechada (depende do item de 24h da T17)
- [x] Fix 7: asserções vacuosas trocadas por valor exato em `run_test.rb` e `ingestion_import_task_test.rb`; depois do Verifier, `ingestion_remap_task_test.rb` perde o `refute_includes` implicado pela linha exata, `ingestion_compare_snapshots_task_test.rb` restaura `A`/`B` no teardown e o teste de teto de `set_progress_numbers_test.rb` usa `base_set_size` 2 contra 3 números (a mutação que tira o teto derruba o teste: 150,0 ≠ 100,0). `run_test.rb:77` fica: o `Run` recebe o `fetch:` com o dublê, então a asserção prova que o caminho com snapshot não o usa
- [x] Gate full e build (a cargo do supervisor)

**Tests**: unit + integration
**Gate**: full
**Commit**: `test(fonte-apitcg): fechar as lacunas de evidência do ciclo de correção 1`

---

## Plano de delegação

17 tasks, em três lotes de fases inteiras: **Lote A** = Phases 1–3 (T1–T7), que
não dependem da API; **Lote B** = Phase 4 (T8–T10), em que a T10 para no aval do
dono; **Lote C** = Phases 5–6 (T11–T17), em que a T17 para no aval do dono.
Revisões por agente agnóstico de linguagem, já que não há revisor Ruby:
`ecc:database-reviewer` em T2, T4 e T5; `ecc:a11y-architect` em T3;
`ecc:security-reviewer` em T7, T8 e T9; `ecc:silent-failure-hunter` em T9 e T13;
`ecc:pr-test-analyzer` em T5 e T14. O Verifier roda depois da T17.

---

## Task Granularity Check

| Task | Escopo | Status |
|---|---|---|
| T1 | 1 scope | ✅ |
| T2 | 1 query object | ✅ |
| T3 | 1 controller + a linha da view que ele alimenta | ⚠️ coeso |
| T4 | 1 query object + a linha da view que exibe o resultado | ⚠️ coeso (a view quebra se a query mudar sozinha) |
| T5 | 1 serviço | ✅ |
| T6 | 1 rake task | ✅ |
| T7 | 1 serviço | ✅ |
| T8 | 1 classe + o YAML que ela lê | ⚠️ coeso |
| T9 | 1 serviço | ✅ |
| T10 | 1 fixture + o script que a verifica | ⚠️ coeso |
| T11 | 1 serviço | ✅ |
| T12 | 1 serviço | ✅ |
| T13 | 1 serviço + o rake que o chama | ⚠️ coeso |
| T14 | remoção + 1 arquivo de teste | ⚠️ coeso (a remoção só passa com a migração do teste) |
| T15 | 1 serviço + o rake que o chama | ⚠️ coeso |
| T16 | documentação | ✅ |
| T17 | execução + registro | ✅ |
| T18 | 1 serviço + o lock no model + o rescue no rake | ⚠️ coeso (a exceção nova só existe com quem a trata) |
| T19 | 1 arquivo de teste | ✅ |
| T20 | 1 arquivo de teste | ✅ |
| T21 | 1 serviço | ✅ |
| T22 | 1 view | ✅ |
| T23 | 1 query object + a linha da view que exibe o resultado | ⚠️ coeso |
| T24 | 1 guarda no `Normalize` + 1 teste | ✅ |
| T25 | correções de teste, 1 `inspect` e documentação | ⚠️ coeso |

## Diagram-Definition Cross-Check

| Task | Depends On (task body) | Diagram Shows | Status |
|---|---|---|---|
| T1 | None | — | ✅ |
| T2 | T1 | T1 → T2 | ✅ |
| T3 | T1 | T1 → T3 | ✅ |
| T4 | T1 | T1 → T4 | ✅ |
| T5 | T1 (Phase 1) | fase anterior | ✅ |
| T6 | T5 | T5 → T6 | ✅ |
| T7 | None | — | ✅ |
| T8 | None | — | ✅ |
| T9 | T8 | T8 → T9 | ✅ |
| T10 | T9 | T9 → T10 | ✅ |
| T11 | T10 (Phase 4) | fase anterior | ✅ |
| T12 | T11 | T11 → T12 | ✅ |
| T13 | T9 (Phase 4), T12 | T12 → T13 | ✅ |
| T14 | T13 | T13 → T14 | ✅ |
| T15 | T10 (Phase 4) | fase anterior | ✅ |
| T16 | T14 (Phase 5) | fase anterior | ✅ |
| T17 | T16 | T16 → T17 | ✅ |
| T18 | T5, T6 (Phase 2) | fase anterior | ✅ |
| T19 | T18 | T18 → T19 | ✅ |
| T20 | T18 | T18 → T20 | ✅ |
| T21 | T7 (Phase 3) | fase anterior | ✅ |
| T22 | T3 (Phase 1) | fase anterior | ✅ |
| T23 | T4 (Phase 1) | fase anterior | ✅ |
| T24 | T11, T12 (Phase 5) | fase anterior | ✅ |
| T25 | T24 | fase anterior | ✅ |

## Test Co-location Validation

| Task | Camada | Matriz exige | Task diz | Status |
|---|---|---|---|---|
| T1 | Model | unit | unit | ✅ |
| T2 | Query | unit | unit | ✅ |
| T3 | Controller + view | integration | integration | ✅ |
| T4 | Query + view | integration (maior das duas) | integration | ✅ |
| T5 | Serviço | unit | unit | ✅ |
| T6 | Rake | integration | integration | ✅ |
| T7 | Serviço + rota existente | integration (maior das duas) | integration | ✅ |
| T8 | Serviço de config | unit | unit | ✅ |
| T9 | Serviço | unit | unit | ✅ |
| T10 | Fixture | script offline | integration | ✅ (`verify_fixture.py` + gate full) |
| T11 | Serviço | unit | unit | ✅ |
| T12 | Serviço | unit | unit | ✅ |
| T13 | Serviço + rake | integration | integration | ✅ |
| T14 | Testes de garantia | unit | unit | ✅ |
| T15 | Serviço + rake | integration | integration | ✅ |
| T16 | Documentação | none | none | ✅ |
| T17 | Execução real | none | none | ✅ |
| T18 | Serviço + rake | unit (o rake só repassa a mensagem; coberto pelos testes de T20) | unit | ✅ |
| T19 | Serviço | unit | unit | ✅ |
| T20 | Rake | integration | integration | ✅ |
| T21 | Serviço | unit | unit | ✅ |
| T22 | View | integration | integration | ✅ |
| T23 | Query + view | integration | integration | ✅ |
| T24 | Serviço | unit | unit | ✅ |
| T25 | Testes | unit + integration | unit + integration | ✅ |
