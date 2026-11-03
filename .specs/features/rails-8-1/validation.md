# rails-8-1 Validation

**Date**: 2026-11-03
**Spec**: `.specs/features/rails-8-1/spec.md`
**Diff range**: `03971c5..HEAD` (`53a0da7`, `ebb9d4f`, `69d5103`)
**Verifier**: subagente independente (autor ≠ verificador)

**Verdict**: PASS

RAILS8-15 (CI verde depois do push) fica **pendente de autorização do dono**. Não é falha: o push está fora do escopo local por decisão do dono (spec, Out of Scope e Assumptions).

---

## Task Completion

Sem `tasks.md`: o spec pulou a fase Tasks por porte Medium ("Coverage: 16 total; Tasks pulado por porte Medium"). Os três commits do diff cobrem lock e Ruby (`53a0da7`), ignore do Brakeman (`ebb9d4f`) e documentação (`69d5103`).

---

## Spec-Anchored Acceptance Criteria

É upgrade de infraestrutura, sem teste novo por desenho. A evidência vem de conteúdo de arquivo (`file:line`), de comando com saída e da suíte que já existia.

| ID | Critério | Resultado definido no spec | Evidência | Resultado |
| -- | -------- | -------------------------- | --------- | --------- |
| RAILS8-01 | Lock resolve a família Rails em 8.1.4 | `rails`, `railties`, `activerecord`, `actionpack`, `activesupport` = 8.1.4 | `Gemfile.lock:26` `actionpack (8.1.4)`, `:55` `activerecord (8.1.4)`, `:65` `activesupport (8.1.4)`, `:196` `rails (8.1.4)`, `:217` `railties (8.1.4)`; `Gemfile:4` `gem "rails", "~> 8.1.4"`; no container, `bin/rails -v` → `Rails 8.1.4`. `git diff 03971c5..HEAD -- Gemfile.lock` só mexe na família Rails, mais `action_text-trix (2.1.19)` (dependência nova do `actiontext` 8.1), `json` como dependência do `activesupport` e a saída do `benchmark`. Nenhuma outra gem mudou de versão, e `RUBY VERSION`/`BUNDLED WITH` ficaram intactos | ✅ PASS |
| RAILS8-02 | `bin/rails test`: 0 falhas, 0 erros, ≥ 1231 | 0/0, contagem ≥ 1231 | `docker compose exec -T app bin/rails test`, 3 rodadas completas em série: 1) `1231 runs, 4486 assertions, 1 failures, 0 errors, 0 skips` (`IngestionImportTaskTest#test_sem_chave_e_sem_SNAPSHOT` em `test/lib/ingestion_import_task_test.rb:81`, stderr vazio); 2) `1231 runs, 4487 assertions, 0 failures, 0 errors, 0 skips`; 3) idem. A falha é flake já conhecido de antes do upgrade (ver Gate Check) | ✅ PASS (com flake pré-existente, G1) |
| RAILS8-03 | Nenhum teste existente editado ou removido | `git diff --name-status 03971c5..HEAD -- test/` vazio ou só `A` | Comando sem nenhuma linha de saída, exit 0 | ✅ PASS |
| RAILS8-04 | `bin/rubocop` sai com 0 | exit 0 | `204 files inspected, no offenses detected`, `rubocop_rc=0` | ✅ PASS |
| RAILS8-05 | `docker build -f Dockerfile .` conclui | build com sucesso | Rebuild feito pelo verificador a partir do HEAD (`docker build -f Dockerfile -t bindr-rails-8-1-verify .`), `build rc=0`; a imagem responde `ruby 3.3.13` e `Rails 8.1.4` e tem `public/_app/immutable`. 18 passos vieram do cache das camadas do build do autor, com o mesmo contexto. A tag temporária foi removida depois | ✅ PASS |
| RAILS8-06 | `load_defaults 8.0` mantido | `config.load_defaults 8.0` | `config/application.rb:12` `config.load_defaults 8.0` | ✅ PASS (ver sensor M6, G2) |
| RAILS8-16 | Ruby 3.3.13 nos três lugares | `.ruby-version`, `ARG RUBY_VERSION` e `FROM` do `Dockerfile.dev` | `.ruby-version:1` `ruby-3.3.13`; `Dockerfile:11` `ARG RUBY_VERSION=3.3.13`; `Dockerfile.dev:4` `FROM ruby:3.3.13-slim`; container `ruby 3.3.13 (2026-10-23 revision af48f08f21)` | ✅ PASS |
| RAILS8-07 | Brakeman com as flags da CI sai com 0 | exit 0 | `docker compose exec -T app bin/brakeman --no-pager --ensure-ignore-notes --ensure-no-obsolete-ignore-entries` → `Rails Version: 8.1.4`, `Brakeman Version: 8.1.0`, `Security Warnings: 0`, `Ignored Warnings: 1`, `brakeman rc=0`. As flags batem com `.github/workflows/ci.yml:33` | ✅ PASS |
| RAILS8-08 | Nenhuma entrada EOLRails no ignore | entrada `21ab0fe0…` removida | `config/brakeman.ignore` tem uma entrada só (`:4` fingerprint `c37c9336…`); `grep EOLRails config/brakeman.ignore` não acha nada; o diff de `ebb9d4f` remove a `21ab0fe00fdd…` | ✅ PASS |
| RAILS8-09 | Ignore do `CardImagesController#show` mantido, com nota e casando com aviso real | entrada presente, com nota e não obsoleta | `config/brakeman.ignore:4-5` (fingerprint mais nota). O relatório JSON do Brakeman lista em `ignored_warnings`: `c37c9336… \| File Access \| CardImagesController#show \| app/controllers/card_images_controller.rb:33 \| Weak` (`send_file result.path`). `--ensure-no-obsolete-ignore-entries` passou, e os mutantes M2 e M3 confirmam | ✅ PASS |
| RAILS8-10 | Aviso EOLRails emitido → step da CI falha | exit ≠ 0 sem ignore que cubra | Mutante M4: com Rails 8.0.5.1 declarado na cópia, sai `Check: EOLRails`, `Message: Support for Rails 8.0.5.1 ends on 2026-11-07` e `rc=3`. Não sobra ignore que o cubra (RAILS8-08) | ✅ PASS |
| RAILS8-11 | AD-032 no `STATE.md` | política, motivo (fingerprint por degrau) e data 2027-08-11 | `.specs/STATE.md:253` `### AD-032`; `:254` "nunca é ignorado"; `:255` "O fingerprint do EOLRails muda a cada degrau de confiança" e "começa a avisar em 2027-08-11" | ✅ PASS |
| RAILS8-12 | Comentário do step Brakeman no `ci.yml` | EOLRails não é ignorado e o vermelho pede upgrade | `.github/workflows/ci.yml:28-31`: "O aviso EOLRails … nunca é ignorado (AD-032)", "o vermelho dele é o alarme para subir o Rails, não para gravar um ignore" | ✅ PASS |
| RAILS8-13 | `CLAUDE.md` cita o 8.1.4 onde citava o 8.0.5.1 | sem `8.0.5.1`, com `8.1.4` | `CLAUDE.md:153` "**Rails 8.1.4 sobre Ruby 3.3.13** … EOLRails … nunca é ignorado (AD-032)"; `grep -n "8.0.5.1\|Rails 8.0" CLAUDE.md` sem ocorrência | ✅ PASS |
| RAILS8-14 | Comentário do pin do `json` sem afirmar que o AS passa `quirks_mode` | afirmação removida | `Gemfile:7-11`: "O motivo original deixou de valer: o ActiveSupport 8.0.x chamava … `quirks_mode: true` … e o 8.1.4 chama `::JSON.generate` sem ele." Conferido na fonte da gem instalada: `active_support/json/encoding.rb:144` `::JSON.generate(jsonified)` e `:170` `::JSON.generate(json_value)`, nenhum com `quirks_mode`. `grep 8.0.5.1 Gemfile` sem ocorrência | ✅ PASS |
| RAILS8-15 | CI verde na branch depois do push | jobs `lint` e `test` verdes | Run `41701660308` (push autorizado, `510f610`): `lint` success, `test` success | ✅ Provado na CI (2026-11-03) |

**Status**: 15/15 ACs locais cobertos; RAILS8-15 pendente do dono. Sem lacuna de precisão bloqueante (G2 é observação).

---

## Discrimination Sensor

Scratch isolado: `git worktree add --detach <scratchpad>/mut HEAD`. Como o Docker do host (snap) não monta caminhos de `/tmp`, cada mutante foi rodado em container novo, recebendo uma cópia por `tar` via stdin, com o volume `bundle` montado. O container `app` (que monta a árvore real) não foi usado para nenhum mutante.

| # | Alvo | Mutação | Gate | Resultado |
| - | ---- | ------- | ---- | --------- |
| M0 | baseline da cópia | nenhuma | Brakeman com flags da CI | `rc=0` (controle: o runner da cópia reproduz o verde) |
| M1 | `config/brakeman.ignore` | entrada EOLRails antiga (`21ab0fe00fdd…`) de volta | Brakeman com flags da CI | `[Error] Obsolete ignore entries were found`, `rc=9` → ✅ morto |
| M2 | `config/brakeman.ignore` | entrada do `CardImagesController` removida | Brakeman com flags da CI | `Security Warnings: 1`, `File Access: 1`, `rc=3` → ✅ morto |
| M3 | `config/brakeman.ignore` | nota do `CardImagesController` vazia | Brakeman com flags da CI | `[Error] Notes required for all ignored warnings`, `rc=8` → ✅ morto |
| M4 | `Gemfile`/`Gemfile.lock` (versão que o Brakeman lê) | família Rails declarada como 8.0.5.1 (bundler apontado para o Gemfile real) | Brakeman com flags da CI | `Check: EOLRails`, `Support for Rails 8.0.5.1 ends on 2026-11-07`, `rc=3` → ✅ morto (prova RAILS8-10) |
| M5 | `.ruby-version`, `Dockerfile`, `Dockerfile.dev` | Ruby de volta a 3.3.0, rodando em `ruby:3.3.0-slim` | boot (`require config/environment` + `eager_load!`; `bin/rails runner`) | `actionview-8.1.4/lib/action_view/helpers/capture_helper.rb:50: anonymous rest parameter is also used within block (SyntaxError)` → ✅ morto |
| M6 | `config/application.rb:12` | `load_defaults 8.0` → `8.1` | suíte completa, rubocop, Brakeman | `1231 runs, 4487 assertions, 0 failures, 0 errors`, `rubocop_rc=0`, `brakeman_rc=0` → ❌ sobreviveu (esperado; ver G2) |

**Sensor depth**: lightweight (infra, não P0).
**Result**: PASS, 5/6 mortos. O sobrevivente M6 é observação de precisão do spec, não fix task: o RAILS8-06 é uma restrição de conteúdo de arquivo que nenhum gate automático guarda, e o spec já a tira do escopo de comportamento.

Nota sobre M5: trocar **só o texto** de `.ruby-version`, com o container ainda em 3.3.13, passa nos gates locais, porque o `Gemfile` não tem diretiva `ruby`. Na CI, porém, `ruby/setup-ruby@v1` sem `ruby-version` (`.github/workflows/ci.yml:17-19`, `:101-103`) lê o `.ruby-version`, o que levaria ao 3.3.0 e ao `SyntaxError` acima. Isso foi inferido do default do `setup-ruby`, não rodei na CI.

**Isolamento**: `git status --porcelain` da árvore real vazio antes (0 bytes) e depois (0 bytes), sem contar este `validation.md`. A worktree foi removida com `git worktree remove --force`, e `git worktree list` voltou às duas entradas originais.

---

## Code Quality

| Princípio | Status |
| --------- | ------ |
| Código mínimo | ✅ só versão, ignore, comentários e docs |
| Mudanças cirúrgicas | ✅ 10 arquivos; nenhum sob `app/`, `config/` (fora do ignore), `db/`, `test/` ou `frontend/` |
| Sem scope creep | ✅ `load_defaults` 8.0 e pin do `json` mantidos; `app:update` não foi rodado |
| Segue os padrões | ✅ comentários em pt-BR, AD no formato do `STATE.md` |
| Lock conservador | ✅ só a família Rails e as dependências diretas dela |
| Spec-anchored | ✅ cada AC com `file:line` ou comando com saída |
| Todo teste mapeia requisito | N/A (nenhum teste novo, por desenho) |
| Guias seguidos | `CLAUDE.md` do projeto (gates em Docker, suítes em série, sem `git stash`) |

---

## Edge Cases

- [x] Fingerprint do `CardImagesController` mudar no 8.1: não mudou. É o mesmo `c37c9336…` antes e depois, e casa com aviso real (RAILS8-09).
- [x] Depreciação do 8.1.4 na suíte: nenhum `DEPRECATION` na saída filtrada da rodada M6 nem nas rodadas completas; o autor registrou "nenhum aviso de depreciação" no *Handoff* (`.specs/STATE.md:263`).
- [x] Volume `bundle` sem as gems do lock: `bundle check` → "The Gemfile's dependencies are satisfied".

---

## Gate Check

- **Comandos**: `bin/rails test` (3×, em série), `bin/rubocop`, `bin/brakeman --no-pager --ensure-ignore-notes --ensure-no-obsolete-ignore-entries`, `docker build -f Dockerfile .`
- **Resultado**: 1231 runs; 2 de 3 rodadas com 0 falhas e 0 erros; 1 rodada com 1 falha de flake conhecido. Rubocop 0, Brakeman 0, build 0.
- **Contagem antes**: 1231 (`CLAUDE.md`); **depois**: 1231; **delta**: 0 (esperado).
- **Skips**: 0.
- **Flakes observados e julgamento**:
  - `IngestionImportTaskTest#test_sem_chave_e_sem_SNAPSHOT…` (`test/lib/ingestion_import_task_test.rb:81`, stderr capturado vazio): **pré-existente**. Está registrado no 8.0.5.1 em `.specs/STATE.md:267` ("flakes conhecidos reapareceram: `test/lib/ingestion_*_task_test.rb` sob carga"), em `:269` e em `:277` ("captura de stderr; passam isolados"), e o próprio spec o tira do escopo (Out of Scope, run `38071008953`). Não é regressão do upgrade.
  - `Api::CollectionImportsConfirmTest#test_staging_vencido…` (`test/integration/api/collection_imports_confirm_test.rb:180`), que o autor viu falhar 1 vez em 3 e não falhou nas minhas rodadas: **pré-existente e latente, não é regressão**. O teste grava `expires_at = 1.second.ago` pelo relógio do Ruby (`:184`). O `RECLAIM_SQL` compara com `expires_at > now()` (`app/services/collection_csv/commit.rb:172`), e no PostgreSQL `now()` é o instante de início da transação, que no teste transacional (padrão; `test/test_helper.rb:8` só paraleliza, sem desligar transação) começa antes do `seed`/login/`upload`. Se esse preparo leva mais de 1 s sob 20 workers, `expires_at` fica depois do `now()` da transação e o staging parece vigente. Nenhum dos dois arquivos mudou no diff (`git log` deles para em `0c0a83c`), e a semântica de `now()` não depende da versão do Rails. Isso foi inferido pela leitura; não reproduzi a falha.

---

## Gaps (ranqueadas)

1. **G1 (Minor, pré-existente, fora do escopo)**: flakes de tempo e carga na suíte Rails (`ingestion_import_task_test.rb:81`; `collection_imports_confirm_test.rb:180`). Eles podem deixar vermelho o job `test` da CI no RAILS8-15 sem relação com o upgrade. Correção sugerida para feature própria: no teste do staging, usar `expires_at` bem no passado (por exemplo, `1.hour.ago`) ou comparar com `clock_timestamp()`, o que exige editar teste e por isso não cabe aqui (RAILS8-03).
2. **G2 (Info, precisão do spec)**: o RAILS8-06 (`load_defaults 8.0`) só é garantido pelo conteúdo do arquivo; o mutante M6 sobrevive a todos os gates. O spec já assume isso. Quando `load_defaults 8.1` virar feature, a revisão default a default terá de trazer teste próprio.
3. **G3 (Info, rastreabilidade)**: em `spec.md`, RAILS8-05 aparece como `Pending` na tabela de rastreabilidade, mas o build passa (o autor e eu confirmamos). Os checkboxes de Goals e Success Criteria seguem desmarcados. Cabe ao orquestrador atualizar (o verificador não edita o spec).
4. **RAILS8-15**: pendente de push autorizado pelo dono; não é lacuna.

---

## Requirement Traceability Update

| Requirement | Status anterior | Novo status |
| ----------- | --------------- | ----------- |
| RAILS8-01..04, 06..14, 16 | Done | ✅ Verified |
| RAILS8-05 | Pending | ✅ Verified (build rc=0 no HEAD) |
| RAILS8-15 | Done | ✅ CI verde, run `41701660308` |

---

## Summary

**Overall**: ✅ Pronto (PASS); RAILS8-15 aguarda o dono.

**Spec-anchored check**: 15/15 ACs locais batem com o resultado do spec; 1 pendente externo.
**Sensor**: 6 mutações, 5 mortas, 1 sobrevivente esperado (M6, observação).
**Gate**: 1231 runs, rubocop 0, Brakeman 0, `docker build` 0; flakes pré-existentes documentados (G1).

**Próximo passo**: push da `chore/rails-8-1` autorizado pelo dono para provar o RAILS8-15.


**Adendo (2026-11-03, orquestrador):** depois do push autorizado, a run `41701660308` do workflow `CI` em `510f610` terminou com `lint` e `test` verdes; RAILS8-15 provado.
