# Conformidade com o canvas — conferência da T12 (2026-09-28)

Capturas do app em Chromium no host (`spec/visual/capture.cjs` e uma captura com
posse registrada pelo stepper do detalhe), em 390px e 1280px, anônimo e com
sessão, postas ao lado do artboard em `tmp/comparacao/{catalogo,detalhe,pasta}-{390,1280}.png`.
A captura é evidência de revisão, não gate (AD-015); `tmp/` fica fora do git.

Cada item das checklists T3–T11 do `tasks.md` recebe um de três resultados
(CNF-35): **conforme**, **CNF** (a divergência é pedida por um critério) ou
**Out of Scope** (linha da spec). Nenhum item ficou sem resultado.

A primeira passada, depois da T11, reprovou 11 itens; eles viraram T13–T17 e
estão conformes nesta passada. Medição de `scrollWidth` a 360px em catálogo
(com e sem filtro), detalhe, pasta (as duas ordens), import e wishlist, anônimo
e com sessão: todas iguais à viewport depois da T16.

## Catálogo (`Main.dc.html` 390px, `Desktop-Catalogo.dc.html` 1280px)

| Item da checklist | Resultado |
|---|---|
| Selo accent no canto superior direito da arte, só com posse (Main:61, D:83) | Conforme |
| Nome 15px 600 com reticências (Main:65) | Conforme |
| Código mono 13px e raridade numa linha, gap 8 (Main:65-66) | Conforme (corrigido na T13) |
| Rótulo da busca 13/18 muted (Main:24) | Conforme (T13) |
| Placeholder `OP01-024`, 44px, surface, border-strong (Main:25); 480px em 1280 (D:69) | Conforme; a largura em 1280 vem da linha busca + status (CNF-08) |
| Status "N cartas · M filtros ativos" + "Limpar filtros" 44px bordado (Main:48-49, D:66-75) | Conforme |
| Convite anônimo | CNF-07: uma vez, na linha de status (o artboard não desenha anônimo) |
| Chip ativo accent com "×"; inativo transparente (Main:29-30, D:44, D:56) | Conforme |
| Chip "owned/missing" cru (D:54) | CNF-31 e canvas incompleto: "Todas / Tenho / Não tenho" (NAV-12) |
| Grupo "Tipo", seletor de set, botão "Buscar", paginação | Canvas incompleto (spec, Out of Scope) |
| Ordem das cores e raridades (D:32-37, D:42) | CNF-11: cores como o canvas; raridades por valor (padrão confirmado) |
| h1 "Catálogo" no topo, conteúdo com padding 24 (D:62-64) | Conforme (T13) |
| Grade 2 colunas gap 8 (Main:55); 5 colunas gap 16 (D:77) | Conforme |
| Tile surface, borda, raio 8, padding 16; arte sunken, padding 8 (Main:57-58, D:79-80) | Conforme |
| Coluna lateral 280px, surface, divisor entre navegação e filtros (D:19, D:27) | Conforme |
| Entrada "Baralhos" (Main:136-139, D:22-24) | Out of Scope (Fase 2) |

## Detalhe da carta (`Mobile-Carta.dc.html`, `Desktop-Carta.dc.html`)

| Item da checklist | Resultado |
|---|---|
| Miniatura ao lado do título; imagem maior sob demanda (Mobile:23-40) | Conforme; "Ver imagem maior" em `<details>` (CNF-14) |
| Imagem 320px em coluna própria, no topo (D:32-37) | Conforme (T14) |
| Selo de quantidade sobre a imagem (Mobile:27, D:36) | Conforme |
| "Ilustração: nome" (D:38) | Conforme quando há ilustrador; a fixture de captura não tem (CNF-37) |
| h1, código mono, chips Tipo/Raridade/Cor (+ Counter em 1280) (Mobile:31-37, D:45-55) | Conforme |
| Linha "set · código" (Mobile:38) | Conforme; nome cru do set (Out of Scope, D12) |
| Campos Power/Life/Attribute/Traits/Block | CNF-17 (Req. 5.1; o canvas não desenha) |
| Efeito com trigger inline (Mobile:43-45) | Conforme |
| Divisores 1px e "Variantes na pasta" (Mobile:48-51) | Conforme |
| Linha da variante surface/borda/raio 8; em 1280 numa linha (Mobile:53, D:69) | Conforme (T14) |
| "raridade · tipo de arte" 13 muted; "não tenho" (Mobile:57, :72, :74) | Conforme (T14) |
| Stepper `− [n] +`, 44×44, `[n]` sunken só exibe (Mobile:62-64) | Conforme (T14) |
| Miniatura própria de cada variante | Canvas incompleto (D9, Req. 5.2) |
| Marca de wishlist por variante | Canvas incompleto (Req. 8.1) |
| "Voltar ao catálogo" bordado 44px sem seta; em 1280 na coluna lateral (Mobile:21, D:26-27) | Conforme; em 390 fica no cabeçalho, ao lado da marca, que o dono manteve em todas as larguras |
| Cotações, "Zerar quantidade desta carta" (Mobile:87-115, D:39, D:94-121) | Out of Scope |

## Minha pasta (`Mobile-Pasta.dc.html`, `Desktop-Pasta.dc.html`)

| Item da checklist | Resultado |
|---|---|
| h1 e cartões "cartas na pasta" / "cartas diferentes" (Mobile:21-30) | Conforme |
| Cartões 2 colunas gap 8; em 1280, 4 colunas de 1/4 (Mobile:23, D:34) | Conforme |
| "Valor estimado", "% do catálogo", "Faltando para os baralhos" | Out of Scope (Fase 3 / Fase 2) |
| Linha de set: código mono + nome muted com reticências, "N / M" à direita (Mobile:46-49) | Conforme (T15, T16); o percentual vem junto (CNF-26) |
| Barra 8px, trilho sunken, preenchimento border-strong (Mobile:51) | Conforme |
| Legenda base e parallels | CNF-26 (Req. 9.6; o canvas não desenha) |
| Chips "Recentes / Por código" | CNF-29 (o canvas não desenha; seguem o chip do catálogo) |
| Links de export, wishlist e import | Canvas incompleto (NAV-19); em 1280 na coluna de 420px (CNF-30) |
| Duas colunas em 1280, direita 420px (D:53-125) | Conforme; a direita recebe as ações secundárias em vez de "Faltando" (Out of Scope) |
| "Adicionar cartas à pasta" fixo acima da barra (Mobile:115) | Conforme |
| "Adicionar cartas" accent na coluna lateral (D:26-27) | Conforme (T15, T17) |
| Nome cru do set ("EXTRA BOOSTER -Memorial Collection- [EB-01]") | Out of Scope (D12) |

## Riscos residuais registrados

- **Vão acima do h1 do catálogo com flash visível.** A T13 zera as linhas de flash
  vazias da grade do `body`; com um flash na tela, o vão de ~80px volta em 1280px.
  Ocorre só logo depois de uma ação que gera mensagem.
- **"Percentual indisponível" em citação com barra à esquerda** nos sets sem total
  base (`MX…`). Forma herdada da `progresso` (NAV-38); o artboard não tem esse caso.
- **O guarda estático de 360px não vê estouro de grade.** Os dois estouros da T16
  só apareceram medindo `scrollWidth` no navegador. Sem navegador no container,
  essa medição não é gate (AD-015).
