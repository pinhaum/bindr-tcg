# Especificação — Decks na SPA

Recorte da feature `spa-decks` sobre `.context/requirements.md` Req. 21
(SDEC-NN, mesma numeração dos critérios). Em divergência, `.context/` vence
(AD-005). Depende da `api-fundacao` (Req. 16), da `spa-fundacao` (Req. 17) e
da `spa-carta` (Req. 19, dona do detalhe e do stepper otimista que esta feature
reusa), encerradas e verificadas, e da `spa-pasta` (Req. 20, dona da tela onde
entra o bloco "Faltando para os baralhos"), implementada. Escrita em 2026-10-10
sem o dono presente; aprovada pelo dono em 2026-10-11, com o P12 decidido
(AD-029).

## Problem Statement

A Fase 2 (Req. 14) só existe no Hotwire: na SPA a entrada "Baralhos" do casco
recarrega a página inteira em `/decks` (SPA-26), o detalhe da carta da
`spa-carta` não soma carta a deck nenhum (o controle ficou para esta fatia) e a
pasta da `spa-pasta` não mostra o que falta para os decks (o bloco também
ficou para cá). A API não tem endpoint de deck. Esta feature leva lista,
criação, renomeação, exclusão, página do deck e importação para
`/app/baralhos`, com paridade com as telas Hotwire, liga o deck em edição ao
detalhe e o bloco de falta à pasta, e cria os endpoints que tudo isso precisa.
As regras de montagem continuam nos objetos do Req. 14; a SPA só exibe.

## Goals

- [ ] `/app/baralhos/<id>` mostra o mesmo status, os mesmos motivos e avisos, os mesmos grupos e ordem de entradas e os mesmos números "pedida, possuída, falta" que `/decks/<id>` para o mesmo deck, verificado por Playwright contra a API real a 360px e a 1280px, nos dois temas, sem scroll horizontal.
- [ ] Um deck de 1 Leader + 50 é montado só pela SPA (criar, escolher o Leader e somar cartas pelo detalhe) e sai `válido` no Hotwire e na SPA.
- [ ] Importar pela SPA o texto exportado de um deck reproduz o mesmo Leader e as mesmas entradas (Req. 14.32); uma lista com linha ruim não cria deck e mostra cada linha com número e motivo.
- [ ] O bloco "Faltando para os baralhos" da `/app/pasta` lista as mesmas cartas, faltas e decks que a `/progress`.
- [ ] A suíte Rails existente passa sem edição; os endpoints novos têm request test de sessão, CSRF, isolamento entre usuários e concorrência.

## Out of Scope

| Feature | Reason |
|---|---|
| Regra de montagem, status, motivos, avisos, falta e formato da lista calculados no cliente | Um dono por regra: `Deck::Legality`, `DeckShortfallQuery` e `Deck::ListText` (Req. 14). A SPA exibe o que a API devolve. |
| Escolher o deck em edição a partir do detalhe da carta | O HTML só escolhe pela página do deck ("Editar este deck"); seletor no detalhe é melhoria além da paridade, para decisão do dono. |
| Botão "Copiar lista" ou download do texto exportado | O HTML abre `/decks/<id>.txt` como texto no navegador; a SPA leva ao mesmo endereço (SDEC-29). Melhoria além da paridade. |
| Exclusão em diálogo, sem página de confirmação | O HTML confirma em página própria; a SPA faz o mesmo em rota (SDEC-15). |
| Marcar "Baralhos" como atual nas rotas abaixo de `/app/baralhos` | O HTML marca só `/decks` (`current_page?` exato); mesma fronteira que a `spa-pasta` usou para `/app/pasta/desejos`. |
| Lista de banidas, deck de DON!!, decks públicos, preço do deck, outros formatos de lista | Fora do Req. 14 por decisão do dono (spec da `decks`). |
| Mandar o que falta para a wishlist em um clique | Ideia adjacente, fora do Req. 14. |
| Atualizar a página do deck aberta quando o deck mudar noutra aba | O HTML só muda ao recarregar; a página reconsulta ao abrir e ao "Tentar novamente". |
| Redirecionar `/decks` para a SPA, remover as telas Hotwire e o `GET /decks/:id.txt` | Feature final `spa-troca` (AD-023); ela decide para onde vai a exportação. |
| Links de outras telas Hotwire para os decks | Continuam em `/decks` até a `spa-troca`. |
| Limite de taxa nas mutações de deck | Não existe no HTML nem na API (dívida de autenticação registrada no `CLAUDE.md`). |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
|---|---|---|---|
| **P12** — chave das rotas de entrada de deck | `id` do deck, exposto no payload, mais `card_number` no caminho: `POST /api/decks/:id/cards/:card_number/increment` e `/decrement`, `PUT /api/decks/:id/leader` com `card_number` no corpo (SDEC-51..55). Alternativa: rotas sobre o deck em edição da sessão, sem id (`/api/editing_deck/cards/:card_number/…`) | Com o id, a operação vai para o deck que a tela mostra, mesmo que outra aba ou o Hotwire troque o deck em edição entre a carga e o toque: é o princípio do SPA-10 ("uma ação nunca é executada em conta diferente da que estava na tela") aplicado ao deck. O deck não tem chave natural, então o id é exposto; a carta usa `card_number`, como no P9. Contrato público com efeito em dado | Sim — dono, 2026-10-11 (AD-029) |
| Onde mora o deck em edição | Na sessão do Rails (`session[:editing_deck_id]`, concern `EditingDeck`), lida e gravada pela API; nada em `localStorage` | Paridade e coexistência: durante a transição, escolher o deck no Hotwire vale na SPA e vice-versa; login e logout já limpam a chave com `reset_session`, e a revalidação contra `Current.user.decks` dá o DCK-41 de graça | Sim — dono, 2026-10-11 |
| Deck em edição no detalhe da carta | Campo aditivo `editing_deck` no `GET /api/cards/:card_number` (SDEC-50), em vez de um endpoint próprio | É o que o `catalog#show` HTML faz numa ida só (`editing_deck_quantity`); um segundo `GET` por carta duplicaria a carga e abriria uma janela de estados divergentes. A mudança é aditiva e não quebra o contrato do Req. 16.23 | Sim — dono, 2026-10-11 |
| Bloco da pasta | Endpoint próprio `GET /api/decks/shortfall` (SDEC-59), pedido pela pasta em paralelo ao `GET /api/progress` | O `GET /api/progress` é da `spa-pasta`; um endpoint próprio mantém cada fatia dona do seu contrato, e a falha de um não derruba o outro (SDEC-42). Custo: duas idas na abertura da pasta | Sim — dono, 2026-10-11 |
| Exportação | Link de página inteira para o `GET /decks/<id>.txt` existente | Todo endpoint de `/api` responde JSON (API-14); a exportação HTML já devolve o texto que o simulador aceita (T21 da `decks`). Mesmo critério da `spa-pasta` para o CSV | Sim — dono, 2026-10-11 (paridade) |
| Stepper do deck | Otimista, reusando o componente e a fila em série da `spa-carta` (SDEC-36) | A `spa-fundacao` atribuiu o estado de deck em edição a esta fatia e o stepper otimista à `spa-carta`; o deck tem o mesmo padrão de toques rápidos ao montar | Sim — dono, 2026-10-11 |
| `−` do deck em zero | `aria-disabled`, focável, sem envio, anuncia "<card_number> não está no deck “<deck>”." (SDEC-37) | O HTML envia e recebe esse alerta; a SPA já sabe o resultado, como no `−` da posse (SCAR-29). Mesmo texto do HTML | Sim — dono, 2026-10-11 |
| Decremento sem entrada na API | `200` com `quantity: 0`, sem gravar (SDEC-52) | Mesma regra do P10 da `spa-carta` (AD-027): só ocorre por corrida entre abas e reconcilia sem caso especial | Sim — acompanha o P10 (AD-027) |
| Teto de 50 e Leader somado como entrada | `422 validation_failed` com a mensagem do HTML, sem `fields` de campo (SDEC-53, SDEC-54) | O HTML responde alerta com a quantidade inalterada; na SPA otimista a recusa precisa voltar o valor e mostrar a mensagem, o que o SCAR-32 já faz para qualquer erro. Reusa o código existente em vez de criar um novo | Sim — dono, 2026-10-11 |
| Recusa da importação | `validation_failed` com `fields.list` contendo "Linha N: <motivo>" ou o motivo sem número, na ordem, e `message` "A lista não foi importada. Nenhum deck foi criado." (SDEC-58) | Cabe no envelope de erro do Req. 16 (lista de mensagens por campo) sem formato novo; as frases são as do `Deck::ListText` e da view HTML | Sim — dono, 2026-10-11 |
| Mensagens de nome | `fields.name` como frase inteira: "O nome não pode ficar vazio." e "O nome pode ter no máximo 60 caracteres." | A view HTML monta "O nome <mensagem do model>."; a API do Req. 16 entrega frase pronta em pt-BR | Sim — dono, 2026-10-11 |
| Status na API | Código (`valid`, `incomplete`, `invalid`); a SPA exibe "válido", "incompleto", "inválido" | Mesma separação do `deck_status_label` do HTML; motivos e avisos já saem em pt-BR do `Deck::Legality` | Sim — dono, 2026-10-11 |
| Grupos da página do deck | A API devolve `entries` já na ordem do DCK-07; a SPA só corta a cada troca de `card_type`, com os rótulos do `DecksHelper` | Um dono para a ordenação (`Deck#ordered_entries`), como o `chunk_while` da view HTML | Sim — dono, 2026-10-11 (paridade) |
| Rotas da SPA | `/app/baralhos`, `/app/baralhos/novo`, `/app/baralhos/importar`, `/app/baralhos/<id>`, `/app/baralhos/<id>/renomear` e `/app/baralhos/<id>/excluir` | Nome da entrada do casco ("Baralhos") e pt-BR como `/app/pasta` e `/app/cartas`; uma rota por página HTML | Sim — dono, 2026-10-11 |
| Rotas da API | `GET/POST /api/decks`, `GET/PATCH/DELETE /api/decks/:id`, `POST /api/decks/:id/select`, `POST /api/decks/import`, `GET /api/decks/shortfall` e as do P12 | Inglês e recursos como `/api/catalog` e `/api/cards`; `select` e `import` espelham as rotas HTML. `import` e `shortfall` precisam vir antes de `:id` no `routes.rb` | Sim — dono, 2026-10-11 |
| Remoção do deck | Não otimista: a SPA navega só depois do `200` | Remoção não tem desfazer, como a do desejo na `spa-pasta` | Sim — dono, 2026-10-11 |
| "Usar como Leader" | Não otimista, com o botão pendente da `spa-fundacao` | Troca do Leader é uma ação, não contagem; o HTML também espera a resposta | Sim — dono, 2026-10-11 |
| Carga lenta | Só depois de 200 ms, `aria-busy` e "Carregando baralhos…"/"Carregando deck…" | Mesmo limiar do SCAT-38, SCAR-07 e da `spa-pasta` | Sim — dono, 2026-10-11 |
| Foco ao abrir uma tela de deck | O de rota nova da `spa-fundacao`: `main#conteudo` | Troca de rota, como nas fatias anteriores | Sim — dono, 2026-10-11 |

**Open questions:** none - all resolved or logged above. O P12 foi decidido com a opção recomendada (AD-029); o SDEC-52 segue o P10 (AD-027).

---

## User Stories

### P1: Rotas e lista de decks ⭐ MVP

**User Story**: Como jogador, quero abrir "Baralhos" pelo casco e ver meus decks com Leader, total e status, sem recarregar a página.

**Why P1**: Sem a lista não há como chegar a deck nenhum; é o destino da entrada do casco.

**Acceptance Criteria**:

1. WHEN o usuário abrir `/app/baralhos` THEN the system SHALL exibir a lista com o título de página "Baralhos — Bindr" e o cabeçalho de nível 1 "Baralhos".
2. WHEN o usuário acionar a entrada "Baralhos" da navegação THEN the system SHALL levar a `/app/baralhos` sem recarregar a página e marcá-la com `aria-current="page"` em `/app/baralhos` com qualquer query, no lugar do destino Hotwire do SPA-26.
3. IF a sessão estiver anônima quando uma rota sob `/app/baralhos` abrir THEN the system SHALL levar a `/app/entrar?return_to=<caminho e query atuais>` sem chamar a API da tela.
4. WHILE a consulta de uma tela de deck estiver pendente há mais de 200 ms the system SHALL marcar a tela com `aria-busy="true"` e anunciar "Carregando baralhos…" ou "Carregando deck…", e antes dos 200 ms SHALL manter o conteúdo anterior.
5. IF chegar a resposta de uma URL que já não é a atual THEN the system SHALL descartá-la sem alterar a tela.
6. IF a consulta de uma tela de deck falhar com erro que não seja `404 not_found` THEN the system SHALL exibir a `message` do erro e o botão "Tentar novamente", que repete a consulta.
7. The system SHALL exibir cada deck na ordem da API, com o nome como cabeçalho de nível 2 e link para `/app/baralhos/<id>` sem recarga, "Leader" com "<nome> (<card_number>)" ou "Sem Leader", "Cartas" com "N / 50" e "Status" com "válido", "incompleto" ou "inválido" (Req. 14.8).
8. IF o usuário não tiver decks THEN the system SHALL exibir "Você ainda não tem decks.".
9. The system SHALL oferecer na lista os links "Novo deck" para `/app/baralhos/novo` e "Importar lista" para `/app/baralhos/importar`, sem recarga.

**Independent Test**: Vitest da rota com cliente falso: redirecionamento sem sessão sem chamar o cliente, lista com Leader e sem Leader, os três rótulos de status, lista vazia, resposta antiga descartada, erro com "Tentar novamente"; Playwright: casco → `/app/baralhos` sem recarga e a mesma sequência de decks que `/decks`.

---

### P1: Criar, renomear e excluir ⭐ MVP

**User Story**: Como jogador, quero criar um deck com um nome, renomeá-lo e excluí-lo com confirmação, sem tocar na minha coleção.

**Why P1**: Req. 14.1, 14.9 e 14.10; sem criar não há deck para montar.

**Acceptance Criteria**:

10. The system SHALL exibir em `/app/baralhos/novo` e `/app/baralhos/<id>/renomear` o título de página "Novo deck — Bindr" ou "Renomear deck — Bindr", o mesmo texto como cabeçalho de nível 1 e o campo obrigatório "Nome do deck (até 60 caracteres)" com `maxlength="60"`, preenchido com o nome atual ao renomear.
11. WHEN a API aceitar a criação THEN the system SHALL levar a `/app/baralhos/<id>` do deck novo e exibir a mensagem de sucesso "Deck criado." (Req. 14.1).
12. WHEN a API aceitar a renomeação THEN the system SHALL levar à página do deck e exibir a mensagem de sucesso "Deck renomeado." (Req. 14.10).
13. IF a API recusar o nome com `validation_failed` THEN the system SHALL exibir a mensagem de `fields.name` junto do campo, ligada por `aria-describedby`, marcar o campo com `aria-invalid="true"`, mover o foco para ele e manter o valor digitado.
14. WHILE um envio de formulário de deck estiver pendente the system SHALL manter o botão de envio desabilitado e ignorar novo envio (Req. 17.21).
15. The system SHALL exibir em `/app/baralhos/<id>/excluir` o título de página "Excluir deck — Bindr", o cabeçalho "Excluir o deck “<nome>”?", o texto "O deck e as cartas dele somem. Sua coleção e sua wishlist não mudam.", o botão "Excluir deck" e o link "Cancelar" para a página do deck, sem apagar nada ao abrir a tela.
16. WHEN a API aceitar a exclusão THEN the system SHALL levar a `/app/baralhos` e exibir a mensagem de sucesso "Deck “<nome>” excluído." (Req. 14.9).

**Independent Test**: Vitest dos formulários com cliente falso: rótulo e `maxlength`, `fields.name` com `aria-describedby`/`aria-invalid`/foco, segundo envio ignorado, navegação e mensagem em cada sucesso; abrir a confirmação não chama o cliente; Playwright: criar, renomear e excluir um deck e conferir em `/decks` (Hotwire).

---

### P1: Página do deck ⭐ MVP

**User Story**: Como jogador, quero ver o Leader e as cartas do deck agrupadas, o status com os motivos e quanto falta na minha pasta, para saber o que comprar ou trocar.

**Why P1**: Req. 14.7, 14.15, 14.17, 14.19, 14.21, 14.22 e 14.44; é o produto da Fase 2.

**Acceptance Criteria**:

17. WHEN o usuário abrir `/app/baralhos/<id>` THEN the system SHALL exibir a página com o título de página "<nome> — Bindr" e o nome do deck como cabeçalho de nível 1.
18. IF a API responder `404 not_found` a qualquer tela de um deck THEN the system SHALL exibir no lugar dela o título de página "Deck não encontrado — Bindr", a `message` da API e o link "Voltar aos baralhos".
19. WHILE o deck exibido for o deck em edição (`editing: true`) the system SHALL exibir "Em edição" e, nos demais casos, SHALL exibir o botão "Editar este deck".
20. WHEN a API aceitar "Editar este deck" THEN the system SHALL exibir "Em edição" no lugar do botão e a mensagem de sucesso "Agora as cartas vão para o deck “<nome>”.".
21. The system SHALL exibir o cabeçalho "Status: <rótulo>" e, quando o status não for `valid`, a lista de `reasons` na ordem e com o texto que a API devolve (Req. 14.15).
22. WHEN a API devolver `warnings` THEN the system SHALL exibir, para cada um, "Este Leader tem regra de montagem própria, não verificada" e o texto do aviso num `<blockquote>` (Req. 14.44).
23. The system SHALL exibir sempre "A lista de banidas não é verificada" na página do deck (Req. 14.17).
24. The system SHALL exibir na seção "Na sua pasta" "Este deck ainda não tem cartas" sem Leader e sem entradas, "Você tem todas as cartas deste deck" com `missing_total` zero, "Falta 1 cópia para montar este deck" com 1 e "Faltam N cópias para montar este deck" acima de 1 (Req. 14.22).
25. The system SHALL exibir na seção "Leader" "<nome> (<card_number>)" como link para `/app/cartas/<card_number>` sem recarga, ou "Sem Leader" quando `leader` é `null`.
26. The system SHALL exibir a seção "Deck principal: <main_total> / 50" com as entradas na ordem da API, um cabeçalho de nível 3 a cada troca de `card_type` ("Personagens", "Eventos", "Locais"; outro valor com inicial maiúscula) e, em cada entrada, "N×", "<nome> (<card_number>)" como link para `/app/cartas/<card_number>` sem recarga e "custo N" quando `cost` não é `null` (Req. 14.7).
27. WHEN o Leader ou uma entrada tiver `in_source: false` THEN the system SHALL exibir nela "carta fora da fonte" (Req. 14.19).
28. The system SHALL exibir no Leader e em cada entrada "pedida N, possuída N, falta N" com `required`, `owned` e `missing` da API (Req. 14.21).
29. The system SHALL oferecer "Exportar lista" para `/decks/<id>.txt` com navegação de página inteira, e "Renomear", "Excluir" e "Voltar aos baralhos" sem recarga (Req. 14.31).

**Independent Test**: Vitest da página com payloads falsos: deck vazio, deck válido, deck incompleto e inválido com motivos, Leader com aviso, entrada fora da fonte, Event com `cost: null`, tipo desconhecido, cada frase do SDEC-24; Playwright compara, para o mesmo deck, status, motivos, grupos, ordem e números de `/app/baralhos/<id>` com `/decks/<id>`, a 360px e 1280px nos dois temas.

---

### P1: Importar lista ⭐ MVP

**User Story**: Como jogador, quero colar a lista do OPTCG Simulator e ganhar um deck novo, ou ver exatamente quais linhas estão erradas.

**Why P1**: Req. 14.24–14.32; é o caminho de quem já tem a lista montada em outro app.

**Acceptance Criteria**:

30. The system SHALL exibir em `/app/baralhos/importar` o título de página "Importar lista — Bindr", o cabeçalho "Importar lista", o texto "Cole a lista do OPTCG Simulator: uma carta por linha, como 4xOP01-016, com o Leader como 1x. A importação cria um deck novo e não altera nenhum deck que você já tem.", o campo opcional "Nome do deck (opcional; sem nome, o deck leva o nome do Leader)" com `maxlength="60"`, a área de texto obrigatória "Lista (até 200 linhas e 10.000 caracteres)", o botão "Importar lista" e o link "Voltar aos baralhos".
31. WHEN a API aceitar a importação THEN the system SHALL levar à página do deck criado e exibir a mensagem de sucesso "Deck importado." (Req. 14.24).
32. IF a API recusar a lista com `validation_failed` THEN the system SHALL exibir num resumo com `role="alert"`, que recebe o foco, a `message` da API e cada mensagem de `fields.list` na ordem, ligar o resumo à área de texto por `aria-describedby` com `aria-invalid="true"`, manter nome e lista digitados e tratar `fields.name` como no SDEC-13.

**Independent Test**: Vitest com cliente falso: sucesso navega e avisa; recusa com três linhas mostra as três na ordem, foco no resumo, `aria-describedby`/`aria-invalid` na lista e textos mantidos; Playwright: exportar um deck por `/decks/<id>.txt`, colar o texto em `/app/baralhos/importar` e comparar Leader e entradas do deck novo com o original.

---

### P1: Deck em edição no detalhe da carta ⭐ MVP

**User Story**: Como jogador montando um deck, quero tocar `+` no detalhe da carta e ver a quantidade no deck subir na hora, e escolher o Leader no detalhe dele.

**Why P1**: Req. 14.3–14.6 e 14.41; é como o deck é montado, e a `spa-carta` deixou o controle para esta fatia.

**Acceptance Criteria**:

33. WHILE houver sessão e `editing_deck` não for `null` the system SHALL exibir no detalhe `/app/cartas/<card_number>` a seção "Deck em edição" com "As cartas vão para o deck <nome>", o nome como link para `/app/baralhos/<id>` sem recarga (Req. 14.3).
34. IF não houver sessão ou `editing_deck` for `null`, inclusive porque o deck foi excluído, THEN the system SHALL não exibir a seção "Deck em edição" no detalhe (Req. 14.41).
35. WHILE a carta não for Leader the system SHALL exibir na seção, numa região `aria-live="polite"`, "1 cópia de <nome> no deck" ou "N cópias de <nome> no deck" (inclusive "0 cópias") e o controle `−` `+` com alvos de no mínimo 44px e os nomes acessíveis "Remover uma cópia de <nome> do deck <deck>" e "Adicionar uma cópia de <nome> ao deck <deck>" (Req. 14.3, 14.5).
36. WHEN o usuário acionar `−` ou `+` do deck THEN the system SHALL aplicar as regras do stepper otimista do SCAR-27, SCAR-28, SCAR-30, SCAR-31, SCAR-32 e SCAR-34 à quantidade da carta no deck exibido, com as operações de incremento e decremento do SDEC-51 e do SDEC-52.
37. WHILE a quantidade exibida no deck for zero the system SHALL marcar o `−` com `aria-disabled="true"`, mantê-lo focável e, quando acionado, não enviar operação e anunciar "<card_number> não está no deck “<deck>”." na região viva do controle.
38. WHILE a carta for Leader the system SHALL exibir o botão "Usar como Leader" com nome acessível "Usar <nome> como Leader do deck <deck>" ou, quando `is_leader` for verdadeiro, o botão "<nome> é o Leader deste deck" com `aria-disabled="true"`, focável e sem envio (Req. 14.4).
39. WHEN a API aceitar "Usar como Leader" THEN the system SHALL trocar o botão pelo de Leader atual e exibir a mensagem de sucesso "<card_number> é o Leader do deck “<deck>”.".

**Independent Test**: Vitest do detalhe com payload falso: sem `editing_deck` nada aparece; carta comum com 0, 1 e 2; cinco `+` rápidos sobem 1..5 e enviam cinco chamadas em série ao deck do payload; falha no 3º volta ao confirmado; `−` em 0 não chama o cliente e anuncia; Leader com e sem `is_leader`; Playwright: escolher deck em `/app/baralhos/<id>`, abrir uma carta, `+` três vezes, e a página do deck mostra `3×`.

---

### P1: Faltando para os baralhos na pasta ⭐ MVP

**User Story**: Como jogador, quero ver na minha pasta o que falta comprar para montar qualquer um dos meus decks.

**Why P1**: Req. 14.33–14.35; a `spa-pasta` deixou o bloco para esta fatia.

**Acceptance Criteria**:

40. WHEN `/app/pasta` abrir e `GET /api/decks/shortfall` devolver ao menos uma carta THEN the system SHALL exibir no grupo de ações secundárias da pasta, antes dos links, o bloco de cabeçalho "Faltando para os baralhos" com cada carta na ordem da API: o nome como link para `/app/cartas/<card_number>` sem recarga, o `card_number` em `code`, "falta 1" ou "faltam N" e "Em" seguido dos decks que a usam, cada um como link para `/app/baralhos/<id>` sem recarga, separados por ", " (Req. 14.33, 14.34).
41. WHEN a resposta vier sem cartas THEN the system SHALL omitir o bloco e o cabeçalho (Req. 14.35).
42. IF a consulta do bloco falhar THEN the system SHALL exibir no lugar do bloco a `message` do erro e "Tentar novamente", sem alterar o resto da pasta.

**Independent Test**: Vitest do bloco com cliente falso: lista vazia sem nada no DOM, "falta 1"/"faltam 2", carta em dois decks com dois links, erro com "Tentar novamente" e a pasta intacta; Playwright compara as cartas, faltas e decks do bloco com os da `/progress`.

---

### P1: API de decks ⭐ MVP

**User Story**: Como SPA do Bindr, quero ler e gravar os decks do usuário da sessão em JSON, com as mesmas regras e garantias atômicas do HTML.

**Why P1**: A fatia vertical não tem nada a exibir sem estes endpoints; nenhum existe sob `/api`.

**Acceptance Criteria**:

43. WHEN `GET /api/decks` chegar THEN the system SHALL responder `200` com os decks do usuário da sessão ordenados por nome e id, cada um com `id`, `name`, `leader` (`{ card_number, name }` ou `null`), `main_total` e `status` (`valid`, `incomplete` ou `invalid`).
44. WHEN `POST /api/decks` chegar com nome válido THEN the system SHALL criar o deck vazio, torná-lo o deck em edição da sessão e responder `201` com o deck no formato do SDEC-47.
45. WHEN `PATCH /api/decks/:id` chegar com nome válido THEN the system SHALL mudar só o nome e responder `200` com o deck no formato do SDEC-47.
46. IF o nome faltar, ficar vazio depois de tirar os espaços das bordas ou passar de 60 caracteres THEN the system SHALL responder `422 validation_failed` na criação, na renomeação e na importação, com `fields.name` igual a `["O nome não pode ficar vazio."]` ou `["O nome pode ter no máximo 60 caracteres."]`, sem gravar, e na importação SHALL recusar o nome ausente só quando a lista não tem Leader (Req. 14.24).
47. WHEN `GET /api/decks/:id` chegar THEN the system SHALL responder `200` com `id`, `name`, `editing`, `status`, `reasons`, `warnings`, `main_total`, `missing_total`, `leader` e `entries`, em que `leader` (ou `null`) e cada entrada trazem `card_number`, `name`, `card_type`, `cost`, `in_source`, `required`, `owned` e `missing`, cada entrada também `quantity`, `entries` na ordem do Req. 14.7 e todos os campos lidos num retrato só do banco (`REPEATABLE READ`, como o `DecksController#show`).
48. WHEN `DELETE /api/decks/:id` chegar THEN the system SHALL apagar o deck e as entradas dele, sem alterar coleção nem wishlist, e responder `200` com `{ "data": { "id", "name" } }`.
49. WHEN `POST /api/decks/:id/select` chegar THEN the system SHALL gravar o deck em `session[:editing_deck_id]`, a mesma chave que o Hotwire lê, e responder `200` com `{ "data": { "id", "name" } }`.
50. WHEN `GET /api/cards/:card_number` chegar com sessão e deck em edição válido THEN the system SHALL incluir na carta `editing_deck` com `id`, `name`, `quantity` (`0` sem entrada) e `is_leader`, e sem sessão ou sem deck em edição SHALL devolver `editing_deck: null` (emenda aditiva do API-23).
51. WHEN `POST /api/decks/:id/cards/:card_number/increment` chegar THEN the system SHALL somar 1 à entrada da carta no deck, criando-a com 1 quando não existe, e responder `200` com `{ "data": { "card_number", "quantity" } }` (P12, AD-029).
52. WHEN `POST /api/decks/:id/cards/:card_number/decrement` chegar THEN the system SHALL subtrair 1 da entrada, apagá-la ao chegar a zero e responder `200` com a quantidade resultante, e sem entrada SHALL responder `200` com `quantity: 0` sem gravar (P10, AD-027).
53. IF o incremento encontrar a entrada em 50 THEN the system SHALL responder `422 validation_failed` com `message` "O máximo é 50 cópias por carta no deck.", sem gravar (Req. 14.39).
54. IF o incremento apontar uma carta Leader THEN the system SHALL responder `422 validation_failed` com `message` "<card_number> é um Leader; use “Usar como Leader” em vez de somar cópias.", sem gravar.
55. WHEN `PUT /api/decks/:id/leader` chegar com o `card_number` de uma carta Leader THEN the system SHALL gravar ou substituir o Leader, sem tocar as entradas, e responder `200` com `{ "data": { "leader_card_number" } }`, e com carta que não é Leader SHALL responder `422 validation_failed` com "<card_number> não é um Leader; use “+” para somar cópias ao deck.", sem gravar.
56. WHEN incrementos e decrementos da mesma carta no mesmo deck chegarem ao mesmo tempo THEN the system SHALL aplicar todos, sem perder operação, sem passar de 50 e sem gravar quantidade abaixo de 1 (Req. 14.38).
57. WHEN `POST /api/decks/import` chegar com `name` e `list` e a lista for aceita pelo Req. 14.24–14.30 THEN the system SHALL criar o deck com Leader e entradas da lista, torná-lo o deck em edição e responder `201` com o deck no formato do SDEC-47.
58. IF a lista for recusada THEN the system SHALL responder `422 validation_failed` com `message` "A lista não foi importada. Nenhum deck foi criado." e `fields.list` com cada recusa na ordem do texto, como "Linha N: <motivo>" ou só o motivo quando vale para o texto inteiro, sem criar deck.
59. WHEN `GET /api/decks/shortfall` chegar THEN the system SHALL responder `200` só com as cartas que faltam para os decks do usuário (`missing > 0`, regra do Req. 14.33), ordenadas por `card_number`, cada uma com `card_number`, `name`, `missing` e `decks` (`{ id, name }` dos decks que a usam, ordenados por id).
60. IF um endpoint de deck for chamado sem sessão, uma mutação sem `X-CSRF-Token` válido, ou com deck inexistente ou de outro usuário ou carta inexistente THEN the system SHALL responder `401 unauthenticated`, `422 invalid_csrf_token` ou `404 not_found` sem gravar, e com sessão SHALL partir sempre de `Current.user.decks`, ignorando qualquer `user_id` no corpo ou na query (Req. 6.5, 14.36, 14.37).
61. The system SHALL manter inalterados os controllers e as rotas HTML: a suíte existente passa sem edição (API-17).

**Independent Test**: request tests Rails: cada endpoint com e sem sessão, mutação sem token com `allow_forgery_protection` ligado, deck de outro usuário 404 nas leituras e nas mutações, `user_id` alheio ignorado, nome vazio e com 61 caracteres, teto de 50, Leader no incremento e não-Leader no `leader`, decremento sem entrada, `editing_deck` com e sem sessão e depois de excluir o deck em edição, importação aceita e recusada sem criar deck, `shortfall` igual ao bloco da `/progress`, contagem de consultas fixa com 1 e 3 decks; teste de corrida (`use_transactional_tests = false`) repetido sobre o endpoint da API.

---

## Edge Cases

- IF o `card_number` tiver caractere reservado de URL (`P-117`, ponto, espaço) THEN the system SHALL codificá-lo nas rotas de deck da API e nos links da SPA, e a API SHALL aceitá-lo como no API-23.
- WHEN o deck em edição for trocado noutra aba ou no Hotwire com o detalhe da carta aberto THEN the system SHALL continuar enviando as operações para o deck exibido (P12) e mostrar o novo deck em edição só na próxima carga do detalhe.
- IF o deck exibido no detalhe for excluído noutra aba THEN the system SHALL responder `404 not_found` ao incremento (como o `InvalidForeignKey` do HTML), voltar ao último valor confirmado e exibir a mensagem (SCAR-32).
- WHEN o usuário sair pelo casco com o detalhe aberto THEN the system SHALL repetir a consulta da carta (SCAR-09) e ocultar a seção "Deck em edição", porque o logout limpa a sessão do Rails.
- WHEN o usuário navegar para outra carta com operações de deck pendentes THEN the system SHALL descartar as não enviadas e não aplicar resposta da carta antiga à nova.
- WHEN a carta do deck estiver ausente da fonte THEN the system SHALL mantê-la no deck, contando para as regras e com "carta fora da fonte" (Req. 14.19); o link dela pode cair no "Carta não encontrada" do SCAR-05 quando nenhuma variante é visível para o usuário.
- WHEN o deck tiver Leader e nenhuma entrada THEN the system SHALL exibir "Deck principal: 0 / 50" sem grupos e calcular "Na sua pasta" só com o Leader.
- WHEN o deck não tiver Leader THEN the system SHALL deixar a regra de cor fora do status e dos motivos (Req. 14.42), o que já sai do `Deck::Legality`.
- IF o texto importado passar de 200 linhas ou 10.000 caracteres THEN the system SHALL recusá-lo sem processar, com o limite em `fields.list` (Req. 14.29).
- IF o corpo de uma mutação de deck for JSON malformado THEN the system SHALL responder `400 invalid_json` (caso de borda do Req. 16).
- WHEN o mesmo nome for usado em dois decks THEN the system SHALL aceitar, como o HTML (nome não é único).
- WHEN `GET /api/decks/shortfall` e `GET /api/progress` responderem em ordens diferentes THEN the system SHALL exibir cada parte quando a sua chegar, sem uma esperar a outra.

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
|---|---|---|---|
| SDEC-01 | P1: Lista — rota e título (Req. 21.1) | - | Pending |
| SDEC-02 | P1: Lista — entrada do casco (Req. 21.2) | - | Pending |
| SDEC-03 | P1: Lista — sessão anônima (Req. 21.3) | - | Pending |
| SDEC-04 | P1: Lista — carga lenta (Req. 21.4) | - | Pending |
| SDEC-05 | P1: Lista — resposta antiga descartada (Req. 21.5) | - | Pending |
| SDEC-06 | P1: Lista — erro de carga (Req. 21.6) | - | Pending |
| SDEC-07 | P1: Lista — linha do deck (Req. 21.7) | - | Pending |
| SDEC-08 | P1: Lista — sem decks (Req. 21.8) | - | Pending |
| SDEC-09 | P1: Lista — ações (Req. 21.9) | - | Pending |
| SDEC-10 | P1: Criar/renomear — formulário (Req. 21.10) | - | Pending |
| SDEC-11 | P1: Criar/renomear — criado (Req. 21.11) | - | Pending |
| SDEC-12 | P1: Criar/renomear — renomeado (Req. 21.12) | - | Pending |
| SDEC-13 | P1: Criar/renomear — nome recusado (Req. 21.13) | - | Pending |
| SDEC-14 | P1: Criar/renomear — envio pendente (Req. 21.14) | - | Pending |
| SDEC-15 | P1: Excluir — confirmação (Req. 21.15) | - | Pending |
| SDEC-16 | P1: Excluir — excluído (Req. 21.16) | - | Pending |
| SDEC-17 | P1: Página — rota e título (Req. 21.17) | - | Pending |
| SDEC-18 | P1: Página — deck não encontrado (Req. 21.18) | - | Pending |
| SDEC-19 | P1: Página — em edição (Req. 21.19) | - | Pending |
| SDEC-20 | P1: Página — escolher deck em edição (Req. 21.20) | - | Pending |
| SDEC-21 | P1: Página — status e motivos (Req. 21.21) | - | Pending |
| SDEC-22 | P1: Página — aviso de Leader (Req. 21.22) | - | Pending |
| SDEC-23 | P1: Página — banidas (Req. 21.23) | - | Pending |
| SDEC-24 | P1: Página — na sua pasta (Req. 21.24) | - | Pending |
| SDEC-25 | P1: Página — Leader (Req. 21.25) | - | Pending |
| SDEC-26 | P1: Página — deck principal (Req. 21.26) | - | Pending |
| SDEC-27 | P1: Página — fora da fonte (Req. 21.27) | - | Pending |
| SDEC-28 | P1: Página — pedida, possuída, falta (Req. 21.28) | - | Pending |
| SDEC-29 | P1: Página — ações (Req. 21.29) | - | Pending |
| SDEC-30 | P1: Importar — formulário (Req. 21.30) | - | Pending |
| SDEC-31 | P1: Importar — importado (Req. 21.31) | - | Pending |
| SDEC-32 | P1: Importar — lista recusada (Req. 21.32) | - | Pending |
| SDEC-33 | P1: Detalhe — seção do deck em edição (Req. 21.33) | - | Pending |
| SDEC-34 | P1: Detalhe — sem deck em edição (Req. 21.34) | - | Pending |
| SDEC-35 | P1: Detalhe — quantidade e stepper (Req. 21.35) | - | Pending |
| SDEC-36 | P1: Detalhe — stepper otimista (Req. 21.36) | - | Pending |
| SDEC-37 | P1: Detalhe — `−` em zero (Req. 21.37) | - | Pending |
| SDEC-38 | P1: Detalhe — usar como Leader (Req. 21.38) | - | Pending |
| SDEC-39 | P1: Detalhe — Leader trocado (Req. 21.39) | - | Pending |
| SDEC-40 | P1: Pasta — bloco de falta (Req. 21.40) | - | Pending |
| SDEC-41 | P1: Pasta — bloco omitido (Req. 21.41) | - | Pending |
| SDEC-42 | P1: Pasta — falha do bloco (Req. 21.42) | - | Pending |
| SDEC-43 | P1: API — lista (Req. 21.43) | - | Pending |
| SDEC-44 | P1: API — criar (Req. 21.44) | - | Pending |
| SDEC-45 | P1: API — renomear (Req. 21.45) | - | Pending |
| SDEC-46 | P1: API — nome inválido (Req. 21.46) | - | Pending |
| SDEC-47 | P1: API — deck (Req. 21.47) | - | Pending |
| SDEC-48 | P1: API — excluir (Req. 21.48) | - | Pending |
| SDEC-49 | P1: API — escolher deck em edição (Req. 21.49) | - | Pending |
| SDEC-50 | P1: API — deck em edição no detalhe (Req. 21.50) | - | Pending |
| SDEC-51 | P1: API — incremento (Req. 21.51) | - | Pending |
| SDEC-52 | P1: API — decremento (Req. 21.52) | - | Pending |
| SDEC-53 | P1: API — teto de 50 (Req. 21.53) | - | Pending |
| SDEC-54 | P1: API — Leader no incremento (Req. 21.54) | - | Pending |
| SDEC-55 | P1: API — Leader do deck (Req. 21.55) | - | Pending |
| SDEC-56 | P1: API — concorrência (Req. 21.56) | - | Pending |
| SDEC-57 | P1: API — importar (Req. 21.57) | - | Pending |
| SDEC-58 | P1: API — lista recusada (Req. 21.58) | - | Pending |
| SDEC-59 | P1: API — o que falta (Req. 21.59) | - | Pending |
| SDEC-60 | P1: API — sessão, CSRF e isolamento (Req. 21.60) | - | Pending |
| SDEC-61 | P1: API — HTML inalterado (Req. 21.61) | - | Pending |

**Coverage:** 61 total, 0 mapped to tasks, 61 unmapped ⚠️ (Design e Tasks ainda não escritos)

## Implicit-Requirement Dimensions

| Dimension | Resolution |
|---|---|
| Input validation & bounds | SDEC-46 (nome 1–60), SDEC-53 (teto de 50), SDEC-54/55 (forma do Leader), SDEC-58 e edge cases de limite do texto, de codificação do `card_number` e de JSON malformado; as regras da lista são do Req. 14.25–14.29 |
| Failure / partial-failure states | SDEC-06, SDEC-18 (carga), SDEC-13, SDEC-32 (formulários recusados), SDEC-36 via SCAR-32 (operação de deck falha no meio da fila), SDEC-42 (bloco da pasta falha sem derrubar a pasta); importação tudo ou nada (SDEC-58) |
| Idempotency / retry / duplicate handling | SDEC-52 (decremento sem entrada é `200` sem gravar), SDEC-49 (escolher o mesmo deck de novo não muda nada), SDEC-55 (regravar o mesmo Leader); incremento não é idempotente e o SCAR-30 garante uma operação por toque. Importar duas vezes cria dois decks, como o HTML (Req. 14.24) |
| Auth boundaries & rate limits | SDEC-03 (rota protegida na SPA), SDEC-60 (sessão, CSRF, `Current.user.decks`, 404 para deck alheio). Rate limit N/A because nem o HTML nem a API o têm (Out of Scope) |
| Concurrency / ordering | SDEC-56 (atomicidade no banco, mesmo SQL do HTML), SDEC-36 (série por carta), SDEC-47 (retrato único), SDEC-05 (resposta antiga), edge case do deck em edição trocado noutra aba (P12) |
| Data lifecycle / expiry | SDEC-48 apaga deck e entradas, nunca coleção nem wishlist; a ingestão preserva Leader e entradas (Req. 14.40, sem mudança aqui); o deck em edição some com o logout e com a exclusão (SDEC-34) |
| Observability | N/A because a SPA não tem coleta remota de erro (decisão da `spa-fundacao`); a API registra o `500` no log como no Req. 16 |
| External-dependency failure | N/A because a fatia não chama serviço externo; as telas de deck não exibem imagem, e a API é tratada por SDEC-06, SDEC-42 e SCAR-32 |
| State-transition integrity | Deck em edição: só muda por criar, importar ou "Editar este deck" (SDEC-11, SDEC-31, SDEC-49) e some ao excluir ou sair (SDEC-34); quantidade no deck: valor exibido = confirmado + pendentes, volta ao confirmado em falha (SDEC-36), nunca abaixo de zero na tela (SDEC-37) nem fora de 1–50 no banco (SDEC-53, SDEC-56) |

## Success Criteria

- [ ] Playwright contra a API real compara `/app/baralhos/<id>` com `/decks/<id>` (status, motivos, aviso de Leader, grupos, ordem, "pedida, possuída, falta", "Na sua pasta") para um deck vazio, um incompleto, um inválido por cor e um válido, a 360px e a 1280px, nos dois temas, sem scroll horizontal.
- [ ] Um deck de 1 Leader + 50 montado só pela SPA aparece `válido` em `/decks` e na SPA; cinco toques rápidos em `+` no detalhe deixam `+5` no deck e o número final igual ao do `GET` seguinte.
- [ ] O texto de `/decks/<id>.txt` colado em `/app/baralhos/importar` gera um deck com o mesmo Leader e as mesmas entradas; uma lista com duas linhas ruins não cria deck e mostra as duas.
- [ ] O bloco "Faltando para os baralhos" de `/app/pasta` traz as mesmas cartas, faltas e decks que o da `/progress`.
- [ ] A suíte Rails passa sem edição, com os request tests novos e o teste de corrida da API somando todas as operações simultâneas.
