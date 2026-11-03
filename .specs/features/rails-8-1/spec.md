# Rails 8.1 Specification

## Problem Statement

A CI está vermelha desde 2026-10-10 (12 runs seguidas; a última verde foi `284e25c`, em
2026-10-05). Em todas, o step `Brakeman` do job `lint` sai com código 3: o aviso EOLRails do
Rails 8.0.5.1 (fim de suporte em 2026-11-07) subiu de confiança `low` para `medium`, o
fingerprint mudou e a entrada `21ab0fe0…` de `config/brakeman.ignore` ficou obsoleta, o que
`--ensure-no-obsolete-ignore-entries` recusa. Regravar o ignore não resolve: o aviso muda de
novo em 2026-11-07 (vira `unsupported`, confiança `high`). A causa raiz é a versão do Rails;
a correção é subir para o Rails 8.1.4, com fim de suporte em 2027-10-10.

## Goals

- [ ] O lockfile resolve o Rails 8.1.4, e a suíte Rails inteira passa sem teste existente editado para acomodar o upgrade.
- [ ] O Brakeman com as flags da CI sai com código 0, sem entrada EOLRails no ignore.
- [ ] A política "EOLRails nunca é ignorado" fica registrada como decisão (AD) e no próprio `ci.yml`.

## Out of Scope

| Feature | Reason |
| ------- | ------ |
| Subir `config.load_defaults` para 8.1 | Muda comportamento por default novo; revisão default a default é feature própria (ver Assumptions) |
| Soltar o pin do `json` (`~> 2.7`) | Troca de major sem necessidade para tirar a CI do vermelho (ver Assumptions) |
| Atualizar o Ruby para outra série (3.4+) | Só a patch da 3.3 é necessária (ver Assumptions); troca de série é feature própria |
| Flake das 7 falhas em `test/lib/ingestion_*_task_test.rb` (run `38071008953`) | Não se repetiu nas 11 runs seguintes; só registrar se voltar |
| Qualquer mudança na SPA (`frontend/`) | O upgrade é do backend; a API JSON não muda de contrato |
| Push, PR e merge | Exigem autorização explícita do dono |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --------------------- | -------------- | --------- | ---------- |
| Política do aviso EOLRails | Nunca ignorar: a entrada EOLRails sai do ignore e nenhuma outra é gravada; a CI fica vermelha a partir de 2027-08-11 (60 dias antes do EOL do 8.1) como alarme de upgrade | O fingerprint muda a cada degrau de confiança, então um ignore quebra a CI de qualquer jeito; o vermelho antecipado é o aviso desejado | y (dono, 2026-11-03) |
| Versão-alvo | Rails 8.1.4 (`gem "rails", "~> 8.1.4"`) | Última série estável (2026-09-24); não existe 8.2 | y (dono, 2026-11-03) |
| `config.load_defaults` | Fica em 8.0 neste corte | O objetivo é tirar a CI do vermelho com o menor raio; defaults novos mudam comportamento e merecem revisão própria | y (dono, 2026-11-03) |
| Pin do `json` | Fica em `~> 2.7`; o comentário do `Gemfile` é reescrito dizendo que a razão do pin deixou de valer no 8.1.4 (`ActiveSupport::JSON` chama `::JSON.generate` sem `quirks_mode`) e que soltá-lo é decisão separada | Mantém a série do `json` já provada pela suíte; o comentário atual ficaria falso | y (dono, 2026-11-03) |
| `bin/rails app:update` | Não é rodado por inteiro; só entram as mudanças de arquivo gerado que o 8.1.4 exigir para bootar e passar a suíte | Evita sobrescrever configuração customizada (`application.rb`, `routes.rb`, inicializadores) | y (dono, 2026-11-03) |
| Ruby | Sobe de 3.3.0 para 3.3.13 (`.ruby-version`, `Dockerfile`, `Dockerfile.dev`) | O 3.3.0 tem bug de parser (parâmetro anônimo `*`/`**` usado dentro de bloco é `SyntaxError`) e o `actionview` 8.1.4 usa essa sintaxe em `action_view/helpers/capture_helper.rb:50`, então o app não sobe; o mesmo trecho roda no 3.3.13. Só patch, mesma ABI 3.3 | y (dono, 2026-11-03, emenda no Execute) |
| Prova na CI | Prova local com as mesmas flags; a prova na CI depende do push autorizado pelo dono | Push é ação externa | y (instrução do dono) |

**Open questions:** none - all resolved or logged above.

---

## User Stories

### P1: Rails 8.1.4 com a suíte verde ⭐ MVP

**User Story**: Como dono do projeto, quero o app no Rails 8.1.4 para ter suporte até 2027-10-10 sem regressão de comportamento.

**Why P1**: É a causa raiz da CI vermelha; sem o upgrade, o Brakeman continua falhando.

**Acceptance Criteria**:

1. The `Gemfile.lock` SHALL resolve `rails`, `railties`, `activerecord`, `actionpack` e `activesupport` na versão 8.1.4.
2. WHEN `bin/rails test` roda no container THEN a suíte SHALL terminar com 0 falhas e 0 erros e com contagem de testes igual ou maior que 1231.
3. The upgrade SHALL NOT editar nem remover arquivo de teste existente sob `test/` (`git diff --name-status 03971c5..HEAD -- test/` vazio ou só com `A`).
4. WHEN `bin/rubocop` roda THEN ele SHALL sair com código 0.
5. WHEN `docker build -f Dockerfile .` roda THEN a imagem de produção SHALL ser construída com sucesso.
6. The `config/application.rb` SHALL manter `config.load_defaults 8.0`.
7. The `.ruby-version` e o `ARG RUBY_VERSION` do `Dockerfile` e a imagem base do `Dockerfile.dev` SHALL declarar Ruby 3.3.13.

**Independent Test**: `bin/rails -v` imprime `Rails 8.1.4` e `bin/rails test && bin/rubocop` passa no container.

---

### P1: Brakeman verde sem ignorar o fim de suporte ⭐ MVP

**User Story**: Como dono do projeto, quero o Brakeman da CI verde e sem silenciar o aviso de fim de suporte, para que o próximo prazo de upgrade volte a avisar.

**Why P1**: É o step que derruba a CI.

**Acceptance Criteria**:

1. WHEN `bin/brakeman --no-pager --ensure-ignore-notes --ensure-no-obsolete-ignore-entries` roda THEN ele SHALL sair com código 0.
2. The `config/brakeman.ignore` SHALL NOT conter entrada cujo aviso seja do tipo EOLRails (a entrada `21ab0fe00fdd…` sai).
3. The `config/brakeman.ignore` SHALL manter o aviso do `CardImagesController#show` ignorado, com nota, e a entrada SHALL corresponder a um aviso real.
4. IF o Brakeman emitir um aviso EOLRails THEN o step `Brakeman` da CI SHALL falhar, sem entrada de ignore que o cubra.

**Independent Test**: rodar o comando do AC 1 no container e conferir código 0.

---

### P2: Política registrada

**User Story**: Como quem mantiver o projeto depois, quero a política do EOLRails escrita onde a CI é configurada e no log de decisões, para não regravar o ignore por reflexo.

**Why P2**: Sem o registro, o próximo vermelho de 2027-08-11 tende a ser "resolvido" com um ignore.

**Acceptance Criteria**:

1. The `.specs/STATE.md` SHALL ter a decisão AD-032 com a política "EOLRails nunca é ignorado", o motivo (fingerprint muda por degrau de confiança) e a data em que o 8.1 começa a avisar (2027-08-11).
2. The comentário do step `Brakeman` em `.github/workflows/ci.yml` SHALL dizer que o EOLRails não é ignorado e que o vermelho dele pede upgrade do Rails.
3. The `CLAUDE.md` SHALL citar o Rails 8.1.4 onde hoje cita o aviso de fim de suporte do Rails 8.0.5.1.
4. The comentário do pin do `json` no `Gemfile` SHALL deixar de afirmar que o ActiveSupport passa `quirks_mode`.

**Independent Test**: `grep` por `AD-032` em `STATE.md`, por `EOLRails` no `ci.yml` e por `8.0.5.1` no `CLAUDE.md` e no `Gemfile` (sem ocorrência).

---

### P3: CI verde na branch

**User Story**: Como dono, quero ver a CI verde na `chore/rails-8-1` antes do merge.

**Why P3**: Depende de push, que só o dono autoriza.

**Acceptance Criteria**:

1. WHEN o dono autorizar o push da `chore/rails-8-1` THEN os jobs `lint` e `test` do workflow `CI` SHALL terminar com sucesso.

---

## Edge Cases

- IF o aviso do `CardImagesController` mudar de fingerprint no Brakeman com o Rails 8.1 THEN a entrada SHALL ser regravada com a mesma nota, nunca removida enquanto o aviso existir.
- IF o 8.1.4 emitir aviso de depreciação na suíte THEN ele SHALL ser registrado no *Handoff* do `STATE.md`, sem correção neste corte, salvo se derrubar teste.
- IF o volume `bundle` local não tiver as gems do lock THEN `docker compose run --rm --no-deps app bundle install` SHALL rodar antes de qualquer gate.

## Implicit-requirement sweep

- Failure / partial-failure: coberto pela suíte inteira e pelo build da imagem (RAILS8-02, RAILS8-05).
- Remaining dimensions N/A for this scope: não há dado, rota, autorização nem contrato de API novo.

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| -------------- | ----- | ----- | ------ |
| RAILS8-01 | P1: Rails 8.1.4 com a suíte verde (AC 1) | Execute | Done |
| RAILS8-02 | P1: Rails 8.1.4 com a suíte verde (AC 2) | Execute | Done |
| RAILS8-03 | P1: Rails 8.1.4 com a suíte verde (AC 3) | Execute | Done |
| RAILS8-04 | P1: Rails 8.1.4 com a suíte verde (AC 4) | Execute | Done |
| RAILS8-05 | P1: Rails 8.1.4 com a suíte verde (AC 5) | Execute | Pending |
| RAILS8-06 | P1: Rails 8.1.4 com a suíte verde (AC 6) | Execute | Done |
| RAILS8-16 | P1: Rails 8.1.4 com a suíte verde (AC 7) | Execute | Done |
| RAILS8-07 | P1: Brakeman verde (AC 1) | Execute | Done |
| RAILS8-08 | P1: Brakeman verde (AC 2) | Execute | Done |
| RAILS8-09 | P1: Brakeman verde (AC 3) | Execute | Done |
| RAILS8-10 | P1: Brakeman verde (AC 4) | Execute | Done |
| RAILS8-11 | P2: Política registrada (AC 1) | Execute | Done |
| RAILS8-12 | P2: Política registrada (AC 2) | Execute | Done |
| RAILS8-13 | P2: Política registrada (AC 3) | Execute | Done |
| RAILS8-14 | P2: Política registrada (AC 4) | Execute | Done |
| RAILS8-15 | P3: CI verde na branch (AC 1) | Execute | Pending |

**Coverage:** 16 total; Tasks pulado por porte Medium, todos executados no Execute.

---

## Success Criteria

- [ ] `bin/brakeman` com as flags da CI sai com código 0 no container.
- [ ] `bin/rails test && bin/rubocop` passa com ≥ 1231 testes e 0 falhas.
- [ ] `docker build -f Dockerfile .` conclui.
- [ ] Depois do push autorizado, a CI da `chore/rails-8-1` fica verde.
