# Decks (Fase 2) — Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Spec**: `.specs/features/decks/spec.md` (DCK-01..DCK-44, Req. 14)
**Design**: `.specs/features/decks/design.md` (aprovado; deck em edição na sessão)
**Status**: Approved (dono, 2026-10-02)

Regras que valem para todas as tasks:

- A numeração T1–T21 é **desta feature** e não tem relação com a das outras.
- Nenhum teste desta feature altera `collection_items` ou `wishlist_items` fora do próprio setup. Excluir deck nunca toca a coleção (DCK-09).
- Todo acesso a deck parte de `Current.user.decks`, nunca de um `user_id` vindo do request (Req. 6.5).
- Não há navegador no container, então teste de UI é integração sobre o HTML renderizado (`SPEC_DEVIATION` do projeto). Tasks de layout anexam capturas (AD-015) como evidência, não como gate.
- Proibido `git add -A`, `git add .`, `git stash`, `reset`, `rebase`, `checkout` e worktree. O worker não marca checkbox: quem marca, neste arquivo e em `.context/tasks.md` §9, é o orquestrador, no commit da task.

---

## Test Coverage Matrix

> Generated from codebase, project guidelines, and spec. Guidelines found: `CLAUDE.md` (gates quick/full/build, sem system test), `.github/workflows/ci.yml` (rubocop, brakeman, `bin/rails test`). Não há limiar de cobertura configurado, então valem os defaults fortes.

| Camada | Tipo de teste | Cobertura esperada | Onde | Comando |
|---|---|---|---|---|
| Schema (migração, CHECK, UNIQUE, FK) | unit (Minitest com banco, SQL direto) | Cada constraint provada no banco contornando o model (`insert_all`, `update_all`, SQL), como em `test/models/collection_item_test.rb` | `test/models/deck_schema_test.rb` | `bin/rails test test/models` |
| Model (`Deck`, `DeckEntry`) | unit | Validações, associações, `ordered_entries`, `main_total` | `test/models/deck_test.rb`, `test/models/deck_entry_test.rb` | `bin/rails test test/models` |
| Domínio puro (`Deck::Legality`, `Deck::ListText`) | unit | Todos os ramos; 1:1 com os DCK da task; todo edge case listado | `test/models/deck/*_test.rb` | `bin/rails test test/models` |
| Query object (`DeckShortfallQuery`) | unit (com banco) | 1:1 com DCK-20..23 e DCK-33; isolamento entre usuários; número fixo de consultas | `test/queries/deck_shortfall_query_test.rb` | `bin/rails test test/queries` |
| Controller + view | integration (HTML renderizado) | Toda rota da task: caminho feliz, sem sessão (DCK-37), deck de outro usuário (DCK-36) e os erros da task | `test/integration/deck*_test.rb` | `bin/rails test test/integration` |
| CSS / layout | design (teste que lê as regras de CSS, como os de `test/design/`) | 360px sem scroll horizontal (Req. 2.5) e classes cobertas (`class_coverage_test.rb`) | `test/design/deck*_test.rb` | `bin/rails test test/design` |
| Documentação | none | Conferência por `grep` registrada no commit | — | gate full |

## Gate Check Commands

Todos rodam com o container `app` no ar (`docker compose up -d`). Se o Docker do host exigir, vale prefixar `DOCKER_CONFIG=/tmp/claude-1000/bindr-dockercfg`.

| Gate | Quando | Comando |
|---|---|---|
| quick | Tasks só de model, domínio ou query | `docker compose exec -T app bin/rails test test/models test/queries` |
| full | Qualquer task com controller, view, CSS ou doc | `docker compose exec -T app bin/rails test && docker compose exec -T app bin/rubocop && docker compose exec -T app bin/brakeman --no-pager` |
| build | Fim de cada phase | `docker compose build` + gate full |

Toda task registra no commit a contagem de runs do gate. Essa contagem nunca cai.

---

## Execution Plan

As fases rodam em sequência, e as tasks dentro de cada fase também.

### Phase 1: Regras, schema e domínio

Nada de HTTP. A fase fecha com todo o domínio coberto por teste de unidade.

```
T1 → T4
T2 → T3 → T4
T3 → T5
T3 → T6 → T7
T5 → T22
```

A T22 (correções da revisão de banco do Lote A) entrou depois do lote e roda antes da T8.

### Phase 2: Telas do deck e montagem pelo detalhe

```
T8 → T9 → T10
T8 → T11
T8 → T12 → T13 → T14 → T15
T15 → T23 → T24
```

T23 e T24 (correções das revisões de segurança, banco e a11y do Lote B) entraram depois do lote e rodam antes da T16.

### Phase 3: Lista em texto, pasta e fechamento

```
T16 → T17 → T18 → T19 → T20 → T21
```

---

## Task Breakdown

### T1: Confirmar no Rule Manual as regras marcadas ⚠️ VERIFICAR

**What**: Ler o Rule Manual oficial (`en.onepiece-cardgame.com/pdf/rule_manual.pdf`) e resolver duas linhas de *Assumptions*: (a) se a carta multicolorida do deck principal precisa ter **todas** as cores no Leader ou se basta **uma**; (b) se existe carta cujo texto permite mais de 4 cópias. Registrar seção e página no spec, no Req. 14 e no `.context/design.md` §10, trocando o ⚠️ por "Confirmado".
**Where**: `.specs/features/decks/spec.md`
**Depends on**: None
**Reuses**: a confirmação do Play Guide já registrada no `.context/design.md` §10
**Requirement**: DCK-12, DCK-13, DCK-16

**Tools**:

- MCP: NONE (WebFetch e WebSearch para o PDF)
- Skill: NONE

**Done when**:

- [x] As duas perguntas têm resposta com citação (seção e página do Rule Manual) no spec, no Req. 14 e no `design.md` §10
- [x] Se (a) der "basta uma cor" ou se (b) achar exceção, o critério do spec e o Req. 14 são emendados **antes** da T4, e o dono é avisado (regra de requisito errado do `CLAUDE.md`)
- [x] Se o PDF não puder ser lido, a task para e volta ao dono, sem chute (lido: Rule Manual e Comprehensive Rules v1.2.1)
- [x] `validate_spec.py` sai 0; o gate full passa com a contagem inalterada

**Tests**: none
**Gate**: full
**Commit**: `docs(decks): confirmar no Rule Manual as regras de cor e de cópias`

---

### T2: Migração `CreateDecks`

**What**: Tabelas `decks` e `deck_entries` como em *Data Models* do `design.md`: CHECK do nome (1..60), CHECK da quantidade (1..50), `UNIQUE (deck_id, card_id)`, FKs para `users` e `cards` com `ON DELETE RESTRICT` e `deck_entries.deck_id` com `ON DELETE CASCADE`. O `db:migrate` regenera `db/structure.sql`.
**Where**: `db/migrate/20261002120000_create_decks.rb`
**Depends on**: None
**Reuses**: `db/migrate/20260919120200_create_collection_tables.rb`
**Requirement**: DCK-02, DCK-39, DCK-40

**Tools**:

- MCP: NONE
- Skill: NONE (revisão por `ecc:database-reviewer`)

**Done when**:

- [x] O teste prova pelo banco, sem passar pelo model: a segunda entrada com o mesmo `(deck, card)` dá `RecordNotUnique`; quantidade 0 e 51 violam o CHECK; nome vazio e nome de 61 caracteres violam o CHECK
- [x] O teste prova que `DELETE FROM cards` falha por FK quando a carta é Leader ou está numa entrada, e que `DELETE FROM decks` apaga só as entradas daquele deck
- [x] `db/structure.sql` regenerado e commitado junto
- [x] Gate quick passa; contagem registrada

**Tests**: unit
**Gate**: quick
**Commit**: `feat(decks): criar as tabelas de deck com as constraints no banco`

---

### T3: Models `Deck` e `DeckEntry`

**What**: `Deck` tem `belongs_to :user`, `leader` opcional, `has_many :entries`, `normalizes :name`, validação de tamanho do nome, exigência de que o Leader tenha `card_type == "leader"`, `ordered_entries` e `main_total`. `DeckEntry` exige quantidade de 1 a 50 e carta que não seja Leader. `User` ganha `has_many :decks, dependent: :restrict_with_exception`.
**Where**: `app/models/deck.rb`, `app/models/deck_entry.rb`, `app/models/user.rb`
**Depends on**: T2
**Reuses**: `app/models/collection_item.rb` (estilo de validação e escopo por usuário)
**Requirement**: DCK-02, DCK-07 (ordem), DCK-39

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Nome com espaços nas bordas é gravado sem eles; nome vazio e nome de 61 caracteres são inválidos, com mensagem em português
- [x] Leader que não é `leader` é inválido; entrada com carta Leader é inválida
- [x] `ordered_entries` devolve character, event e stage, nessa ordem; dentro de cada tipo, custo crescente com nulos por último e depois `card_number`
- [x] `main_total` soma as quantidades das entradas e não conta o Leader
- [x] Gate quick passa; contagem registrada

**Tests**: unit
**Gate**: quick
**Commit**: `feat(decks): adicionar os models de deck e de entrada`

---

### T4: `Deck::Legality`

**What**: Função pura `Deck::Legality.call(leader:, entries:)` que devolve `Result(status:, reasons:, warnings:)` com as regras confirmadas na T1, `Deck#legality` delegando a ela, e os predicados `Card#unlimited_copies?` e `Card#own_deck_rule` sobre `effect_text`.
**Where**: `app/models/deck/legality.rb`, `app/models/card.rb`
**Depends on**: T1, T3
**Reuses**: `Card#colors`, `Card#card_number`, `Card#effect_text` (sem HTML desde `normalize.rb:263-273`)
**Requirement**: DCK-11, DCK-12, DCK-13, DCK-14, DCK-15, DCK-16, DCK-18, DCK-42, DCK-43, DCK-44

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Leader com 50 cartas das cores dele, nenhuma acima de 4 cópias → `valid`, sem motivos
- [x] Com 49 cartas → `incomplete`, com o motivo de quantas faltam (texto exato fixado no teste a partir dos exemplos do DCK-15); sem Leader → `incomplete`, com o motivo do Leader
- [x] Com 51 cartas, com 5 cópias de uma carta ou com carta de cor fora do Leader → `invalid`, cada caso com seu motivo e o `card_number` envolvido
- [x] Com 51 cartas e sem Leader → `invalid`, mostrando os dois motivos
- [x] Sem Leader, carta de qualquer cor não gera motivo de cor (DCK-42)
- [x] A carta multicolorida segue a regra da T1 nos dois sentidos: uma cor fora gera motivo, todas dentro não
- [x] Carta com "you may have any number of this card in your deck" no `effect_text` (texto real de OP01-075) aceita 8 cópias sem motivo; a mesma quantidade de uma carta sem a frase gera motivo (DCK-43)
- [x] Leader com regra própria (textos reais de OP12-001, OP13-079 e P-117) gera um aviso com a frase da regra, e o status continua `valid` num deck de 50 cartas; Leader sem a frase não gera aviso, nem um "Under the rules of this game" que não fala do deck (texto de OP15-058) (DCK-44)
- [x] Nenhum status é gravado: `decks` não tem coluna de status (DCK-11)
- [x] Gate quick passa; contagem registrada

**Tests**: unit
**Gate**: quick
**Commit**: `feat(decks): calcular o status do deck pelas regras de montagem`

---

### T5: `DeckShortfallQuery`

**What**: Consulta única que devolve, por carta, `required`, `owned`, `missing` e `deck_ids`, para um deck (`deck:`) ou para todos os decks do usuário (`MAX` entre eles). O Leader conta como 1.
**Where**: `app/queries/deck_shortfall_query.rb`
**Depends on**: T3
**Reuses**: o estilo de `app/queries/set_progress_query.rb`
**Requirement**: DCK-20, DCK-21, DCK-22, DCK-23, DCK-33

**Tools**:

- MCP: NONE
- Skill: NONE (revisão por `ecc:database-reviewer`)

**Done when**:

- [x] Com 2 cópias da base e 1 da parallel, e um deck pedindo 4 → `required 4, owned 3, missing 1` (Independent Test do P1)
- [x] Variante ausente da fonte conta como possuída (DCK-20)
- [x] Possuir mais do que o pedido dá `missing 0`, nunca negativo
- [x] Dois decks pedindo 4 e 2 da mesma carta, com 1 possuída → `missing 3` e os dois `deck_ids` (DCK-33)
- [x] A coleção de outro usuário não conta; `user` nil devolve vazio
- [x] Mudar a coleção muda o resultado na chamada seguinte, sem gravar nada (DCK-23)
- [x] A chamada roda numa consulta só (contada no teste), com 1 deck e com 3
- [x] Gate quick passa; contagem registrada

**Tests**: unit
**Gate**: quick
**Commit**: `feat(decks): cruzar os decks com a coleção numa consulta`

---

### T6: `Deck::ListText.parse`

**What**: Leitura do formato do OPTCG Simulator, tudo ou nada, devolvendo `leader`, `entries` e `errors` por linha.
**Where**: `app/models/deck/list_text.rb`
**Depends on**: T3
**Reuses**: a busca de `card_number` em caixa alta, como na busca exata do `CatalogQuery`
**Requirement**: DCK-25, DCK-26, DCK-27, DCK-28, DCK-29

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] O exemplo do dono (15 linhas separadas por CR, Leader OP17-079) vira 1 Leader + 50 cartas, sobre uma fixture de teste com essas cartas
- [x] CR, LF, CRLF e a mistura deles dão o mesmo resultado; linhas em branco e espaços nas bordas e ao redor do `x` são ignorados; `op17-079` casa com `OP17-079`
- [x] Linhas repetidas somam numa entrada
- [x] Cada recusa gera um erro com número da linha e motivo em português: formato errado, `card_number` inexistente, quantidade 0 ou 51, dois Leaders, Leader com quantidade 2
- [x] Texto com 201 linhas ou com 10.001 caracteres é recusado sem consultar o banco (0 consultas)
- [x] A busca das cartas é uma consulta só, qualquer que seja o número de linhas
- [x] Gate quick passa; contagem registrada

**Tests**: unit
**Gate**: quick
**Commit**: `feat(decks): ler a lista do OPTCG Simulator`

---

### T7: `Deck::ListText.format` e ida e volta

**What**: Escrita do deck no formato do simulador (Leader primeiro, depois `ordered_entries`, linhas separadas por LF) e o teste de ida e volta.
**Where**: `app/models/deck/list_text.rb`
**Depends on**: T6
**Reuses**: `Deck#ordered_entries` (T3)
**Requirement**: DCK-31, DCK-32

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] A primeira linha é `1x<leader>`; as seguintes seguem `ordered_entries`; o separador é `"\n"` e o texto não tem `"\r"`
- [x] Deck sem Leader exporta só as entradas
- [x] `parse(format(deck))` devolve o mesmo Leader e as mesmas entradas, tanto para o deck do exemplo do dono quanto para um deck com cartas de custo nulo
- [x] Gate quick passa; contagem registrada

**Tests**: unit
**Gate**: quick
**Commit**: `feat(decks): exportar o deck no formato do OPTCG Simulator`

---

### T22: Correções da revisão de banco do Lote A

**What**: Fechar os achados de `ecc:database-reviewer` sobre T2 e T5: (M1) provar o filtro de usuário e de deck no ramo Leader da `DeckShortfallQuery`; (M2) provar os índices `decks(user_id)`, `decks(leader_card_id)`, `deck_entries(card_id)` e o único `(deck_id, card_id)`; (L3) registrar no cabeçalho da query a invariante "Leader nunca é entrada do mesmo deck", garantida por `DeckEntry`; (L4) afirmar `required = 1` e os dois `deck_ids` no teste do Leader em dois decks; (L5) comentário de nome `-- listDeckShortfall` na primeira linha do SQL (convenção do projeto); (L6) asserções de FK com o nome da constraint ou coluna.
**Where**: `test/queries/deck_shortfall_query_test.rb`, `test/models/deck_schema_test.rb`, `app/queries/deck_shortfall_query.rb`
**Depends on**: T5
**Reuses**: `pg_indexes` / `connection.index_exists?`
**Requirement**: DCK-02, DCK-21, DCK-33, DCK-36

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Remover `AND decks.user_id = :user_id` ou o filtro de deck do ramo Leader faz um teste falhar (verificado aplicando a mutação numa cópia e descartando)
- [x] Remover qualquer um dos quatro índices da migração faz um teste falhar
- [x] L3–L6 aplicados; `deck_shortfall_query.rb` muda só em comentário
- [x] Gate quick passa; contagem registrada, sem queda

**Tests**: unit
**Gate**: quick
**Commit**: `test(decks): cobrir o ramo Leader da falta e os índices do deck`

---

### T8: Rotas, lista e criação de deck

**What**: `resources :decks`, com `delete` e `select` como membros; `DecksController#index`, `#new` e `#create`; views `index` e `new`; e o link "Baralhos" na navegação, entre "Minha pasta" e "Sair". `create` cria o deck vazio e abre a página dele, que fica mínima até a T9.
**Where**: `app/controllers/decks_controller.rb`, `config/routes.rb`, `app/views/decks/index.html.erb`, `app/views/decks/new.html.erb`, `app/views/layouts/application.html.erb`
**Depends on**: None (a Phase 1 inteira fecha antes; a lista usa `Deck#legality` da T4)
**Reuses**: `nav_link_to` e o layout (`application.html.erb:26-43`)
**Requirement**: DCK-01, DCK-08, DCK-36, DCK-37, DCK-39

**Tools**:

- MCP: NONE
- Skill: NONE (revisão por `ecc:security-reviewer` do escopo por usuário)

**Done when**:

- [x] Criar com um nome gera um deck sem Leader e sem entradas, do usuário da sessão, e redireciona para ele
- [x] Nome vazio ou de 61 caracteres re-renderiza com 422 e mensagem em português, sem criar nada
- [x] A lista mostra só os decks do usuário, cada um com nome, Leader (ou "Sem Leader"), "N / 50" e status em português
- [x] Sem sessão, toda rota redireciona para o login sem criar nada; deck de outro usuário dá 404
- [x] "Baralhos" aparece na navegação só com sessão e tem `aria-current` na lista de decks
- [x] Gate full passa; contagem registrada

**Tests**: integration
**Gate**: full
**Commit**: `feat(decks): listar e criar decks`

---

### T9: Página do deck: composição e status

**What**: `DecksController#show` em HTML, com o Leader, as entradas agrupadas em Character, Event e Stage na ordem de `ordered_entries`, "N / 50", o status com os motivos, o aviso "A lista de banidas não é verificada", o aviso de regra própria do Leader e a marca "fora da fonte".
**Where**: `app/views/decks/show.html.erb`
**Depends on**: T8
**Reuses**: `Deck#legality` (T4) e `CardVariant::PRESENT_SQL` para "fora da fonte"
**Requirement**: DCK-07, DCK-15, DCK-17, DCK-19, DCK-44

**Tools**:

- MCP: NONE
- Skill: NONE (revisão por `ecc:a11y-architect`)

**Done when**:

- [x] Com fixture de Leader e entradas dos três tipos, o HTML mostra os grupos na ordem, e dentro de cada um a ordem é custo e depois `card_number`
- [x] "N / 50" segue `main_total`, e o status aparece em português (`válido`, `incompleto`, `inválido`)
- [x] Status diferente de `válido` mostra cada motivo; `válido` não mostra nenhum
- [x] O aviso de banidas aparece sempre
- [x] Com Leader de regra própria, aparece "Este Leader tem regra de montagem própria, não verificada" com o texto da regra; com Leader sem regra, não aparece
- [x] Carta sem variante presente aparece marcada "fora da fonte" e continua contando no total
- [x] O número de consultas da página não cresce com o número de entradas
- [x] Gate full passa; contagem registrada

**Tests**: integration
**Gate**: full
**Commit**: `feat(decks): mostrar a composição e o status do deck`

---

### T10: Página do deck: o que falta na pasta

**What**: Na página do deck, as colunas pedida, possuída e falta para o Leader e para cada entrada, mais o total que falta ou "Você tem todas as cartas deste deck".
**Where**: `app/views/decks/show.html.erb`
**Depends on**: T9
**Reuses**: `DeckShortfallQuery` (T5)
**Requirement**: DCK-21, DCK-22, DCK-23

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] O cenário do Independent Test (2 base + 1 parallel, deck pedindo 4) mostra "pedida 4, possuída 3, falta 1"
- [x] O total soma o que falta de todas as cartas, Leader incluído; com total zero, a página mostra "Você tem todas as cartas deste deck"
- [x] Incrementar a coleção entre duas leituras muda o que falta na segunda
- [x] Gate full passa; contagem registrada

**Tests**: integration
**Gate**: full
**Commit**: `feat(decks): mostrar no deck o que falta na pasta`

---

### T11: Renomear e excluir

**What**: `edit` e `update` para renomear; `delete` (página de confirmação) e `destroy` para excluir.
**Where**: `app/controllers/decks_controller.rb`, `app/views/decks/edit.html.erb`, `app/views/decks/delete.html.erb`
**Depends on**: T8
**Reuses**: a confirmação em página própria de `collection_imports/show.html.erb`
**Requirement**: DCK-09, DCK-10, DCK-36, DCK-39

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Renomear grava o nome novo e mantém Leader e entradas; nome inválido dá 422 sem gravar
- [x] `GET /decks/:id/delete` mostra a confirmação sem apagar nada; `DELETE` apaga o deck e as entradas dele
- [x] Excluir não muda nenhum `collection_item` nem `wishlist_item` (`assert_no_changes` sobre os dois)
- [x] Renomear ou excluir deck de outro usuário dá 404 sem alterar nada
- [x] Gate full passa; contagem registrada

**Tests**: integration
**Gate**: full
**Commit**: `feat(decks): renomear e excluir deck com confirmação`

---

### T12: Deck em edição

**What**: Concern `EditingDeck` com `editing_deck`, que lê `session[:editing_deck_id]` só depois de `authenticated?`, revalida por `Current.user.decks.find_by` e limpa a chave quando não acha o deck. Rota `POST /decks/:id/select`. `create` passa a marcar o deck criado como em edição. A página do deck mostra "Editar este deck" ou "Em edição".
**Where**: `app/controllers/concerns/editing_deck.rb`, `app/controllers/decks_controller.rb`
**Depends on**: T8
**Reuses**: `Authentication#authenticated?`
**Requirement**: DCK-41, DCK-36

**Tools**:

- MCP: NONE
- Skill: NONE (revisão por `ecc:security-reviewer`)

**Done when**:

- [x] Criar um deck o deixa em edição; `select` troca o deck em edição
- [x] `select` de deck de outro usuário dá 404 e não altera a sessão
- [x] Depois de excluído o deck em edição, `editing_deck` devolve `nil` e a chave sai da sessão
- [x] Um id de deck de outro usuário posto na sessão (simulado no teste) não é aceito
- [x] Gate full passa; contagem registrada

**Tests**: integration
**Gate**: full
**Commit**: `feat(decks): guardar na sessão o deck em edição`

---

### T13: Incrementar e decrementar carta no deck

**What**: `DeckEntriesController#increment` e `#decrement`, com o SQL do `design.md`, resposta HTML (`redirect_back`) e Turbo Stream sobre `dom_id(card, :deck_entry)`, mais a partial `decks/_card_controls` que o Stream renderiza.
**Where**: `app/controllers/deck_entries_controller.rb`, `app/views/decks/_card_controls.html.erb`, `config/routes.rb`
**Depends on**: T12
**Reuses**: `CollectionItemsController` (`execute_returning_quantity`, `respond_with_quantity`)
**Requirement**: DCK-05, DCK-06, DCK-18, DCK-36, DCK-37, DCK-38, DCK-39

**Tools**:

- MCP: NONE
- Skill: NONE (revisão por `ecc:database-reviewer` do SQL e da corrida)

**Done when**:

- [x] O incremento de carta nova cria a entrada com 1, o seguinte leva a 2, e a 5ª cópia é aceita e gravada (DCK-18)
- [x] Em 50, o incremento é recusado com alerta em português e a quantidade fica em 50
- [x] O decremento leva 2 a 1, e em 1 remove a entrada; sem entrada, nada é criado
- [x] Carta Leader enviada a `increment` dá 422 sem gravar
- [x] Com `Accept: text/vnd.turbo-stream.html`, a resposta é um `turbo-stream` que atualiza o alvo com a quantidade nova; sem esse header, redireciona
- [x] Duas threads incrementando a mesma carta ao mesmo tempo terminam em 2 (DCK-38), e duas decrementando a partir de 2 terminam sem entrada
- [x] Deck de outro usuário dá 404 sem gravar; sem sessão, redireciona sem gravar
- [x] Gate full passa; contagem registrada

**Tests**: integration
**Gate**: full
**Commit**: `feat(decks): incrementar e decrementar carta no deck`

---

### T14: Usar como Leader

**What**: `POST /decks/:deck_id/leader` com `card_id`, que grava ou substitui o Leader, com resposta HTML e Turbo Stream.
**Where**: `app/controllers/deck_entries_controller.rb`
**Depends on**: T13
**Reuses**: a resposta dupla da T13
**Requirement**: DCK-04, DCK-36

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Usar um Leader num deck sem Leader grava; usar outro o substitui, sem mudar as entradas
- [x] Carta que não é Leader dá 422 sem gravar
- [x] Deck de outro usuário dá 404 sem gravar
- [x] Gate full passa; contagem registrada

**Tests**: integration
**Gate**: full
**Commit**: `feat(decks): escolher o Leader do deck`

---

### T15: Controle de deck no detalhe da carta

**What**: `CatalogController#show` expõe `@editing_deck` e a quantidade da carta nele (uma consulta), e `catalog/show.html.erb` renderiza `decks/_card_controls`: `− N +` para carta comum, "Usar como Leader" para Leader, e o nome do deck em edição com link para ele.
**Where**: `app/views/catalog/show.html.erb`, `app/controllers/catalog_controller.rb`
**Depends on**: T14
**Reuses**: `EditingDeck` (T12), `_card_controls` (T13)
**Requirement**: DCK-03, DCK-04, DCK-41

**Tools**:

- MCP: NONE
- Skill: NONE (revisão por `ecc:a11y-architect`: nome acessível do `−` e do `+`, como no controle de posse)

**Done when**:

- [x] Com sessão e deck em edição, a carta comum mostra o controle com a quantidade atual (0 sem entrada) e o nome do deck
- [x] Com sessão e deck em edição, a carta Leader mostra "Usar como Leader" no lugar do `− N +`
- [x] Sem sessão, sem deck em edição ou com o deck em edição excluído, o detalhe responde 200 sem controle de deck
- [x] Os controles de posse da coleção não mudam: os testes existentes do detalhe passam sem edição
- [x] Gate full passa; contagem registrada

**Tests**: integration
**Gate**: full
**Commit**: `feat(decks): montar o deck pelo detalhe da carta`

---

### T23: Robustez do deck sob corrida e entrada malformada

**What**: Fechar os achados das revisões do Lote B: (DB-H1) o teste de corrida força a sobreposição — uma terceira conexão segura a linha com `SELECT ... FOR UPDATE` numa transação aberta, os dois POSTs são disparados, o teste espera ambos bloqueados em `pg_stat_activity` (`wait_event_type = 'Lock'`) e só então libera — e ganha os casos 49 + 49 → 50 com um recusado e incremento ∥ decremento a partir de 1; (DB-M2) `ActiveRecord::InvalidForeignKey` no `DeckEntriesController` vira 404, não 500 (deck excluído em corrida); (DB-M3) as três leituras do `DecksController#show` rodam numa transação `REPEATABLE READ`, sem `KeyError` com um decremento concorrente; (SEC-L1) `card_id` não escalar (`card_id[]=`) dá 404 em vez de 500; (DB-L6) binds de id como `BigInteger` aqui e em `collection_items_controller.rb`; (DB-L7) teste de corrida com nomes únicos por execução e teardown tolerante a setup parcial; (DB-L4) a janela do decremento em duas etapas fica anotada no cabeçalho do controller.
**Where**: `app/controllers/deck_entries_controller.rb`, `app/controllers/decks_controller.rb`, `app/controllers/collection_items_controller.rb`, `test/integration/deck_entries_concurrency_test.rb`
**Depends on**: T15
**Reuses**: `pg_stat_activity`, `Deck.transaction(isolation: :repeatable_read)`
**Requirement**: DCK-36, DCK-38, DCK-39

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Com o incremento trocado por leitura em Ruby + `update!` (mutação numa cópia, descartada), o teste de corrida falha em toda execução, não às vezes
- [x] Dois incrementos simultâneos a partir de 49 terminam em 50, e exatamente um recebe a recusa
- [x] Incremento contra deck apagado depois do `find` responde 404 sem 500 (teste que apaga o deck entre o `find` e o SQL)
- [x] A página do deck não levanta erro quando a entrada some entre as leituras (teste que provoca a corrida ou que prova a transação `REPEATABLE READ`)
- [x] `card_id[]=1&card_id[]=2` em `leader`, `increment` e `decrement` dá 404
- [x] Os testes existentes de coleção passam sem edição
- [x] Gate full passa 3 vezes seguidas; contagem registrada

**Tests**: integration
**Gate**: full
**Commit**: `fix(decks): resistir a corrida e a parâmetro malformado no deck`

---

### T24: Acessibilidade das telas de deck

**What**: Fechar os achados de `ecc:a11y-architect` no markup: (H2) "Usar como Leader" não tira o foco do DOM — o botão continua após a troca, com `aria-disabled="true"` e o texto "é o Leader deste deck", no padrão do controle de posse; (M3) o erro do nome fica associado ao campo (`aria-invalid`, `aria-describedby="deck-name-error"`) e ganha ajuda "até 60 caracteres"; (M4) a região viva do `_card_controls` envolve só a frase da quantidade ("N cópias de <carta> no deck"), e o sucesso é anunciado por um canal só; (M5) o controle do detalhe fica numa `section` com `h2` "Deck em edição"; (L8) "carta fora da fonte"; (L10) tipos em português no agrupamento: "Personagens", "Eventos", "Locais".
**Where**: `app/views/decks/_card_controls.html.erb`, `app/views/decks/_name_form.html.erb`, `app/views/decks/show.html.erb`, `app/controllers/deck_entries_controller.rb`
**Depends on**: T23
**Reuses**: `app/views/collection_items/_ownership.html.erb` (`aria-disabled`, região viva)
**Requirement**: DCK-03, DCK-04, DCK-05, DCK-07, DCK-19, DCK-39

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] A resposta Turbo Stream de `leader` contém o botão com `aria-disabled="true"`, sem remover o elemento focável
- [x] Com nome inválido, o campo tem `aria-invalid="true"` e `aria-describedby` apontando para o id da mensagem; sem erro, nenhum dos dois
- [x] Exatamente uma região viva anuncia a quantidade nova, e ela não contém botões nem links
- [x] O detalhe com deck em edição tem `section` com `aria-labelledby` para um `h2` "Deck em edição"
- [x] A página do deck agrupa em "Personagens", "Eventos" e "Locais", e a marca diz "carta fora da fonte"
- [x] Testes ajustados só onde o texto do critério mudou, cada um listado no corpo do commit
- [x] Gate full passa; contagem registrada

**Tests**: integration
**Gate**: full
**Commit**: `fix(decks): ajustar foco, anúncios e rótulos das telas de deck`

---

### T16: Exportar o deck

**What**: `GET /decks/:id.txt` responde `text/plain; charset=utf-8` com `Deck::ListText.format`, e a página do deck ganha o link "Exportar lista".
**Where**: `app/controllers/decks_controller.rb`
**Depends on**: None (a Phase 2 inteira, com T23 e T24, fecha antes)
**Reuses**: `Deck::ListText.format` (T7)
**Requirement**: DCK-31, DCK-36

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] O corpo é igual a `Deck::ListText.format(deck)`, sem `\r`, com tipo `text/plain`
- [x] Deck de outro usuário dá 404; sem sessão, redireciona
- [x] Gate full passa; contagem registrada

**Tests**: integration
**Gate**: full
**Commit**: `feat(decks): exportar a lista do deck em texto`

---

### T17: Importar lista

**What**: `DeckImportsController#new` e `#create` (`/decks/import`), com nome opcional e `<textarea>`. No sucesso, cria o deck numa transação, marca como em edição e redireciona para ele. No erro, re-renderiza com 422 e a lista de linhas recusadas. A lista de decks ganha o link "Importar lista".
**Where**: `app/controllers/deck_imports_controller.rb`, `app/views/deck_imports/new.html.erb`, `config/routes.rb`
**Depends on**: T16
**Reuses**: `Deck::ListText.parse` (T6), `EditingDeck` (T12)
**Requirement**: DCK-24, DCK-26, DCK-27, DCK-28, DCK-29, DCK-30, DCK-32

**Tools**:

- MCP: NONE
- Skill: NONE (revisão por `ecc:silent-failure-hunter` do tudo-ou-nada)

**Done when**:

- [x] O exemplo do dono importa num deck com Leader OP17-079 e 50 cartas; sem nome informado, o deck leva o nome do Leader
- [x] Importar duas vezes cria dois decks sem alterar o primeiro (DCK-24)
- [x] Uma linha ruim entre linhas boas não cria deck nem entrada (`assert_no_difference` em `Deck` e `DeckEntry`) e mostra "Linha N: motivo" para cada linha ruim
- [x] Texto acima do limite dá 422 com o limite na mensagem
- [x] Lista sem nenhuma carta (vazia ou só linhas em branco) dá 422 com "A lista não tem nenhuma carta", sem criar deck (DCK-28)
- [x] Lista aceita com 5 cópias de uma carta cria o deck, e a página dele mostra `inválido` (DCK-30)
- [x] Exportar (T16) e reimportar o texto dá um deck com o mesmo Leader e as mesmas entradas (DCK-32, ponta a ponta)
- [x] Sem sessão, redireciona sem criar nada
- [x] Gate full passa; contagem registrada

**Tests**: integration
**Gate**: full
**Commit**: `feat(decks): importar a lista do OPTCG Simulator num deck novo`

---

### T18: "Faltando para os baralhos" na pasta

**What**: Partial `decks/_shortfall` no topo de `progress__secondary`, com cada carta que falta (nome, `card_number`, "faltam N") e links para os decks que a usam. Sem decks, ou sem nada faltando, o bloco não aparece.
**Where**: `app/views/decks/_shortfall.html.erb`, `app/views/progress/index.html.erb`, `app/controllers/progress_controller.rb`
**Depends on**: T17
**Reuses**: `DeckShortfallQuery` sem `deck:` (T5); a composição do canvas (`navegacao/canvas/Desktop-Pasta.dc.html:126-140`), sem o preço (Fase 3)
**Requirement**: DCK-33, DCK-34, DCK-35

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Dois decks pedindo 4 e 2 da mesma carta, com 1 possuída, mostram "faltam 3" e links para os dois decks
- [x] Sem decks, ou com tudo possuído, o HTML não tem o bloco nem um título vazio
- [x] Os testes existentes da pasta passam sem edição, exceto `set_progress_plan_test.rb`, que passa de 2 para 3 consultas com a `listDeckShortfall` nomeada (AD-021)
- [x] Gate full passa; contagem registrada

**Tests**: integration
**Gate**: full
**Commit**: `feat(decks): mostrar na pasta o que falta para os decks`

---

### T19: Ingestão preserva os decks

**What**: Estender o teste de garantias da ingestão: com um deck povoado (Leader e entradas), rodar a ingestão duas vezes sobre a fixture e verificar que Leader, entradas e quantidades ficam intactos.
**Where**: `test/services/ingestion/guarantees_test.rb`
**Depends on**: T18
**Reuses**: o teste da task 2.6 da Fase 1, no mesmo arquivo
**Requirement**: DCK-40

**Tools**:

- MCP: NONE
- Skill: NONE (revisão por `ecc:pr-test-analyzer`)

**Done when**:

- [x] Duas ingestões sobre a fixture não mudam `leader_card_id` nem nenhum par `(card_id, quantity)` do deck
- [x] Uma carta do deck ausente do snapshot continua no deck (a ingestão não apaga)
- [x] Gate full passa; contagem registrada

**Tests**: unit
**Gate**: full
**Commit**: `test(decks): provar que a ingestão não toca os decks`

---

### T20: Layout das telas de deck a 360px

**What**: CSS das telas de deck e do controle no detalhe com os tokens do `.context/design.md` §11, sem scroll horizontal a 360px, mais capturas de antes e depois (`spec/visual/capture.cjs`) em 390px e 1280px.
**Where**: `app/assets/stylesheets/application.css`
**Depends on**: T19
**Reuses**: os tokens e os blocos BEM existentes; `spec/visual/capture.cjs` (AD-015)
**Requirement**: DCK-07, DCK-34 (Req. 2.5)

**Tools**:

- MCP: `playwright` (capturas no host)
- Skill: NONE (revisão por `ecc:a11y-architect`)

**Done when**:

- [ ] Botões `−`, `+`, "Usar como Leader", "Editar este deck", "Excluir deck" e o submit do nome têm `min-height` e `min-width` de 44px, como `.ownership__button`, e os links de ação da página do deck ficam separados por ao menos 24px (achado H1 da revisão de a11y)
- [ ] O teste de design prova que as classes novas existem no CSS (`class_coverage_test.rb`) e que nenhuma regra delas impede a quebra de linha a 360px
- [ ] Capturas da lista, do deck, da importação, do detalhe com o controle e da pasta com o bloco, em 390px e 1280px, anexadas à task (fora do git)
- [ ] Gate build passa; contagem registrada

**Tests**: integration
**Gate**: build
**Commit**: `style(decks): ajustar as telas de deck aos tokens e ao 360px`

---

### T21: Documentação e aceite do dono

**What**: Atualizar o `CLAUDE.md` (models, controllers, contagem de testes, deck em edição na sessão), o *Handoff* do `STATE.md` e a traceability do spec. Pedir ao dono o teste manual: colar no OPTCG Simulator uma lista exportada, o que resolve o ⚠️ do separador LF, e montar um deck pelo detalhe até `válido` a 360px.
**Where**: `CLAUDE.md`
**Depends on**: T20
**Reuses**: o formato da seção "Estado atual" do `CLAUDE.md`
**Requirement**: DCK-31 (⚠️ LF), Success Criteria

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] O `CLAUDE.md` descreve o que existe depois da feature, e o `grep` registrado no commit não acha model ou controller citado que não exista
- [ ] A traceability tem DCK-01..44 mapeados para tasks
- [ ] O dono respondeu sobre o LF no simulador; se o simulador não aceitar, o separador passa a CRLF ou CR, com emenda no spec e no Req. 14, numa task de correção
- [ ] Gate full passa; contagem registrada

**Tests**: none
**Gate**: full
**Commit**: `docs(decks): registrar a feature no CLAUDE.md e no STATE`

---

## Plano de delegação

São 21 tasks em três lotes, um por phase: **Lote A** = Phase 1 (T1–T7), sem
HTTP; **Lote B** = Phase 2 (T8–T15); **Lote C** = Phase 3 (T16–T21), que para na
T21 para o teste manual do dono. A T1 para e volta ao dono se o Rule Manual
mudar alguma regra do spec. Como não há revisor de Ruby, as revisões ficam com
agentes agnósticos de linguagem: `ecc:database-reviewer` em T2, T5 e T13;
`ecc:security-reviewer` em T8 e T12; `ecc:a11y-architect` em T9, T15 e T20;
`ecc:silent-failure-hunter` em T17; `ecc:pr-test-analyzer` em T19. O Verifier
roda depois da T21.

---

## Task Granularity Check

| Task | Escopo | Status |
|---|---|---|
| T1 | 1 verificação de regra, registrada em 3 documentos | ✅ |
| T2 | 1 migração (o `structure.sql` é gerado) | ✅ |
| T3 | 2 models pequenos e 1 associação | ⚠️ OK, coeso |
| T4 | 1 função | ✅ |
| T5 | 1 query object | ✅ |
| T6 | 1 função (`parse`) | ✅ |
| T7 | 1 função (`format`) | ✅ |
| T8 | 3 actions, rotas e link de navegação | ⚠️ OK, coeso: sem rota e sem link as actions não têm como ser testadas |
| T9 | 1 view | ✅ |
| T10 | 1 bloco da mesma view | ✅ |
| T11 | 4 actions (renomear e excluir) | ⚠️ OK, coeso |
| T12 | 1 concern e 1 action | ✅ |
| T13 | 2 actions, a partial do Stream e as rotas | ⚠️ OK, coeso |
| T14 | 1 action | ✅ |
| T15 | 1 view e 1 leitura no controller | ✅ |
| T16 | 1 formato de resposta | ✅ |
| T17 | 1 controller (2 actions), view e rota | ⚠️ OK, coeso |
| T18 | 1 partial e a inclusão na pasta | ✅ |
| T19 | 1 teste | ✅ |
| T20 | 1 folha de estilo | ✅ |
| T21 | documentação | ✅ |

## Diagram-Definition Cross-Check

| Task | Depends on (corpo) | Diagrama | Status |
|---|---|---|---|
| T1 | None | — | ✅ |
| T2 | None | — | ✅ |
| T3 | T2 | T2 → T3 | ✅ |
| T4 | T1, T3 | T1 → T4, T3 → T4 | ✅ |
| T5 | T3 | T3 → T5 | ✅ |
| T6 | T3 | T3 → T6 | ✅ |
| T7 | T6 | T6 → T7 | ✅ |
| T8 | None (Phase 1 antes) | — | ✅ |
| T9 | T8 | T8 → T9 | ✅ |
| T10 | T9 | T9 → T10 | ✅ |
| T11 | T8 | T8 → T11 | ✅ |
| T12 | T8 | T8 → T12 | ✅ |
| T13 | T12 | T12 → T13 | ✅ |
| T14 | T13 | T13 → T14 | ✅ |
| T15 | T14 | T14 → T15 | ✅ |
| T16 | None (Phase 2 antes) | — | ✅ |
| T17 | T16 | T16 → T17 | ✅ |
| T18 | T17 | T17 → T18 | ✅ |
| T19 | T18 | T18 → T19 | ✅ |
| T20 | T19 | T19 → T20 | ✅ |
| T21 | T20 | T20 → T21 | ✅ |

## Test Co-location Validation

| Task | Camada | Matriz exige | Task diz | Status |
|---|---|---|---|---|
| T1 | Documentação | none | none | ✅ |
| T2 | Schema | unit | unit | ✅ |
| T3 | Model | unit | unit | ✅ |
| T4 | Domínio puro | unit | unit | ✅ |
| T5 | Query object | unit | unit | ✅ |
| T6 | Domínio puro | unit | unit | ✅ |
| T7 | Domínio puro | unit | unit | ✅ |
| T8–T18 | Controller + view | integration | integration | ✅ |
| T19 | Teste de serviço de ingestão | unit | unit | ✅ |
| T20 | CSS / layout | design | integration (teste de design) | ✅ |
| T21 | Documentação | none | none | ✅ |
