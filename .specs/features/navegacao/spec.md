# Navegação e layout das telas — Especificação

**Status**: Approved (2026-09-23, pelo dono do produto)

## Problem Statement

O app tem as telas do MVP, mas elas não têm estrutura de navegação: um cabeçalho
com links de texto no topo, longe do polegar, e cada resumo da coleção numa página
diferente. O pior é que a grade **não tem nenhum controle para aplicar filtro**:
o Req. 4 é atendido pelo query object e pelos chips de remoção, mas o único jeito
de filtrar é editar a URL ou chegar pelo link "ver no catálogo" do progresso. O
canvas "Bindr — telas" (`claude.ai/artifact/P7WCTR9YkH1i52DWoVwPn8`) desenha a
estrutura que falta. Esta feature a aplica ao que já existe, sem baralho e sem
preço.

## Goals

- [ ] Catálogo e Minha pasta ficam a um toque de qualquer página, na borda
      inferior em viewport estreita e em coluna lateral em viewport larga
- [ ] Cor, tipo, raridade, set e posse podem ser aplicados na grade sem editar a
      URL
- [ ] "Minha pasta" responde "quanto tenho?" e "quanto falta do set X?" na mesma
      tela
- [ ] As verificações de 360px do Req. 2.5 e os testes de `test/design/` continuam
      passando sem edição

## Out of Scope

| Feature | Reason |
|---|---|
| Entrada e telas de "Baralhos" | Fase 2; o `.context/tasks.md` exige confirmar as regras no regulamento oficial antes de qualquer código |
| Valor estimado, cotações, "falta comprar", "faltando para os baralhos" | Fase 3 (preços) sem fonte de mercado; "faltando para os baralhos" depende também da Fase 2 |
| Botão "Zerar quantidade desta carta" | Comportamento novo de coleção; esta feature muda layout, não operação |
| Controles para faixa de custo/power/counter, `attribute` e `trait` | Decisão do dono (2026-09-22): ficam só pela URL, como hoje |
| Indicador "% do catálogo" | Métrica nova sem denominador definido (cartas ou variantes); não está no Req. 9 nem no Req. 13 |
| Rota nova para a pasta | Decisão do dono: a página de progresso vira a pasta, `/progress` permanece |
| Hexadecimais das seis cores do jogo | Pendência P8 aberta; chips seguem neutros (Req. 12.11) |
| Ícones na navegação | Design system não escolheu conjunto; a navegação usa palavra escrita |
| Verificação de layout em navegador real | Não há navegador no container; UI vira teste de integração sobre HTML e teste sobre o texto da folha |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
|---|---|---|---|
| O que o canvas vira agora | Layout do MVP, só com dados que existem | Baralho e preço são fases futuras com pendências próprias | y |
| O que é "Minha pasta" | A página de progresso, com total de cópias, variantes distintas e links para wishlist, import e export | Nenhuma rota nova; o progresso já é a página "da minha coleção" | y |
| Controles de filtro | Cor, tipo, raridade, set e posse | Os que o canvas desenha, mais set; o resto continua pela URL | y |
| Fonte de verdade | `.context/requirements.md` Req. 4.9 e Req. 13; canvas é referência visual | O canvas é externo e editável fora do repo (AD-005, como na AD-011) | y |
| Itens da navegação com sessão | Catálogo, Minha pasta, Sair | Três itens cabem com folga em 360px; "Sair" continua alcançável como hoje | y |
| Itens da navegação sem sessão | Catálogo, Entrar, Criar conta | Link para página que exige sessão só levaria ao login (regra já usada no cabeçalho atual) | y |
| Fronteira estreita/larga | 1024px de largura | O canvas desenha 390px e 1280px; 1024px deixa tablet em retrato com barra inferior | y |
| Uma marcação ou duas para a navegação | Uma só, reposicionada por CSS | Duas cópias divergem na primeira correção e duplicam os links para leitor de tela | y |
| Filtro sem JavaScript | Os controles funcionam como formulário GET ou links; JS é opcional | Stimulus não está pinado no projeto; o Req. 4.7 já exige estado na URL | y |
| Fileiras de chips em 360px | Quebram linha, sem rolagem horizontal interna | O canvas rola a fileira; controle escondido fora da tela é pior de descobrir e de testar | y |
| Controle de posse para anônimo | Não renderizado | O query object já ignora `owned` sem usuário; mostrar controle inerte é promessa quebrada | y |
| Título da página de progresso | `h1` "Minha pasta", "Progresso por set" vira `h2` | É a entrada da navegação; o nome da seção continua dizendo o que a lista é | y |
| Testes que leem `catalog.css` como texto | Não são editados; regras novas só são acrescentadas | Mesma restrição da `interface` (AD-011, trade-off 2) | y |

**Open questions:** none — os defaults do agente foram confirmados pelo dono
na aprovação desta spec (2026-09-23).

---

## User Stories

### P1: Navegação principal ao alcance do polegar ⭐ MVP

**User Story**: Como colecionador com o celular numa mão e um booster na outra,
quero trocar entre catálogo e pasta com um toque na borda inferior, para não subir
até o topo da tela.

**Why P1**: É a estrutura de todas as telas do canvas e a condição para o critério
de sucesso do `product.md` §7 ("quanto falta do set X?" em até três toques).

**Acceptance Criteria**:

1. The system SHALL renderizar em toda página um único elemento `nav` de navegação principal com a entrada "Catálogo" apontando para o catálogo. <!-- NAV-01 -->
2. WHILE houver sessão, the system SHALL exibir na navegação principal as entradas "Minha pasta", apontando para `/progress`, e "Sair", que encerra a sessão. <!-- NAV-02 -->
3. WHILE não houver sessão, the system SHALL exibir "Entrar" e "Criar conta" no lugar de "Minha pasta" e "Sair". <!-- NAV-03 -->
4. WHEN uma página da navegação estiver aberta THEN the system SHALL marcar a entrada correspondente com `aria-current="page"` e com peso de fonte distinto das demais. <!-- NAV-04 -->
5. WHILE a largura da viewport for menor que 1024px, the system SHALL fixar a navegação principal na borda inferior, com cada entrada de altura mínima de 44px, e reservar no fim do conteúdo espaço igual à altura da barra. <!-- NAV-05 -->
6. WHILE a largura da viewport for de 1024px ou mais, the system SHALL posicionar a navegação principal numa coluna lateral à esquerda do conteúdo. <!-- NAV-06 -->
7. The system SHALL não exibir na navegação entrada para baralho, preço ou cotação. <!-- NAV-07 -->

**Independent Test**: Abrir o catálogo logado e anônimo; o HTML traz uma única
`nav` principal com as entradas de cada caso e `aria-current="page"` em
"Catálogo"; a folha fixa a barra embaixo abaixo de 1024px.

---

### P1: Filtrar a grade sem editar a URL ⭐ MVP

**User Story**: Como colecionador, quero tocar em "Red" ou "SR" na grade e ver o
resultado filtrado, para responder "quais Characters vermelhos existem?" sem
conhecer o formato da URL.

**Why P1**: Hoje o Req. 4 só existe para quem edita a URL; sem controle, o filtro
é invisível para o usuário.

**Acceptance Criteria**:

1. The system SHALL exibir na grade um controle por valor de cor, tipo de carta e raridade presentes no catálogo, e um controle de seleção de set. <!-- NAV-08 -->
2. WHEN o usuário aplicar um valor de filtro pelo controle THEN the system SHALL produzir a mesma URL de parâmetros e o mesmo resultado que o query object já aceita para aquele valor (`design.md` §4.2). <!-- NAV-09 -->
3. WHEN um filtro for aplicado pelo controle THEN the system SHALL preservar na URL a busca textual e os demais filtros já ativos, inclusive os que não têm controle (faixas, `attribute`, `trait`). <!-- NAV-10 -->
4. WHILE um valor de filtro estiver ativo, the system SHALL indicar o controle correspondente como ativo por rótulo ou estado escrito, não só por cor (Req. 12.6). <!-- NAV-11 -->
5. WHILE houver sessão, the system SHALL exibir o controle de posse com as opções "todas", "tenho" e "não tenho", mapeadas para `owned=all|owned|missing`. <!-- NAV-12 -->
6. WHILE não houver sessão, the system SHALL não renderizar o controle de posse. <!-- NAV-13 -->
7. The system SHALL aplicar os filtros pelos controles sem depender de JavaScript. <!-- NAV-14 -->
8. The system SHALL renderizar o controle de cor sem preenchimento `accent`, com seleção indicada por anel de 2px em `accent` e rótulo escrito (Req. 12.11). <!-- NAV-15 -->

**Independent Test**: Na grade, sem JS, marcar "Red" e "SR", aplicar; a URL traz
`colors[]=Red&rarities[]=SR`, a contagem bate com a da URL digitada à mão e os dois
controles aparecem ativos por texto.

---

### P1: Minha pasta como resumo da coleção ⭐ MVP

**User Story**: Como colecionador, quero abrir "Minha pasta" e ver quantas cartas
tenho, quantas diferentes, e o progresso por set, para decidir o que caçar sem
passar por três páginas.

**Why P1**: É a segunda entrada da navegação e o lugar onde o critério de sucesso
do MVP se responde.

**Acceptance Criteria**:

1. WHEN o usuário com sessão abrir `/progress` THEN the system SHALL exibir o título de nível 1 "Minha pasta" e a lista de progresso por set sob o título de nível 2 "Progresso por set". <!-- NAV-16 -->
2. The system SHALL exibir em "Minha pasta" o total de cópias possuídas pelo usuário da sessão, com o mesmo valor que `owned_total` produz para o catálogo (Req. 7.7). <!-- NAV-17 -->
3. The system SHALL exibir em "Minha pasta" o número de variantes distintas com quantidade maior ou igual a 1 do usuário da sessão. <!-- NAV-18 -->
4. The system SHALL exibir em "Minha pasta" links para a wishlist, para o import e para o export da coleção. <!-- NAV-19 -->
5. WHEN o usuário não tiver nenhuma cópia THEN the system SHALL exibir os dois indicadores com valor 0, não omiti-los. <!-- NAV-20 -->
6. The system SHALL calcular os indicadores exclusivamente a partir do usuário da sessão, ignorando qualquer identificador de usuário vindo do request (Req. 6.5). <!-- NAV-21 -->

**Independent Test**: Logado com 3 cópias de uma variante e 1 de outra, abrir
"Minha pasta": "4 cartas na pasta", "2 cartas diferentes", a lista de sets sob
"Progresso por set" e os três links; `?user_id=` de outro usuário não muda nada.

---

### P2: Layout largo para catálogo e detalhe

**User Story**: Como colecionador no computador, quero filtros ao lado da grade e
a arte ao lado dos dados da carta, para aproveitar a largura da tela.

**Why P2**: Não muda o que o usuário consegue fazer, só onde as coisas ficam; o
uso principal é no celular.

**Acceptance Criteria**:

1. WHILE a largura da viewport for de 1024px ou mais, the system SHALL posicionar os controles de filtro numa coluna ao lado da grade. <!-- NAV-22 -->
2. WHILE a largura da viewport for menor que 1024px, the system SHALL posicionar os controles de filtro acima da grade, em fluxo normal. <!-- NAV-23 -->
3. WHILE a largura da viewport for de 1024px ou mais, the system SHALL exibir no detalhe da carta a arte ao lado dos dados da carta. <!-- NAV-24 -->
4. The system SHALL manter no detalhe todos os campos e controles que ele exibe hoje (Req. 5, posse do Req. 7, marca de wishlist do Req. 8). <!-- NAV-25 -->

**Independent Test**: A folha declara as regras de duas colunas só dentro de
`@media (min-width: 1024px)`; o HTML do detalhe traz os mesmos campos e controles
de antes.

---

## Edge Cases

- IF um parâmetro de filtro for desconhecido ou inválido THEN the system SHALL ignorá-lo também nos controles, sem marcar nenhum como ativo e sem erro. <!-- NAV-26 -->
- WHEN o catálogo estiver filtrado até zero resultados THEN the system SHALL manter os controles de filtro visíveis, com os valores ativos marcados. <!-- NAV-27 -->
- WHILE a viewport tiver 360px de largura, the system SHALL não produzir scroll horizontal da página com a navegação, os controles de filtro e os indicadores da pasta (Req. 2.5). <!-- NAV-28 -->
- IF o usuário anônimo abrir `/progress` THEN the system SHALL redirecioná-lo ao login, como hoje (Req. 6.4). <!-- NAV-29 -->

### Varredura de dimensões implícitas

| Dimensão | Resolução |
|---|---|
| Validação de entrada | NAV-26; o query object já normaliza e descarta parâmetros |
| Falha / falha parcial | N/A: só leitura e layout; nenhuma escrita nova |
| Idempotência / retry | N/A: filtros são GET, reenviar dá o mesmo resultado |
| Fronteira de autenticação | NAV-02, NAV-03, NAV-13, NAV-21, NAV-29 |
| Concorrência / ordem | N/A: nenhuma escrita nova |
| Ciclo de vida do dado | N/A: nenhum dado novo persistido |
| Observabilidade | N/A: nenhum fluxo novo de servidor além de duas contagens |
| Falha de dependência externa | N/A: nenhuma chamada externa nova |
| Integridade de transição de estado | N/A: não há estado com transição nesta feature |

---

## Requirement Traceability

| Requirement ID | Story | Origem | Status |
|---|---|---|---|
| NAV-01 | P1: Navegação principal | Req. 13.1 | Pending |
| NAV-02 | P1: Navegação principal | Req. 13.1 | Pending |
| NAV-03 | P1: Navegação principal | Req. 13.1 | Pending |
| NAV-04 | P1: Navegação principal | Req. 13.2 | Pending |
| NAV-05 | P1: Navegação principal | Req. 13.3 | Pending |
| NAV-06 | P1: Navegação principal | Req. 13.3 | Pending |
| NAV-07 | P1: Navegação principal | Req. 13.8 | Pending |
| NAV-08 | P1: Filtrar a grade | Req. 4.9 | Implemented (T1) |
| NAV-09 | P1: Filtrar a grade | Req. 4.9, 4.7 | Pending |
| NAV-10 | P1: Filtrar a grade | Req. 4.3, 4.7 | Pending |
| NAV-11 | P1: Filtrar a grade | Req. 12.6 | Pending |
| NAV-12 | P1: Filtrar a grade | Req. 4.9, 7.6 | Pending |
| NAV-13 | P1: Filtrar a grade | Req. 6.3 | Pending |
| NAV-14 | P1: Filtrar a grade | Req. 4.9 | Pending |
| NAV-15 | P1: Filtrar a grade | Req. 12.11 | Pending |
| NAV-16 | P1: Minha pasta | Req. 13.4 | Implemented (T3) |
| NAV-17 | P1: Minha pasta | Req. 13.4, 7.7 | Implemented (T3) |
| NAV-18 | P1: Minha pasta | Req. 13.4 | Implemented (T3) |
| NAV-19 | P1: Minha pasta | Req. 13.4 | Implemented (T4) |
| NAV-20 | P1: Minha pasta | Req. 13.4 | Implemented (T3) |
| NAV-21 | P1: Minha pasta | Req. 6.5 | Implemented (T3) |
| NAV-22 | P2: Layout largo | Req. 13.5 | Pending |
| NAV-23 | P2: Layout largo | Req. 13.5 | Pending |
| NAV-24 | P2: Layout largo | Req. 13.6 | Pending |
| NAV-25 | P2: Layout largo | Req. 13.6 | Pending |
| NAV-26 | Edge case | Req. 4 (parâmetro inválido ignorado) | Pending |
| NAV-27 | Edge case | Req. 3.6 | Pending |
| NAV-28 | Edge case | Req. 2.5, 13.7 | Pending |
| NAV-29 | Edge case | Req. 6.4 | Implemented (T3) |

**Coverage:** 29 total, 0 mapped to tasks, 29 unmapped ⚠️ (tasks ainda não
escritas)

---

## Success Criteria

- [ ] Registrar posse e chegar a "quanto falta do set X?" a partir do catálogo em
      no máximo três toques no celular (`product.md` §7)
- [ ] Aplicar cor + raridade na grade sem tocar na URL, sem JavaScript
- [ ] `bin/rails test && bin/rubocop` limpo, com os arquivos de `test/design/` e os
      sete testes que leem `catalog.css` sem edição
- [ ] Revisão visual aprovada pelo dono do produto em 360px e em 1280px
