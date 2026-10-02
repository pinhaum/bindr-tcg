# Conformidade com o canvas — Specification

## Problem Statement

O dono reprovou duas vezes a revisão visual das telas: a `navegacao` cumpriu os
seus 51 critérios e a interface continuou "sem muito a ver com o artifact". A
spec copiava traços isolados do canvas (44px, tokens, `aria-current`) e nunca
descrevia a composição de cada tela; dois critérios (NAV-25, NAV-48) empurravam
contra o canvas. Esta feature faz de cada artboard um critério de aceite
(AD-016) e traduz em requisito verificável tudo o que o canvas desenha para
catálogo, detalhe e pasta, em 390px e 1280px.

Fonte de verdade: `.context/requirements.md` Req. 7.5, 9.7 e 13.19–13.39
(emendados em 2026-09-27). Artboards: `.specs/features/navegacao/canvas/`
(`Main`, `Desktop-Catalogo`, `Mobile-Carta`, `Desktop-Carta`, `Mobile-Pasta`,
`Desktop-Pasta`). Decisões do dono: D1–D12 (`tmp/handoff-conformidade.md`,
resumidas em AD-016).

## Goals

- [ ] Catálogo, detalhe e pasta renderizados em 390px e 1280px batem com o artboard item a item da checklist de cada task, sem divergência que não esteja coberta por um CNF ou pelo Out of Scope.
- [ ] O registro de posse fica só no detalhe (Req. 7.5) e a grade só exibe o selo.
- [ ] A pasta ordena os sets por "Recentes" ou "Por código" (Req. 9.7), a partir do usuário da sessão.
- [ ] Nenhum critério da `navegacao` mantido por referência regride: a suíte inteira continua verde.

## Relação com a spec da `navegacao`

Os NAVs **mantidos** continuam valendo como estão e não são reescritos aqui:
NAV-01..NAV-24, NAV-26..NAV-35, NAV-37..NAV-46, NAV-50 e NAV-51. Os testes que
os provam continuam na suíte; uma task desta feature que precise mudar um deles
registra o motivo na própria task.

Os NAVs abaixo são **substituídos** por critérios desta spec:

| NAV | Substituído por | Motivo |
|---|---|---|
| NAV-25 (manter todos os campos e controles do detalhe como estão) | CNF-14..CNF-24 | Congelava a forma `dl` que o canvas troca por chips (D2) |
| NAV-36 (linha de status em dois parágrafos, "Limpar filtros" ≥24px) | CNF-05..CNF-07 | O canvas desenha frase única e botão de 44px |
| NAV-47 (linha de status alinhada à grade, sem medida) | CNF-08 | A medida verificável vem para cá (validação da `navegacao`, M42) |
| NAV-48 (imagem maior no topo do detalhe em toda largura) | CNF-14, CNF-15 | O canvas usa miniatura ao lado do título no celular (D8) |
| NAV-49 (linha da variante; rótulos fora da vista) | CNF-19..CNF-22 | A linha da variante muda de forma (D9, D10); a prova dos rótulos vem para cá (M45) |

As linhas do Out of Scope da `navegacao` "Raridade no tile da grade", "Número
fixo de colunas da grade" e "Tirar 'Entrar para registrar posse' de cada tile"
ficam **revogadas** (D5, D6, D7).

## Out of Scope

| Feature | Reason |
|---|---|
| Entrada e telas de "Baralhos" | Fase 2 |
| Cotações, valor estimado, "% do catálogo", "Faltando para os baralhos" | Fase 3 sem fonte de preço; "Faltando" depende também da Fase 2 |
| "Zerar quantidade desta carta" | Comportamento novo de coleção, não conformidade visual |
| Nome curto do set ("Memorial Collection") | Exige mudar o estágio Normalize (D12); pendência em `STATE.md` |
| Esconder a marca "Bindr" em viewport estreita | Decisão do dono de 2026-09-26 |
| Rolagem horizontal das fileiras de chips | AD-013; o celular recolhe os filtros (NAV-43) |
| Conteúdo da segunda coluna da pasta em 1280px ("Faltando para os baralhos") | Conteúdo recusado; a coluna de sets fica com a largura do artboard e a segunda coluna recebe as ações secundárias (CNF-30) |
| Hexadecimais das seis cores do jogo | Pendência P8; o swatch continua neutro (Req. 12.11) |
| Captura em navegador como gate | Sem navegador no container; a captura é evidência de revisão (AD-015) |

**Canvas incompleto — o app está certo e fica como está:** grupo "Tipo" nos
filtros; seletor de set em `select`; posse com "Todas/Tenho/Não tenho"
(NAV-12); lista "Filtros ativos" fora do `<details>` (NAV-44); "×" em todo chip
ativo, inclusive o de cor (NAV-34); botão "Buscar" (NAV-46); paginação;
"Entrar/Criar conta" e "Sair" na navegação; links de wishlist, import e export
na pasta (NAV-19); marca de wishlist por variante no detalhe (Req. 8.1); campos
completos do detalhe (Req. 5.1, na forma do CNF-17); arte real no tile;
miniatura própria em cada variante (Req. 5.2, D9).

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
|---|---|---|---|
| Ordem das raridades nos chips | C, UC, R, SR, SEC, L, depois os demais valores em ordem alfabética | O artboard lista um exemplo sem ordem de valor (SR, C, UC, R, SEC, L); o handoff pede "por valor". `rarity` é texto livre (valor novo não pode quebrar) | y |
| Rótulo do tipo de arte na linha da variante | `base` → "arte base"; `parallel` → "parallel"; `other` → "alternativa" | A fonte só distingue base, parallel e outro (`normalize.rb:139`); o canvas usa "arte base" e "alternativa" | y |
| Nome acessível do stepper | Mantém "Adicionar uma cópia de {nome} {código}" / "Remover uma cópia de …" | O canvas diz "Aumentar/Diminuir quantidade de {código}"; nome acessível não é visual, e o atual já distingue a carta (revisão de a11y da `colecao`) | y |
| "−" com quantidade zero | Continua `aria-disabled`, focável, com o estilo desabilitado do canvas | O canvas mostra o botão apagado; `disabled` real perde o foco após o Turbo Stream (achado HIGH da `colecao`) | y |
| Chip "Todas" da posse | Marcado como atual quando não há `owned`, sem "×" e sem o nome "Remover filtro" | Lacuna da validação da `navegacao`: o nome prometia uma remoção que não acontece | y |
| "Todas" conta como filtro ativo | Não conta | "Todas" é a ausência do filtro; já é o comportamento de hoje | y |
| Raridade e set no cabeçalho do detalhe | Os da primeira variante listada, a mesma da imagem principal | Card ≠ CardVariant: a carta não tem raridade própria (handoff §5) | y |
| Selo de quantidade no detalhe | Quantidade da primeira variante listada, sobre a imagem principal | É a variante que a imagem mostra | y |
| "Recentes" em sets com mesma data | Desempate por código do set, crescente | Ordem estável; sem desempate a lista pode trocar de posição entre requisições | y |
| Conformidade verificada sem navegador | Teste de integração sobre o HTML e leitura resolvida da folha (`Stylesheet.resolved`), mais captura × artboard na task final | Não há navegador no container; `SPEC_DEVIATION` como na `navegacao` | y |

**Open questions:** none — todos os padrões acima foram confirmados pelo dono em 2026-09-27.

**Varredura de dimensões implícitas:** autorização → CNF-02 e CNF-27 (selo e
ordem partem do usuário da sessão); validação de entrada → CNF-28 (parâmetro de
ordem inválido); estado → CNF-21 (stepper em zero). Falha parcial, idempotência,
concorrência, ciclo de vida de dado, observabilidade e dependência externa: N/A,
porque a feature muda apresentação e uma ordenação de leitura, sem escrita nova.

---

## User Stories

### P1: Catálogo como o artboard ⭐ MVP

**User Story**: Como colecionador, quero a grade do catálogo como o canvas a
desenha, para ver de relance o que tenho sem controles espalhados por cada carta.

**Why P1**: É a tela de entrada e a mais reprovada na revisão.

**Acceptance Criteria**:

1. The system SHALL NOT renderizar controle de posse (incremento, decremento ou formulário) em nenhum tile da grade do catálogo. <!-- CNF-01 -->
2. WHILE o usuário tiver sessão e possuir ao menos uma cópia de alguma variante da carta, the system SHALL exibir no tile um selo com o total de cópias das variantes da carta, posicionado sobre o canto superior direito da arte, com fundo `--accent`, texto `--on-accent` e nome acessível "N cópias" ("1 cópia" no singular). <!-- CNF-02 -->
3. IF o usuário não tiver sessão ou a quantidade for zero THEN the system SHALL NOT renderizar o selo no tile. <!-- CNF-03 -->
4. WHEN a carta tiver uma única variante THEN the system SHALL exibir no tile a raridade dessa variante ao lado do código; WHEN tiver mais de uma THEN the system SHALL exibir "N impressões" no lugar da raridade. <!-- CNF-04 -->
5. The system SHALL exibir a linha de status como uma frase única "N cartas", acrescida de " · M filtros ativos" (ou "1 filtro ativo") quando houver filtro, contando o total do resultado e não o da página. <!-- CNF-05 -->
6. WHILE houver filtro ativo E ao menos um resultado, the system SHALL exibir na linha de status o botão "Limpar filtros", bordado, com altura mínima de 44px, que leva ao catálogo sem filtros e preserva `sort` e `dir` (decisão T17). <!-- CNF-06 -->
41. WHEN o filtro ativo não retornar resultado THEN the system SHALL exibir "Limpar filtros" no estado vazio (`.catalog__empty`), com altura mínima de 44px, e nenhum link na linha de status (`.catalog__status`). <!-- CNF-41 -->
7. WHILE o usuário não tiver sessão, the system SHALL exibir uma única vez, na linha de status, o convite "Entrar para registrar posse" apontando para a página de entrada, e nenhum convite nos tiles. <!-- CNF-07 -->
8. WHILE a largura da viewport for de 1024px ou mais, the system SHALL exibir a linha de status na mesma linha do campo de busca, com "Limpar filtros" à direita, e alinhar a borda esquerda da busca à borda esquerda da grade (mesmo recuo resolvido em `.catalog__head` e `.catalog__body`); o campo de busca SHALL ter 480px (`30rem`) de largura, como em `Desktop-Catalogo.dc.html:69`. <!-- CNF-08 -->
9. The system SHALL rotular o campo de busca "Buscar por nome ou card_number" e usar um código de carta (ex.: "OP01-024") como placeholder. <!-- CNF-09 -->
10. The system SHALL NOT exibir no catálogo o total de cópias da coleção ("Sua coleção: N cópias"). <!-- CNF-10 -->
11. The system SHALL ordenar os chips de cor como Red, Green, Blue, Purple, Black, Yellow, os de raridade como C, UC, R, SR, SEC, L seguidos dos demais em ordem alfabética, e exibir o tipo com inicial maiúscula, sem alterar o valor enviado na URL. <!-- CNF-11 -->
12. WHILE a largura da viewport for de 1280px, the system SHALL renderizar a grade com cinco colunas de mesma largura e 16px de espaço entre tiles; abaixo de 1024px, duas colunas com 8px, sem scroll horizontal em 360px (Req. 2.5). <!-- CNF-12 -->
13. The system SHALL dar ao tile padding de 16px e à arte uma moldura `--surface-sunken` com padding de 8px, de modo que a imagem não ocupe a largura inteira do tile, e separar navegação e filtros na coluna lateral por um divisor de 1px `--border`. <!-- CNF-13 -->
14. WHILE nenhum filtro de posse estiver ativo, the system SHALL marcar o chip "Todas" como atual sem sinal "×" e sem nome acessível de remoção. <!-- CNF-31 -->

**Independent Test**: `get catalog_path` com e sem sessão, com uma carta de uma
variante e outra de três, e com filtros; asserções sobre o HTML (selo, ausência
de `form` de posse, frase de status, convite único) e sobre `Stylesheet.resolved`
(5 colunas em 1280px, paddings, divisor).

---

### P1: Detalhe da carta como o artboard ⭐ MVP

**User Story**: Como colecionador, quero o detalhe da carta com a composição do
canvas, para registrar as cópias de cada impressão com o polegar.

**Why P1**: É onde o registro de posse passa a morar (Req. 7.5).

**Acceptance Criteria**:

1. WHILE a largura da viewport for menor que 1024px, the system SHALL exibir uma miniatura da primeira variante listada ao lado do título, e a imagem maior do Req. 5.1 dentro de um `<details>` que expande no lugar, sem JavaScript. <!-- CNF-14 -->
2. WHILE a largura da viewport for de 1024px ou mais, the system SHALL exibir a imagem maior numa coluna própria de 320px à esquerda dos dados, sempre visível, com o placeholder do Req. 2.3 na mesma medida. <!-- CNF-15 -->
3. WHILE o usuário tiver sessão e possuir a primeira variante listada, the system SHALL exibir sobre a imagem principal o selo com a quantidade dessa variante; WHEN a variante tiver ilustrador THEN the system SHALL exibir abaixo da imagem a legenda "Ilustração: {nome}". <!-- CNF-16 -->
4. The system SHALL exibir no cabeçalho, como chips, o tipo, a raridade da primeira variante listada e cada cor da carta, mais o counter quando existir e a viewport for de 1024px ou mais, e abaixo do título a linha "{nome do set} · {código}" da primeira variante; os demais campos do Req. 5.1 (custo, power, life, attribute, traits, block) SHALL aparecer em forma compacta, respeitando o Req. 5.5. <!-- CNF-17 -->
5. WHEN a carta tiver texto de trigger THEN the system SHALL exibi-lo dentro da seção "Efeito", depois do efeito, com o rótulo "Trigger" em peso 600, preservando quebras de linha (Req. 5.4). <!-- CNF-18 -->
6. The system SHALL intitular a lista de variantes "Variantes na pasta" e separá-la da seção de efeito por um divisor de 1px `--border`. <!-- CNF-19 -->
7. The system SHALL exibir em cada linha de variante o código, "{raridade} · {tipo de arte}", o set, e uma miniatura própria menor que a imagem principal, com os rótulos "Código", "Raridade" e "Set" presentes no HTML e fora da vista. <!-- CNF-20 -->
8. WHILE o usuário tiver sessão, the system SHALL exibir em cada linha de variante o controle `−` `[n]` `+` nessa ordem, com botões de 44×44px e `[n]` como texto não editável da quantidade; WHILE a quantidade for zero, the system SHALL exibir "não tenho" e o `−` com `aria-disabled="true"`. <!-- CNF-21 -->
9. WHEN o usuário acionar `+` ou `−` no detalhe THEN the system SHALL atualizar a quantidade exibida da variante sem recarregar a página (Req. 7.5, Turbo Stream). <!-- CNF-22 -->
10. The system SHALL exibir "Voltar ao catálogo" como botão bordado de altura mínima de 44px, sem seta; WHILE a largura da viewport for de 1024px ou mais, SHALL posicioná-lo na coluna lateral, abaixo da navegação e de um divisor de 1px. <!-- CNF-23 -->
11. WHILE a largura da viewport for de 1024px ou mais, the system SHALL exibir a marca "Bindr" com a tipografia `display` do design system (28/32, peso 700). <!-- CNF-24 -->

**Independent Test**: `get card_path(card.card_number)` com uma carta de três
variantes (uma com ilustrador, uma possuída) com e sem sessão; asserções sobre a
ordem `−`/`[n]`/`+`, "não tenho", `<details>` da imagem, chips do cabeçalho e
`Stylesheet.resolved` para 44px, 320px e divisores; POST de incremento com
`Accept: text/vnd.turbo-stream.html` responde stream.

---

### P1: Minha pasta como o artboard ⭐ MVP

**User Story**: Como colecionador, quero a pasta com a lista de sets do canvas e
ordená-la pelo que mexi por último, para voltar ao set que estou montando.

**Why P1**: A pasta é o resumo da coleção e a segunda tela mais usada.

**Acceptance Criteria**:

1. The system SHALL exibir em cada linha de set o código e o nome do set à esquerda, sendo o nome o link para o catálogo filtrado por aquele set (Req. 9.3), e "possuídas / total" à direita, com a barra de progresso abaixo. <!-- CNF-25 -->
2. The system SHALL exibir o percentual (Req. 9.2) junto da contagem "possuídas / total" e a contagem de parallels (Req. 9.6) como legenda da linha, e SHALL NOT exibir o link "Ver no catálogo" nem a contagem total de sets. <!-- CNF-26 -->
3. The system SHALL ordenar os sets pelo `updated_at` mais novo dos `collection_items` do usuário da sessão em cada set, do mais novo para o mais antigo, quando o parâmetro de ordem estiver ausente ou for `recent`; e pelo código do set, crescente, quando for `code`; em ambas, os sets sem posse ficam no fim, por código, e empates por código. <!-- CNF-27 -->
4. IF o parâmetro de ordem for desconhecido ou inválido THEN the system SHALL aplicar a ordem "Recentes" e responder 200. <!-- CNF-28 -->
5. The system SHALL exibir junto do título "Progresso por set" os chips-link "Recentes" e "Por código", com `aria-current` no chip da ordem aplicada. <!-- CNF-29 -->
6. WHILE a largura da viewport for de 1024px ou mais, the system SHALL exibir os cartões de indicador em quatro colunas de mesma largura com 16px de espaço, a coluna de sets com a largura do artboard e as ações secundárias (wishlist, import, export) numa segunda coluna de 420px. <!-- CNF-30 -->
7. WHILE a largura da viewport for menor que 1024px, the system SHALL fixar "Adicionar cartas à pasta" acima da barra inferior, com fundo `--accent` e altura mínima de 44px, sem cobrir o fim do conteúdo; WHILE for de 1024px ou mais, SHALL exibir "Adicionar cartas" na coluna lateral, abaixo de um divisor de 1px. <!-- CNF-32 -->
8. The system SHALL estilizar o campo de arquivo da página de import com as superfícies, borda e altura mínima de 44px do design system. <!-- CNF-33 -->

**Independent Test**: dois usuários; o primeiro com posse em OP02 (atualizada
agora) e OP01 (ontem); `get progress_path` → OP02, OP01, depois os sem posse por
código; `?order=code` → OP01, OP02, …; `?order=xyz` → mesma ordem do padrão; o
segundo usuário não altera a ordem do primeiro.

---

### P1: Captura conferida contra o artboard ⭐ MVP

**User Story**: Como dono do produto, quero conferir as telas contra a checklist
de cada artboard, para aprovar pela composição e não por traços isolados.

**Why P1**: É o critério de aceite da AD-016; sem ele a feature repete o erro da `navegacao`.

**Acceptance Criteria**:

1. WHEN as tasks de tela estiverem concluídas THEN the system SHALL ter capturas de catálogo, detalhe e pasta, com e sem sessão, em 390px e 1280px, geradas por `spec/visual/capture.cjs`, postas lado a lado com o artboard correspondente. <!-- CNF-34 -->
2. The system SHALL ter cada item da checklist de cada artboard marcado como conforme, coberto por um CNF que o justifica, ou listado no Out of Scope desta spec; um item em nenhum dos três reprova a task. <!-- CNF-35 -->

**Independent Test**: tabela item × resultado em `canvas-conformance.md` da
feature, com a imagem da comparação de cada tela.

---

## Edge Cases

- IF a carta não tiver imagem THEN the system SHALL exibir o placeholder do Req. 2.3 na miniatura, na imagem do `<details>` e na coluna de 320px, na mesma medida da imagem: 155×217px na miniatura (`Mobile-Carta.dc.html:24`) e 320px de largura por 448px de altura na coluna (`Desktop-Carta.dc.html:32-33`). <!-- CNF-36 -->
- IF a variante não tiver ilustrador THEN the system SHALL omitir a legenda "Ilustração". <!-- CNF-37 -->
- WHEN a coleção do usuário estiver vazia THEN the system SHALL listar todos os sets por código, com "Recentes" ainda marcado como ordem atual. <!-- CNF-38 -->
- WHEN a carta tiver mais de uma cor THEN the system SHALL exibir um chip por cor no cabeçalho do detalhe. <!-- CNF-39 -->
- IF a raridade da variante for um valor fora da lista conhecida THEN the system SHALL exibir o chip de filtro dessa raridade depois dos conhecidos, sem erro. <!-- CNF-40 -->

---

## Requirement Traceability

| Requirement ID | Story | Origem | Task | Status |
|---|---|---|---|---|
| CNF-01 | P1: Catálogo | Req. 7.5, 13.22 | T3 | Implemented |
| CNF-02 | P1: Catálogo | Req. 13.22, 12.6 | T3, T19 | Implemented |
| CNF-03 | P1: Catálogo | Req. 13.22, 6.3 | T3 | Implemented |
| CNF-04 | P1: Catálogo | Req. 13.24 (D6) | T3, T13, T19 | Implemented |
| CNF-05 | P1: Catálogo | Req. 13.26, 13.12 | T4 | Implemented |
| CNF-06 | P1: Catálogo | Req. 13.26, 3.6 | T4, T21 | Implemented |
| CNF-07 | P1: Catálogo | Req. 13.23 (D5) | T4 | Implemented |
| CNF-08 | P1: Catálogo | Req. 13.26, 13.18 (NAV-47) | T4, T20, T21 | Implemented |
| CNF-09 | P1: Catálogo | Req. 13.27 | T4, T13 | Implemented |
| CNF-10 | P1: Catálogo | Req. 13.28 | T4 | Implemented |
| CNF-11 | P1: Catálogo | Req. 13.29 | T2 | Implemented |
| CNF-12 | P1: Catálogo | Req. 13.25 (D7), 2.5 | T5, T16, T18 | Implemented |
| CNF-13 | P1: Catálogo | Req. 13.21 | T5, T13 | Implemented |
| CNF-14 | P1: Detalhe | Req. 13.30 (D8), 5.1 | T6, T22 | Implemented |
| CNF-15 | P1: Detalhe | Req. 13.19 | T6, T14 | Implemented |
| CNF-16 | P1: Detalhe | Req. 13.35 | T6, T19, T22 | Implemented |
| CNF-17 | P1: Detalhe | Req. 13.31, 5.1, 5.5 | T7, T21 | Implemented |
| CNF-18 | P1: Detalhe | Req. 13.32, 5.4 | T7, T20 | Implemented |
| CNF-19 | P1: Detalhe | Req. 13.33 | T8 | Implemented |
| CNF-20 | P1: Detalhe | Req. 13.33, 5.2 (D9, NAV-49) | T8, T14 | Implemented |
| CNF-21 | P1: Detalhe | Req. 13.33 (D10), 7.2, 7.4 | T8, T14 | Implemented |
| CNF-22 | P1: Detalhe | Req. 7.5 | T8 | Implemented |
| CNF-23 | P1: Detalhe | Req. 13.34 | T9, T20 | Implemented |
| CNF-24 | P1: Detalhe | Req. 13.21 | T9 | Implemented |
| CNF-25 | P1: Pasta | Req. 13.36, 9.3 | T10, T15, T16 | Implemented |
| CNF-26 | P1: Pasta | Req. 13.36, 9.2, 9.6 | T10, T15 | Implemented |
| CNF-27 | P1: Pasta | Req. 9.7 (D11), 6.5 | T1 | Implemented |
| CNF-28 | P1: Pasta | Req. 9.7 | T1 | Implemented |
| CNF-29 | P1: Pasta | Req. 13.37 | T10, T15 | Implemented |
| CNF-30 | P1: Pasta | Req. 13.39, 13.21 | T11 | Implemented |
| CNF-31 | P1: Catálogo | Req. 13.11 (lacuna da validação da `navegacao`) | T4 | Implemented |
| CNF-32 | P1: Pasta | Req. 13.38, 13.3 | T11, T15, T17 | Implemented |
| CNF-33 | P1: Pasta | Req. 13.21 | T11, T16 | Implemented |
| CNF-34 | P1: Captura | Req. 13.21 (AD-016) | T12 | ✅ Verified (aprovado pelo dono em 2026-10-01) |
| CNF-35 | P1: Captura | Req. 13.21 (AD-016) | T12 | ✅ Verified (aprovado pelo dono em 2026-10-01) |
| CNF-36 | Edge case | Req. 2.3 | T6, T21 | Implemented |
| CNF-37 | Edge case | Req. 13.35 | T6 | Implemented |
| CNF-38 | Edge case | Req. 9.7 | T1 | Implemented |
| CNF-39 | Edge case | Req. 13.31 | T7 | Implemented |
| CNF-40 | Edge case | Req. 13.29, `rarity` como texto | T2 | Implemented |
| CNF-41 | P1: Catálogo | Req. 13.26, 3.6 (decisão T17) | T17, T21 | Implemented |

**Coverage:** 41 total, 41 mapped to tasks (T1–T22); T13–T17 são as correções da conferência com o canvas de 2026-09-28; T18–T22 são as correções do ciclo 1.

---

## Success Criteria

- [ ] Todos os CNF-01..CNF-40 com teste que discrimina, e o Verifier da `conformidade` em PASS.
- [ ] Capturas de catálogo, detalhe e pasta em 390px e 1280px, com e sem sessão, conferidas contra a checklist de cada artboard sem item órfão (CNF-35), e aprovadas pelo dono.
- [ ] Gate full verde (`bin/rails test && bin/rubocop`) e gate build verde.
- [ ] Nenhum teste de NAV mantido por referência removido ou afrouxado sem motivo registrado na task.
