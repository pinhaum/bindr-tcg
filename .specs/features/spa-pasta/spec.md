# Especificação — Pasta e lista de desejos na SPA

Recorte da feature `spa-pasta` sobre `.context/requirements.md` Req. 20
(SPAS-NN, mesma numeração dos critérios). Em divergência, `.context/` vence
(AD-005). Depende da `api-fundacao` (Req. 16) e da `spa-fundacao` (Req. 17),
encerradas e verificadas, e de duas fatias especificadas e ainda não
implementadas na escrita: a `spa-catalogo` (Req. 18, hoje encerrada), destino do
link de set, e a `spa-carta` (Req. 19, em execução), destino do link de desejo e dona
da chave das rotas de desejo (P9). Escrita em 2026-10-10 sem o dono presente; a de
contrato (P11) foi decidida pelo dono em 2026-10-11 com a opção recomendada
(AD-027), e as demais escolhas do agente foram aprovadas pelo dono em 2026-10-11.

## Problem Statement

A pasta é a tela que responde "quanto falta do set X?" e "quanto vale o que eu
tenho", e na SPA ela ainda não existe: a entrada "Minha pasta" do casco
recarrega a página inteira em `/progress` (SPA-26), e a lista de desejos, cuja
remoção a `spa-carta` deixou para esta fatia, só existe em `/wishlist`. A API
não tem endpoint de progresso nem de leitura ou remoção de desejo. Esta feature
leva a pasta e a lista de desejos para `/app/pasta`, com paridade com as telas
Hotwire, cria os três endpoints que elas precisam e o componente que nasce
nela: o número interpolado dos indicadores.

## Goals

- [ ] `/app/pasta?order=<x>` mostra os mesmos indicadores, a mesma ordem de sets e os mesmos números por set (possuídas, `base_size`, percentual, parallels, subtotal) que `/progress?order=<x>` para o mesmo usuário, verificado por Playwright contra a API real a 360px e a 1280px, nos dois temas, sem scroll horizontal.
- [ ] `/app/pasta/desejos` lista os mesmos itens, na mesma ordem e com o mesmo "Atendido"/"Faltam N" que `/wishlist`, e remover um item pela SPA apaga o mesmo `wishlist_items` que o botão Hotwire apaga.
- [ ] Os indicadores contam de zero ao valor em `--duration-slow` e aparecem direto no valor com `prefers-reduced-motion: reduce`; o leitor de tela nunca lê um valor intermediário.
- [ ] A suíte Rails existente passa sem edição; os três endpoints novos têm request test de sessão, CSRF, isolamento entre usuários e contagem de consultas.

## Out of Scope

| Feature | Reason |
|---|---|
| Bloco "o que falta para os decks" da pasta (Req. 14, DCK-33..35) | Depende do modelo de deck na API, que nasce na `spa-decks` (mesma fronteira que a `spa-carta` usou para o deck em edição). A `spa-decks` acrescenta o bloco à pasta da SPA; até lá ele segue só na `/progress` Hotwire, que continua no ar (AD-023). |
| Telas de import e de export (Req. 10) | Fatia `spa-portabilidade`. A pasta só oferece os links: o export já é um download (`/collection/export`) e o import abre a tela Hotwire. |
| Link do desejo direto na impressão desejada (`/app/cartas/<card_number>?variant=<variant_code>`) | O HTML leva ao detalhe sem `variant`; levar à impressão é melhoria além da paridade, para decisão do dono. |
| Editar o alvo de um desejo na lista | O HTML não oferece; o alvo se edita no detalhe da carta (SCAR-45). |
| Imagem da carta, preço e valor total na lista de desejos | O HTML não exibe; melhoria além da paridade. |
| Omitir "valor US$ 0,00" nos sets sem cópia com preço | Sugestão aberta da revisão de a11y da `precos`; o PRC-13 pede o zero e a paridade o mantém. Decisão do dono. |
| Atualizar a pasta aberta quando a coleção mudar em outra aba | O HTML só muda ao recarregar; aqui a pasta reconsulta ao abrir, ao trocar a ordem e ao "Tentar novamente". |
| Paginação ou recolhimento da lista de sets | O HTML lista todos os sets numa página. |
| Marcar "Minha pasta" como atual em `/app/pasta/desejos` | Em `/wishlist` o HTML não marca nenhuma entrada (`current_page?` exato); melhoria além da paridade. |
| Histórico de preço e moeda BRL | Fora do Req. 15 por decisão do dono (só USD e só o preço atual). |
| Redirecionar `/progress` e `/wishlist` para a SPA, remover as páginas Hotwire | Feature final `spa-troca` (AD-023). |
| Links de outras telas Hotwire para a pasta e para a lista de desejos | Continuam em `/progress` e `/wishlist` até a fatia de cada tela migrar. |
| Limite de taxa na remoção de desejo | Não existe no HTML nem na API (dívida de autenticação registrada no `CLAUDE.md`). |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
|---|---|---|---|
| **P11** — remoção de desejo na API | `DELETE /api/cards/:card_number/variants/:variant_code/wishlist`, o mesmo recurso do `PUT` do SCAR-45, respondendo `200` com `wishlist_target: null` também quando não há desejo (SPAS-43). Alternativa: `DELETE /api/wishlist/:id`, com o id do item no payload e `404` para id inexistente ou alheio, como o HTML | Segue a chave recomendada no P9: a SPA identifica variante por `card_number` + `variant_code` e o payload do Req. 16 não expõe id de banco. Escopar por `Current.user` dá o isolamento por construção, sem precisar do `404` por id alheio. O `200` sem desejo torna a remoção idempotente entre abas, mesmo raciocínio do P10. Contrato público com efeito em dado: fica para o dono, e acompanha a decisão do P9 | Sim — dono, 2026-10-11 (AD-027) |
| Rotas da SPA | `/app/pasta` (com `?order=`) e `/app/pasta/desejos` | Nomes em pt-BR como `/app/entrar` e `/app/cartas`; a lista de desejos sob a pasta porque é dela que se chega a ela (Req. 13.4) | Sim — dono, 2026-10-11 |
| Rotas da API | `GET /api/progress?order=` e `GET /api/wishlist` | Inglês, como `/api/catalog` e `/api/cards`, e o mesmo nome dos recursos HTML (`/progress`, `wishlist_items`) | Sim — dono, 2026-10-11 |
| Formato do payload de progresso | `{ data: { order, summary: { total_copies, distinct_variants, estimated_value, unpriced_copies }, sets: [{ code, name, owned_numbers, base_size, completion_percent, parallel_owned, parallel_total, value }] } }` (SPAS-37..40) | Um `GET` só para a tela inteira, como a página HTML; `order` normalizado na resposta para a SPA marcar o chip sem duplicar a lista fechada de `SetProgressQuery::ORDERS` | Sim — dono, 2026-10-11 |
| Valor agregado no payload | `{ amount, currency }`, sem `observed_at` | A AD-024 define `{ amount, currency, observed_at }` para preço de variante; uma soma de preços com datas diferentes não tem data de observação, e `observed_at: null` seria lido como "sem preço" | Sim — dono, 2026-10-11 |
| Percentual | Calculado e arredondado no servidor (`completion_percent` inteiro, meio para cima como o `number_to_percentage(precision: 0)` do HTML) e `owned_numbers` já limitado ao `base_size` | Um dono para a regra do teto de 100% e do arredondamento (`SetProgressQuery::Row`); a SPA só exibe | Sim — dono, 2026-10-11 |
| `base_size` zero | Sai `null`, igual a ausente | `completion_percent_known?` já trata zero como indisponível; dois valores para o mesmo estado obrigariam a SPA a repetir a regra | Sim — dono, 2026-10-11 |
| Rota protegida com sessão anônima | A SPA leva a `/app/entrar?return_to=...` antes de chamar a API (SPAS-03); um `401` vindo da API segue o SPA-09 | A sessão já está carregada antes da primeira rota (SPA-14); chamar a API só para receber `401` gasta uma ida e pisca a tela | Sim — dono, 2026-10-11 |
| Número interpolado — quais números | Só os três indicadores (cópias, cartas diferentes, valor estimado); as linhas de set exibem o número direto | A tabela da `spa-fundacao` atribui o componente à pasta sem dizer onde; animar dezenas de linhas de set é ruído e custo de render sem informação | Sim — dono, 2026-10-11 |
| Número interpolado — quando | De zero ao valor na primeira exibição da tela; do valor exibido ao novo quando o valor muda com a tela aberta; nada quando a troca de ordem devolve o mesmo valor | A contagem a partir de zero é o efeito pedido; repetir a animação a cada troca de ordem, com o mesmo número, seria movimento sem mudança | Sim — dono, 2026-10-11 |
| Número interpolado — duração e acessibilidade | `--duration-slow` (320 ms) e `--ease-standard`, pela `duration()` de `motion.ts`; valor animado `aria-hidden` e o valor final como texto acessível | SPA-41 e SPA-42; um leitor de tela que leia durante os 320 ms não pode ouvir um número que não é o da coleção. A interpolação muda texto, não propriedade CSS, então não fere a regra de só animar `transform` e `opacity` | Sim — dono, 2026-10-11 |
| Remoção de desejo | Não otimista: o item sai da lista só depois do `200` | Remoção não tem desfazer; tirar o item antes da resposta e devolvê-lo na falha move a lista sob o foco | Sim — dono, 2026-10-11 |
| Foco depois da remoção | "Remover" do item seguinte; sem seguinte, do anterior; lista vazia, o cabeçalho de nível 1 (SPAS-34) | O botão focado deixa de existir; sem destino o foco cai no `<body>`, o mesmo defeito de a11y que o *Handoff* registra no Hotwire depois de `+`/`−` | Sim — dono, 2026-10-11 |
| Remoção pendente | Só o botão do item fica desabilitado; os outros seguem acionáveis | Mesma regra de envio pendente do SPA-21, por item, porque cada remoção é independente | Sim — dono, 2026-10-11 |
| Plural de cópias no desejo | "cópia" com alvo 1, "cópias" nos demais | O HTML escreve "cópia(s)"; a `spa-carta` já trocou por plural certo (SCAR-36) | Sim — dono, 2026-10-11 |
| Carga lenta | Só depois de 200 ms, `aria-busy` e "Carregando pasta…"/"Carregando lista de desejos…"; antes disso a tela mantém o conteúdo anterior | Mesmo limiar do SCAT-38 e do SCAR-07; resposta rápida não pisca | Sim — dono, 2026-10-11 |
| Link do set | `/app?sets[]=<código>`, sem recarga | O mesmo parâmetro do `catalog_path(sets: [code])` do HTML, no formato da URL da SPA (SCAT-05) | Sim — dono, 2026-10-11 (paridade) |
| Link do desejo | `/app/cartas/<card_number>`, sem recarga, sem `variant` | Paridade com o `card_path(card.card_number)` do HTML; exige a `spa-carta` implementada antes desta | Sim — dono, 2026-10-11 (paridade) |
| "Baixar minha coleção (CSV)" | Link de página inteira para `/collection/export`, o endpoint HTML que já devolve o arquivo | O export não é tela, é download com `Content-Disposition`; não precisa de endpoint na API para esta fatia | Sim — dono, 2026-10-11 |
| Desejo de variante ausente da fonte | Listado como qualquer outro | Paridade: a `/wishlist` lista todos os itens sem olhar a presença | Sim — dono, 2026-10-11 (paridade) |
| Foco ao abrir a pasta ou a lista | O de rota nova da `spa-fundacao`: `main#conteudo`; a troca de ordem segue a regra de navegação só de query da `spa-catalogo` | Troca de rota versus troca de query, como nas fatias anteriores | Sim — dono, 2026-10-11 |

**Open questions:** none - all resolved or logged above. P11 decidida com a recomendada (AD-027), junto com o P9 da `spa-carta`.

---

## User Stories

### P1: Pasta em `/app/pasta` ⭐ MVP

**User Story**: Como colecionador, quero abrir a minha pasta pela navegação da SPA, sem recarregar a página, e ser levado a entrar quando não tenho sessão.

**Why P1**: Sem a rota e a carga nenhuma outra parte da pasta aparece.

**Acceptance Criteria**:

1. The system SHALL exibir a pasta em `/app/pasta`, com o título de página "Minha pasta — Bindr" e o cabeçalho de nível 1 "Minha pasta".
2. The system SHALL apontar a entrada "Minha pasta" da navegação para `/app/pasta`, com navegação sem recarga, e marcá-la com `aria-current="page"` em `/app/pasta` com qualquer query, no lugar do destino Hotwire do SPA-26.
3. IF a sessão estiver anônima quando `/app/pasta` ou `/app/pasta/desejos` abrir THEN the system SHALL levar a `/app/entrar?return_to=<caminho e query atuais, codificados>` sem chamar `GET /api/progress` nem `GET /api/wishlist`.
4. WHEN `/app/pasta` abrir ou sua query mudar THEN the system SHALL chamar `GET /api/progress` pelo cliente da `spa-fundacao`, repassando só o parâmetro `order` da URL quando ele existir.
5. IF chegar a resposta de uma URL que já não é a atual THEN the system SHALL descartá-la sem alterar a tela.
6. WHEN uma consulta de `/app/pasta` ou `/app/pasta/desejos` passar de 200 ms sem resposta THEN the system SHALL marcar a região do conteúdo com `aria-busy="true"` e exibir "Carregando pasta…" ou "Carregando lista de desejos…", mantendo até lá o conteúdo anterior.
7. IF a consulta falhar com erro diferente de `401` THEN the system SHALL exibir a `message` do erro como veio e o botão "Tentar novamente", que repete a consulta, e com `401` SHALL seguir o SPA-09.

**Independent Test**: Vitest com cliente falso: sessão anônima navega para `/app/entrar?return_to=%2Fapp%2Fpasta%3Forder%3Dcode` sem chamar o cliente; com sessão, chama `GET /api/progress?order=code`; resposta antiga descartada; texto de carga só depois de 200 ms (relógio falso); erro `500` mostra a mensagem e "Tentar novamente".

---

### P1: Indicadores da pasta ⭐ MVP

**User Story**: Como colecionador, quero ver no topo da pasta quantas cartas tenho, quantas são diferentes e quanto vale a coleção, para ter o resumo num lugar só.

**Why P1**: É o resumo da coleção do Req. 13.4 e o valor da pasta do Req. 15; sem eles a pasta é só uma lista de sets.

**Acceptance Criteria**:

8. The system SHALL exibir três cartões de indicador, nesta ordem: `summary.total_copies` com "carta na pasta" quando 1 e "cartas na pasta" nos demais; `summary.distinct_variants` com "carta diferente" quando 1 e "cartas diferentes" nos demais; e `summary.estimated_value` no formato `US$ 1.234,56` com "valor estimado".
9. WHEN `summary.unpriced_copies` for maior que zero THEN the system SHALL exibir no cartão de valor "1 cópia sem preço" ou "N cópias sem preço", e com zero SHALL omitir a nota.
10. WHEN `summary.estimated_value.amount` for `"0.00"` THEN the system SHALL exibir o valor estimado como `US$ 0,00`.
11. WHILE a viewport tiver 64rem ou mais the system SHALL dar a cada cartão de indicador um quarto da largura da coluna de conteúdo, sem esticar.

**Independent Test**: Vitest renderiza a pasta com `summary` falso: textos e plurais com 0, 1 e 2; nota de cópias sem preço só com `unpriced_copies > 0`; `US$ 0,00` com `"0.00"`; Playwright a 1280px mede a largura de cada cartão igual a um quarto da coluna (tolerância de 1px).

---

### P1: Número interpolado ⭐ MVP

**User Story**: Como colecionador, quero ver os números do resumo contarem até o valor quando abro a pasta, sem que o movimento atrapalhe quem prefere menos animação ou usa leitor de tela.

**Why P1**: A tabela de componentes da `spa-fundacao` atribui o número interpolado a esta fatia; é o que a pasta acrescenta além da paridade, por decisão do dono.

**Acceptance Criteria**:

12. WHEN os indicadores aparecerem pela primeira vez na tela THEN the system SHALL levar cada número de zero ao valor da resposta em `--duration-slow` com a curva `--ease-standard`.
13. WHEN o valor de um indicador mudar com a pasta aberta THEN the system SHALL levar o número do valor exibido ao novo com a mesma duração e curva, e com o mesmo valor SHALL não animar.
14. WHILE `prefers-reduced-motion: reduce` estiver ativo the system SHALL exibir cada indicador direto no valor final, sem valor intermediário.
15. The system SHALL manter os valores intermediários fora da árvore de acessibilidade, com o texto acessível de cada indicador sempre igual ao valor final seguido do rótulo, e SHALL não declarar o indicador como região viva.
16. The system SHALL formatar os valores intermediários como o final (inteiro nas contagens, `US$` com duas casas no valor) com algarismos tabulares, sem deslocar o conteúdo, e SHALL exibir ao fim exatamente a formatação do `amount` da resposta.

**Independent Test**: Vitest com relógio falso: aos 0 ms o texto visível é `0` e o texto acessível já é o final; aos 320 ms o visível é o final; troca de `amount` de `"10.00"` para `"12.50"` anima de `US$ 10,00` a `US$ 12,50`; com `prefersReducedMotion` verdadeiro o primeiro quadro já é o final; `amount` `"1234.56"` termina em `US$ 1.234,56`, nunca `US$ 1.234,55` por erro de ponto flutuante. Playwright: a largura do cartão não muda durante a animação.

---

### P1: Progresso por set ⭐ MVP

**User Story**: Como colecionador, quero ver por set quantas cartas do set base tenho, o percentual, os parallels à parte e quanto vale, e escolher a ordem, para decidir o que caçar.

**Why P1**: É o Req. 9, a razão de existir da pasta.

**Acceptance Criteria**:

17. The system SHALL exibir o título de nível 2 "Progresso por set" com os chips-link "Recentes" (`/app/pasta?order=recent`) e "Por código" (`/app/pasta?order=code`) numa lista com nome acessível "Ordenar sets", navegando sem recarga, e SHALL marcar com `aria-current="page"` o chip igual a `data.order` da resposta, nunca o da query crua.
18. The system SHALL exibir os sets na ordem de `data.sets`, numa lista cujo nome acessível é o título "Progresso por set", sem exibir a contagem total de sets.
19. The system SHALL exibir cada set numa linha sem moldura, com `code` em estilo `code` e `name` como link para `/app?sets[]=<code codificado>` sem recarga, com nome acessível "<name> (<code>): ver no catálogo".
20. WHEN o set tiver `base_size` THEN the system SHALL exibir "<owned_numbers> / <base_size> · <completion_percent>%" na linha do nome, uma barra de progresso `aria-hidden="true"` com `value` igual a `owned_numbers` e `max` igual a `base_size`, e a legenda "<owned_numbers> de <base_size> do set base".
21. WHEN o set tiver `base_size` nulo THEN the system SHALL exibir só `owned_numbers`, sem barra nem percentual, com a legenda "Percentual indisponível: este set não informa o tamanho do set base.", e SHALL nunca exibir "0%" nem "100%" nesse set.
22. The system SHALL exibir na legenda "<parallel_owned> de <parallel_total> parallel" quando `parallel_total` for 1 e "parallels" nos demais, num elemento irmão do percentual e nunca dentro dele.
23. The system SHALL exibir em cada set "valor" seguido de `value` no formato `US$ 1.234,56`, inclusive `US$ 0,00`.

**Independent Test**: Vitest com `sets` falso: set com `base_size` (texto, barra, legenda), set sem `base_size` (sem barra nem `%`), parallels com total 1 e 2, subtotal zero, chip marcado por `data.order = "recent"` com a URL em `?order=xyz`; Playwright compara, para o mesmo usuário, a sequência de `code` e os números de cada linha de `/app/pasta?order=code` com `/progress?order=code`.

---

### P1: Ações da pasta ⭐ MVP

**User Story**: Como colecionador, quero sair da pasta para adicionar cartas, ver a lista de desejos, importar ou baixar a coleção, com a mesma disposição das telas atuais.

**Why P1**: Sem as ações a pasta vira beco: o Req. 13.4 e o 13.14 as exigem.

**Acceptance Criteria**:

24. The system SHALL oferecer "Adicionar cartas à pasta", que leva a `/app` sem recarga, fixa acima da barra inferior sem cobrir o fim da lista abaixo de 64rem, e na coluna lateral, abaixo de um divisor, com o texto "Adicionar cartas", a partir de 64rem.
25. The system SHALL oferecer, num grupo de ações secundárias separado de "Adicionar cartas", os links "Baixar minha coleção (CSV)" para `/collection/export` com página inteira, "Lista de desejos" para `/app/pasta/desejos` sem recarga e "Importar coleção" para `/collection/import` com página inteira.
26. WHEN a pasta for exibida a 390px e a 1280px THEN the system SHALL ter a composição da página `/progress` do Hotwire, que segue os artboards "Mobile-Pasta" e "Desktop-Pasta" de `.specs/features/navegacao/canvas/`, sem scroll horizontal a 360px (SPA-30).

**Independent Test**: Vitest: `href` e modo de navegação de cada link; Playwright a 390px: a ação fica acima da barra inferior e o último set rola até ficar visível acima dela; a 1280px: a ação está na coluna lateral, abaixo do divisor, com o texto "Adicionar cartas"; capturas a 390px e 1280px comparadas com as da `/progress`.

---

### P1: Lista de desejos ⭐ MVP

**User Story**: Como colecionador, quero ver o que desejo, quanto já tenho de cada um e remover o que não quero mais, para levar a lista a trocas e compras.

**Why P1**: A `spa-carta` deixou a lista e a remoção de desejo para esta fatia (Req. 8.2–8.4); sem ela a SPA marca desejos que não consegue mostrar.

**Acceptance Criteria**:

27. The system SHALL exibir a lista de desejos em `/app/pasta/desejos`, com o título de página "Lista de desejos — Bindr" e o cabeçalho de nível 1 "Lista de desejos", e SHALL chamar `GET /api/wishlist` ao abrir a rota.
28. WHEN `data` vier vazio THEN the system SHALL exibir "Você ainda não marcou nenhuma carta como desejada." e "Abra o detalhe de uma carta no catálogo e escolha a impressão que quer adquirir.", com "catálogo" como link para `/app` sem recarga.
29. WHEN `data` tiver itens THEN the system SHALL exibir "1 item" ou "N itens" e uma lista com os itens na ordem de `data`.
30. The system SHALL exibir em cada item `card_name` e `variant_code` (este em estilo `code`) como um link para `/app/cartas/<card_number codificado>` sem recarga, e "<owned_quantity> de <target_quantity> cópia" quando `target_quantity` for 1 e "cópias" nos demais.
31. WHEN `fulfilled` for verdadeiro THEN the system SHALL exibir o rótulo escrito "Atendido", e com `fulfilled` falso SHALL exibir "Faltam N", com N igual a `target_quantity − owned_quantity`.
32. The system SHALL dar a cada item o botão "Remover", com alvo de no mínimo 44px e nome acessível "Remover <card_name> <variant_code> da lista de desejos (atendido)" ou "(faltam N)".
33. WHEN o usuário acionar "Remover" THEN the system SHALL chamar a remoção de desejo da API (SPAS-43) e, com `200`, SHALL tirar o item da lista, atualizar a contagem e anunciar "Item removido da lista de desejos." como mensagem de sucesso (SPA-44).
34. WHEN um item for removido THEN the system SHALL mover o foco para o "Remover" do item seguinte; sem seguinte, para o do anterior; com a lista vazia, para o cabeçalho "Lista de desejos".
35. WHILE a remoção de um item estiver pendente the system SHALL manter o botão daquele item desabilitado e ignorar novo acionamento dele, mantendo os demais itens acionáveis.
36. IF a remoção falhar THEN the system SHALL manter o item na lista e exibir a `message` do erro como veio numa mensagem de erro (SPA-45), e com `401` ou sessão trocada SHALL seguir o SPA-09 e o SPA-10.

**Independent Test**: Vitest com cliente falso: lista vazia (textos e link), "1 item"/"2 itens", plural pelo alvo, "Atendido" com 3 de 2, "Faltam 2" com 0 de 2, nome acessível do botão; remoção com `200` tira o item, atualiza a contagem e foca o seguinte, o anterior ou o cabeçalho; segundo clique durante a pendência não chama o cliente; `500` mantém o item e mostra a mensagem. Playwright contra a API real: o item removido some de `/wishlist`.

---

### P1: API da pasta e da lista de desejos ⭐ MVP

**User Story**: Como SPA do Bindr, quero ler o progresso, o valor e a lista de desejos do usuário da sessão e remover um desejo em JSON, com os mesmos números das telas HTML.

**Why P1**: A fatia vertical não mostra nada sem estes endpoints; nenhum existe sob `/api`.

**Acceptance Criteria**:

37. WHEN `GET /api/progress` chegar com sessão THEN the system SHALL responder `200` com `{ "data": { "order", "summary", "sets" } }` calculado sobre a coleção do usuário da sessão.
38. IF o parâmetro `order` faltar, for desconhecido, vazio ou vier em lista (`order[]=code`) THEN the system SHALL usar `recent`, devolver `order: "recent"` e responder `200`; com `code` SHALL devolver `order: "code"`.
39. The system SHALL devolver em `summary` os campos `total_copies`, `distinct_variants`, `estimated_value` (`{ "amount", "currency" }`, `amount` em string decimal de duas casas e `currency` `"USD"`) e `unpriced_copies`, iguais aos números da pasta Hotwire para o mesmo usuário (`CollectionItem.collection_stats_for`).
40. The system SHALL devolver em cada item de `sets` os campos `code`, `name`, `owned_numbers` (o `displayed_owned_numbers`, limitado ao `base_size` quando ele existe), `base_size` (`null` quando ausente ou zero), `completion_percent` (inteiro arredondado meio para cima, no máximo 100, `null` sem `base_size`), `parallel_owned`, `parallel_total` e `value` (`{ "amount", "currency" }`, `"0.00"` sem cópia com preço), iguais aos da linha da pasta Hotwire.
41. The system SHALL montar `summary` e `sets` com um número de consultas SQL que não cresce com a quantidade de sets, de variantes ou de itens de coleção do usuário.
42. WHEN `GET /api/wishlist` chegar com sessão THEN the system SHALL responder `200` com os desejos do usuário da sessão em `data[]`, cada um com `card_number`, `card_name`, `variant_code`, `target_quantity`, `owned_quantity` (`0` sem posse) e `fulfilled` (`owned_quantity >= target_quantity`), ordenados por criação e id crescentes, com um número de consultas que não cresce com a lista.
43. WHEN `DELETE /api/cards/:card_number/variants/:variant_code/wishlist` chegar com sessão e CSRF válidos THEN the system SHALL apagar o desejo do usuário da sessão naquela variante e responder `200` com `{ "data": { "variant_code", "wishlist_target": null } }`, e sem desejo SHALL responder o mesmo `200` sem apagar nada (P11, AD-027).
44. IF a carta não existir ou o `variant_code` não for de uma variante dela THEN the system SHALL responder `404` `not_found` à remoção, sem apagar.
45. IF um dos três endpoints for chamado sem sessão, ou a remoção sem `X-CSRF-Token` válido, THEN the system SHALL responder `401 unauthenticated` ou `422 invalid_csrf_token` sem ler nem apagar, e com sessão SHALL ler e apagar só registros de `Current.user`, ignorando qualquer `user_id` no corpo ou na query (Req. 6.5, API-08, API-10).
46. The system SHALL manter inalterados os controllers e as rotas HTML: a suíte existente passa sem edição (API-17).

**Independent Test**: request tests Rails: `GET /api/progress` com os mesmos números que `SetProgressQuery` e `collection_stats_for` para dois usuários com coleções diferentes; cada valor de `order` do SPAS-38; set sem `base_size` e set com posse acima do `base_size`; contagem de consultas igual com 2 e com 20 sets; `GET /api/wishlist` com atendido e não atendido e contagem de consultas igual com 1 e com 10 itens; `DELETE` apaga só o desejo do usuário da sessão, `200` sem desejo, `404` para carta inexistente e para variante de outra carta, `401` sem sessão, `422` sem token com `allow_forgery_protection` ligado, `user_id` alheio ignorado.

---

## Edge Cases

- WHEN a coleção do usuário estiver vazia THEN the system SHALL exibir `0`, `0` e `US$ 0,00` nos indicadores, sem animação (de zero a zero), e os sets na ordem por código (Req. 9.7).
- WHEN o usuário possuir mais números do set base do que o `base_size` THEN the system SHALL exibir `owned_numbers` igual ao `base_size` e `100%`, nunca acima (Req. 9.5).
- WHEN o `base_size` vier zero do banco THEN the system SHALL tratá-lo como ausente (`null` na API, SPAS-21 na tela).
- IF o `code` do set tiver caractere reservado de URL THEN the system SHALL codificá-lo no link `/app?sets[]=` (SPAS-19).
- IF o `variant_code` tiver `:` (`tcgplayer:12345`) ou o `card_number` caractere reservado THEN the system SHALL codificá-los no caminho do `DELETE` e no link do desejo, e a API SHALL decodificá-los antes da busca.
- WHEN o desejo já tiver sido removido em outra aba THEN the system SHALL receber `200` da remoção (SPAS-43) e tirar o item da lista como num sucesso comum.
- WHEN a posse de uma variante desejada passar do alvo THEN the system SHALL exibir "Atendido" (Req. 8.3: "atingir ou exceder").
- WHEN um desejo for de variante ausente da fonte THEN the system SHALL listá-lo como os demais.
- WHEN o usuário acionar "Remover" em dois itens diferentes em seguida THEN the system SHALL processar as duas remoções e aplicar a regra de foco do SPAS-34 sobre a lista do momento em que cada uma termina.
- WHEN a ordem mudar com a interpolação em curso THEN the system SHALL não reiniciar a animação se os valores do `summary` forem os mesmos (SPAS-13).
- WHEN o usuário sair pelo casco com a pasta ou a lista aberta THEN the system SHALL seguir o SPA-22 (leva a `/app`), sem exibir dado da coleção na tela anônima.
- WHEN a sessão expirar com a lista de desejos aberta e o usuário acionar "Remover" THEN the system SHALL receber `401` e seguir o SPA-09, com `return_to` igual a `/app/pasta/desejos`.
- IF existir preço em moeda diferente de `USD` THEN the system SHALL deixá-lo fora de `estimated_value` e de `value`, como a consulta do HTML faz (só USD, Req. 15).
- WHEN a pasta tiver dezenas de sets (85 no catálogo atual) THEN the system SHALL exibir todos sem scroll horizontal a 360px, sem repetir o estouro de 408px da `/progress` a 390px registrado no *Handoff* (SPA-30).
- IF o corpo do `DELETE` vier com JSON malformado THEN the system SHALL responder `400 invalid_json` (caso de borda do Req. 16).

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
|---|---|---|---|
| SPAS-01 | P1: Pasta — rota e título (Req. 20.1) | T13, T15 | Implemented |
| SPAS-02 | P1: Pasta — entrada da navegação (Req. 20.2) | T8, T15 | Implemented |
| SPAS-03 | P1: Pasta — sessão anônima (Req. 20.3) | T5, T13, T14, T15 | Implemented |
| SPAS-04 | P1: Pasta — consulta do progresso (Req. 20.4) | T4, T13 | Implemented |
| SPAS-05 | P1: Pasta — resposta antiga descartada (Req. 20.5) | T4, T13 | Implemented |
| SPAS-06 | P1: Pasta — carga lenta (Req. 20.6) | T4, T13, T14 | Implemented |
| SPAS-07 | P1: Pasta — erro de carga (Req. 20.7) | T4, T13, T14 | Implemented |
| SPAS-08 | P1: Indicadores — três cartões (Req. 20.8) | T10 | Implemented |
| SPAS-09 | P1: Indicadores — cópias sem preço (Req. 20.9) | T10 | Implemented |
| SPAS-10 | P1: Indicadores — valor zero (Req. 20.10) | T10 | Implemented |
| SPAS-11 | P1: Indicadores — largura em 64rem (Req. 20.11) | T10, T15 | Implemented |
| SPAS-12 | P1: Número interpolado — primeira exibição (Req. 20.12) | T6, T9, T15 | Implemented |
| SPAS-13 | P1: Número interpolado — mudança de valor (Req. 20.13) | T9 | Implemented |
| SPAS-14 | P1: Número interpolado — reduced motion (Req. 20.14) | T9, T15 | Implemented |
| SPAS-15 | P1: Número interpolado — acessibilidade (Req. 20.15) | T9, T10 | Implemented |
| SPAS-16 | P1: Número interpolado — formato e estabilidade (Req. 20.16) | T9, T15 | Implemented |
| SPAS-17 | P1: Progresso — chips de ordem (Req. 20.17) | T13, T15 | Implemented |
| SPAS-18 | P1: Progresso — lista de sets (Req. 20.18) | T13, T15 | Implemented |
| SPAS-19 | P1: Progresso — linha e link do set (Req. 20.19) | T11 | Implemented |
| SPAS-20 | P1: Progresso — set com `base_size` (Req. 20.20) | T11 | Implemented |
| SPAS-21 | P1: Progresso — set sem `base_size` (Req. 20.21) | T11 | Implemented |
| SPAS-22 | P1: Progresso — parallels à parte (Req. 20.22) | T11 | Implemented |
| SPAS-23 | P1: Progresso — subtotal do set (Req. 20.23) | T11 | Implemented |
| SPAS-24 | P1: Ações — adicionar cartas (Req. 20.24) | T13, T15 | Implemented |
| SPAS-25 | P1: Ações — ações secundárias (Req. 20.25) | T13 | Implemented |
| SPAS-26 | P1: Ações — composição dos artboards (Req. 20.26) | T15 | Implemented |
| SPAS-27 | P1: Desejos — rota e título (Req. 20.27) | T14, T16 | Implemented |
| SPAS-28 | P1: Desejos — lista vazia (Req. 20.28) | T14 | Implemented |
| SPAS-29 | P1: Desejos — contagem e ordem (Req. 20.29) | T14, T16 | Implemented |
| SPAS-30 | P1: Desejos — linha do item (Req. 20.30) | T7, T12, T16 | Implemented |
| SPAS-31 | P1: Desejos — atendido (Req. 20.31) | T12, T16 | Implemented |
| SPAS-32 | P1: Desejos — botão remover (Req. 20.32) | T12 | Implemented |
| SPAS-33 | P1: Desejos — remoção com sucesso (Req. 20.33) | T14, T16 | Implemented |
| SPAS-34 | P1: Desejos — foco após remoção (Req. 20.34) | T14, T16 | Implemented |
| SPAS-35 | P1: Desejos — remoção pendente (Req. 20.35) | T12, T14 | Implemented |
| SPAS-36 | P1: Desejos — falha na remoção (Req. 20.36) | T14 | Implemented |
| SPAS-37 | P1: API — progresso (Req. 20.37) | T1 | Implemented |
| SPAS-38 | P1: API — ordem (Req. 20.38) | T1 | Implemented |
| SPAS-39 | P1: API — resumo e valor (Req. 20.39) | T1 | Implemented |
| SPAS-40 | P1: API — linha do set (Req. 20.40) | T1 | Implemented |
| SPAS-41 | P1: API — consultas constantes no progresso (Req. 20.41) | T1 | Implemented |
| SPAS-42 | P1: API — lista de desejos (Req. 20.42) | T2 | Implemented |
| SPAS-43 | P1: API — remoção de desejo (Req. 20.43) | T3, T7, T16 | Implemented |
| SPAS-44 | P1: API — carta ou variante inexistente (Req. 20.44) | T3 | Implemented |
| SPAS-45 | P1: API — sessão, CSRF e isolamento (Req. 20.45) | T1, T2, T3 | Implemented |
| SPAS-46 | P1: API — HTML inalterado (Req. 20.46) | T3, T17 | Implemented |

**Coverage:** 46 total, 46 mapped to tasks (T1–T17), 0 unmapped

---

## Success Criteria

- [ ] Para dois usuários com coleções diferentes, `/app/pasta?order=recent`, `/app/pasta?order=code` e `/app/pasta/desejos` mostram os mesmos números, na mesma ordem, que `/progress` e `/wishlist`, em Playwright contra a API real, a 360px e a 1280px, nos dois temas, sem scroll horizontal.
- [ ] Remover um desejo pela SPA apaga o registro de `wishlist_items` do usuário da sessão e nenhum outro, e o foco nunca termina no `<body>`.
- [ ] Com `prefers-reduced-motion: reduce`, nenhum indicador exibe valor intermediário; sem ela, cada indicador chega ao valor final em 320 ms.
- [ ] `GET /api/progress` executa o mesmo número de consultas SQL com 2 e com todos os sets do catálogo.
- [ ] A suíte Rails existente passa sem edição e nenhum controller ou view HTML muda nesta feature.
