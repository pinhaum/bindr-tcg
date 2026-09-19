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
