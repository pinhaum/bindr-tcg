# Especificação — Detalhe da carta na SPA

Recorte da feature `spa-carta` sobre `.context/requirements.md` Req. 19
(SCAR-NN, mesma numeração dos critérios). Em divergência, `.context/` vence
(AD-005). Depende da `api-fundacao` (Req. 16) e da `spa-fundacao` (Req. 17),
encerradas e verificadas, e da `spa-catalogo` (Req. 18), especificada e ainda
não implementada: o tile, o placeholder e o skeleton nascem lá e aqui são
reusados. Escrita em 2026-10-10 sem o dono presente; as escolhas dele estão
marcadas `Confirmed? não` abaixo; as duas de contrato (P9 e P10) foram
decididas pelo dono em 2026-10-11 com as opções recomendadas (AD-027).

## Problem Statement

Com a `spa-catalogo`, a grade migra para `/app`, mas o tile ainda leva ao
detalhe Hotwire com recarga de página inteira (SCAT-03), e é no detalhe que o
colecionador faz o que o produto existe para fazer: registrar quantas cópias
tem de cada impressão (Req. 7) e marcar o que quer (Req. 8). A API não tem
endpoint de escrita de coleção nem de wishlist: sem eles, nenhuma tela da SPA
grava dado do usuário. Esta feature leva o detalhe para `/app/cartas/:card_number`,
com paridade com a tela Hotwire, cria os três endpoints de escrita que ela
precisa e os dois componentes que nascem nela: o stepper `−`/`+` com
atualização otimista e o morph grade → detalhe.

## Goals

- [ ] `/app/cartas/<card_number>?variant=<código>` mostra os mesmos campos, variantes, preços e variante em destaque que `/cards/<card_number>?variant=<código>`, verificado por Playwright contra a API real, a 360px e a 1280px, nos dois temas, sem scroll horizontal.
- [ ] Com sessão, cinco toques rápidos em `+` deixam a coleção do usuário com exatamente +5 cópias da variante, e o número na tela muda a cada toque antes da resposta.
- [ ] Marcar e atualizar um desejo pela SPA grava o mesmo `wishlist_items` que o formulário Hotwire grava.
- [ ] A suíte Rails existente passa sem edição; os três endpoints novos têm request test de sessão, CSRF, isolamento entre usuários e concorrência.

## Out of Scope

| Feature | Reason |
|---|---|
| Controle do deck em edição no detalhe (DCK-03..05: `−`/`+` no deck, "Usar como Leader") | O estado de deck em edição nasce na `spa-decks` (tabela da `spa-fundacao`); os endpoints de `deck_entries` e de escolha do deck são dela. Até lá, quem monta deck usa o fluxo Hotwire, que continua no ar (AD-023). |
| Lista de desejos, remoção de desejo e "atendido" (Req. 8.2–8.4) | O detalhe HTML só marca e atualiza (`wishlist_items/_mark`); listar e remover são da página `/wishlist`, que migra com a fatia da pasta. |
| Endpoint `DELETE` de desejo e de "definir quantidade" (Req. 7.1 por valor) | O detalhe HTML não oferece nenhum dos dois: posse é só `−`/`+` (Req. 7.2). |
| "Voltar ao catálogo" que restaura os filtros da grade de origem | O HTML leva a `/catalog` sem query; o voltar do navegador já restaura a grade. Melhoria além da paridade, para decisão do dono. |
| Pré-carregamento do detalhe ao passar o mouse no tile | Otimização sem requisito. |
| Mensagem de sucesso (toast) a cada toque de posse | O HTML com Turbo atualiza o número e o flash a cada clique; aqui o anúncio fica na região viva do controle (SCAR-33). Ver *Assumptions*. |
| Redirecionar `/cards/:id` para `/app/cartas/:id`, remover o detalhe Hotwire | Feature final `spa-troca` (AD-023). |
| Links de outras telas Hotwire para o detalhe (deck, pasta, wishlist) | Continuam em `/cards/:id` até a fatia de cada tela migrar. |
| Limite de tentativas ou de taxa nas mutações | Não existe no HTML nem na API (dívida de autenticação registrada no `CLAUDE.md`). |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
|---|---|---|---|
| **P9** — chave das rotas de escrita | `card_number` + `variant_code` no caminho: `POST /api/cards/:card_number/variants/:variant_code/increment` e `/decrement`, `PUT …/wishlist` (SCAR-42..47). Alternativa: expor o `id` da variante no payload e usar `card_variant_id`, como as rotas HTML | O payload do Req. 16 não expõe id de banco e a SPA só conhece `card_number` e `variant_code`; o índice único é `(card_id, variant_code)`, então `variant_code` sozinho não identifica a variante. Contrato público com efeito em dado: fica para o dono | Sim — dono, 2026-10-11 (AD-027) |
| **P10** — decremento em zero | `200` com `owned_quantity: 0`, sem criar registro (SCAR-43). Alternativa: `422` com "Você não tem cópias desta variante para remover.", como o alerta do HTML | Com atualização otimista, outra aba pode zerar a posse entre o toque e a resposta; o `200` deixa a reconciliação do SCAR-31 sem caso especial e o decremento idempotente no piso. A SPA não envia decremento com zero na tela (SCAR-29), então o caso só ocorre por corrida | Sim — dono, 2026-10-11 (AD-027) |
| Deck em edição | Fora desta fatia, para a `spa-decks` | A `spa-fundacao` atribuiu o estado de deck em edição à `spa-decks`; trazê-lo aqui exigiria endpoints de deck e de seleção de deck antes da tela de decks existir. Lacuna de paridade aceita durante a transição: o detalhe Hotwire segue com o controle | Não — escolha do agente |
| Rota | `/app/cartas/<card_number>`, `card_number` codificado, `?variant=<variant_code>` como no HTML | Nomes de rota em pt-BR como `/app/entrar`; o parâmetro `variant` igual ao do Req. 13.40 deixa a query trocável entre `/cards/X` e `/app/cartas/X` | Não — escolha do agente |
| Emenda do Req. 18.3 | O tile passa a levar ao detalhe da SPA (SCAR-03); o Req. 18 continua dizendo "até o detalhe migrar" e o SCAT-03 precisa ser emendado pelo dono da `spa-catalogo` | Esta feature só pode editar o Req. 19 e o próprio spec; a `spa-catalogo` ainda não foi implementada, então a emenda não mexe em código | Não — escolha do agente |
| Troca de variante | Local, sem nova consulta: a regra de destaque do CNF-42 (SCAR-24) roda sobre as variantes já carregadas, e a URL muda com `replaceState` | Refazer o `GET` apagaria operações de posse pendentes e piscaria a tela; a API já entrega tudo o que a troca precisa | Não — escolha do agente |
| Valor otimista | Toque muda o número na hora; operações da mesma variante vão em série, na ordem dos toques; ao fim, vale o `owned_quantity` da última resposta; em falha, descarta o que não foi enviado e volta à última quantidade confirmada (SCAR-27..32) | Decisão do dono (stepper com atualização otimista, tabela da `spa-fundacao`). Em série porque respostas paralelas chegam fora de ordem e a última a chegar não seria a última aplicada | Não — escolha do agente (o otimista é do dono; a série e a regra de falha são do agente) |
| `−` em zero | `aria-disabled="true"`, focável, não envia, anuncia "Você não tem cópias desta variante para remover." na região viva do controle | Paridade com o HTML (mesmo texto e mesmo `aria-disabled`, achado HIGH de a11y da `colecao`); sem envio porque a tela já sabe o resultado | Não — escolha do agente |
| Anúncio da posse | Só quando a última operação pendente termina com sucesso, com nome da carta e código (SCAR-33); sem toast de sucesso por toque | Cinco toques rápidos anunciariam cinco números; o HTML também anuncia pela região viva do controle. O flash "Você tem N cópia(s)…" do HTML vira só o anúncio | Não — escolha do agente |
| Erro de posse | Toast de erro com a `message` como veio; `401` e `session_changed` seguem o cliente da fundação (SPA-09, SPA-10) e também voltam o valor | A mensagem é evento da ação, não estado da tela; o cliente já trata sessão | Não — escolha do agente |
| Selo da imagem principal | Segue o valor exibido do controle da variante em destaque, inclusive o otimista (SCAR-15) | No HTML o selo só muda na recarga; na SPA o mesmo número em dois lugares discordando seria defeito novo | Não — escolha do agente |
| Texto do aviso de desejo | "<nome> <variant_code> na lista de desejos: 1 cópia." ou "N cópias." (SCAR-36) | O HTML escreve "cópia(s)"; plural certo custa nada | Não — escolha do agente |
| Mensagem de alvo inválido | `fields.target_quantity = ["Informe um número inteiro maior ou igual a 1."]`, `message` "Dados inválidos." como o cadastro | O HTML usa a mensagem em inglês do model ("Target quantity must be…"); a API do Req. 16 exige pt-BR | Não — escolha do agente |
| Validação do alvo no cliente | Só `type="number"`, `min="1"`, `step="1"` nativos; a regra é da API (SCAR-46) | Mesma decisão da `spa-fundacao`: um dono por regra | Não — escolha do agente |
| Trigger sem efeito | A seção "Efeito" aparece quando há efeito **ou** trigger (SCAR-18) | No HTML um trigger sem efeito some, o que contraria o Req. 5.4; é defeito, não comportamento | Não — escolha do agente |
| Carta sem variante | Cabeçalho com nome e `card_number`, campos e efeito; sem imagem e sem a seção "Variantes na pasta" | O HTML renderiza o título da seção com a lista vazia; uma seção sem conteúdo não informa nada | Não — escolha do agente |
| Variante ausente da fonte na escrita | Os endpoints aceitam qualquer variante da carta, presente ou ausente | Paridade: o HTML acha a variante por id sem olhar a presença; a ausente só aparece na tela para quem a tem (SRC-17) | Não — escolha do agente, paridade |
| Carga lenta | Só depois de 200 ms, `aria-busy` e "Carregando carta…"; antes disso a tela mantém o conteúdo anterior | Mesmo limiar do SCAT-38; resposta rápida não pisca | Não — escolha do agente |
| Morph | `view-transition-name` só na arte do tile da carta navegada e na imagem principal **visível** do detalhe (miniatura abaixo de 64rem, coluna a partir dele), dentro da transição de rota que a `spa-fundacao` já faz (SCAR-39..41) | Dois elementos com o mesmo nome no mesmo documento anulam a transição; o detalhe tem duas cópias da imagem no DOM abaixo de 64rem | Não — escolha do agente |
| Foco ao abrir o detalhe | O de rota nova da `spa-fundacao`: `main#conteudo` | Troca de rota, não de query | Não — escolha do agente |

**Open questions:** none - all resolved or logged above. P9 e P10 decididas com as recomendadas (AD-027).

---

## User Stories

### P1: Detalhe em `/app/cartas` ⭐ MVP

**User Story**: Como colecionador, quero abrir uma carta pela grade da SPA ou por um link compartilhado, sem recarregar a página, e voltar ao catálogo.

**Why P1**: Sem a rota não há tela; é o destino do tile.

**Acceptance Criteria**:

1. WHEN o usuário abrir `/app/cartas/<card_number>` THEN the system SHALL exibir o detalhe com o título de página "<nome> (<card_number>) — Bindr" e o nome da carta como cabeçalho de nível 1.
2. WHEN a rota abrir ou o `card_number` da URL mudar THEN the system SHALL chamar `GET /api/cards/:card_number` pelo cliente da `spa-fundacao`, com o `card_number` codificado para URL e o `variant` da URL repassado sem alteração.
3. WHEN o usuário acionar um tile do catálogo THEN the system SHALL navegar para `/app/cartas/<card_number>` sem recarregar a página, no lugar do destino Hotwire do SCAT-03.
4. The system SHALL exibir "Voltar ao catálogo" como botão bordado de no mínimo 44px, sem seta, que leva a `/app` sem recarregar a página, na coluna lateral abaixo de um divisor a partir de 64rem (Req. 13.34).
5. IF a API responder `404 not_found` THEN the system SHALL exibir no lugar do detalhe a `message` da API e "Voltar ao catálogo", com o título de página "Carta não encontrada — Bindr".
6. IF `GET /api/cards/:card_number` falhar com qualquer outro erro do cliente THEN the system SHALL exibir a `message` do erro e o botão "Tentar novamente", que repete a consulta.
7. WHILE a consulta da carta da URL estiver pendente há mais de 200 ms the system SHALL marcar o detalhe com `aria-busy="true"` e anunciar "Carregando carta…"; antes dos 200 ms SHALL manter o conteúdo anterior.
8. IF chegar a resposta de uma carta que já não é a da URL atual THEN the system SHALL descartá-la sem alterar a tela.
9. WHEN o estado de sessão mudar (entrar, sair, `401`) com o detalhe aberto THEN the system SHALL repetir `GET /api/cards/:card_number` da carta atual.

**Independent Test**: Vitest da rota com cliente falso (codificação do `card_number`, `variant` repassado, resposta antiga descartada, refetch na troca de sessão, 404 e erro de rede); Playwright: tile → detalhe sem recarga e "Voltar ao catálogo" → `/app`.

---

### P1: Cabeçalho e dados da carta ⭐ MVP

**User Story**: Como colecionador, quero ver a arte em tamanho maior e todos os campos que se aplicam à carta, com o efeito legível.

**Why P1**: Req. 5.1, 5.4 e 5.5; é o conteúdo da tela.

**Acceptance Criteria**:

10. The system SHALL exibir como imagem principal a da variante em destaque, com texto alternativo "<nome> <variant_code>", e atrás dela um placeholder com nome e `card_number`, visível quando `image_url` é `null` ou a imagem falha, sem mudar a largura nem a altura do quadro.
11. WHILE a viewport tiver menos de 64rem the system SHALL exibir a miniatura da arte ao lado do título e a imagem maior num `<details>` com o resumo "Ver imagem maior", fechado por padrão (Req. 13.30).
12. WHILE a viewport tiver 64rem ou mais the system SHALL exibir a imagem maior numa coluna própria ao lado dos dados, sempre visível (Req. 13.6, 13.19).
13. The system SHALL exibir no cabeçalho uma lista de chips com o tipo com inicial maiúscula, a raridade da variante em destaque quando existe, uma entrada por cor e, a partir de 64rem, "Counter N" quando o counter se aplica ao tipo e não é `null`, seguida da linha "<nome do set> · <código do set>" da variante em destaque (Req. 13.31).
14. WHEN a variante em destaque tiver `in_source: false` THEN the system SHALL exibir no cabeçalho "Variante fora da fonte".
15. WHILE houver sessão e o valor exibido da posse da variante em destaque for maior que zero the system SHALL exibir sobre a imagem principal um selo com esse valor, com `role="img"` e nome acessível "1 cópia" ou "N cópias" (Req. 13.35).
16. WHEN a variante em destaque tiver `illustrator` THEN the system SHALL exibir "Ilustração: <illustrator>" (Req. 13.35).
17. The system SHALL exibir Custo, Power, Life, Attribute, Traits e Block só quando o campo se aplica ao tipo e tem valor (não `null`, lista não vazia), pela tabela leader = power, life, attribute, traits, block; character = cost, power, counter, attribute, traits, block; event e stage = cost, attribute, traits, block, com `0` exibido como valor e listas separadas por ", " (Req. 5.1, 5.5).
18. WHEN a carta tiver `effect_text` ou `trigger_text` THEN the system SHALL exibir a seção "Efeito" com o texto como texto puro, sem interpretar HTML, preservando as quebras de linha, e o `trigger_text` dentro dela, depois do efeito, sob o rótulo "Trigger" em `<strong>` (Req. 5.4, 13.32).

**Independent Test**: Vitest do componente de detalhe com payloads falsos de Leader, Character com counter `null` e `0`, Event, efeito com `<script>` e quebras, trigger sem efeito, variante sem imagem e ausente da fonte; Playwright a 360px (miniatura + "Ver imagem maior") e a 1280px (coluna sempre visível, chip "Counter").

---

### P1: Variantes, preço e destaque ⭐ MVP

**User Story**: Como colecionador, quero ver cada impressão com raridade, set e preço e trocar a arte principal por ela, para saber qual alt art eu tenho e quanto vale.

**Why P1**: Req. 5.2 e 15.8–15.10; carta e variante são objetos distintos e a coleção é por variante.

**Acceptance Criteria**:

19. The system SHALL exibir a seção "Variantes na pasta" com uma linha por variante de `variants[]`, na ordem devolvida, cada uma com miniatura própria (placeholder igual ao do SCAR-10, `alt=""`, `loading="lazy"`), o `variant_code` em estilo `code`, "<rarity> · <tipo de arte>" (`base` → "arte base", `parallel` → "parallel", qualquer outro → "alternativa"; omitido sem `rarity`) e "<nome do set> (<código do set>)" (Req. 5.2, 13.33).
20. WHEN a variante tiver `in_source: false` THEN the system SHALL exibir na linha dela "fora da fonte" em texto.
21. The system SHALL exibir em cada variante, com ou sem sessão, o preço como `US$ 1.234,56` (unidade `US$` para `USD`, o código ISO para outra moeda) seguido de "TCGplayer · market · <dd/mm/aaaa>" com a data de `observed_at` no fuso `America/Sao_Paulo`, ou "Sem preço" quando `price` é `null` (Req. 15.8–15.10).
22. The system SHALL renderizar a miniatura de cada variante como link para `/app/cartas/<card_number>?variant=<variant_code>`, com nome acessível "Mostrar <variant_code> na imagem principal" e `aria-current="true"` só na variante em destaque.
23. WHEN o usuário acionar a miniatura de uma variante THEN the system SHALL tornar essa variante a em destaque (imagem principal, selo, ilustração, raridade e set do cabeçalho), substituir a URL sem criar item no histórico e sem chamar a API de novo (Req. 13.40).
24. WHEN o `variant` da URL estiver ausente ou não for o `variant_code` de nenhuma variante listada THEN the system SHALL usar como destaque a primeira variante com `in_source: true`, ou a primeira listada se nenhuma estiver na fonte, sem erro (Req. 13.40, API-24).

**Independent Test**: Vitest com payload de três variantes (uma ausente, uma sem preço, uma em `EUR`): rótulos, preço e data em São Paulo para `observed_at` às 02:00Z, `aria-current`, troca local sem nova chamada ao cliente falso, `variant` inválido; Playwright: `/app/cartas/X?variant=Y` e `/cards/X?variant=Y` mostram o mesmo destaque.

---

### P1: Posse com stepper otimista ⭐ MVP

**User Story**: Como colecionador abrindo boosters, quero tocar `+` várias vezes seguidas e ver o número subir na hora, com a certeza de que cada toque foi gravado.

**Why P1**: Req. 7.2 e 7.5 são o caminho principal do produto; o stepper com atualização otimista é decisão do dono para esta fatia.

**Acceptance Criteria**:

25. WHILE houver sessão the system SHALL exibir em cada variante a quantidade possuída ("não tenho" quando zero, "1 cópia" ou "N cópias" acima) e o controle `−` `[n]` `+`, em que `[n]` só exibe e é `aria-hidden`, com botões de no mínimo 44px e os nomes acessíveis "Remover uma cópia de <nome> <variant_code>" e "Adicionar uma cópia de <nome> <variant_code>" (Req. 7.2, 13.19, 13.33).
26. WHILE não houver sessão the system SHALL exibir em cada variante, no lugar do controle, o link "Entrar para registrar posse" para `/app/entrar?return_to=<caminho e query atuais>`.
27. WHEN o usuário acionar `+` THEN the system SHALL somar 1 ao valor exibido antes da resposta da API e enviar uma operação de incremento daquela variante.
28. WHEN o usuário acionar `−` com o valor exibido maior que zero THEN the system SHALL subtrair 1 do valor exibido antes da resposta e enviar uma operação de decremento.
29. WHILE o valor exibido for zero the system SHALL marcar o `−` com `aria-disabled="true"`, mantê-lo focável e, quando acionado, não enviar operação e anunciar "Você não tem cópias desta variante para remover." na região viva do controle (Req. 7.4).
30. The system SHALL enviar exatamente uma operação por toque, na ordem dos toques, e só enviar a operação seguinte de uma variante depois da resposta da anterior.
31. WHEN não restar operação pendente nem por enviar numa variante THEN the system SHALL exibir como valor o `owned_quantity` da última resposta recebida.
32. IF uma operação de posse falhar com qualquer erro do cliente THEN the system SHALL descartar as operações ainda não enviadas daquela variante, voltar o valor exibido ao último `owned_quantity` confirmado e exibir a `message` do erro como veio numa mensagem de erro (SPA-45).
33. WHEN a última operação pendente de uma variante terminar com sucesso THEN the system SHALL anunciar numa região `aria-live="polite"` do controle a quantidade com o nome da carta e o `variant_code` ("2 cópias <nome> <variant_code>", "não tenho <nome> <variant_code>").
34. The system SHALL manter o foco no botão acionado durante e depois da operação, sem desabilitá-lo.

**Independent Test**: Vitest com cliente falso de respostas controladas: cinco `+` mostram 1..5 na hora e enviam cinco chamadas em série; a última resposta (`owned_quantity: 7`, outra aba) vence; falha na 3ª volta ao confirmado e não envia a 4ª e a 5ª; `−` em zero não chama o cliente; Playwright contra a API real: cinco `+` rápidos deixam `+5` no banco e o número final igual ao `GET` seguinte.

---

### P1: Desejo por variante ⭐ MVP

**User Story**: Como colecionador, quero marcar quantas cópias de uma impressão eu quero, para levar a lista a trocas.

**Why P1**: Req. 8.1; é o segundo controle do detalhe HTML e a única entrada da wishlist.

**Acceptance Criteria**:

35. WHILE houver sessão the system SHALL exibir em cada variante um formulário com `role="group"` e nome acessível "Marcar <nome> <variant_code> como desejada", contendo o campo numérico de rótulo visível "Quero" (`min="1"`, `step="1"`, valor inicial `wishlist_target`) e o botão "Quero esta" quando `wishlist_target` é `null` ou "Atualizar desejo" quando não é; sem sessão, SHALL não exibi-lo (Req. 8.1).
36. WHEN a API aceitar o alvo THEN the system SHALL exibir a mensagem de sucesso "<nome> <variant_code> na lista de desejos: 1 cópia." ou "…: N cópias.", mostrar no campo o `wishlist_target` devolvido e trocar o botão para "Atualizar desejo".
37. IF a API recusar o alvo com `validation_failed` THEN the system SHALL exibir a mensagem de `fields.target_quantity` junto do campo, ligada por `aria-describedby`, marcar o campo com `aria-invalid="true"`, mover o foco para ele e manter o valor digitado.
38. WHILE o envio do desejo estiver pendente the system SHALL manter o botão desabilitado e ignorar novo envio (Req. 17.21).

**Independent Test**: Vitest do formulário com cliente falso: rótulos por estado, mensagem no singular e no plural, `validation_failed` com `aria-describedby`/`aria-invalid` e foco, segundo envio ignorado; Playwright: marcar 2, recarregar e ver "Atualizar desejo" com 2.

---

### P2: Transição grade → detalhe

**User Story**: Como colecionador, quero ver a arte do tile crescer até virar a imagem da carta, para não perder de vista qual carta abri.

**Why P2**: Componente atribuído a esta fatia pela `spa-fundacao`; é refinamento visual, a tela funciona sem ele.

**Acceptance Criteria**:

39. WHEN o usuário navegar de um tile para o detalhe da mesma carta, com View Transitions suportadas e sem `prefers-reduced-motion: reduce`, THEN the system SHALL transformar a arte do tile na imagem principal visível do detalhe dentro da transição de rota do SPA-43.
40. WHEN o usuário voltar do detalhe ao catálogo (botão ou voltar do navegador) e o tile da carta estiver na grade ao fim da navegação THEN the system SHALL transformar a imagem principal na arte do tile.
41. IF o navegador não suportar View Transitions ou houver `prefers-reduced-motion: reduce` THEN the system SHALL trocar de tela sem transformação e sem erro (SPA-42, SPA-43).

**Independent Test**: Vitest: só um elemento com o `view-transition-name` da carta em cada lado; com `startViewTransition` ausente a navegação conclui; Playwright (Chromium): durante a transição existe o pseudo-elemento `::view-transition-group` da carta, e com `reducedMotion: 'reduce'` não existe.

---

### P1: API de posse e de desejo ⭐ MVP

**User Story**: Como SPA do Bindr, quero gravar posse e desejo do usuário da sessão em JSON, com a mesma garantia atômica do HTML.

**Why P1**: A fatia vertical não grava nada sem estes endpoints; nenhum existe sob `/api`.

**Acceptance Criteria**:

42. WHEN `POST /api/cards/:card_number/variants/:variant_code/increment` chegar com sessão e CSRF válidos THEN the system SHALL somar 1 à quantidade do usuário da sessão naquela variante, criando o `collection_item` com 1 quando não existe, e responder `200` com `{ "data": { "variant_code", "owned_quantity" } }` (formato da rota: P9, AD-027).
43. WHEN `POST /api/cards/:card_number/variants/:variant_code/decrement` chegar com sessão e CSRF válidos THEN the system SHALL subtrair 1 quando a quantidade for maior que zero e responder `200` com a quantidade resultante, e com a quantidade zero ou sem registro SHALL responder `200` com `owned_quantity: 0` sem criar nem alterar registro (P10, AD-027).
44. WHEN incrementos e decrementos da mesma variante e do mesmo usuário chegarem ao mesmo tempo THEN the system SHALL aplicar todos, sem perder operação nem gravar quantidade negativa (Req. 7.4, 7.8).
45. WHEN `PUT /api/cards/:card_number/variants/:variant_code/wishlist` chegar com sessão, CSRF válido e `target_quantity` inteiro maior ou igual a 1 THEN the system SHALL criar ou atualizar o desejo do usuário da sessão naquela variante e responder `200` com `{ "data": { "variant_code", "wishlist_target" } }`.
46. IF `target_quantity` faltar ou não for inteiro maior ou igual a 1 (zero, negativo, decimal, texto, `null`) THEN the system SHALL responder `422` `validation_failed` com `message` "Dados inválidos." e `fields.target_quantity` igual a `["Informe um número inteiro maior ou igual a 1."]`, sem gravar.
47. IF a carta não existir ou o `variant_code` não for de uma variante dela THEN the system SHALL responder `404` `not_found` nos três endpoints, sem gravar.
48. IF um dos três endpoints for chamado sem sessão ou sem `X-CSRF-Token` válido THEN the system SHALL responder `401 unauthenticated` ou `422 invalid_csrf_token` sem gravar, e com sessão SHALL ler e gravar só registros de `Current.user`, ignorando qualquer `user_id` no corpo ou na query (Req. 6.5, API-08, API-10).
49. The system SHALL manter inalterados o comportamento e as rotas HTML: a suíte existente passa sem edição (API-17); o `CollectionItemsController` SHALL passar a delegar o SQL de posse a `CollectionItem`, sem mudar respostas, mensagens nem rotas (abordagem A do design, decisão do dono em 2026-10-11).

**Independent Test**: request tests Rails: incremento cria e soma, decremento no piso, desejo criado e atualizado, cada valor inválido do SCAR-46, carta inexistente e variante de outra carta 404, sem sessão 401, sem token 422 com `allow_forgery_protection` ligado, `user_id` alheio ignorado, e o teste de corrida do `collection_items` (`use_transactional_tests = false`) repetido sobre o endpoint da API.

---

## Edge Cases

- IF o `card_number` tiver caractere reservado de URL (`P-029`, ponto, espaço) THEN the system SHALL codificá-lo na rota da SPA e na chamada à API (SCAR-02), e a rota da API SHALL aceitá-lo como em API-23.
- IF o `variant_code` tiver `:` (`tcgplayer:12345`) THEN the system SHALL codificá-lo no caminho dos endpoints de escrita e no `?variant=`, e a API SHALL decodificá-lo antes da busca.
- WHEN o usuário sair pelo casco com o detalhe aberto THEN the system SHALL repetir a consulta (SCAR-09), trocar steppers e formulários de desejo pelo convite do SCAR-26 e ocultar o selo, e as variantes ausentes da fonte que só ele tinha SHALL sumir da lista (API-25 pode devolver `404` se eram todas).
- WHEN o usuário sair com operações de posse pendentes THEN the system SHALL descartar as não enviadas e não exibir valor otimista na tela anônima.
- WHEN o usuário trocar de variante com operações pendentes noutra variante THEN the system SHALL concluir essas operações e manter o valor de cada variante independente da que está em destaque.
- WHEN o usuário navegar para outra carta com operações pendentes THEN the system SHALL descartar as não enviadas e não aplicar resposta da carta antiga à nova (SCAR-08); as já enviadas valem no servidor.
- IF outra aba mudar a posse entre o toque e a resposta THEN the system SHALL exibir o `owned_quantity` devolvido pela API ao fim da fila (SCAR-31), mesmo diferente do otimista.
- IF o decremento chegar à API com a posse já em zero por causa de outra aba THEN the system SHALL responder `200` com `owned_quantity: 0` (SCAR-43) e a tela SHALL exibir zero.
- IF a imagem da variante em destaque responder `403` ou `404` (sets não lançados, pendência do *Handoff*) THEN the system SHALL manter o placeholder do SCAR-10 visível.
- WHEN a carta não tiver variante THEN the system SHALL exibir cabeçalho com nome e `card_number`, campos e efeito, sem imagem principal e sem a seção "Variantes na pasta".
- WHEN o desejo for enviado com o mesmo alvo já salvo THEN the system SHALL responder `200` com o mesmo `wishlist_target`, sem criar registro duplicado (`UNIQUE (user_id, card_variant_id)`).
- IF o corpo do `PUT` for JSON malformado THEN the system SHALL responder `400 invalid_json` (caso de borda do Req. 16).
- WHEN a viewport cruzar 64rem com o detalhe aberto THEN the system SHALL mover a imagem entre miniatura e coluna sem refazer a consulta nem perder operações pendentes.

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
|---|---|---|---|
| SCAR-01 | P1: Detalhe — rota e título (Req. 19.1) | T13, T17, T19 | Implemented |
| SCAR-02 | P1: Detalhe — consulta da carta (Req. 19.2) | T6, T8, T17 | Implemented |
| SCAR-03 | P1: Detalhe — tile leva à SPA (Req. 19.3) | T6, T18, T19 | Implemented |
| SCAR-04 | P1: Detalhe — voltar ao catálogo (Req. 19.4) | T17, T19 | Implemented |
| SCAR-05 | P1: Detalhe — carta não encontrada (Req. 19.5) | T8, T17, T19 | Implemented |
| SCAR-06 | P1: Detalhe — erro de carga (Req. 19.6) | T8, T17 | Implemented |
| SCAR-07 | P1: Detalhe — carga lenta (Req. 19.7) | T8, T17 | Implemented |
| SCAR-08 | P1: Detalhe — resposta antiga descartada (Req. 19.8) | T8, T17 | Implemented |
| SCAR-09 | P1: Detalhe — troca de sessão (Req. 19.9) | T17, T20 | Implemented |
| SCAR-10 | P1: Cabeçalho — imagem principal e placeholder (Req. 19.10) | T11, T19 | Implemented |
| SCAR-11 | P1: Cabeçalho — miniatura abaixo de 64rem (Req. 19.11) | T13, T19 | Implemented |
| SCAR-12 | P1: Cabeçalho — coluna a partir de 64rem (Req. 19.12) | T13, T19 | Implemented |
| SCAR-13 | P1: Cabeçalho — chips e set (Req. 19.13) | T13, T19 | Implemented |
| SCAR-14 | P1: Cabeçalho — variante fora da fonte (Req. 19.14) | T13 | Implemented |
| SCAR-15 | P1: Cabeçalho — selo de quantidade (Req. 19.15) | T5, T13, T17 | Implemented |
| SCAR-16 | P1: Cabeçalho — ilustração (Req. 19.16) | T13 | Implemented |
| SCAR-17 | P1: Cabeçalho — campos por tipo (Req. 19.17) | T12, T19 | Implemented |
| SCAR-18 | P1: Cabeçalho — efeito e trigger (Req. 19.18) | T12 | Implemented |
| SCAR-19 | P1: Variantes — linha da variante (Req. 19.19) | T16, T19 | Implemented |
| SCAR-20 | P1: Variantes — fora da fonte (Req. 19.20) | T16 | Implemented |
| SCAR-21 | P1: Variantes — preço (Req. 19.21) | T5, T16, T19 | Implemented |
| SCAR-22 | P1: Variantes — miniatura como link (Req. 19.22) | T6, T16, T19 | Implemented |
| SCAR-23 | P1: Variantes — troca local do destaque (Req. 19.23) | T16, T17, T19 | Implemented |
| SCAR-24 | P1: Variantes — destaque padrão (Req. 19.24) | T7, T17, T19 | Implemented |
| SCAR-25 | P1: Posse — controle com sessão (Req. 19.25) | T5, T14, T16, T20 | Implemented |
| SCAR-26 | P1: Posse — convite sem sessão (Req. 19.26) | T16, T20 | Implemented |
| SCAR-27 | P1: Posse — incremento otimista (Req. 19.27) | T9, T14, T20 | Implemented |
| SCAR-28 | P1: Posse — decremento otimista (Req. 19.28) | T9, T14 | Implemented |
| SCAR-29 | P1: Posse — `−` em zero (Req. 19.29) | T9, T14, T20 | Implemented |
| SCAR-30 | P1: Posse — uma operação por toque, em série (Req. 19.30) | T9, T20 | Implemented |
| SCAR-31 | P1: Posse — reconciliação (Req. 19.31) | T9, T20 | Implemented |
| SCAR-32 | P1: Posse — falha volta ao confirmado (Req. 19.32) | T9, T14 | Implemented |
| SCAR-33 | P1: Posse — anúncio (Req. 19.33) | T9, T14 | Implemented |
| SCAR-34 | P1: Posse — foco preservado (Req. 19.34) | T14 | Implemented |
| SCAR-35 | P1: Desejo — formulário (Req. 19.35) | T15, T16 | Implemented |
| SCAR-36 | P1: Desejo — sucesso (Req. 19.36) | T5, T15, T20 | Implemented |
| SCAR-37 | P1: Desejo — alvo recusado (Req. 19.37) | T15 | Implemented |
| SCAR-38 | P1: Desejo — envio pendente (Req. 19.38) | T15 | Implemented |
| SCAR-39 | P2: Transição — ida (Req. 19.39) | T10, T13, T18, T21 | Implemented |
| SCAR-40 | P2: Transição — volta (Req. 19.40) | T10, T18, T21 | Implemented |
| SCAR-41 | P2: Transição — sem suporte ou movimento reduzido (Req. 19.41) | T10, T21 | Implemented |
| SCAR-42 | P1: API — incremento (Req. 19.42) | T2, T6 | Implemented |
| SCAR-43 | P1: API — decremento (Req. 19.43) | T2 | Implemented |
| SCAR-44 | P1: API — concorrência (Req. 19.44) | T1, T4 | Implemented |
| SCAR-45 | P1: API — desejo (Req. 19.45) | T3, T6 | Implemented |
| SCAR-46 | P1: API — alvo inválido (Req. 19.46) | T3 | Implemented |
| SCAR-47 | P1: API — carta ou variante inexistente (Req. 19.47) | T2, T3 | Implemented |
| SCAR-48 | P1: API — sessão, CSRF e isolamento (Req. 19.48) | T2, T3 | Implemented |
| SCAR-49 | P1: API — HTML inalterado (Req. 19.49) | T1, T22 | Implemented |

**Coverage:** 49 total, 49 mapped to tasks, 0 unmapped

## Implicit-Requirement Dimensions

| Dimension | Resolution |
|---|---|
| Input validation & bounds | SCAR-46 (alvo inteiro ≥ 1, mensagem pt-BR), SCAR-47 (carta e variante), edge cases de codificação de `card_number` e `variant_code` e de JSON malformado |
| Failure / partial-failure states | SCAR-05, SCAR-06 (carga), SCAR-32 (operação de posse falha no meio da fila), SCAR-37 (desejo recusado), SCAR-10 (imagem) |
| Idempotency / retry / duplicate handling | SCAR-43 (decremento no piso é idempotente), SCAR-45 e edge case do mesmo alvo (`PUT` idempotente, sem duplicata); incremento não é idempotente por natureza e o SCAR-30 garante uma operação por toque, sem reenvio além do da renovação de CSRF (SPA-10, que não executa a action no `422`) |
| Auth boundaries & rate limits | SCAR-48 (sessão, CSRF, `Current.user`), SCAR-25/26/35 (controles só com sessão). Rate limit N/A because nem o HTML nem a API o têm (Out of Scope) |
| Concurrency / ordering | SCAR-30 (série por variante), SCAR-31 (última resposta vence), SCAR-44 (atomicidade no banco), SCAR-08 (resposta de carta antiga) |
| Data lifecycle / expiry | N/A because a fatia não apaga nada: posse vai a zero sem apagar o registro (como o HTML), e a remoção de desejo é de outra fatia |
| Observability | N/A because a SPA não tem coleta remota de erro (decisão da `spa-fundacao`); a API registra o `500` no log como no Req. 16 |
| External-dependency failure | SCAR-10 e o edge case do `403` do CDN cobrem a imagem; a API é tratada por SCAR-06 e SCAR-32 |
| State-transition integrity | SCAR-27..32: valor exibido = confirmado + operações pendentes, e volta ao confirmado em falha; SCAR-29 impede transição abaixo de zero na tela e SCAR-43/44 no banco |

## Success Criteria

- [ ] Playwright contra a API real compara `/app/cartas/X?variant=Y` com `/cards/X?variant=Y` (campos, variantes, preços, destaque) para um Leader, um Character com três variantes e um Event, a 360px e a 1280px, nos dois temas, sem scroll horizontal.
- [ ] Cinco toques rápidos em `+` gravam exatamente +5 e o número final na tela é igual ao do `GET` seguinte; com a rede cortada no 3º, a tela volta ao último valor confirmado e mostra "Sem conexão com o servidor. Tente novamente.".
- [ ] Um desejo marcado na SPA aparece em `/wishlist` (Hotwire) com o mesmo alvo.
- [ ] A suíte Rails passa sem edição, com os request tests novos dos três endpoints, e o teste de corrida da API soma todas as operações simultâneas.
