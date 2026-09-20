# Estado da execução — feature `portabilidade`

> Documento de retomada do orquestrador. Atualizado a cada fase.
> **Última atualização**: 2026-09-20, durante a T3.

## Onde estamos

**Fase 1 (suíte determinística) — T1 e T2 fechadas, T3 em curso.**

| Task | Commit | Estado |
|---|---|---|
| T1 | `8062fa3` | ✅ fechada, checkboxes marcados |
| T2 | `4efc35c` | ✅ fechada, checkboxes marcados |
| T3 | — | 🔄 doze execuções da suíte, **10 de 12 verdes** até agora |
| T4–T17 | — | ⬜ não iniciadas |

HEAD antes da feature: `cb92c65`. Branch `main`. Nenhum push (proibido).

## As duas causas-raiz da Fase 1 (medidas; os diagnósticos da spec estavam ERRADOS)

**T1 — `guarantees_test.rb`**: o **relógio de parede do host anda para trás**
(ressincronização do WSL2). Medido: `Time.now` deu 4 saltos de ±11,25s em 2000
leituras, enquanto `CLOCK_MONOTONIC` avançou 0,005s. A execução que falhou gravou
`ImportRun` com `finished_at` **5,3s anterior ao próprio `started_at`**.
A spec culpava truncamento por `to_i` — truncamento não inverte ordem.
**Correção**: relógio monotônico injetado pelo parâmetro `clock:` que
`Ingestion::Upsert#initialize` já expunha. Asserção `:>` estrita INTACTA.

**T2 — `catalog_search_test.rb`**: a **pending list do GIN**. Os três índices da
busca são GIN com `fastupdate`; o custo de varrer a lista pendente entra na conta
do planejador. Medido: custo do mesmo índice sobre os mesmos dados variou
34.31→1292.31 em 8 seeds idênticos **com estatística válida em todos**; drenando,
34.31 constante. As duas hipóteses do orquestrador (ANALYZE não enxergar linhas
não-commitadas; `SemTransacaoTest` corromper estatística) foram **falsificadas
com medição** pelo subagente.
**Correção**: `gin_clean_pending_list` nos três índices antes do `ANALYZE`, mais
guarda `assert_operator` sobre `pg_stats > 0` (e **não** sobre `reltuples`, que
não é transacional e fica verde por resíduo). As 6 asserções de plano seguem
**byte a byte idênticas** — verificado pelo orquestrador por diff isolado.

## Decisões registradas nesta execução

- **AD-009** e **AD-010** foram acrescentadas a `.specs/STATE.md`:
  - AD-009: o padrão de correção das duas famílias de flake (ordem de tempo →
    relógio monotônico; plano com GIN → drenar pending list + guarda `pg_stats`).
    Registra que corrigimos o **teste**, não o **host**: o relógio do WSL2 segue
    saltando, e se `last_seen_at` virar requisito de produto a inversão reaparece
    nos dados reais.
  - AD-010: os deadlocks `PG::TRDeadlockDetected` sob paralelismo são
    **pré-existentes** (origem: `teardown` de `SemTransacaoTest`,
    `catalog_search_test.rb:418-420`, três `delete_all` fora de transação).
    **Consequência operacional: toda medição de suíte roda EM SÉRIE**, senão
    deadlock se confunde com flake.

## Regras que valem para toda task seguinte (do prompt do dono do produto)

- **A INVARIANTE**: nenhuma escrita na coleção sem confirmação explícita do
  usuário (Req. 10.5). Task que grave antes da confirmação está **errada mesmo
  que os testes passem**.
- AD-006 (substituir quantidade), AD-007 (tabela de staging → **tem migração**),
  AD-008 (limite de 10.000 linhas, verificado antes de processar) — **não
  reabrir**. Se alguma se mostrar inviável, PARAR e avisar o dono do produto.
- Uma task por vez, em ordem. Commit atômico por task, pt-BR, Conventional
  Commits, **sem nenhuma linha de atribuição**.
- Marcar checkbox nos DOIS planos antes do commit. **§5.2 de `.context/tasks.md`
  (linha 203) fecha na T7; §5.3 (linha 207) fecha na T15.**
- Toda consulta parte de `Current.user`. `CollectionItem.for_user` exige o objeto
  `User` e levanta `ArgumentError` num id.
- Nunca `git push`/`reset --hard`/`rebase`/force-push. **Nunca `git stash`** —
  usar cópia (`cp`/`diff`).
- Teste de UI vira teste de integração com `SPEC_DEVIATION` no cabeçalho (não há
  navegador no container).

## Contratos já levantados (não re-levantar)

- `CollectionItem.for_user(user)`: `nil`→`none`, `User`→`where`, outro→`ArgumentError`.
  Scopes `owned` (`quantity: 1..`) e `unowned` (`quantity: 0`).
  `CollectionItem.total_copies_for(user)` = `for_user(user).owned.sum(:quantity)`.
- **`CardVariant` NÃO tem `card_number`** — ele vive em `Card`. Export precisa de
  join `CollectionItem → CardVariant → Card`. O `UNIQUE` é `(card_id, variant_code)`,
  **por carta, não global** — por isso a chave do CSV é o PAR.
- `collection_items`: `UNIQUE (user_id, card_variant_id)`, `CHECK (quantity >= 0)`,
  todas as FKs `ON DELETE RESTRICT`. A tabela de staging (T11) deve manter esse regime.
- Padrão de escrita atômica a reusar na T14 (de `collection_items_controller.rb`):
  `INSERT ... ON CONFLICT (user_id, card_variant_id) DO UPDATE SET ... RETURNING quantity`.
- `ApplicationController` inclui `Authentication` → **toda action nasce protegida**.
  Os controllers novos (export/import) **não** devem declarar
  `allow_unauthenticated_access`.
- Ruby 3.3.0, Rails 8.0.5.1. `app/services/` só tem `ingestion/` hoje.
- Não existem views `collection_exports/` nem `collection_imports/`.
- `assert_queries_count` **existe** no ActiveRecord 8.0.5.1
  (`active_record/testing/query_assertions.rb:18`, assinatura
  `assert_queries_count(count = nil, include_schema: false, &block)`). É a
  ferramenta que a T5 e a T13 pedem para provar POR-13 — não precisa improvisar
  contador.
- A página da coleção que o usuário já usa é `app/views/progress/index.html.erb`
  (não existe `app/views/collection/`). É o destino natural do link da T7.

## Próximo passo exato

1. **T4 EM EXECUÇÃO** (subagente): gem `csv` no Gemfile + `app/services/collection_csv/format.rb`
   + testes de unidade (colunas idênticas export/import, cabeçalho por nome com
   ordem trocada, cabeçalho com BOM). Gate **build**.
2. Depois da T4, a Fase 2 é **estritamente serial** — cada task consome o
   artefato da anterior, não há o que paralelizar:
   T5 (`export.rb`, gate quick) → T6 (`collection_exports_controller.rb` + rota,
   gate full) → **T7 fecha a §5.2** (link na view, gate full, marca o checkbox
   da §5.2 em `.context/tasks.md`).
3. Ao fim da T17: Verifier FRESCO (autor ≠ verificador) produzindo
   `.specs/features/portabilidade/validation.md`, com pedido EXPLÍCITO de tentar
   **destruir dado de coleção** por algum caminho. Depois:
   `python3 ~/.claude/skills/tlc-spec-driven/scripts/validate_state.py portabilidade`
