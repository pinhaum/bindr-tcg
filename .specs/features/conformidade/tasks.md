# Conformidade com o canvas — Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Spec**: `.specs/features/conformidade/spec.md` (CNF-01..CNF-40)
**Design**: inline (sem `design.md`: a feature muda apresentação e uma ordenação de leitura; nenhum padrão novo)
**Status**: Draft

Cada task de tela traz a **checklist do artboard** que ela cobre, extraída dos
`.dc.html` de `.specs/features/navegacao/canvas/` com a linha de origem. A
checklist é critério de aceite (AD-016): o item está conforme, ou um CNF o
justifica, ou está no Out of Scope da spec. A T12 confere as capturas contra
estas mesmas listas.

Tokens do artboard, para leitura das checklists: bg `#051b23`, surface
`#102b36`, sunken `#011018`, border `#1c3a47`, border-strong `#717e84`, text
`#e9f0f3`, muted `#9ba7ad`, accent `#ff9e14`, on-accent `#051b23`, danger
`#ff5448`. No código, sempre o token (`var(--accent)` etc.), nunca o hexadecimal
(Req. 12.1, `test/design/literal_values_test.rb`).

---

## Test Coverage Matrix

| Camada | Tipo de teste | Cobertura esperada | Onde | Comando |
|---|---|---|---|---|
| Query object (`SetProgressQuery` com ordem, `CatalogQuery#filter_options`) | unit | 1:1 com CNF-11, 27, 28, 38, 40, mais isolamento entre dois usuários | `test/queries/*_test.rb` | `bin/rails test test/models test/queries` |
| Views, helpers, controllers | integration | Com e sem sessão, caminho feliz e edge cases CNF-36..40, sobre HTML renderizado (`get`, `assert_select`) | `test/integration/*_test.rb` | `bin/rails test test/integration` |
| Regras da folha (colunas, paddings, 44px, divisores, selo) | unit (folha resolvida) | Todo AC de medida, lido com `Stylesheet.resolved` (última declaração vence), nunca `include?` solto na folha | `test/design/*_test.rb` | `bin/rails test test/design` |
| Guardas de design e 360px | integration + unit | Continuam passando; `set_progress_plan_test.rb` e os sete arquivos protegidos da `navegacao` só mudam com motivo registrado na task | `test/design/*`, `test/queries/set_progress_plan_test.rb` | `bin/rails test` |
| Composição renderizada | none (evidência) | Captura × artboard contra as checklists desta lista (AD-015) | `tmp/capturas/`, `tmp/comparacao/` | `node spec/visual/capture.cjs` (no host) |

Sem fixtures YAML: cada teste cria os registros no `setup`. Rota do detalhe:
`card_path(card.card_number)`, nunca `card_path(card)` (responde 404 e deixa o
teste vácuo; validação da `navegacao`, M08). Teste de detalhe exige
`assert_response :success`.

## Gate Check Commands

Todos com `docker compose exec -T app` na frente e `DOCKER_CONFIG` apontando para
um diretório com `config.json` contendo `{}`.

| Gate | Quando | Comando |
|---|---|---|
| quick | Task só com teste de query | `bin/rails test test/models test/queries` |
| full | Task com integração ou folha | `bin/rails test && bin/rubocop` |
| build | Fechamento (T12) | `docker compose build` |

Base antes da T1: **1214 runs**, 0 falhas, RuboCop limpo. Toda task registra a
contagem nova; ela só cai quando a task remove um comportamento que a spec
retira, e o commit diz quais testes saíram e por quê.

---

## Execution Plan

As fases rodam em sequência. Quase toda task toca `app/assets/stylesheets/catalog.css`,
por isso só a Fase 1 roda em paralelo (T1 e T2 não compartilham arquivo).

### Phase 1: Dados

```
T1 ∥ T2
```

### Phase 2: Catálogo

```
T2 → T3 → T4 → T5
```

### Phase 3: Detalhe da carta

```
T5 → T6 → T7 → T8 → T9
```

### Phase 4: Minha pasta

```
T9 → T10 → T11
T1 → T10
```

### Phase 5: Correções da conferência

As capturas de 2026-09-28 (`tmp/capturas/top-*.png`, `tmp/comparacao/`) contra as
checklists T3–T11 mostraram itens fora do artboard sem CNF nem Out of Scope, o que
reprovaria o CNF-35. Cada um volta como correção.

```
T11 → T13 → T14 → T15
```

### Phase 6: Fechamento

```
T15 → T12
```

---

## Task Breakdown

### T1: Ordem da pasta por atividade do usuário

**What**: `SetProgressQuery` aceita a ordem `recent` (padrão) ou `code` e o `ProgressController` a lê de `params[:order]`, com sets sem posse no fim, por código.
**Where**: `app/queries/set_progress_query.rb`, `app/controllers/progress_controller.rb`, `test/queries/set_progress_query_test.rb`, `test/integration/progress_order_test.rb` (novo)
**Depends on**: None
**Reuses**: o cálculo por set que já existe na query; a validação de parâmetro por lista fechada do `CatalogQuery`
**Requirement**: CNF-27, CNF-28, CNF-38

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] `recent`: sets ordenados pelo `MAX(collection_items.updated_at)` do usuário, mais novo primeiro; empate por código; sets sem posse no fim, por código
- [x] `code`: sets com posse por código, depois os sem posse por código
- [x] Ordem ausente, desconhecida (`xyz`), vazia ou em array cai em `recent` e responde 200 (CNF-28)
- [x] Coleção vazia: todos os sets por código (CNF-38)
- [x] Dois usuários: a atividade do segundo não muda a ordem do primeiro; a query parte de `Current.user`, nunca de ID do request (Req. 6.5)
- [x] Item com `quantity: 0` não conta como posse na ordem
- [x] `test/queries/set_progress_plan_test.rb` (protegido, AD-017) passa sem edição; se a forma da consulta obrigar a editá-lo, parar e voltar `blocked`
- [x] Gate full passa

**Tests**: unit, integration
**Gate**: full
**Commit**: `feat(conformidade): ordenar os sets da pasta por atividade ou por código`

---

### T2: Ordem de apresentação dos chips de filtro

**What**: `filter_options` devolve cores na ordem do canvas e raridades por valor, com valor desconhecido depois dos conhecidos.
**Where**: `app/queries/catalog_query.rb`, `test/queries/catalog_filter_options_test.rb`
**Depends on**: None
**Reuses**: `CatalogQuery#filter_options`
**Requirement**: CNF-11, CNF-40

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Cores: Red, Green, Blue, Purple, Black, Yellow (`Desktop-Catalogo.dc.html:32-37`), só as presentes no catálogo
- [x] Raridades: C, UC, R, SR, SEC, L, depois as demais em ordem alfabética; uma raridade fora da lista (ex.: `"X"`) aparece no fim, sem erro (CNF-40)
- [x] O valor devolvido continua o valor cru da coluna: nenhuma tradução ou capitalização aqui (a capitalização do tipo é da view, T4)
- [x] Gate quick passa

**Tests**: unit
**Gate**: quick
**Commit**: `feat(conformidade): ordenar cores e raridades dos filtros como o canvas`

---

### T3: Tile da grade só com o selo

**What**: O tile deixa de renderizar controle de posse e convite, e passa a exibir o selo com o total de cópias da carta e a raridade ou "N impressões" ao lado do código.
**Where**: `app/views/catalog/_card_tile.html.erb`, `app/controllers/catalog_controller.rb`, `app/helpers/collection_helper.rb`, `app/assets/stylesheets/catalog.css`, `test/integration/catalog_tile_test.rb` (novo), `test/integration/collection_ownership_ui_test.rb`, `test/integration/ownership_badge_ui_test.rb`, `test/design/ownership_badge_test.rb`
**Depends on**: T2
**Reuses**: `owned_quantity(variant)` de `CollectionHelper`; o badge `.ownership-badge` existente, se servir
**Requirement**: CNF-01, CNF-02, CNF-03, CNF-04

**Tools**:

- MCP: NONE
- Skill: NONE

**Checklist do artboard** (`Main.dc.html` 390px, `Desktop-Catalogo.dc.html` 1280px):

- [x] Selo absoluto no canto superior direito da arte, `top: 8px; right: 8px`, `min-width: 24px`, altura 24px, padding `0 8px`, raio 999px, fundo accent, texto on-accent, peso 600 (Main:61, D:83)
- [x] Selo só quando há posse: Nami e Yamato do artboard sem selo (Main:61, D:83)
- [x] Nome 15px peso 600, com reticências (Main:65)
- [x] Linha do código: código em mono 13px e raridade 13px, `gap: 8px` (Main:65-66, D:144)

**Done when**:

- [x] Nenhum tile tem `form`, `button` de posse ou link "Entrar para registrar posse", com ou sem sessão (CNF-01)
- [x] Com sessão, carta de três variantes com 2 + 1 + 0 cópias mostra o selo "3" e nome acessível "3 cópias"; com uma cópia, "1 cópia" (CNF-02)
- [x] Anônimo e usuário sem cópia: nenhum selo (CNF-03)
- [x] Carta de uma variante: raridade ao lado do código; de três: "3 impressões" (CNF-04)
- [x] Os testes de posse na grade de `collection_ownership_ui_test.rb` e `ownership_badge_ui_test.rb` passam a exercer o detalhe ou saem; o commit lista cada teste removido e o motivo (Req. 7.5 emendado). Os testes do controller de posse (`collection_items_test.rb`) ficam intactos
- [x] Gate full passa

**Tests**: integration, unit (folha)
**Gate**: full
**Commit**: `feat(conformidade): tirar a posse da grade e mostrar só o selo`

---

### T4: Linha de status, busca e chips do catálogo

**What**: Linha de status como frase única com "Limpar filtros" de 44px e o convite anônimo único; busca com o rótulo do canvas; sem "Sua coleção"; tipo com inicial maiúscula; chip "Todas" sem remoção.
**Where**: `app/views/catalog/index.html.erb`, `app/views/catalog/_owned_total.html.erb` (remover), `app/controllers/collection_items_controller.rb`, `app/assets/stylesheets/catalog.css`, `test/integration/catalog_status_line_test.rb`, `test/integration/collection_total_test.rb`, `test/integration/catalog_filter_controls_test.rb`
**Depends on**: T3
**Reuses**: `clear_filters_url`, `filter_toggle_url`, `nav_link_to`
**Requirement**: CNF-05, CNF-06, CNF-07, CNF-08, CNF-09, CNF-10, CNF-31

**Tools**:

- MCP: NONE
- Skill: NONE

**Checklist do artboard**:

- [x] Rótulo "Buscar por nome ou card_number", 13/18 muted (Main:24, D:68); input com placeholder "OP01-024", 44px, surface, border-strong, raio 4, 15px (Main:25); 480px de largura em 1280px (D:69)
- [x] Status em 390px: "112 cartas" 13/18 muted (Main:48) e "Limpar filtros" botão bordado de 44px, padding `0 16px`, raio 4, 13px (Main:49)
- [x] Status em 1280px: "112 cartas · 2 filtros ativos" com "Limpar filtros" na mesma linha da busca (D:66-75)
- [x] Chip ativo que não é de cor: fundo accent, texto on-accent, borda accent, 44px, peso 600, com "×" (Main:29-30, D:44, D:56); inativo transparente, border-strong, padding `0 16px`, 13px 400
- [x] Título h1 "Catálogo" 28/32 700 (Main:21, D:64)

**Done when**:

- [x] Sem filtro: a linha diz só "N cartas"; com dois filtros: "N cartas · 2 filtros ativos"; com um: "· 1 filtro ativo"; o N é o total do resultado com mais de uma página (CNF-05)
- [x] "Limpar filtros" só com filtro, preserva `sort` e `dir`, e `Stylesheet.resolved` dá `min-height` ≥ 44px e borda (CNF-06); com zero resultados continua aparecendo uma vez só
- [x] Anônimo: "Entrar para registrar posse" aparece exatamente uma vez na página, dentro da linha de status, apontando para `new_session_path`; com sessão, nenhuma vez (CNF-07)
- [x] Em ≥1024px, busca e status na mesma linha e o recuo resolvido de `.catalog__head` igual ao de `.catalog__body` (CNF-08; mata o antigo M42)
- [x] Rótulo e placeholder da busca como o canvas (CNF-09)
- [x] "Sua coleção" não aparece no catálogo; o stream de posse deixa de atualizar `catalog_owned_total`; o total continua na pasta (CNF-10, NAV-17)
- [x] Tipos exibidos com inicial maiúscula ("Leader") e a URL continua `card_types[]=leader` (CNF-11)
- [x] Sem `owned`, o chip "Todas" tem `aria-current` e não tem "×" nem nome "Remover filtro" (CNF-31)
- [x] Gate full passa

**Tests**: integration, unit (folha)
**Gate**: full
**Commit**: `feat(conformidade): linha de status e busca do catálogo como o canvas`

---

### T5: Grade e tile nas medidas do canvas

**What**: Cinco colunas em 1280px, tile com padding de 16px e arte emoldurada, divisor entre navegação e filtros na coluna lateral.
**Where**: `app/assets/stylesheets/catalog.css`, `app/views/layouts/application.html.erb`, `test/design/catalog_grid_canvas_test.rb` (novo), `test/design/catalog_subgrid_layout_test.rb`
**Depends on**: T4
**Reuses**: `Stylesheet.resolved` de `test/design/support/stylesheet.rb`
**Requirement**: CNF-12, CNF-13

**Tools**:

- MCP: NONE
- Skill: NONE

**Checklist do artboard**:

- [x] Grade 390px: `repeat(2, minmax(0, 1fr))`, `gap: 8px` (Main:55)
- [x] Grade 1280px: `repeat(5, minmax(0, 1fr))`, `gap: 16px` (D:77)
- [x] Tile: surface, borda 1px border, raio 8, padding 16 (Main:57, D:79)
- [x] Arte: sunken, raio 8, padding 8, com folga lateral (Main:58, D:80)
- [x] Coluna lateral: 280px, surface, `border-right` border, padding 24, gap 24 (D:19); divisor 1px border entre navegação e filtros (D:27)
- [x] Conteúdo: padding 24, coluna, gap 16 (D:62)

**Done when**:

- [x] Dentro da media query de 1280px (ou a de 64rem, se o reflow for mantido por ela), `.catalog__grid` resolve `repeat(5, minmax(0, 1fr))` e gap 16px; fora, duas colunas e gap 8px (CNF-12)
- [x] O guarda de 360px sem scroll horizontal continua passando
- [x] `.card-tile` resolve padding 16px; `.card-tile__art` resolve fundo `var(--surface-sunken)` e padding 8px; o divisor da coluna lateral resolve `1px solid var(--border)` (CNF-13)
- [x] Gate full passa

**Tests**: unit (folha), integration
**Gate**: full
**Commit**: `style(conformidade): grade de cinco colunas e tile nas medidas do canvas`

---

### T6: Imagem principal do detalhe

**What**: Miniatura ao lado do título com a imagem maior num `<details>` abaixo de 1024px; coluna de 320px acima; selo da primeira variante e legenda do ilustrador.
**Where**: `app/views/catalog/show.html.erb`, `app/assets/stylesheets/catalog.css`, `test/integration/card_detail_hero_image_test.rb`, `test/design/card_detail_media_test.rb`, `test/integration/card_detail_image_test.rb` (novo)
**Depends on**: T5
**Reuses**: o placeholder do tile (Req. 2.3), `card_image_path`, `owned_quantity`
**Requirement**: CNF-14, CNF-15, CNF-16, CNF-36, CNF-37

**Tools**:

- MCP: NONE
- Skill: NONE

**Checklist do artboard** (`Mobile-Carta.dc.html`, `Desktop-Carta.dc.html`):

- [x] 390px: miniatura 155×217, sunken, raio 8, padding 8, ao lado do título (Mobile:23-40)
- [x] Selo de quantidade sobre a imagem, `top: 8px; right: 8px` (Mobile:27)
- [x] 1280px: imagem 320×448 em coluna própria; selo `top: 16px; right: 16px` (D:32-37, D:36)
- [x] Legenda "Ilustração: [nome]" 13/18 muted (D:38)

**Done when**:

- [x] Abaixo de 1024px: a miniatura fica ao lado do `h1` e a imagem maior dentro de `<details>` com `<summary>` de texto; nenhum `<script>` novo (CNF-14)
- [x] Em ≥1024px: a imagem maior fica visível numa coluna de 320px resolvida na folha (o `<details>` aberto por CSS ou uma segunda instância fora dele; o teste prova a que for escolhida) (CNF-15)
- [x] Com sessão e 2 cópias da primeira variante: selo "2" sobre a imagem; sem posse ou anônimo: sem selo (CNF-16)
- [x] Variante com `illustrator: "Eiichiro Oda"`: "Ilustração: Eiichiro Oda"; sem ilustrador: sem legenda (CNF-16, CNF-37)
- [x] Sem `image_url`: placeholder na miniatura, no `<details>` e na coluna, nas mesmas medidas (CNF-36)
- [x] Gate full passa

**Tests**: integration, unit (folha)
**Gate**: full
**Commit**: `feat(conformidade): miniatura no celular e imagem em coluna no detalhe`

---

### T7: Cabeçalho e efeito do detalhe

**What**: Chips de tipo, raridade, cor (e counter em ≥1024px), linha "set · código", demais campos em forma compacta e trigger dentro da seção "Efeito".
**Where**: `app/views/catalog/show.html.erb`, `app/assets/stylesheets/catalog.css`, `test/integration/card_detail_test.rb`, `test/integration/card_detail_header_test.rb` (novo)
**Depends on**: T6
**Reuses**: os campos e a regra de omissão do Req. 5.5 que o `show` já implementa
**Requirement**: CNF-17, CNF-18, CNF-39

**Tools**:

- MCP: NONE
- Skill: NONE

**Checklist do artboard**:

- [x] h1 28/32 700 (Mobile:31, D:45); código em mono 13 500 muted (Mobile:32)
- [x] Chips Tipo / Raridade / Cor (Mobile:33-37), mais Counter no desktop (D:50-55): padding `4px 8px`, borda 1px border-strong, raio 4, 13px, gap 8, com quebra
- [x] Linha "Nome do set · código" 13 muted (Mobile:38); no desktop em linha com o código (D:47-48)
- [x] h2 "Efeito" 20/26 600 (Mobile:43); texto 15/22 (Mobile:44); trigger inline com rótulo 600 (Mobile:45); `max-width: 62ch` no desktop (D:60-61)

**Done when**:

- [x] Chips com o tipo, a raridade da primeira variante listada e uma entrada por cor; carta Red/Green tem dois chips de cor (CNF-17, CNF-39)
- [x] Counter como chip só quando a carta tem counter, e visível só em ≥1024px (NULL ≠ 0: counter NULL não gera chip)
- [x] Linha "{nome do set} · {código}" da primeira variante abaixo do título
- [x] Custo, power, life, attribute, traits e block continuam no HTML quando se aplicam e somem quando não (Req. 5.5), em forma compacta
- [x] Trigger dentro da seção "Efeito", depois do efeito, com rótulo "Trigger" peso 600 e quebras de linha preservadas; não existe mais seção própria de trigger (CNF-18)
- [x] Gate full passa

**Tests**: integration, unit (folha)
**Gate**: full
**Commit**: `feat(conformidade): cabeçalho em chips e trigger dentro do efeito`

---

### T8: Variantes na pasta com stepper

**What**: Lista "Variantes na pasta" com linhas no desenho do canvas e o controle `−` `[n]` `+` no lugar de "+1/−1".
**Where**: `app/views/catalog/show.html.erb`, `app/views/collection_items/_ownership.html.erb`, `app/assets/stylesheets/catalog.css`, `test/integration/collection_ownership_ui_test.rb`, `test/design/card_detail_ownership_buttons_test.rb`, `test/design/card_detail_variants_grid_test.rb`, `test/integration/card_detail_variants_test.rb` (novo)
**Depends on**: T7
**Reuses**: `button_to` com Turbo Stream de `CollectionItemsController`, `aria-disabled` em zero
**Requirement**: CNF-19, CNF-20, CNF-21, CNF-22

**Tools**:

- MCP: NONE
- Skill: NONE

**Checklist do artboard**:

- [x] Divisores 1px border depois de Efeito e depois de Variantes (Mobile:48, :84)
- [x] h2 "Variantes na pasta" 20/26 600 (Mobile:51, D:67)
- [x] Linha: surface, borda 1px border, raio 8, padding 16, gap 8 (Mobile:53); no desktop em linha, `align-items: center`, gap 16 (D:69)
- [x] Código mono 13 500 (Mobile:56); "SR · arte base" / "SP CARD · alternativa" 13 muted (Mobile:57, :72); "não tenho" 13 muted com zero (Mobile:74)
- [x] Stepper `− [n] +` (Mobile:62-64): botões 44×44, transparentes, border-strong, raio 4, 20px; `[n]` 44px, sunken, border-strong, 15px 600, só exibe; com zero, "−" apagado (Mobile:77)

**Done when**:

- [x] Título "Variantes na pasta" e divisor `1px solid var(--border)` entre efeito e variantes (CNF-19)
- [x] Cada linha: código, "{raridade} · {tipo de arte}" com `base` → "arte base", `parallel` → "parallel", `other` → "alternativa", o set e a miniatura menor que a imagem principal; rótulos "Código", "Raridade" e "Set" no HTML e fora da vista (CNF-20; mata o antigo M45)
- [x] Com sessão, a ordem no DOM é `−`, `[n]`, `+`; `[n]` não é `input`; botões resolvem 44×44px; nomes acessíveis "Adicionar uma cópia de …" / "Remover uma cópia de …" mantidos (CNF-21)
- [x] Com zero: "não tenho" e `−` com `aria-disabled="true"`, sem `disabled` (CNF-21)
- [x] POST de incremento com `Accept: text/vnd.turbo-stream.html` responde stream que atualiza a linha da variante (CNF-22)
- [x] Marca de wishlist por variante continua na linha (Req. 8.1)
- [x] Gate full passa

**Tests**: integration, unit (folha)
**Gate**: full
**Commit**: `feat(conformidade): variantes na pasta com o stepper do canvas`

---

### T9: Voltar ao catálogo e marca no desktop

**What**: "Voltar ao catálogo" como botão bordado de 44px, na coluna lateral em ≥1024px, e a marca "Bindr" com a tipografia `display`.
**Where**: `app/views/catalog/show.html.erb`, `app/views/layouts/application.html.erb`, `app/assets/stylesheets/catalog.css`, `test/integration/card_detail_layout_test.rb`, `test/design/navigation_canvas_test.rb`
**Depends on**: T8
**Reuses**: `content_for` para a coluna lateral, se o layout já tiver um slot; senão, criar um só
**Requirement**: CNF-23, CNF-24

**Tools**:

- MCP: NONE
- Skill: NONE

**Checklist do artboard**:

- [x] 390px: botão bordado 44px, padding `0 16px`, border-strong, raio 4, sem "←", `align-self: flex-start` (Mobile:21)
- [x] 1280px: divisor 1px e o botão na coluna lateral abaixo da navegação, 13px (D:26-27)
- [x] Marca "Bindr" 28/32 700 (D:20); navegação 44px, padding `0 16px`, raio 4, 15px, ativo sunken 600 (D:22-24)

**Done when**:

- [x] O link "Voltar ao catálogo" não contém "←" e resolve `min-height` ≥ 44px com borda (CNF-23)
- [x] Em ≥1024px ele fica dentro da coluna lateral, depois da navegação e de um divisor de 1px (CNF-23)
- [x] A marca resolve 28px / 32px / 700 em ≥1024px (CNF-24); em 390px continua visível (decisão de 2026-09-26)
- [x] Gate full passa

**Tests**: integration, unit (folha)
**Gate**: full
**Commit**: `feat(conformidade): voltar ao catálogo e marca como o canvas`

---

### T10: Linha de set e escolha de ordem na pasta

**What**: Linha de set com nome como link, percentual junto da contagem, parallels como legenda e os chips "Recentes / Por código".
**Where**: `app/views/progress/index.html.erb`, `app/assets/stylesheets/catalog.css`, `test/integration/progress_ui_test.rb`, `test/integration/minha_pasta_test.rb`, `test/design/progress_line_test.rb`, `test/integration/progress_order_test.rb`
**Depends on**: T1, T9
**Reuses**: `nav_link_to` para o `aria-current` dos chips; a ordem da T1
**Requirement**: CNF-25, CNF-26, CNF-29

**Tools**:

- MCP: NONE
- Skill: NONE

**Checklist do artboard** (`Mobile-Pasta.dc.html`, `Desktop-Pasta.dc.html`):

- [x] h1 "Minha pasta" 28/32 700 (Mobile:21); h2 "Progresso por set" 20/26 600 (Mobile:41, D:56); lista em coluna, gap 8 (Mobile:43)
- [x] Linha: código mono 13 500 text e nome 13 muted com reticências à esquerda (Mobile:46-47); "142 / 254" 13 muted à direita (Mobile:49)
- [x] Barra abaixo: altura 8, trilho sunken, raio 4, preenchimento border-strong (Mobile:51)

**Done when**:

- [x] O nome do set é o link para `catalog_path(sets: [code])`; não existe mais "Ver no catálogo" (CNF-25, CNF-26)
- [x] O percentual aparece na mesma linha de "possuídas / total"; parallels como legenda; set com `base_set_size: nil` continua sem barra e com "Percentual indisponível" (NAV-38)
- [x] A contagem total de sets ("76 sets") não aparece (CNF-26)
- [x] Chips "Recentes" e "Por código" junto do h2, levando a `?order=recent` e `?order=code`, com `aria-current` no da ordem aplicada, inclusive "Recentes" quando o parâmetro é inválido (CNF-29, CNF-28)
- [x] Gate full passa

**Tests**: integration, unit (folha)
**Gate**: full
**Commit**: `feat(conformidade): linha de set e escolha de ordem na pasta`

---

### T11: Layout da pasta e ação de adicionar

**What**: Cartões de indicador em quatro colunas, segunda coluna de 420px com as ações secundárias em ≥1024px, "Adicionar cartas à pasta" fixo no celular e na coluna lateral no desktop, e o campo de arquivo do import estilizado.
**Where**: `app/views/progress/index.html.erb`, `app/views/layouts/application.html.erb`, `app/views/collection_imports/new.html.erb`, `app/assets/stylesheets/catalog.css`, `test/design/progress_canvas_test.rb`, `test/integration/minha_pasta_test.rb`, `test/design/focus_obscured_test.rb`
**Depends on**: T10
**Reuses**: o slot da coluna lateral da T9; a reserva de fundo da barra inferior (NAV-06)
**Requirement**: CNF-30, CNF-32, CNF-33

**Tools**:

- MCP: NONE
- Skill: NONE

**Checklist do artboard**:

- [x] Cartões: surface, borda, raio 8, padding 16, gap 4 (Mobile:24); número 28/32 700, legenda 13/18 muted; "cartas na pasta" (Mobile:26), "cartas diferentes" (Mobile:30)
- [x] Grade dos cartões: 390px `repeat(2, …)` gap 8 (Mobile:23); 1280px `repeat(4, …)` gap 16 (D:34)
- [x] 1280px: duas colunas com gap 24 e `align-items: flex-start` (D:53); esquerda cresce (D:55), direita 420px (D:125)
- [x] "Adicionar cartas à pasta" no celular: fixo acima da barra inferior, 44px, accent, on-accent, raio 8, 15/22 600, padding `16px 24px`, `border-top` (Mobile:115)
- [x] 1280px: divisor 1px (D:26) e "Adicionar cartas" na coluna lateral (D:27)

**Done when**:

- [x] Em ≥1024px os cartões resolvem `repeat(4, minmax(0, 1fr))` com gap 16px e não esticam além disso (CNF-30)
- [x] Em ≥1024px, sets à esquerda e as ações de wishlist, import e export numa coluna de 420px (CNF-30); o grupo continua separado de "Adicionar cartas" (NAV-51)
- [x] Abaixo de 1024px, "Adicionar cartas à pasta" é `position: fixed` acima da barra inferior, fundo `var(--accent)`, ≥44px, e a reserva no fim do conteúdo cresce o bastante para o último set não ficar coberto (CNF-32, Req. 13.3)
- [x] Em ≥1024px, "Adicionar cartas" fica na coluna lateral abaixo de um divisor de 1px e não aparece fixa (CNF-32)
- [x] O `input type="file"` do import resolve surface, borda do design system e ≥44px (CNF-33)
- [x] Gate full passa

**Tests**: unit (folha), integration
**Gate**: full
**Commit**: `feat(conformidade): layout da pasta e ação de adicionar como o canvas`

---

### T13: Catálogo — linha do código, rótulo da busca e topo em 1280px

**What**: Código e raridade (ou "N impressões") numa linha só do tile, rótulo da busca no estilo de legenda e o título sem vão acima em ≥1024px.
**Where**: `app/assets/stylesheets/catalog.css`, `app/views/catalog/_card_tile.html.erb`, `app/views/catalog/index.html.erb`, `test/design/catalog_grid_canvas_test.rb`, `test/integration/catalog_tile_test.rb`
**Depends on**: T11
**Reuses**: `Stylesheet.resolved`
**Requirement**: CNF-04, CNF-09, CNF-13

**Tools**:

- MCP: NONE
- Skill: NONE

**Checklist do artboard**:

- [x] Linha do código numa linha só: código mono 13px e raridade 13px com `gap: 8px`; o código nunca quebra no hífen; "N impressões" não quebra (Main:65-66, D:144)
- [x] Rótulo "Buscar por nome ou card_number" 13/18, `--ink-muted`, peso regular (Main:24, D:68)
- [x] Em 1280px o h1 "Catálogo" fica no topo do conteúdo, só com o padding de 24px (D:62-64)

**Done when**:

- [x] `.card-tile__number` (ou o elemento do código) resolve `white-space: nowrap`; a linha resolve `display: flex`, `gap: 8px`, sem quebra entre os dois, e com o texto que excede em reticências
- [x] O rótulo da busca resolve tamanho e altura da legenda (`--caption-size`/`--caption-line-height`), cor `var(--ink-muted)` e peso regular
- [x] Em ≥1024px nenhuma regra do cabeçalho do catálogo cria margem ou linha de grade vazia acima do h1 (o teste prova a regra que causava o vão, achada na folha resolvida)
- [x] Gate full passa

**Tests**: unit (folha), integration
**Gate**: full
**Commit**: `fix(conformidade): linha do código, rótulo da busca e topo do catálogo como o canvas`

---

### T14: Detalhe — imagem no topo e linha da variante do canvas

**What**: Imagem principal alinhada ao topo em ≥1024px; linha da variante com "raridade · tipo" em legenda, "não tenho", `[n]` de 44px e, em ≥1024px, numa linha só.
**Where**: `app/assets/stylesheets/catalog.css`, `app/views/catalog/show.html.erb`, `app/views/collection_items/_ownership.html.erb`, `test/integration/card_detail_variants_test.rb`, `test/design/card_detail_ownership_buttons_test.rb`, `test/design/card_detail_media_test.rb`
**Depends on**: T13
**Reuses**: `Stylesheet.resolved`
**Requirement**: CNF-15, CNF-20, CNF-21

**Tools**:

- MCP: NONE
- Skill: NONE

**Checklist do artboard**:

- [ ] 1280px: imagem 320×448 alinhada ao topo da coluna, na altura do título (D:32-37)
- [ ] "SR · arte base" / "SP CARD · alternativa" 13px, `--ink-muted`, peso regular (Mobile:57, :72)
- [ ] "não tenho" 13px muted com zero cópias (Mobile:74)
- [ ] `[n]` com 44px de largura e altura, sunken, border-strong, 15px 600 (Mobile:63)
- [ ] 1280px: linha da variante em linha, `align-items: center`, `gap: 16px` — miniatura, identificação, quantidade e stepper lado a lado (D:69)

**Done when**:

- [ ] Em ≥1024px a coluna da imagem resolve `align-self: start` (ou o contêiner `align-items: start`), sem centralização vertical
- [ ] A linha "raridade · tipo de arte" resolve a tipografia de legenda, `var(--ink-muted)` e peso regular
- [ ] Com zero cópias o texto visível é exatamente "não tenho" (não "não tenho cópias"); com N cópias continua o selo com o número
- [ ] `[n]` resolve `min-width: 44px` e `min-height: 44px`
- [ ] Em ≥1024px a linha da variante resolve `display: flex` (ou grid numa linha), `align-items: center` e gap 16px; em <1024px continua empilhada
- [ ] Marca de wishlist por variante continua na linha (Req. 8.1)
- [ ] Gate full passa

**Tests**: integration, unit (folha)
**Gate**: full
**Commit**: `fix(conformidade): imagem no topo e linha da variante como o canvas`

---

### T15: Pasta — linha de set, chips de ordem e "Adicionar cartas" em accent

**What**: Linha de set no desenho do canvas (nome em legenda numa linha, "possuídas / total · N%" à direita, uma legenda só para base e parallels), chips de ordem no estilo dos chips do catálogo e "Adicionar cartas" em accent também na coluna lateral.
**Where**: `app/assets/stylesheets/catalog.css`, `app/views/progress/index.html.erb`, `test/integration/progress_ui_test.rb`, `test/integration/minha_pasta_test.rb`, `test/design/progress_line_test.rb`, `test/design/progress_add_cards_test.rb`
**Depends on**: T14
**Reuses**: `.catalog__chip` e `nav_link_to`; `Stylesheet.resolved`
**Requirement**: CNF-25, CNF-26, CNF-29, CNF-32

**Tools**:

- MCP: NONE
- Skill: NONE

**Checklist do artboard**:

- [ ] Código mono 13 500 `--ink` e nome 13 `--ink-muted` numa linha só, com reticências, sem sublinhado nem caixa alta própria (Mobile:46-47)
- [ ] À direita, "142 / 254" 13 muted (Mobile:49), com o percentual junto (CNF-26)
- [ ] Barra abaixo (Mobile:51); parallels e o total base numa legenda única de 13px muted
- [ ] Chips "Recentes" e "Por código" com o desenho de `.catalog__chip` (44px, borda border-strong; o atual com fundo accent) — o canvas não desenha, vale o design system (CNF-29)
- [ ] 1280px: "Adicionar cartas" na coluna lateral com fundo accent e texto on-accent, raio 8, 44px (D:27) — é a única ação em accent da tela

**Done when**:

- [ ] Em 390px o nome do set não quebra: resolve `white-space: nowrap`, `overflow: hidden`, `text-overflow: ellipsis`, cor `var(--ink-muted)`, tipografia de legenda e `text-decoration: none`; continua sendo o link para o catálogo filtrado (CNF-25)
- [ ] A contagem visível da linha é "N / M · P%" (M = variantes do set, P = percentual do Req. 9.5) numa linha à direita; o set com `base_set_size: nil` mostra "N / M" e "Percentual indisponível" (NAV-38)
- [ ] Base e parallels numa só legenda de 13px muted (ex.: "1 de 121 do set base · 0 de 33 parallels"), sem somar parallels ao percentual (Req. 9.6)
- [ ] Os chips de ordem resolvem `min-height: 44px` e a borda do chip; o da ordem aplicada tem `aria-current` e o fundo do chip ativo
- [ ] Em ≥1024px `.progress__add-cards` resolve fundo `var(--accent)`, cor `var(--on-accent)`, `min-height` ≥ 44px e continua sem `position: fixed`; `.site-header__aside` continua sem accent (o teste da tela de autenticação passa sem edição)
- [ ] Gate full passa

**Tests**: integration, unit (folha)
**Gate**: full
**Commit**: `fix(conformidade): linha de set, chips de ordem e ação em accent na pasta`

---

### T12: Captura conferida contra o artboard e fechamento

**What**: Capturas das três telas em 390px e 1280px, com e sem sessão, comparadas com o artboard item a item das checklists T3–T11; rastreabilidade, `.context/tasks.md` §6.7, gate build e aprovação do dono.
**Where**: `.specs/features/conformidade/canvas-conformance.md` (novo), `.specs/features/conformidade/spec.md`, `.specs/features/conformidade/tasks.md`, `.context/tasks.md`, `.specs/STATE.md`
**Depends on**: T15
**Reuses**: `spec/visual/capture.cjs`; o formato do `canvas-conformance.md` da `navegacao`
**Requirement**: CNF-34, CNF-35

**Tools**:

- MCP: `playwright` (captura no host)
- Skill: NONE

**Done when**:

- [ ] Capturas de catálogo, detalhe e pasta, anônimo e com sessão, em 390px e 1280px, lado a lado com o artboard em `tmp/comparacao/` (CNF-34)
- [ ] `canvas-conformance.md` com uma tabela por tela: cada item das checklists T3–T11 com resultado (conforme / CNF que justifica / Out of Scope) e nenhum item sem os três (CNF-35)
- [ ] Traceability da spec com CNF-01..40 apontando para as tasks
- [ ] §6.7 do `.context/tasks.md` marcada
- [ ] Gate build passa
- [ ] O dono comparou as capturas com os artboards e aprovou
- [ ] Bloco novo no *Handoff* do `STATE.md`

**Tests**: none
**Gate**: build
**Commit**: `docs(conformidade): registrar a conferência com o canvas e fechar a feature`

---

## Plano de delegação

| Task | Worker | Revisão |
|---|---|---|
| T1 | Sonnet (consulta e autorização) | `ecc:database-reviewer` se o plano da consulta passar a fazer full scan |
| T2, T5, T9 | Haiku (mecânicas) | o orquestrador lê os testes contra a checklist |
| T3, T4, T6, T7, T8, T10, T11 | Sonnet (mudam comportamento ou reescrevem testes de outra feature) | `ecc:a11y-architect` sobre T3, T4, T8 e T11 antes da T12; `ecc:pr-test-analyzer` sobre os testes reescritos antes do Verifier |
| T12 | Orquestrador (captura e triagem); Haiku só para gerar as capturas | Dono |

Regras que todo prompt de worker repete: não usar `git add -A` nem `git add .`
(o index é compartilhado); não marcar checkbox em `tasks.md` (o orquestrador marca
no commit); não editar arquivo fora do `Where`; teste afirma o valor da spec, não
o da implementação; parar com `blocked` diante de decisão de design.

## Task Granularity Check

| Task | Escopo | Status |
|---|---|---|
| T1 | um parâmetro de ordem numa query e no controller | ✅ |
| T2 | a ordem de duas listas num método | ✅ |
| T3 | o partial do tile | ✅ |
| T4 | o cabeçalho do catálogo (status, busca, chips) | ✅ |
| T5 | regras de grade e tile na folha | ✅ |
| T6 | o bloco da imagem do detalhe | ✅ |
| T7 | o cabeçalho e o efeito do detalhe | ✅ |
| T8 | a lista de variantes e o partial de posse | ✅ |
| T9 | um link e a marca | ✅ |
| T10 | a linha de set e os chips de ordem | ✅ |
| T11 | o layout da pasta e uma ação | ✅ |
| T12 | conferência e documentação | ✅ |
| T13 | uma linha do tile, um rótulo, o topo do catálogo | ✅ |
| T14 | imagem e linha da variante do detalhe | ✅ |
| T15 | linha de set, chips de ordem, uma ação | ✅ |

## Diagram-Definition Cross-Check

| Task | Depends on (definição) | Diagrama | Status |
|---|---|---|---|
| T1 | None | Phase 1: `T1 ∥ T2` | ✅ |
| T2 | None | Phase 1: `T1 ∥ T2` | ✅ |
| T3 | T2 | Phase 2: `T2 → T3` | ✅ |
| T4 | T3 | Phase 2: `T3 → T4` | ✅ |
| T5 | T4 | Phase 2: `T4 → T5` | ✅ |
| T6 | T5 | Phase 3: `T5 → T6` | ✅ |
| T7 | T6 | Phase 3: `T6 → T7` | ✅ |
| T8 | T7 | Phase 3: `T7 → T8` | ✅ |
| T9 | T8 | Phase 3: `T8 → T9` | ✅ |
| T10 | T1, T9 | Phase 4: `T9 → T10`, `T1 → T10` | ✅ |
| T11 | T10 | Phase 4: `T10 → T11` | ✅ |
| T12 | T15 | Phase 6: `T15 → T12` | ✅ |
| T13 | T11 | Phase 5: `T11 → T13` | ✅ |
| T14 | T13 | Phase 5: `T13 → T14` | ✅ |
| T15 | T14 | Phase 5: `T14 → T15` | ✅ |

## Test Co-location Validation

| Task | Camada tocada | Tipo exigido pela matriz | Tests da task | Status |
|---|---|---|---|---|
| T1 | query, controller | unit, integration | unit, integration | ✅ |
| T2 | query | unit | unit | ✅ |
| T3 | view, controller, helper, folha | integration, unit (folha) | integration, unit (folha) | ✅ |
| T4 | view, controller, folha | integration, unit (folha) | integration, unit (folha) | ✅ |
| T5 | folha, layout | unit (folha), integration | unit (folha), integration | ✅ |
| T6 | view, folha | integration, unit (folha) | integration, unit (folha) | ✅ |
| T7 | view, folha | integration, unit (folha) | integration, unit (folha) | ✅ |
| T8 | view, partial, folha | integration, unit (folha) | integration, unit (folha) | ✅ |
| T9 | view, layout, folha | integration, unit (folha) | integration, unit (folha) | ✅ |
| T10 | view, folha | integration, unit (folha) | integration, unit (folha) | ✅ |
| T11 | views, layout, folha | unit (folha), integration | unit (folha), integration | ✅ |
| T12 | documentação | none | none | ✅ |
| T13 | folha, views | unit (folha), integration | unit (folha), integration | ✅ |
| T14 | folha, views | integration, unit (folha) | integration, unit (folha) | ✅ |
| T15 | folha, view | integration, unit (folha) | integration, unit (folha) | ✅ |
