# Especificação — Preços (Fase 3)

Recorte da feature `precos` sobre `.context/requirements.md` Req. 15. Em
divergência, `.context/` vence (AD-005).

## Problem Statement

O Bindr diz o que o usuário tem, mas não quanto isso vale. Hoje, para saber o
valor de uma variante ou da pasta inteira, o colecionador abre um site de
mercado e consulta carta por carta. A fonte do catálogo já entrega o preço
`market` do TCGplayer por produto, que é a nossa `card_variant`, e o app
descarta esse campo no Normalize. Esta feature guarda esse preço a cada import e
o mostra na variante e no valor da pasta.

## Goals

- [ ] Cada variante com preço na fonte mostra, no detalhe da carta, o valor em USD e a data do preço.
- [ ] A pasta mostra o valor estimado da coleção do usuário e o subtotal de cada set.
- [ ] Rodar o import duas vezes com o mesmo snapshot dá os mesmos preços e não toca na coleção.

## Out of Scope

| Feature | Reason |
|---|---|
| Conversão para BRL | Decisão do dono em 2026-10-05: USD por ora. A moeda fica explícita no dado (PRC-01, PRC-05), então BRL entra depois sem migrar o que já existe. Exige fonte de câmbio, que é integração nova. |
| Histórico de preço, gráfico de variação | Decisão do dono em 2026-10-05: só o preço atual. Os snapshots brutos ficam em `storage/ingestion/`, mas são descartáveis e ignorados pelo git. |
| Consultar a apitcg ao abrir a página | Decisão do dono em 2026-10-05: o preço vem do banco. A apitcg só atualiza o preço quando atualiza a carta (`updatedAt` de 2026-08-12 a 2026-10-01 no snapshot de 2026-10-01), então a consulta ao vivo não seria mais fresca. O valor da pasta exigiria uma chamada por variante possuída. |
| Preço do Cardmarket e outras fontes | A apitcg só traz `tcgplayer` em `markets` (7.253 de 7.253 produtos). O canvas desenha uma linha do Cardmarket, mas não há fonte para ela. |
| Preço de wishlist e de deck ("Faltando para os baralhos") | Decisão do dono em 2026-10-05: o MVP é variante + pasta. O deck referencia `cards`, não variantes, e precificá-lo exige escolher uma variante, o que é decisão própria. |
| Ordenar ou filtrar o catálogo por preço, alerta de preço | Não pedido. |
| Preço por impressão (Normal × Foil) do mesmo produto | A variante é o produto do TCGplayer; abrir subvariante por impressão mudaria o modelo da coleção. Só 90 produtos têm mais de uma impressão. |

## Assumptions & Open Questions

| Assumption/decision | Chosen default | Rationale | Confirmed? |
|---|---|---|---|
| Fonte do preço | `markets.tcgplayer.prices.market` da apitcg, lido no Normalize a cada `ingestion:import` | Já vem no payload que o import baixa. Cobertura no snapshot `apitcg-20261001T231649Z.json`: 7.038 de 7.253 produtos com `prices`, 6.903 com `market` (6.815 `Float`, 88 `Integer`, nenhum negativo) | Sim — dono, 2026-10-05 |
| Onde o preço aparece | Detalhe da carta (por variante) e pasta (total e subtotal por set) | Decisão do dono em 2026-10-05. É o que `product.md` §4 promete ("preços e valor estimado da coleção") | Sim — dono, 2026-10-05 |
| Moeda | USD, com a moeda gravada junto do valor | Decisão do dono em 2026-10-05: "USD a princípio, mapear para tratar BRL no futuro" | Sim — dono, 2026-10-05 |
| Persistência | No banco, só o preço atual; cada import sobrescreve | Decisão do dono em 2026-10-05 | Sim — dono, 2026-10-05 |
| Campo de preço | `market`, sem fallback para `mid` | O `mid` é a média dos anúncios, não o preço de venda; usá-lo infla o valor da pasta sem aviso. As 135 variantes com `prices` sem `market` ficam "Sem preço" | Sim — dono, 2026-10-05 |
| Produto com mais de uma impressão | O preço de topo (`prices`), nunca o de `printings` | A variante é o produto. Nos 90 produtos com mais de uma impressão do snapshot, o `prices` de topo é igual ao da impressão indicada em `printing` (90 de 90) | Sim — dono, 2026-10-05 |
| Fonte sem preço num import novo | A variante fica sem preço, mesmo que tivesse um | O catálogo espelha a fonte; um preço antigo mostrado como atual engana mais que "Sem preço" | Sim — dono, 2026-10-05 |
| Variante ausente da fonte | Mantém o último preço e a data dele | A ingestão nunca apaga (Req. 1.7) e a cópia física continua na pasta; a data mostra a idade do preço | Sim — dono, 2026-10-05 |
| Data do preço | A data e hora em que o import começou | É quando o app leu o preço. O `updatedAt` da apitcg é da carta, não do preço, e não há campo de data do preço na fonte. ⚠️ VERIFICAR: a cadência com que a apitcg atualiza `prices` não está documentada; o preço de fato pode ser mais velho que a data exibida | Sim — dono, 2026-10-05 |
| Formato e rótulo | `US$ 1.234,56` e `TCGplayer · market · dd/mm/aaaa` | Formato numérico pt-BR com o símbolo da moeda de origem. Data absoluta em vez do "há 2 h" do canvas, porque o preço pode ter dias de idade | Sim — dono, 2026-10-05 |
| Subtotal por set | Agrupado pelo set da variante (`card_variants.set_id`) | A variante tem set próprio; reimpressão de uma carta em outro set conta no set da impressão. O canvas não desenha subtotal, só o total | Sim — dono, 2026-10-05 |
| Coleção sem cópia com preço | Valor estimado `US$ 0,00` | Mostrar zero é verdade; esconder o bloco faria o usuário procurar o recurso | Sim — dono, 2026-10-05 |

**Open questions:** none — todas as decisões foram tomadas pelo dono em 2026-10-05. O ⚠️ VERIFICAR da data do preço não bloqueia: o rótulo diz quando o app leu o preço, o que é verdadeiro independentemente da cadência da apitcg.

## User Stories

### P1: Preço da variante vindo da ingestão ⭐ MVP

**User Story**: Como dono do catálogo, quero que cada import grave o preço de mercado de cada variante, para que o app tenha preço sem consultar a fonte fora da ingestão.

**Why P1**: Sem o preço no banco, nem o detalhe nem a pasta têm o que mostrar.

**Acceptance Criteria**:
1. WHEN a ingestão processar um produto cujo `markets.tcgplayer.prices.market` seja um número maior ou igual a zero THEN the system SHALL gravar na variante esse valor, a moeda `USD` e a data e hora em que o import começou.
2. IF o produto vier sem `markets.tcgplayer.prices.market` numérico e maior ou igual a zero (ausente, nulo, negativo ou não numérico) THEN the system SHALL deixar a variante sem preço (valor, moeda e data nulos), mesmo que ela tivesse preço antes, sem falhar o registro.
3. The system SHALL ler o preço de `markets.tcgplayer.prices` e nunca de `markets.tcgplayer.printings`, mesmo quando houver mais de uma impressão.
4. WHEN uma variante não vier na fonte num import THEN the system SHALL manter o último preço dela, com a moeda e a data desse preço.
5. The system SHALL garantir no banco que valor, moeda e data do preço sejam todos nulos ou todos preenchidos, e que o valor nunca seja negativo.
6. The system SHALL manter o conhecimento do formato de preço da apitcg só no estágio Normalize.
7. WHEN o mesmo snapshot for importado duas vezes THEN the system SHALL produzir os mesmos valores e moedas de preço depois de cada import e manter intacta a coleção do usuário.

**Independent Test**: Importar a fixture, conferir que a variante `tcgplayer:541058` tem `1.7 USD` com a data do import; reimportar um snapshot em que o mesmo produto perdeu `market` e conferir que a variante ficou sem preço; conferir que uma variante ausente do segundo snapshot manteve o preço.

### P1: Preço no detalhe da carta ⭐ MVP

**User Story**: Como visitante ou colecionador, quero ver o preço de cada variante no detalhe da carta, para saber quanto vale a impressão que tenho ou procuro.

**Why P1**: É onde o usuário já olha a variante; é o primeiro uso do preço gravado.

**Acceptance Criteria**:
8. WHEN alguém abrir o detalhe de uma carta THEN the system SHALL exibir, em cada variante com preço, o valor no formato `US$ 1.234,56` e o rótulo `TCGplayer · market · <dd/mm/aaaa>` com a data do preço.
9. WHEN a variante não tiver preço THEN the system SHALL exibir "Sem preço" no lugar do valor.
10. The system SHALL exibir o preço no detalhe sem exigir sessão, como o resto do catálogo (Req. 6.3).

**Independent Test**: Abrir sem sessão o detalhe de uma carta com uma variante com preço e outra sem; ver `US$ 1,70` com o rótulo e a data na primeira e "Sem preço" na segunda.

### P1: Valor estimado da pasta ⭐ MVP

**User Story**: Como colecionador, quero ver quanto vale a minha pasta e cada set dela, para saber onde está o valor da coleção.

**Why P1**: É o "valor estimado da coleção" que `product.md` §4 promete para a Fase 3.

**Acceptance Criteria**:
11. WHEN o usuário autenticado abrir a pasta THEN the system SHALL exibir o valor estimado da coleção, igual à soma de `quantidade × preço` das variantes possuídas que têm preço, em USD, no formato `US$ 1.234,56`.
12. WHEN houver cópias possuídas de variantes sem preço THEN the system SHALL exibir junto do valor estimado quantas são, no texto "N cópias sem preço".
13. The system SHALL exibir em cada set da pasta o subtotal `quantidade × preço` das variantes possuídas daquele set, agrupando pelo set da variante.
14. The system SHALL calcular o valor da pasta e os subtotais só sobre a coleção do usuário da sessão (Req. 6.5).
15. WHEN o usuário não tiver nenhuma cópia com preço THEN the system SHALL exibir o valor estimado como `US$ 0,00`.
16. The system SHALL obter o valor estimado e os subtotais por set de uma consulta agregada, sem uma consulta por variante ou por set.

**Independent Test**: Com 3 cópias de uma variante de `US$ 1,70` no set A, 1 cópia de `US$ 10,00` no set B e 2 cópias sem preço, a pasta mostra `US$ 15,10`, "2 cópias sem preço", subtotal `US$ 5,10` no set A e `US$ 10,00` no set B; outro usuário com coleção diferente não altera esses números.

## Edge Cases

- IF `market` vier como string, mesmo numérica (ex.: `"1.70"`) THEN the system SHALL tratá-lo como não numérico e deixar a variante sem preço (PRC-02). No snapshot de 2026-10-01 nenhum valor veio como string.
- IF `market` vier `0` THEN the system SHALL gravar `US$ 0,00` como preço válido, distinto de "Sem preço" (o mesmo cuidado do `counter` NULL ≠ 0).
- WHEN a soma da pasta tiver mais de duas casas decimais intermediárias THEN the system SHALL somar os valores exatos e só arredondar o total exibido para duas casas.
- WHEN o preço de uma variante ausente da fonte tiver data antiga THEN the system SHALL exibir essa data, sem esconder nem destacar o preço (PRC-04, PRC-08).
- IF um set da pasta não tiver nenhuma cópia com preço THEN the system SHALL exibir `US$ 0,00` como subtotal desse set.

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
|---|---|---|---|
| PRC-01 | Ingestão: grava valor, `USD` e data (Req. 15.1) | T2, T3 | Implemented |
| PRC-02 | Ingestão: sem `market` válido → sem preço (Req. 15.2) | T2, T3 | Implemented |
| PRC-03 | Ingestão: `prices` de topo, nunca `printings` (Req. 15.3) | T2 | Implemented |
| PRC-04 | Ingestão: ausente da fonte mantém o preço (Req. 15.4) | T3 | Implemented |
| PRC-05 | Ingestão: constraint tudo-ou-nada e não negativo (Req. 15.5) | T1 | Implemented |
| PRC-06 | Ingestão: formato só no Normalize (Req. 15.6) | T2 | Implemented |
| PRC-07 | Ingestão: idempotência com coleção intacta (Req. 15.7) | T3 | Implemented |
| PRC-08 | Detalhe: valor e rótulo com data (Req. 15.8) | T4, T5 | Implemented |
| PRC-09 | Detalhe: "Sem preço" (Req. 15.9) | T5 | Implemented |
| PRC-10 | Detalhe: público (Req. 15.10) | T5 | Implemented |
| PRC-11 | Pasta: valor estimado (Req. 15.11) | T6, T7 | Implemented |
| PRC-12 | Pasta: "N cópias sem preço" (Req. 15.12) | T6, T7 | Implemented |
| PRC-13 | Pasta: subtotal por set da variante (Req. 15.13) | T6, T7 | Implemented |
| PRC-14 | Pasta: só a coleção da sessão (Req. 15.14) | T6, T7 | Implemented |
| PRC-15 | Pasta: `US$ 0,00` sem cópia com preço (Req. 15.15) | T6, T7 | Implemented |
| PRC-16 | Pasta: consulta agregada (Req. 15.16) | T6, T7 | Implemented |

**Coverage:** 16 total, 16 mapped to tasks, 0 unmapped

## Implicit-Requirement Dimensions

| Dimension | Resolution |
|---|---|
| Input validation & bounds | PRC-02 (número ≥ 0, senão sem preço), PRC-05 (constraint no banco), edge case da string |
| Failure / partial-failure states | PRC-02: preço inválido não falha o registro; o resto do pipeline já trata erro por registro em `import_runs.error_log` |
| Idempotency / retry / duplicate handling | PRC-07 |
| Auth boundaries & rate limits | PRC-10 (detalhe público), PRC-14 (pasta só da sessão). Rate limit N/A because não há endpoint novo de escrita |
| Concurrency / ordering | N/A because o preço só é escrito pela ingestão, que já roda um import por vez, e lido pelas páginas |
| Data lifecycle / expiry | PRC-04 (ausente mantém) e PRC-02 (fonte sem preço apaga); sem histórico (Out of Scope) |
| Observability | N/A because o `ImportRun` existente já registra contagens e erros por import; preço inválido não é erro (PRC-02) |
| External-dependency failure | N/A because o preço chega no mesmo fetch do catálogo; a página nunca chama a apitcg (Out of Scope) |
| State-transition integrity | PRC-01/02/04: com preço ↔ sem preço só pela ingestão; PRC-05 impede estado parcial |

## Success Criteria

- [x] Depois de um `ingestion:import` real, toda variante do catálogo cujo produto traz `market` tem preço. *Emendado em 2026-10-05 (T8): o texto anterior pedia "pelo menos 6.900", contados sobre **produtos** com `market` (6.903), o que incluía 237 DON!!, fora do catálogo por P7, e 6 produtos repetidos absorvidos pela SRC-34. Medido no import do snapshot `apitcg-20261001T231649Z.json`: 7.006 variantes presentes, 6.660 com preço, igual ao número de variantes cujo produto tem `market` (100% do elegível).*
- [x] O valor estimado da pasta bate com a soma manual de `quantidade × preço` em um teste com coleção conhecida.
- [x] O gate full continua verde e a pasta não ganha consulta por variante.

## Referências visuais

Canvas "Bindr — telas", artboards versionados em `.specs/features/navegacao/canvas/` (valores ilustrativos):

- `Desktop-Carta.dc.html`: bloco "Cotações" no detalhe com "TCGplayer market price · há 2 h · US$ 4,10". Este spec troca o tempo relativo por data absoluta e não tem a linha do Cardmarket (sem fonte).
- `Desktop-Pasta.dc.html` e `Mobile-Pasta.dc.html`: "Valor estimado" no resumo da pasta, em R$ no canvas. Este spec usa USD, decisão do dono. O subtotal por set não está no canvas e foi aprovado pelo dono em 2026-10-05.
