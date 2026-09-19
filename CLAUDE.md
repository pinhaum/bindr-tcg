# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Estado atual: esqueleto Rails 8, sem domínio

O app Rails existe e boota (task 1.1 em andamento), mas **não há nenhum model,
migration ou rota de domínio** — `app/models/` tem só `ApplicationRecord` e
`db/` não tem `migrate/`. O único teste é `test/lib/stack_test.rb`, que prova que
a conexão é PostgreSQL de verdade e que o banco de teste é distinto do de
desenvolvimento (AD-002 depende disso: `pg_trgm`, `unaccent` e GIN sustentam os
Req. 3 e 4 inteiros).

Pendente ainda em 1.1: o README tem uma linha só e **não documenta a subida em um
comando** (Req. 11.6) — a task não fecha sem isso. Não há CI (task 1.2).

## Comandos

Tudo roda em Docker; o Postgres não existe fora dele.

```bash
cp .env.example .env
docker compose up          # sobe db + app, roda db:prepare, serve em :3000
docker compose exec app bin/rails test
docker compose exec app bin/rails test test/lib/stack_test.rb
docker compose exec app bin/rails test test/lib/stack_test.rb -n "/PostgreSQL/"
docker compose exec app bin/rubocop      # rubocop-rails-omakase
docker compose exec app bin/brakeman
docker compose exec app bin/rails db:prepare
```

Gates definidos em `.specs/features/catalogo/tasks.md`: **quick** =
`bin/rails test test/models test/lib`; **full** = `bin/rails test && bin/rubocop`;
**build** = `docker compose build`.

Verificação da fixture de ingestão, offline, sem Docker e sem Ruby — deve
continuar passando (12 verificações):

```bash
python3 spec/verify_fixture.py
```

Validadores do fluxo spec-driven:

```bash
SKILL=~/.claude/skills/tlc-spec-driven
python3 $SKILL/scripts/validate_spec.py  .specs/features/catalogo/spec.md
python3 $SKILL/scripts/validate_tasks.py .specs/features/catalogo/tasks.md
```

`Dockerfile.dev` é a imagem de desenvolvimento (código como volume); `Dockerfile`
é o de produção gerado pelo Rails — separados de propósito, não unificar.

## Método de trabalho: spec-driven

O fluxo é `requirements` → `design` → `tasks`, documentado em `.context/README.md`.
Regras que valem para qualquer sessão de trabalho aqui:

- **Uma task por vez**, em ordem, de `.context/tasks.md`. Não abrir a próxima com a
  anterior incompleta.
- **Toda task termina com código que roda e teste que passa.** "Estrutura criada"
  não conta como task concluída.
- **Se um requisito se mostrar errado durante a execução, pare e corrija
  `requirements.md`** antes de continuar. Não improvisar no código — corrigir só o
  código desalinha o spec e destrói o valor do método.
- Mudança de escopo volta ao documento de origem e se propaga para baixo.

### Dois diretórios de spec, de propósito

`.context/` é a **fonte de verdade** de requisitos, design e plano de tasks.
`.specs/` guarda o recorte por feature (`features/catalogo/`), o log de decisões
(`STATE.md`, AD-001 a AD-005) e os artefatos do Verifier. Em divergência,
`.context/` vence (AD-005). Os IDs `CAT-NN` e `T1`–`T14` de `.specs/` apontam para
os requisitos numerados de `.context/requirements.md`.

**Ao concluir uma task, marcar o checkbox nos dois planos** (`.context/tasks.md` e
`.specs/features/catalogo/tasks.md`) e commitar junto com o código. `STATE.md`
tem a seção *Handoff* com o ponto exato de retomada — ler antes de começar.

### Convenções nos documentos

- `SHALL` / `DEVE` — requisito obrigatório e testável.
- `⚠️ VERIFICAR` — afirmação sobre o jogo, uma API ou uma biblioteca que **não foi
  confirmada**. Precisa de validação em fonte primária antes de virar código. Não
  tratar como fato.
- `DECISÃO PENDENTE` — ponto onde o design deliberadamente não escolheu.

Os documentos estão em português brasileiro. Escrever novos documentos e commits
na mesma língua.

## Decisões já tomadas (P1–P7 resolvidas)

As sete pendências que bloqueavam código foram decididas na Fase 0 e estão em
`.specs/STATE.md` como AD-001..AD-004. **Nenhuma bloqueia mais nada** — não
reabrir sem motivo novo:

| # | Decisão | Onde |
|---|---------|------|
| P1 | Fonte = `hugoprudente/optcgjson` (`output/*.json`), revisão imutável | AD-001 |
| P2 | Campos/raridades/sets reais extraídos da fixture; glossário de `product.md` §6 corrigido | task 0.2 |
| P3 | "Set completo" = `baseSetSize` (variantes base); parallels em métrica separada | AD-003 |
| P4 | Rails 8 + Hotwire + PostgreSQL | AD-002 |
| P5 | Não se aplica: a fonte dá `id` estável por variante (`OP01-001_p1`) | AD-001 |
| P6 | Sem cache de imagens na Fase 1; hotlink de `imageUrl` | AD-004 |
| P7 | `DON!!` fora do catálogo na Fase 1 | task 0.2 |

A escolha da fonte em AD-001 é o que **elimina** a fragilidade que o design
original atribuía a `variant_code`: ele vem pronto da fonte, não é derivado por
hash. Trocar de fonte reintroduz esse problema.

A fixture `spec/fixtures/optcgjson-subset.json` (1.4 MB) é versionada de
propósito — é a entrada dos testes de ingestão sem rede (Req. 11.5). Já
`storage/ingestion/` (payloads brutos do Fetch) é ignorada: reconstruível a
partir da revisão fixada.

## Arquitetura (de `.context/design.md`)

Três subsistemas, e a separação entre eles é o eixo do design inteiro:

```
Fonte externa → INGESTÃO (Fetch → Normalize → Upsert) → CATÁLOGO → COLEÇÃO
                                                     (read-only)  (escrita do usuário)
```

**O catálogo é regenerável; a coleção é insubstituível.** Todas as invariantes
abaixo existem para impedir que a ingestão corrompa dados do usuário:

- A ingestão **não tem operação de delete**. Carta ausente da fonte é marcada,
  nunca removida (Req. 1.7).
- **Nenhuma foreign key da coleção usa delete em cascata** — deletar uma variante
  apagaria em cascata o registro do usuário.
- Upsert por chave natural (`card_number` para cartas, `card_id + variant_code`
  para variantes), nunca `create` cego. Cada registro em transação própria; erro em
  um registro vai para `import_runs.error_log` e o loop continua.
- O teste mais valioso do projeto (task 2.6): rodar a ingestão duas vezes com um
  `collection_item` existente e verificar que a quantidade continua intacta.

### `Card` ≠ `CardVariant` — a decisão central do modelo

- **Card** = a carta do jogo, identificada por `card_number` (`OP01-001`). É sobre
  ela que as regras e textos falam.
- **CardVariant** = uma impressão física específica (base, alternate art, parallel,
  manga, promo). Mesmo `card_number`, mesmo efeito, **objeto de coleção diferente**.

Coleção e wishlist referenciam **variantes**. Busca e filtros operam sobre
**cartas**, exibindo variantes agregadas. Colapsar as duas entidades destrói metade
do sentido do produto e é o erro mais caro de corrigir depois. Preço (Fase 3) e
deck (Fase 2) dependem dessa mesma distinção: deck referencia `cards`, coleção
referencia `card_variants`.

### Isolamento da fonte externa

Todo conhecimento sobre o formato da fonte vive **no estágio Normalize e em nenhum
outro lugar**. Trocar de fonte de dados deve significar escrever um normalizador
novo, nada mais. O estágio Fetch salva o payload bruto em disco antes de processar
— é isso que permite reprocessar sem rede e transforma o payload em fixture de
teste (Req. 11.5).

### Busca e filtros

Tudo em PostgreSQL, sem serviço de busca dedicado (dataset pequeno, consultas
estruturadas): `pg_trgm` + GIN para nome com tolerância a typo, `unaccent` para
acentos, `tsvector` para texto de efeito, e uma **consulta separada** para match
exato de `card_number` cujo resultado é prependido. Não tentar resolver ranking
exato dentro do full-text.

Um **único query object** traduz parâmetros de URL em consulta e serve tanto HTML
quanto JSON — é o único lugar que precisa de teste de filtro. Contrato em
`design.md` §4.2. Semântica: `OU` dentro de uma categoria, `E` entre categorias;
filtro de cor inclui multicoloridas. **Parâmetro desconhecido ou inválido é
ignorado, nunca causa erro** — uma URL compartilhada não pode dar 500 porque um
filtro foi renomeado.

### Detalhes de modelagem fáceis de errar

- `counter` **NULL ≠ 0**: "não tem counter" não é "counter de 0". Nunca usar 0 como
  sentinela.
- `colors`, `traits`, `attributes` como arrays Postgres + GIN (não tabelas de
  junção). `traits` vem de texto livre da fonte → **normalizar caixa e espaçamento
  na ingestão**, senão `"Straw Hat Crew"` e `"Straw hat crew"` viram traits
  distintos e o filtro fica furado.
- `rarity` como **texto, não enum** — a fixture confirma nove valores
  (`C UC R SR SEC L P "SP CARD" TR`), mas a fonte é um scraper comunitário: enum
  faz a ingestão explodir no dia em que aparecer um valor novo.
- `variant_code` precisa ser **estável entre execuções**, senão a idempotência
  quebra e o usuário perde o vínculo com a coleção. Hoje ele vem pronto da fonte
  (`id` por variante, AD-001) — foi o que tirou este ponto da lista de riscos.

### Revisão por subagente

**Não existe `ruby-reviewer` nem `rails-reviewer`** entre os agentes instalados
(Python, Go, Rust, Java, PHP, TypeScript, React, Django, FastAPI — Ruby não). O
plano completo está em `.specs/features/catalogo/tasks.md` §"Plano de delegação";
o resumo: Fase 1 inline (T1 fixa convenções que as outras 13 herdam), Fase 2 e
Fase 3 como um lote cada, e revisão pelos agentes agnósticos de linguagem —
`ecc:database-reviewer` no schema/índices, `ecc:silent-failure-hunter` no loop de
erro por registro do upsert, `ecc:pr-test-analyzer` nos testes de ingestão,
`ecc:a11y-architect` nas views.

Se rodar sensor de mutação, isolar em worktree ou cópia — **nunca `git stash`**:
há trabalho não commitado com frequência neste repo.

### Autorização

**Toda** consulta a coleção ou wishlist parte do usuário da sessão, nunca de um ID
vindo do request. Isso satisfaz o Req. 6.5 por construção em vez de por verificação.
Catálogo é público; qualquer mutação exige sessão.

## Alvos não-funcionais que já têm task de validação

- Filtro combinado com busca: **p95 < 500ms** com catálogo completo (Req. 11.1,
  task 3.4). Se falhar, a saída é otimizar índice/consulta e depois hidratar
  filtros no cliente — **não** trocar de stack.
- Filtros do Req. 4 **sem full table scan**, verificável por plano de execução
  (Req. 11.3, task 2.2).
- Usável em viewport de **360px sem scroll horizontal** (Req. 2.5).
- Subida local em **um único comando documentado** (Req. 11.6).
