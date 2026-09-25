# Navegação e layout das telas — Tasks

**Spec**: `.specs/features/navegacao/spec.md` (Approved, 2026-09-23)
**Design**: inline, na seção "Decisões de implementação" abaixo; não há `design.md`
**Status**: Approved (2026-09-23, pelo dono do produto). Emendado em 2026-09-24
com T12–T21 (Fases 6–10), depois da reprovação visual registrada na T11.

Cobre a §6 de `.context/tasks.md` no item de Req. 4.9 e 13.1–13.14.
A seção só fecha na T21.

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
- **Testes criados por esta feature** (`test/design/navigation_layout_test.rb`,
  `filter_layout_test.rb`, `test/integration/catalog_filter_controls_test.rb`,
  `catalog_ownership_filter_test.rb`) podem ser reescritos nas Fases 6–10, e só
  onde o critério que provam mudou com a emenda de 2026-09-24. O commit diz
  qual asserção caiu e qual NAV a substitui. Asserção de critério que não mudou
  (URL resultante, preservação de filtro, isolamento de posse, NAV-26, NAV-27)
  é mantida ou reescrita com a mesma força.
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
| Barra inferior | Mobile-first: a regra base é a estreita, com `position: fixed; bottom: 0` em `.site-header__nav` e altura `var(--nav-height)`. `body` reserva `padding-bottom: var(--nav-height)`. `@media (min-width: 64rem)` (= 1024px; `catalog_grid_test.rb` varre `px`) desfaz as duas coisas | `position: sticky` não serve: a `nav` fica dentro do `header`, e sticky não escapa do contêiner. Um token para a altura da barra e para a reserva faz o NAV-05 ser uma igualdade verificável |
| Token novo `--nav-height` | Acrescentado em `:root`, com valor ≥ 44px, e registrado em `.context/design.md` §11.5 no mesmo commit | A guarda de literais recusa `calc()` com número solto em `padding` |
| Coluna lateral | Em `≥ 1024px`, `body` vira grid de duas colunas. `header.site-header` ocupa a primeira, com marca em cima e `nav` vertical. Flash e `main` ficam na segunda | Uma marcação só (premissa confirmada). A ordem do DOM (navegação antes do conteúdo) é a mesma nas duas larguras |
| `aria-current` | Helper `nav_link_to` com `current_page?`. "Catálogo" fica corrente em `/` e em `/catalog`, "Minha pasta" em `/progress`, "Entrar" e "Criar conta" nas próprias páginas. No detalhe da carta nenhuma entrada fica corrente | NAV-04 fala da página da navegação aberta. O detalhe não é entrada |
| Opções de filtro | `CatalogQuery.filter_options` devolve cores, tipos, raridades e sets presentes no banco, ordenados | As colunas e os nomes de parâmetro já moram em `ARRAY_FILTERS`, `SCALAR_FILTERS` e `VARIANT_FILTERS`. Um segundo lugar que soubesse deles divergiria |
| Formulário de filtro | Um `form` GET para `catalog_path`, com checkbox por cor, tipo e raridade, `select` de set, rádio de posse e botão "Filtrar". Filtros ativos sem controle (faixas, `attributes`, `traits`, `q`, `sort`, `dir`) vão como `hidden` | NAV-10 e NAV-14 sem JavaScript. Os nomes de parâmetro são os do query object |
| Set múltiplo vindo da URL | O `select` mostra "Todos os sets" e os sets ativos seguem em `hidden` | Um `select` simples não representa dois valores, e a URL não pode perder filtro (NAV-10) |
| Estado ativo | Checkbox e rádio nativos visíveis, marcados. O chip de cor ganha anel de 2px `accent` via `:has(:checked)` | O estado marcado é anunciado e visível sem depender de cor (NAV-11). O anel é o do Req. 12.11 (NAV-15) |
| Indicadores da pasta | `CollectionItem.total_copies_for` (já existe) e `CollectionItem.distinct_variants_for` (novo, ao lado) | O mesmo número do catálogo por construção (NAV-17). A barreira de tipo de `for_user` vale para os dois (NAV-21) |
| Chips de filtro (emenda) | Cada valor de cor, tipo, raridade e posse é um `<a>` gerado por um helper novo `filter_toggle_url(active_filters, key, value)` em `catalog_helper.rb`, ao lado de `filters_without`: acrescenta o valor inativo, remove o ativo, descarta `page`. Posse usa a mesma função com valor escalar | A URL parte dos filtros normalizados, como os chips de remoção (Req. 4.6). Um toque aplica, sem JS e sem botão |
| Nome acessível do chip | Inativo: sem `aria-label`, o nome é o texto visível. Ativo: `aria-label="Remover filtro <Categoria>: <valor>"` e "×" com `aria-hidden` | O nome contém o rótulo visível (SC 2.5.3). É o padrão que o `filter-chip` já usa |
| Set (emenda) | Continua `select` num formulário GET próprio, com botão "Aplicar" e os filtros ativos em `hidden` | Dezenas de sets virariam dezenas de chips em 360px. O formulário e os `hidden` da T7 são reaproveitados |
| Coluna lateral com filtros (emenda) | Em ≥ 64rem, `body` define `grid-template-columns: var(--sidebar-width) minmax(0, 1fr)`. No catálogo, `main.catalog` ocupa `1 / -1` com `grid-template-columns: subgrid` e `grid-template-rows: subgrid`, e a view agrupa os filhos em `catalog__head` (título, busca, chips ativos), `catalog__filters` e `catalog__body` (status, grade, paginação). `head` vai para a coluna 2 e linha 1, `filters` para a coluna 1 e linha 2, `body` para a coluna 2 e linha 2. O cabeçalho fica na coluna 1 e linha 1 | A ordem do DOM continua a do celular: título, busca, filtros, grade. `display: contents` em `main` foi descartado porque apaga o landmark em parte dos navegadores (⚠️ VERIFICAR se a T18 achar fonte primária em contrário). Subgrid é Baseline desde 2023 |
| Barra de progresso do set | `<progress value max>` com `aria-hidden="true"`, dentro da linha do set, fora do `<p>` da contagem | A contagem escrita já diz o mesmo. Um `progress` exposto repetiria cada número para leitor de tela. O elemento dispensa `style` inline |
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

### Phase 5: Detalhe largo e primeira revisão

```
T9 → T10 → T11
```

### Phase 6: Navegação no desenho do canvas

```
T11 → T12
```

### Phase 7: Filtros como chips

```
T12 → T13 → T14 → T15 → T16 → T17
```

### Phase 8: Filtros na coluna lateral

```
T17 → T18
```

### Phase 9: Minha pasta no desenho do canvas

```
T18 → T19 → T20
```

### Phase 10: Fechamento

```
T20 → T21
```

Lotes para o Execute: **B1 = Fases 1–3 (T1–T6)** e **B2 = Fases 4–5
(T7–T11)**, ambos fechados. **B3 = Fases 6–7 (T12–T17)** e **B4 = Fases 8–10
(T18–T21)**. Workers só com aceite explícito. Depois da T21, o Verifier roda
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

**Resultado**: 263 runs, 0 failures (gate quick); rubocop limpo. Revisão do orquestrador: chaves e colunas passaram a sair das constantes do query object, e raridade NULL ficou de fora das opções.

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

- [x] Três cópias de uma variante e uma de outra dão 2. Item com quantidade 0 não conta
- [x] Usuário sem nenhum item dá 0, e `nil` dá 0
- [x] Itens de outro usuário não entram. Um id em vez de `User` levanta `ArgumentError`, pela barreira de `for_user`
- [x] Teste em `test/models/`; gate quick passa, contagem registrada

**Resultado**: 269 runs, 0 failures (gate quick); rubocop limpo.

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

- [x] `h1` "Minha pasta". `h2` "Progresso por set" carrega o `id` que o `aria-labelledby` da lista usa. Nome do set em `h3`, sem nível pulado
- [x] Com 3 cópias de uma variante e 1 de outra: "4 cartas na pasta" e "2 cartas diferentes". O total é igual ao que o catálogo mostra para o mesmo usuário
- [x] Usuário sem cópia vê os dois indicadores com 0
- [x] `?user_id=` de outro usuário não muda os números. O controller continua sem ler `params`
- [x] Anônimo em `/progress` continua redirecionado ao login
- [x] Classes novas são elementos de `progress` e têm regra na folha (`class_coverage_test` passa)
- [x] `progress_ui_test.rb` passa **sem edição**; gate full passa, contagem registrada

**Resultado**: 985 runs, 0 failures (gate full); rubocop limpo.

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

- [x] Os três links existem, com texto que diz o destino, e o de export é o partial que já existe, não uma cópia
- [x] Alvos com `min-height` e `min-width` de 24px, como os outros links de texto (SC 2.5.8)
- [x] Testes de integração em `test/integration/minha_pasta_test.rb` cobrem os links e falham se removidos; `collection_export_link_test.rb` passa sem edição; gate full passa, contagem registrada (994 runs)

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

- [x] Exatamente um `nav` principal por página, `aria-label="Principal"`, com classe `site-header__nav`, dentro de `header.site-header`
- [x] Com sessão, as entradas são Catálogo, Minha pasta (`/progress`) e Sair. Sem sessão, Catálogo, Entrar e Criar conta. "Progresso por set" e "Lista de desejos" saem do cabeçalho
- [x] `aria-current="page"` só em "Catálogo" no catálogo, só em "Minha pasta" em `/progress`, e em nenhuma entrada no detalhe da carta
- [x] Nenhuma entrada de baralho, preço ou cotação (NAV-07), verificado por texto e por `href`
- [x] `wishlist_items_test.rb:542-546` reescrito: a wishlist é alcançável a partir de "Minha pasta" e não aparece para anônimo. O motivo vai no comentário do teste
- [x] `progress_ui_test.rb` e `sessions_test.rb` passam sem edição; gate full passa, contagem registrada

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

- [x] Token `--nav-height` ≥ 44px em `:root`, registrado em `.context/design.md` §11.5 no mesmo commit
- [x] Fora de media query: `.site-header__nav` com `position: fixed`, `bottom: 0` e `height: var(--nav-height)`, cada entrada com `min-height` ≥ 44px, e `body` com `padding-bottom: var(--nav-height)`. É o mesmo token dos dois lados
- [x] Dentro de `@media (min-width: 64rem)`: a navegação sai de `fixed`, a reserva é zerada, e o layout de duas colunas põe o cabeçalho à esquerda do conteúdo
- [x] `[aria-current="page"]` na navegação com `font-weight` de token diferente do das outras entradas
- [x] A barra cabe em 360px com três entradas: nenhuma largura fixa soma mais que o viewport
- [x] `test/design/navigation_layout_test.rb` novo, com recorte próprio de `@media`; os arquivos existentes de `test/design/` passam sem edição; gate full passa, contagem registrada

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

- [x] Um controle por valor presente de cor, tipo e raridade, com rótulo escrito, e um `select` de set com "Todos os sets"
- [x] Os nomes dos campos produzem a URL que o query object aceita. Para `colors[]=Red&rarities[]=SR`, a contagem da página enviada pelo formulário é a mesma da URL digitada à mão
- [x] Com `q`, faixa de custo, `traits` e `sort` ativos, o formulário os carrega como `hidden`. Dois sets vindos da URL também continuam, com o `select` mostrando "Todos os sets"
- [x] O valor ativo aparece `checked` ou `selected`, sem depender de cor
- [x] Parâmetro desconhecido ou valor inválido não marca controle nenhum e não gera erro
- [x] Com zero resultados, os controles continuam na página com os valores ativos marcados
- [x] Nenhum `data-controller` nem JS: o formulário funciona com envio nativo
- [x] Classes novas são elementos de `catalog`, com regra na folha; `catalog_grid_test.rb` e `color_chip_ui_test.rb` passam sem edição; gate full passa, contagem registrada

**Resultado**: 1043 runs, 0 failures (gate full); rubocop limpo. Correção T7a: preservar `sort` e `dir` como `hidden`, reescrever teste NAV-09 para simular formulário, gerar IDs sem espaço para raridades com espaço (SP CARD), mover `filter_options` para controller. Correção T7b: testes NAV-09 refatorados para ler HTML renderizado e localizar checkboxes pelo valor, sem supor o `name`, provando que o formulário enviado pelos campos dá a mesma contagem da URL digitada à mão.

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

- [x] Com sessão: três rádios `owned=all|owned|missing`, com os rótulos da spec, dentro de um `fieldset` com `legend`
- [x] O valor ativo vem de `active_filters[:owned]`. Sem valor na URL, "todas" fica marcado. Valor inválido cai em "todas", como o query object faz
- [x] Sem sessão, nenhum campo `owned` no HTML, nem com `?owned=owned` na URL
- [x] "tenho" e "não tenho" produzem as mesmas cartas que a URL digitada à mão (Req. 7.6)
- [x] Gate full passa, contagem registrada

**Resultado**: 1053 runs, 0 failures (gate full); rubocop limpo.

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

- [x] Fora de media query, os filtros não têm `position` nem `float`, e cada fileira de controles quebra linha (`flex-wrap: wrap`), sem `overflow-x`
- [x] Dentro de `@media (min-width: 64rem)` (= 1024px; `catalog_grid_test.rb` varre `px`), filtros e grade ficam em duas colunas
- [x] O chip de cor marcado tem `outline` ou `box-shadow` de 2px com `var(--accent)`, e nenhum `background` com `accent`, em nenhum estado
- [x] Controles com `min-height` e `min-width` de 24px
- [x] `test/design/filter_layout_test.rb` novo; `layout_test.rb` e os sete arquivos protegidos passam sem edição; gate full passa, contagem registrada

**Resultado**: 1062 runs, 0 failures (gate full); rubocop limpo. Correção T9a: coluna de filtros estreitada para 12–16rem, grade deslocada para coluna 2, demais filhos em 1/-1, e novos testes para grid-column.

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

- [x] As regras de duas colunas do detalhe existem só dentro de `@media (min-width: 64rem)` (= 1024px; `catalog_grid_test.rb` varre `px`)
- [x] Nenhuma view do detalhe perde campo ou controle. `card_detail_test.rb`, `collection_ownership_ui_test.rb` e `wishlist_mark_ui_test.rb` passam sem edição
- [x] Se a view precisar de um contêiner a mais para as duas colunas, ele é elemento de `card-detail`, com regra na folha, e não muda a ordem de leitura
- [x] `test/design/detail_layout_test.rb` novo; `test/integration/card_detail_layout_test.rb` novo; gate full passa, contagem registrada

**Resultado**: 1069 runs, 0 failures, 0 errors, 0 skips; rubocop limpo. Estrutura HTML: `main.card-detail > [p, .card-detail__data > [header, dl, section?, section?], .card-detail__variants]`. CSS: `.card-detail__data { min-width: 0; }` fora de media query, regras de grid dentro de `@media (min-width: 64rem)`. Correção T10a: remover `skip` do teste e implementar `setup` com dados reais, provando que `.card-detail__effect` e `.card-detail__trigger` estão dentro do contêiner de dados e que há duas variantes.

**Tests**: unit + integration
**Gate**: full
**Commit**: `feat(navegacao): pôr a arte ao lado dos dados no detalhe largo`

---

### T11: Revisão de acessibilidade e revisão visual do dono

**Correções da revisão**: nomeou o seletor de set com `label for="filter-sets"` e `select id="filter-sets" name="sets[]"` (SC 4.1.2 e 1.3.1); moveu `scroll-padding-bottom: var(--body-padding-bottom)` para o bloco `:root` base (SC 2.4.11, Res. 12.10). Testes novos: `test/design/focus_obscured_test.rb` (2 testes). Gate: 1075 runs, 0 failures; RuboCop limpo.

**What**: Rodar a revisão de a11y sobre o diff da feature e submeter as telas ao dono do produto em `docker compose up`, em 360px e em 1280px.
**Where**: `.specs/features/navegacao/tasks.md`
**Depends on**: T10
**Reuses**: o plano de delegação do `CLAUDE.md` (`ecc:a11y-architect`, só leitura)
**Requirement**: NAV-01..NAV-29 (Success Criteria da spec)

**Tools**:

- MCP: NONE
- Skill: NONE — subagente `ecc:a11y-architect`, só leitura

**Done when**:

- [x] `ecc:a11y-architect` revisou layout, navegação, formulário de filtro e pasta. Achados CRITICAL e HIGH viraram task de correção antes do Verifier
- [x] O dono abriu catálogo, filtro, detalhe e Minha pasta, com sessão e sem sessão, em 360px e em 1280px, e aprovou ou listou o que reprova

Os dois itens de fechamento (Success Criteria e gate build) passaram para a T21.

**Resultado (2026-09-24)**: **reprovada pelo dono**. A interface não segue o
canvas "Bindr — telas". Divergências, comparando o HTML e a folha com os
`.dc.html` do canvas:

1. Barra inferior: entradas centralizadas em vez de dividir a largura; fundo
   `surface-base` em vez de `surface-raised`; entrada atual marcada só pelo peso,
   sem o fundo `surface-sunken`.
2. Coluna lateral: `minmax(200px, 1fr)` sem fundo nem borda, contra 280px fixos
   em `surface-raised` com borda direita.
3. Catálogo largo: os filtros formam uma segunda coluna dentro de `main`, e a
   tela fica com três colunas. No canvas, eles ficam dentro da coluna lateral,
   abaixo da navegação.
4. Filtros: checkboxes e rádios nativos num painel com botão "Filtrar", contra
   chips de 44px que aplicam com um toque (ativo em `accent` com "×", cor com
   anel).
5. Falta a linha de status com "N filtros ativos" e "Limpar filtros".
6. Minha pasta: indicadores em texto corrido em vez de cartões; set sem barra
   de progresso; falta "Adicionar cartas".

Causa: NAV-01..NAV-29 descrevem estrutura e comportamento, e a spec tratava o
canvas só como "referência visual". A T7 chegou a pedir checkbox
explicitamente. Correção: Req. 13.9–13.14, NAV-30..NAV-39 e as tasks T12–T21.
Continuam como decididos na spec: chips que quebram linha em vez de rolar, sem
Baralhos, sem valor estimado nem "% do catálogo", sem "Zerar quantidade", busca
com botão.

**Tests**: none
**Gate**: none
**Commit**: `docs(navegacao): registrar a reprovação visual e emendar a spec com o desenho do canvas`

---

### T12: Barra inferior e coluna lateral no desenho do canvas

**What**: A barra inferior divide a largura entre as entradas, sobre `surface-raised`, com a entrada atual em `surface-sunken`. A partir de 1024px, a coluna lateral tem largura fixa, fundo elevado e borda direita.
**Where**: `app/assets/stylesheets/catalog.css`, `.context/design.md` §11.5
**Depends on**: T11
**Reuses**: `--nav-height`, `--nav-current-weight`, `--body-grid-columns`, os tokens de superfície de §11.3
**Requirement**: NAV-30, NAV-31, NAV-04, NAV-05, NAV-28

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] Fora de media query: `.site-header__nav` com `background-color: var(--surface-raised)` e cada entrada (link e botão "Sair") com `flex: 1`
- [ ] `.site-header__nav [aria-current="page"]` com `background-color: var(--surface-sunken)` e `color: var(--ink)`; as demais entradas com `color: var(--ink-muted)`. O peso distinto de NAV-04 continua
- [ ] Token `--sidebar-width: 280px` em `:root`, registrado em §11.5 junto com a troca de `body-grid-columns` em ≥ 64rem para `var(--sidebar-width) minmax(0, 1fr)`
- [ ] Dentro de `@media (min-width: 64rem)`: `.site-header` com `background-color: var(--surface-raised)`, `border-right: 1px solid var(--border)`, altura da página inteira, e as entradas empilhadas com `min-height: 44px`
- [ ] Em 360px a barra continua sem largura fixa que some mais que o viewport (NAV-28)
- [ ] Testes textuais novos em `test/design/navigation_canvas_test.rb`. `navigation_layout_test.rb` só muda onde a coluna deixou de ser `minmax(200px, 1fr)`. Gate full passa, contagem registrada

**Tests**: unit
**Gate**: full
**Commit**: `feat(navegacao): desenhar a barra inferior e a coluna lateral como no canvas`

---

### T13: URL de alternância de um valor de filtro

**What**: Um helper devolve a URL do catálogo com um valor de filtro acrescentado, se inativo, ou removido, se ativo, preservando todo o resto menos `page`.
**Where**: `app/helpers/catalog_helper.rb`
**Depends on**: T12
**Reuses**: `filters_without`, `NON_FILTER_KEYS`, os filtros normalizados de `@result.active_filters`
**Requirement**: NAV-33, NAV-09, NAV-10, NAV-26

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] `filter_toggle_url(active_filters, :colors, "Green")` com `colors: ["Red"]` gera `colors[]=Red&colors[]=Green`. Com `"Red"`, gera a URL sem `colors`
- [x] `q`, faixas, `traits`, `attributes`, `sort` e `dir` sobrevivem à alternância; `page` nunca sobrevive
- [x] Para `:owned` (escalar), `"owned"` troca o valor e `"all"` remove a chave
- [x] Valor inválido que o query object descartou não reaparece na URL
- [x] Teste unit em `test/helpers/catalog_helper_test.rb` (novo ou existente, conferir antes). Gate full passa, contagem registrada

**Tests**: unit
**Gate**: full
**Commit**: `feat(navegacao): gerar a URL que liga ou desliga um valor de filtro`

---

### T14: Chips de cor, tipo e raridade

**What**: Os checkboxes de cor, tipo e raridade dão lugar a chips-link, um por valor presente, apontando para `filter_toggle_url`. O set continua `select` num formulário GET com botão "Aplicar" e os filtros ativos em `hidden`.
**Where**: `app/views/catalog/index.html.erb`
**Depends on**: T13
**Reuses**: `filter_toggle_url` (T13), `@filter_options` (T1), `FILTER_LABELS`, os `hidden` da T7
**Requirement**: NAV-08, NAV-09, NAV-10, NAV-11, NAV-14, NAV-26, NAV-27, NAV-33, NAV-34

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] Um `<a>` por valor presente de cor, tipo e raridade, agrupado sob um título por categoria, com classe de elemento de `catalog`
- [ ] Seguir o `href` de "Red" e depois o de "SR" dá a mesma contagem de `colors[]=Red&rarities[]=SR` digitada à mão
- [ ] Chip ativo: "×" visível com `aria-hidden` e `aria-label` "Remover filtro Cor: Red". Chip inativo sem `aria-label`
- [ ] O `select` de set, com "Todos os sets", "Aplicar" e os `hidden`, mantém os casos da T7: dois sets vindos da URL, set único `selected`, `sort` e `dir` preservados
- [ ] Nenhum checkbox de filtro nem botão "Filtrar" no HTML. Nenhum `data-controller`
- [ ] Parâmetro desconhecido não marca chip. Com zero resultados, os chips continuam com os ativos marcados
- [ ] `catalog_filter_controls_test.rb` reescrito conforme o protocolo; `catalog_grid_test.rb` e `color_chip_ui_test.rb` passam sem edição; gate full passa, contagem registrada

**Tests**: integration
**Gate**: full
**Commit**: `feat(navegacao): aplicar cor, tipo e raridade com um toque no chip`

---

### T15: Chips de posse

**What**: Com sessão, os rádios de posse dão lugar a três chips-link, "Todas", "Tenho" e "Não tenho", exclusivos entre si. Sem sessão, nada é renderizado.
**Where**: `app/views/catalog/index.html.erb`
**Depends on**: T14
**Reuses**: `filter_toggle_url` (T13), `CatalogQuery::OWNERSHIP_VALUES`
**Requirement**: NAV-12, NAV-13, NAV-33, NAV-34

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] Com sessão, três links. O ativo segue NAV-34; sem `owned` na URL ou com valor inválido, "Todas" é o ativo
- [ ] "Tenho" e "Não tenho" levam às mesmas cartas que `?owned=owned` e `?owned=missing` digitados à mão, e a posse de outro usuário não entra
- [ ] Sem sessão, nenhum link com `owned` no HTML, nem com `?owned=owned` na URL
- [ ] `catalog_ownership_filter_test.rb` reescrito conforme o protocolo, mantendo os dois testes de isolamento; gate full passa, contagem registrada

**Tests**: integration
**Gate**: full
**Commit**: `feat(navegacao): filtrar por posse com um toque no chip`

---

### T16: Folha dos chips de filtro

**What**: Os chips ganham o desenho do canvas: 44px, borda `border-strong`, ativo preenchido de `accent` com "×". O chip de cor leva amostra tracejada neutra e, ativo, anel de 2px em `accent` sem preenchimento.
**Where**: `app/assets/stylesheets/catalog.css`
**Depends on**: T15
**Reuses**: `--accent`, `--on-accent`, `--border-strong`, `--radius-sm`, `--caption-size`
**Requirement**: NAV-15, NAV-35, NAV-11, NAV-28

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] Chip com `min-height: 44px`, `border: 1px solid var(--border-strong)` e `border-radius: var(--radius-sm)`, em fileira que quebra linha, sem `overflow-x`
- [ ] Chip ativo que não é de cor: `background-color: var(--accent)` e `color: var(--on-accent)`
- [ ] Chip de cor ativo: `outline: 2px solid var(--accent)` com `outline-offset: 2px`, e nenhuma regra do chip de cor com `background` em `accent`, em nenhum estado
- [ ] Amostra do chip de cor com borda tracejada `border-strong` sobre `surface-sunken` (P8 aberta)
- [ ] `filter_layout_test.rb` reescrito conforme o protocolo (o anel sai de `:has(:checked)` para o chip ativo); os testes de `test/design/` anteriores à feature e o contraste passam sem edição; gate full passa, contagem registrada

**Tests**: unit
**Gate**: full
**Commit**: `feat(navegacao): desenhar os chips de filtro como no canvas`

---

### T17: Linha de status do catálogo

**What**: A contagem de resultados fica numa linha de status. Com filtro ativo, a linha diz quantos são e oferece "Limpar filtros".
**Where**: `app/views/catalog/index.html.erb`, `app/assets/stylesheets/catalog.css`
**Depends on**: T16
**Reuses**: `catalog_chips` (a contagem de filtros é o número de chips), `.catalog__count`
**Requirement**: NAV-36, NAV-27

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] Sem filtro: só "N cartas". Com `colors[]=Red&rarities[]=SR`: "2 filtros ativos" e "Limpar filtros". Com um: "1 filtro ativo"
- [ ] "Limpar filtros" aponta para o catálogo sem filtros, mantendo `sort` e `dir` quando ativos
- [ ] `sort`, `dir` e `page` não contam como filtro
- [ ] Com zero resultados, a linha continua, e o "Limpar filtros" do estado vazio não fica duplicado sem motivo (decidir e registrar no resultado)
- [ ] "Limpar filtros" com alvo ≥ 24px; `catalog_grid_test.rb` passa sem edição; gate full passa, contagem registrada

**Tests**: integration
**Gate**: full
**Commit**: `feat(navegacao): mostrar filtros ativos e limpar filtros na linha de status`

---

### T18: Filtros na coluna lateral do catálogo largo

**What**: A partir de 1024px, os filtros do catálogo ficam na coluna lateral, abaixo da navegação, e título, busca, status e grade ocupam a coluna de conteúdo. Abaixo de 1024px, nada muda.
**Where**: `app/views/catalog/index.html.erb`, `app/assets/stylesheets/catalog.css`
**Depends on**: T17
**Reuses**: `--sidebar-width` (T12), o grid de `body` da T6
**Requirement**: NAV-32, NAV-22, NAV-23, NAV-06

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] Antes do código, conferir em fonte primária (MDN, caniuse) o suporte a `subgrid` e o efeito de `display: contents` sobre o landmark `main`. Registrar no resultado
- [ ] A view agrupa os filhos de `main.catalog` em `catalog__head`, `catalog__filters` e `catalog__body`, nessa ordem de DOM; o `main` continua sendo o landmark e contém os filtros
- [ ] Só dentro de `@media (min-width: 64rem)`: `main.catalog` em `grid-column: 1 / -1` com `subgrid` nos dois eixos; `head` na coluna 2 e linha 1, `filters` na coluna 1 e linha 2, `body` na coluna 2 e linha 2; `.site-header` na coluna 1 e linha 1
- [ ] Detalhe da carta e Minha pasta continuam na coluna 2 (`navigation_layout_test.rb` ajustado conforme o protocolo só na exceção do catálogo)
- [ ] O flash continua acima do conteúdo e as duas regiões vivas continuam no DOM
- [ ] Teste de integração da ordem dos três grupos e testes textuais das regras; gate full passa, contagem registrada

**Tests**: unit + integration
**Gate**: full
**Commit**: `feat(navegacao): pôr os filtros na coluna lateral do catálogo largo`

---

### T19: Minha pasta com cartões e barra por set

**What**: Os dois indicadores viram cartões com o número em destaque, e cada set ganha uma barra de progresso ao lado da contagem "possuídas / total".
**Where**: `app/views/progress/index.html.erb`, `app/assets/stylesheets/catalog.css`
**Depends on**: T18
**Reuses**: `progress__stat`, `row.owned_variants`, `row.total_variants`, `row.completion_percent_known?`
**Requirement**: NAV-37, NAV-38, NAV-17, NAV-18, NAV-20, NAV-28

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] Cada indicador é um cartão (`surface-raised`, borda `border`, `radius-md`), com o número em `display` e a legenda em `caption`. Com zero cópias, os dois mostram 0
- [ ] Em 360px os cartões dividem a largura em duas colunas sem estourar (NAV-28)
- [ ] Set com total conhecido: `<progress value="owned" max="total" aria-hidden="true">`, fora do `<p>` da contagem, trilho `surface-sunken` e preenchimento `border-strong`. Sem total conhecido, sem barra
- [ ] A mudança na view é só acréscimo: classes e textos que `progress_ui_test.rb` e `minha_pasta_test.rb` leem continuam. `progress_ui_test.rb` passa **sem edição**
- [ ] Classes novas são elementos de `progress` ou `progress-set`, com regra na folha; gate full passa, contagem registrada

**Tests**: integration + unit
**Gate**: full
**Commit**: `feat(navegacao): mostrar a pasta em cartões e com barra por set`

---

### T20: Adicionar cartas a partir da pasta

**What**: "Minha pasta" ganha o link "Adicionar cartas", em estilo de ação principal, que leva ao catálogo.
**Where**: `app/views/progress/index.html.erb`, `app/assets/stylesheets/catalog.css`
**Depends on**: T19
**Reuses**: `progress__actions`, `--accent`, `--on-accent`
**Requirement**: NAV-39

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] Link "Adicionar cartas" para `catalog_path`, antes dos links de wishlist, import e export, com `min-height: 44px`
- [ ] Fundo `accent` e texto `on-accent`; o contraste é o par já verificado em `test/design/`
- [ ] Teste em `minha_pasta_test.rb` que falha sem o link; gate full passa, contagem registrada

**Tests**: integration
**Gate**: full
**Commit**: `feat(navegacao): levar da pasta ao catálogo com adicionar cartas`

---

### T21: Segunda revisão visual e fechamento

**What**: Rodar a revisão de a11y sobre o diff das Fases 6–9 e submeter as telas de novo ao dono, comparando lado a lado com o canvas, em 360px e em 1280px.
**Where**: `.specs/features/navegacao/tasks.md`, `.context/tasks.md`
**Depends on**: T20
**Reuses**: o plano de delegação (`ecc:a11y-architect`, só leitura)
**Requirement**: NAV-01..NAV-39 (Success Criteria da spec)

**Tools**:

- MCP: NONE
- Skill: NONE — subagente `ecc:a11y-architect`, só leitura

**Done when**:

- [ ] `ecc:a11y-architect` revisou chips, linha de status, coluna lateral e pasta. Achados CRITICAL e HIGH viraram task de correção antes do Verifier
- [ ] Um revisor que não escreveu nenhuma das T12–T20 conferiu o HTML renderizado e a folha contra os artboards versionados em `.specs/features/navegacao/canvas/` (`Main`, `Mobile-Carta`, `Mobile-Pasta`, `Desktop-Catalogo`, `Desktop-Carta`, `Desktop-Pasta`), elemento por elemento: estrutura, ordem, medidas, tokens de cor e estado ativo. Cada divergência cita o artboard e o seletor e é classificada como defeito (vira task de correção antes do dono) ou recusa registrada na spec (Baralhos, preço, "% do catálogo", "Zerar quantidade", rolagem horizontal dos chips). O relatório fica em `.specs/features/navegacao/canvas-conformance.md`
- [ ] O dono comparou catálogo, filtro, detalhe e Minha pasta com o canvas, com sessão e sem sessão, em 360px e em 1280px, e aprovou ou listou o que reprova
- [ ] Os Success Criteria da spec estão marcados, e o item Req. 4.9 / 13.1–13.14 de `.context/tasks.md` §6 está fechado
- [ ] Gate build passa

**Tests**: none
**Gate**: build
**Commit**: `docs(navegacao): registrar a segunda revisão visual e de acessibilidade`

---

## Plano de delegação

| Task | Revisão |
|---|---|
| T3, T5 — títulos, `aria-current`, links | `ecc:a11y-architect` na T11 |
| T6, T9 — alvo de 44px, anel, reflow | `ecc:a11y-architect` na T11 |
| T7, T8 — formulário sem JS e preservação de URL | `ecc:pr-test-analyzer` antes do Verifier |
| T13–T15 — URL de alternância e chips | `ecc:pr-test-analyzer` sobre os testes reescritos, antes do Verifier |
| T12, T16, T18–T20 — barra, chips, coluna, pasta | `ecc:a11y-architect` na T21 |
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
| T12 | um grupo de regras mais um token | ✅ coeso |
| T13 | um helper | ✅ |
| T14 | três grupos de chips e o `select` que fica | ✅ um conceito |
| T15 | um grupo de chips | ✅ |
| T16 | um grupo de regras | ✅ |
| T17 | uma linha da view com a regra dela | ✅ |
| T18 | agrupamento da view mais as regras de subgrid | ⚠️ dois arquivos, um conceito |
| T19 | cartões e barra da pasta | ✅ coeso |
| T20 | um link | ✅ |
| T21 | revisão | ✅ |

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
| T12 | T11 | T11 → T12 (Fase 6) | ✅ |
| T13 | T12 | T12 → T13 (Fase 7) | ✅ |
| T14 | T13 | T13 → T14 | ✅ |
| T15 | T14 | T14 → T15 | ✅ |
| T16 | T15 | T15 → T16 | ✅ |
| T17 | T16 | T16 → T17 | ✅ |
| T18 | T17 | T17 → T18 (Fase 8) | ✅ |
| T19 | T18 | T18 → T19 (Fase 9) | ✅ |
| T20 | T19 | T19 → T20 | ✅ |
| T21 | T20 | T20 → T21 (Fase 10) | ✅ |

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
| T12 | folha | unit (textual) | unit | ✅ |
| T13 | helper | unit | unit | ✅ |
| T14 | view | integration | integration | ✅ |
| T15 | view | integration | integration | ✅ |
| T16 | folha | unit (textual) | unit | ✅ |
| T17 | view e folha | integration | integration | ✅ |
| T18 | view e folha | integration + unit (textual) | unit + integration | ✅ |
| T19 | view e folha | integration + unit (textual) | integration + unit | ✅ |
| T20 | view | integration | integration | ✅ |
| T21 | revisão | none | none | ✅ |
