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
- **Fases 11–15 (emenda de 2026-09-26):** toda task de layout roda
  `spec/visual/capture.cjs` (T22) antes e depois e cita no commit as capturas
  que mudaram. Captura é evidência, não gate (AD-015). Os testes criados por
  esta feature nas Fases 1–10 (`navigation_layout_test.rb`,
  `navigation_canvas_test.rb`, `filter_layout_test.rb`,
  `catalog_subgrid_layout_test.rb`, `detail_layout_test.rb`,
  `progress_canvas_test.rb`, `catalog_filter_controls_test.rb`,
  `catalog_ownership_filter_test.rb`, `catalog_status_line_test.rb`,
  `catalog_layout_structure_test.rb`, `card_detail_layout_test.rb`,
  `minha_pasta_test.rb`, `navegacao_principal_test.rb`) seguem a mesma regra
  das Fases 6–10: reescrita só onde o critério mudou, com o commit dizendo qual
  asserção caiu e qual NAV a substitui.

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

Medidas em `main` (`491c5d5`) para a emenda de 2026-09-26:

- **`.ownership__button` base continua com 24px.**
  `collection_ownership_ui_test.rb:314-320` (protegido) exige `min-height: 24px`
  e `min-width: 24px` na regra base. Os 44px do NAV-50 vêm de uma regra escopada
  ao detalhe (`.card-detail .ownership__button`), que o teste não lê.
- **A marcação do set na pasta não muda de forma.** `progress_ui_test.rb` lê
  `.progress-set__owned`, `__total`, `__percent`, `__percent-value`,
  `__parallel-owned` e exige os parallels fora do percentual;
  `set_progress_plan_test.rb:533-539` lista as classes do set. O NAV-51 se faz
  na folha, com os mesmos elementos.
- **Nenhum bloco BEM novo** continua valendo: o `<details>` dos filtros usa
  elementos de `catalog`, e os rótulos fora da vista usam elementos de
  `variant`. Não existe utilitário `visually-hidden` na folha, e criar um seria
  bloco novo.
- **A lista "Filtros ativos" (`ul.catalog__chips`) já mora em `catalog__head`,**
  fora de `catalog__filters`. O NAV-44 sai de graça se o `<details>` envolver só
  `catalog__filters`.
- A render (2026-09-26) mediu: fim do conteúdo em y=920 e barra em y=944 no
  catálogo em 390px (NAV-05 cumprido); nav da coluna lateral em y≈765 na carta e
  na pasta; vão de ~180px entre "Cor" e "Tipo" na coluna do catálogo.

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
| Script de captura (emenda) | `spec/visual/capture.cjs`, Node puro, `require('playwright')` resolvido por `NODE_PATH`, `executablePath` opcional por `CHROMIUM_PATH`. Cria um usuário descartável pelo formulário de cadastro, espera a URL do destino (o Turbo navega depois do `load`) e navega com `domcontentloaded`. Grava em `tmp/capturas/` (ignorado pelo git) | `spec/` já guarda o `verify_fixture.py`, ferramenta de host fora da suíte. Sem `package.json` no projeto: uma dependência Node no repo Rails não se paga para um script de revisão |
| Barra a 0% (emenda) | `appearance: none` em `.progress-set__bar`, trilho em `::-webkit-progress-bar` e preenchimento em `::-webkit-progress-value` e `::-moz-progress-bar` | `accent-color` não pinta o trilho do `<progress>` no Chromium; o trilho nativo cinza lê como barra cheia |
| "Sair" (emenda) | Regra para `.site-header__nav button` zerando `background` e `border` herdados do botão nativo, com a mesma cor das entradas inativas | O `button_to` gera `<button>`, que traz o estilo do agente de usuário |
| Coluna lateral (emenda) | `.site-header` em `≥ 64rem` com `justify-content: flex-start` e `align-items: stretch`; a marca ganha `padding` de entrada | A regra base (barra estreita) distribui os filhos; a coluna herdava isso e jogava a `nav` para o pé |
| Filtros recolhidos (emenda) | `<details class="catalog__filters-toggle">` envolve `catalog__filters`; `<summary class="catalog__filters-summary">` com "Filtros" e, com filtro ativo, a contagem de `active_filter_count`. Em `≥ 64rem`, `summary` sai de vista e `::details-content` recebe `content-visibility: visible` e `display: contents`. Confirmado na T27 pela captura em 1280px (Chromium do Playwright, cache `chromium-1223`): o conteúdo aparece com o `<details>` fechado, e o fallback por script não foi usado. Firefox e Safari não foram renderizados. O próprio `<details>` também recebe `display: contents` em `≥ 64rem`, senão ele vira o item do subgrid e desloca filtros e grade (complemento da T27); o efeito disso na árvore de acessibilidade fica para a revisão da T33 | `::details-content` é Baseline desde 2025 (Chrome 131, Firefox 143, Safari 18.4). Sem JS, os filtros continuam funcionando (NAV-14), só recolhidos |
| Imagem maior no detalhe (emenda) | A imagem da primeira variante de `@variants`, pelo mesmo `card_image_path` e com o mesmo placeholder em camada que o tile usa, dentro de um elemento de `card-detail` | Reaproveita o fallback sem JS do tile (Req. 2.3) em vez de um segundo |
| Variantes em linha (emenda) | `.variant` vira grid de três colunas (miniatura, meta, controles). Os `dt` de `.variant__meta` saem da vista pelo padrão de recorte (`clip-path: inset(50%)`, 1px) | Mantém `dl` e o texto para leitor de tela sem bloco utilitário novo |

## Test Coverage Matrix

> Gerado a partir do código, das diretrizes do projeto (`CLAUDE.md`,
> `.context/design.md` §11.7) e da spec. Confirmar antes do Execute.

| Camada | Tipo de teste | Cobertura esperada | Onde | Comando |
|---|---|---|---|---|
| Query object e model (`filter_options`, `distinct_variants_for`) | unit | 1:1 com os ACs de dado, mais usuário nil, usuário sem cópia e isolamento entre usuários | `test/queries/*_test.rb`, `test/models/*_test.rb` | `bin/rails test test/models test/queries` |
| Views, helper e controller (navegação, filtros, pasta) | integration | Com sessão e sem sessão, caminho feliz, todo edge case (NAV-26, 27, 29) e a URL resultante comparada com o resultado do query object | `test/integration/*_test.rb` — `get`, `assert_select` | `bin/rails test test/integration` |
| Regras da folha (media query, altura, reserva, anel) | unit (textual) | Todo AC de layout (NAV-05, 06, 15, 22–24, 28), com falha que nomeia seletor e media query | `test/design/<arquivo novo>_test.rb` | `bin/rails test test/design` |
| Guardas existentes de design e 360px | integration + unit | Passam **sem edição** | `test/design/*`, os sete arquivos protegidos | `bin/rails test` |
| Aparência renderizada | none (evidência) | Captura antes e depois em toda task de layout das Fases 11–14; revisão do dono sobre as capturas na T33 (AD-015) | `tmp/capturas/` | `NODE_PATH=<dir com playwright> node spec/visual/capture.cjs` (no host) |

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

### Phase 11: Evidência e correções da render

Emenda de 2026-09-26. O script vem primeiro para que as correções já saiam
com captura.

```
T21 → T22 → T23 → T24
```

### Phase 12: Coluna lateral e filtros

```
T24 → T25 → T26 → T27 → T28
```

### Phase 13: Detalhe da carta

```
T28 → T29 → T30 → T31
```

### Phase 14: Minha pasta

```
T31 → T32
```

### Phase 15: Fechamento da emenda

```
T32 → T33
```

### Phase 16: Correções da validação

Emenda de 2026-09-27, iteração 1 do loop de correção do Verifier
(`validation.md`). A T34 é documental. T35–T41 não compartilham arquivo e
rodam em paralelo, cada worker com seu banco de teste
(`POSTGRES_TEST_DB=bindr_test_<task>`, AD-014). O commit de cada uma sai
do orquestrador, depois do gate, porque o checkbox deste arquivo é comum a
todas.

```
T33 → T34
T34 → T35
T34 → T36
T34 → T37
T34 → T38
T34 → T39
T34 → T40
T34 → T41
T35 → T42
T36 → T42
T37 → T42
T38 → T42
T39 → T42
T40 → T42
T41 → T42
```

Lotes para o Execute: **B1 = Fases 1–3 (T1–T6)** e **B2 = Fases 4–5
(T7–T11)**, ambos fechados. **B3 = Fases 6–7 (T12–T17)** e **B4 = Fases 8–10
(T18–T21)**. Workers só com aceite explícito. **B5 = Fases 11–12 (T22–T28)** e
**B6 = Fases 13–15 (T29–T33)**. Depois da T33, o Verifier roda automaticamente.
**Fase 16 (T34–T42)** é o loop de correção da validação de 2026-09-27; o
Verifier roda de novo depois da T42.

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

- [x] Fora de media query: `.site-header__nav` com `background-color: var(--surface-raised)` e cada entrada (link e botão "Sair") com `flex: 1`
- [x] `.site-header__nav [aria-current="page"]` com `background-color: var(--surface-sunken)` e `color: var(--ink)`; as demais entradas com `color: var(--ink-muted)`. O peso distinto de NAV-04 continua
- [x] Token `--sidebar-width: 280px` em `:root`, registrado em §11.5 junto com a troca de `body-grid-columns` em ≥ 64rem para `var(--sidebar-width) minmax(0, 1fr)`
- [x] Dentro de `@media (min-width: 64rem)`: `.site-header` com `background-color: var(--surface-raised)`, `border-right: 1px solid var(--border)`, altura da página inteira, e as entradas empilhadas com `min-height: 44px`
- [x] Em 360px a barra continua sem largura fixa que some mais que o viewport (NAV-28)
- [x] Testes textuais novos em `test/design/navigation_canvas_test.rb`. `navigation_layout_test.rb` só muda onde a coluna deixou de ser `minmax(200px, 1fr)`. Gate full passa, contagem registrada

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

- [x] Um `<a>` por valor presente de cor, tipo e raridade, agrupado sob um título por categoria, com classe de elemento de `catalog`
- [x] Seguir o `href` de "Red" e depois o de "SR" dá a mesma contagem de `colors[]=Red&rarities[]=SR` digitada à mão
- [x] Chip ativo: "×" visível com `aria-hidden` e `aria-label` "Remover filtro Cor: Red". Chip inativo sem `aria-label`
- [x] O `select` de set, com "Todos os sets", "Aplicar" e os `hidden`, mantém os casos da T7: dois sets vindos da URL, set único `selected`, `sort` e `dir` preservados
- [x] Nenhum checkbox de filtro nem botão "Filtrar" no HTML. Nenhum `data-controller`
- [x] Parâmetro desconhecido não marca chip. Com zero resultados, os chips continuam com os ativos marcados
- [x] `catalog_filter_controls_test.rb` reescrito conforme o protocolo; `catalog_grid_test.rb` e `color_chip_ui_test.rb` passam sem edição; gate full passa, contagem registrada

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

- [x] Com sessão, três links. O ativo segue NAV-34; sem `owned` na URL ou com valor inválido, "Todas" é o ativo
- [x] "Tenho" e "Não tenho" levam às mesmas cartas que `?owned=owned` e `?owned=missing` digitados à mão, e a posse de outro usuário não entra
- [x] Sem sessão, nenhum link com `owned` no HTML, nem com `?owned=owned` na URL
- [x] `catalog_ownership_filter_test.rb` reescrito conforme o protocolo, mantendo os dois testes de isolamento; gate full passa, contagem registrada

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

- [x] Chip com `min-height: 44px`, `border: 1px solid var(--border-strong)` e `border-radius: var(--radius-sm)`, em fileira que quebra linha, sem `overflow-x`
- [x] Chip ativo que não é de cor: `background-color: var(--accent)` e `color: var(--on-accent)`
- [x] Chip de cor ativo: `outline: 2px solid var(--accent)` com `outline-offset: 2px`, e nenhuma regra do chip de cor com `background` em `accent`, em nenhum estado
- [x] Amostra do chip de cor com borda tracejada `border-strong` sobre `surface-sunken` (P8 aberta)
- [x] `filter_layout_test.rb` reescrito conforme o protocolo (o anel sai de `:has(:checked)` para o chip ativo); os testes de `test/design/` anteriores à feature e o contraste passam sem edição; gate full passa, contagem registrada

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

- [x] Sem filtro: só "N cartas". Com `colors[]=Red&rarities[]=SR`: "2 filtros ativos" e "Limpar filtros". Com um: "1 filtro ativo"
- [x] "Limpar filtros" aponta para o catálogo sem filtros, mantendo `sort` e `dir` quando ativos
- [x] `sort`, `dir` e `page` não contam como filtro
- [x] Com zero resultados, a linha continua, e o "Limpar filtros" do estado vazio não fica duplicado sem motivo (decidir e registrar no resultado)
- [x] "Limpar filtros" com alvo ≥ 24px; `catalog_grid_test.rb` passa sem edição; gate full passa, contagem registrada

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

- [x] Antes do código, conferir em fonte primária (MDN, caniuse) o suporte a `subgrid` e o efeito de `display: contents` sobre o landmark `main`. Registrar no resultado
- [x] A view agrupa os filhos de `main.catalog` em `catalog__head`, `catalog__filters` e `catalog__body`, nessa ordem de DOM; o `main` continua sendo o landmark e contém os filtros
- [x] Só dentro de `@media (min-width: 64rem)`: `main.catalog` em `grid-column: 1 / -1` com `subgrid` nos dois eixos; `head` na coluna 2 e linha 1, `filters` na coluna 1 e linha 2, `body` na coluna 2 e linha 2; `.site-header` na coluna 1 e linha 1
- [x] Detalhe da carta e Minha pasta continuam na coluna 2 (`navigation_layout_test.rb` ajustado conforme o protocolo só na exceção do catálogo)
- [x] O flash continua acima do conteúdo e as duas regiões vivas continuam no DOM
- [x] Teste de integração da ordem dos três grupos e testes textuais das regras; gate full passa, contagem registrada

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

- [x]  Cada indicador é um cartão (`surface-raised`, borda `border`, `radius-md`), com o número em `display` e a legenda em `caption`. Com zero cópias, os dois mostram 0
- [x]  Em 360px os cartões dividem a largura em duas colunas sem estourar (NAV-28)
- [x]  Set com total conhecido: `<progress value="owned" max="total" aria-hidden="true">`, fora do `<p>` da contagem, trilho `surface-sunken` e preenchimento `border-strong`. Sem total conhecido, sem barra
- [x]  A mudança na view é só acréscimo: classes e textos que `progress_ui_test.rb` e `minha_pasta_test.rb` leem continuam. `progress_ui_test.rb` passa **sem edição**
- [x]  Classes novas são elementos de `progress` ou `progress-set`, com regra na folha; gate full passa, contagem registrada

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

- [x] Link "Adicionar cartas" para `catalog_path`, antes dos links de wishlist, import e export, com `min-height: 44px`
- [x] Fundo `accent` e texto `on-accent`; o contraste é o par já verificado em `test/design/`
- [x] Teste em `minha_pasta_test.rb` que falha sem o link; gate full passa, contagem registrada

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

- [x] `ecc:a11y-architect` revisou chips, linha de status, coluna lateral e pasta. Achados CRITICAL e HIGH viraram task de correção antes do Verifier
- [x] Um revisor que não escreveu nenhuma das T12–T20 conferiu o HTML renderizado e a folha contra os artboards versionados em `.specs/features/navegacao/canvas/` (`Main`, `Mobile-Carta`, `Mobile-Pasta`, `Desktop-Catalogo`, `Desktop-Carta`, `Desktop-Pasta`), elemento por elemento: estrutura, ordem, medidas, tokens de cor e estado ativo. Cada divergência cita o artboard e o seletor e é classificada como defeito (vira task de correção antes do dono) ou recusa registrada na spec (Baralhos, preço, "% do catálogo", "Zerar quantidade", rolagem horizontal dos chips). O relatório fica em `.specs/features/navegacao/canvas-conformance.md`
- [x] O dono comparou catálogo, filtro, detalhe e Minha pasta com o canvas, com sessão e sem sessão, em 360px e em 1280px, e aprovou ou listou o que reprova

Os dois itens de fechamento (Success Criteria e gate build) passaram para a T33.

**Resultado parcial (2026-09-25)**: a revisão de a11y (revisor Haiku no Orca, só
leitura, no papel do `ecc:a11y-architect`) listou 2 CRITICAL e 4 HIGH. Nenhum se
sustentou na triagem: o chip de cor ativo se distingue por anel, peso e "×"
visível (não só por cor); o `aria-label` "Remover filtro Cor: Red" contém o
rótulo visível, que é o que o SC 2.5.3 exige, e é o texto que a NAV-34 manda; a
borda `border-strong` tem 4,23:1 sobre `surface-base` e 3,53:1 sobre
`surface-raised`; o "×" fica dentro do link de 44px. A conferência com o canvas
está em `canvas-conformance.md`: dois defeitos procedentes, corrigidos em
`1206aeb`. Faltam a revisão do dono e o gate build.

**Resultado (2026-09-26)**: **reprovada em parte**, agora sobre telas
renderizadas (AD-015; capturas de 390px e 1280px, com e sem sessão). Das
divergências, duas violam critério existente e viram correção (T23: barra a 0%
desenhada cheia, NAV-38; T24: "Sair" com fundo de botão nativo, NAV-30). Dez
viraram NAV-40..NAV-51 (T25–T32). Não procederam: barra inferior cobrindo o
conteúdo (medido: não cobre), raridade no tile, 5 colunas fixas e tirar o
convite de posse do tile (motivos no Out of Scope da spec). A rolagem
horizontal dos chips continua recusada; em troca, os filtros recolhem no
celular (NAV-43).

**Tests**: none
**Gate**: build
**Commit**: `docs(navegacao): registrar a segunda revisão visual e de acessibilidade`

---

### T22: Script de captura das telas

**What**: Versionar o script que fotografa as telas em 390px e 1280px, com e sem sessão, para servir de evidência às tasks de layout.
**Where**: `spec/visual/capture.cjs`, `.gitignore`
**Depends on**: T21
**Reuses**: o formulário de cadastro (`registrations/new`)
**Requirement**: AD-015 (Success Criteria da spec: revisão sobre capturas)

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] `node spec/visual/capture.cjs` com `NODE_PATH` apontando para um `playwright` grava em `tmp/capturas/` as telas catálogo, detalhe de uma carta, pasta, wishlist e import, em 390×1000 e 1280×900, sem sessão (catálogo e detalhe) e com sessão (todas)
- [x] A sessão vem de um usuário descartável criado pelo formulário, e o script espera a URL do destino antes da captura seguinte (a corrida do Turbo fez a primeira tentativa fotografar o login)
- [x] Navega com `domcontentloaded`; a captura não espera imagens da origem
- [x] Sem `playwright` resolvível, sai com código ≠ 0 e mensagem que diz como apontar `NODE_PATH`; sem o app em `:3000`, idem
- [x] Imprime, por captura, a URL final e o `scrollWidth` do documento, e marca `scrollWidth` maior que a viewport (Req. 2.5)
- [x] `tmp/capturas/` coberto pelo `.gitignore`; `python3 spec/verify_fixture.py` continua passando

**Resultado**: script criado, 14 capturas geradas (2 viewports × 7 telas); gate full passa com 1140 runs, rubocop limpo, `verify_fixture.py` com 12 verificações passando. Capturas confirmam sessão ativa em `catalogo-390-sessao.png` e `pasta-1280-sessao.png`.

**Tests**: none
**Gate**: o script roda contra `docker compose up` e produz as 14 capturas
**Commit**: `chore(navegacao): versionar o script de captura das telas`

---

### T23: Barra de progresso vazia desenhada vazia

**What**: A barra do set passa a desenhar trilho `surface-sunken` e preenchimento `border-strong` também no Chromium, e a 0% aparece vazia.
**Where**: `app/assets/stylesheets/catalog.css`
**Depends on**: T22
**Reuses**: `.progress-set__bar` (T19)
**Requirement**: NAV-38

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] `.progress-set__bar` declara `appearance: none`; `::-webkit-progress-bar` tem fundo `var(--surface-sunken)`; `::-webkit-progress-value` e `::-moz-progress-bar` têm fundo `var(--border-strong)`
- [x] Teste novo em `test/design/` que falha sem qualquer um dos três e nomeia o seletor que falta
- [x] Captura da pasta com usuário sem cópia: nenhum set desenha barra cheia
- [x] `progress_ui_test.rb` e `set_progress_plan_test.rb` passam **sem edição**; gate full passa, contagem registrada

**Tests**: unit (textual)
**Gate**: full
**Commit**: `fix(navegacao): desenhar a barra do set vazia quando nada foi coletado`

---

### T24: "Sair" e entradas da navegação sem estilo nativo

**What**: "Sair" perde o fundo e a borda do botão nativo, e nenhuma entrada da navegação é sublinhada.
**Where**: `app/assets/stylesheets/catalog.css`
**Depends on**: T23
**Reuses**: `.site-header__action`, `.site-header__nav`
**Requirement**: NAV-41, NAV-30, NAV-31

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] `.site-header__nav button` com `background` transparente e `border` nula ou `transparent`, e a mesma cor de texto das entradas inativas; a entrada atual continua com fundo `surface-sunken` (NAV-30)
- [x] `.site-header__nav a` com `text-decoration: none`; a entrada atual continua distinta por fundo e peso (NAV-04)
- [x] O foco visível da navegação continua (`focus_test.rb` passa sem edição)
- [x] Teste novo em `test/design/` para as duas regras; `navigation_canvas_test.rb` passa ou é reescrito só onde o NAV-41 muda a expectativa
- [x] Capturas com sessão em 390px e 1280px: "Sair" no mesmo fundo das outras entradas inativas; gate full passa, contagem registrada

**Tests**: unit (textual)
**Gate**: full
**Commit**: `fix(navegacao): tirar o estilo nativo do Sair e o sublinhado da navegação`

---

### T25: Navegação no topo da coluna lateral

**What**: Em viewport larga, a marca fica no topo da coluna, alinhada à esquerda, e a navegação logo abaixo dela.
**Where**: `app/assets/stylesheets/catalog.css`
**Depends on**: T24
**Reuses**: o bloco `@media (min-width: 64rem)` de `.site-header` (T12)
**Requirement**: NAV-40

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Dentro de `@media (min-width: 64rem)`, `.site-header` com `justify-content: flex-start` e `align-items: stretch`, e a marca com alinhamento à esquerda
- [x] Teste novo em `test/design/`, com recorte da media query, que falha se a coluna distribuir os filhos (`space-between`, `space-around`, `center`)
- [x] Capturas em 1280px da carta, da pasta e do catálogo: a `nav` começa logo abaixo da marca
- [x] `navigation_layout_test.rb` e `catalog_subgrid_layout_test.rb` passam; gate full passa, contagem registrada

**Tests**: unit (textual)
**Gate**: full
**Commit**: `fix(navegacao): pôr a navegação logo abaixo da marca na coluna lateral`

---

### T26: Filtros da coluna lateral sem vão

**What**: Os grupos de filtro na coluna ficam a `var(--space-4)` um do outro, e navegação e filtros formam uma superfície só.
**Where**: `app/assets/stylesheets/catalog.css`
**Depends on**: T25
**Reuses**: `.catalog__filters` e o subgrid de `main.catalog` (T18)
**Requirement**: NAV-42, NAV-32

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Em `≥ 64rem`, `.catalog__filters` empilha os grupos com `gap: var(--space-4)` e `align-content: start`, sem que a linha do subgrid estique o espaço entre eles
- [x] Nenhuma faixa de `surface-base` entre o cabeçalho e os filtros na coluna 1: os dois em `surface-raised`, sem `margin` nem `row-gap` entre as linhas da coluna
- [x] Teste novo em `test/design/` para o `gap` e o alinhamento; `catalog_subgrid_layout_test.rb` passa ou é reescrito só onde o NAV-42 muda a expectativa
- [x] Captura em 1280px, com e sem sessão: "Tipo" logo abaixo das cores; gate full passa, contagem registrada

**Tests**: unit (textual)
**Gate**: full
**Commit**: `fix(navegacao): empilhar os filtros da coluna lateral sem vão`

---

### T27: Filtros recolhidos no celular

**What**: Em viewport estreita, os controles de filtro ficam num `<details>` fechado que diz quantos filtros estão ativos; em viewport larga, continuam sempre visíveis.
**Where**: `app/views/catalog/index.html.erb`, `app/assets/stylesheets/catalog.css`
**Depends on**: T26
**Reuses**: `active_filter_count`, `ul.catalog__chips` (lista "Filtros ativos")
**Requirement**: NAV-43, NAV-44, NAV-45, NAV-14, NAV-27

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] `<details>` sem `open` envolve só `catalog__filters`; o `<summary>` diz "Filtros" e, com filtro ativo, "N filtro(s) ativo(s)" com a mesma contagem da linha de status
- [x] `ul.catalog__chips` continua fora do `<details>`, com os links de remoção
- [x] Sem JavaScript: abrir o `<details>` e tocar num chip aplica o filtro (NAV-14); com zero resultados, os controles continuam na página (NAV-27)
- [x] ⚠️ VERIFICAR: em `≥ 64rem`, `summary` fora de vista e `::details-content` visível com o `<details>` fechado, confirmado pela captura em 1280px. Se não funcionar, aplicar o fallback registrado nas Decisões de implementação e registrar a escolha na spec
- [x] Testes de integração novos para o `<details>`, o `<summary>` com e sem filtro, e a lista de ativos fora dele; teste de folha para a regra larga
- [x] Captura em 390px: a primeira carta da grade aparece acima de y=600 com o `<details>` fechado; gate full passa, contagem registrada

**Tests**: integration + unit (textual)
**Gate**: full
**Commit**: `feat(navegacao): recolher os filtros do catálogo no celular`

---

### T28: Busca e linha de status no desenho do canvas

**What**: Campo de busca e botão "Buscar" com 44px e as superfícies do design system; linha de status rente à grade.
**Where**: `app/assets/stylesheets/catalog.css`
**Depends on**: T27
**Reuses**: `.catalog__search`, `.catalog__status`
**Requirement**: NAV-46, NAV-47

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] O `input` de `.catalog__search` com `min-height: 44px`, fundo `var(--surface-raised)` e borda `var(--border-strong)`; o botão com `min-height: 44px`, fundo transparente e borda `var(--border-strong)`
- [x] `.catalog__status` sem `padding` nem `margin` horizontais próprios
- [x] O rótulo da busca continua associado ao campo e o foco continua visível
- [x] Teste novo em `test/design/`; `catalog_status_line_test.rb` passa; `contrast_test.rb` passa sem edição
- [x] Capturas em 390px e 1280px; gate full passa, contagem registrada

**Tests**: unit (textual)
**Gate**: full
**Commit**: `fix(navegacao): dar à busca e à linha de status a forma do canvas`

---

### T29: Imagem maior no detalhe da carta

**What**: O detalhe exibe no topo a imagem maior da primeira variante listada e, em viewport larga, numa coluna de 320px à esquerda dos dados.
**Where**: `app/views/catalog/show.html.erb`, `app/assets/stylesheets/catalog.css`
**Depends on**: T28
**Reuses**: `card_image_path` e o placeholder em camada do `_card_tile` (Req. 2.3)
**Requirement**: NAV-48, NAV-24, NAV-25

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Elemento novo de `card-detail` antes de `card-detail__data`, com a imagem da primeira variante de `@variants` e o placeholder (nome + `card_number`) na mesma medida, visível sem JS quando a imagem falha
- [x] A imagem tem `alt` que nomeia a carta e o código da variante; carta sem variante não renderiza o elemento e não dá erro
- [x] Em `≥ 64rem`, o elemento ocupa uma coluna de 320px à esquerda dos dados
- [x] `card_detail_test.rb`, `collection_ownership_ui_test.rb` e `wishlist_mark_ui_test.rb` passam **sem edição** (NAV-25); `card_detail_layout_test.rb` reescrito só onde o NAV-48 muda a expectativa
- [x] Testes de integração e de folha novos; capturas do detalhe em 390px e 1280px; gate full passa, contagem registrada

**Tests**: integration + unit (textual)
**Gate**: full
**Commit**: `feat(navegacao): mostrar a imagem maior no detalhe da carta`

---

### T30: Variantes do detalhe em linhas

**What**: Cada variante vira uma linha com miniatura própria, código, raridade, set, posse e wishlist, com os rótulos fora da vista.
**Where**: `app/assets/stylesheets/catalog.css`, `app/views/catalog/show.html.erb` (só se a grade pedir contêiner)
**Depends on**: T29
**Reuses**: `.variant`, `.variant__meta`, os partials de posse e de wishlist
**Requirement**: NAV-49, NAV-25, Req. 5.2

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] `.variant` em grid de três colunas (miniatura, meta, controles) em toda largura; em 360px os controles descem sem scroll horizontal (NAV-28)
- [x] Cada linha mantém a imagem própria da variante (Req. 5.2)
- [x] Os `dt` de `.variant__meta` continuam no HTML e saem da vista pelo padrão de recorte, sem `display: none`
- [x] Contêiner novo, se houver, é elemento de `variant`, com regra na folha, e não muda a ordem de leitura
- [x] `card_detail_test.rb` passa **sem edição**; teste de folha novo; captura do detalhe em 390px e 1280px; gate full passa, contagem registrada

**Tests**: unit (textual)
**Gate**: full
**Commit**: `feat(navegacao): listar as variantes do detalhe em linhas`

---

### T31: Controles de posse de 44px no detalhe

**What**: No detalhe, os botões +1 e −1 passam a ter alvo de 44×44px; na grade, continuam com 24px.
**Where**: `app/assets/stylesheets/catalog.css`
**Depends on**: T30
**Reuses**: `.ownership__button`
**Requirement**: NAV-50

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Regra `.card-detail .ownership__button` com `min-height: 44px` e `min-width: 44px`; a regra base continua com 24px
- [x] `collection_ownership_ui_test.rb` passa **sem edição**
- [x] Teste novo em `test/design/` para a regra escopada, que falha se ela sumir ou cair abaixo de 44px
- [x] Captura do detalhe com sessão em 390px e 1280px; gate full passa, contagem registrada

**Tests**: unit (textual)
**Gate**: full
**Commit**: `fix(navegacao): dar alvo de 44px aos controles de posse do detalhe`

---

### T32: Minha pasta em linhas e ações agrupadas

**What**: Cada set vira uma linha sem moldura, com a contagem ao lado do nome e a barra abaixo, e os links de wishlist, import e export formam um grupo separado de "Adicionar cartas".
**Where**: `app/assets/stylesheets/catalog.css`, `app/views/progress/index.html.erb` (só o agrupamento das ações)
**Depends on**: T31
**Reuses**: `.progress-set`, `.progress__actions`, `progress/_export_link`
**Requirement**: NAV-51, NAV-19, NAV-39

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] `.progress-set` sem `border` nem `background` próprios; nome e contagem "possuídas / total" na mesma linha, a barra abaixo, percentual e parallels como legenda
- [x] Os três links secundários num contêiner próprio, elemento de `progress`, separado de "Adicionar cartas"; o export continua sendo o partial, não uma cópia
- [x] `progress_ui_test.rb`, `set_progress_plan_test.rb` e `collection_export_link_test.rb` passam **sem edição**; `minha_pasta_test.rb` reescrito só onde o NAV-51 muda a expectativa
- [x] Em 360px, nome longo de set quebra linha sem scroll horizontal (NAV-28)
- [x] Teste de integração para o agrupamento e teste de folha para a linha; capturas da pasta em 390px e 1280px; gate full passa, contagem registrada

**Tests**: integration + unit (textual)
**Gate**: full
**Commit**: `feat(navegacao): mostrar a pasta em linhas e agrupar as ações`

---

### T33: Revisão sobre capturas e fechamento

**What**: Rodar a revisão de a11y sobre o diff das Fases 11–14, submeter as capturas ao dono lado a lado com o canvas e fechar a feature.
**Where**: `.specs/features/navegacao/tasks.md`, `.specs/features/navegacao/canvas-conformance.md`, `.context/tasks.md`
**Depends on**: T32
**Reuses**: `spec/visual/capture.cjs`, o plano de delegação (`ecc:a11y-architect`, só leitura)
**Requirement**: NAV-01..NAV-51 (Success Criteria da spec)

**Tools**:

- MCP: NONE
- Skill: NONE — subagente `ecc:a11y-architect`, só leitura

**Done when**:

- [x] `ecc:a11y-architect` revisou o `<details>`, os rótulos fora da vista das variantes, os alvos de 44px e a navegação. Achados CRITICAL e HIGH triados e, os que procederem, corrigidos antes do Verifier
- [x] `canvas-conformance.md` ganha a conferência renderizada: captura × artboard, por tela, com defeito ou recusa registrada
- [x] ~~O dono comparou as capturas com o canvas, com e sem sessão, em 360px e 1280px, e aprovou ou listou o que reprova~~ — **substituído pela feature `conformidade`**. O dono comparou as capturas em 2026-09-27 e reprovou a interface ("ainda não tem muito a ver com o artifact"). A correção não cabe nesta spec, porque NAV-25 e NAV-48 empurram contra o canvas; vai para `.specs/features/conformidade/`, com o artboard como critério de aceite (AD-016)
- [x] Os Success Criteria da spec estão marcados, e o item Req. 4.9 / 13.1–13.20 de `.context/tasks.md` §6 está fechado
- [x] Gate build passa (2026-09-27; gate full no mesmo HEAD: 1197 runs, 0 falhas, RuboCop limpo)

**Tests**: none
**Gate**: build
**Commit**: `docs(navegacao): registrar a revisão sobre capturas e fechar a feature`

---

### T34: Ratificar o teste protegido e fechar as lacunas de precisão

**What**: Registrar a AD-017 (edição de `6394755` aceita pelo dono), corrigir o Success Criterion e resolver na spec as seis lacunas de precisão do Verifier.
**Where**: `.specs/STATE.md`, `.specs/features/navegacao/spec.md`
**Depends on**: T33
**Reuses**: `validation.md` §"Lacunas de precisão da spec"
**Requirement**: Success Criteria, NAV-01, NAV-04, NAV-38, NAV-45, NAV-47, NAV-49

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] AD-017 em `STATE.md`, com a decisão do dono de 2026-09-27
- [x] O Success Criterion diz "seis dos sete" e cita a AD-017
- [x] NAV-04 inclui "Entrar" e "Criar conta" e exclui páginas sem entrada, como o detalhe (decisão do dono: corrigir o código)
- [x] NAV-38 diz o par da barra (`value` possuídas, `max` total de variantes)
- [x] NAV-01 e NAV-45 registram a premissa; NAV-47 e NAV-49 remetem a medida à `conformidade`; "Todas" ativo vai para a `conformidade` como critério

**Tests**: none
**Gate**: quick
**Commit**: `docs(navegacao): ratificar a edição do teste protegido e fechar as lacunas da spec`

---

### T35: `aria-current` em "Entrar" e "Criar conta"

**What**: As duas entradas sem sessão passam a usar `nav_link_to`, e o detalhe da carta fica sem entrada corrente.
**Where**: `app/views/layouts/application.html.erb`, `test/integration/navegacao_principal_test.rb`
**Depends on**: T34
**Reuses**: `ApplicationHelper#nav_link_to`
**Requirement**: NAV-04

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Em `/session/new`, `a[aria-current=page]` é "Entrar", e só ele; em `/registration/new`, é "Criar conta", e só ele
- [x] Em `card_path` de uma carta do fixture, nenhum `[aria-current]` dentro de `.site-header__nav`, com e sem sessão (mata o M08)
- [x] Gate full passa

**Tests**: integration
**Gate**: full
**Commit**: `fix(navegacao): marcar Entrar e Criar conta como entrada atual`

---

### T36: Indicadores da pasta provados com quantidade 0

**What**: O teste de integração da pasta cobre item de quantidade 0 no método que a tela usa, e o método morto sai.
**Where**: `test/integration/minha_pasta_test.rb`, `app/models/collection_item.rb`, `test/models/collection_item_test.rb`
**Depends on**: T34
**Reuses**: `CollectionItem.collection_stats_for` (`collection_item.rb:88`)
**Requirement**: NAV-17, NAV-18

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Em `minha_pasta_test.rb`, um `CollectionItem` com `quantity: 0` não muda os dois indicadores renderizados (cópias e variantes distintas), com os números exatos (mata o M06)
- [x] `distinct_variants_for` sai de `collection_item.rb`; os seis testes dele em `collection_item_test.rb` passam a exercer `collection_stats_for` com as mesmas entradas e as mesmas expectativas (≥ 1, exclui 0, usuário sem itens, `nil`, isolamento, recusa de id)
- [x] Os testes de `minha_pasta_test.rb:248-255` e `:386-391`, que prometem 24px e 44px sem medir, passam a medir pela folha com `Stylesheet.resolved` (`test/design/support/stylesheet.rb`), com `assert_equal` no valor
- [x] Gate full passa

**Tests**: integration + unit
**Gate**: full
**Commit**: `test(navegacao): provar os indicadores da pasta com quantidade zero`

---

### T37: Barra do set provada por valor

**What**: Teste de integração novo afirma `value` e `max` da barra com os números do fixture e a ausência da barra num set sem total base.
**Where**: `test/integration/set_progress_bar_test.rb` (novo)
**Depends on**: T34
**Reuses**: helpers de sessão e fixture de `minha_pasta_test.rb`
**Requirement**: NAV-38

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] No `li` de um set com posse conhecida, `.progress-set__bar` tem `value` igual às variantes possuídas e `max` igual ao total de variantes, os dois iguais aos números da contagem da mesma linha (mata o M12)
- [ ] Num set com `base_set_size: nil`, a contagem aparece e `.progress-set__bar` tem `count: 0` naquele `li` (mata o M13)
- [ ] Gate full passa

**Tests**: integration
**Gate**: full
**Commit**: `test(navegacao): provar a barra do set por valor`

---

### T38: "Limpar filtros" do vazio preserva a ordenação

**What**: O link do estado vazio usa `clear_filters_url`, e a linha de status ganha testes que medem.
**Where**: `app/views/catalog/index.html.erb`, `test/integration/catalog_status_line_test.rb`
**Depends on**: T34
**Reuses**: `CatalogHelper#clear_filters_url`
**Requirement**: NAV-36, NAV-27

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] `index.html.erb:258` usa `clear_filters_url(@result.active_filters)`; com `colors[]=Purple&sort=name&dir=desc` e zero resultados, o único "Limpar filtros" aponta para uma URL com `sort=name` e `dir=desc` e sem `colors`
- [ ] Com mais cartas que uma página, a contagem mostra o total, não o tamanho da página (mata o M39)
- [ ] `catalog_status_line_test.rb:145`, que promete 24px sem medir, passa a medir pela folha com `Stylesheet.resolved`
- [ ] Gate full passa

**Tests**: integration
**Gate**: full
**Commit**: `fix(navegacao): preservar a ordenação no Limpar filtros do vazio`

---

### T39: `filter_toggle_url` aceita chave string

**What**: O helper normaliza chave e filtros para símbolo, e o teste cobre chave string.
**Where**: `app/helpers/catalog_helper.rb`, `test/helpers/catalog_helper_test.rb`
**Depends on**: T34
**Reuses**: `filter_toggle_url` (`catalog_helper.rb:66`)
**Requirement**: NAV-33

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] `filter_toggle_url({ colors: ["Red"] }, "colors", "Red")` devolve `/catalog` sem `colors`; `({ owned: "owned" }, "owned", "owned")` devolve URL sem `owned`; o mesmo com o hash de chaves string
- [ ] Os comentários do método ficam na densidade do resto do arquivo
- [ ] Gate full passa

**Tests**: unit
**Gate**: full
**Commit**: `fix(navegacao): aceitar chave string na alternância de filtro`

---

### T40: Alvo de 44px do chip medido na regra do chip

**What**: O teste do NAV-35 lê a regra resolvida de `.catalog__chip` em vez de procurar o texto na folha inteira.
**Where**: `test/design/filter_layout_test.rb`
**Depends on**: T34
**Reuses**: `Stylesheet.resolved`
**Requirement**: NAV-35

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] `filter_layout_test.rb:92-110` usa `Stylesheet.resolved("catalog__chip")` com `assert_equal "44px"` em `min-height`, e o mesmo para borda, raio e o fundo do chip ativo (mata o M14)
- [ ] Gate full passa

**Tests**: unit
**Gate**: full
**Commit**: `test(navegacao): medir o alvo do chip na regra do chip`

---

### T41: Set selecionado e "×" do chip de cor

**What**: Restaurar a asserção do set selecionado, afirmar o "×" do chip de cor e corrigir os seletores sem efeito.
**Where**: `test/integration/catalog_filter_controls_test.rb`
**Depends on**: T34
**Reuses**: fixture de ingestão
**Requirement**: NAV-11, NAV-34, NAV-26

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] `get catalog_path(sets: ["OP02"])` → `option[value=OP02][selected]` e `option[value=OP01]:not([selected])` (mata o M43)
- [ ] O chip de cor ativo tem `span[aria-hidden='true']` com texto "×" (mata o M41)
- [ ] Os seletores de `:265`, `:274` e `:287-288` passam a casar com o HTML real; cada um é conferido fazendo-o falhar uma vez com o valor trocado
- [ ] Gate full passa

**Tests**: integration
**Gate**: full
**Commit**: `test(navegacao): provar o set selecionado e o × do chip de cor`

---

### T42: Rastreabilidade e registro da iteração

**What**: Atualizar a rastreabilidade da spec e registrar no `validation.md` o que foi para a `conformidade`.
**Where**: `.specs/features/navegacao/spec.md`, `.specs/features/navegacao/validation.md`
**Depends on**: T35, T36, T37, T38, T39, T40, T41
**Reuses**: tabela "Requirement Traceability"
**Requirement**: NAV-30..NAV-39, NAV-47, NAV-49

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] NAV-30..NAV-39 deixam de estar `Pending`; NAV-04, 11, 18, 34, 35, 36 e 38 citam a task de correção
- [ ] `validation.md` registra que M42 (NAV-47) e M45 (NAV-49) não viram correção aqui: a `conformidade` reescreve a linha de status e a linha da variante, e leva as duas medidas como critério
- [ ] Gate full passa, contagem registrada

**Tests**: none
**Gate**: full
**Commit**: `docs(navegacao): atualizar a rastreabilidade depois das correções`

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
| T24–T32 — navegação, `<details>`, busca, detalhe, pasta | `ecc:a11y-architect` na T33 |
| T27, T29, T32 — testes de integração novos | `ecc:pr-test-analyzer` antes do Verifier |

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
| T22 | um script de host | ✅ |
| T23 | uma regra e dois pseudo-elementos | ✅ |
| T24 | duas regras da navegação | ✅ coeso |
| T25 | uma regra da coluna | ✅ |
| T26 | uma regra dos filtros largos | ✅ |
| T27 | um `<details>` mais a regra larga | ⚠️ view e folha, um conceito |
| T28 | duas regras (busca, status) | ✅ coeso |
| T29 | um elemento da view mais a coluna larga | ⚠️ view e folha, um conceito |
| T30 | uma grade de linha | ✅ |
| T31 | uma regra escopada | ✅ |
| T32 | linha do set mais agrupamento de ações | ⚠️ dois ajustes na mesma página |
| T33 | revisão | ✅ |
| T34 | documentação | ✅ |
| T35 | um layout e o teste dele | ✅ |
| T36 | um método morto e os testes que o cobriam | ⚠️ três arquivos, um conceito |
| T37 | um teste novo | ✅ |
| T38 | um link e o teste da linha | ✅ |
| T39 | um helper e o teste dele | ✅ |
| T40 | um teste | ✅ |
| T41 | um teste | ✅ |
| T42 | documentação | ✅ |

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
| T22 | T21 | T21 → T22 (Fase 11) | ✅ |
| T23 | T22 | T22 → T23 | ✅ |
| T24 | T23 | T23 → T24 | ✅ |
| T25 | T24 | T24 → T25 (Fase 12) | ✅ |
| T26 | T25 | T25 → T26 | ✅ |
| T27 | T26 | T26 → T27 | ✅ |
| T28 | T27 | T27 → T28 | ✅ |
| T29 | T28 | T28 → T29 (Fase 13) | ✅ |
| T30 | T29 | T29 → T30 | ✅ |
| T31 | T30 | T30 → T31 | ✅ |
| T32 | T31 | T31 → T32 (Fase 14) | ✅ |
| T33 | T32 | T32 → T33 (Fase 15) | ✅ |
| T34 | T33 | T33 → T34 (Fase 16) | ✅ |
| T35 | T34 | T34 → T35 (Fase 16) | ✅ |
| T36 | T34 | T34 → T36 (Fase 16) | ✅ |
| T37 | T34 | T34 → T37 (Fase 16) | ✅ |
| T38 | T34 | T34 → T38 (Fase 16) | ✅ |
| T39 | T34 | T34 → T39 (Fase 16) | ✅ |
| T40 | T34 | T34 → T40 (Fase 16) | ✅ |
| T41 | T34 | T34 → T41 (Fase 16) | ✅ |
| T42 | T35..T41 | T35..T41 → T42 (Fase 16) | ✅ |

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
| T22 | script de host | none | none | ✅ |
| T23 | folha | unit (textual) | unit | ✅ |
| T24 | folha | unit (textual) | unit | ✅ |
| T25 | folha | unit (textual) | unit | ✅ |
| T26 | folha | unit (textual) | unit | ✅ |
| T27 | view e folha | integration + unit (textual) | integration + unit | ✅ |
| T28 | folha | unit (textual) | unit | ✅ |
| T29 | view e folha | integration + unit (textual) | integration + unit | ✅ |
| T30 | folha | unit (textual) | unit | ✅ |
| T31 | folha | unit (textual) | unit | ✅ |
| T32 | view e folha | integration + unit (textual) | integration + unit | ✅ |
| T33 | revisão | none | none | ✅ |
| T34 | documentação | none | none | ✅ |
| T35 | layout | integration | integration | ✅ |
| T36 | model e view | integration + unit | integration + unit | ✅ |
| T37 | view | integration | integration | ✅ |
| T38 | view | integration | integration | ✅ |
| T39 | helper | unit | unit | ✅ |
| T40 | folha | unit (textual) | unit | ✅ |
| T41 | view | integration | integration | ✅ |
| T42 | documentação | none | none | ✅ |
