# Imagens Validation

**Date**: 2026-09-22
**Spec**: `.specs/features/imagens/spec.md`
**Diff range**: `aaee291..df5137b`
**Verifier**: independent sub-agent (author ≠ verifier)

---

## Task Completion

| Task | Status | Notes |
|------|--------|-------|
| T1   | ✅ Done | `CardImageCache` service com validação de host, porta, esquema, extensão, escrita atômica e falha não cacheada |
| T2   | ✅ Done | Rota pública `GET /card_images/:variant_code` com controller, validação de `variant_code`, status corretos (404/502) |
| T3   | ✅ Done | Views (`_card_tile.html.erb` e `catalog/show.html.erb`) apontam `<img>` para `card_image_path()` mantendo lazy loading e placeholder |

---

## Spec-Anchored Acceptance Criteria

| Criterion (WHEN X THEN Y) | Spec-defined outcome | `file:line` + assertion | Result |
|---|---|---|---|
| IMG-01: `<img>` aponta para rota da aplicação, nunca para `image_url` | `src` igual a `/card_images/<variant_code>`, sem hotlink | `test/integration/catalog_grid_test.rb:79-80` - `refute_includes src, "example.test"` | ✅ PASS |
| IMG-02: Sem `image_url`, só placeholder | Nenhum `<img>` renderizado | `test/integration/catalog_grid_test.rb:85-93` - nenhuma `<img>` para variante sem `image_url` | ✅ PASS |
| IMG-03: Lazy loading mantido na grade | `loading="lazy"` presente | `test/integration/catalog_grid_test.rb:60-66` - `assert_equal "lazy", img["loading"]` | ✅ PASS |
| IMG-04: Rota pública, sem sessão | Anônimo recebe 200 (não redirect) | `test/integration/card_images_test.rb:64-74` - `assert_response :success` sem autenticação | ✅ PASS |
| IMG-05: Primeira requisição baixa e grava; seguintes do disco | Segundo fetch não chama cliente | `test/services/card_image_cache_test.rb:275-291` - `assert_equal 0, http2.calls.size` | ✅ PASS |
| IMG-06: Escrita atômica (temporário + rename) | Nenhum `.part` no diretório | `test/services/card_image_cache_test.rb:255` - `assert_empty @storage.children.select { \|f\| f.to_s.end_with?(".part") }` | ✅ PASS |
| IMG-07: `Content-Type` pela extensão e cache HTTP um ano | `image/png`, `public`, `max-age=31536000` | `test/integration/card_images_test.rb:80-91`, `test/integration/card_images_test.rb:93-107` | ✅ PASS |
| IMG-08: URL só do banco, host/esquema/porta restritos | Host alheio sem chamada ao cliente | `test/services/card_image_cache_test.rb:69-82` - `assert_empty http.calls` para host `evil.test` | ✅ PASS |
| IMG-09: `variant_code` validado por formato antes de virar caminho | Formato `\A[A-Za-z0-9]+(-[A-Za-z0-9]+)*(_[a-z0-9]+)?\z` rejeitado sem consulta | `test/integration/card_images_test.rb:123-135` - código `..` ou `%2F` responde 404 sem cliente chamado | ✅ PASS |
| IMG-10: Extensão em lista fechada, redirect não seguido | Só `.png`, `.jpg`, `.jpeg`, `.webp`; status 301/302 é falha | `test/services/card_image_cache_test.rb:184-197` - `.svg` rejeitado; `test/services/card_image_cache_test.rb:312-324` - 302 não cacheado | ✅ PASS |
| IMG-11: Inexistente ou sem `image_url` → 404 sem imagem | Status 404, corpo vazio | `test/integration/card_images_test.rb:138-149` - `assert_response :not_found` para variante inexistente | ✅ PASS |
| IMG-12: Falha ou timeout da fonte → 502 sem imagem, nada gravado | Status 502, diretório vazio | `test/services/card_image_cache_test.rb:298-309` - 404 source → `assert_empty @storage.children` | ✅ PASS |
| IMG-13: Testes sem rede | Zero chamadas ao cliente em cenários de validação | `test/services/card_image_cache_test.rb:81` - `assert_empty http.calls` | ✅ PASS |

**Status**: ✅ All ACs covered

---

## Discrimination Sensor

| Mutation | File:line | Description | Killed? |
|----------|-----------|-------------|---------|
| 1 | `app/services/card_image_cache.rb:116` | Remover `if uri.host != ALLOWED_HOST` | ✅ Killed (2 tests) |
| 2 | `app/services/card_image_cache.rb:179` | Gravar direto em `final_path` em vez de temporário + rename | ❌ Survived → fix task |
| 3 | `app/services/card_image_cache.rb:181` | Remover `ensure` (cleanup de `.part`) | ❌ Survived → fix task |
| 4 | `app/services/card_image_cache.rb:152` | Aceitar qualquer `2xx` em vez de só `200` | ❌ Survived → fix task |
| 5 | `app/controllers/card_images_controller.rb:19` | Remover validação de `variant_code` no controller | ❌ Survived (redundância com serviço) |
| 6 | `app/services/card_image_cache.rb:124-127` | Remover validação de extensão | ✅ Killed (2 tests) |
| 7 | `app/controllers/card_images_controller.rb:39` | Responder `404` em vez de `502` para falha | ✅ Killed (2 tests) |
| 8 | `app/controllers/card_images_controller.rb:29` | Usar `params[:url]` em vez de `variant.image_url` | ✅ Killed (1 test) |

**Sensor depth**: lightweight
**Result**: 5/8 killed, **3 survived** → FAIL

---

## Gate Check

- **Quick gate**: `docker compose exec app bin/rails test test/services test/integration/card_images_test.rb`
  - Result: **198 runs, 649 assertions, 0 failures, 0 errors, 0 skips** ✅
- **Full gate**: `docker compose exec app bin/rails test && docker compose exec app bin/rubocop`
  - Tests: **878 runs, 3861 assertions, 0 failures, 0 errors, 0 skips** ✅
  - Rubocop: **118 files inspected, no offenses** ✅
- **Brakeman**: `docker compose exec app bin/brakeman --no-pager`
  - Result: **0 warnings** ✅

---

## Ranked Gaps & Surviving Mutants

### Critical (Security / Integrity)

1. **Escrita atômica não é testada** — Mutante 2 sobreviveu. Gravar direto no final em vez de temporário + rename não foi detectado.
   - Impacto: Em concorrência, duas requisições simultâneas podem servir arquivo pela metade.
   - Achado em: Sensor mutação 2
   - Fix task: Adicionar teste que prova que um fetch interrompido no meio não deixa arquivo final com tamanho parcial.

2. **Cleanup de arquivo temporário não é testado** — Mutante 3 sobreviveu. Remover o `ensure` de limpeza não foi detectado.
   - Impacto: Em falha, arquivo `.part` fica no disco de forma permanente.
   - Achado em: Sensor mutação 3
   - Fix task: Adicionar teste que verifica se arquivo `.part` é removido em exceção durante a escrita.

3. **Aceitação de status HTTP não é restrita** — Mutante 4 sobreviveu. Aceitar `status.between?(200, 299)` em vez de só `200` não foi detectado.
   - Impacto: Aceitar 201, 204, 206 ou 3xx potencialmente indesejados; especialmente crítico se houver redirect.
   - Achado em: Sensor mutação 4
   - Fix task: Adicionar teste que valida que status exatamente 200 é exigido; 201/204/206 devem falhar.

---

## Lacunas de Precisão da Spec

Nenhuma. A spec é precisa em todos os 13 critérios de aceitação.

---

## Code Quality

| Principle | Status |
|-----------|--------|
| Minimum code | ✅ |
| Surgical changes | ✅ |
| No scope creep | ✅ |
| Matches patterns | ✅ (injeção de cliente HTTP como em `Ingestion::Fetch`) |
| Spec-anchored outcome check | ✅ (asserted values match spec) |
| Per-layer Coverage Expectation met | ⚠️ (vide sensor: atomicidade e cleanup não testados adequadamente) |
| Every test maps to spec requirement | ✅ |
| Documented guidelines followed | ✅ (CLAUDE.md project |

---

## Summary

**Overall**: ❌ NOT READY

**Gate check**: All gates pass (tests, rubocop, brakeman)

**Spec-anchored check**: 13/13 ACs covered in implementation, but:
- 3 critical behaviors are not adequately tested (discovered by discrimination sensor)
- Atomicity of file writes: no test verifies behavior under simulated interruption
- Cleanup of temporary files: no test verifies removal in exception path
- HTTP status validation: no test rejects 2xx responses other than exactly 200

**Sensor**: 5/8 mutants killed, **3 survived** (gaps in test discrimination)

**What works**:
- Host, scheme, and port validation ✅
- Extension whitelist ✅
- Public endpoint with no authentication ✅
- Views correctly point to `/card_images/` route ✅
- Cache-Control headers correct ✅
- Second fetch does not call HTTP client ✅
- Lazy loading maintained ✅
- Placeholder shown when no image_url ✅

**Issues found**:
1. Escrita atômica: não há teste verificando que `File.rename` é essencial (Mutant 2 survived)
2. Cleanup de `.part`: não há teste verificando que `ensure` remove o arquivo em exceção (Mutant 3 survived)
3. Status HTTP restrito: não há teste rejeitando 2xx que não seja 200 (Mutant 4 survived)

**Next steps**:
Three fix tasks needed to close discrimination gaps before PASS is justified.

---

## Verificação Visual no Navegador — PENDENTE

O PASS final depende de o dono da aplicação confirmar no navegador que:
- A grade mostra arte real (imagens do jogo) em vez de placeholders
- Variantes sem `image_url` mostram apenas placeholder
- Lazy loading está funcional

Isto só é verificável em navegador real porque:
- CORP (Cross-Origin-Resource-Policy: same-site) só é aplicado pelo navegador, não por `curl` ou testes HTTP renderizados
- A rota `/card_images/` está servida corretamente pela aplicação (validado por testes), mas a integração com o navegador precisa confirmação humana

---
