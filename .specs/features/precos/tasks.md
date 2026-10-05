# Preços — Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Design**: `.specs/features/precos/design.md`
**Status**: Draft

---

## Test Coverage Matrix

> Generated from codebase, project guidelines, and spec - confirm before Execute. Guidelines found: `CLAUDE.md` (gates da `fonte-apitcg`; "toda task termina com código que roda e teste que passa"; sem navegador no container, logo UI vira integração sobre HTML renderizado), `.context/requirements.md` Req. 11.4 e 11.5 (coleção e ingestão com teste automatizado), AD-009 (relógio injetado), AD-021 (contagem de consultas da pasta).

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| ---------- | ------------------ | -------------------- | ---------------- | ----------- |
| Schema / constraint (`card_variants`) | unit (model) | Cada `CHECK` violada levanta `ActiveRecord::StatementInvalid`; estado válido grava | `test/models/card_variant_price_test.rb` | `bin/rails test test/models` |
| Ingestão (Normalize, Upsert) | unit | 1:1 com PRC-01..07 e os edge cases de `market` (ausente, nulo, string, negativo, zero, `printings`) | `test/services/ingestion/**/*_test.rb` | `bin/rails test test/services` |
| Helper de formatação | unit | Valor, separadores, zero, moeda sem unidade, data em `America/Sao_Paulo` | `test/helpers/prices_helper_test.rb` | `bin/rails test test/helpers` |
| Model de coleção (agregação) | unit | PRC-11..16: total, sem preço, subtotal por set, isolamento, zero, ausente incluída | `test/models/collection_item_test.rb` | `bin/rails test test/models` |
| Telas (detalhe, pasta) | integration | Sem sessão e com sessão; preço e "Sem preço"; total, subtotal, "N cópias sem preço"; contagem de consultas da AD-021 | `test/integration/*_test.rb`, `test/queries/set_progress_plan_test.rb` | `bin/rails test test/integration test/queries` |
| Docs | none | - | - | build gate only |

## Gate Check Commands

> Generated from codebase - confirm before Execute. O `app` não sobe com `docker compose up` enquanto outro processo ocupar a porta 3000 no host; nesse caso troque `exec app` por `run --rm app` (sobe o `db` como dependência).

| Gate Level | When to Use | Command |
| ---------- | ----------- | ------- |
| Quick | Tasks com teste de unidade | `docker compose exec app bin/rails test test/models test/queries test/services test/helpers` |
| Full | Tasks com teste de integração | `docker compose exec app bin/rails test && docker compose exec app bin/rubocop` |
| Build | Fim de phase e task de verificação | `docker compose build && docker compose exec app bin/rails test && docker compose exec app bin/rubocop && docker compose exec app bin/brakeman -q --no-pager && python3 spec/verify_fixture.py` |

---

## Execution Plan

Phases are ordered and run sequentially - each phase completes before the next begins, and tasks within a phase execute in order.

### Phase 1: Dado e ingestão

```
T1 → T3
T2 → T3
```

### Phase 2: Leitura e telas

```
T4 → T5
T4 → T7
T6 → T7
```

### Phase 3: Fechamento

```
T8
```

---

## Task Breakdown

### T1: Colunas de preço em `card_variants`

**What**: Migração com `price_amount numeric(10,2)`, `price_currency text`, `price_observed_at timestamp`, as duas `CHECK` do design; `db/structure.sql` regenerado. `CardVariant#priced?` foi para a T5, onde é usado pela primeira vez.
**Where**: `db/migrate/20261005120000_add_price_to_card_variants.rb`
**Depends on**: None
**Reuses**: padrão de `card_variants_art_kind_check`
**Requirement**: PRC-05

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Teste prova que valor sem moeda, valor sem data, moeda sem valor e valor negativo são recusados pelo banco, e que os três nulos e os três preenchidos gravam
- [x] `db/structure.sql` contém as duas `CHECK`
- [x] Gate check passes: quick
- [x] Test count: suíte anterior (1751) + novos, sem remoção

**Tests**: unit
**Gate**: quick

**Commit**: `feat(precos): adicionar colunas de preço às variantes`

---

### T2: Preço no Normalize

**What**: `NormalizedVariant` ganha `price_amount` e `price_currency`; `extract_price` lê só `markets.tcgplayer.prices.market`.
**Where**: `app/services/ingestion/apitcg/normalize.rb`
**Depends on**: None
**Reuses**: `normalize_variant`, `to_integer`/`presence` como estilo
**Requirement**: PRC-02, PRC-03, PRC-06

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] A fixture dá `BigDecimal("1.7")` e `"USD"` para `tcgplayer:541058`
- [x] `market` ausente, nulo, string (`"1.70"`), negativo e não finito dão `nil, nil`; `0` dá `BigDecimal("0")`, `"USD"`
- [x] Produto com `printings` de preços diferentes usa o `prices` de topo
- [x] Nenhum outro arquivo de `app/` lê `markets` (busca por `"markets"` fora do Normalize volta vazia)
- [x] Gate check passes: quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(precos): extrair o preço market no Normalize`

---

### T3: Preço no Upsert

**What**: `upsert_variant` grava valor, moeda e `price_observed_at = @started_at`, ou os três nulos.
**Where**: `app/services/ingestion/upsert.rb`
**Depends on**: T1, T2
**Reuses**: `clock:` do `Upsert` (AD-009), `apply` e `error_log`
**Requirement**: PRC-01, PRC-02, PRC-04, PRC-07

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Com relógio fixo, a variante recebe valor, `USD` e a data igual a `import_runs.started_at`
- [x] Segundo import em que o produto perdeu `market` deixa os três nulos
- [x] Variante ausente do segundo snapshot mantém valor, moeda e data do primeiro
- [x] Mesmo snapshot duas vezes: mesmos valores e moedas, e `collection_items.quantity` intacta (estende o teste de garantias da task 2.6)
- [x] Gate check passes: quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(precos): gravar o preço da variante no Upsert`

---

### T4: `PricesHelper`

**What**: `format_price(amount, currency)` e `price_label(variant)`.
**Where**: `app/helpers/prices_helper.rb`
**Depends on**: None
**Reuses**: `number_to_currency` do Rails
**Requirement**: PRC-08, PRC-11, PRC-15

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] `1234.56 USD` → `US$ 1.234,56`; `0` → `US$ 0,00`; `1.7` → `US$ 1,70`; moeda sem unidade cai no código ISO
- [x] `price_label` de uma variante observada em `2026-10-06 01:30 UTC` mostra `05/10/2026` (`America/Sao_Paulo`)
- [x] Gate check passes: quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(precos): formatar preço e rótulo da cotação`

---

### T5: Preço no detalhe da carta

**What**: Par `dt` "Preço" / `dd` em cada variante de `catalog/show`, com valor e rótulo ou "Sem preço".
**Where**: `app/views/catalog/show.html.erb`
**Depends on**: T4
**Reuses**: `.variant__meta`, `PricesHelper`
**Requirement**: PRC-08, PRC-09, PRC-10

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Sem sessão, uma variante com preço mostra `US$ 1,70` e `TCGplayer · market · <data>`, e outra mostra "Sem preço"
- [x] Variante ausente da fonte com preço antigo mostra o valor e a data dele
- [x] O detalhe não ganha consulta (contagem de consultas antes e depois igual no teste)
- [x] Guardas de 360px existentes continuam verdes
- [x] Gate check passes: full

**Tests**: integration
**Gate**: full

**Commit**: `feat(precos): mostrar o preço de cada variante no detalhe`

---

### T6: Valor da coleção em `collection_stats_for`

**What**: A consulta dos indicadores agrupa por `card_variants.set_id` e devolve também `estimated_value`, `unpriced_copies` e `value_by_set_id`.
**Where**: `app/models/collection_item.rb`
**Depends on**: None
**Reuses**: `for_user(user).owned`, testes existentes de `collection_stats_for`
**Requirement**: PRC-11, PRC-12, PRC-13, PRC-14, PRC-15, PRC-16

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Cenário do Independent Test do spec: `15.10`, 2 sem preço, `5.10` no set A e `10.00` no set B
- [x] Soma dos subtotais igual ao total, com uma cópia de variante ausente da fonte incluída
- [x] Outro usuário não altera os números; usuário sem itens e `nil` dão `0` e `{}`
- [x] Os seis testes atuais de `collection_stats_for` passam sem edição
- [x] Uma única consulta SQL por chamada
- [x] Gate check passes: quick

**Tests**: unit
**Gate**: quick

**Commit**: `feat(precos): calcular o valor da coleção por set`

---

### T7: Valor estimado na pasta

**What**: Terceiro `.progress__stat` com o valor estimado, "N cópias sem preço" quando houver, e subtotal em cada `.progress-set`.
**Where**: `app/views/progress/index.html.erb`
**Depends on**: T4, T6
**Reuses**: `.progress__stat`, `stats` já carregado na view, `PricesHelper`
**Requirement**: PRC-11, PRC-12, PRC-13, PRC-14, PRC-15, PRC-16

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [ ] Integração: total, "2 cópias sem preço" e subtotais aparecem para o dono; outro usuário logado vê os próprios números
- [ ] Sem cópia com preço: `US$ 0,00` e nenhum texto "cópias sem preço"
- [ ] `test/queries/set_progress_plan_test.rb` passa **sem edição** (3 consultas, AD-021)
- [ ] Guardas de 360px existentes continuam verdes
- [ ] Gate check passes: full

**Tests**: integration
**Gate**: full

**Commit**: `feat(precos): mostrar o valor estimado na pasta`

---

### T8: Fechamento com o snapshot real

**What**: Importar `storage/ingestion/apitcg-20261001T231649Z.json` no banco de dev, conferir a cobertura, capturar detalhe e pasta (AD-015) e registrar o resultado.
**Where**: `.specs/features/precos/tasks.md`
**Depends on**: None
**Reuses**: `ingestion:import SNAPSHOT=`, `spec/visual/capture.cjs`
**Requirement**: PRC-01, PRC-08, PRC-11

**Tools**:

- MCP: `playwright`
- Skill: NONE

**Done when**:

- [ ] Pelo menos 6.900 variantes com preço após o import (Success Criteria)
- [ ] Capturas de detalhe e pasta em 390px e 1280px sem scroll horizontal, conferidas contra o canvas
- [ ] Gate check passes: build
- [ ] `.context/tasks.md` §10 e este plano marcados

**Tests**: none
**Gate**: build

**Commit**: `docs(precos): registrar o import real e as capturas`

---

## Phase Execution Map

```
Phase 1 → Phase 2 → Phase 3

Phase 1:  T1, T2, depois T3 (depende de T1 e T2)
Phase 2:  T4, T5 (depende de T4), T6, depois T7 (depende de T4 e T6)
Phase 3:  T8
```

Oito tasks, um lote só: execução inline, sem sub-agentes de lote. O Verifier roda depois da T8.

## Plano de delegação

Revisão pelos agentes agnósticos de linguagem (não há revisor de Ruby): `ecc:database-reviewer` na T1 (constraints) e na T6 (consulta agregada); `ecc:silent-failure-hunter` na T2 e T3 (preço inválido vira "Sem preço" sem erro, e isso precisa ser a decisão, não um engolir de exceção); `ecc:a11y-architect` na T5 e T7. O Verifier roda depois da T8.

---

## Task Granularity Check

| Task | Scope | Status |
|---|---|---|
| T1: colunas e constraints | 1 migração (+ `structure.sql` gerado, 1 método no model) | ✅ Granular |
| T2: `extract_price` | 1 função + 2 campos de struct | ✅ Granular |
| T3: `upsert_variant` | 1 função | ✅ Granular |
| T4: `PricesHelper` | 2 funções coesas, 1 arquivo | ✅ Granular |
| T5: detalhe | 1 view | ✅ Granular |
| T6: `collection_stats_for` | 1 função | ✅ Granular |
| T7: pasta | 1 view | ✅ Granular |
| T8: fechamento | verificação + registro | ✅ Granular |

## Diagram-Definition Cross-Check

| Task | Depends On (task body) | Diagram Shows | Status |
|---|---|---|---|
| T1 | None | — | ✅ Match |
| T2 | None | — | ✅ Match |
| T3 | T1, T2 | T1 → T3, T2 → T3 | ✅ Match |
| T4 | None | — | ✅ Match |
| T5 | T4 | T4 → T5 | ✅ Match |
| T6 | None (T1 em phase anterior) | — | ✅ Match |
| T7 | T4, T6 | T4 → T7, T6 → T7 | ✅ Match |
| T8 | None (phases anteriores) | — | ✅ Match |

## Test Co-location Validation

| Task | Code Layer Created/Modified | Matrix Requires | Task Says | Status |
|---|---|---|---|---|
| T1 | Schema / constraint | unit | unit | ✅ OK |
| T2 | Ingestão | unit | unit | ✅ OK |
| T3 | Ingestão | unit | unit | ✅ OK |
| T4 | Helper | unit | unit | ✅ OK |
| T5 | Tela | integration | integration | ✅ OK |
| T6 | Model de coleção | unit | unit | ✅ OK |
| T7 | Tela | integration | integration | ✅ OK |
| T8 | Docs / verificação | none | none | ✅ OK |
