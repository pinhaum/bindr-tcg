# Catálogo — Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path.

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

> **Fonte de verdade das tasks:** `.context/tasks.md`. Este arquivo é o mesmo plano
> no formato do skill, com dependências e gates explícitos. Marcar conclusão **nos
> dois**. Ver AD-005 em `.specs/STATE.md`.

---

**Design**: `.context/design.md`
**Spec**: `.specs/features/catalogo/spec.md`
**Status**: In Progress — Fase 0 concluída (0.1, 0.2, 0.3); Fase 1 concluída (T1, T2)

---

## Test Coverage Matrix

| Camada | O que testar | Tipo de teste |
| ------ | ------------ | ------------- |
| Normalize | Mapeamento fonte → modelo, normalização de traits, casos-limite | unit, sobre fixture, sem rede |
| Upsert | Idempotência, preservação da coleção, ausência de delete | integration, com banco |
| Query object | Cada filtro isolado, combinações, multicolor, parâmetro inválido | unit/integration |
| Índices | Ausência de full table scan | integration, via plano de execução |
| Grade / detalhe | Estado na URL, placeholder, 360px | system/e2e |
| CI (T2) | — | none (o próprio pipeline é a verificação) |
| Carga real (T9) | — | none (inspeção manual contra a fonte oficial) |
| Latência (T13) | — | none (medição, não asserção) |

Os warnings de `Tests: none` em T2, T9 e T13 são deliberados e cobertos por esta
tabela. O warning de granularidade em T1 também: inicializar o projeto toca
`docker-compose.yml` e `README.md` por natureza, e dividir produziria uma task
cujo resultado é "estrutura criada" — proibido por `.context/tasks.md`.

## Gate Check Commands

Definidos na T1 e em uso:

- **quick**: `bin/rails test test/models test/lib`
- **full**: `bin/rails test && bin/rubocop`
- **build**: `docker compose build`

Dentro do container, prefixar com `docker compose exec app`.

---

## Execution Plan

### Phase 0: Desbloqueio — CONCLUÍDA

```
T0.1 → T0.2 → T0.3
```

### Phase 1: Fundação

```
T1 → T2
```

### Phase 2: Modelo e ingestão

Schema e Fetch partem de T1 em paralelo; convergem no Normalize.

```
T1 → T3 → T4
T1 → T5
T3 → T6
T5 → T6 → T7 → T8 → T9
```

### Phase 3: Busca, filtros e exibição

Detalhe e medição de latência ambos dependem da grade, não um do outro.

```
T4 → T10
T9 → T10 → T11 → T12
T12 → T13
T12 → T14
```

---

## Plano de delegação

Mapeado em 2026-09-19. **Advisory** — nenhum gate depende disto.

### Lotes (batches)

O critério do skill é ~7 tasks por worker, **nunca partindo uma fase**. Com
fases de 2 / 7 / 5 tasks (T1–T14), o empacotamento é:

| Lote | Fases | Tasks | Como executar | Tier |
| ---- | ----- | ----- | ------------- | ---- |
| — | Fase 1 | T1, T2 | **Inline, sem subagente** | — |
| B1 | Fase 2 | T3–T9 (7) | Worker único | Alto raciocínio |
| B2 | Fase 3 | T10–T14 (5) | Worker único | Alto raciocínio |

**Fase 1 não se delega.** T1 fixa as convenções que as outras 13 herdam — layout,
nomes, `docker-compose`, como o teste roda. Delegar isso é herdar uma convenção
que ninguém escolheu. São 2 tasks; cabem inline.

**Nenhum dos dois lotes é "mecânico".** A Fase 2 tem a invariante mais cara do
projeto (ingestão não corrompe coleção) e a Fase 3 tem a semântica de filtro
`OU`/`E` com multicolor. O rubric manda dimensionar para cima na dúvida.

### Verifier — obrigatório, não se pergunta

Roda **ao fim de cada lote**, com autor ≠ verificador. Tier médio-alto: ele
projeta mutações e re-deriva cobertura; um Verifier fraco anula a garantia.

O sensor de discriminação é onde ele ganha o custo. Mutações que os testes
**precisam** matar:

- Trocar o upsert de variante por `create` cego → T8 deve falhar.
- Fazer a ingestão deletar carta ausente da fonte → T8 deve falhar.
- Tratar `counter` nulo como `0` → teste de modelagem deve falhar.
- Inverter `OU`/`E` entre categorias de filtro → T10 deve falhar.
- Excluir multicoloridas do filtro de cor → T10 deve falhar.

> **Isolamento:** o sensor usa worktree temporário ou cópia de arquivos, **nunca
> `git stash`**. Há trabalho não commitado com frequência neste repo.

### Agentes nomeados

**Não existe `ruby-reviewer` nem `rails-reviewer`** entre os 68 agentes
instalados (verificado). Há Python, Go, Rust, Java, PHP, TypeScript, React,
Django, FastAPI — Ruby não. Então o worker é um agente genérico com o payload do
skill, e a revisão usa os que são agnósticos de linguagem:

| Quando | Agente | Por quê |
| ------ | ------ | ------- |
| Após T3/T4 (schema e índices) | `ecc:database-reviewer` | Constraints, índices, planos de execução — agnóstico de ORM |
| Após T7/T8 (upsert) | `ecc:silent-failure-hunter` | O loop de erro por registro é exatamente onde erro engolido some |
| Após T8 | `ecc:pr-test-analyzer` | Julga se os testes cobrem comportamento ou só espelham a implementação |
| Após T12/T14 (views) | `ecc:a11y-architect` | Req. 2.5 (360px) e placeholder de imagem |
| Antes de expor rotas de sessão (Fase 4) | `ecc:security-reviewer` | Req. 6.5 — consulta parte sempre do usuário da sessão |

Não usar `ecc:code-reviewer` genérico junto com os acima: sobreposição sem ganho.

---

## Task Breakdown

### T1: Inicializar o projeto Rails 8 com PostgreSQL — CONCLUÍDA

**What**: Projeto Rails 8 novo, PostgreSQL configurado, suíte de testes rodando com um teste trivial verde, subida local em um comando documentado.
**Where**: raiz do repositório, `docker-compose.yml`, `README.md`
**Depends on**: None
**Requirement**: CAT-01

**Done when**:

- [x] `docker compose up` sobe app + Postgres
- [x] Um teste trivial passa
- [x] README documenta o comando único de subida
- [x] Confirmado na documentação do Rails 8 se o gerador de autenticação atende o Req. 6 (resolve um `⚠️ VERIFICAR` de `design.md`)

**Tests**: unit
**Gate**: full

---

### T2: Configurar CI — CONCLUÍDA

**What**: Pipeline que roda linter e suíte de testes em cada push.
**Where**: `.github/workflows/`
**Depends on**: T1
**Requirement**: CAT-01

**Done when**:

- [x] Pipeline roda em push e falha quando o teste falha

**Tests**: none
**Gate**: full

---

### T3: Migrações de `sets`, `cards` e `card_variants`

**What**: Schema conforme `design.md` §3.2, ajustado ao vocabulário real da task 0.2.
**Where**: `db/migrate/`
**Depends on**: T1
**Requirement**: CAT-01, CAT-05

**Done when**:

- [ ] `card_number` único; `(card_id, variant_code)` único
- [ ] Foreign keys sem delete em cascata em direção à coleção
- [ ] `rarity` como texto, não enum
- [ ] `counter` permite NULL, distinto de 0
- [ ] `colors`, `traits`, `attributes` como arrays Postgres

**Tests**: integration
**Gate**: quick

---

### T4: Índices do catálogo

**What**: Índices de `design.md` §3.4 e extensões do Postgres.
**Where**: `db/migrate/`
**Depends on**: T3
**Requirement**: CAT-04

**Done when**:

- [ ] GIN nas colunas de array; trigram no nome
- [ ] `pg_trgm` e `unaccent` habilitadas
- [ ] Teste prova, via plano de execução, que filtro por cor e por faixa de custo não fazem full table scan
- [ ] Sintaxe de `gin_trgm_ops` e `to_tsvector` conferida na documentação da versão em uso (resolve um `⚠️ VERIFICAR` de `design.md`)

**Tests**: integration
**Gate**: quick

---

### T5: Estágio Fetch

**What**: Buscar o payload da revisão fixada e persistir bruto em disco antes de processar.
**Where**: `app/services/ingestion/`
**Depends on**: T1
**Requirement**: CAT-01

**Done when**:

- [ ] Revisão fixada (commit/tag), nunca `main`
- [ ] Payload bruto salvo em disco antes de qualquer processamento
- [ ] Aborta sem escrever no banco se a fonte estiver indisponível

**Tests**: unit
**Gate**: quick

---

### T6: Estágio Normalize

**What**: Mapear o formato da optcgjson para o modelo interno. Todo conhecimento do formato externo isolado aqui.
**Where**: `app/services/ingestion/normalize.rb`
**Depends on**: T3, T5
**Requirement**: CAT-01

**Done when**:

- [ ] `variant_code` = campo `id` da fonte, sem hash derivado
- [ ] `traits` normalizados em caixa e espaçamento
- [ ] `counter` nulo preservado como NULL
- [ ] Trata `attribute: "?"` sem falhar
- [ ] Testes rodam sobre `spec/fixtures/optcgjson-subset.json`, sem rede

**Tests**: unit
**Gate**: quick

---

### T7: Estágio Upsert + `import_runs`

**What**: Upsert por chave natural, cada registro em transação própria, com resumo persistido.
**Where**: `app/services/ingestion/upsert.rb`
**Depends on**: T6
**Requirement**: CAT-01

**Done when**:

- [ ] Upsert por `card_number` e por `(card_id, variant_code)`, nunca create cego
- [ ] Erro em um registro vai para `import_runs.error_log` e o loop continua
- [ ] Resumo com início, fim, status, criados, atualizados, falhados e **revisão utilizada**
- [ ] Mesma variante em dois sets não gera duplicata (caso `P-029_r1`)

**Tests**: integration
**Gate**: quick

---

### T8: Testes de garantia da ingestão

**What**: Os testes que provam que a ingestão não corrompe dados do usuário. É a task mais importante do projeto.
**Where**: `test/services/ingestion/`
**Depends on**: T7
**Requirement**: CAT-01

**Done when**:

- [ ] Ingestão rodada duas vezes sobre a mesma fixture não altera contagem
- [ ] `collection_item` criado antes da segunda execução continua com a mesma quantidade
- [ ] Carta ausente da fonte não é deletada, apenas marcada

**Tests**: integration
**Gate**: full

---

### T9: Carregar o catálogo completo em desenvolvimento

**What**: Executar a ingestão real e conferir contra a fonte oficial.
**Where**: ambiente local
**Depends on**: T8
**Requirement**: CAT-01

**Done when**:

- [ ] Número final de cartas e variantes registrado (esperado ~2815 / ~4915)
- [ ] 10 cartas inspecionadas manualmente, incluindo um Leader dual-color e uma com arte alternativa

**Tests**: none
**Gate**: full

---

### T10: Query object do catálogo

**What**: Contrato de `design.md` §4.2 — filtros, faixas, ordenação e paginação num único objeto.
**Where**: `app/queries/`
**Depends on**: T4, T9
**Requirement**: CAT-04

**Done when**:

- [ ] OU dentro da categoria, E entre categorias
- [ ] Filtro de cor inclui multicoloridas
- [ ] Parâmetro inválido é ignorado, nunca causa erro
- [ ] Retorna `total_count` e filtros ativos normalizados
- [ ] Testes: cada filtro isolado, duas combinações, caso multicolor

**Tests**: integration
**Gate**: quick

---

### T11: Busca textual

**What**: Nome com tolerância a typo, efeito por full-text, `card_number` exato prependido.
**Where**: `app/queries/`
**Depends on**: T10
**Requirement**: CAT-03

**Done when**:

- [ ] Nome insensível a caixa e acento, tolerante a erro de digitação
- [ ] Match exato de `card_number` vem como primeiro resultado, por consulta separada
- [ ] Combinável com todos os filtros

**Tests**: integration
**Gate**: quick

---

### T12: Grade do catálogo

**What**: Grade navegável com paginação, lazy loading e estado na URL.
**Where**: `app/views/`, `app/controllers/`
**Depends on**: T11
**Requirement**: CAT-02

**Done when**:

- [ ] Imagem, nome e `card_number` por carta; paginação; lazy loading
- [ ] Placeholder com nome e código quando a imagem falha
- [ ] Estado vazio com termo buscado e ação de limpar filtros
- [ ] Filtros ativos como chips removíveis individualmente
- [ ] Estado completo na URL; recarregar reproduz o resultado
- [ ] Usável em 360px sem scroll horizontal

**Tests**: e2e
**Gate**: full

---

### T13: Medir a latência do filtro

**What**: Validar a premissa de stack (AD-002) com o catálogo completo carregado.
**Where**: ambiente local
**Depends on**: T12
**Requirement**: CAT-04

**Done when**:

- [ ] p95 medido para busca + três filtros combinados
- [ ] Resultado registrado
- [ ] Se > 500ms: otimizar índice e consulta **antes** de considerar troca de stack

**Tests**: none
**Gate**: full

---

### T14: Página de detalhe da carta

**What**: Todos os campos, todas as variantes, campos inaplicáveis omitidos.
**Where**: `app/views/`
**Depends on**: T12
**Requirement**: CAT-05

**Done when**:

- [ ] Todas as variantes listadas, cada uma com raridade, set e imagem própria
- [ ] `effect_text` e `trigger_text` preservam quebras de linha
- [ ] Campos não aplicáveis ao tipo omitidos, não exibidos vazios

**Tests**: e2e
**Gate**: full
