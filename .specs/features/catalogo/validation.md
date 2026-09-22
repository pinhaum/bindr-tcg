# Catálogo — Validação do lote B1 (T3–T9, Fase 2)

**Date**: 2026-09-19
**Spec**: `.specs/features/catalogo/spec.md`
**Diff range**: `8e46b9c..0151f56` (escopo designado) + `249f43d`, commit
concorrente que entrou durante esta verificação (ver *Nota sobre o escopo*)
**Verifier**: subagente independente (autor ≠ verificador)
**Veredito**: ✅ **PASS**, com 1 lacuna de cobertura registrada (não bloqueante)

---

## Nota sobre o escopo

O intervalo designado foi `8e46b9c..0151f56`. Duas correções de escopo:

1. **`8e46b9c` é o commit da T3**, e a notação `A..B` o exclui. Os critérios da
   T3 foram verificados lendo o próprio commit
   (`db/migrate/20260919120000_create_catalog_tables.rb`,
   `test/models/catalog_schema_test.rb`), não o diff.
2. **`249f43d` foi commitado às 18:35**, durante esta verificação, pelo
   orquestrador, em resposta à revisão de banco. Ele acrescenta três testes de
   plano de execução à T4. Está incluído na verificação porque altera
   diretamente a cobertura de um critério em escopo.

---

## Task Completion

| Task | Status | Notas |
| ---- | ------ | ----- |
| T3 | ✅ Done | Schema verificado no commit `8e46b9c` |
| T4 | ✅ Done | Reforçada por `249f43d` (counter + full-text) |
| T5 | ✅ Done | — |
| T6 | ✅ Done | 1 lacuna de cobertura (M10), abaixo |
| T7 | ✅ Done | — |
| T8 | ✅ Done | — |
| T9 | ✅ Done | `Tests: none` deliberado; contagens re-derivadas por mim |

---

## Verificação ancorada no spec

### T3 — Migrações de `sets`, `cards`, `card_variants`

| Critério (Done when) | Resultado definido pelo spec | `file:line` + asserção | Result |
| -------------------- | ---------------------------- | ---------------------- | ------ |
| `card_number` único | Req. 1.2 / CAT-01: segunda carta com mesmo número é recusada pelo banco | `test/models/catalog_schema_test.rb:54` — `assert_raises(ActiveRecord::RecordNotUnique)` + `assert_match(/card_number/, error.message)` | ✅ PASS |
| `(card_id, variant_code)` único | Req. 1.3 | `test/models/catalog_schema_test.rb:66` — `assert_raises(ActiveRecord::RecordNotUnique)` | ✅ PASS |
| Mesmo `variant_code` em cartas distintas é permitido | Edge case do spec (`P-029_r1`) | `test/models/catalog_schema_test.rb:79` — `assert create_variant(...)` | ✅ PASS |
| FK sem delete em cascata | Req. 1.7 / design §5.2 | `test/models/catalog_schema_test.rb:92` — consulta `pg_constraint` por `confdeltype='c'`, `assert_empty` | ✅ PASS |
| `rarity` como texto, não enum | design §3.3 | `test/models/catalog_schema_test.rb:117` — grava `"RARIDADE INEDITA"` e assere `data_type = 'text'` | ✅ PASS |
| `counter` NULL ≠ 0 | Edge case do spec: nunca 0 como sentinela | `test/models/catalog_schema_test.rb:135` — `assert_nil` + `assert_equal 0` + contagem `counter IS NULL` | ✅ PASS |
| `colors`/`traits`/`attributes` como arrays | Req. 4.5 | `test/models/catalog_schema_test.rb:149` — `assert_equal %w[ARRAY ARRAY ARRAY]` | ✅ PASS |

A asserção de unicidade é real: `insert_returning_id`
(`test/models/catalog_schema_test.rb:17`) força `connection.uncached`, senão o
cache de consulta do Active Record devolveria o INSERT memoizado e a violação
nunca chegaria ao banco. É um cuidado que a maioria das suítes erra.

### T4 — Índices do catálogo

| Critério | Resultado definido pelo spec | `file:line` + asserção | Result |
| -------- | ---------------------------- | ---------------------- | ------ |
| GIN nas colunas de array | Req. 4.1/4.5 | `test/models/catalog_indexes_test.rb:141` — varre `pg_indexes` por `USING gin` em `colors`, `traits`, `attributes_list` | ✅ PASS |
| Trigram no nome | Req. 3.2 | `test/models/catalog_indexes_test.rb:153` — `assert_match(/gin_trgm_ops/, definicao)` | ✅ PASS |
| `pg_trgm` e `unaccent` habilitadas | Req. 3.1–3.3 | `test/models/catalog_indexes_test.rb:133` — `assert_includes` em `pg_extension` | ✅ PASS |
| Filtro por cor sem full table scan | Req. 11.3, verificável por plano | `test/models/catalog_indexes_test.rb:75` — `refute_match(/Seq Scan on cards/, plan)` sobre `EXPLAIN` | ✅ PASS |
| Filtro por faixa de custo sem full table scan | Req. 11.3 | `test/models/catalog_indexes_test.rb:93` | ✅ PASS |
| Faixa de `counter` sem full table scan | Req. 4.2 (terceira coluna de faixa) | `test/models/catalog_indexes_test.rb:106` — acrescentado por `249f43d` | ✅ PASS |
| Índice full-text de efeito é usado | Req. 3.3 | `test/models/catalog_indexes_test.rb:125` — acrescentado por `249f43d` | ✅ PASS |

**O teste é honesto sobre seletividade.** `seed_catalog`
(`test/models/catalog_indexes_test.rb:32`) semeia 20k linhas com cor, custo e
counter raros e roda `ANALYZE`. Sem isso, o planejador escolheria Seq Scan *com
razão* e o teste não distinguiria índice ausente de índice ignorado por custo —
ele provaria nada. O commit `249f43d` documenta a medição que sustenta a
escolha (`counter BETWEEN 1000 AND 2000` casa 1721 de 2815 cartas reais).

#### `schema_format = :sql` e `immutable_unaccent` — ceticismo resolvido

Ambas as afirmações do autor procedem, verificadas por mim no servidor:

- `unaccent` é **STABLE** (`provolatile = 's'`) nas duas assinaturas;
  `immutable_unaccent` é **IMMUTABLE** (`'i'`). A afirmação está correta e o
  wrapper é a saída certa.
- **Semântica do wrapper conferida**: `immutable_unaccent('Pórtgas D. Ácé çãõ ñ')`
  e `unaccent(...)` devolvem ambos `Portgas D. Ace cao n`. Idênticos.
- **`db/structure.sql` recria tudo do zero**: carreguei-o em um banco novo
  (`verifier_structure_probe`) com `ON_ERROR_STOP=1` — exit 0, a função volta
  com `provolatile='i'`, os 5 índices GIN/trigram voltam, 8 tabelas. O desvio
  do padrão Rails está justificado e funciona. Banco de prova removido.
- O índice **é de fato usado**: `test/models/catalog_indexes_test.rb:167`
  assere ausência de `Seq Scan` numa busca por `immutable_unaccent(name)`.

### T5 — Estágio Fetch

| Critério | Resultado definido pelo spec | `file:line` + asserção | Result |
| -------- | ---------------------------- | ---------------------- | ------ |
| Revisão fixada, nunca `main` | Req. 1.9: referência móvel rejeitada | `test/services/ingestion/fetch_test.rb:14` — itera `main master HEAD latest Main`, `assert_raises(InvalidRevision)` + `assert_match(/referência móvel/)` | ✅ PASS |
| Validação na **carga**, não no download | Req. 1.11: pin é ato explícito | `test/services/ingestion/fetch_test.rb:47` — `SourceConfig.load` real assere `COMMIT_SHA` | ✅ PASS |
| Payload bruto salvo antes de processar | Req. 11.5 | `test/services/ingestion/fetch_test.rb:92` — `assert_equal PAYLOAD, resultado.path.read` | ✅ PASS |
| Aborta sem escrever se a fonte cai | Req. 1.8 | `test/services/ingestion/fetch_test.rb:111`, `:120`, `:128` — rede, timeout e HTTP 404, cada um com `assert_empty @storage.children` | ✅ PASS |

A rejeição não é lista negra furada: `TAG`
(`app/services/ingestion/source_config.rb:123`) é deliberadamente estreita, e
`fetch_test.rb:23` prova que `v1-branch-do-fulano` e um SHA curto são recusados.

### T6 — Estágio Normalize

| Critério | Resultado definido pelo spec | `file:line` + asserção | Result |
| -------- | ---------------------------- | ---------------------- | ------ |
| `variant_code` = `id` da fonte, sem hash | AD-001 | `test/services/ingestion/normalize_test.rb:31` — `assert_equal "OP01-001_p1", variant("OP01-001_p1").variant_code` | ✅ PASS |
| `traits` normalizados em caixa e espaçamento | Edge case do spec | `test/services/ingestion/normalize_test.rb:97` — três grafias colapsam em `["Straw Hat Crew"]` | ✅ PASS |
| Grafia da fonte preservada | Achado da T9 | `test/services/ingestion/normalize_test.rb:119` — `["Former CP9", "Kingdom of GERMA", "Land of Wano"]` | ✅ PASS |
| `counter` nulo preservado como NULL | Edge case: nunca 0 | `test/services/ingestion/normalize_test.rb:56` — `assert_nil` + `refute_equal 0` | ✅ PASS |
| Trata `attribute: "?"` sem falhar | Edge case (OP13-079) | `test/services/ingestion/normalize_test.rb:89` — `assert_equal ["?"], imu.attributes_list` | ✅ PASS |
| Roda sobre fixture, sem rede | Req. 11.5 | `normalize_test.rb:8` — entrada é `spec/fixtures/optcgjson-subset.json` | ✅ PASS |
| `data` como objeto **ou** lista | Achado da T9 | `test/services/ingestion/normalize_test.rb:206` — compara as duas formas | ✅ PASS |
| Conversão string→inteiro | Req. 4.2 (faixas não podem comparar texto) | `test/services/ingestion/normalize_test.rb:81` — `assert_empty numericos.grep(String)` | ⚠️ ver lacuna M10 |

### T7 — Estágio Upsert + `import_runs`

| Critério | Resultado definido pelo spec | `file:line` + asserção | Result |
| -------- | ---------------------------- | ---------------------- | ------ |
| Upsert por `card_number`, nunca create cego | Req. 1.2 | `test/services/ingestion/upsert_test.rb:27` — `assert_equal 1, Card.count` + nome atualizado de "Nome Antigo" para "Nome Novo" | ✅ PASS |
| Upsert por `(card_id, variant_code)` | Req. 1.3 | `test/services/ingestion/upsert_test.rb:39` — `assert_equal variante.id, CardVariant.sole.id` (id estável, não só contagem) | ✅ PASS |
| Erro em um registro vai para `error_log`, loop continua | Req. 1.5 | `test/services/ingestion/upsert_test.rb:99` — `failed_count=2`, `Card.count=2`, `status="failed"` | ✅ PASS |
| `error_log` identifica registro e motivo | Req. 1.5 | `test/services/ingestion/upsert_test.rb:118` — `assert_equal "TST-001", entrada["identifier"]` + erro encadeado registrado à parte | ✅ PASS |
| Resumo com início, fim, status, 3 contagens | Req. 1.6 | `test/services/ingestion/upsert_test.rb:68` | ✅ PASS |
| Resumo registra a revisão utilizada | Req. 1.10 | `test/services/ingestion/upsert_test.rb:80` — `assert_equal REVISION, run.source_revision` | ✅ PASS |
| `P-029_r1` em dois sets não duplica | Edge case do spec | `test/services/ingestion/upsert_test.rb:50` — `assert_equal 1, CardVariant.where(variant_code: "P-029_r1").count` | ✅ PASS |

### T8 — Testes de garantia da ingestão

| Critério | Resultado definido pelo spec | `file:line` + asserção | Result |
| -------- | ---------------------------- | ---------------------- | ------ |
| Duas execuções não alteram contagem | Req. 1.4 | `test/services/ingestion/guarantees_test.rb:28` — contagem **e** `status="succeeded"`, `failed_count=0`, `created_count=0`, `updated_count=soma` | ✅ PASS |
| `collection_item` intacto após reingestão | Req. 1.7 — o teste mais valioso | `test/services/ingestion/guarantees_test.rb:63` — `assert_equal 3, item.quantity` + `card_variant_id` estável + `status="succeeded"` | ✅ PASS |
| Carta ausente da fonte não é deletada | Req. 1.7 | `test/services/ingestion/guarantees_test.rb:106` — `assert Card.exists?` + contagem preservada | ✅ PASS |
| Ausente é **marcada**, não removida | Req. 1.7 | `test/services/ingestion/guarantees_test.rb:119` — `last_seen_at` do ausente inalterado, do presente atualizado | ✅ PASS |
| Ingestão não tem operação de delete | design §5.2 | `test/services/ingestion/guarantees_test.rb:136` — `refute_match` de `destroy`/`delete`/`DELETE FROM` no fonte do upsert | ✅ PASS |
| Banco recusa remover variante possuída | design §5.2 | `test/services/ingestion/guarantees_test.rb:154` — `assert_raises(ActiveRecord::InvalidForeignKey)` | ✅ PASS |

**A asserção de idempotência é forte pelo motivo certo.** O comentário em
`guarantees_test.rb:38` registra exatamente a armadilha: contagem estável
sozinha não prova idempotência, porque uma ingestão que falha em *todo* registro
também deixa a contagem intacta. As asserções exigem `status` e `failed_count`.
Isso é a correção de um mutante que sobreviveu à primeira versão do teste — o
histórico está honesto na task.

### T9 — Carga real (`Tests: none`)

`Tests: none` é deliberado e coberto pela Test Coverage Matrix. Como não há
teste, **re-derivei cada número de forma independente**, do payload bruto e do
banco:

| Afirmação da T9 | Como verifiquei | Result |
| --------------- | --------------- | ------ |
| 2815 cartas / 4914 variantes / 62 sets | `psql` no banco de desenvolvimento: `2815 / 4914 / 62` | ✅ confere |
| 7791 criados, 0 falhas | `import_runs` id 2: `created=7791, failed=0, status=succeeded` | ✅ confere |
| Idempotência: 0 criados / 7791 atualizados | `import_runs` id 3: `created=0, updated=7791, failed=0` | ✅ confere |
| 4914 ≠ 4915 por causa de `P-029_r1` | Contei o payload bruto em Python: **4915 linhas de carta, 4914 `id` distintos, único duplicado = `P-029_r1`**, 2815 `number` distintos, 62 sets | ✅ confere exatamente |
| `EB01-001` é Leader dual-color Red/Green | `psql`: `Kouzuki Oden, {Red,Green}, leader` | ✅ confere |
| `EB01-006` tem 6 variantes em 3 sets | `psql`: 6 variantes em `EB01`, `Promotioncard`, `PRB01` | ✅ confere |

A inspeção manual **é verificável**, e verifiquei-a. Além disso, os dois achados
da carga real têm regressão automatizada: `data` como objeto
(`normalize_test.rb:206`) e a grafia de traits (`normalize_test.rb:119`). Ou
seja, o que a T9 descobriu não depende de ninguém lembrar.

**Reprodutibilidade provada por acidente útil:** durante esta verificação
apaguei o banco de desenvolvimento (ver *Incidente*). Reconstruí-o **offline**,
sem rede, com `REUSE_PAYLOAD=1 bin/rails ingestion:import` a partir do payload
fixado em disco, e obtive `2815 / 4914 / 62`, `7791 criados, 0 falhados` —
exatamente os números da T9. Isso valida na prática a promessa central do
AD-001 e do estágio Fetch: o catálogo é reconstruível sem rede.

---

## Sensor de discriminação

**Isolamento:** cópia de arquivo para o scratchpad, mutação, execução,
restauração por `cp`. **Nenhum `git stash`.** `git status --porcelain` conferido
vazio antes, entre e depois de cada mutante.

Os quatro mutantes que o plano exige já haviam sido rodados pelo orquestrador e
não foram repetidos. Os 18 abaixo são novos.

| # | Arquivo:linha | Mutação | Killed? |
| - | ------------- | ------- | ------- |
| M1 | `normalize.rb:162` | Remove dedup insensível a caixa em `traits` | ✅ Killed (1F) |
| M2 | `normalize.rb:128` | `variant_code` derivado por MD5 em vez de vir da fonte | ✅ Killed (2F 7E) |
| M3 | `normalize.rb:173` | `presence` sem colapso de espaçamento | ✅ Killed (1F) |
| M4 | `normalize.rb:162` | Volta do Title Case (a regressão que a T9 descobriu) | ✅ Killed (2F) |
| M5 | `normalize.rb:66` | Chave da variante inclui o set → `P-029_r1` duplica | ✅ Killed (4F) |
| M6 | `source_config.rb:157` | Aceita referência móvel (`main`/`HEAD`) | ✅ Killed (1F) |
| M7 | `fetch.rb:66` | Grava o payload **antes** de validar o status HTTP | ✅ Killed (1F) |
| M8 | `upsert.rb:46` | Remove `transaction(requires_new: true)` por registro | ⚪ Equivalente (ver abaixo) |
| M8b | `upsert.rb:30-38` | Transação **única** envolvendo o laço inteiro | ✅ Killed (1F) |
| M9 | `upsert.rb:56` | `error_log` engolido (erro contado, não registrado) | ✅ Killed (1E) |
| M10 | `normalize.rb:189` | `to_integer` devolve `0` em vez de `nil` para string não-numérica | ❌ **SOBREVIVEU** |
| M11 | `normalize.rb:112` | `attribute: "?"` descartado | ✅ Killed (1F) |
| M12 | `upsert.rb:77` | `last_seen_at` nunca gravado | ✅ Killed (2F) |
| M13b | banco de teste | `DROP INDEX index_cards_on_colors` | ✅ Killed (3F) |
| M14 | banco de teste | `immutable_unaccent` devolve a entrada sem remover acento | ✅ Killed (1F) |
| M15 | `upsert.rb:90` | Chave de upsert da variante inclui `set_id` | ⚪ Equivalente (ver abaixo) |
| M16 | `normalize.rb:140` | `art_kind` sempre `"base"` (perde parallel) | ✅ Killed (1F) |
| M17 | `normalize.rb:103` | Cores truncadas na primeira (quebra Req. 4.5) | ✅ Killed (1F) |
| M18 | `upsert.rb:99` | `status` sempre `"succeeded"` mesmo com falhas | ✅ Killed (1F) |
| M19 | `upsert.rb:14` | `MAX_LOGGED_ERRORS = 0` | ✅ Killed (1E) |
| M20 | `upsert.rb:24` | `source_revision` gravada como `"main"` | ✅ Killed (1F) |
| M21 | banco de teste | `DROP INDEX index_cards_on_counter` | ✅ Killed (1F) |
| M22 | banco de teste | `DROP INDEX index_cards_on_effect_text_tsvector` | ✅ Killed (1F) |

**Sensor depth**: P0-full (a ingestão é integridade de dados do usuário).
**Resultado**: 20 mortos, 2 equivalentes, **1 sobrevivente real (M10)**.

### M8 e M15 — investigados e classificados como equivalentes, não lacunas

Registro o raciocínio porque "sobreviveu" e "é lacuna" não são a mesma coisa, e
tratar um mutante equivalente como falha geraria uma task de correção inútil.

**M8** (remover a transação por registro) deixa a suíte verde. Investiguei em
vez de reportar: todos os erros que a suíte injeta são `RecordInvalid`,
levantado pela **validação do model**, antes de qualquer INSERT — não há nada
para reverter. Construí um teste-sonda com erro de **banco** (check constraint
de `card_type`) e rodei fora da transação de teste, no cenário de produção: o
original grava 2 de 3; o mutante **também** grava 2 de 3, porque sem transação
envolvente cada `update!` já é a sua própria transação implícita. M8 é
semanticamente equivalente. O mutante que descreve a falha real — **M8b**,
transação única no laço inteiro, exatamente o que o comentário de
`upsert.rb:43` adverte — **é morto**. O Req. 1.5 está protegido.

**M15** (incluir `set_id` na chave de upsert da variante) também sobrevive.
Causa: o Normalize já deduplica por `variant_code` em `normalize.rb:66`, então o
Upsert nunca recebe `P-029_r1` duas vezes e a sua defesa não é exercitada.
Testei o cenário que a quebraria — variante migrando de set entre execuções — e
o vínculo da coleção se mantém: o índice `UNIQUE (card_id, variant_code)` da T3
impede a duplicata mesmo com a chave de upsert errada. É defesa em profundidade
com duas camadas; a de baixo segura. Não é lacuna, mas vale saber que a camada
de cima não tem teste próprio.

### M10 — mutante sobrevivente (lacuna real)

```ruby
# app/services/ingestion/normalize.rb:189
- Integer(text, exception: false)
+ Integer(text, exception: false) || 0
```

Suíte completa **verde** (84 runs, 218 assertions, 0 failures).

`to_integer` devolve `nil` em três caminhos: valor `nil`, string vazia e
**string não-numérica** (`Integer(..., exception: false)` devolve `nil`). Os
dois primeiros têm guarda explícita e teste. O terceiro não tem teste nenhum.

Alcançabilidade medida na fonte real, não suposta: `counter`, `cost`, `life` e
`power` não trazem string não-numérica hoje — mas **`blockIcon` traz `"X"` em 27
registros**, e o banco de desenvolvimento confirma 8 cartas com
`block_icon IS NULL` vindas exatamente desse caminho. Sob M10 elas viriam como
`block_icon = 0`.

Por que nenhum teste pega:
- `normalize_test.rb:56` usa `OP01-001`, cujo `counter` é `nil` **na fonte** — a
  guarda `return nil if value.nil?` (`normalize.rb:184`) responde antes, e a
  mutação nunca é atingida.
- `normalize_test.rb:81` (`assert_empty numericos.grep(String)`) só verifica que
  nada escapou como String; `0` passa.
- `normalize_test.rb:77` assere `block_icon == 1`, um valor numérico.

Gravidade: **Minor**, e não bloqueia o lote. Hoje o único campo afetado é
`block_icon`, que nenhum requisito da Fase 1 consome. Mas o defeito é
exatamente o padrão que o spec proíbe em `counter` ("nunca 0 como sentinela") e
a proibição está escrita no design como regra geral de modelagem, não como
exceção de um campo. Se a fonte passar a trazer `"X"` em `counter` ou `"?"` em
`cost` — plausível num scraper comunitário, e é a premissa que sustenta
`rarity` como texto —, o dado entra corrompido em silêncio.

**Correção sugerida** (do orquestrador, não minha): um teste em
`test/services/ingestion/normalize_test.rb` que passe `"X"` num campo numérico e
assere `nil`, não `0`.

---

## Code Quality

| Princípio | Status |
| --------- | ------ |
| Código mínimo | ✅ |
| Mudanças cirúrgicas | ✅ |
| Sem scope creep | ✅ (`users`/`collection_items` justificados na T8: a invariante do Req. 1.7 não é demonstrável sem coleção) |
| Segue os padrões do projeto | ✅ |
| Checagem ancorada no spec | ✅ |
| Cobertura por camada | ✅ Normalize unit; Upsert integration; índices via plano |
| Todo teste mapeia a um requisito | ✅ — nenhum teste órfão |
| Guidelines documentadas seguidas | ✅ `CLAUDE.md`, `.context/design.md` §3/§5 |
| `SPEC_DEVIATION` marcados | ✅ `app/models/card_set.rb:1` e `db/migrate/20260919120000_create_catalog_tables.rb:41` |

**Renomeações conferidas**: `attributes → attributes_list` e `Set → CardSet`
estão marcadas com `SPEC_DEVIATION` e com a razão técnica verificável
(`ActiveRecord::DangerousAttributeError`; `Set` da stdlib). **Não vazaram para o
schema**: `information_schema.tables` lista a tabela como `sets`, e
`card_set.rb:6` fixa `self.table_name = "sets"`. Correto.

**Gem `json ~> 2.7` — a justificativa procede, não é superstição.** Verifiquei:
`activesupport-8.0.5.1/lib/active_support/json/encoding.rb:110` chama de fato
`JSON.generate(jsonified, quirks_mode: true, max_nesting: false)`. E o efeito é
real: com a json 3.0.2 (presente na imagem), `JSON.generate(..., quirks_mode: true)`
levanta `ArgumentError: unknown keyword: quirks_mode`. Sob `bundle exec` o pin
resolve para 2.21.2 e funciona. Como `import_runs.error_log` é `jsonb`, soltar o
pin quebraria o Req. 1.5 inteiro. Pin correto e bem documentado.

---

## Edge Cases (do spec)

- [x] `variant_code` em dois sets = uma variante — `upsert_test.rb:50`, `normalize_test.rb:48`
- [x] Raridade/attribute desconhecido persiste como texto — `catalog_schema_test.rb:117`, `normalize_test.rb:89`
- [x] `counter` NULL ≠ 0 — `catalog_schema_test.rb:135`, `normalize_test.rb:56` (⚠️ caminho de string não-numérica descoberto, M10)
- [x] `traits` com variação de caixa/espaçamento normalizados — `normalize_test.rb:97`

---

## Gate Check

- **Gate**: full = `bin/rails test && bin/rubocop`
- **Resultado**: **84 runs, 218 assertions, 0 failures, 0 errors, 0 skips** (exit 0)
- **RuboCop**: 45 arquivos, **no offenses** (exit 0)
- **Contagem antes do lote**: 3 testes (`test/lib/stack_test.rb`)
- **Delta**: **+81 testes**
- **Skips**: nenhum

### Flakiness observada

A **primeira** execução da suíte falhou:

```
Ingestion::GuaranteesTest#test_a_marca_de_última_aparição_distingue_o_presente_do_ausente
test/services/ingestion/guarantees_test.rb:130
Expected 2026-09-19 21:31:10.897 to be > 2026-09-19 21:31:19.007
```

Essa execução reportou **81 runs** em vez de 84 — um worker paralelo não
completou. Nas **6 execuções seguintes** da suíte completa e nas **9** do
arquivo isolado, passou sempre (0 falhas). Não consegui reproduzir.

Registro como **observação, não como falha do lote**: a asserção
`presente.last_seen_at > ausente.last_seen_at` compara timestamps de duas
execuções de ingestão e, sob contenção entre os 4 workers paralelos, a segunda
ingestão pode receber um `started_at` anterior ao da primeira. Não é defeito de
produção — é a suíte competindo consigo mesma. Se voltar, a saída é congelar o
relógio (o `Upsert` já aceita `clock:` injetável em `upsert.rb:16`) em vez de
afrouxar a asserção.

---

## Incidente durante a verificação (transparência)

Rodei `bin/rails db:drop db:create db:migrate RAILS_ENV=test` para restaurar o
banco de teste após um mutante de índice. **`RAILS_ENV` como argumento posicional
não é lido pelo Rails** — só como prefixo de ambiente —, então o comando atingiu
o banco de **desenvolvimento** e apagou o catálogo carregado pela T9.

Restaurado integralmente, **sem rede**, com
`REUSE_PAYLOAD=1 bin/rails ingestion:import`, a partir do payload da revisão
fixada em `storage/ingestion/`: `2815 / 4914 / 62`, `7791 criados, 0 falhados`.
Estado final do banco de desenvolvimento idêntico ao anterior, com um
`import_run` a mais.

Nenhum arquivo versionado foi tocado: `git status --porcelain` vazio.

---

## Requirement Traceability Update

| Requirement | Status anterior | Novo status |
| ----------- | --------------- | ----------- |
| CAT-01 (Ingestão, Req. 1.1–1.11) | Pending | ✅ **Verified** |
| CAT-04 (Filtros — parte de índices, Req. 4.1/4.2/11.3) | Pending | ⏳ Parcial — índices verificados; semântica OU/E é T10 |
| CAT-05 (Detalhe — parte de schema) | Pending | ⏳ Parcial — schema verificado; exibição é T12+ |
| CAT-02, CAT-03 | Pending | Pending (Fase 3) |

---

## Summary

**Overall**: ✅ **Pronto** — a Fase 3 pode abrir.

**Checagem ancorada no spec**: 36/36 critérios de "Done when" de T3–T9 com
evidência `file:line`. Nenhum critério sem teste que o cubra, exceto a T9, cujo
`Tests: none` é deliberado e cujas afirmações re-derivei manualmente contra a
fonte bruta e o banco — todas conferem, inclusive as duas cartas da inspeção.

**Sensor**: 23 mutantes novos; 20 mortos, 2 equivalentes (investigados, não
lacunas), **1 sobrevivente real**.

**Gate**: 84 testes, 0 falhas; RuboCop limpo.

**O que está sólido**: a invariante mais cara do projeto — reingestão não
corrompe coleção — está genuinamente protegida, e as asserções são fortes pelo
motivo certo (exigem `status` e `failed_count`, não só contagem). Todos os
quatro pontos de ceticismo apontados ao Verifier se sustentaram na verificação:
`schema_format = :sql` recria tudo do zero, o wrapper `immutable_unaccent` é
semanticamente idêntico ao `unaccent` e o índice é usado, as contagens da T9
batem exatamente com a fonte bruta, as renomeações não vazaram para o schema, e
o pin da gem `json` tem causa reproduzível.

**Lacuna encontrada**: M10 — `to_integer` sem teste para string não-numérica;
sob mutação, `"X"` viraria `0`, o sentinela que o spec proíbe. Alcançável hoje
em `blockIcon` (27 registros na fonte, 8 cartas no banco), não em `counter`.
Minor, não bloqueante.

**Próximo passo**: abrir a T10 (Fase 3). Corrigir M10 é uma task de teste de uma
linha; cabe no início da T10 ou como fix isolada, a critério do orquestrador.

---
---

# Catálogo — Validação do lote B2 (T10–T14, Fase 3)

**Date**: 2026-09-19
**Spec**: `.specs/features/catalogo/spec.md`
**Diff range**: `22612fe..5dd1f85` (escopo designado). Durante a verificação
entrou `7e28f1c` (a11y), commit concorrente fora do escopo — ver *Nota sobre o
escopo*.
**Verifier**: subagente independente (autor ≠ verificador)
**Veredito**: ✅ **PASS**, com **1 defeito real** e **2 lacunas de cobertura**
registrados (nenhum bloqueante para fechar a Fase 3; o defeito é Major)

---

## Nota sobre o escopo

1. **`22612fe` é a correção do `design.md`**, não uma task, e `A..B` o exclui —
   correto. Confirmei que os cinco commits de task estão dentro do intervalo:
   `81ef3e4` (T10), `e33b045` (T11), `b232ef8` (T12), `126638a` (T13),
   `3af5982` (T14), mais `e501a46` e `5dd1f85` (docs). **Nenhum commit de task
   ficou de fora.**
2. **`7e28f1c` (`fix(a11y): stop screen readers announcing each card three
   times`) foi commitado durante esta verificação**, por outro agente. Ele
   altera `_card_tile.html.erb`, `show.html.erb`, `application.html.erb` e os
   dois testes de integração (`alt=""`, `aria-hidden="true"`, `lang="pt-BR"`).
   **Não faz parte deste escopo e não foi verificado como task.** Ele não toca
   nenhum dos três arquivos que o sensor mutou. Efeito colateral registrado: a
   asserção de `alt` da T12 (`alt="Roronoa Zoro (OP01-001)"`) foi **substituída**
   por `alt=""` — mudança deliberada de decisão de acessibilidade, não
   regressão, mas significa que o critério "imagem com texto alternativo" da
   T12 já não vale como estava.
3. Durante a execução concorrente a suíte esteve transitoriamente vermelha (2
   falhas, `catalog_grid_test.rb:120` e `:130`). Ao fim do commit `7e28f1c` ela
   voltou a **180 runs, 0 falhas**.

---

## Task Completion

| Task | Status | Notas |
| ---- | ------ | ----- |
| T10 | ✅ Done | Query object completo; semântica OU/E provada por resultado |
| T11 | ✅ Done | `word_similarity` 0.5 e `UNION` confirmados contra o catálogo real |
| T12 | ⚠️ Done com desvio | `SPEC_DEVIATION` honesto: e2e → integração (sem navegador no container) |
| T13 | ✅ Done | p95 reproduzido; mede o cenário que o Req. 11.1 pede |
| T14 | ⚠️ Done com desvio | Mesmo `SPEC_DEVIATION` da T12 |

---

## Critérios "Done when" — verificação ancorada no spec

### T10 — Query object (Req. 4)

| Critério | Outcome definido no spec | Evidência `file:line` | Resultado |
| -------- | ------------------------ | --------------------- | --------- |
| OU dentro da categoria | Req. 4.4 — dois valores da mesma categoria unem por OU | `test/queries/catalog_query_test.rb:123` — `assert_equal ["OP01-002","OP01-003"], numbers(...colors: ["Green","Blue"])` | ✅ PASS |
| E entre categorias | Req. 4.3 — categorias distintas unem por E | `test/queries/catalog_query_test.rb:141` e `:149` — a ausência de `OP01-004` (Red event) é o que separa E de OU | ✅ PASS |
| Cor inclui multicoloridas | Req. 4.5 — Red/Blue entra no filtro de Red **e** no de Blue | `test/queries/catalog_query_test.rb:131` — `assert_includes vermelhas, "OP01-003"` + `assert_includes azuis, "OP01-003"` | ✅ PASS |
| Parâmetro inválido ignorado, nunca erro | Req. 4.7 / §4.2 — resultado válido, nunca 500 | `test/queries/catalog_query_test.rb:165`, `:171`, `:177`, `:184`; HTTP em `test/integration/catalog_grid_test.rb:282`, `:289` (`assert_response :success`) | ✅ PASS |
| `total_count` + filtros ativos normalizados | Req. 4.8 e 4.6 | `test/queries/catalog_query_test.rb:201` — `assert_equal 3, resultado.total_count` com `per_page: 1`; `:208` e `:217` para chips | ✅ PASS |
| Filtro isolado, 2 combinações, multicolor | — | `:62`–`:96` (seis filtros isolados), `:141`/`:149`/`:157` (combinações), `:131` (multicolor) | ✅ PASS |
| Faixas (Req. 4.2) | `counter` NULL ≠ 0 | `test/queries/catalog_query_test.rb:114` — `counter_min: 0` **não** arrasta `OP01-003` (counter NULL) | ✅ PASS |

### T11 — Busca textual (Req. 3)

| Critério | Outcome definido no spec | Evidência `file:line` | Resultado |
| -------- | ------------------------ | --------------------- | --------- |
| Insensível a caixa | Req. 3.2 | `test/queries/catalog_search_test.rb:66` | ✅ PASS |
| Insensível a acento, nos dois sentidos | Req. 3.2 | `test/queries/catalog_search_test.rb:71` — `Bell-mere` acha `Bell-mère` e vice-versa | ✅ PASS |
| Tolerante a typo | Req. 3.3 — typo de 1–2 caracteres acha a carta pretendida | `test/queries/catalog_search_test.rb:79` (`Zorro`→Zoro, `Namy`→Nami) e `:84` (`Belmere`→Bell-mère) | ✅ PASS |
| Busca no texto de efeito | Req. 3.1 | `test/queries/catalog_search_test.rb:90` e `:97` (stemming: `drawing`→`draw`) | ✅ PASS |
| Exato de `card_number` em primeiro, por consulta separada | Req. 3.4 | `test/queries/catalog_search_test.rb:124` — o decoy `OP01-000` **ordena antes** do exato; `assert_equal "OP01-001", resultado.first` só passa com prepend real | ✅ PASS |
| Combinável com todos os filtros | Req. 3.6 | `test/queries/catalog_search_test.rb:152`, `:158`, `:165`, `:172` | ✅ PASS |
| Sem full table scan | Req. 11.3 | `test/queries/catalog_search_test.rb:216` — EXPLAIN com 20k linhas semeadas assere os três índices e `refute_match(/Seq Scan on cards/)` | ✅ PASS |

### T12 — Grade (Req. 2, 3.5, 4.6, 4.7, 11.2)

| Critério | Outcome definido no spec | Evidência `file:line` | Resultado |
| -------- | ------------------------ | --------------------- | --------- |
| Imagem, nome e `card_number` | Req. 2.1 | `test/integration/catalog_grid_test.rb:44` | ✅ PASS |
| Paginação | Req. 2.2 | `test/integration/catalog_grid_test.rb:203` — páginas disjuntas (`assert_empty primeira & segunda`) | ✅ PASS |
| Lazy loading | Req. 11.2 | `test/integration/catalog_grid_test.rb:56` — toda `img.card-tile__image` com `loading="lazy"` | ✅ PASS |
| Placeholder com nome e código | Req. 2.3 | `test/integration/catalog_grid_test.rb:70`, `:84` (renderizado mesmo com imagem), `:95` (camada CSS) | ✅ PASS (ver *Placeholder* abaixo) |
| Estado vazio com termo e limpar | Req. 3.5 | `test/integration/catalog_grid_test.rb:187` — `.catalog__empty` com `/xyzqwkjhgf/` e link para `catalog_path` | ✅ PASS |
| Chips removíveis individualmente | Req. 4.6 | `test/integration/catalog_grid_test.rb:166` e `:192` — assere que remover Red preserva Green **e** vice-versa | ✅ PASS |
| Estado completo na URL | Req. 4.7 | `test/integration/catalog_grid_test.rb:144` (recarga reproduz) e `:215` (paginação preserva filtro) | ✅ PASS |
| 360px sem scroll horizontal | Req. 2.5 | `test/integration/catalog_grid_test.rb` (CSS: nenhuma declaração px > 360; `--tile-min` cabe 2x; `auto-fill`) + Chromium real (verificado pelo orquestrador) | ⚠️ Coberto por proxy — ver *Desvio* |
| Ordenação | Req. 2.4 | `test/integration/catalog_grid_test.rb:226`; unit em `catalog_query_test.rb:226` (asc **e** desc) | ✅ PASS |

### T13 — Latência (Req. 11.1)

| Critério | Outcome definido no spec | Evidência | Resultado |
| -------- | ------------------------ | --------- | --------- |
| p95 de busca + 3 filtros, catálogo completo | Req. 11.1 — p95 < 500 ms | `lib/tasks/benchmark.rake:148` — cenário `q: "Zorro", colors, card_types, cost_min/max` sobre 2815 cartas; **reproduzido por mim: p95 = 20,6 ms** (autor: 25,3 ms) | ✅ PASS |
| Resultado registrado | — | `.specs/features/catalogo/tasks.md` §T13, duas tabelas (query object e HTTP) | ✅ PASS |

**Verificação do ceticismo**: o cenário do Req. 11.1 é genuíno — busca textual
(`q`) **mais três categorias distintas** de filtro (cor, tipo, faixa de custo),
contra o catálogo completo (`Card.count` = 2815, impresso pela própria task).
Não é um caminho mais fácil. O aquecimento de 3 execuções descartadas é
metodologicamente correto (`benchmark.rake:173`). Ressalva menor: `p95 =
amostras[(reps*0.95).ceil - 1]` com 50 amostras pega o índice 47, que é o 48º
valor — aproximação aceitável, e o resultado está 20x abaixo do alvo, então
nenhuma escolha de interpolação muda o veredito.

### T14 — Detalhe (Req. 5)

| Critério | Outcome definido no spec | Evidência `file:line` | Resultado |
| -------- | ------------------------ | --------------------- | --------- |
| Todas as variantes, cada uma com raridade, set e imagem | Req. 5.2 | `test/integration/card_detail_test.rb:26` — 3 variantes, raridades L/SEC/C, sets Romance Dawn e Straw Hat Crew, três `img[src]` distintos | ✅ PASS |
| Quebras de linha de `effect_text` e `trigger_text` | Req. 5.4 | `test/integration/card_detail_test.rb:178` e `:195` — `assert_match(/<br/, html)` com texto multilinha explícito | ✅ PASS |
| Campos inaplicáveis omitidos, não vazios | Req. 5.5 | `test/integration/card_detail_test.rb:93` (Leader), `:107` (Event), `:122` (Stage), `:136` (Character sem counter) | ⚠️ **Lacuna** — ver M13 |
| Campos conhecidos + imagem maior | Req. 5.1 | `test/integration/card_detail_test.rb:232` | ✅ PASS |

---

## Verificação dos pontos de ceticismo

### `word_similarity` com limiar 0.5 — ✅ confirmado, bem calibrado

Medido por mim contra o catálogo real (2815 cartas), não contra fixture:

| Termo | Linhas casadas | Nomes distintos | Avaliação |
| ----- | -------------- | --------------- | --------- |
| `Zorro` | 42 | 5 | Roronoa Zoro (+ Parallel) e Zoro-Juurou — todos legítimos |
| `Namy` | 39 | 5 | Nami, O-Nami, Namule — plausível |
| `Luffi` | 94 | 10 | todos contêm "Luffy" |
| `Belmere` | 3 | 2 | Bell-mère |
| `Sanji` | 48 | 9 | — |

Nenhum falso positivo semanticamente absurdo, e nenhum resultado legítimo
cortado. **0.5 é o valor certo.** O limiar inferior é que não está travado —
ver M10.

### `UNION` no lugar de `OR` — ⚠️ a afirmação do design **não se sustenta mais**

`EXPLAIN` contra o catálogo real, com o schema atual:

```
UNION → Append + 3 Bitmap Index Scan (nome trgm, effect tsvector, card_number trgm)
OR    → Bitmap Heap Scan + BitmapOr dos MESMOS 3 índices     ← também indexado
```

As três ramificações usam índice no `UNION`, como o autor afirma — **isso
confere**. Mas a justificativa de §4.1.2 ("uma ramificação inindexável derruba o
plano do predicado inteiro") descreve o estado **anterior** à migração
`20260919120300`. Reproduzi a condição original derrubando o índice novo dentro
de uma transação com `ROLLBACK`:

```
OR sem index_cards_on_card_number_trgm → Seq Scan on cards (cost=0.00..1599.76)
OR com o índice                        → BitmapOr, sem Seq Scan
```

**A causa do Seq Scan era o índice ausente, não o `OR`.** Uma vez criado o
índice, `OR` planeja tão bem quanto `UNION`. O `UNION` não é errado (deduplica e
o plano é equivalente), mas §4.1.2 atribui a ele um efeito que pertence à
migração. Isso torna M8 um mutante **equivalente**, não uma lacuna — e é o que
explica o design.md descrever duas correções "as duas necessárias" quando só
uma delas é que resolve o plano.

### Migração `20260919120300` — ✅ aditiva, confirmado

`git diff 22612fe..5dd1f85 -- db/structure.sql` traz exatamente duas adições:
um `CREATE INDEX index_cards_on_card_number_trgm ... USING gin (card_number
public.gin_trgm_ops)` e a linha `('20260919120300')` em `schema_migrations`.
**Nenhuma tabela, coluna ou constraint do schema verificado na Fase 2 foi
tocada.** O índice único btree `index_cards_on_card_number` continua presente e
é o que atende o match exato.

### T13 p95 — ✅ reproduzido, mede o que o Req. 11.1 pede

Ver tabela da T13 acima. p95 = 20,6 ms na minha execução.

### T12/T14 como integração em vez de e2e — ✅ desvio honesto, lacuna real e nomeada

O `SPEC_DEVIATION` está registrado em `tasks.md` §T12 e §T14, e em `STATE.md`.
Confirmei a causa: não há binário de navegador no container. O que **fica
descoberto sem navegador**, e está corretamente nomeado pelo autor:

- Comportamento de renderização em viewport real (coberto por proxy de CSS +
  verificação manual em Chromium, já feita pelo orquestrador).
- O placeholder aparecendo quando o **hotlink quebra de verdade** (e não só
  quando `image_url` é NULL).

O desvio **não** esconde critério não atendido — todos os "Done when" da T12 e
da T14 têm asserção correspondente no HTML renderizado ou no CSS. O custo real é
que a regressão de layout só seria pega por inspeção manual.

### Placeholder por CSS, sem JS — ✅ mecanismo correto, cobertura parcial

O mecanismo é sólido e melhor que `onerror`: `.card-tile__art { position:
relative }` com imagem e placeholder ambos `position: absolute; inset: 0`
(`app/assets/stylesheets/catalog.css:102-119`). O placeholder é renderizado
**sempre**, por baixo; imagem ausente ou quebrada simplesmente não pinta nada
por cima. Não depende de script.

Os testes cobrem: placeholder presente com `image_url` NULL
(`catalog_grid_test.rb:70`), presente **mesmo havendo** `image_url` (`:84`), e a
camada CSS (`:95`). O que **nenhum teste cobre** é a falha real do hotlink em
navegador — mas, ao contrário de um `onerror`, aqui não há código a executar: se
o markup e o CSS estão certos, o comportamento decorre. Risco baixo.

**Observação**: o comentário de cabeçalho de `test/integration/catalog_grid_test.rb:11-12`
ainda fala em "execução do `onerror` da imagem", vocabulário da solução
descartada. Cosmético, mas induz a erro quem ler o teste.

### `owned` fora do query object — ⚠️ registrado, mas só em um lugar

A ausência está registrada em `.specs/STATE.md:55` ("é onde o parâmetro `owned`
do `design.md` §4.2 entra — ele foi deixado **fora** do query object de
propósito, por depender de sessão"). **Não** há menção em `tasks.md` §T10 nem
comentário em `catalog_query.rb`, que é onde quem for implementar vai olhar.

Quanto a aceitar o filtro depois sem reescrita: **sim**. `owned` hoje cai no
saneador genérico e é ignorado (`normalize_keys` + ausência de entrada nos
hashes de filtro), então nenhuma URL com `owned` quebra. Adicioná-lo é
acrescentar um predicado ao lado de `apply_variant_filters`, no mesmo formato
dos existentes. A estrutura `reduce`-por-categoria comporta isso sem
reorganização. Ressalva: `owned` opera sobre **variantes do usuário**, e o
escopo base é `Card.all` — vai precisar de um `EXISTS` como `VARIANT_FILTERS` já
faz, não de uma coluna. Está dentro do padrão existente.

---

## Sensor de Discriminação

**Isolamento**: mutação in-place com restauração a partir de cópia pristina
extraída de `git show 5dd1f85:<arquivo>`, verificada por `cmp` após cada rodada.
**Nunca `git stash`**. Um worktree temporário foi criado e descartado ao
descobrir-se que `/tmp` não está no mount do container; a alternativa por cópia
de arquivo foi usada em seu lugar. Os três alvos (`catalog_query.rb`,
`catalog_helper.rb`, `card.rb`) **não são tocados** pelo commit concorrente
`7e28f1c`, então não houve colisão. Todos verificados idênticos ao HEAD ao fim.

| # | Mutante | `file:line` | Resultado |
| - | ------- | ----------- | --------- |
| M1 | `E` entre categorias → `OU` (`current.where(...)` → `current.or(Card.where(...))`) | `app/queries/catalog_query.rb:260` | ✅ Morto (3 falhas) |
| M2 | Cor exclui multicoloridas (`&&` → `=` em array) | `app/queries/catalog_query.rb:250` | ✅ Morto (5 falhas) |
| M3 | `per_page` sem teto (`value.clamp(1, MAX_PER_PAGE)` → `value`) | `app/queries/catalog_query.rb:323` | ✅ Morto |
| M4 | `total_count` conta a página (`scope.count` → `[scope.count, per_page].min`) | `app/queries/catalog_query.rb:137` | ✅ Morto |
| M5 | Parâmetro inválido vira 500 (remove `rescue ArgumentError, TypeError`) | `app/queries/catalog_query.rb:343` | ✅ Morto (3 erros) |
| M6 | `dir` ignorado (sempre `asc`) | `app/queries/catalog_query.rb:299` | ✅ Morto |
| M7 | `immutable_unaccent` → `unaccent` (mesmo resultado, perde índice) | `app/queries/catalog_query.rb:205` | ✅ Morto (teste de plano) |
| M8 | `UNION` → `OR` nas três ramificações | `app/queries/catalog_query.rb:204-210` | ⚪ **Equivalente** — ver acima: com o índice novo, `OR` também usa os 3 índices |
| M9 | Limiar `word_similarity` 0.5 → 0.9 (corta typo legítimo) | `app/queries/catalog_query.rb:60` | ✅ Morto (5 falhas) |
| M10 | Limiar `word_similarity` 0.5 → 0.1 (inunda de falso positivo) | `app/queries/catalog_query.rb:60` | ❌ **SOBREVIVEU** |
| M11 | Off-by-one no offset do prepend (`- 1` removido) | `app/queries/catalog_query.rb:158` | ⚪ Equivalente — mas **expôs o defeito D1** (ver abaixo) |
| M12 | Chip remove tudo em vez de só a si mesmo (`remaining.except(:page)` → `remaining.slice(:sort, :dir)`) | `app/helpers/catalog_helper.rb:72` | ✅ Morto (3 falhas) |
| M13 | Aplicabilidade por tipo ignorada (remove `return false unless field_applicable?`) | `app/models/card.rb:118` | ❌ **SOBREVIVEU** |
| M14 | `counter` NULL vira 0 (`!value.nil?` → `true`) | `app/models/card.rb:121` | ✅ Morto |
| M16 | Prepend removido (`exact = exact_card_number_match(scope)` → `exact = nil`) | `app/queries/catalog_query.rb:132` | ✅ Morto (5 falhas) |
| M17 | Match exato case-sensitive (remove `.upcase`) | `app/queries/catalog_query.rb:226` | ✅ Morto |

**Sensor depth**: 16 mutantes novos (além dos 2 obrigatórios do plano, ambos
mortos). 12 mortos, 2 equivalentes, **2 sobreviventes reais**.

**Nota**: o mutante "remover a transação explícita de `CatalogQuery#call`" não
foi repetido — o orquestrador já o confirmou morto (`SemTransacaoTest`).
`simple_format` não foi mutado porque `show.html.erb` estava sob edição
concorrente; o critério tem asserção direta em `card_detail_test.rb:178`.

---

## Achados

### D1 — DEFEITO REAL: o match exato é prependido em **todas** as páginas (Major)

**Não é mutante — é comportamento do HEAD.** `app/queries/catalog_query.rb:154-159`:

```ruby
def page_records(scope, exact, page, per_page)
  return paginate(ordered(scope), page, per_page).to_a unless exact
  return [ exact ] + ordered(scope).limit(per_page - 1).to_a if page == 1

  [ exact ] + ordered(scope).limit(per_page).offset((page - 1) * per_page - 1).to_a.last(per_page)
end
```

O ramo de `page > 1` **também** prepende `exact`. Reproduzido no banco de teste
com um termo que é exato e casa outras 9 cartas por substring, `per_page = 3`:

```
p1: tamanho=3  ["ZZT-005", "ZZT-0051", "ZZT-0052"]
p2: tamanho=4  ["ZZT-005", "ZZT-0053", "ZZT-0054", "ZZT-0055"]   ← 4 > per_page
p3: tamanho=4  ["ZZT-005", "ZZT-0056", "ZZT-0057", "ZZT-0058"]   ← 4 > per_page
p4: tamanho=2  ["ZZT-005", "ZZT-0059"]
```

Consequências: (a) a página devolve **mais itens que `per_page`**; (b) a carta
exata **se repete em todas as páginas**, contradizendo o comentário do próprio
código em `:133-134` ("o exato sai do conjunto paginado para não aparecer duas
vezes"); (c) `total_count` = 10 com `per_page` = 3 promete 4 páginas de ≤3, e a
soma dos tamanhos é 13. Nenhuma carta é perdida nem duplicada *dentro* da mesma
página, o que é por que a suíte não percebe.

**Por que nenhum teste pega**: o único teste de paginação com prepend é
`catalog_search_test.rb:144`, que usa `per_page: 1` e **só olha a página 1**.
`catalog_grid_test.rb:203` testa paginação, mas **sem termo de busca**, então
`exact` é `nil` e o ramo defeituoso nunca executa. Falta um teste que combine
match exato + `per_page` pequeno + página ≥ 2.

Severidade **Major**: viola o contrato de `per_page` de `design.md` §4.2 e é
visível ao usuário (a mesma carta reaparece ao paginar uma busca por código).
Não é Blocker porque nenhum dado se perde e o caso exige busca por
`card_number` exato com muitos outros resultados.

### D2 — LACUNA: limiar inferior de `word_similarity` sem teste (Minor)

M10 sobreviveu: baixar o limiar de `0.5` para `0.1`
(`app/queries/catalog_query.rb:60`) não derruba nenhum dos 180 testes. Medido
contra o catálogo real, o estrago é concreto:

| Termo | linhas @ 0.5 | @ 0.3 | @ 0.1 |
| ----- | ------------ | ----- | ----- |
| `Zorro` | 42 | 46 | 113 |
| `Nami` | 39 | 48 | 205 |

Buscar "Nami" devolveria **205 cartas em vez de 39** — 5x de ruído — e a suíte
continuaria verde. Todos os testes de busca usam `assert_includes`, que só
verifica presença; nenhum verifica **ausência de resultado irrelevante** nem
põe teto no tamanho do resultado. O limiar superior está travado (M9 morreu por
5 asserções); o inferior não tem nada.

Correção sugerida (uma asserção): num termo como `Zorro`, exigir que uma carta
sem parentesco (ex.: `Nami`) **não** apareça, ou que o resultado não ultrapasse
um teto plausível.

### D3 — LACUNA: `field_applicable?` não é exercitado de forma independente (Minor)

M13 sobreviveu: remover `return false unless field_applicable?(field)` de
`app/models/card.rb:118` não derruba nenhum teste de detalhe.

A causa é que **toda** fixture da T14 dá `nil` aos campos inaplicáveis — o
Leader de `card_detail_test.rb:93` tem `cost: nil, counter: nil`, o Event de
`:107` tem `power: nil, life: nil, counter: nil`. Com o valor ausente, "não se
aplica" e "não tem valor" produzem o mesmo resultado, e só o segundo está sendo
testado. Provei a diferença criando um Leader com `cost: 4, counter: 1000`:

```
HEAD     display_field?(:cost) = false   (correto, Req. 5.5)
MUTANTE  display_field?(:cost) = true    (viola Req. 5.5)
```

Isto é exatamente a distinção que a própria nota da T14 diz ser deliberada — "o
dia em que a fonte entregar counter num Event passar despercebido" — e é o caso
que não tem teste. A T14 afirma que o mutante "ignorar aplicabilidade por tipo"
foi morto; **não foi**, com os dados que a suíte usa.

Correção sugerida: um teste com carta de tipo `leader` carregando `cost` e
`counter` preenchidos, asserindo `.field--cost` ausente.

---

## Code Quality

| Princípio | Status |
| --------- | ------ |
| Código mínimo | ✅ |
| Mudanças cirúrgicas | ✅ |
| Sem scope creep | ✅ |
| Segue padrões existentes | ✅ |
| Outcome ancorado no spec | ✅ (2 lacunas nomeadas) |
| Cobertura por camada | ⚠️ domínio quase 1:1; falta o caso de D1 e D3 |
| Todo teste mapeia a requisito | ✅ — cada bloco cita `Req. N.N` |
| Diretrizes documentadas seguidas | ✅ `CLAUDE.md` + `.context/design.md` §4 |

Observações de qualidade, nenhuma bloqueante:

- `catalog_query.rb` tem 346 linhas, das quais boa parte é comentário
  explicando *por que* — apropriado, dado que várias decisões (limiar, `UNION`,
  transação) são contraintuitivas e foram pagas caro.
- `search_match_sql` e `exact_match_sql` são públicos só para o teste de plano.
  Está documentado no código (`:110`, `:120`). Aceitável.
- `catalog_helper.rb:67` — `rest.empty? ? remaining.delete(key) : remaining[key] = rest`
  funciona, mas a atribuição dentro de ternário é frágil de ler. Cosmético.
- Comentário obsoleto em `test/integration/catalog_grid_test.rb:11-12` (fala de
  `onerror`, solução que não foi adotada).
- `design.md` §4.1.2 atribui ao `OR` um efeito que pertence ao índice ausente
  (ver ceticismo). Vale corrigir o parágrafo, pela mesma regra que o próprio
  projeto aplica: requisito/design errado se corrige no documento.

---

## Edge Cases

- [x] Mesma variante em dois sets — coberto na Fase 2 (fora deste lote)
- [x] Raridade/attribute desconhecido persistido como texto — Fase 2
- [x] `counter` NULL ≠ 0 — `catalog_query_test.rb:114` (filtro) e `card_detail_test.rb:136` (tela)
- [x] `traits` com variação de caixa — Fase 2
- [x] Termo de busca com SQL injection — `catalog_search_test.rb:205`
- [x] `sort` com SQL injection — `catalog_query_test.rb:177`
- [x] Página além da última devolve vazio sem erro — verificado (`page=9999` → 0 registros, sem exceção)
- [ ] **Match exato + paginação além da página 1** — D1, não coberto

---

## Gate Check

- **Comando**: `docker compose exec -T app bin/rails test` (full) + `bin/rubocop`
- **No escopo designado (`5dd1f85`)**: **176 runs, 500 assertions, 0 falhas, 0 erros, 0 skips**; RuboCop **54 arquivos, 0 offenses**
- **No HEAD atual (`7e28f1c`, com o commit concorrente de a11y)**: **180 runs, 506 assertions, 0 falhas**
- **Benchmark**: `bin/rails catalog:benchmark` — todos os 6 cenários `OK`, pior p95 = 20,6 ms contra alvo de 500 ms
- **Delta de testes no lote B2**: +92 (84 ao fim da Fase 2 → 176)
- **Skips**: nenhum

---

## Requirement Traceability Update

| Requirement | Status anterior | Novo status |
| ----------- | --------------- | ----------- |
| CAT-02 (Navegação) | Implementing | ✅ Verified |
| CAT-03 (Busca) | Implementing | ✅ Verified, com D2 |
| CAT-04 (Filtros) | Implementing | ✅ Verified, com D1 |
| CAT-05 (Detalhe) | Implementing | ✅ Verified, com D3 |

---

## Fix Plans

### Fix 1 (D1) — prepend só na página 1

- **Root cause**: `app/queries/catalog_query.rb:158` prepende `exact` em toda
  página; só a página 1 deveria recebê-lo.
- **Fix**: no ramo `page > 1`, devolver apenas
  `ordered(scope).limit(per_page).offset((page - 1) * per_page - 1)`, sem
  `[ exact ] +` e sem `.last(per_page)`.
- **Teste**: termo exato com ≥ 2 páginas de resultado e `per_page` pequeno;
  asserir `records.size <= per_page` em toda página e que o exato aparece uma
  única vez no conjunto de todas as páginas.
- **Prioridade**: Major

### Fix 2 (D2) — travar o limiar inferior da busca

- **Root cause**: nenhum teste assere ausência de resultado irrelevante.
- **Fix**: asserção em `test/queries/catalog_search_test.rb` — buscar `Zorro` e
  `refute_includes` uma carta sem parentesco.
- **Prioridade**: Minor

### Fix 3 (D3) — exercitar `field_applicable?` isolado de "tem valor"

- **Root cause**: todas as fixtures dão `nil` ao campo inaplicável.
- **Fix**: teste com `card_type: "leader"` e `cost: 4, counter: 1000`
  preenchidos, asserindo `.field--cost` e `.field--counter` ausentes.
- **Prioridade**: Minor

### Fix 4 (cosmético) — documentação

- `design.md` §4.1.2: separar "o `OR` caía em Seq Scan **porque faltava o
  índice em `card_number`**" de "portanto usamos `UNION`".
- `test/integration/catalog_grid_test.rb:11-12`: remover a menção a `onerror`.
- Registrar a ausência de `owned` em `tasks.md` §T10 ou como comentário em
  `catalog_query.rb`, não só em `STATE.md`.

---

## Summary

**Overall**: ✅ **PASS** — a Fase 3 entrega o que o spec pede.

**Spec-anchored check**: todos os critérios "Done when" de T10–T14 têm teste com
evidência `file:line`; 2 deles (Req. 5.5 e o limiar da busca) passam por motivo
mais fraco do que aparentam, o que está registrado como D2 e D3.

**Sensor**: 16 mutantes novos — 12 mortos, 2 equivalentes, 2 sobreviventes.
Os dois mutantes obrigatórios do plano (`OU`/`E` invertido, multicolor excluída)
morreram com folga.

**Gate**: 180 testes, 0 falhas; RuboCop limpo; benchmark 20x abaixo do alvo.

**O que está sólido**: a semântica de filtro é testada por *resultado*, não por
SQL, e os testes escolhem os casos que separam a regra certa da errada — o decoy
que ordena antes do exato (`catalog_search_test.rb:124`) e a ausência do Red
event no teste de E (`catalog_query_test.rb:141`) são exemplos de teste que
discrimina de verdade. Os três defeitos que só afetam latência
(`immutable_unaccent`, índice do match exato, plano das ramificações) têm teste
de plano de execução, o que é raro e correto. O `SPEC_DEVIATION` de T12/T14 é
honesto e nomeia com precisão o que fica descoberto.

**O que encontrei**: um defeito real de paginação que a suíte não podia ver
(D1), duas lacunas onde o teste passa por motivo mais fraco que o critério (D2,
D3), e uma afirmação de design que a evidência não sustenta mais (`UNION` vs
`OR`).

**Próximo passo**: os três fixes são pequenos e independentes. D1 é o único que
muda comportamento; D2 e D3 são asserções novas. Nenhum bloqueia a Fase 4.

---

## Adendo pós-validação (2026-09-22)

O "risco baixo" da seção *Placeholder por CSS* estava errado no fato, não no
raciocínio: o mecanismo funciona, e por isso **escondeu** que nenhuma imagem
jamais carregou. A fonte responde `Cross-Origin-Resource-Policy: same-site`; o
navegador descarta toda imagem hotlinkada e o placeholder aparece em 100% das
cartas. Os PASS do Req. 2.1 (imagem na grade) e 5.2 (imagem por variante) valem
para o HTML renderizado, não para o que o usuário vê. Correção: AD-012,
`.context/tasks.md` §3.6. Este relatório não é reescrito — o adendo é o registro.
