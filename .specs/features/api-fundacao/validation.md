# Validação — api-fundacao

**Veredito**: PASS
**Data**: 2026-10-10
**Spec**: `.specs/features/api-fundacao/spec.md` (API-01..32)
**Diff range**: `9b0d059..58bb4df` (17 commits; HEAD = `58bb4df`)
**Verifier**: sub-agente independente (autor ≠ verificador)

Testes existentes alterados: só `test/queries/catalog_query_test.rb` (+10 linhas, teste do int4). Nenhum teste HTML foi editado ou enfraquecido (API-17).

---

## Conclusão das tasks

T1–T12 marcadas `[x]` em `tasks.md`; nenhuma parcial ou bloqueada.

---

## Critérios de aceitação ancorados na spec

| AC | Resultado definido na spec | `file:line` + asserção | Resultado |
|---|---|---|---|
| API-01 | 200, `user` nil, `csrf_token` | `test/integration/api/sessions_test.rb:39-42` — `assert_nil …"user"`, `assert_predicate …csrf_token, :present?` | ✅ |
| API-02 | `data.user.email` da sessão | `sessions_test.rb:51` — `assert_equal CREDENTIALS[:email], …dig("data","user","email")` | ✅ |
| API-03 | Session criada, cookie httponly/lax, token novo | `sessions_test.rb:58-66` — `assert_difference Session.count,1`; `assert_not_equal old_token`; `assert_match /httponly/i`, `/samesite=lax/i` | ✅ |
| API-04 | 401, corpo idêntico, sem Session nem cookie | `sessions_test.rb:73-82` — `assert_equal INVALID_BODY, bodies.first`; `assert_nil session_cookie_header`; campo ausente `:85-94` | ✅ |
| API-05 | Session apagada, cookie removido, token novo | `sessions_test.rb:100-107` — `Session.count -1`, `assert_match(/session_id=;/)`, `assert_not_equal token` | ✅ |
| API-06 | 201, User e Session criados, token novo | `registrations_test.rb:240-247` — `assert_response :created`; `assert_not_equal old_token` | ✅ |
| API-07 | 422 `validation_failed`, `fields` por atributo em pt-BR, nada criado | `registrations_test.rb:270,280,288,296` — `assert_rejected("email"=>["não pode ficar em branco"])` etc.; sem `user` `:299-311` | ✅ |
| API-08 | 422 `invalid_csrf_token`, sem executar (inclui login/cadastro) | `sessions_test.rb:125-137`; `registrations_test.rb:314-320` | ✅ |
| API-09 | token anterior 422, novo aceito (login, logout, cadastro) | `sessions_test.rb:145-150,159-163`; `registrations_test.rb:258-262` | ✅ |
| API-10 | 401 `unauthenticated` + mensagem, sem `return_to` | `sessions_test.rb:115-120` — `assert_nil session[:return_to_after_authenticating]` | ✅ |
| API-11 | corpo `{error:{code,message,fields:{}}}` | `contract_test.rb:360` — `assert_equal({…"fields"=>{}}, response.parsed_body)`; `sessions_test.rb:170` | ✅ |
| API-12 | 404 `not_found`, "Não encontrado." | `cards_test.rb:154-155,163-164` (código); mensagem exata só em `contract_test.rb:360` | ✅ (ver G2) |
| API-13 | 404 JSON sob `/api` | `contract_test.rb:358-361,370-371,377-378` | ✅ |
| API-14 | `application/json` com `Accept: text/html` e `.html` | `contract_test.rb:385,393`; varredura `end_to_end_test.rb:537-543` | ✅ |
| API-15 | 406 `unsupported_browser` JSON | `contract_test.rb:400-404` | ✅ |
| API-16 | 500 `internal_error`, mensagem fixa, sem dado da exceção | `contract_test.rb:424-429` — `assert_no_match(/RuntimeError|segredo-interno|\.rb/, body)`; `catalog_filters_test.rb:430-433` | ✅ |
| API-17 | HTML intacto, suíte sem edição | `contract_test.rb:407-411`; `git diff --diff-filter=M` só `catalog_query_test.rb` (+10); varredura `end_to_end_test.rb:513-544` | ✅ |
| API-18 | mesma lista/ordem do `CatalogQuery`, `meta` completo | `catalog_test.rb:247-251` — `assert_equal expected.records.map(&:card_number)`, `assert_equal({page,per_page,total_count,total_pages,active_filters}, meta)` | ✅ |
| API-19 | parâmetro inválido ignorado, 200 | `catalog_test.rb:263-268`; `:388-396` (int4) | ✅ |
| API-20 | owned por sessão; anônimo ignora; `user_id` inócuo | `catalog_test.rb:282,290,299-300,307-310` | ✅ |
| API-21 | só `present`, por `variant_code` | `catalog_test.rb:318-319`; `card_preload_present_variants_test.rb:24-45` | ✅ |
| API-22 | `data == CatalogQuery.filter_options` | `catalog_filters_test.rb:416-418` | ✅ |
| API-23 | carta + variantes do detalhe HTML, `in_source:false` | `cards_test.rb:44-50,118-119,133-134` | ✅ |
| API-24 | `featured_variant_code` (CNF-42) | `cards_test.rb:138-140,148`; fallback "só ausente retida" em `card_detail_test.rb:92` | ✅ |
| API-25 | 404 para inexistente / todas ocultas | `cards_test.rb:152-155,159-164` | ✅ |
| API-26 | catálogo e detalhe sem sessão | `catalog_test.rb:323-326`; `cards_test.rb:83-86` | ✅ |
| API-27 | carta ≠ variante (chaves exatas) | `cards_test.rb:56-58` — `assert_equal %w[art_kind … wishlist_target], variant.keys.sort` | ✅ |
| API-28 | NULL → `null`, nunca 0 | `cards_test.rb:44-47` — `"life"=>nil,"counter"=>nil,"cost"=>0` | ✅ |
| API-29 | `price` `"1.70"` / `"0.00"` / `null`, moeda, ISO 8601 UTC | `cards_test.rb:65-68` | ✅ |
| API-30 | `image_url` = `/card_images/<code>` | `cards_test.rb:72,78` | ✅ |
| API-31 | posse 0/meta nil logado; null anônimo | `cards_test.rb:85-86,96-99`; `variant_holdings_test.rb:33,57` | ✅ |
| API-32 | B nunca vê A | `cards_test.rb:96-104`; `catalog_test.rb:374-385`; `variant_holdings_test.rb:85` | ✅ |

Casos de borda da spec: JSON sem `email`/`password` (`sessions_test.rb:88-93`), cadastro sem `user` (`registrations_test.rb:302`), JSON malformado (`sessions_test.rb:167-171`), troca de sessão (`sessions_test.rb:174-187`), `per_page` > 100 (`catalog_test.rb:272`), `card_number` com ponto (`cards_test.rb:167-177`), `variant_code` com `:` (`cards_test.rb:72`). Todos cobertos.

**Status**: ✅ 32/32 ACs com asserção no resultado definido pela spec. 3 observações menores (G1–G3).

---

## Sensor de discriminação

Cópia em `tmp/sensor-api-fundacao/` (rsync sem `.git`, `tmp`, `log`, `storage`, `node_modules`); testes rodados na cópia. Árvore real intocada.

| # | Arquivo | Mutação | Testes | Resultado |
|---|---|---|---|---|
| M1 | `app/controllers/api/base_controller.rb:9` | removeu `before_action :resume_session` | cards, catalog | ✅ Morto (6 falhas) |
| M2 | `base_controller.rb:19-23` | `rescue_from StandardError` movido para o fim (inverte precedência) | contract, sessions, cards, registrations | ✅ Morto |
| M2b | `base_controller.rb:19-23` | removeu o handler de `StandardError` | contract, sessions, cards | ✅ Morto (1 erro) |
| M3 | `app/controllers/concerns/authentication.rb:77` | removeu `reset_session` no login (token CSRF não troca) | sessions, registrations | ✅ Morto (2 falhas) |
| M4 | `app/queries/variant_holdings.rb:23` | removeu `return unless @user` em `owned_quantity` (anônimo vê 0) | cards, catalog | ✅ Morto (2 falhas) |
| M5 | `app/models/card.rb:30` | preload sem `CardVariant.present` | catalog, preload | ✅ Morto (3 falhas) |
| M6 | `base_controller.rb:22` | mensagem do 500 inclui `error.message` | contract, catalog_filters | ✅ Morto (2 falhas) |
| M7 | `app/controllers/api/catalog_controller.rb:8` | `owned` usa `params[:user_id]` | catalog | ✅ Morto (1 falha) |
| M8 | `base_controller.rb:51` | 401 grava `return_to_after_authenticating` | sessions | ✅ Morto (1 falha) |
| M9 | `config/routes.rb:158` | removeu o catch-all | contract, end_to_end | ✅ Morto (6 falhas) |

**Profundidade**: P0-full (auth/CSRF, isolamento de dados), ≥5 mutantes manuais cobrindo os ramos de risco.
**Resultado**: **9/9 mutantes distintos mortos** (M2b é variante de M2; 10/10 execuções). Nenhum sobrevivente, nenhuma fix task.
**Isolamento**: `git status --porcelain` da árvore real igual a `tmp/baseline-status.txt` (`?? .playwright-mcp/`) conferido antes desta escrita.

---

## Qualidade do código

| Princípio | Status |
|---|---|
| Mínimo de código / sem escopo extra | ✅ |
| Mudança cirúrgica (HTML só via extração `CardDetail`/`VariantHoldings`, API-17) | ✅ |
| Segue padrões (query objects, `allow_unauthenticated_access`, jbuilder) | ✅ |
| Valor asserido = resultado da spec | ✅ |
| Cobertura por camada (rotas: sucesso + borda + erro) | ✅ |
| Todo teste mapeia para AC/borda | ✅ |
| Diretrizes seguidas: `CLAUDE.md` (default de sessão, `Current.user` por argumento, rubocop-omakase) | ✅ |

---

## Gate

- **Comando**: `docker compose exec -T app bin/rails test` + `bin/rubocop`
- **Resultado**: 1908 runs, 7781 assertions, 0 failures, 0 errors, 0 skips (esperado 1908 ✅)
- **Rubocop**: 245 arquivos, 0 ofensas
- **Skips**: nenhum

---

## Lacunas (todas menores, não bloqueiam)

1. **G1 — Spec-precision**: API-24 não define o `featured_variant_code` de uma carta sem variante alguma (o código devolve `null`; `card_detail_test.rb:126` só prova que não levanta). Definir na spec: `null`.
2. **G2 — Spec-precision**: API-12 fixa a mensagem `"Não encontrado."`, mas `cards_test.rb:155,164` só asseram o `code`; a mensagem é provada apenas no catch-all (`contract_test.rb:360`). Mesmo handler, sem risco real.
3. **G3 — Observação**: API-03 exige cookie *assinado*; os testes provam `httponly`/`samesite=lax`, não a assinatura. A garantia vem de `cookies.signed.permanent` em `authentication.rb:82`, herdado do HTML.

## Rastreabilidade

API-01..32: ✅ Verified (confirmado de forma independente).

## Resumo

**Geral**: ✅ Pronto
**Check ancorado na spec**: 32/32 ACs; 2 lacunas de precisão menores e 1 observação
**Sensor**: 9/9 mortos
**Gate**: 1908 passando, rubocop limpo
