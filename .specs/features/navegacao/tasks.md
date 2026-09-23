# Navegação e layout das telas — Tasks

**Spec**: `.specs/features/navegacao/spec.md` (Approved, 2026-09-23)
**Design**: inline, na seção "Decisões de implementação" abaixo; não há `design.md`
**Status**: Approved (2026-09-23, pelo dono do produto)

Cobre a §6 de `.context/tasks.md` no item de Req. 4.9 e 13.1–13.8 (linha 274).
A seção só fecha na T11.

## Execution Protocol

Implementar com a skill `tlc-spec-driven`, seguindo o fluxo Execute e as
Critical Rules dela. Se a skill não puder ser ativada, parar e avisar.

- Uma task por vez, em ordem. Não abrir a próxima com a anterior incompleta.
- Toda task termina com código que roda e teste que passa.
- Testes derivam dos critérios de aceitação da spec, nunca espelham a
  implementação. Nunca enfraquecer, pular ou apagar teste para passar no gate.
- **Não editar nenhum arquivo existente de `test/design/`** nem os sete testes
  que leem `catalog.css` (`catalog_grid_test.rb`, `progress_ui_test.rb`,
  `collection_ownership_ui_test.rb`, `collection_export_link_test.rb`,
  `collection_import_preview_ui_test.rb`, `collection_import_summary_test.rb`,
  `set_progress_plan_test.rb`). Esse é o Success Criterion da spec. Se um deles
  quebrar, o sinal é real: corrigir a view ou o CSS, não o teste. Arquivo
  **novo** em `test/design/` é permitido.
- `catalog.css` **não é reorganizado** (§11.7). Regras novas são acrescentadas.
- Um commit atômico por task, em português brasileiro, Conventional Commits, sem
  linha de atribuição. O checkbox é marcado neste arquivo antes do commit.
- Não há navegador no container. A prova é textual (sobre a folha) ou de
  integração (sobre o HTML renderizado). A verificação renderizada fica com o
  dono do produto na T11.

### Restrições medidas antes do plano

Medidas em `main` (`2234e11`):

- **Nenhum bloco BEM novo.** `literal_values_test.rb:119` compara o conjunto de
  blocos da folha com a lista fixa `EXPECTED_BLOCKS`. Um bloco novo reprova
  esse teste, e o teste não pode ser editado. Por isso a navegação usa
  elementos de `site-header`, os filtros usam elementos de `catalog` e os
  indicadores da pasta usam elementos de `progress`.
- **A navegação continua dentro de `header.site-header`, com a classe
  `site-header__nav`.** `progress_ui_test.rb:293-304` exige
  `header.site-header a[href="/progress"]` com sessão e a ausência dele sem
  sessão. `sessions_test.rb:227-236` procura `.site-header__nav`. Manter o
  contêiner faz os dois passarem sem edição.
- **O rótulo da lista de sets continua dizendo "Progresso por set"**
  (`progress_ui_test.rb:535`). O `id` que o `aria-labelledby` usa migra do `h1`
  para o novo `h2` "Progresso por set".
- **`wishlist_items_test.rb:542-546` vai mudar de forma legítima.** O teste
  espera "Lista de desejos" no cabeçalho do catálogo. A spec tira a wishlist da
  navegação e a põe em "Minha pasta" (NAV-02, NAV-19). O arquivo não é um dos
  sete protegidos. A T5 reescreve esses dois testes para a entrada nova: a
  wishlist alcançável a partir de "Minha pasta" e ausente para anônimo.
- A folha não tem nenhum `@media` hoje. O parser de `Stylesheet.rules`
  (`test/design/support/stylesheet.rb:103`) lê regra dentro de `@media` como se
  estivesse no topo. Os testes novos de layout precisam do próprio recorte por
  media query e não devem confiar em `Stylesheet.resolved` para isso.
- A guarda de literais exige token em `padding`, `margin`, `gap` e cores. Não
  exige em `height`, `min-height`, `position`, `grid-template-columns` nem em
  condição de `@media`.

### Decisões de implementação

| Ponto | Escolha | Motivo |
|---|---|---|
| Barra inferior | Mobile-first: a regra base é a estreita, com `position: fixed; bottom: 0` em `.site-header__nav` e altura `var(--nav-height)`. `body` reserva `padding-bottom: var(--nav-height)`. `@media (min-width: 1024px)` desfaz as duas coisas | `position: sticky` não serve: a `nav` fica dentro do `header`, e sticky não escapa do contêiner. Um token para a altura da barra e para a reserva faz o NAV-05 ser uma igualdade verificável |
| Token novo `--nav-height` | Acrescentado em `:root`, com valor ≥ 44px, e registrado em `.context/design.md` §11.5 no mesmo commit | A guarda de literais recusa `calc()` com número solto em `padding` |
| Coluna lateral | Em `≥ 1024px`, `body` vira grid de duas colunas. `header.site-header` ocupa a primeira, com marca em cima e `nav` vertical. Flash e `main` ficam na segunda | Uma marcação só (premissa confirmada). A ordem do DOM (navegação antes do conteúdo) é a mesma nas duas larguras |
| `aria-current` | Helper `nav_link_to` com `current_page?`. "Catálogo" fica corrente em `/` e em `/catalog`, "Minha pasta" em `/progress`, "Entrar" e "Criar conta" nas próprias páginas. No detalhe da carta nenhuma entrada fica corrente | NAV-04 fala da página da navegação aberta. O detalhe não é entrada |
| Opções de filtro | `CatalogQuery.filter_options` devolve cores, tipos, raridades e sets presentes no banco, ordenados | As colunas e os nomes de parâmetro já moram em `ARRAY_FILTERS`, `SCALAR_FILTERS` e `VARIANT_FILTERS`. Um segundo lugar que soubesse deles divergiria |
| Formulário de filtro | Um `form` GET para `catalog_path`, com checkbox por cor, tipo e raridade, `select` de set, rádio de posse e botão "Filtrar". Filtros ativos sem controle (faixas, `attributes`, `traits`, `q`, `sort`, `dir`) vão como `hidden` | NAV-10 e NAV-14 sem JavaScript. Os nomes de parâmetro são os do query object |
| Set múltiplo vindo da URL | O `select` mostra "Todos os sets" e os sets ativos seguem em `hidden` | Um `select` simples não representa dois valores, e a URL não pode perder filtro (NAV-10) |
| Estado ativo | Checkbox e rádio nativos visíveis, marcados. O chip de cor ganha anel de 2px `accent` via `:has(:checked)` | O estado marcado é anunciado e visível sem depender de cor (NAV-11). O anel é o do Req. 12.11 (NAV-15) |
| Indicadores da pasta | `CollectionItem.total_copies_for` (já existe) e `CollectionItem.distinct_variants_for` (novo, ao lado) | O mesmo número do catálogo por construção (NAV-17). A barreira de tipo de `for_user` vale para os dois (NAV-21) |
| Hierarquia de títulos da pasta | `h1` "Minha pasta" → `h2` "Progresso por set" → nome de cada set vira `h3` | O nome do set hoje é `h2`. Ele desce um nível para não pular hierarquia (SC 1.3.1) |

## Test Coverage Matrix

> Gerado a partir do código, das diretrizes do projeto (`CLAUDE.md`,
> `.context/design.md` §11.7) e da spec. Confirmar antes do Execute.

| Camada | Tipo de teste | Cobertura esperada | Onde | Comando |
|---|---|---|---|---|
| Query object e model (`filter_options`, `distinct_variants_for`) | unit | 1:1 com os ACs de dado, mais usuário nil, usuário sem cópia e isolamento entre usuários | `test/queries/*_test.rb`, `test/models/*_test.rb` | `bin/rails test test/models test/queries` |
| Views, helper e controller (navegação, filtros, pasta) | integration | Com sessão e sem sessão, caminho feliz, todo edge case (NAV-26, 27, 29) e a URL resultante comparada com o resultado do query object | `test/integration/*_test.rb` — `get`, `assert_select` | `bin/rails test test/integration` |
| Regras da folha (media query, altura, reserva, anel) | unit (textual) | Todo AC de layout (NAV-05, 06, 15, 22–24, 28), com falha que nomeia seletor e media query | `test/design/<arquivo novo>_test.rb` | `bin/rails test test/design` |
| Guardas existentes de design e 360px | integration + unit | Passam **sem edição** | `test/design/*`, os sete arquivos protegidos | `bin/rails test` |
| Aparência renderizada | none | Revisão visual do dono (T11), em 360px e 1280px | — | — |

O projeto não usa fixtures YAML: cada teste cria os próprios registros no
`setup`. A suíte roda em paralelo.

## Gate Check Commands

Todos rodam com `docker compose exec app` na frente.

| Gate | Quando | Comando |
|---|---|---|
| quick | Tasks só com teste unit de query ou model | `bin/rails test test/models test/queries` |
| full | Tasks com integração ou folha | `bin/rails test && bin/rubocop` |
| build | Fechamento da feature | `docker compose build` (no WSL, com `DOCKER_CONFIG` apontando para um diretório com `{}`; ver o Handoff do `STATE.md`) |

Base antes da T1: **951 runs**, 0 falhas, RuboCop limpo. Toda task registra a
contagem nova, que não pode cair.

## Execution Plan

As fases rodam em sequência, e as tasks de cada fase rodam em ordem.

### Phase 1: Dados

```
T1 → T2
```

### Phase 2: Minha pasta

Vem antes da navegação: a T5 tira a wishlist do cabeçalho, então a entrada
nova (T4) precisa existir antes.

```
T2 → T3 → T4
```

### Phase 3: Navegação principal

```
T4 → T5 → T6
```

### Phase 4: Filtros na grade

```
T6 → T7 → T8 → T9
```

### Phase 5: Detalhe largo e fechamento

```
T9 → T10 → T11
```

Lotes para o Execute: **B1 = Fases 1–3 (T1–T6)** e **B2 = Fases 4–5
(T7–T11)**. Workers só com aceite explícito. Depois da T11, o Verifier roda
automaticamente.

## Task Breakdown

### T1: Opções de filtro presentes no catálogo

**What**: `CatalogQuery.filter_options` devolve os valores distintos de cor, tipo de carta e raridade presentes no banco, e os sets (código e nome), ordenados.
**Where**: `app/queries/catalog_query.rb`
**Depends on**: None
**Reuses**: `ARRAY_FILTERS`, `SCALAR_FILTERS`, `VARIANT_FILTERS` (`catalog_query.rb:28-41`)
**Requirement**: NAV-08

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] As chaves do retorno são os nomes de parâmetro do query object (`colors`, `card_types`, `rarities`, `sets`), lidos das constantes e não repetidos
- [x] Carta multicolor contribui com cada uma das cores. Valor repetido aparece uma vez só. Catálogo vazio devolve listas vazias
- [x] Raridade vem das variantes, não das cartas
- [x] Carta marcada como ausente da fonte (Req. 1.7) segue as mesmas regras de visibilidade que a grade já aplica
- [x] `test/queries/catalog_filter_options_test.rb` novo; gate quick passa, contagem registrada

**Resultado**: 261 runs, 0 failures (gate quick); rubocop limpo.

**Tests**: unit
**Gate**: quick
**Commit**: `feat(navegacao): listar as opções de filtro presentes no catálogo`

---

### T2: Variantes distintas possuídas

**What**: `CollectionItem.distinct_variants_for(user)` conta as variantes com quantidade ≥ 1 do usuário.
**Where**: `app/models/collection_item.rb`
**Depends on**: T1
**Reuses**: `CollectionItem.total_copies_for`, os scopes `for_user` e `owned`
**Requirement**: NAV-18, NAV-20, NAV-21

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] Três cópias de uma variante e uma de outra dão 2. Item com quantidade 0 não conta
- [ ] Usuário sem nenhum item dá 0, e `nil` dá 0
- [ ] Itens de outro usuário não entram. Um id em vez de `User` levanta `ArgumentError`, pela barreira de `for_user`
- [ ] Teste em `test/models/`; gate quick passa, contagem registrada

**Tests**: unit
**Gate**: quick
**Commit**: `feat(navegacao): contar as variantes distintas da coleção`

---

### T3: Minha pasta: títulos e indicadores

**What**: A página de progresso ganha `h1` "Minha pasta", o total de cópias e o número de variantes distintas. "Progresso por set" vira `h2` e o nome de cada set vira `h3`.
**Where**: `app/views/progress/index.html.erb`
**Depends on**: T2
**Reuses**: `CollectionItem.total_copies_for`, `distinct_variants_for` (T2), o plural explícito de `catalog/_owned_total`
**Requirement**: NAV-16, NAV-17, NAV-18, NAV-20, NAV-21, NAV-29

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] `h1` "Minha pasta". `h2` "Progresso por set" carrega o `id` que o `aria-labelledby` da lista usa. Nome do set em `h3`, sem nível pulado
- [ ] Com 3 cópias de uma variante e 1 de outra: "4 cartas na pasta" e "2 cartas diferentes". O total é igual ao que o catálogo mostra para o mesmo usuário
- [ ] Usuário sem cópia vê os dois indicadores com 0
- [ ] `?user_id=` de outro usuário não muda os números. O controller continua sem ler `params`
- [ ] Anônimo em `/progress` continua redirecionado ao login
- [ ] Classes novas são elementos de `progress` e têm regra na folha (`class_coverage_test` passa)
- [ ] `progress_ui_test.rb` passa **sem edição**; gate full passa, contagem registrada

**Tests**: integration
**Gate**: full
**Commit**: `feat(navegacao): transformar o progresso em Minha pasta com os indicadores`

---

### T4: Minha pasta: links para wishlist, import e export

**What**: "Minha pasta" exibe links para a wishlist, para o import e para o export da coleção.
**Where**: `app/views/progress/index.html.erb`
**Depends on**: T3
**Reuses**: `progress/_export_link` (o link de export já está na página), `wishlist_items_path`, `new_collection_import_path`
**Requirement**: NAV-19

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] Os três links existem, com texto que diz o destino, e o de export é o partial que já existe, não uma cópia
- [ ] Alvos com `min-height` e `min-width` de 24px, como os outros links de texto (SC 2.5.8)
- [ ] `collection_export_link_test.rb` passa sem edição; gate full passa, contagem registrada

**Tests**: integration
**Gate**: full
**Commit**: `feat(navegacao): ligar Minha pasta à wishlist, ao import e ao export`

---

### T5: Navegação principal: marcação e entrada corrente

**What**: A `nav` do cabeçalho vira a navegação principal: "Catálogo" sempre, "Minha pasta" e "Sair" com sessão, "Entrar" e "Criar conta" sem sessão, e `aria-current="page"` na entrada da página aberta.
**Where**: `app/views/layouts/application.html.erb`
**Depends on**: T4
**Reuses**: `button_to "Sair"` e os links de anônimo existentes; helper novo `nav_link_to` em `app/helpers/application_helper.rb`
**Requirement**: NAV-01, NAV-02, NAV-03, NAV-04, NAV-07

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] Exatamente um `nav` principal por página, `aria-label="Principal"`, com classe `site-header__nav`, dentro de `header.site-header`
- [ ] Com sessão, as entradas são Catálogo, Minha pasta (`/progress`) e Sair. Sem sessão, Catálogo, Entrar e Criar conta. "Progresso por set" e "Lista de desejos" saem do cabeçalho
- [ ] `aria-current="page"` só em "Catálogo" no catálogo, só em "Minha pasta" em `/progress`, e em nenhuma entrada no detalhe da carta
- [ ] Nenhuma entrada de baralho, preço ou cotação (NAV-07), verificado por texto e por `href`
- [ ] `wishlist_items_test.rb:542-546` reescrito: a wishlist é alcançável a partir de "Minha pasta" e não aparece para anônimo. O motivo vai no comentário do teste
- [ ] `progress_ui_test.rb` e `sessions_test.rb` passam sem edição; gate full passa, contagem registrada

**Tests**: integration
**Gate**: full
**Commit**: `feat(navegacao): trocar o cabeçalho pela navegação principal`

---

### T6: Navegação principal: barra inferior e coluna lateral

**What**: A folha fixa a navegação na borda inferior abaixo de 1024px, reservando o espaço, e a põe em coluna lateral a partir de 1024px. A entrada corrente ganha peso distinto.
**Where**: `app/assets/stylesheets/catalog.css`
**Depends on**: T5
**Reuses**: `site-header__action`, os tokens de §11
**Requirement**: NAV-04, NAV-05, NAV-06, NAV-28

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] Token `--nav-height` ≥ 44px em `:root`, registrado em `.context/design.md` §11.5 no mesmo commit
- [ ] Fora de media query: `.site-header__nav` com `position: fixed`, `bottom: 0` e `height: var(--nav-height)`, cada entrada com `min-height` ≥ 44px, e `body` com `padding-bottom: var(--nav-height)`. É o mesmo token dos dois lados
- [ ] Dentro de `@media (min-width: 1024px)`: a navegação sai de `fixed`, a reserva é zerada, e o layout de duas colunas põe o cabeçalho à esquerda do conteúdo
- [ ] `[aria-current="page"]` na navegação com `font-weight` de token diferente do das outras entradas
- [ ] A barra cabe em 360px com três entradas: nenhuma largura fixa soma mais que o viewport
- [ ] `test/design/navigation_layout_test.rb` novo, com recorte próprio de `@media`; os arquivos existentes de `test/design/` passam sem edição; gate full passa, contagem registrada

**Tests**: unit
**Gate**: full
**Commit**: `feat(navegacao): fixar a navegação embaixo no celular e ao lado na tela larga`

---

### T7: Controles de filtro de cor, tipo, raridade e set

**What**: A grade ganha um formulário GET com um checkbox por cor, tipo e raridade presentes, um `select` de set e o botão "Filtrar", preservando busca e filtros sem controle.
**Where**: `app/views/catalog/index.html.erb`
**Depends on**: T6
**Reuses**: `CatalogQuery.filter_options` (T1), `@result.active_filters`, `FILTER_LABELS` de `catalog_helper.rb`
**Requirement**: NAV-08, NAV-09, NAV-10, NAV-11, NAV-14, NAV-26, NAV-27

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] Um controle por valor presente de cor, tipo e raridade, com rótulo escrito, e um `select` de set com "Todos os sets"
- [ ] Os nomes dos campos produzem a URL que o query object aceita. Para `colors[]=Red&rarities[]=SR`, a contagem da página enviada pelo formulário é a mesma da URL digitada à mão
- [ ] Com `q`, faixa de custo, `traits` e `sort` ativos, o formulário os carrega como `hidden`. Dois sets vindos da URL também continuam, com o `select` mostrando "Todos os sets"
- [ ] O valor ativo aparece `checked` ou `selected`, sem depender de cor
- [ ] Parâmetro desconhecido ou valor inválido não marca controle nenhum e não gera erro
- [ ] Com zero resultados, os controles continuam na página com os valores ativos marcados
- [ ] Nenhum `data-controller` nem JS: o formulário funciona com envio nativo
- [ ] Classes novas são elementos de `catalog`, com regra na folha; `catalog_grid_test.rb` e `color_chip_ui_test.rb` passam sem edição; gate full passa, contagem registrada

**Tests**: integration
**Gate**: full
**Commit**: `feat(navegacao): filtrar a grade por cor, tipo, raridade e set sem editar a URL`

---

### T8: Controle de posse

**What**: Com sessão, o formulário de filtro ganha o controle de posse com "todas", "tenho" e "não tenho". Sem sessão, ele não é renderizado.
**Where**: `app/views/catalog/index.html.erb`
**Depends on**: T7
**Reuses**: `CatalogQuery::OWNERSHIP_VALUES`
**Requirement**: NAV-12, NAV-13

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] Com sessão: três rádios `owned=all|owned|missing`, com os rótulos da spec, dentro de um `fieldset` com `legend`
- [ ] O valor ativo vem de `active_filters[:owned]`. Sem valor na URL, "todas" fica marcado. Valor inválido cai em "todas", como o query object faz
- [ ] Sem sessão, nenhum campo `owned` no HTML, nem com `?owned=owned` na URL
- [ ] "tenho" e "não tenho" produzem as mesmas cartas que a URL digitada à mão (Req. 7.6)
- [ ] Gate full passa, contagem registrada

**Tests**: integration
**Gate**: full
**Commit**: `feat(navegacao): filtrar por posse a partir da grade`

---

### T9: Folha dos filtros: fluxo estreito, coluna larga e anel da cor

**What**: Os controles de filtro ficam acima da grade em fluxo normal abaixo de 1024px, em coluna ao lado da grade a partir de 1024px, e o chip de cor selecionado leva anel de 2px em `accent`, sem preenchimento.
**Where**: `app/assets/stylesheets/catalog.css`
**Depends on**: T8
**Reuses**: `--accent`, a regra de foco de `catalog.css:640`
**Requirement**: NAV-15, NAV-22, NAV-23, NAV-28

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] Fora de media query, os filtros não têm `position` nem `float`, e cada fileira de controles quebra linha (`flex-wrap: wrap`), sem `overflow-x`
- [ ] Dentro de `@media (min-width: 1024px)`, filtros e grade ficam em duas colunas
- [ ] O chip de cor marcado tem `outline` ou `box-shadow` de 2px com `var(--accent)`, e nenhum `background` com `accent`, em nenhum estado
- [ ] Controles com `min-height` e `min-width` de 24px
- [ ] `test/design/filter_layout_test.rb` novo; `layout_test.rb` e os sete arquivos protegidos passam sem edição; gate full passa, contagem registrada

**Tests**: unit
**Gate**: full
**Commit**: `feat(navegacao): posicionar os filtros e marcar a cor selecionada com anel`

---

### T10: Detalhe da carta em duas colunas na tela larga

**What**: A partir de 1024px, o detalhe exibe a arte ao lado dos dados da carta. Abaixo disso, continua empilhado e com todos os campos e controles de hoje.
**Where**: `app/assets/stylesheets/catalog.css`
**Depends on**: T9
**Reuses**: `card-detail`, `variant-list`
**Requirement**: NAV-24, NAV-25, NAV-28

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] As regras de duas colunas do detalhe existem só dentro de `@media (min-width: 1024px)`
- [ ] Nenhuma view do detalhe perde campo ou controle. `card_detail_test.rb`, `collection_ownership_ui_test.rb` e `wishlist_mark_ui_test.rb` passam sem edição
- [ ] Se a view precisar de um contêiner a mais para as duas colunas, ele é elemento de `card-detail`, com regra na folha, e não muda a ordem de leitura
- [ ] `test/design/detail_layout_test.rb` novo; gate full passa, contagem registrada

**Tests**: unit
**Gate**: full
**Commit**: `feat(navegacao): pôr a arte ao lado dos dados no detalhe largo`

---

### T11: Revisão de acessibilidade e revisão visual do dono

**What**: Rodar a revisão de a11y sobre o diff da feature e submeter as telas ao dono do produto em `docker compose up`, em 360px e em 1280px.
**Where**: `.specs/features/navegacao/tasks.md`
**Depends on**: T10
**Reuses**: o plano de delegação do `CLAUDE.md` (`ecc:a11y-architect`, só leitura)
**Requirement**: NAV-01..NAV-29 (Success Criteria da spec)

**Tools**:

- MCP: NONE
- Skill: NONE — subagente `ecc:a11y-architect`, só leitura

**Done when**:

- [ ] `ecc:a11y-architect` revisou layout, navegação, formulário de filtro e pasta. Achados CRITICAL e HIGH viraram task de correção antes do Verifier
- [ ] O dono abriu catálogo, filtro, detalhe e Minha pasta, com sessão e sem sessão, em 360px e em 1280px, e aprovou ou listou o que reprova
- [ ] Os Success Criteria da spec estão marcados, e o item Req. 4.9 / 13.1–13.8 de `.context/tasks.md` §6 está fechado
- [ ] Gate build passa

**Tests**: none
**Gate**: build
**Commit**: `docs(navegacao): registrar a revisão visual e de acessibilidade`

---

## Plano de delegação

| Task | Revisão |
|---|---|
| T3, T5 — títulos, `aria-current`, links | `ecc:a11y-architect` na T11 |
| T6, T9 — alvo de 44px, anel, reflow | `ecc:a11y-architect` na T11 |
| T7, T8 — formulário sem JS e preservação de URL | `ecc:pr-test-analyzer` antes do Verifier |
| T1, T2 — consultas novas | `ecc:database-reviewer` se `filter_options` fizer full scan na tabela de variantes |

## Task Granularity Check

| Task | Escopo | Status |
|---|---|---|
| T1 | um método de classe | ✅ |
| T2 | um método de classe | ✅ |
| T3 | uma view: títulos e dois indicadores | ✅ coeso |
| T4 | uma view: três links | ✅ |
| T5 | um layout mais o helper da entrada corrente | ⚠️ dois arquivos, um conceito |
| T6 | um grupo de regras mais um token | ✅ coeso |
| T7 | um formulário | ✅ |
| T8 | um `fieldset` no mesmo formulário | ✅ |
| T9 | um grupo de regras | ✅ |
| T10 | um grupo de regras | ✅ |
| T11 | revisão | ✅ |

Separar o helper `nav_link_to` da T5 deixaria uma task com helper sem uso e sem
teste de integração.

## Diagram-Definition Cross-Check

| Task | Depends on | Diagrama | Status |
|---|---|---|---|
| T1 | None | início da Fase 1 | ✅ |
| T2 | T1 | T1 → T2 | ✅ |
| T3 | T2 | T2 → T3 (Fase 2) | ✅ |
| T4 | T3 | T3 → T4 | ✅ |
| T5 | T4 | T4 → T5 (Fase 3) | ✅ |
| T6 | T5 | T5 → T6 | ✅ |
| T7 | T6 | T6 → T7 (Fase 4) | ✅ |
| T8 | T7 | T7 → T8 | ✅ |
| T9 | T8 | T8 → T9 | ✅ |
| T10 | T9 | T9 → T10 (Fase 5) | ✅ |
| T11 | T10 | T10 → T11 | ✅ |

## Test Co-location Validation

| Task | Camada | Matriz exige | Task diz | Status |
|---|---|---|---|---|
| T1 | query object | unit | unit | ✅ |
| T2 | model | unit | unit | ✅ |
| T3 | view | integration | integration | ✅ |
| T4 | view | integration | integration | ✅ |
| T5 | layout e helper | integration | integration | ✅ |
| T6 | folha | unit (textual) | unit | ✅ |
| T7 | view | integration | integration | ✅ |
| T8 | view | integration | integration | ✅ |
| T9 | folha | unit (textual) | unit | ✅ |
| T10 | folha | unit (textual) | unit | ✅ |
| T11 | revisão | none | none | ✅ |
