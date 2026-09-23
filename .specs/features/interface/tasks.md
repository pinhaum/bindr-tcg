# Plano de execução — Camada de apresentação (Fase 6)

Espelha `.context/tasks.md` §6.1–§6.5. A fonte de verdade da ordem é
`.context/tasks.md`; este documento acrescenta dependências, gate e teste
explícitos por task (AD-005). **Ao concluir uma task, marcar o checkbox nos dois
planos e commitar junto com o código.** Cada seção do `.context/tasks.md` só
fecha quando todas as tasks que ela cobre fecharem:

| Seção | Cobre | Fecha na |
|---|---|---|
| §6.1 Camada de tokens | T1 | T1 |
| §6.2 Contraste como teste | T2, T3 | T3 |
| §6.3 Aplicar os tokens aos blocos existentes | T4, T5, T6, T7 | T7 |
| §6.4 Modificadores BEM sem regra | T8, T9, T10 | T10 |
| §6.5 Regras de conteúdo e foco | T11, T12, T13 | T13 |

A T14 não fecha seção: é o Success Criterion "revisão visual aprovada pelo dono
do produto" da `spec.md`, pré-requisito do Verifier.

A feature é governada por **AD-011** e por `.context/design.md` §11, que é a
cópia normativa do design system. Os valores de token saem de lá, não do
artifact externo.

**Status**: Approved (2026-09-22, pelo dono do produto) — execução não iniciada

## Execution Protocol

Implementar com a skill `tlc-spec-driven`, seguindo o fluxo Execute e as
Critical Rules dela. Se a skill não puder ser ativada, parar e avisar.

- Uma task por vez, em ordem. Não abrir a próxima com a anterior incompleta.
- Toda task termina com código que roda e teste que passa.
- Testes derivam dos critérios de aceitação da spec, nunca espelham a
  implementação. Nunca enfraquecer, pular ou apagar teste para passar no gate.
- **Os testes que já leem `catalog.css` não são editados.** São sete arquivos
  (`catalog_grid_test.rb`, `progress_ui_test.rb`,
  `collection_ownership_ui_test.rb`, `collection_export_link_test.rb`,
  `collection_import_preview_ui_test.rb`, `collection_import_summary_test.rb`,
  `set_progress_plan_test.rb`). Se um deles quebrar, o sinal é real: corrigir o
  CSS, não o teste. É o Success Criterion "as verificações de 360px passam sem
  edição" e o Edge Case da largura fixa.
- **Par de contraste que reprovar se corrige no valor do token, nunca no
  limiar** (Edge Case da spec). Valor de token que mude em relação a
  `.context/design.md` §11.3 atualiza o design no mesmo commit.
- `catalog.css` **não é reorganizado, renomeado nem dividido** (§11.7). Tokens e
  regras novas são acrescentados; declarações existentes trocam literal por
  `var(--…)` no próprio lugar.
- Nenhuma view muda de estrutura (Out of Scope). As duas exceções previstas são
  **classe ou elemento inline**, sem mudar a árvore: modificador condicional de
  posse (T9) e envoltório `code` em identificadores inline (T11). Cada uma é
  registrada com `SPEC_DEVIATION` se acabar exigindo mais que isso.
- Se um requisito se mostrar errado durante a execução, parar e avisar o dono do
  produto. Corrigir `.context/requirements.md` é decisão dele (AD-005).
- Um commit atômico por task, em português brasileiro, Conventional Commits, sem
  linha de atribuição.
- Não há navegador no container. Toda prova é textual (sobre a folha) ou de
  integração (sobre o HTML renderizado). A verificação renderizada fica com o
  dono do produto na T14.

### Inventário medido antes do plano

Medido em `main` (`8365e1c`), por varredura de `class=` e `class:` em
`app/views` e `app/helpers` contra os seletores de `catalog.css`:

- **21 blocos BEM** em `catalog.css`, mais o seletor raiz (`*`, `body`):
  `auth`, `card-detail`, `card-tile`, `catalog`, `collection-export`, `field`,
  `filter-chip`, `flash`, `flash-area`, `import-preview`, `import-summary`,
  `ownership`, `pagination`, `progress`, `progress-set`, `site-header`,
  `variant`, `variant-list`, `wishlist`, `wishlist-item`, `wishlist-mark`.
- **25 classes usadas nas views sem nenhuma regra** — não 23 como diz a spec, e
  nem todas são modificadores:
  - 15 modificadores: `flash--notice`, `flash--alert` (interpolados em
    `layouts/_flash_message.html.erb:14`), `field--attributes`, `field--block`,
    `field--card-type`, `field--colors`, `field--cost`, `field--counter`,
    `field--life`, `field--power`, `field--traits`,
    `ownership__button--increment`, `ownership__button--decrement`,
    `wishlist-item__status--fulfilled`, `wishlist-item__status--pending`.
  - 10 elementos: `card-detail__variants`, `card-tile__placeholder-name`,
    `catalog__empty-reset`, `filter-chip__remove`, `pagination__next`,
    `pagination__prev`, `pagination__status`, `variant__code`,
    `variant__rarity`, `variant__set`.
- **Zero hex, zero `color`/`background-color` temático, zero sombra ou
  gradiente** na folha hoje. `:root` declara só `--tile-min: 150px` e
  `--gap: 0.75rem`.
- Foco: três seletores com `outline: 2px solid currentcolor` (`catalog.css:395`).
- `ownership__count` é renderizado sempre, inclusive com quantidade zero
  (`collection_items/_ownership.html.erb`) — daí o modificador condicional da T9.

A T10 não depende da contagem: o teste de guarda é **derivado** (toda classe
das views precisa de regra), então fecha pelas 25 medidas e por qualquer uma
que apareça depois. A divergência de número com a spec fica registrada para
correção no fechamento da MVP (§7.2).

## Test Coverage Matrix

> Gerado a partir do código, das diretrizes do projeto (`CLAUDE.md`,
> `.context/design.md` §11.7) e da spec. Confirmar antes do Execute.

| Camada | Tipo de teste | Cobertura esperada | Onde | Comando |
|---|---|---|---|---|
| Tokens e regras da folha (texto de `catalog.css`) | unit | Todo AC textual de INT-01..INT-05, INT-09..INT-12, com falha que nomeia o token, o par ou o seletor | `test/design/*_test.rb` | `bin/rails test test/design` |
| Cálculo de contraste | unit | Fórmula WCAG de luminância relativa; todo par de §11.3; token ausente falha | `test/design/contrast_test.rb` | `bin/rails test test/design` |
| HTML renderizado (flash, posse, `code`, chip) | integration | Caminho feliz + ausência (faltante sem badge) + toda tela que renderiza o identificador | `test/integration/*_ui_test.rb` — `get`, `assert_select` | `bin/rails test test/integration` |
| Layout de 360px | integration (textual) | Os testes existentes, **sem edição**, mais a conta de §11.5 | `test/integration/catalog_grid_test.rb` (não editar), `test/design/layout_test.rb` | `bin/rails test` |
| Aparência renderizada | none | Revisão visual do dono do produto (T14) | — | — |

O projeto não usa fixtures YAML: cada teste cria seus registros no `setup`. A
suíte roda em paralelo. `bin/rails test` sem argumento inclui `test/design/`.

## Gate Check Commands

| Gate | Comando |
|---|---|
| quick | `docker compose exec app bin/rails test test/design` |
| full | `docker compose exec app bin/rails test && docker compose exec app bin/rubocop` |
| build | `docker compose build && docker compose exec app bin/rails test && docker compose exec app bin/rubocop` |

A contagem de base é medida no início da T1 (`bin/rails test`, total de runs) e
registrada aqui. Todo gate depois disso compara contra ela: o total só cresce.

**Contagem de base**: 772 runs, 3390 assertions (medido em main antes de T1)

## Execution Plan

### Phase 1: Fundação

Os tokens e as provas que só dependem deles. Nada visual muda além de `body`
passar a ter fundo e tinta — é o mínimo para os pares de contraste terem o que
medir.

```
T1 → T2 → T3
```

### Phase 2: Aplicação dos tokens

Os 21 blocos consumindo tokens, um grupo de telas por task. A guarda de
literais nasce na T4 cobrindo os blocos dela e cresce a cada task; na T7 cobre a
folha inteira.

```
T3 → T4 → T5 → T6 → T7
```

### Phase 3: Estado sem depender de cor

O único defeito percebido da feature (`flash--notice` = `flash--alert`), a
posse por badge e o resto das classes sem regra.

```
T7 → T8 → T9 → T10
```

### Phase 4: Conteúdo e foco

`code` nos identificadores, anel de foco único e as proibições (emoji, `accent`
no chip de cor, `border` em controle).

```
T10 → T11 → T12 → T13
```

### Phase 5: Revisão

```
T13 → T14
```

## Task Breakdown

### T1: Camada de tokens em `:root`

**What**: Declarar em `:root` de `catalog.css` todos os tokens de `.context/design.md` §11.3–§11.5 e `color-scheme: dark`, e fazer `body` consumir `surface-base` e `ink`.
**Where**: `app/assets/stylesheets/catalog.css`
**Depends on**: None
**Reuses**: o `:root` existente (`catalog.css:10`), mantendo `--tile-min` e `--gap`
**Requirement**: INT-01, INT-02

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Contagem de base medida e registrada em "Gate Check Commands"
- [x] `:root` declara os dez tokens de cor com os valores de §11.3, os seis estilos de tipografia de §11.4 (tamanho, altura de linha e peso como tokens separados, mais `--font-sans` e `--font-mono`), `space-1..4` e `radius-sm/md/full` de §11.5
- [x] `:root` declara `color-scheme: dark`; a folha não contém `prefers-color-scheme`
- [x] `body` usa `background-color: var(--surface-base)` e `color: var(--ink)`
- [x] `test/design/tokens_test.rb` lê `:root` da folha e prova cada token com o valor de §11 — a lista esperada vive no teste, não é lida do CSS; token ausente ou com valor diferente falha nomeando o token
- [x] Teste prova `color-scheme: dark` presente e `prefers-color-scheme` ausente
- [x] Os sete arquivos de teste que leem `catalog.css` passam sem edição
- [x] Gate full passa; total = base + novos

**Tests**: unit
**Gate**: full

**Commit**: `feat(interface): declarar a camada de tokens do design system`

---

### T2: Contraste calculado sobre os tokens

**What**: Teste que calcula a razão de contraste WCAG entre pares de tokens lidos da folha e exige 4.5:1 para texto e 3:1 para borda de controle e anel de foco.
**Where**: `test/design/contrast_test.rb`
**Depends on**: T1
**Reuses**: o leitor de `:root` da T1 (extrair para `test/design/support/stylesheet.rb` se a T1 o tiver escrito inline)
**Requirement**: INT-05

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Luminância relativa e razão implementadas pela fórmula WCAG 2.2 — **Verificado contra W3C (0.04045, WCAG 2.2, Note 2)**: "Before May 2021 the value of 0.04045 in the definition was different (0.03928). It has no practical effect on the calculations."
- [x] O cálculo é provado contra valores conhecidos: preto/branco = 21:1, par idêntico = 1:1
- [x] Pares a 4.5:1: `ink`, `ink-muted` e `accent` sobre `surface-base`, `surface-raised` e `surface-sunken`; `on-accent` sobre `accent` e sobre `danger`; `danger` sobre `surface-base`
- [x] Pares a 3:1: `border-strong` e `accent` (anel de foco) sobre as três superfícies
- [x] Os valores declarados em §11.3 e §11.6 (15.35, 7.18, 8.55, 5.57, 4.23, 7.15) são **recalculados**, não copiados: o teste assere o limiar, e a razão medida aparece na mensagem
- [x] Falha nomeia o par e a razão medida — provado com um par reprovado sintético dentro do próprio teste, não por mutação da folha
- [x] Token referenciado por um par e ausente da folha **falha**, não é pulado (Edge Case)
- [x] Se algum par do design system reprovar, o token é corrigido na folha e em §11.3 no mesmo commit, com a razão nova (todos passam)
- [x] Gate quick passa

**Tests**: unit
**Gate**: quick

**Commit**: `test(interface): provar o contraste dos pares de tokens`

---

### T3: Duas matizes, sem sombra, sem gradiente

**What**: Teste que prova que toda cor da folha é token de `:root` com matiz 228° ou 66° (ou `danger` em 28°) e que nenhuma regra usa sombra ou gradiente.
**Where**: `test/design/palette_test.rb`
**Depends on**: T2
**Reuses**: o leitor da folha de `test/design/support/stylesheet.rb`
**Requirement**: INT-03, INT-04

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Nenhum hex, `rgb()` ou `hsl()` fora de `:root` (comentários descontados)
- [x] Todo hex de `:root` tem matiz dentro de uma tolerância declarada no teste em torno de 228° ou 66°, ou é `danger` em torno de 28°; para cor de saturação muito baixa, onde a matiz é instável, a regra é explícita no teste, não um `skip`
- [x] Nenhuma ocorrência de `box-shadow`, `text-shadow`, `drop-shadow` ou `gradient(`
- [x] Nenhuma palavra-chave de cor nomeada (`red`, `white`, …) além de `currentcolor`, `transparent` e `inherit`
- [x] Gate quick passa — §6.2 fecha aqui

**Tests**: unit
**Gate**: quick

**Commit**: `test(interface): travar a paleta em duas matizes e sem sombra`

**Nota**: as duas ocorrências de `rgb(0 0 0 / 6%)` em `.card-tile__art` (linha 171) e `.variant__art` (linha 251) de `app/assets/stylesheets/catalog.css` foram trocadas por `var(--surface-sunken)` na T3, adiantando o poço da T4, porque a guarda de literais de cor exige que toda cor use token.

---

### T4: Tokens no layout e no catálogo

**What**: Trocar literais por tokens no seletor raiz e nos blocos `site-header`, `flash-area`, `flash`, `catalog`, `filter-chip`, `card-tile` e `pagination`, e criar a guarda de literais para eles.
**Where**: `app/assets/stylesheets/catalog.css`
**Depends on**: T3
**Reuses**: tokens da T1; o leitor de `test/design/support/stylesheet.rb`
**Requirement**: INT-01, INT-12

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Nos blocos listados, `font-size`, `line-height`, `font-weight`, `color`, `background-color`, `border-color`, `padding`, `margin`, `gap` e `border-radius` usam `var(--…)`; `opacity: 0.7` usado como texto secundário vira `color: var(--ink-muted)`
- [x] `border: 1px solid currentcolor` vira `border-strong` em controle e `border` só em hairline decorativa
- [x] `surface-raised` nunca aparece sem borda no mesmo seletor (§11.3: 1.20:1 não delimita sozinho)
- [x] Tile e poço da imagem em `radius-md`; placeholder em `surface-sunken` ocupando a mesma caixa da imagem (Edge Case do reflow) — provado por teste textual de que placeholder e imagem compartilham a mesma `aspect-ratio`
- [x] `test/design/literal_values_test.rb` prova, para os blocos desta task, que nenhuma das propriedades acima tem literal (exceções declaradas no teste: `0`, `auto`, `100%`, `1fr`, `inherit`)
- [x] `test/design/layout_test.rb` prova a conta de §11.5 com os valores reais da folha: `2 × --tile-min + 2 × padding lateral da página + gap da grade ≤ 360`
- [x] Os testes de 360px de `catalog_grid_test.rb` passam sem edição
- [x] Gate full passa

**Tests**: unit
**Gate**: full

**Commit**: `feat(interface): aplicar os tokens ao layout e ao catálogo`

---

### T5: Tokens no detalhe da carta e no controle de posse

**What**: Trocar literais por tokens em `card-detail`, `field`, `variant`, `variant-list` e `ownership`, e estender a guarda de literais a esses blocos.
**Where**: `app/assets/stylesheets/catalog.css`
**Depends on**: T4
**Reuses**: `test/design/literal_values_test.rb` da T4
**Requirement**: INT-01

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Os cinco blocos sem literal nas propriedades da T4
- [x] `card-detail__name` em `display`; `field dt` e `variant__meta dt` em `caption` com `ink-muted`
- [x] Botões de `ownership` com borda `border-strong` e raio `radius-md`; nenhum usa `accent` como fundo (o uso de `accent` na posse é o badge da T9)
- [x] A guarda cobre os blocos da T4 e da T5
- [x] `collection_ownership_ui_test.rb` passa sem edição
- [x] Gate full passa

**Tests**: unit
**Gate**: full

**Commit**: `feat(interface): aplicar os tokens ao detalhe e à posse`

---

### T6: Tokens em autenticação e wishlist

**What**: Trocar literais por tokens em `auth`, `wishlist`, `wishlist-item` e `wishlist-mark`, e estender a guarda de literais.
**Where**: `app/assets/stylesheets/catalog.css`
**Depends on**: T5
**Reuses**: `test/design/literal_values_test.rb`
**Requirement**: INT-01

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Os quatro blocos sem literal nas propriedades da T4
- [x] Inputs de `auth` com borda `border-strong`, fundo `surface-sunken`, raio `radius-sm`; título em `display`
- [x] Botão de envio de `auth` é a única ação em `accent` da tela, com texto `on-accent`
- [x] `wishlist-item--fulfilled` não comunica "atendido" só por cor — o rótulo escrito que já existe continua sendo o sinal
- [x] A guarda cobre os blocos da T4 à T6
- [x] Gate full passa

**Tests**: unit
**Gate**: full

**Commit**: `feat(interface): aplicar os tokens à autenticação e à wishlist`

---

### T7: Tokens em progresso e portabilidade, e guarda na folha inteira

**What**: Trocar literais por tokens em `progress`, `progress-set`, `collection-export`, `import-preview` e `import-summary`, e fazer a guarda de literais cobrir a folha inteira.
**Where**: `app/assets/stylesheets/catalog.css`
**Depends on**: T6
**Reuses**: `test/design/literal_values_test.rb`
**Requirement**: INT-01, INT-12

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Os cinco blocos sem literal nas propriedades da T4
- [x] `progress-set__code` em `code` (código de set, identificador lido caractere a caractere)
- [x] A guarda deixa de ter lista de blocos: varre **todo** seletor fora de `:root`; e um teste prova que o conjunto de blocos da folha é o esperado, para bloco novo não escapar em silêncio
- [x] Os arquivos que filtram a folha por prefixo (`progress-*`, `import-preview*`, `import-summary*`, `collection-export*`) passam sem edição
- [x] Gate full passa — §6.3 fecha aqui

**Tests**: unit
**Gate**: full

**Commit**: `feat(interface): aplicar os tokens a progresso e portabilidade`

---

### T8: Erro e sucesso distinguíveis sem cor

**What**: Dar a `flash--alert` e `flash--notice` regras que os diferenciem por forma e peso, não só por cor.
**Where**: `app/assets/stylesheets/catalog.css`
**Depends on**: T7
**Reuses**: `layouts/_flash_message.html.erb` (sem mudança de marcação)
**Requirement**: INT-06

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] `flash--alert` e `flash--notice` têm regras próprias que diferem em pelo menos uma propriedade não-cromática (espessura ou estilo de borda, peso do texto)
- [x] **`flash--alert` não usa `danger`**: é mensagem de validação, e §11.6 reserva `danger` para ação destrutiva confirmada
- [x] Teste textual prova a diferença não-cromática: descontadas as declarações de cor das duas regras, elas continuam diferentes
- [x] Teste de integração provoca um `alert` (login inválido) e um `notice` e prova a classe certa em cada um
- [x] Gate full passa

**Tests**: integration
**Gate**: full

**Commit**: `fix(interface): distinguir mensagem de erro de sucesso sem depender de cor`

---

### T9: Posse por badge com número

**What**: Exibir a quantidade possuída como badge `radius-full` em `accent` só quando a quantidade for maior que zero.
**Where**: `app/views/collection_items/_ownership.html.erb`
**Depends on**: T8
**Reuses**: `ownership__count` existente; o Turbo Stream `update` da `colecao` (o badge vive dentro do contêiner que o Stream troca)
**Requirement**: INT-07

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] `ownership__count` recebe o modificador `ownership__count--owned` só quando `quantity > 0`; a árvore do partial não muda
- [x] A regra de `ownership__count--owned` usa `radius-full`, fundo `accent`, texto `on-accent`, e é o **único** uso de `radius-full` na folha (provado por teste textual)
- [x] Teste de integração: variante com quantidade 2 renderiza o badge com "2"; variante com quantidade 0 e variante sem registro não renderizam badge — as duas ausências medidas
- [x] O payload do Turbo Stream do incremento de 0 para 1 contém o badge, e o do decremento de 1 para 0 não contém
- [x] Nenhum outro nível de âmbar indica posse (não existe segundo token de accent)
- [x] Os testes de região viva de `collection_ownership_ui_test.rb` passam sem edição
- [x] Gate full passa

**Tests**: integration
**Gate**: full

**Commit**: `feat(interface): marcar a variante possuída com badge de quantidade`

---

### T10: Regra para toda classe usada nas views

**What**: Travar com um teste que exige regra em `catalog.css` para toda classe usada nas views, e dar regra às classes restantes do inventário.
**Where**: `test/design/class_coverage_test.rb`
**Depends on**: T9
**Reuses**: o inventário medido no topo deste plano
**Requirement**: INT-06, INT-07

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] O teste extrai as classes de `class="…"` e `class: "…"` em `app/views` e `app/helpers` e exige um seletor correspondente em `catalog.css`; a classe interpolada `flash--<%= kind %>` é expandida por uma lista declarada no teste (`notice`, `alert`), conferida contra os `flash[:…]` usados em `app/controllers`
- [x] Antes das regras, o teste falha listando as classes do inventário (prova de que discrimina)
- [x] Seletor sem declaração não conta como regra
- [x] `ownership__button--increment` e `--decrement` se distinguem por rótulo, não por cor; nenhum deles em `danger` (decremento não é destrutivo confirmado)
- [x] `wishlist-item__status--pending` e `--fulfilled` se distinguem pelo texto que já exibem; a regra não faz da cor o único sinal
- [x] Gate full passa — §6.4 fecha aqui

**Tests**: unit
**Gate**: full

**Commit**: `feat(interface): estilizar as classes que as views usam e a folha ignorava`

---

### T11: `code` em `card_number` e `variant_code`

**What**: Renderizar todo `card_number` e `variant_code` visível no estilo `code`, inclusive inline em texto corrido.
**Where**: `app/views/collection_items/_ownership.html.erb`
**Depends on**: T10
**Reuses**: as classes que já envolvem só o identificador (`card-tile__number`, `card-tile__placeholder-number`, `card-detail__number`, `variant__code`, `import-preview__number`, `import-preview__variant`, `import-summary__number-card`, `import-summary__variant`)
**Requirement**: INT-08

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Toda classe que envolve só o identificador consome os tokens de `code` (`--font-mono`, 500, 13px/18px)
- [x] Onde o identificador está inline sem envoltório próprio — `ownership__variant`, o `<span>` de `catalog/show.html.erb:112`, o link de `wishlist_items/index.html.erb:40`, `collection_imports/resumo.html.erb:215` — ele ganha um `<code>` com classe `code`, sem mudar a árvore em volta
- [x] `aria-label` e `<title>` ficam como estão (não são texto renderizado)
- [x] Teste de integração por tela (grade, detalhe, posse, wishlist, pré-visualização e resumo do import) prova que o texto do identificador está dentro de um elemento em estilo `code`
- [x] Gate full passa

**Tests**: integration
**Gate**: full

**Commit**: `feat(interface): exibir códigos de carta e variante em monoespaçado`

---

### T12: Anel de foco único e `border` só decorativa

**What**: Substituir os três anéis de foco em `currentcolor` por uma regra `:focus-visible` única, sólida de 2px em `accent` com 2px de deslocamento, para todo elemento focável.
**Where**: `app/assets/stylesheets/catalog.css`
**Depends on**: T11
**Reuses**: a regra existente em `catalog.css:395`, que é substituída, não duplicada
**Requirement**: INT-09, INT-05

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Uma regra `:focus-visible` cobre `a`, `button`, `input`, `select`, `textarea` e `summary`, com `outline: 2px solid var(--accent)` e `outline-offset: 2px`
- [x] Nenhuma regra declara `outline: none` ou `outline: 0` sem substituto, nem cor de outline com transparência
- [x] O par do anel a 3:1 sobre as três superfícies está na T2 (conferir que existe, não reescrever)
- [x] `var(--border)` não aparece em regra de controle nem de foco — teste textual sobre seletores de `button`, `input`, `select`, `*__button`, `*__input` e `:focus*`
- [x] Gate full passa

**Tests**: unit
**Gate**: full

**Commit**: `feat(interface): unificar o anel de foco em accent`

---

### T13: Sem emoji e chip de cor neutro

**What**: Provar que nenhuma view, helper ou locale contém emoji e que o chip de filtro nunca é preenchido com `accent`.
**Where**: `test/design/content_rules_test.rb`
**Depends on**: T12
**Reuses**: `filter-chip` da T4; `catalog/index.html.erb:17`
**Requirement**: INT-10, INT-11

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Varredura de `app/views`, `app/helpers` e `config/locales` por codepoints de emoji (faixas Unicode declaradas no teste, incluindo o seletor de variação U+FE0F); a varredura é provada contra uma string sintética com emoji
- [x] `filter-chip` e descendentes não usam `var(--accent)` como `background-color`; o chip ativo de cor do jogo usa `border-strong` mais o rótulo escrito que já existe (P8 aberta)
- [x] Teste de integração com filtro de cor ativo prova que o chip exibe o nome da cor por escrito
- [x] Gate full passa — §6.5 fecha aqui

**Tests**: unit
**Gate**: full

**Commit**: `test(interface): travar a ausência de emoji e o chip de cor neutro`

---

### T14: Revisão de acessibilidade e revisão visual do dono

**What**: Rodar a revisão de a11y sobre o diff da feature e submeter as telas ao dono do produto em `docker compose up`, registrando o resultado.
**Where**: `.specs/features/interface/tasks.md`
**Depends on**: T13
**Reuses**: o plano de delegação do `CLAUDE.md` (`ecc:a11y-architect` em controle visual)
**Requirement**: INT-01..INT-12 (Success Criteria da spec)

**Tools**:

- MCP: NONE
- Skill: NONE — subagente `ecc:a11y-architect`, só leitura

**Done when**:

- [ ] `ecc:a11y-architect` revisou `catalog.css` e as views tocadas; achados CRITICAL/HIGH viraram task de correção antes do Verifier
- [ ] O dono do produto abriu grade, detalhe, wishlist, progresso, import e login em `docker compose up`, inclusive a 360px, e aprovou ou listou o que reprova
- [ ] O resultado está registrado nesta task, com o que foi visto
- [ ] Gate build passa

**Tests**: none
**Gate**: build

**Commit**: `docs(interface): registrar a revisão visual e de acessibilidade`

---

## Plano de delegação

14 tasks empacotam em **dois lotes**: B1 = Fases 1 e 2 (T1–T7), B2 = Fases 3,
4 e 5 (T8–T14). Workers só com aceite explícito. Depois da T14 o Verifier roda
automaticamente (autor ≠ verificador), com sensor de mutação em cópia isolada —
**nunca `git stash`**.

| Onde | Revisor |
|---|---|
| T2, T3 — fórmula de contraste e paleta | orquestrador confere a constante contra a W3C |
| T9, T11, T12 — posse, `code`, foco | `ecc:a11y-architect` na T14 |
| T8–T13 — testes de ausência | `ecc:pr-test-analyzer`, antes do Verifier do B2 |

## Task Granularity Check

| Task | Escopo | Status |
|---|---|---|
| T1 | tokens em um seletor + teste | ✅ |
| T2 | um arquivo de teste | ✅ |
| T3 | um arquivo de teste | ✅ |
| T4–T7 | um grupo de blocos por task, no mesmo arquivo | ✅ coeso |
| T8 | duas regras de um bloco | ✅ |
| T9 | um modificador condicional + uma regra | ✅ |
| T10 | um teste de guarda + as regras que ele exige | ⚠️ ~23 regras, um conceito |
| T11 | um estilo aplicado às ocorrências de um identificador | ⚠️ várias views, um conceito |
| T12 | uma regra de foco | ✅ |
| T13 | um arquivo de teste | ✅ |
| T14 | revisão | ✅ |

T10 e T11 tocam vários pontos para fechar **um** critério cada; dividi-las por
arquivo deixaria tasks intermediárias com o teste de guarda vermelho.

## Diagram-Definition Cross-Check

| Task | Depends on | Diagrama | Status |
|---|---|---|---|
| T1 | None | início da Fase 1 | ✅ |
| T2 | T1 | T1 → T2 | ✅ |
| T3 | T2 | T2 → T3 | ✅ |
| T4 | T3 | início da Fase 2 (após a Fase 1) | ✅ |
| T5 | T4 | T4 → T5 | ✅ |
| T6 | T5 | T5 → T6 | ✅ |
| T7 | T6 | T6 → T7 | ✅ |
| T8 | T7 | início da Fase 3 (após a Fase 2) | ✅ |
| T9 | T8 | T8 → T9 | ✅ |
| T10 | T9 | T9 → T10 | ✅ |
| T11 | T10 | início da Fase 4 (após a Fase 3) | ✅ |
| T12 | T11 | T11 → T12 | ✅ |
| T13 | T12 | T12 → T13 | ✅ |
| T14 | T13 | Fase 5 (após a Fase 4) | ✅ |

## Test Co-location Validation

| Task | Camada | Matriz exige | Task diz | Status |
|---|---|---|---|---|
| T1 | tokens da folha | unit | unit | ✅ |
| T2 | contraste | unit | unit | ✅ |
| T3 | regras da folha | unit | unit | ✅ |
| T4 | regras da folha + layout | unit / integration textual | unit (+ testes de 360px existentes no gate full) | ✅ |
| T5 | regras da folha | unit | unit | ✅ |
| T6 | regras da folha | unit | unit | ✅ |
| T7 | regras da folha | unit | unit | ✅ |
| T8 | folha + HTML renderizado | integration | integration | ✅ |
| T9 | view + folha | integration | integration | ✅ |
| T10 | guarda sobre views e folha | unit | unit | ✅ |
| T11 | views + folha | integration | integration | ✅ |
| T12 | regras da folha | unit | unit | ✅ |
| T13 | conteúdo das views | unit + integration | unit (com um teste de integração) | ✅ |
| T14 | aparência renderizada | none | none | ✅ |
