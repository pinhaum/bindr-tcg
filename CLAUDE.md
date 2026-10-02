# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Estado atual: catálogo pronto, coleção em construção

A feature **`catalogo` está encerrada e verificada** (14 tasks, dois lotes, ambos
PASS em `.specs/features/catalogo/validation.md`): ingestão, busca com tolerância
a typo, filtros, grade e página de detalhe funcionam e são **públicos**.

A feature **`colecao` (Fase 4) está encerrada e verificada** (13 tasks, dois
lotes, ambos PASS em `.specs/features/colecao/validation.md` — 62 critérios,
62 PASS, 0 FAIL, autor ≠ verificador): identidade e sessão, posse por variante,
filtro de posse, total de cópias e wishlist. Com ela fechou a **§4 inteira** de
`.context/tasks.md` (§4.1 a §4.5). O próximo trabalho é a **Fase 5**: §5.1
progresso por set e §5.2–5.3 import/export CSV.

O que existe hoje:

- **Models**: `Card`, `CardVariant`, `CardSet`, `ImportRun`, `CollectionItem`,
  `WishlistItem`, `User`, `Session`, `Current`.
- **Controllers**: `CatalogController` (público), `CollectionItemsController`,
  `WishlistItemsController`, `SessionsController`, `RegistrationsController`, e
  o concern `Authentication`.
- **Seis migrações**, de `20260919120000` a `20260919120500`. `schema_format`
  é `:sql`: migração nova exige `db:migrate` para regenerar `db/structure.sql`.
- **26 arquivos de teste, 395 testes**, rubocop limpo.
- **Importmap instalado na T8**, com Turbo pinado para `turbo.js` e **Stimulus
  deliberadamente não pinado** (não há controller Stimulus no projeto). O
  placeholder de imagem do catálogo continua resolvido em CSS — não trocar por
  JS só porque agora existe pipeline.

**O default do app é exigir sessão.** `ApplicationController` inclui
`Authentication`, então toda action nasce protegida e o acesso público é exceção
declarada com `allow_unauthenticated_access` — hoje o `CatalogController` e o
`RegistrationsController`. `CollectionItemsController` e
`WishlistItemsController` não declaram nada e por isso exigem sessão.
Uma action nova que não declare nada já está protegida.

Dívidas abertas que valem saber antes de mexer em autenticação:

- **Login sem limite de tentativas.** O `rate_limit` do template do Rails foi
  deliberadamente omitido na T4: sem cache store compartilhado ele não limita
  nada (teste é `:null_store`; produção cai em `:file_store` por container).
  Justificativa completa em `app/controllers/sessions_controller.rb`. Reabrir
  junto com Redis ou `solid_cache`.
- **O cookie de sessão não declara `secure` explicitamente** — em produção vem
  de `config.force_ssl`. A garantia é indireta; comentada no concern.
- **Não há navegador no container**, logo não há system test. Teste de UI vira
  teste de integração sobre HTML renderizado, com `SPEC_DEVIATION` registrado.
- **`allow_unauthenticated_access` não resolve a sessão.** Ele remove o
  `before_action :require_authentication`, que era quem chamava
  `resume_session`: num controller público, `Current.user` é `nil` na action
  até alguém chamar `authenticated?`. Ler dado do usuário ali sem isso é
  defeito **silencioso** — responde 200 e devolve vazio. A T8 tropeçou nisso;
  `CatalogController#owned_quantities` chama `authenticated?` antes de ler
  `Current.user` por esse motivo.

## Comandos

Tudo roda em Docker; o Postgres não existe fora dele. A chave da apitcg é obrigatória
só para `ingestion:import` real; os testes usam um cliente HTTP falso e não a usam.

```bash
cp .env.example .env
# Depois de pôr a chave em `.env`, recrie o container (a variável passa como ENV):
docker compose up
docker compose exec app bin/rails test
docker compose exec app bin/rails test test/integration/sessions_test.rb
docker compose exec app bin/rails test test/models/user_password_test.rb -n "/senha/"
docker compose exec app bin/rubocop      # rubocop-rails-omakase
docker compose exec app bin/brakeman
docker compose exec app bin/rails db:prepare
```

Ingestão do catálogo — a chave da apitcg é lida de `APITCG_API_KEY` no `.env`:

```bash
# Busca na apitcg real (requer chave e conectividade)
docker compose exec app bin/rails ingestion:import

# Reprocessa um snapshot existente sem rede nem chave (útil offline ou para testar)
docker compose exec app bin/rails ingestion:import SNAPSHOT=storage/ingestion/apitcg-<UTC>.json

# Aponta coleção e wishlist para as variantes da fonte atual (sempre após import)
docker compose exec app bin/rails ingestion:remap

# Compara dois snapshots para medir estabilidade do tcgplayer.id (≥20h de diferença)
docker compose exec app bin/rails ingestion:compare_snapshots A=storage/ingestion/<arq-A> B=storage/ingestion/<arq-B>
```

Gem nova exige `docker compose run --rm --no-deps app bundle install`: o volume
nomeado `bundle` sombreia as gems da imagem, então rebuild **não** basta.

Gates da feature em execução (`.specs/features/fonte-apitcg/tasks.md`): **quick** =
`bin/rails test test/models test/queries`; **full** =
`bin/rails test && bin/rubocop`; **build** = `docker compose build`.

Verificação da fixture de ingestão, offline, sem Docker e sem Ruby — deve
continuar passando (19 verificações):

```bash
python3 spec/verify_fixture.py
```

Validadores do fluxo spec-driven:

```bash
SKILL=~/.claude/skills/tlc-spec-driven
python3 $SKILL/scripts/validate_spec.py  .specs/features/colecao/spec.md
python3 $SKILL/scripts/validate_tasks.py .specs/features/colecao/tasks.md
```

`Dockerfile.dev` é a imagem de desenvolvimento (código como volume); `Dockerfile`
é o de produção gerado pelo Rails — separados de propósito, não unificar.

## Método de trabalho: spec-driven

O fluxo é `requirements` → `design` → `tasks`, documentado em `.context/README.md`.
Regras que valem para qualquer sessão de trabalho aqui:

- **Tasks em ordem de dependência**, de `.context/tasks.md`. Não abrir uma task com
  alguma de que ela depende incompleta. Tasks independentes podem rodar em
  paralelo quando nenhuma dependência (`Depends on`) está pendente e os arquivos
  tocados (`Where`) não se sobrepõem; na dúvida, sequencial.
- **Toda task termina com código que roda e teste que passa.** "Estrutura criada"
  não conta como task concluída.
- **Se um requisito se mostrar errado durante a execução, pare e corrija
  `requirements.md`** antes de continuar. Não improvisar no código — corrigir só o
  código desalinha o spec e destrói o valor do método.
- Mudança de escopo volta ao documento de origem e se propaga para baixo.

### Dois diretórios de spec, de propósito

`.context/` é a **fonte de verdade** de requisitos, design e plano de tasks.
`.specs/` guarda o recorte por feature — `features/catalogo/` (encerrada) e
`features/colecao/` (em execução) —, o log de decisões (`STATE.md`, AD-001 a
AD-005) e os artefatos do Verifier. Em divergência, `.context/` vence (AD-005).
Os IDs de `.specs/` apontam para os requisitos numerados de
`.context/requirements.md`: `CAT-NN` e `T1`–`T14` no `catalogo`, `COL-NN` e
`T1`–`T13` na `colecao`. **Os dois planos numeram `T1` em diante e as numerações
não têm relação entre si** — sempre dizer de qual feature se fala.

**Ao concluir uma task, marcar o checkbox nos dois planos** (`.context/tasks.md` e
o `tasks.md` da feature em execução) e commitar junto com o código. Atenção ao
escopo de cada seção do `.context/tasks.md`: uma seção costuma cobrir várias
tasks do plano da feature e só fecha quando todas elas fecham — a §4.1 cobriu
T1–T4 e só foi marcada na T4. `STATE.md` tem a seção *Handoff* com o ponto exato
de retomada — ler antes de começar.

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
`.specs/STATE.md`. **Nenhuma bloqueia mais nada** — não reabrir sem motivo novo:

| # | Decisão | Onde |
|---|---------|------|
| P1 | Fonte = apitcg (`GET /api/one-piece/sets` e `/products?type=card`, header `x-api-key`) | **AD-019** |
| P2 | Campos/raridades/sets reais extraídos da fixture; glossário de `product.md` §6 corrigido | task 0.2 |
| P3 | "Set completo" = `baseSetSize` (variantes base); parallels em métrica separada | AD-003 |
| P4 | Rails 8 + Hotwire + PostgreSQL | AD-002 |
| P5 | `variant_code = "tcgplayer:<id>"`, ou `"apitcg:<_id>"` sem esse id | **AD-019** |
| P6 | App serve a imagem com cache em disco; host = `tcgplayer-cdn.tcgplayer.com` | **AD-019** |
| P7 | `DON!!` fora do catálogo na Fase 1 | task 0.2 |

A troca para a apitcg (AD-019) superou a AD-001. O `variant_code` agora vem do
`tcgplayer.id` da apitcg, com reserva para `apitcg:<_id>` quando o id não existe.
A estabilidade do `tcgplayer.id` entre buscas foi verificada em 2026-10-01:
0 mudados em 20h27m entre dois snapshots (7.252 comuns), fechando o SRC-31 com
a emenda de 20h no lugar de 24h (SRC-31, D-14).

A fixture `spec/fixtures/apitcg-subset.json` é versionada de propósito — é a entrada
dos testes de ingestão sem rede (Req. 11.5). Já `storage/ingestion/` (snapshots brutos
do Fetch) é ignorada pelo git: reconstruível a partir de `ingestion:import`.

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

Todo conhecimento sobre o formato da apitcg vive **no estágio Normalize e em nenhum
outro lugar** (`app/services/ingestion/apitcg/normalize.rb`). O estágio Fetch salva
o snapshot bruto em `storage/ingestion/apitcg-<UTC>.json` antes de normalizar —
é isso que permite reprocessar sem rede via `ingestion:import SNAPSHOT=` e transforma
o snapshot em fixture de teste (Req. 11.5). A apitcg não tem revisão imutável; o
snapshot em disco a substitui.

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
- `rarity` como **texto, não enum** — o snapshot da apitcg traz `C UC R SR PR L
  SEC TR`, mas a fonte é um agregador comunitário: enum faz a ingestão explodir
  no dia em que aparecer um valor novo.
- `variant_code` precisa ser **estável entre execuções**, senão a idempotência
  quebra e o usuário perde o vínculo com a coleção. Hoje ele é `"tcgplayer:<id>"`
  do campo `markets.tcgplayer.id` da apitcg, ou `"apitcg:<_id>"` quando aquele não
  existe. A estabilidade deste id foi verificada em 2026-10-01: 0 mudados em 20h27m (SRC-31, D-14).

### Revisão por subagente

**Não existe `ruby-reviewer` nem `rails-reviewer`** entre os agentes instalados
(Python, Go, Rust, Java, PHP, TypeScript, React, Django, FastAPI — Ruby não), daí
a revisão sair sempre pelos agentes agnósticos de linguagem. Cada feature tem seu
plano na seção "Plano de delegação" do próprio `tasks.md`. Na `colecao`:
`ecc:security-reviewer` no concern e no controller de sessão (feito na Fase 1),
`ecc:database-reviewer` nas constraints e no plano de execução,
`ecc:a11y-architect` nos controles de posse, `ecc:pr-test-analyzer` nos testes de
isolamento e wishlist.

Coletas mecânicas — ler arquivo, listar símbolo, extrair formato — vão para
subagentes Haiku com prompt fechado e **leitura apenas**. Decisão de design e
resolução de colisão ficam com o orquestrador.

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
