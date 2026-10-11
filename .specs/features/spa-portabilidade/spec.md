# Especificação — Import e export da coleção na SPA

Recorte da feature `spa-portabilidade` sobre `.context/requirements.md` Req. 22
(SPOR-NN, mesma numeração dos critérios). Em divergência, `.context/` vence
(AD-005). Depende da `api-fundacao` (Req. 16) e da `spa-fundacao` (Req. 17),
encerradas e verificadas, e da `spa-pasta` (Req. 20), especificada e ainda não
implementada, dona da tela de onde se chega ao import e ao export. A regra do
CSV é da feature `portabilidade` (Req. 10, POR-01..13), encerrada e verificada:
formato, parser, resolvedor, staging (AD-007), substituição (AD-006), teto de
10.000 linhas (AD-008) e gravação atômica por reivindicação continuam nos
objetos `CollectionCsv::*` e não mudam aqui. Escrita em 2026-10-10 sem o dono
presente; as escolhas dele estão marcadas `Confirmed? não` abaixo, e a de dado
está como `DECISÃO PENDENTE` (P13 do *Rastreamento de pendências*).

## Problem Statement

O import da coleção só existe no Hotwire: a ação "Importar coleção" da pasta da
SPA abre `/collection/import` com recarga (Req. 20.25), e a API não tem
endpoint de envio, pré-visualização nem confirmação. É a única escrita em massa
sobre o dado insubstituível do sistema, e a barreira do Req. 10.5 (ver antes,
confirmar depois) precisa atravessar a troca de front sem afrouxar: nada é
gravado sem confirmação, o efeito destrutivo aparece antes do botão e o resumo
descreve o que foi gravado, não a intenção. Esta feature leva envio,
pré-visualização e resumo para `/app/pasta/importar`, com paridade com as telas
Hotwire, cria os três endpoints que elas precisam, ensina o cliente HTTP a
mandar arquivo, e fecha a ida e volta com o download que já existe.

## Goals

- [ ] Para o mesmo arquivo e o mesmo usuário, `/app/pasta/importar/<token>` mostra os mesmos grupos, na mesma ordem, com as mesmas linhas, números de linha, antes e depois e motivos que `/collection/import/<token>`, em Playwright contra a API real a 360px e a 1280px, nos dois temas, sem scroll horizontal.
- [ ] Confirmar pela SPA grava em `collection_items` exatamente o que confirmar pelo HTML grava para o mesmo staging, e o resumo exibe as contagens que o banco confirma.
- [ ] Baixar a coleção pelo link da pasta e enviá-la sem edição pela SPA dá uma pré-visualização só com "Já está assim" e deixa a coleção idêntica depois de confirmar.
- [ ] A suíte Rails existente passa sem edição; os três endpoints novos têm request test de sessão, CSRF, isolamento entre usuários, contagem de consultas e corrida de confirmação.

## Out of Scope

| Feature | Reason |
|---|---|
| Endpoint de exportação sob `/api` | Todo endpoint de `/api` responde `application/json` (Req. 16.14); o download de `/collection/export` já entrega o CSV com `Content-Disposition`. Mesmo critério da `spa-pasta` (CSV) e da `spa-decks` (`/decks/<id>.txt`). Mover o download para a API exige emendar o Req. 16.14, decisão do dono. |
| Esconder "Confirmar" numa pré-visualização já confirmada ou vencida | O HTML exibe o botão e responde com a mensagem de "já confirmada ou expirou" ao clicar; expor o estado no payload é melhoria além da paridade. |
| Prazo de confirmação visível na tela | O HTML não mostra as duas horas do staging (`CollectionImport::VALIDADE`). |
| Validação de tamanho, extensão ou conteúdo no cliente | O HTML só usa `required` e `accept`; a regra é do parser (um dono só). |
| Arrastar e soltar o arquivo, progresso de envio em porcentagem | O HTML não oferece; melhoria além da paridade. |
| Import de wishlist ou de planilhas de terceiros, formatos além de CSV, desfazer import | Fora do Req. 10 (spec da `portabilidade`). |
| Import assíncrono | Mesma regra da `portabilidade`: só com medição reprovando o tempo de resposta. |
| Virtualização da lista de 10.000 linhas | O HTML renderiza todas as linhas; só entra se a medição da tela reprovar. |
| Limpeza automática do staging vencido | `CollectionImport.limpar_expiradas` continua manual, como hoje. |
| Limite de taxa no envio | Não existe no HTML nem na API (dívida de autenticação do `CLAUDE.md`). |
| Redirecionar `/collection/import` para a SPA, remover as telas Hotwire | Feature final `spa-troca` (AD-023). |
| Componente de campo de arquivo genérico | Nasce aqui só o que esta tela usa; não há outra fatia que envie arquivo. |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
|---|---|---|---|
| **DECISÃO PENDENTE P13** — resposta da confirmação perdida (rede ou tempo limite) | Manter o resumo não persistido, como o HTML: a SPA exibe "Não foi possível saber se a importação foi gravada. Confira a sua pasta antes de enviar o arquivo de novo." com link para a pasta, sem reenviar (SPOR-31). Alternativa: persistir o `Commit::Result` em `collection_imports` (migração) e devolvê-lo no `GET` da pré-visualização confirmada, para recuperar o resumo | A reivindicação condicional do `Commit` já impede gravar duas vezes, então o risco é só de informação: sem persistência, quem perde a resposta não vê o resumo nem as falhas por linha, e uma segunda tentativa recebe "já foi confirmada ou expirou. Sua coleção não foi alterada", frase que diz respeito só àquela tentativa. A persistência é migração sobre a tabela de staging e muda o que o HTML decidiu na T14 da `portabilidade` (não persistir), por isso fica com o dono | Não — DECISÃO PENDENTE, recomendada a primeira |
| Rotas da SPA | `/app/pasta/importar` (envio) e `/app/pasta/importar/<token>` (pré-visualização e, depois de confirmar, resumo) | Nomes em pt-BR sob a pasta, como `/app/pasta/desejos`; o import só é alcançado pela pasta (Req. 13.4, 20.25) | Não — escolha do agente |
| Rotas da API | `POST /api/collection/imports`, `GET /api/collection/imports/:token`, `POST /api/collection/imports/:token/confirm` | Inglês, como `/api/catalog`; o token como chave porque é a chave do staging e a do HTML (`collection/import/:token`); recurso no plural como `/api/decks` | Não — escolha do agente |
| Campo do arquivo | `file`, em `multipart/form-data` | Campos da API em inglês (`card_number`, `name`, `list`); o HTML usa `arquivo` e não muda | Não — escolha do agente |
| Recusa do arquivo | `422 validation_failed`, `message` "O arquivo não foi importado. Sua coleção não foi alterada." e `fields.file` com a mensagem do HTML para o caso (SPOR-37) | Mesmo desenho da recusa de lista da `spa-decks` (Req. 21.58): mensagem geral mais o motivo no campo; as frases do parser já estão em pt-BR e são as que o usuário do HTML lê | Não — escolha do agente |
| Corpo grande demais | O mesmo teto de 12 MB declarado e 8 MB de conteúdo do HTML, com `422` e a mesma frase, e não `413` | Um código só para "arquivo recusado" simplifica a tela; o teto é o mesmo objeto de regra | Não — escolha do agente |
| Confirmação não reivindicada | `409 import_closed`, código novo na lista do Req. 16, com a frase do HTML (SPOR-41) | Não é erro de campo (`validation_failed`) nem de registro ausente (`404`); `409` diz "o estado do recurso não permite" para os dois casos que o HTML junta (já confirmada, vencida) | Não — escolha do agente |
| Payload da pré-visualização | `{ token, filename, rows[] }`, cada linha com `line`, `classification`, `card_number`, `variant_code`, `card_name`, `quantity_before`, `quantity_after`, `message` (SPOR-38) | `line` já somado (+2) no servidor, um dono para a conta que a T13 da `portabilidade` documentou; `quantity_before` `null` sem registro (`NULL ≠ 0`, como a tela HTML); a ordem dos grupos é de exibição e fica na SPA | Não — escolha do agente |
| Classificações no payload | `removes`, `creates`, `updates`, `rejected`, `unchanged` (de `:zera`, `:cria`, `:atualiza`, `:rejeita`, `:inalterada`) | Cinco grupos e não três, pela mesma razão da tela HTML: o destrutivo (`removes`) e o inerte (`unchanged`) têm de ser visíveis | Não — escolha do agente |
| Payload do resumo | `{ filename, created, updated, removed, unchanged, rejected[], failures[] }`, com `updated` incluindo `removed` (SPOR-40) | `updated` é o número do Req. 10.4; `removed` é o recorte que o HTML exibe à parte. Recusas e falhas separadas, como a tela HTML | Não — escolha do agente |
| Depois do envio aceito | Navega para `/app/pasta/importar/<token>`, e a pré-visualização é lida pelo `GET` | Uma fonte só para a tela: recarregar a URL mostra o mesmo que o envio mostrou, como o redirect do HTML. Custa um `GET` a mais | Não — escolha do agente |
| Resumo e recarga | O resumo troca a pré-visualização na mesma URL; recarregar mostra a pré-visualização de novo, e confirmar outra vez dá `409` | Paridade com o F5 do HTML, que reenvia o POST e cai em "já confirmada" (T15 da `portabilidade`); o resumo não é persistido (P13) | Não — escolha do agente, paridade |
| Leitura de staging vencido | O `GET` devolve a pré-visualização vencida; só a confirmação recusa | Paridade: `find_by_token_for` não filtra por prazo e a tela HTML abre | Não — escolha do agente, paridade |
| Tempo limite | 60 s no envio e na confirmação; 15 s nas demais (SPOR-32) | O HTML não tem limite no cliente, e a confirmação perdida é o pior desfecho da feature (P13). Um CSV real tem cerca de 200 KB (4.917 variantes), mas o `Commit` de 10.000 linhas não foi medido | Não — escolha do agente; o design mede o `Commit` com 10.000 linhas |
| Cliente com `FormData` | O cliente da `spa-fundacao` passa a aceitar `FormData`, sem `Content-Type` próprio, com CSRF e reenvio único (SPOR-35) | O ESLint proíbe `fetch` fora de `client.ts` (SPA-06); um segundo cliente duplicaria CSRF e `401`. Reenviar `FormData` depois de `422 invalid_csrf_token` é seguro: a API não executa a action nesse caso (API-08) | Não — escolha do agente |
| Foco | Recusa do envio: o resumo de erro; resumo do import: o `h1` "Importação concluída"; entrada nas rotas: o `main#conteudo` do SPA | Mesmo padrão do SPA-17/19 e da `spa-decks`; a troca de pré-visualização por resumo não muda a rota, então o foco precisa de destino explícito | Não — escolha do agente |
| Sem toast no sucesso | O resumo é a resposta; nenhuma mensagem efêmera | Paridade: o HTML renderiza a página de resumo, sem flash | Não — escolha do agente, paridade |
| Texto vindo do arquivo | `card_name`, `filename` e `message` interpolados como texto; `{@html}` proibido nas três telas | O nome da carta é entrada hostil (T10 da `portabilidade`); o Svelte escapa interpolação por padrão | Não — escolha do agente |
| Export | Link de página inteira para `/collection/export`, já oferecido pela pasta (Req. 20.25) | Ver *Out of Scope*; o download depende só do cookie de sessão, que é o mesmo | Não — escolha do agente, paridade |
| Duas abas confirmando | A segunda recebe `409` e mantém a pré-visualização | A reivindicação do `Commit` é um `UPDATE … WHERE status = 'pendente'`; a SPA só exibe o desfecho | Não — escolha do agente |

**Open questions:** none - all resolved or logged above. A `DECISÃO PENDENTE` P13 tem opção recomendada, e o spec segue a recomendada até o dono decidir.

---

## User Stories

### P1: Envio do arquivo ⭐ MVP

**User Story**: Como colecionador, quero enviar o CSV da minha coleção pela SPA e ler, sem sair da tela, por que um arquivo foi recusado.

**Why P1**: É a porta de entrada; sem ela nada do resto acontece.

**Acceptance Criteria**:

1. The system SHALL exibir o envio em `/app/pasta/importar`, com o título de página "Importar coleção — Bindr", o cabeçalho de nível 1 "Importar coleção" e o texto "Envie o arquivo CSV exportado da sua coleção. Você verá o que vai mudar antes de qualquer alteração ser gravada.".
2. The system SHALL apontar a ação "Importar coleção" da pasta para `/app/pasta/importar`, com navegação sem recarga, no lugar do destino Hotwire do SPAS-25.
3. IF a sessão estiver anônima quando `/app/pasta/importar` ou `/app/pasta/importar/<token>` abrir THEN the system SHALL levar a `/app/entrar?return_to=<caminho atual, codificado>` sem chamar a API da tela.
4. The system SHALL oferecer o campo de arquivo obrigatório de rótulo "Arquivo CSV", com `accept="text/csv,.csv"`, e o botão "Pré-visualizar importação", sem validar no cliente tamanho, extensão nem conteúdo.
5. WHEN o usuário enviar o formulário THEN the system SHALL chamar `POST /api/collection/imports` pelo cliente da `spa-fundacao`, em `multipart/form-data` com o arquivo no campo `file`, com o botão desabilitado e novo envio ignorado enquanto pendente (SPA-21).
6. WHEN a API responder `201` THEN the system SHALL navegar para `/app/pasta/importar/<token>` sem recarga, com o `token` da resposta.
7. IF a API responder `422 validation_failed` THEN the system SHALL exibir, num resumo com `role="alert"` que recebe o foco, a `message` e cada mensagem de `fields.file` na ordem, ligar o resumo ao campo por `aria-describedby` com `aria-invalid="true"` e permanecer em `/app/pasta/importar`.
8. IF o envio falhar com outro erro THEN the system SHALL exibir a `message` como veio, e com `401` ou sessão trocada SHALL seguir o SPA-09 e o SPA-10, sem reenviar o arquivo em outra conta.

**Independent Test**: Vitest com cliente falso: sessão anônima navega para `/app/entrar?return_to=%2Fapp%2Fpasta%2Fimportar` sem chamar o cliente; envio chama `POST /api/collection/imports` com `FormData` contendo `file`; `201` navega para `/app/pasta/importar/abc`; `422` com `fields.file` mostra as duas frases, foca o resumo e marca o campo; duplo clique gera uma chamada só.

---

### P1: Pré-visualização ⭐ MVP

**User Story**: Como colecionador, quero ver o que cada linha do arquivo vai fazer na minha coleção, com o que destrói posse em primeiro lugar, antes de qualquer gravação.

**Why P1**: É a barreira do Req. 10.5; sem ela o import não deve existir.

**Acceptance Criteria**:

9. WHEN `/app/pasta/importar/<token>` abrir THEN the system SHALL chamar `GET /api/collection/imports/<token>` e exibir o título de página "Pré-visualização da importação — Bindr" e o cabeçalho de nível 1 "Confira o que vai mudar".
10. WHEN essa consulta passar de 200 ms sem resposta THEN the system SHALL marcar a região do conteúdo com `aria-busy="true"` e exibir "Carregando pré-visualização…".
11. IF a consulta responder `404` THEN the system SHALL exibir a `message` e o link "Enviar um arquivo" para `/app/pasta/importar`, sem "Tentar novamente", e com outro erro diferente de `401` SHALL exibir a `message` e "Tentar novamente", que repete a consulta.
12. The system SHALL exibir "Arquivo: <filename> — 1 linha analisada." ou "Arquivo: <filename> — N linhas analisadas." e o aviso "Nada foi gravado na sua coleção ainda. Sua coleção só muda quando você confirmar, no fim desta página.", com a primeira frase em destaque.
13. The system SHALL agrupar as linhas nesta ordem, cada grupo com cabeçalho de nível 2 "<título> (<quantidade>)" e frase de apoio, omitindo grupo vazio: `removes` "Remove da coleção", `creates` "Passa a constar", `updates` "Altera a quantidade", `rejected` "Não será importada", `unchanged` "Já está assim", com as frases de apoio do Req. 22.13.
14. The system SHALL exibir em cada linha o rótulo escrito ("Remove da coleção", "Cria", "Altera", "Recusada" ou "Sem alteração"), o `card_number`, o `variant_code` em estilo `code`, o `card_name`, "—" no lugar de código ausente e "Linha <line> do arquivo", na ordem da resposta dentro do grupo.
15. The system SHALL exibir a `message` na linha recusada, "Você não tem esta variante registrada; passará a ter nova quantidade <depois>." na linha `creates` e "De quantidade atual <antes> para nova quantidade <depois>." nas demais, com antes e depois em elementos próprios.
16. The system SHALL distinguir as classificações por rótulo escrito e por cabeçalho, e a distinção visual entre grupos SHALL usar forma ou peso além da cor (Req. 12.8).
17. The system SHALL exibir `card_name`, `filename` e `message` como texto, de modo que um `<script>` no nome da carta apareça escrito e não execute.
18. WHEN houver linhas `removes` THEN the system SHALL exibir, antes do botão de confirmar e no fluxo do documento, "Atenção: 1 carta que você possui hoje sai da sua coleção se você confirmar." ou "Atenção: N cartas que você possui hoje saem da sua coleção se você confirmar.", seguido de "Veja quais em “Remove da coleção”, no topo desta página.".
19. The system SHALL terminar a pré-visualização com o botão "Confirmar e gravar na minha coleção" e o texto "Se algo estiver errado, envie outro arquivo. Sair desta página sem confirmar deixa sua coleção exatamente como está.", com "envie outro arquivo" como link para `/app/pasta/importar` sem recarga.
20. WHILE a confirmação não for acionada the system SHALL manter `collection_items` inalterada, inclusive ao abrir, recarregar ou deixar a pré-visualização.

**Independent Test**: Vitest com payload falso de cinco classificações em ordem embaralhada: grupos na ordem fixa com contagens; grupo vazio ausente; `creates` sem "antes"; aviso de remoção com 1 e com 2; `<script>` no nome aparece como texto; plural de "linha analisada". Playwright: retrato de `collection_items` igual antes e depois de abrir e recarregar a pré-visualização.

---

### P1: Confirmação e resumo ⭐ MVP

**User Story**: Como colecionador, quero confirmar a importação e ler o que de fato foi gravado, inclusive o que saiu da coleção e o que não entrou.

**Why P1**: É a única escrita da feature; sem ela o import não grava nada, e sem o resumo o usuário não sabe se precisa corrigir algo (Req. 10.4).

**Acceptance Criteria**:

21. WHEN o usuário acionar "Confirmar e gravar na minha coleção" THEN the system SHALL chamar `POST /api/collection/imports/<token>/confirm` sem corpo, com o botão desabilitado e novo acionamento ignorado enquanto pendente.
22. WHEN a confirmação responder `200` THEN the system SHALL trocar a pré-visualização pelo resumo na mesma URL, com o título de página "Importação concluída — Bindr" e o cabeçalho de nível 1 "Importação concluída", que recebe o foco.
23. The system SHALL exibir no resumo "Arquivo: <filename> — sua coleção foi atualizada." e as contagens "Importadas" (`created`), "Atualizadas" (`updated`) e "Recusadas" (quantidade de `rejected`), nesta ordem, cada número com seu rótulo e a frase de apoio do Req. 22.23 em elemento próprio, inclusive com zero.
24. WHEN `removed` for maior que zero THEN the system SHALL exibir "1 dessas atualizações removeu a carta da sua coleção: o arquivo trazia zero para uma variante que você possuía." ou "N dessas atualizações removeram a carta da sua coleção: o arquivo trazia zero para N variantes que você possuía.".
25. WHEN `unchanged` for maior que zero THEN the system SHALL exibir "1 linha do arquivo já estava assim na sua coleção: nada mudou nelas." ou "N linhas do arquivo já estavam assim na sua coleção: nada mudou nelas.".
26. WHEN houver recusas THEN the system SHALL exibir "Confira estas linhas: 1 linha do arquivo não foi aplicada. Sua coleção não foi alterada por ela." ou "Confira estas linhas: N linhas do arquivo não foram aplicadas. Sua coleção não foi alterada por elas." e, para cada recusa, `card_number`, `variant_code`, `card_name`, "Linha <line> do arquivo" e a `message`.
27. WHEN houver falhas de gravação THEN the system SHALL exibir, separado das recusas, "Atenção: 1 linha não pôde ser gravada por um problema ao salvar. As demais entraram normalmente. Envie o arquivo de novo com essa linha para tentar outra vez." ou a forma plural, e cada falha como "Linha <line> do arquivo — <card_number> <variant_code>".
28. IF não houver recusa nem falha THEN the system SHALL produzir um resumo cujo texto não contém "rejeitada", "falha" nem "erro".
29. The system SHALL terminar o resumo com os links "Ver minha coleção", para `/app/pasta`, e "importar outro arquivo", para `/app/pasta/importar`, ambos sem recarga.
30. IF a confirmação responder `409 import_closed` THEN the system SHALL manter a pré-visualização e exibir a `message` da API com `role="alert"`.
31. IF a confirmação falhar sem resposta ou por tempo limite THEN the system SHALL exibir "Não foi possível saber se a importação foi gravada. Confira a sua pasta antes de enviar o arquivo de novo." com o link "Ver minha coleção" para `/app/pasta`, sem reenviar a confirmação (DECISÃO PENDENTE P13).
32. The system SHALL aplicar tempo limite de 60 s ao envio e à confirmação, mantendo os 15 s do SPA-12 nas demais chamadas.

**Independent Test**: Vitest com cliente falso: `200` mostra o resumo, foca o `h1` e troca o título; contagens com `updated` 3 e `removed` 1 exibem 3 em "Atualizadas" e a frase de remoção com 1; sem recusa e sem falha o texto não tem "rejeitada", "falha" nem "erro"; com recusa, a frase "Confira estas linhas" aparece; `409` mantém a pré-visualização com alerta; `network_error` mostra a frase do SPOR-31 e o cliente recebe uma chamada só; relógio falso confirma 60 s no envio e 15 s no `GET`.

---

### P1: Ida e volta com o export ⭐ MVP

**User Story**: Como colecionador, quero baixar a minha coleção e devolvê-la sem edição pela SPA sem que nada mude, para confiar que o arquivo é meu dado e não uma cópia aproximada.

**Why P1**: É o POR-11 atravessando a troca de front; prova que a SPA não deforma o arquivo nem a classificação.

**Acceptance Criteria**:

33. The system SHALL manter "Baixar minha coleção (CSV)" da pasta como link de página inteira para `/collection/export` (SPAS-25), sem endpoint de exportação sob `/api`.
34. WHEN o arquivo baixado por esse link for enviado sem edição pela SPA THEN the system SHALL apresentar só o grupo "Já está assim" e, depois de confirmar, SHALL deixar `collection_items` do usuário idêntica à exportada.

**Independent Test**: Playwright contra a API real: usuário com posse em três sets e uma variante zerada baixa o CSV pelo link da pasta, envia pela SPA, vê só "Já está assim (N)", confirma e o retrato de `collection_items` é o mesmo de antes.

---

### P1: Cliente HTTP com arquivo ⭐ MVP

**User Story**: Como quem implementa a SPA, quero que o mesmo cliente que fala JSON mande arquivo, para que CSRF, `401` e sessão trocada valham também no upload.

**Why P1**: Sem ele o envio não sai sem quebrar o SPA-06.

**Acceptance Criteria**:

35. The system SHALL aceitar corpo `FormData` no cliente HTTP da `spa-fundacao`, enviando sem `Content-Type` próprio, com `X-CSRF-Token` e com a renovação e o reenvio único do SPA-10, e o cliente SHALL continuar o único módulo que chama `fetch`.

**Independent Test**: Vitest com `fetch` falso: mutação com `FormData` sai sem header `Content-Type` e com `X-CSRF-Token`; `422 invalid_csrf_token` renova e reenvia o mesmo `FormData` uma vez; com outro e-mail na renovação, não reenvia; o ESLint continua recusando `fetch` fora de `client.ts`.

---

### P1: API do import ⭐ MVP

**User Story**: Como SPA, quero endpoints JSON de envio, leitura e confirmação do import, com o mesmo parser, resolvedor e gravação do HTML, para que as duas telas gravem a mesma coisa.

**Why P1**: A SPA não tem outro caminho até o staging e a gravação.

**Acceptance Criteria**:

36. WHEN `POST /api/collection/imports` chegar com sessão, CSRF válido e arquivo aceito pelo parser THEN the system SHALL criar a pré-visualização em `collection_imports`, dona do usuário da sessão, com o mesmo parser, resolvedor e nome de arquivo saneado do HTML, sem escrever em `collection_items`, e SHALL responder `201` no formato do SPOR-38.
37. IF faltar o arquivo, o corpo declarar mais de 12 MB ou o parser recusar o arquivo THEN the system SHALL responder `422 validation_failed` com `message` "O arquivo não foi importado. Sua coleção não foi alterada." e `fields.file` com a mensagem do HTML para o mesmo caso, sem criar pré-visualização.
38. WHEN `GET /api/collection/imports/:token` chegar THEN the system SHALL responder `200` com `{ data: { token, filename, rows } }`, `rows` na ordem do arquivo com `line` (cabeçalho na linha 1), `classification` (`removes`, `creates`, `updates`, `rejected` ou `unchanged`), `card_number`, `variant_code`, `card_name` do arquivo, `quantity_before` (`null` sem registro, nunca `0`), `quantity_after` (`null` na recusada) e `message` (`null` fora da recusada), também depois do prazo de confirmação.
39. IF o token não existir ou for de outro usuário THEN the system SHALL responder o mesmo `404 not_found` na leitura e na confirmação, sem gravar.
40. WHEN `POST /api/collection/imports/:token/confirm` chegar com sessão e CSRF válidos sobre pré-visualização pendente e no prazo THEN the system SHALL gravar pelo mesmo `CollectionCsv::Commit` do HTML, só o que o staging guarda e sem ler outro parâmetro, e SHALL responder `200` com `{ data: { filename, created, updated, removed, unchanged, rejected, failures } }`, `updated` incluindo `removed`, `rejected` com `line`, `card_number`, `variant_code`, `card_name` e `message`, e `failures` com `line`, `card_number` e `variant_code`.
41. IF a pré-visualização já estiver confirmada ou vencida THEN the system SHALL responder `409 import_closed` com "Esta importação já foi confirmada ou expirou. Sua coleção não foi alterada; envie o arquivo de novo se quiser importar.", sem gravar.
42. WHEN duas confirmações do mesmo token chegarem ao mesmo tempo THEN the system SHALL gravar uma só vez e responder `409 import_closed` à outra.
43. The system SHALL exigir sessão nos três endpoints (`401 unauthenticated`) e CSRF nas duas mutações (`422 invalid_csrf_token`), e SHALL ler e gravar só registros do usuário da sessão, ignorando `user_id` no corpo ou na query.
44. The system SHALL resolver o envio e a leitura da pré-visualização num número de consultas que não cresce com a quantidade de linhas do arquivo.
45. The system SHALL manter os controllers e as rotas HTML inalterados, com a suíte existente passando sem edição.

**Independent Test**: Request tests: envio aceito cria um `collection_imports` e não muda `collection_items`; envio de arquivo com `;`, vazio, sem arquivo e com `Content-Length` acima de 12 MB dá `422` com a frase do HTML em `fields.file` e nenhum staging; leitura com `line` +2 e `quantity_before` `null` em `creates`; token alheio e inexistente dão o mesmo `404`; confirmação grava o mesmo que o HTML para staging igual; segunda confirmação e staging vencido dão `409`; corrida com duas threads grava uma vez; sem sessão `401`, sem CSRF `422`, `?user_id=` ignorado; contagem de consultas igual com 2 e com 200 linhas.

---

### P2: Tela em 360px e nos dois temas

**User Story**: Como colecionador no celular, quero ler a pré-visualização e o resumo sem rolar para o lado e acertar os botões com o dedo.

**Why P2**: Não muda o que é gravado, mas a pré-visualização com nomes longos é a tela mais larga da feature.

**Acceptance Criteria**:

46. The system SHALL exibir as três telas em 360px sem scroll horizontal, nos dois temas, com nome de carta e código longos quebrando linha, e com alvo de no mínimo 44px nos botões.

**Independent Test**: Playwright a 360px nos dois temas, com um arquivo de nome de carta de 120 caracteres e `variant_code` `tcgplayer:1234567890`: `scrollWidth` igual a `clientWidth` nas três telas; caixa dos botões com 44px ou mais.

---

## Edge Cases

- WHEN o arquivo trouxer a mesma variante em duas linhas THEN the system SHALL exibir a ocorrência anterior em "Não será importada" com "Esta variante aparece mais de uma vez no arquivo; vale a última ocorrência." e a última no seu grupo, como o resolvedor já classifica.
- WHEN o arquivo tiver só o cabeçalho THEN the system SHALL exibir "Arquivo: <filename> — 0 linhas analisadas.", nenhum grupo e o botão de confirmar, como o HTML; confirmar SHALL dar um resumo com três zeros.
- IF o arquivo vier com BOM, colunas em outra ordem ou `;` como separador THEN the system SHALL aplicar a regra do parser do Req. 10 sem mudança: BOM e ordem aceitos, `;` recusado com a frase que diz o separador esperado em `fields.file`.
- IF o arquivo não estiver em UTF-8 THEN the system SHALL responder `422` com "O arquivo não está em UTF-8. Salve a planilha como CSV UTF-8 e envie novamente." em `fields.file`, e não `500`.
- IF o arquivo tiver mais de 10.000 linhas de dado THEN the system SHALL recusá-lo inteiro com a frase do parser que diz o limite, sem criar pré-visualização (AD-008).
- WHEN a sessão expirar entre a pré-visualização e a confirmação THEN the system SHALL receber `401`, seguir o SPA-09 com `return_to` igual a `/app/pasta/importar/<token>` e, depois de entrar com a mesma conta dentro do prazo, SHALL permitir confirmar.
- WHEN outra conta entrar em outra aba antes da confirmação THEN the system SHALL seguir o SPA-10, sem reenviar a confirmação, e a pré-visualização aberta com a outra conta SHALL dar `404`.
- WHEN o usuário recarregar a URL depois do resumo THEN the system SHALL exibir a pré-visualização de novo e, se confirmar, SHALL receber `409 import_closed` sem gravar.
- WHEN o usuário mudar a coleção por outro caminho entre a pré-visualização e a confirmação THEN the system SHALL exibir no resumo as contagens que o `Commit` gravou, não as da pré-visualização.
- IF o `filename` saneado for `colecao.csv` porque o original não tinha caractere aproveitável THEN the system SHALL exibir `colecao.csv`.
- IF o `token` no caminho tiver caractere reservado THEN the system SHALL codificá-lo na chamada à API, e um token malformado SHALL dar `404`.
- WHEN a pré-visualização tiver 10.000 linhas THEN the system SHALL exibi-las todas, e o design SHALL medir o tempo de renderização antes de qualquer virtualização.
- IF o corpo do envio não for `multipart/form-data` THEN the system SHALL tratar como arquivo ausente (`422` com a frase de arquivo ausente), nunca `500`.

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
|---|---|---|---|
| SPOR-01 | P1: Envio — rota, título e texto (Req. 22.1) | - | Pending |
| SPOR-02 | P1: Envio — ação da pasta (Req. 22.2) | - | Pending |
| SPOR-03 | P1: Envio — sessão anônima (Req. 22.3) | - | Pending |
| SPOR-04 | P1: Envio — campo e botão (Req. 22.4) | - | Pending |
| SPOR-05 | P1: Envio — chamada multipart e pendência (Req. 22.5) | - | Pending |
| SPOR-06 | P1: Envio — aceito leva à pré-visualização (Req. 22.6) | - | Pending |
| SPOR-07 | P1: Envio — recusa com resumo e foco (Req. 22.7) | - | Pending |
| SPOR-08 | P1: Envio — outros erros (Req. 22.8) | - | Pending |
| SPOR-09 | P1: Pré-visualização — consulta e título (Req. 22.9) | - | Pending |
| SPOR-10 | P1: Pré-visualização — carga lenta (Req. 22.10) | - | Pending |
| SPOR-11 | P1: Pré-visualização — 404 e erro (Req. 22.11) | - | Pending |
| SPOR-12 | P1: Pré-visualização — arquivo e aviso (Req. 22.12) | - | Pending |
| SPOR-13 | P1: Pré-visualização — cinco grupos (Req. 22.13) | - | Pending |
| SPOR-14 | P1: Pré-visualização — linha (Req. 22.14) | - | Pending |
| SPOR-15 | P1: Pré-visualização — antes, depois e motivo (Req. 22.15) | - | Pending |
| SPOR-16 | P1: Pré-visualização — não só por cor (Req. 22.16) | - | Pending |
| SPOR-17 | P1: Pré-visualização — texto do arquivo como texto (Req. 22.17) | - | Pending |
| SPOR-18 | P1: Pré-visualização — aviso de remoção (Req. 22.18) | - | Pending |
| SPOR-19 | P1: Pré-visualização — confirmar e abandonar (Req. 22.19) | - | Pending |
| SPOR-20 | P1: Pré-visualização — nada gravado (Req. 22.20) | - | Pending |
| SPOR-21 | P1: Confirmação — chamada e pendência (Req. 22.21) | - | Pending |
| SPOR-22 | P1: Resumo — troca, título e foco (Req. 22.22) | - | Pending |
| SPOR-23 | P1: Resumo — três contagens (Req. 22.23) | - | Pending |
| SPOR-24 | P1: Resumo — removidas (Req. 22.24) | - | Pending |
| SPOR-25 | P1: Resumo — inalteradas (Req. 22.25) | - | Pending |
| SPOR-26 | P1: Resumo — recusas (Req. 22.26) | - | Pending |
| SPOR-27 | P1: Resumo — falhas de gravação (Req. 22.27) | - | Pending |
| SPOR-28 | P1: Resumo — sem vocabulário de erro (Req. 22.28) | - | Pending |
| SPOR-29 | P1: Resumo — links finais (Req. 22.29) | - | Pending |
| SPOR-30 | P1: Confirmação — 409 (Req. 22.30) | - | Pending |
| SPOR-31 | P1: Confirmação — resposta perdida (Req. 22.31, P13) | - | Pending |
| SPOR-32 | P1: Tempo limite de 60 s (Req. 22.32) | - | Pending |
| SPOR-33 | P1: Export pelo link da pasta (Req. 22.33) | - | Pending |
| SPOR-34 | P1: Ida e volta idempotente (Req. 22.34) | - | Pending |
| SPOR-35 | P1: Cliente com `FormData` (Req. 22.35) | - | Pending |
| SPOR-36 | P1: API — envio aceito (Req. 22.36) | - | Pending |
| SPOR-37 | P1: API — envio recusado (Req. 22.37) | - | Pending |
| SPOR-38 | P1: API — leitura da pré-visualização (Req. 22.38) | - | Pending |
| SPOR-39 | P1: API — token alheio ou inexistente (Req. 22.39) | - | Pending |
| SPOR-40 | P1: API — confirmação e resumo (Req. 22.40) | - | Pending |
| SPOR-41 | P1: API — já confirmada ou vencida (Req. 22.41) | - | Pending |
| SPOR-42 | P1: API — corrida de confirmação (Req. 22.42) | - | Pending |
| SPOR-43 | P1: API — sessão, CSRF e isolamento (Req. 22.43) | - | Pending |
| SPOR-44 | P1: API — consultas constantes (Req. 22.44) | - | Pending |
| SPOR-45 | P1: API — HTML inalterado (Req. 22.45) | - | Pending |
| SPOR-46 | P2: Tela em 360px e alvos de 44px (Req. 22.46) | - | Pending |

**Coverage:** 46 total, 0 mapped to tasks, 46 unmapped ⚠️ (`design.md` e `tasks.md` ainda não escritos).

---

## Success Criteria

- [ ] Para o mesmo arquivo com as cinco classificações, a pré-visualização da SPA e a do HTML mostram os mesmos grupos, linhas, números de linha, antes e depois e motivos, em Playwright contra a API real a 360px e a 1280px, nos dois temas, sem scroll horizontal.
- [ ] Para o mesmo staging, confirmar pela API e pelo HTML deixa `collection_items` idêntica, e o resumo da SPA exibe as contagens que o banco confirma.
- [ ] Baixar pelo link da pasta, enviar sem edição e confirmar deixa `collection_items` idêntica, com a pré-visualização só em "Já está assim".
- [ ] Nenhuma rota da feature altera `collection_items` antes da confirmação, provado por retrato da tabela antes e depois do envio, da leitura e da recarga.
- [ ] Duas confirmações simultâneas do mesmo token gravam uma vez só.
- [ ] O envio e a leitura da pré-visualização executam o mesmo número de consultas SQL com 2 e com 200 linhas.
- [ ] A suíte Rails existente passa sem edição e nenhum controller ou view HTML muda nesta feature.
