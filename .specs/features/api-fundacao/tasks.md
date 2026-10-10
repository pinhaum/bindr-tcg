# Fundação da API — Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Design**: `.specs/features/api-fundacao/design.md`
**Status**: Approved (dono, 2026-10-10)

---

## Test Coverage Matrix

> Generated from codebase, project guidelines, and spec - confirm before Execute. Guidelines found: `CLAUDE.md` (gates da `fonte-apitcg`; "toda task termina com código que roda e teste que passa"; sem navegador no container, logo teste de UI é integração sobre a resposta), `.context/requirements.md` Req. 16, AD-021 (sem consulta por variante), AD-023/AD-024. Padrões de teste lidos em `test/integration/card_detail_*_test.rb`, `test/integration/authentication_test.rb`, `test/queries/`.

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| ---------- | ------------------ | -------------------- | ---------------- | ----------- |
| Query objects extraídos (`CardDetail`, `VariantHoldings`) | unit | Todos os ramos: anônimo, usuário sem item, com item, ausente retida por coleção e por wishlist, destaque por `?variant=` (válido, de outra carta, lixo, só ausente), carta toda oculta, carta sem variante; isolamento entre dois usuários; uma consulta por hash | `test/queries/*_test.rb` | `bin/rails test test/queries` |
| Model (`Card.preload_present_variants`) | unit | Só presentes; uma consulta para N cartas | `test/models/card_*_test.rb` | `bin/rails test test/models` |
| Locale `pt-BR` | unit | Cada mensagem que o cadastro pode emitir (`blank`, `taken`, `too_short`, `confirmation`, `too_long`) sai em pt-BR sob `:"pt-BR"`; sob `en` nada muda | `test/models/user_messages_pt_br_test.rb` | `bin/rails test test/models` |
| Controller HTML refatorado | integration (suíte existente) | A suíte existente passa **sem edição** (API-17) | `test/integration/**` | `bin/rails test` |
| Controllers `Api::*` + views `jbuilder` | integration | Todo endpoint: caminho feliz, cada edge case do spec, cada erro (`400`, `401`, `404`, `406`, `422`, `500`); corpo exato do envelope; `Content-Type`; nenhuma resposta HTML ou redirect | `test/integration/api/*_test.rb` | `bin/rails test test/integration/api` |
| Rotas, docs | none | - | - | build gate only |

Testes de CSRF ligam `ActionController::Base.allow_forgery_protection = true` no
`setup` e restauram o valor anterior no `teardown` (o default de teste é `false`,
`config/environments/test.rb:29`). Sem isso o teste passa sem exercitar nada.

## Gate Check Commands

> Generated from codebase - confirm before Execute. O projeto `deskansa` ocupa as portas 3000 e 5432 do host: use o override de compose sem portas (ou `run --rm app` no lugar de `exec app`).

| Gate Level | When to Use | Command |
| ---------- | ----------- | ------- |
| Quick | Tasks com teste de unidade | `docker compose exec app bin/rails test test/models test/queries` |
| Full | Tasks com teste de integração | `docker compose exec app bin/rails test && docker compose exec app bin/rubocop` |
| Build | Fim de phase e fechamento | `docker compose build && docker compose exec app bin/rails test && docker compose exec app bin/rubocop && docker compose exec app bin/brakeman -q --no-pager && python3 spec/verify_fixture.py` |

---

## Execution Plan

Phases are ordered and run sequentially - each phase completes before the next begins, and tasks within a phase execute in order.

### Phase 1: Extração sem mudar o HTML

```
T1 → T2
T1 → T4
T2 → T4
T3 → T4
```

### Phase 2: Contrato e sessão

```
T5 → T7
T6 → T7
T7 → T8
```

### Phase 3: Catálogo e fechamento

```
T9 → T10
T10 → T11
T11 → T12
```

---

## Task Breakdown

### T1: `VariantHoldings`

**What**: Objeto que recebe `(user, variants)` e expõe `#owned_quantities`, `#wishlist_targets` (hashes no formato que a view HTML já usa), `#owned_quantity(variant)` (`nil` sem usuário, `0` sem item) e `#wishlist_target(variant)` (`nil` sem usuário ou sem item), com uma consulta por hash e nenhuma para o anônimo.
**Where**: `app/queries/variant_holdings.rb`
**Depends on**: None
**Reuses**: `CatalogController#owned_quantities` e `#wishlist_targets`; `CollectionItem.for_user`, `WishlistItem.for_user`
**Requirement**: API-31, API-32

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Testes em `test/queries/variant_holdings_test.rb` cobrem anônimo (`nil`, sem consulta), autenticado sem item (`0`/`nil`), com item, quantidade zero registrada, e dois usuários (B não vê A)
- [x] Contagem de consultas afirmada (uma por hash)
- [x] Gate check passes: `docker compose exec app bin/rails test test/models test/queries`
- [x] Test count: suíte anterior + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `feat(api-fundacao): extrair a posse por variante para VariantHoldings`

---

### T2: `CardDetail`

**What**: Objeto `CardDetail.new(card_number:, user:, requested_variant:).call` com `#card`, `#variants` (presentes + ausentes retidas pelo usuário, por `variant_code`), `#absent_variant_ids`, `#featured_variant` (CNF-42) e `#holdings`; levanta `RecordNotFound` para carta inexistente ou com todas as variantes ocultas.
**Where**: `app/queries/card_detail.rb`
**Depends on**: T1
**Reuses**: corpo de `CatalogController#show`, `#hero_variant`, `#held_variant_ids`, sem mudar as consultas
**Requirement**: API-23, API-24, API-25

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Testes em `test/queries/card_detail_test.rb` cobrem: ausente retida por coleção e por wishlist (e não retida para outro usuário e para o anônimo); destaque por código válido, de outra carta, lixo, e o padrão quando só há ausente; carta inexistente e toda oculta levantam `RecordNotFound`; carta sem variante nenhuma não levanta
- [x] Gate check passes: `docker compose exec app bin/rails test test/models test/queries`
- [x] Test count: suíte anterior + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `feat(api-fundacao): extrair as regras do detalhe da carta para CardDetail`

---

### T3: `Card.preload_present_variants`

**What**: Método de classe que pré-carrega em `card_variants` só as variantes presentes (`CardVariant.present`) para um array de cartas, numa consulta.
**Where**: `app/models/card.rb`
**Depends on**: None
**Reuses**: o `ActiveRecord::Associations::Preloader` de `CatalogController#index`
**Requirement**: API-21

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Teste em `test/models/card_preload_present_variants_test.rb`: variante ausente fica fora; N cartas custam uma consulta de variantes
- [x] Gate check passes: `docker compose exec app bin/rails test test/models test/queries`
- [x] Test count: suíte anterior + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `feat(api-fundacao): pré-carregar só as variantes presentes num método do Card`

---

### T4: `CatalogController` sobre os objetos extraídos

**What**: `index` passa a usar `Card.preload_present_variants` e `VariantHoldings`; `show` chama `authenticated?` uma vez no topo, constrói o `CardDetail` e copia para os ivars que a view lê (`@card`, `@variants`, `@absent_variant_ids`, `@hero`, `@owned_quantities`, `@wishlist_targets`); os métodos privados movidos saem; nenhuma view muda.
**Where**: `app/controllers/catalog_controller.rb`
**Depends on**: T1, T2, T3
**Reuses**: T1–T3
**Requirement**: API-17

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] `git diff --stat test/` vazio nesta task: nenhum teste existente editado
- [x] Remover o `authenticated?` do topo do `show` derruba ao menos um teste existente (prova manual registrada no commit; o defeito silencioso continua coberto)
- [x] Gate check passes: `docker compose exec app bin/rails test && docker compose exec app bin/rubocop`
- [x] Test count: igual ao da T3 (só refactor)

**Tests**: integration
**Gate**: full

**Commit**: `refactor(catalogo): usar CardDetail e VariantHoldings no CatalogController`

---

### T5: Locale `pt-BR` das mensagens de cadastro

**What**: `config/locales/pt-BR.yml` com `errors.messages` (`blank`, `taken`, `too_short`, `too_long`, `confirmation`) e os nomes de atributo de `User`; `default_locale` continua `en`.
**Where**: `config/locales/pt-BR.yml`
**Depends on**: None
**Reuses**: chaves do `en.yml` do Active Model
**Requirement**: API-07

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Teste em `test/models/user_messages_pt_br_test.rb`: sob `I18n.with_locale(:"pt-BR")`, cada caso de cadastro inválido emite a string pt-BR exata, sem "translation missing"; sob o locale padrão, a mensagem continua em inglês
- [x] `test/models/user_password_test.rb` passa sem edição
- [x] Gate check passes: `docker compose exec app bin/rails test test/models test/queries`
- [x] Test count: suíte anterior + novos, nenhum removido

**Tests**: unit
**Gate**: quick

**Commit**: `feat(api-fundacao): traduzir para pt-BR as mensagens de validação do cadastro`

---

### T6: `Api::BaseController`, escopo `/api` e catch-all

**What**: Base `< ActionController::Base` com `Authentication`, `before_action :resume_session`, `around_action` de locale pt-BR, `allow_browser` com bloco JSON, `request_authentication` em `401` JSON sem `return_to`, `rescue_from` (`StandardError` → `500`, `InvalidAuthenticityToken` → `422`, `RecordNotFound` → `404`, `ParseError` → `400`) e `render_error`; o bloco `scope "api"` com `defaults: { format: :json }, format: false` em `config/routes.rb`; `Api::NotFoundController` público, com `skip_forgery_protection`, no catch-all.
**Where**: `app/controllers/api/base_controller.rb`
**Depends on**: None
**Reuses**: `Authentication`; `allow_browser` do Rails (`block:`)
**Requirement**: API-11, API-13, API-14, API-15

**Tools**:

- MCP: NONE
- Skill: `ecc:error-handling`

**Done when**:

- [x] Testes em `test/integration/api/contract_test.rb`: `GET`/`POST`/`DELETE` em caminho inexistente sob `/api` dão `404 not_found` JSON (inclusive `POST` sem token CSRF com a proteção ligada); `Accept: text/html` e caminho com `.html` continuam JSON; User-Agent de navegador antigo dá `406 unsupported_browser`; corpo segue `{ error: { code, message, fields: {} } }`; `Content-Type` é `application/json`
- [x] Rotas HTML intactas: suíte inteira verde sem edição
- [x] Gate check passes: `docker compose exec app bin/rails test && docker compose exec app bin/rubocop`
- [x] Test count: suíte anterior + novos, nenhum removido

**Tests**: integration
**Gate**: full

**Commit**: `feat(api-fundacao): criar o controller base e o contrato de erro da API`

---

### T7: `Api::SessionsController`

**What**: `GET`, `POST` e `DELETE /api/session` com a view `api/sessions/_session.json.jbuilder` (`user` e `csrf_token`), credencial inválida e campo ausente em `401 invalid_credentials`, logout sem sessão em `401 unauthenticated`.
**Where**: `app/controllers/api/sessions_controller.rb`
**Depends on**: T5, T6
**Reuses**: `start_new_session_for`, `terminate_session`, `User.authenticate_by`
**Requirement**: API-01, API-02, API-03, API-04, API-05, API-08, API-09, API-10

**Tools**:

- MCP: NONE
- Skill: `ecc:security-review`

**Done when**:

- [x] Testes em `test/integration/api/sessions_test.rb`, com a proteção CSRF ligada: os nove critérios de sessão; corpo idêntico para e-mail inexistente e senha errada; `Session` e cookie não criados na falha; cookie `httponly` e `samesite=lax`; token anterior recusado e novo aceito depois de login e logout; mutação sem token dá `422` sem executar; `DELETE` anônimo dá `401` sem gravar `return_to_after_authenticating`; corpo JSON malformado dá `400 invalid_json`; login de quem já está logado troca a sessão
- [x] O fluxo do Independent Test do spec passa num teste só
- [x] Gate check passes: `docker compose exec app bin/rails test && docker compose exec app bin/rubocop`
- [x] Test count: suíte anterior + novos, nenhum removido

**Tests**: integration
**Gate**: full

**Commit**: `feat(api-fundacao): entrar, sair e consultar a sessão por JSON`

---

### T8: `Api::RegistrationsController`

**What**: `POST /api/registration` que cria e autentica (`201`, sessão do `_session`) ou responde `422 validation_failed` com `fields` em pt-BR; corpo sem `user` ou com `user` não-hash vira `422`, não `400`.
**Where**: `app/controllers/api/registrations_controller.rb`
**Depends on**: T7
**Reuses**: `start_new_session_for`; partial da T7
**Requirement**: API-06, API-07

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] Testes em `test/integration/api/registrations_test.rb`: cadastro válido cria `User` e `Session` e devolve token novo; cada caso inválido (e-mail vazio, já usado com outra caixa, senha curta, confirmação diferente) traz a mensagem pt-BR exata em `fields` e não cria nada; sem `user` dá `422`; sem token CSRF dá `422 invalid_csrf_token`
- [ ] Gate check passes: `docker compose exec app bin/rails test && docker compose exec app bin/rubocop`
- [ ] Test count: suíte anterior + novos, nenhum removido

**Tests**: integration
**Gate**: full

**Commit**: `feat(api-fundacao): cadastrar conta por JSON`

---

### T9: `Api::CardsController` e os partials de carta, variante e preço

**What**: `GET /api/cards/:card_number` sobre o `CardDetail`, com `api/cards/_card`, `_variant` e `_price` (`jbuilder`) e `featured_variant_code`; `card_number` com ponto não vira formato.
**Where**: `app/controllers/api/cards_controller.rb`
**Depends on**: None
**Reuses**: `CardDetail` (T2), `VariantHoldings` (T1), `card_image_path`
**Requirement**: API-12, API-23, API-24, API-25, API-26, API-27, API-28, API-29, API-30, API-31, API-32

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] Testes em `test/integration/api/cards_test.rb`: carta com `counter` NULL sai `null`; variante com preço `0` sai `"0.00"`, outra com preço sai `"1.70"` com `currency` e `observed_at` ISO 8601 UTC, outra sem preço sai `null`; `image_url` é `/card_images/<code>` também com `:` no código; anônimo vê `owned_quantity`/`wishlist_target` `null`; dois usuários veem só a própria posse; ausente retida sai com `in_source: false` só para o dono; `?variant=` segue o CNF-42; inexistente e toda oculta dão `404 not_found`; `card_number` com ponto responde JSON
- [ ] Gate check passes: `docker compose exec app bin/rails test && docker compose exec app bin/rubocop`
- [ ] Test count: suíte anterior + novos, nenhum removido

**Tests**: integration
**Gate**: full

**Commit**: `feat(api-fundacao): servir o detalhe da carta por JSON`

---

### T10: `Api::CatalogController#index`

**What**: `GET /api/catalog` sobre o `CatalogQuery`, com `Card.preload_present_variants`, `VariantHoldings` e os partials da T9; `meta` com `page`, `per_page`, `total_count`, `total_pages` e `active_filters`.
**Where**: `app/controllers/api/catalog_controller.rb`
**Depends on**: T9
**Reuses**: `CatalogQuery`, T1, T3, T9
**Requirement**: API-18, API-19, API-20, API-21, API-26

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] Testes em `test/integration/api/catalog_test.rb`: mesma lista e ordem do `CatalogQuery` para um filtro de cor; parâmetro desconhecido e valor inválido ignorados com `200`; `per_page=500` reflete o teto em `meta.per_page`; `owned=owned` filtra pela coleção da sessão, é ignorado sem sessão, e `user_id` no parâmetro não muda a coleção lida; variante ausente fora de `variants`; contagem de consultas não cresce com o número de cartas
- [ ] Gate check passes: `docker compose exec app bin/rails test && docker compose exec app bin/rubocop`
- [ ] Test count: suíte anterior + novos, nenhum removido

**Tests**: integration
**Gate**: full

**Commit**: `feat(api-fundacao): listar e filtrar o catálogo por JSON`

---

### T11: `Api::CatalogController#filters`

**What**: `GET /api/catalog/filters` com `CatalogQuery.filter_options` em `api/catalog/filters.json.jbuilder`.
**Where**: `app/views/api/catalog/filters.json.jbuilder`
**Depends on**: T10
**Reuses**: `CatalogQuery.filter_options`
**Requirement**: API-16, API-22

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] Testes em `test/integration/api/catalog_filters_test.rb`: `data` igual a `filter_options` (`colors`, `card_types`, `rarities`, `sets` com `code` e `name`); com `CatalogQuery.filter_options` substituído por um que levanta, a resposta é `500 internal_error` com a mensagem genérica e sem classe, mensagem ou stack da exceção no corpo
- [ ] Gate check passes: `docker compose exec app bin/rails test && docker compose exec app bin/rubocop`
- [ ] Test count: suíte anterior + novos, nenhum removido

**Tests**: integration
**Gate**: full

**Commit**: `feat(api-fundacao): servir as opções de filtro do catálogo por JSON`

---

### T12: Fechamento

**What**: Teste de ponta a ponta do Success Criteria (`GET /api/session` → login → `GET /api/catalog?owned=owned` → logout, só JSON e o token devolvido a cada passo); `CLAUDE.md` atualizado (API, contagem de testes, armadilhas); §11 do `.context/tasks.md` fechada; traceability do spec preenchida.
**Where**: `test/integration/api/end_to_end_test.rb`
**Depends on**: T11
**Reuses**: T7, T10
**Requirement**: API-17

**Tools**:

- MCP: NONE
- Skill: `superpowers:verification-before-completion`

**Done when**:

- [ ] Teste de ponta a ponta verde; nenhuma resposta de `/api` nos testes é HTML ou redirect
- [ ] Gate check passes: `docker compose build && docker compose exec app bin/rails test && docker compose exec app bin/rubocop && docker compose exec app bin/brakeman -q --no-pager && python3 spec/verify_fixture.py`
- [ ] Test count: suíte anterior + novos, nenhum removido

**Tests**: integration
**Gate**: build

**Commit**: `docs(api-fundacao): fechar a feature com o teste de ponta a ponta`

---

## Phase Execution Map

```
Phase 1 → Phase 2 → Phase 3

Phase 1:  T1 → T2 → T4
          T1 → T4
          T3 → T4
Phase 2:  T5 → T7 → T8
          T6 → T7
Phase 3:  T9 → T10 → T11 → T12
```

T9 não depende de nada na própria phase; T1 e T2 (phase 1) já estão prontas
quando a phase 3 começa, porque as phases são sequenciais.

---

## Plano de delegação

- `ecc:security-reviewer` depois da T7 e da T8 (CSRF, `401`, anti-oráculo, cookie) e no fim, sobre o base controller.
- `ecc:database-reviewer` depois da T10 (contagem de consultas, preload).
- `ecc:pr-test-analyzer` sobre `test/integration/api/` antes do Verifier.
- Verifier (autor ≠ verificador) depois da T12, automático.

---

## Task Granularity Check

| Task | Scope | Status |
| ---- | ----- | ------ |
| T1 | 1 query object | ✅ Granular |
| T2 | 1 query object | ✅ Granular |
| T3 | 1 método de model | ✅ Granular |
| T4 | 1 controller (refactor) | ✅ Granular |
| T5 | 1 arquivo de locale | ✅ Granular |
| T6 | base + rota + catch-all | ⚠️ Coeso: o base só é testável com uma rota e um controller concreto (merge backward) |
| T7 | 1 controller + 1 partial | ⚠️ Coeso |
| T8 | 1 controller | ✅ Granular |
| T9 | 1 endpoint + partials da carta | ⚠️ Coeso: os partials só são testáveis por um endpoint |
| T10 | 1 endpoint | ✅ Granular |
| T11 | 1 endpoint | ✅ Granular |
| T12 | 1 teste + docs | ✅ Granular |

## Diagram-Definition Cross-Check

| Task | Depends On (task body) | Diagram Shows | Status |
| ---- | ---------------------- | ------------- | ------ |
| T1 | None | none | ✅ Match |
| T2 | T1 | T1 → T2 | ✅ Match |
| T3 | None | none | ✅ Match |
| T4 | T1, T2, T3 | T1/T2/T3 → T4 | ✅ Match |
| T5 | None | none | ✅ Match |
| T6 | None | none | ✅ Match |
| T7 | T5, T6 | T5/T6 → T7 | ✅ Match |
| T8 | T7 | T7 → T8 | ✅ Match |
| T9 | None (T1, T2 em phase anterior) | none | ✅ Match |
| T10 | T9 | T9 → T10 | ✅ Match |
| T11 | T10 | T10 → T11 | ✅ Match |
| T12 | T11 | T11 → T12 | ✅ Match |

## Test Co-location Validation

| Task | Code Layer Created/Modified | Matrix Requires | Task Says | Status |
| ---- | --------------------------- | --------------- | --------- | ------ |
| T1 | Query object | unit | unit | ✅ OK |
| T2 | Query object | unit | unit | ✅ OK |
| T3 | Model | unit | unit | ✅ OK |
| T4 | Controller HTML | integration | integration | ✅ OK |
| T5 | Locale | unit | unit | ✅ OK |
| T6 | Controller `Api` + rotas | integration | integration | ✅ OK |
| T7 | Controller `Api` + view | integration | integration | ✅ OK |
| T8 | Controller `Api` | integration | integration | ✅ OK |
| T9 | Controller `Api` + views | integration | integration | ✅ OK |
| T10 | Controller `Api` + view | integration | integration | ✅ OK |
| T11 | View `Api` | integration | integration | ✅ OK |
| T12 | Teste + docs | integration | integration | ✅ OK |
