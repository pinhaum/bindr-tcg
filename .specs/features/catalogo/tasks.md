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

### T3: Migrações de `sets`, `cards` e `card_variants` — CONCLUÍDA

**What**: Schema conforme `design.md` §3.2, ajustado ao vocabulário real da task 0.2.
**Where**: `db/migrate/`
**Depends on**: T1
**Requirement**: CAT-01, CAT-05

**Done when**:

- [x] `card_number` único; `(card_id, variant_code)` único
- [x] Foreign keys sem delete em cascata em direção à coleção
- [x] `rarity` como texto, não enum
- [x] `counter` permite NULL, distinto de 0
- [x] `colors`, `traits`, `attributes` como arrays Postgres (coluna `attributes_list`; ver SPEC_DEVIATION na migração)

**Tests**: integration
**Gate**: quick

---

### T4: Índices do catálogo — CONCLUÍDA

**What**: Índices de `design.md` §3.4 e extensões do Postgres.
**Where**: `db/migrate/`
**Depends on**: T3
**Requirement**: CAT-04

**Done when**:

- [x] GIN nas colunas de array; trigram no nome
- [x] `pg_trgm` e `unaccent` habilitadas
- [x] Teste prova, via plano de execução, que filtro por cor e por faixa de custo não fazem full table scan
- [x] Sintaxe de `gin_trgm_ops` e `to_tsvector` conferida na documentação da versão em uso (resolve um `⚠️ VERIFICAR` de `design.md`)
  - `gin_trgm_ops` e `to_tsvector('english', …)` conferem com a doc do PostgreSQL 17.
  - **Achado novo:** `unaccent` é STABLE nas duas assinaturas (medido no servidor 17.11), logo **não** é indexável direto — nem em índice de expressão nem em coluna gerada. O índice usa o wrapper IMMUTABLE `immutable_unaccent`.
  - Consequência: `schema_format = :sql` (`db/structure.sql`), porque `schema.rb` não representa a função e um banco criado a partir dele falha ao recriar o índice.

**Tests**: integration
**Gate**: quick

---

### T5: Estágio Fetch — CONCLUÍDA

**What**: Buscar o payload da revisão fixada e persistir bruto em disco antes de processar.
**Where**: `app/services/ingestion/`
**Depends on**: T1
**Requirement**: CAT-01

**Done when**:

- [x] Revisão fixada (commit/tag), nunca `main` — validado na carga de `config/ingestion.yml`
- [x] Payload bruto salvo em disco antes de qualquer processamento
- [x] Aborta sem escrever no banco se a fonte estiver indisponível

**Tests**: unit
**Gate**: quick

---

### T6: Estágio Normalize — CONCLUÍDA

**What**: Mapear o formato da optcgjson para o modelo interno. Todo conhecimento do formato externo isolado aqui.
**Where**: `app/services/ingestion/normalize.rb`
**Depends on**: T3, T5
**Requirement**: CAT-01

**Done when**:

- [x] `variant_code` = campo `id` da fonte, sem hash derivado
- [x] `traits` normalizados em caixa e espaçamento
- [x] `counter` nulo preservado como NULL
- [x] Trata `attribute: "?"` sem falhar
- [x] Testes rodam sobre `spec/fixtures/optcgjson-subset.json`, sem rede

**Tests**: unit
**Gate**: quick

---

### T7: Estágio Upsert + `import_runs` — CONCLUÍDA

**What**: Upsert por chave natural, cada registro em transação própria, com resumo persistido.
**Where**: `app/services/ingestion/upsert.rb`
**Depends on**: T6
**Requirement**: CAT-01

**Done when**:

- [x] Upsert por `card_number` e por `(card_id, variant_code)`, nunca create cego
- [x] Erro em um registro vai para `import_runs.error_log` e o loop continua
- [x] Resumo com início, fim, status, criados, atualizados, falhados e **revisão utilizada**
- [x] Mesma variante em dois sets não gera duplicata (caso `P-029_r1`)

**Tests**: integration
**Gate**: quick

---

### T8: Testes de garantia da ingestão — CONCLUÍDA

**What**: Os testes que provam que a ingestão não corrompe dados do usuário. É a task mais importante do projeto.
**Where**: `test/services/ingestion/`
**Depends on**: T7
**Requirement**: CAT-01

**Done when**:

- [x] Ingestão rodada duas vezes sobre a mesma fixture não altera contagem
- [x] `collection_item` criado antes da segunda execução continua com a mesma quantidade
- [x] Carta ausente da fonte não é deletada, apenas marcada

> `users` e `collection_items` entraram aqui, em migração mínima, porque a
> invariante do Req. 1.7 não é demonstrável sem uma coleção para preservar. O
> gerador de autenticação do Rails **não** foi executado — continua sendo Fase 4.
>
> Sensor de discriminação rodado nesta task: `create` cego de carta, `create`
> cego de variante e exclusão da carta ausente da fonte — os três derrubam a
> suíte. O mutante de `create` cego **sobreviveu à primeira versão** do teste,
> que só olhava contagem; uma ingestão que falha em todo registro também deixa a
> contagem intacta. As asserções passaram a exigir `status` e `failed_count`.

**Tests**: integration
**Gate**: full

---

### T9: Carregar o catálogo completo em desenvolvimento — CONCLUÍDA

**What**: Executar a ingestão real e conferir contra a fonte oficial.
**Where**: ambiente local
**Depends on**: T8
**Requirement**: CAT-01

**Done when**:

- [x] Número final de cartas e variantes registrado: **2815 cartas, 4914 variantes, 62 sets**, 7791 registros criados, 0 falhas
- [x] 10 cartas inspecionadas manualmente, incluindo um Leader dual-color (`EB01-001`, Red/Green) e uma com arte alternativa (`EB01-006`, 6 variantes em 3 sets)

> **4914, não 4915.** A fonte tem 4915 linhas de carta e 4914 `id` distintos:
> `P-029_r1` aparece em PRB01 e ST16. O número do ADR 001 contava linhas; 4914 é
> a contagem correta de variantes, e é exatamente o caso-limite que a T7 trata.
>
> Dois achados da carga real, ambos corrigidos no Normalize:
> 1. `AllSets.json` entrega `data` como **objeto indexado pelo código do set**,
>    não como lista — a fixture é um recorte já achatado. Derrubava o Normalize
>    com `TypeError`. Tem teste de regressão.
> 2. A normalização de traits por Title Case corrompia 10 traits reais
>    (`Former CP9` → `Former Cp9`, `Kingdom of GERMA`, `Land of Wano`) para
>    resolver **uma** colisão real (`SMILE`/`Smile`). Trocada por colapso de
>    espaçamento + deduplicação insensível a caixa, preservando a grafia da fonte.
>
> Idempotência confirmada contra o catálogo real: segunda execução deu
> 0 criados / 7791 atualizados / 0 falhados, sem mudança de contagem.

**Tests**: none
**Gate**: full

---

### T10: Query object do catálogo — CONCLUÍDA

**What**: Contrato de `design.md` §4.2 — filtros, faixas, ordenação e paginação num único objeto.
**Where**: `app/queries/`
**Depends on**: T4, T9
**Requirement**: CAT-04

**Done when**:

- [x] OU dentro da categoria, E entre categorias
- [x] Filtro de cor inclui multicoloridas
- [x] Parâmetro inválido é ignorado, nunca causa erro
- [x] Retorna `total_count` e filtros ativos normalizados
- [x] Testes: cada filtro isolado, duas combinações, caso multicolor

**Tests**: integration
**Gate**: quick

---

### T11: Busca textual — CONCLUÍDA

**What**: Nome com tolerância a typo, efeito por full-text, `card_number` exato prependido.
**Where**: `app/queries/`
**Depends on**: T10
**Requirement**: CAT-03

**Done when**:

- [x] Nome insensível a caixa e acento, tolerante a erro de digitação
- [x] Match exato de `card_number` vem como primeiro resultado, por consulta separada
- [x] Combinável com todos os filtros

> Dois achados medidos contra o catálogo real, ambos propagados para
> `design.md` (§4.1.2 e §4.1.3) antes de virarem código:
>
> 1. **O par default do `pg_trgm` não atende o Req. 3.3.**
>    `similarity('Zorro','Roronoa Zoro')` = 0.286, abaixo do limiar 0.3 — a
>    similaridade da string inteira é diluída pelo sobrenome que o termo não
>    tem. Trocado por `word_similarity` (`<%`) com limiar 0.5 via
>    `set_config(..., true)`, local à transação.
> 2. **As três ramificações unidas por `OR` produzem Seq Scan**, mesmo com os
>    três índices presentes: uma ramificação inindexável derruba o plano do
>    predicado inteiro. Passaram a se unir por `UNION`, e `card_number` ganhou
>    índice GIN trigram (migração `20260919120300`, aditiva — não altera nada
>    do schema verificado na Fase 2).
>
> Sensor de discriminação: 7 mutações. Três sobreviveram à primeira versão dos
> testes e cada uma virou asserção nova — o decoy do prepend ordenava *depois*
> do exato, então o exato vinha em primeiro por sorte da ordenação; `unaccent`
> direto no lugar de `immutable_unaccent` e `upper(card_number)` no exato
> devolvem o resultado certo e só perdem o índice, defeito que nenhum teste
> funcional pega. As três agora morrem por teste de plano de execução.

**Tests**: integration
**Gate**: quick

---

### T12: Grade do catálogo — CONCLUÍDA

**What**: Grade navegável com paginação, lazy loading e estado na URL.
**Where**: `app/views/`, `app/controllers/`
**Depends on**: T11
**Requirement**: CAT-02

**Done when**:

- [x] Imagem, nome e `card_number` por carta; paginação; lazy loading
- [x] Placeholder com nome e código quando a imagem falha
- [x] Estado vazio com termo buscado e ação de limpar filtros
- [x] Filtros ativos como chips removíveis individualmente
- [x] Estado completo na URL; recarregar reproduz o resultado
- [x] Usável em 360px sem scroll horizontal

> **SPEC_DEVIATION — `Tests: e2e` virou teste de integração.** A imagem de
> desenvolvimento não tem navegador nem chromedriver (nenhum binário `chrom*`
> no container), e instalá-los é mudança de `Dockerfile.dev`, fora do escopo
> desta task. Todos os critérios do "Done when" são observáveis no HTML
> renderizado — o placeholder é markup, o estado na URL é query string, os
> chips são links, o lazy loading é atributo.
>
> O Req. 2.5 e o Req. 11.2 foram **verificados adicionalmente em navegador
> real** (Chromium do Playwright, no host, contra o catálogo completo em
> :3000), porque "sem scroll horizontal" não é asserível em HTML:
> `scrollWidth == clientWidth == 360` nas três URLs testadas, zero elementos
> ultrapassando 360px, grade em duas colunas fluidas, e as 24 imagens da
> primeira página todas com `loading="lazy"`. Essa verificação é manual e não
> está na suíte — é a lacuna que um chromedriver no container fecharia.
>
> **Placeholder sem JavaScript.** O projeto não tem pipeline de JS
> (`app/javascript` e `config/importmap.rb` não existem; `stimulus-rails` está
> no Gemfile mas nunca foi instalado). Em vez de bootstrapar importmap, o
> placeholder é resolvido por camadas de CSS: renderizado sempre, embaixo,
> com a imagem por cima. Imagem ausente ou hotlink quebrado deixam o
> placeholder visível sem script nenhum — mais robusto que `onerror`, que
> depende de o script carregar.
>
> **Defeito encontrado pelo smoke test, não pela suíte.** Com a página no ar
> contra o catálogo real, `q=Zorro` devolvia **zero** resultado enquanto os 49
> testes passavam. Causa: o limiar do trigram é aplicado com
> `set_config(..., true)` — `SET LOCAL`, válido só até o fim da transação
> corrente. Fora de uma transação cada statement é a sua própria e o limiar já
> voltou a 0.6 quando a consulta roda; o Rails envolve **todo** teste numa
> transação, então a suíte inteira era estruturalmente cega a essa falha. A
> busca passou a rodar em transação explícita e ganhou teste de regressão com
> `use_transactional_tests = false`, que é o único jeito de reproduzir a
> condição real.
>
> Brakeman acusou SQL injection (confiança fraca) na interpolação do nome de
> coluna do filtro de array. O valor vem de constante congelada e não era
> explorável, mas foi eliminado com `quote_column_name` em vez de entrar em
> `brakeman.ignore`: 0 warnings sem ignore novo.

**Tests**: integration (ver desvio acima) + verificação manual em navegador
**Gate**: full

---

### T13: Medir a latência do filtro — CONCLUÍDA

**What**: Validar a premissa de stack (AD-002) com o catálogo completo carregado.
**Where**: ambiente local
**Depends on**: T12
**Requirement**: CAT-04

**Done when**:

- [x] p95 medido para busca + três filtros combinados
- [x] Resultado registrado
- [x] Se > 500ms: otimizar índice e consulta **antes** de considerar troca de stack

> **Resultado: p95 = 25,3 ms no query object e 51,6 ms ponta a ponta por
> HTTP.** O alvo do Req. 11.1 é 500 ms. Passa com ~20x de folga; nada a
> otimizar e nenhuma razão para reabrir AD-002.
>
> Medido com o catálogo completo (2815 cartas, 4914 variantes, 62 sets),
> 50 amostras por cenário, 3 execuções de aquecimento descartadas (a primeira
> paga plano, cache frio e carregamento de classe). Reproduzível:
> `docker compose exec -T app bin/rails catalog:benchmark`.
>
> | Cenário (query object) | p50 | p95 |
> | --- | --- | --- |
> | **busca + 3 filtros — o cenário do Req. 11.1** | 7,2 ms | **25,3 ms** |
> | busca sozinha | 6,3 ms | 8,4 ms |
> | 3 filtros sem busca | 2,1 ms | 3,0 ms |
> | busca com typo + filtros | 6,2 ms | 7,8 ms |
> | `card_number` exato + filtros | 5,7 ms | 7,9 ms |
> | trait + set + raridade | 3,4 ms | 6,1 ms |
>
> O query object sozinho não é o número que o usuário sente, então a medição
> foi repetida por HTTP, com renderização de view, no servidor de
> desenvolvimento (que recarrega código a cada request — é o caso pessimista):
>
> | Cenário (HTTP ponta a ponta) | p50 | p95 |
> | --- | --- | --- |
> | busca + 3 filtros | 23,8 ms | **51,6 ms** |
> | catálogo sem filtro, 24 tiles | 32,8 ms | 43,0 ms |
> | página profunda (`page=100`) | 39,7 ms | 57,9 ms |
> | `per_page=100` | 99,5 ms | 119,6 ms |
> | busca ampla + `per_page=100` (pior caso) | 105,0 ms | 161,9 ms |
>
> Mesmo o pior caso realista fica 3x abaixo do alvo. O custo cresce com o
> número de tiles renderizados, não com o tamanho do catálogo — o que é
> esperado, já que `per_page` é limitado a 100 pelo query object.

**Tests**: none (medição, não asserção — ver Test Coverage Matrix)
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
