# Especificação — Fundação da API JSON

Recorte da feature `api-fundacao` sobre `.context/requirements.md` Req. 16. Em
divergência, `.context/` vence (AD-005).

## Problem Statement

O dono vai trocar o front Hotwire por uma SPA SvelteKit (AD-023), e hoje o Rails
não tem API JSON: nenhum controller responde JSON, o `jbuilder` está no
`Gemfile` sem uso e o concern `Authentication` responde a quem não tem sessão
com um redirect 302 para `/session/new`, que a SPA não consegue usar. Esta
feature cria a base comum a todas as fatias da API, com sessão, CSRF, formato de
erro e convenções de serialização, e entrega o catálogo como a primeira fatia,
que exercita essas convenções num payload real.

## Goals

- [ ] A SPA consegue entrar, cadastrar, sair e descobrir a sessão atual só com chamadas JSON em `/api`, com CSRF verificado em toda mutação.
- [ ] Todo erro de `/api` chega no mesmo formato `{ "error": { "code", "message", "fields" } }`, com mensagem em pt-BR, e nunca como HTML ou redirect.
- [ ] A SPA monta a grade, os filtros e o detalhe da carta só com `/api/catalog`, `/api/catalog/filters` e `/api/cards/:card_number`.
- [ ] A suíte HTML existente continua verde sem alteração: nenhum controller HTML muda.

## Out of Scope

| Feature | Reason |
|---|---|
| Fatias de coleção/wishlist, pasta, decks e portabilidade | Decisão do dono em 2026-10-10: cada uma vira feature própria depois desta. |
| A SPA SvelteKit em `frontend/`, temas, animação, Vitest e Playwright | Lado front, tratado em outra sessão (`spa-fundacao`). |
| Catch-all servindo `index.html`, estágio Node no `Dockerfile`, remoção do Hotwire | Só fazem sentido quando a SPA existir. A remoção do Hotwire espera a paridade (AD-023). |
| Quantidade da carta no deck em edição, no detalhe da carta | Pertence à fatia de decks, que traz `select` e `session[:editing_deck_id]` para a API. |
| CORS | A SPA roda na mesma origem do Rails (AD-023); não há requisição de outra origem a autorizar. |
| Autenticação por token (Bearer, JWT) | A sessão continua no cookie assinado `httponly`, `same_site: :lax`, o mesmo do HTML. |
| Limite de tentativas de login | Dívida aberta em `sessions_controller.rb`: sem cache store compartilhado o `rate_limit` não limita nada. Continua aberta e vale igualmente para `POST /api/session`. |
| OpenAPI, versionamento (`/v1`), tipos TypeScript gerados | Decisão do dono em 2026-10-10: `jbuilder`, sem geração de contrato (AD-024). |
| Tradução das mensagens de validação das páginas HTML | O cadastro HTML exibe hoje as mensagens padrão em inglês. A correção é da página HTML e não desta feature, que só garante pt-BR na API. |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
|---|---|---|---|
| Serialização | `jbuilder`, com views `.json.jbuilder` e partials por entidade | Já está no `Gemfile` e é o padrão do Rails; o volume é pequeno e paginado | Sim — dono, 2026-10-10 |
| Escopo | Infraestrutura + catálogo (leitura pública) | As convenções de serialização só se provam num payload real; o catálogo é a primeira tela da SPA | Sim — dono, 2026-10-10 |
| Classe base | `Api::BaseController < ActionController::Base`, com `Authentication` | `ActionController::API` não tem cookies assinados nem CSRF por padrão; a sessão é o cookie (AD-023) | Sim — handoff do dono, 2026-10-10 |
| Prefixo | `/api/*`, sem versão | Decisão do dono; a SPA é o único cliente e sai do mesmo deploy | Sim — dono, 2026-10-10 |
| Entrega do token CSRF | No corpo de `GET /api/session` e das respostas de login, cadastro e logout, no campo `csrf_token`; a SPA o devolve no header `X-CSRF-Token` | `reset_session` em login e logout troca o segredo do CSRF; um token entregue só uma vez ficaria inválido depois do login. O Rails lê `X-CSRF-Token` nativamente | Sim — handoff do dono, 2026-10-10 |
| Status da falha de CSRF | `422` com `code: "invalid_csrf_token"` | É o status que o Rails já atribui a `InvalidAuthenticityToken` | Sim — dono, 2026-10-10 |
| Status de credencial inválida | `401` com `code: "invalid_credentials"` e mensagem igual para e-mail inexistente e senha errada | Mesma regra anti-oráculo do `SessionsController` HTML | Sim — dono, 2026-10-10 |
| Logout sem sessão | `401 unauthenticated`, como qualquer endpoint protegido | Mantém uma regra só; não há sessão a encerrar | Sim — dono, 2026-10-10 |
| Envelope | Sucesso em `{ "data": ... }`, listas paginadas com `"meta"`; erro em `{ "error": ... }` | A SPA distingue sucesso de erro pela chave de topo, sem depender só do status | Sim — dono, 2026-10-10 |
| `fields` sem erro de campo | Objeto vazio `{}`, nunca `null` nem ausente | O cliente lê `error.fields.email` sem testar a existência de `fields` | Sim — dono, 2026-10-10 |
| Posse e desejo para o anônimo | `owned_quantity` e `wishlist_target` vêm `null`; para o usuário autenticado sem item, `0` e `null` respectivamente | `null` significa "não se aplica", distinto de "tem zero", como no `counter` | Sim — dono, 2026-10-10 |
| Valor monetário | `price` é `{ "amount": "1.70", "currency": "USD", "observed_at": "<ISO 8601 UTC>" }` ou `null`; `amount` em string decimal com duas casas | Float em JSON perde precisão; a moeda e a data vêm junto porque a AD-022 as guarda juntas | Sim — handoff do dono, 2026-10-10 |
| Mensagens de validação | Em pt-BR na API, com tradução própria das mensagens que os models de usuário emitem | O app não tem locale pt-BR (`config/locales/` só tem `en.yml`) e a regra do dono é mensagem de erro ao usuário em português. Trocar o `default_locale` mudaria o HTML, fora de escopo | Sim — dono, 2026-10-10; o design decide o mecanismo |
| `allow_browser` na API | Mantido, respondendo `406` com `code: "unsupported_browser"` em JSON | O handoff pede JSON; o comportamento HTML (página `406-unsupported-browser.html`) não serve à SPA | Sim — handoff do dono, 2026-10-10 |
| Exceção não tratada | `500` com `code: "internal_error"` e mensagem genérica, sem classe, mensagem ou stack da exceção | Detalhe interno no corpo vaza implementação ao cliente | Sim — dono, 2026-10-10 |

**Open questions:** none - all resolved or logged above.

---

## User Stories

### P1: Sessão e CSRF em JSON ⭐ MVP

**User Story**: Como SPA do Bindr, quero descobrir a sessão atual, entrar, cadastrar e sair por JSON, recebendo o token CSRF válido a cada troca de sessão, para operar com o mesmo cookie seguro do HTML.

**Why P1**: Sem isso nenhuma fatia autenticada da API funciona.

**Acceptance Criteria**:

1. WHEN `GET /api/session` chegar sem sessão THEN the system SHALL responder `200` com `{ "data": { "user": null, "csrf_token": "<token>" } }`.
2. WHEN `GET /api/session` chegar com sessão válida THEN the system SHALL responder `200` com `data.user.email` igual ao e-mail do usuário da sessão e `data.csrf_token` preenchido.
3. WHEN `POST /api/session` chegar com `email` e `password` corretos THEN the system SHALL criar um registro `Session`, gravar o cookie assinado `session_id` (`httponly`, `same_site: lax`) e responder `200` com `data.user.email` e um `data.csrf_token` novo.
4. IF `POST /api/session` chegar com e-mail inexistente ou senha errada THEN the system SHALL responder `401` com `error.code` `"invalid_credentials"`, `error.message` `"E-mail ou senha inválidos."`, o mesmo corpo nos dois casos, e sem criar `Session` nem gravar cookie.
5. WHEN `DELETE /api/session` chegar com sessão válida THEN the system SHALL apagar o registro `Session`, remover o cookie `session_id` e responder `200` com `{ "data": { "user": null, "csrf_token": "<token novo>" } }`.
6. WHEN `POST /api/registration` chegar com `user[email]`, `user[password]` e `user[password_confirmation]` válidos THEN the system SHALL criar o `User`, autenticá-lo como no item 3 e responder `201` com `data.user.email` e um `data.csrf_token` novo.
7. IF `POST /api/registration` chegar com dados inválidos (e-mail vazio ou já usado, senha com menos de 8 caracteres, confirmação diferente) THEN the system SHALL responder `422` com `error.code` `"validation_failed"`, `error.fields` com cada atributo inválido apontando para a lista de mensagens em pt-BR, sem criar `User` nem `Session`.
8. IF uma requisição `POST`, `PATCH`, `PUT` ou `DELETE` em `/api` chegar sem header `X-CSRF-Token` válido para a sessão do Rails THEN the system SHALL responder `422` com `error.code` `"invalid_csrf_token"` e não executar a action, inclusive no login e no cadastro.
9. WHEN login, cadastro ou logout terminarem com sucesso THEN the system SHALL recusar com `422 invalid_csrf_token` uma mutação seguinte que envie o `csrf_token` anterior à troca e aceitar a que envie o `csrf_token` devolvido na resposta.

**Independent Test**: Teste de integração: `GET /api/session` → `POST /api/session` com o token → `GET /api/session` mostra o e-mail → `DELETE /api/session` com o token novo → `GET /api/session` volta a `user: null`.

---

### P1: Contrato de acesso e de erro ⭐ MVP

**User Story**: Como SPA do Bindr, quero que toda resposta de `/api` seja JSON, que a falta de sessão seja `401` e que todo erro venha num formato só, para tratar falhas num lugar só do cliente.

**Why P1**: A SPA não segue redirect para página HTML, e cada fatia seguinte herda este contrato.

**Acceptance Criteria**:

10. IF uma requisição chegar sem sessão a um endpoint de `/api` que não declare acesso público THEN the system SHALL responder `401` com `error.code` `"unauthenticated"` e `error.message` `"Faça login para continuar."`, sem redirect e sem gravar `session[:return_to_after_authenticating]`.
11. The system SHALL responder todo erro de `/api` com o corpo `{ "error": { "code": <string snake_case>, "message": <string pt-BR>, "fields": <objeto> } }`, com `fields` igual a `{}` quando o erro não é de campo.
12. IF a action levantar `ActiveRecord::RecordNotFound` THEN the system SHALL responder `404` com `error.code` `"not_found"` e `error.message` `"Não encontrado."`.
13. IF a requisição chegar a um caminho sob `/api` sem rota THEN the system SHALL responder `404` com `error.code` `"not_found"` em JSON, nunca HTML.
14. The system SHALL responder todo endpoint de `/api` com `Content-Type: application/json`, independentemente do header `Accept` e de extensão no caminho.
15. IF `allow_browser` recusar o navegador THEN the system SHALL responder `406` com `error.code` `"unsupported_browser"` em JSON.
16. IF uma exceção não tratada escapar de uma action de `/api` THEN the system SHALL responder `500` com `error.code` `"internal_error"`, `error.message` `"Erro inesperado. Tente novamente."` e nenhum dado da exceção no corpo.
17. The system SHALL manter inalterado o comportamento dos controllers HTML e das rotas fora de `/api`: a suíte existente passa sem edição. Extrair lógica de um controller HTML para objeto compartilhado com a API é permitido (design aprovado em 2026-10-10).

**Independent Test**: Teste de integração sobre um endpoint protegido de teste e sobre os do catálogo: anônimo recebe `401` JSON; caminho inexistente sob `/api` recebe `404` JSON; `Accept: text/html` continua recebendo JSON.

---

### P1: Catálogo em JSON ⭐ MVP

**User Story**: Como SPA do Bindr, quero listar, filtrar e abrir cartas por JSON, com as variantes separadas da carta e a posse do usuário da sessão, para montar a grade e o detalhe sem o HTML.

**Why P1**: É a primeira tela da SPA e o primeiro payload que prova as convenções de serialização.

**Acceptance Criteria**:

18. WHEN `GET /api/catalog` chegar THEN the system SHALL responder `200` com `data` igual à lista de cartas da página que o `CatalogQuery` devolve para os mesmos parâmetros, na mesma ordem, e `meta` com `page`, `per_page`, `total_count`, `total_pages` e `active_filters`.
19. IF `GET /api/catalog` chegar com parâmetro desconhecido ou valor inválido THEN the system SHALL ignorá-lo e responder `200`, como o `CatalogQuery` (design §4.2).
20. WHEN `GET /api/catalog` chegar com `owned=owned` ou `owned=missing` e sessão válida THEN the system SHALL filtrar pela coleção do usuário da sessão; sem sessão, the system SHALL ignorar o filtro; em nenhum caso um `user_id` nos parâmetros muda de quem é a coleção lida.
21. The system SHALL incluir em cada carta de `GET /api/catalog` só as variantes presentes na fonte (`CardVariant.present`), ordenadas por `variant_code`.
22. WHEN `GET /api/catalog/filters` chegar THEN the system SHALL responder `200` com `data` igual a `CatalogQuery.filter_options` (`colors`, `card_types`, `rarities`, `sets` com `code` e `name`).
23. WHEN `GET /api/cards/:card_number` chegar para uma carta existente THEN the system SHALL responder `200` com a carta e as variantes que o detalhe HTML lista (presentes na fonte e, para o usuário da sessão, as ausentes que ele tem na coleção ou na wishlist, com `in_source: false`), ordenadas por `variant_code`.
24. WHEN `GET /api/cards/:card_number` chegar com `?variant=<variant_code>` de uma variante listada THEN the system SHALL devolver esse código em `data.featured_variant_code`; com código ausente, de outra carta ou inválido, the system SHALL devolver a primeira variante presente, ou a primeira listada quando nenhuma estiver presente (regra do CNF-42).
25. IF `GET /api/cards/:card_number` chegar com `card_number` inexistente, ou de carta cujas variantes estão todas ocultas para quem pede THEN the system SHALL responder `404` com `error.code` `"not_found"`.
26. The system SHALL atender `/api/catalog`, `/api/catalog/filters` e `/api/cards/:card_number` sem sessão.

**Independent Test**: Integração com fixtures: anônimo lista o catálogo com filtro de cor e recebe as mesmas cartas do `CatalogQuery`; usuário com uma variante na coleção abre o detalhe e vê `owned_quantity` dela.

---

### P1: Convenções de serialização ⭐ MVP

**User Story**: Como SPA do Bindr, quero um formato de carta e de variante estável e sem ambiguidade, para não confundir "não tem" com "zero" nem perder centavos.

**Why P1**: É o contrato que as fatias seguintes reutilizam; corrigir depois quebra o front.

**Acceptance Criteria**:

27. The system SHALL serializar a carta e a variante como objetos distintos: os campos da carta (`card_number`, `name`, `card_type`, `colors`, `cost`, `life`, `power`, `counter`, `attributes`, `traits`, `block_icon`, `effect_text`, `trigger_text`, `set`) no objeto da carta e os da variante (`variant_code`, `art_kind`, `rarity`, `illustrator`, `set`, `image_url`, `price`, `in_source`, `owned_quantity`, `wishlist_target`) em `variants[]`.
28. The system SHALL serializar `cost`, `life`, `power`, `counter` e `block_icon` como `null` quando a coluna é NULL, nunca como `0`.
29. The system SHALL serializar `price` como `{ "amount": <string com duas casas>, "currency": <ISO 4217>, "observed_at": <ISO 8601 UTC> }` quando a variante tem preço, `"0.00"` quando o preço é zero, e `null` quando não tem.
30. The system SHALL serializar `image_url` como o caminho `/card_images/<variant_code>` do app, nunca a URL do CDN guardada em `card_variants.image_url`.
31. The system SHALL serializar `owned_quantity` como a quantidade na coleção do usuário da sessão (`0` sem item) e `wishlist_target` como a meta na wishlist dele (`null` sem item); sem sessão, os dois são `null`.
32. The system SHALL ler posse e wishlist só de `Current.user`: a resposta para o usuário B nunca contém quantidade ou meta do usuário A.

**Independent Test**: Teste de integração com uma carta de `counter` NULL, uma variante com preço `0` e outra sem preço, dois usuários com posses diferentes.

---

## Edge Cases

- IF `POST /api/session` chegar com JSON sem `email` ou sem `password` THEN the system SHALL responder `401 invalid_credentials`, como credencial errada, e não `500`.
- IF `POST /api/registration` chegar sem a chave `user` THEN the system SHALL responder `422 validation_failed` em JSON, e não o `400` HTML do `params.expect`.
- IF uma requisição a `/api` chegar com corpo JSON malformado THEN the system SHALL responder `400` com `error.code` `"invalid_json"` e `error.message` `"Requisição inválida."`, e não `500` (emenda do design, dono, 2026-10-10).
- WHEN o cliente já autenticado chamar `POST /api/session` com outras credenciais válidas THEN the system SHALL trocar a sessão pela nova, como o HTML faz.
- WHEN `GET /api/catalog` pedir `per_page` acima de 100 THEN the system SHALL usar o teto do `CatalogQuery` (`MAX_PER_PAGE`) e refletir o valor efetivo em `meta.per_page`.
- WHEN `card_number` tiver ponto ou caracteres fora de `[A-Z0-9-]` THEN the system SHALL tratá-lo como identificador, sem interpretar extensão de formato.
- IF o `variant_code` contiver `:` (`tcgplayer:123`) THEN the system SHALL gerar `image_url` que o `CardImagesController` resolve para a mesma variante.

---

## Requirement Traceability

| Requirement ID | Story | Task | Teste | Status |
|---|---|---|---|---|
| API-01 | P1: Sessão — `GET` anônimo (Req. 16.1) | T7 | `test/integration/api/sessions_test.rb › GET anônimo devolve user nil e um csrf_token` | Verified |
| API-02 | P1: Sessão — `GET` autenticado (Req. 16.2) | T7 | `test/integration/api/sessions_test.rb › GET autenticado devolve o e-mail da sessão` | Verified |
| API-03 | P1: Sessão — login (Req. 16.3) | T7 | `test/integration/api/sessions_test.rb › login cria a Session, grava o cookie e devolve token novo; end_to_end_test.rb › ponta a ponta` | Verified |
| API-04 | P1: Sessão — credencial inválida (Req. 16.4) | T7 | `test/integration/api/sessions_test.rb › credencial inválida responde 401; campo ausente no login` | Verified |
| API-05 | P1: Sessão — logout (Req. 16.5) | T7 | `test/integration/api/sessions_test.rb › logout apaga a Session; end_to_end_test.rb › ponta a ponta` | Verified |
| API-06 | P1: Sessão — cadastro (Req. 16.6) | T8 | `test/integration/api/registrations_test.rb › cadastro válido cria User e Session e devolve token novo` | Verified |
| API-07 | P1: Sessão — cadastro inválido (Req. 16.7) | T5, T8 | `test/integration/api/registrations_test.rb › e-mail vazio/já usado/senha curta/confirmação diferente/sem user; test/models/user_messages_pt_br_test.rb` | Verified |
| API-08 | P1: Sessão — CSRF obrigatório (Req. 16.8) | T7, T8 | `test/integration/api/sessions_test.rb › mutação sem token é 422; registrations_test.rb › sem token CSRF é 422` | Verified |
| API-09 | P1: Sessão — CSRF renovado (Req. 16.9) | T7, T8 | `test/integration/api/sessions_test.rb › token anterior é recusado e o novo aceito (login e logout); registrations_test.rb › o token devolvido é aceito` | Verified |
| API-10 | P1: Contrato — `401` (Req. 16.10) | T7 | `test/integration/api/sessions_test.rb › DELETE anônimo é 401 unauthenticated` | Verified |
| API-11 | P1: Contrato — formato de erro (Req. 16.11) | T6 | `test/integration/api/contract_test.rb › caminho inexistente responde 404 em JSON; sessions_test.rb (INVALID_BODY); catalog_filters_test.rb › 500` | Verified |
| API-12 | P1: Contrato — `404` de registro (Req. 16.12) | T9 | `test/integration/api/cards_test.rb › carta inexistente é 404; carta com todas as variantes ocultas é 404` | Verified |
| API-13 | P1: Contrato — `404` de rota (Req. 16.13) | T6 | `test/integration/api/contract_test.rb › caminho inexistente, POST sem token CSRF, caminho aninhado` | Verified |
| API-14 | P1: Contrato — sempre JSON (Req. 16.14) | T6, T12 | `test/integration/api/contract_test.rb › Accept text/html e extensão .html; end_to_end_test.rb › API-17 (varredura)` | Verified |
| API-15 | P1: Contrato — `406` (Req. 16.15) | T6 | `test/integration/api/contract_test.rb › navegador antigo recebe 406; formato desconhecido responde 406` | Verified |
| API-16 | P1: Contrato — `500` (Req. 16.16) | T6, T11 | `test/integration/api/contract_test.rb › exceção inesperada responde 500 e é logada; catalog_filters_test.rb › falha em filter_options` | Verified |
| API-17 | P1: Contrato — HTML intacto (Req. 16.17) | T4, T6, T12 | `test/integration/api/contract_test.rb › as rotas HTML não são afetadas; end_to_end_test.rb › API-17 (varredura)` | Verified |
| API-18 | P1: Catálogo — lista (Req. 16.18) | T10 | `test/integration/api/catalog_test.rb › API-18 (lista e paginação)` | Verified |
| API-19 | P1: Catálogo — parâmetro inválido (Req. 16.19) | T10 | `test/integration/api/catalog_test.rb › API-19; per_page acima do teto` | Verified |
| API-20 | P1: Catálogo — filtro de posse (Req. 16.20) | T10 | `test/integration/api/catalog_test.rb › API-20 (owned, missing, sem sessão, user_id ignorado); end_to_end_test.rb › ponta a ponta` | Verified |
| API-21 | P1: Catálogo — variantes presentes (Req. 16.21) | T3, T10 | `test/integration/api/catalog_test.rb › API-21; test/models/card_preload_present_variants_test.rb; test/queries/card_detail_test.rb` | Verified |
| API-22 | P1: Catálogo — opções de filtro (Req. 16.22) | T11 | `test/integration/api/catalog_filters_test.rb › data é igual a CatalogQuery.filter_options` | Verified |
| API-23 | P1: Catálogo — detalhe (Req. 16.23) | T2, T9 | `test/integration/api/cards_test.rb › devolve a carta com envelope data; test/queries/card_detail_test.rb` | Verified |
| API-24 | P1: Catálogo — variante em destaque (Req. 16.24) | T2, T9 | `test/integration/api/cards_test.rb › featured_variant_code segue o CNF-42; variante pedida de outra carta` | Verified |
| API-25 | P1: Catálogo — `404` do detalhe (Req. 16.25) | T2, T9 | `test/integration/api/cards_test.rb › carta inexistente / todas ocultas é 404; test/queries/card_detail_test.rb › levanta RecordNotFound` | Verified |
| API-26 | P1: Catálogo — público (Req. 16.26) | T9, T10 | `test/integration/api/catalog_test.rb › API-26; cards_test.rb › anônimo vê owned_quantity e wishlist_target null` | Verified |
| API-27 | P1: Serialização — carta ≠ variante (Req. 16.27) | T9 | `test/integration/api/cards_test.rb › carta e variante são objetos distintos` | Verified |
| API-28 | P1: Serialização — NULL ≠ 0 (Req. 16.28) | T9 | `test/integration/api/cards_test.rb › devolve a carta com envelope data (life e counter null, cost 0)` | Verified |
| API-29 | P1: Serialização — preço (Req. 16.29) | T9 | `test/integration/api/cards_test.rb › preço: 1.70, 0.00 e null` | Verified |
| API-30 | P1: Serialização — imagem (Req. 16.30) | T9 | `test/integration/api/cards_test.rb › image_url é o caminho do app; variante sem imagem sai com null` | Verified |
| API-31 | P1: Serialização — posse e desejo (Req. 16.31) | T1, T9 | `test/integration/api/cards_test.rb › anônimo vê owned_quantity e wishlist_target null; test/queries/variant_holdings_test.rb` | Verified |
| API-32 | P1: Serialização — isolamento (Req. 16.32) | T1, T9, T10 | `test/integration/api/cards_test.rb › dois usuários veem só a própria posse; catalog_test.rb › user_id ignorado e posse de outro usuário; variant_holdings_test.rb › dois usuários` | Verified |

**Coverage:** 32 total, 32 mapped to tasks (`tasks.md`, T1–T12), 0 unmapped

## Implicit-Requirement Dimensions

| Dimension | Resolution |
|---|---|
| Input validation & bounds | API-07 (cadastro), API-19 (parâmetro inválido ignorado), edge cases de `per_page` e de corpo sem `user` |
| Failure / partial-failure states | API-11, API-12, API-13, API-16: todo erro tem formato e status definidos; cadastro inválido não cria nada (API-07) |
| Idempotency / retry / duplicate handling | N/A because os endpoints de leitura são idempotentes por natureza e as mutações desta feature (login, cadastro, logout) já têm o comportamento do HTML: repetir o cadastro dá `422` de e-mail em uso, repetir o logout dá `401` |
| Auth boundaries & rate limits | API-08, API-09 (CSRF), API-10 (`401`), API-26 (catálogo público), API-32 (isolamento). Rate limit fora de escopo, dívida registrada |
| Concurrency / ordering | N/A because não há escrita concorrente nova: a corrida de cadastro com o mesmo e-mail já é barrada pelo índice `index_users_on_lower_email` |
| Data lifecycle / expiry | N/A because a sessão segue a política existente (cookie permanente, revogação por `terminate_session`); a feature não guarda dado novo |
| Observability | N/A because os logs de request do Rails já cobrem a API; a `500` não expõe detalhe ao cliente, mas a exceção continua no log (API-16) |
| External-dependency failure | N/A because nenhum endpoint chama serviço externo; a imagem continua no `CardImagesController`, fora desta feature |
| State-transition integrity | API-03, API-05, API-09: anônimo ↔ autenticado só por login, cadastro ou logout, sempre com troca do token CSRF |

## Success Criteria

- [ ] Um teste de integração percorre `GET /api/session` → login → `GET /api/catalog?owned=owned` → logout só com JSON e o token CSRF devolvido a cada passo.
- [ ] Nenhuma resposta de `/api` nos testes é HTML ou redirect.
- [ ] O gate full (`bin/rails test && bin/rubocop`) e o `bin/brakeman` continuam verdes, sem editar teste HTML existente.
