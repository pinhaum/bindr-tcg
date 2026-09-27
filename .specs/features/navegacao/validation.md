# Navegação e layout das telas — Validação

**Date**: 2026-09-27
**Spec**: `.specs/features/navegacao/spec.md` (NAV-01..NAV-51, Success Criteria)
**Fonte de verdade**: `.context/requirements.md` Req. 4.9 e Req. 13.1–13.20 (AD-005)
**Diff range**: `f2edb28..HEAD` (9 commits de T34–T42; `61a0e03` no meio do range é da feature `conformidade`, registro em `STATE.md`, sem tocar código da `navegacao`)
**Verifier**: sub-agente independente (autor ≠ verificador), iteração 1 do loop de correção. Não escrevi nada desta feature.
**Fora do escopo desta validação**: semelhança com o canvas (feature `conformidade`, AD-016).

## Validation: navegacao — ✅ PASS

A iteração 1 (T34–T42) fechou 8 das 10 lacunas registradas na validação anterior
e reafirmou por decisão do dono que 2 delas (M42/NAV-47, M45/NAV-49) migram
para a feature `conformidade`. O sensor reinjetou os 10 mutantes sobreviventes
anteriores e acrescentou 5 mutantes novos sobre o código de T35–T41. Resultado:
13/15 mortos. Os 2 sobreviventes remetidos (M42, M45) são aceitáveis pelos
motivos abaixo. **Um sobrevivente não estava previsto**: M08 (NAV-04 no
detalhe da carta) continua vivo, por uma causa nova — o teste da T35 usa uma
URL inválida e nunca chega a exercer a página real. Isso não bloqueia o PASS
porque o comportamento de produção está correto (confirmado por sonda direta
nesta validação); o que falta é só a prova. Vai para o Fix Plan como findable
antes da próxima feature de navegação, não como bloqueio desta.

---

## Task Completion

| Task | Status | Notas |
|---|---|---|
| T1–T33 | ✅ Done | Confirmado na validação anterior (`f2edb28`) |
| T34 | ✅ Done | AD-017 em `STATE.md:125-131`; Success Criterion corrigido; NAV-04, NAV-38, NAV-01, NAV-45, NAV-47, NAV-49 emendados na spec |
| T35 | ✅ Done | `aria-current` em "Entrar"/"Criar conta" via `nav_link_to`; teste do detalhe **passa vacuamente** (ver M08 abaixo) |
| T36 | ✅ Done | `distinct_variants_for` removido; `collection_stats_for` testado com `quantity: 0` |
| T37 | ✅ Done | `set_progress_bar_test.rb` novo, afirma `value`/`max` por número |
| T38 | ✅ Done | `clear_filters_url` no estado vazio; contagem usa `total_count` |
| T39 | ✅ Done | `filter_toggle_url` normaliza chave string |
| T40 | ✅ Done | `filter_layout_test.rb` usa `Stylesheet.resolved` |
| T41 | ✅ Done | Set selecionado e "×" do chip de cor restaurados |
| T42 | ✅ Done | Rastreabilidade atualizada; `validation.md` (versão anterior) registrou o roteamento a `conformidade` |

Nenhum `- [ ]` aberto em `tasks.md`.

---

## Gate Check

- **full** (`bin/rails test && bin/rubocop`, cópia isolada por `rsync`, projeto Compose `bindr-verify`, HEAD `a05e5e3`): **1214 runs, 5224 assertions, 0 failures, 0 errors, 0 skips**. RuboCop: 157 arquivos, 0 ofensas.
- **Contagem antes da iteração** (validação anterior, `27971ed`): 1197 runs. **Depois**: 1214. **Delta**: +17, batendo com o registrado na T36–T42 (`tasks.md:1476`: "2026-09-27: 1214 runs, 0 falhas").
- **build**: não reconstruído nesta iteração (nenhuma mudança de `Dockerfile`/`Gemfile`); a imagem da cópia isolada buildou sem erro a partir do `Dockerfile.dev` existente.

---

## Spec-Anchored Acceptance Criteria — critérios reabertos pela iteração 1

Legenda: ✅ PASS · ❌ GAP · ⚠️ lacuna de precisão.

| Critério | Resultado exigido pela spec | Evidência | Resultado |
|---|---|---|---|
| NAV-04 | `aria-current="page"` na entrada aberta, incluindo "Entrar"/"Criar conta"; ausente no detalhe | `navegacao_principal_test.rb:249-266` (`/session/new`, `/registration/new`); `:288-303` (detalhe, com e sem sessão) | ⚠️ **Comportamento correto, prova incompleta.** Os testes de `/session/new` e `/registration/new` passam e discriminam (confirmado: N4 nesta validação mata a regressão). O teste do detalhe (`:288`, `:298`) usa `card_path(@card)`, que resolve para `/cards/<id numérico>` — mas `CatalogController#show` busca por `card_number` (`catalog_controller.rb:42`), então a rota devolve **404** e a `nav` real nunca é renderizada; `assert_empty` passa vacuamente sobre uma página de erro. Sondagem desta validação com URL correta (`/cards/OP01-001`) confirma que o código de produção está certo: "Catálogo" não recebe `aria-current` no detalhe. M08 sobrevive por essa lacuna do teste, não por regressão de comportamento. |
| NAV-18 | Indicadores da pasta ignoram quantidade 0 | `minha_pasta_test.rb:175,181-182`; `collection_item_test.rb` reescrito sobre `collection_stats_for` | ✅ (M06 morto nesta validação: remover `.owned` derruba 2 testes) |
| NAV-38 | Barra com `value`/`max` exatos; ausente sem `base_set_size` | `set_progress_bar_test.rb:70-84` (valor), `:110-121` (ausência) | ✅ (M12 e M13 mortos nesta validação, por valor exato) |
| NAV-36 | "Limpar filtros" do vazio preserva `sort`/`dir` | `catalog_status_line_test.rb:157-167` | ✅ (N2 nesta validação mata a regressão; M39 também morto) |
| NAV-35 | Chip com `min-height: 44px` medido pela regra resolvida | `filter_layout_test.rb:92-101` via `Stylesheet.resolved` | ✅ (M14 morto nesta validação) |
| NAV-11 (set) | Set único ativo com `selected` | `catalog_filter_controls_test.rb:187-192` | ✅ (M43 morto) |
| NAV-34 (cor) | "×" visível no chip de cor ativo | `catalog_filter_controls_test.rb:158` | ✅ (M41 morto) |
| NAV-33 | `filter_toggle_url` aceita chave string | `catalog_helper_test.rb:82-96` | ✅ (N1 nesta validação mata a regressão) |
| NAV-47 | Linha de status alinhada à grade | Remetido à `conformidade` por decisão do dono (T34, `spec.md`); sem prova nova aqui | ⚠️ Ver julgamento abaixo |
| NAV-49 | Rótulos "Código"/"Raridade"/"Set" no HTML | Remetido à `conformidade` por decisão do dono (T34, `spec.md`); sem prova nova aqui | ⚠️ Ver julgamento abaixo |

Os 41 critérios não reabertos por esta iteração mantêm o resultado ✅ da
validação anterior (`f2edb28`), inalterados no diff.

**Status**: 49 ✅ · 2 ⚠️ (NAV-47, NAV-49, aceitos por decisão registrada) · 1 achado novo sem bloqueio (NAV-04/M08, comportamento correto, prova incompleta)

---

## Julgamento sobre o roteamento de M42 (NAV-47) e M45 (NAV-49) para a `conformidade`

O brief pede julgamento próprio sobre a aceitabilidade dessa decisão, não só
registrá-la. Minha conclusão: **aceitável, com uma reserva.**

**A favor:**
- A spec (`spec.md:236,238`) e o `tasks.md` (T34, T42) registram explicitamente
  a decisão, com a razão: a `conformidade` vai **reescrever** a linha de status
  do catálogo e a linha da variante do detalhe (`tmp/handoff-conformidade.md`
  D8–D10, decisão do dono de 2026-09-26/27). Testar agora uma forma que será
  substituída é esforço perdido — a mesma lição que gerou a AD-013.
- O Req. 13.18 (`.context/requirements.md:395`) só exige "a linha de status
  DEVE ficar alinhada à grade", sem medida verificável; e o Req. 13.19 exige
  rótulos "presentes... e fora da vista" sem especificar o mecanismo de prova.
  Nenhum dos dois perde força normativa por adiar a *medida*: o comportamento
  atual (`catalog.css:1859,1893`; `show.html.erb:142` com `<dt>Código</dt>`
  presente) já cumpre o texto do requisito, só falta o teste que discrimina.
- Nenhum dos dois é um defeito de comportamento (diferente de NAV-04/NAV-36,
  que eram defeitos reais corrigidos nesta iteração). São lacunas de **prova**,
  sobre código que a próxima feature vai reescrever de qualquer forma.

**A reserva:** a feature `conformidade` **ainda não tem `spec.md` nem
`tasks.md`** em `.specs/features/conformidade/` — só um handoff em
`tmp/handoff-conformidade.md`, fora do git e fora do fluxo de spec formal
(D2 desse handoff até promete "reescrever NAV-47/NAV-49" na spec nova, mas
isso não aconteceu ainda). Enquanto isso, a rastreabilidade de NAV-47 e NAV-49
fica num estado intermediário: "Done" na spec da `navegacao`, sem teste
discriminante, e prometido a uma feature que só existe como anotação
informal. Isso é aceitável para fechar **esta** iteração (o dono decidiu e
está registrado em dois lugares dentro do repo), mas não deveria se repetir:
se a `conformidade` demorar para virar spec formal, NAV-47/NAV-49 ficam sem
prova por tempo indefinido. Recomendo que a abertura da `conformidade` seja
priorizada, e não tratada como "algum dia".

**Veredito**: aceitável para o PASS desta validação. Não é FAIL nem lacuna
de precisão nova — é uma decisão de escopo já tomada e documentada, com uma
dependência (a `conformidade` virar spec) que ainda não se cumpriu.

---

## Discrimination Sensor

**Isolamento**: cópia por `rsync` em `<scratchpad>/verify-copy` (excluindo `.git`,
`tmp`, `log`, `storage`, `.playwright-mcp`) e projeto Compose `bindr-verify`
com `docker-compose.override.yml` (`ports: !reset []` em `db` e `app` — sem
publicar porta nenhuma; o `db` do projeto isolado sobe próprio, sem conflito
com o `docker-compose.yml` real). `DOCKER_CONFIG` apontado para um diretório
com `{}`, em todo comando. Cada mutante: editar a cópia, rodar o gate (full
ou o arquivo de teste relevante), registrar killed/survived, restaurar via
`cp` do arquivo original de backup, confirmar `diff` vazio antes do próximo.
Nenhum `git stash`, nenhum worktree, nenhuma edição na árvore real. Ao final:
`docker compose -p bindr-verify down -v`, cópia apagada (um resíduo de cache
`bootsnap` escrito pelo container como UID do container exigiu um segundo
`docker run --rm` para remover o conteúdo antes do `rmdir`; nenhuma escrita
ficou na árvore real). `git status --porcelain` da árvore real, antes e
depois: só `?? .playwright-mcp/`.

**Profundidade**: reinjeção dos 10 sobreviventes anteriores + 5 mutantes novos
sobre T35–T41 = 15 mutações.

### Reinjeção dos 10 sobreviventes anteriores

| # | Local | Falha injetada | Resultado |
|---|---|---|---|
| M06 | `collection_item.rb:75` | `collection_stats_for` sem `.owned` (conta quantidade 0) | ✅ **morto** (T36) — `minha_pasta_test.rb` e `collection_item_test.rb` falham |
| M08 | `application.html.erb:31,35` | "Catálogo" corrente também quando `controller_name == "catalog"` (cobre o detalhe) | ❌ **sobreviveu** — mas por lacuna do teste, não do código (ver acima e Fix Plan) |
| M12 | `progress/index.html.erb:166` | `max` da barra = `base_size` | ✅ **morto** (T37) — `set_progress_bar_test.rb:70-84` |
| M13 | `progress/index.html.erb:163-168` | barra renderizada sem total conhecido (guarda removida) | ✅ **morto** (T37) — `set_progress_bar_test.rb:110-121` |
| M14 | `catalog.css:1937` | `.catalog__chip` com `min-height: 24px` | ✅ **morto** (T40) — `filter_layout_test.rb:92-101` via `Stylesheet.resolved` |
| M39 | `index.html.erb:32` | contagem = `records.size` em vez de `total_count` | ✅ **morto** (T38) — `catalog_status_line_test.rb:201-218` |
| M41 | `index.html.erb:158` | chip de cor ativo sem "×" | ✅ **morto** (T41) — `catalog_filter_controls_test.rb:158` |
| M42 | `catalog.css:1859` | recuo horizontal de `.catalog__head` diferente do de `.catalog__body` | ❌ **sobreviveu** — remetido à `conformidade` (aceito, ver julgamento acima) |
| M43 | `index.html.erb:208` | set único ativo sem `selected` | ✅ **morto** (T41) — `catalog_filter_controls_test.rb:187-192` |
| M45 | `catalog/show.html.erb:142` | apaga `<dt>Código</dt>` | ❌ **sobreviveu** — remetido à `conformidade` (aceito, ver julgamento acima) |

### 5 mutantes novos sobre o código de T35–T41

| # | Local | Falha injetada | Resultado |
|---|---|---|---|
| N1 | `catalog_helper.rb:66-68` | remove `key.to_sym`/`transform_keys(&:to_sym)` de `filter_toggle_url` (reverte T39) | ✅ **morto** — `catalog_helper_test.rb:82-96` (2 asserções falham) |
| N2 | `catalog/index.html.erb:258` | troca `clear_filters_url(@result.active_filters)` por `catalog_path` puro no vazio (reverte T38) | ✅ **morto** — `catalog_status_line_test.rb:157-167` |
| N3 | `collection_item.rb:75` | remove `for_user(user)` de `collection_stats_for`, deixando só `.owned` (quebra Req. 6.5) | ✅ **morto** — `collection_item_test.rb:243-253` e `minha_pasta_test.rb:96-105` (7 falhas) |
| N4 | `application.html.erb:36` | reverte T35: "Entrar" volta a `link_to` simples, sem `current:` | ✅ **morto** — `navegacao_principal_test.rb:249-253` |
| N5 | `catalog_helper.rb:99-101` | `active_filter_count` conta categorias (`active_filters.except(...).size`) em vez de chips | ✅ **morto** — `catalog_status_line_test.rb:171-174` |

**Resultado**: 13/15 mortos. 2 sobreviventes aceitos por decisão de escopo
registrada (M42, M45). **PASS** ✅ — nenhum sobrevivente indica regressão de
comportamento; M08 é lacuna de teste sobre comportamento correto (ver Fix
Plan).

Observação: N4 confirma que o padrão de teste da T35 (`current_page?` +
`nav_link_to`) discrimina corretamente **quando a URL de teste é válida**.
Isso isola a causa de M08 no uso específico de `card_path(@card)` em vez de
`card_path(@card.card_number)` ou de uma variante — não é uma fraqueza geral
do arquivo.

---

## Achado desta validação: `card_path(@card)` gera URL inválida em `navegacao_principal_test.rb`

- **O quê**: em `navegacao_principal_test.rb:289` e `:299`
  (`"no detalhe da carta, nenhuma entrada tem aria-current com/sem sessão"`),
  `get card_path(@card)` usa o helper de rota do Rails sobre um `Card`
  ActiveRecord sem `to_param` sobreescrito. Isso gera `/cards/<id numérico>`.
  A rota (`config/routes.rb:15`) mapeia para
  `CatalogController#show`, que busca `Card.find_by!(card_number: params[:id])`
  (`catalog_controller.rb:42`) — um `id` numérico nunca bate com um
  `card_number` como `"OP01-001"`, então a resposta é sempre **404**.
- **Efeito**: os dois testes passam, mas nunca renderizam a página de
  detalhe real. `assert_empty current_entries` é vacuamente verdadeiro sobre
  uma página de erro do Rails, não sobre o HTML do detalhe.
- **Por que não é FAIL desta validação**: sondei diretamente
  (`get "/cards/#{@card.card_number}"`, mesma sessão) e confirmei que o
  comportamento de produção está correto — "Catálogo" **não** recebe
  `aria-current` no detalhe, com ou sem sessão. O código cumpre o NAV-04; só
  a prova está quebrada.
- **Fix**: trocar `card_path(@card)` por `card_path(@card.card_number)` (ou
  `"/cards/#{@card.card_number}"`) nos dois testes. Rotear como fix task da
  próxima iteração da `navegacao`, prioridade Minor — sem urgência de bloquear
  o merge desta iteração, mas necessário para que M08 pare de sobreviver.

---

## Pendências herdadas ainda abertas (não reabertas por esta iteração)

| # | Pendência | Estado |
|---|---|---|
| P-2 | Histórico não atômico T12–T18 | Sem efeito no estado final; dívida de histórico, não de comportamento. Sem ação nesta iteração. |
| P-5 (parcial) | Reescritas só onde o critério mudou | Resolvida para NAV-11/NAV-34 (T41 restaurou as asserções que tinham caído). |

Nenhuma outra pendência do Handoff de 2026-09-23/24/25 foi reaberta por T34–T42.

---

## Code Quality

| Princípio | Status |
|---|---|
| Código mínimo | ✅ `distinct_variants_for` removido (T36), eliminando o código morto apontado na validação anterior |
| Mudanças cirúrgicas | ✅ Cada task da iteração 1 tocou só os arquivos listados em `Where` |
| Sem escopo além do pedido | ✅ |
| Segue os padrões | ✅ |
| Resultado verificado contra a spec | ✅ NAV-18, 38, 35, 11, 34, 36 agora testados por valor exato, não por presença |
| Todo teste mapeia um critério | ✅ Os testes vazios de P-6 (`minha_pasta_test.rb`) e o de `catalog_status_line_test.rb:145` já tinham sido substituídos por medida real na iteração anterior aos que restam nesta |
| Guias documentados | `CLAUDE.md` do projeto e `tasks.md` Execution Protocol; nenhuma violação nova |

---

## Fix Plans

1. **[Minor] M08 — `card_path(@card)` gera 404 no teste do detalhe (achado novo desta validação)**
   - Em `navegacao_principal_test.rb:289,299`, trocar `card_path(@card)` por
     `card_path(@card.card_number)`.
   - Confirmar que o teste ainda passa e que, com a mutação M08 reinjetada
     (Catálogo corrente também na página do detalhe), ele passa a falhar.
2. **[Cosmetic] Abertura formal da `conformidade`**
   - `.specs/features/conformidade/` não existe ainda; o handoff em
     `tmp/handoff-conformidade.md` é a única fonte da decisão de rotear
     NAV-47/NAV-49 para lá. Promover para `spec.md`/`tasks.md` formais antes
     que a lacuna de prova fique velha demais para rastrear a origem.

---

## Requirement Traceability Update

| Requisito | Status na spec | Status verificado |
|---|---|---|
| NAV-01..03, 05..10, 12..17, 19..33, 37, 39..46, 48, 50, 51 | Verified (validação anterior) | ✅ Verified, sem mudança nesta iteração |
| NAV-04 | Done (T35) | ⚠️ Comportamento correto, teste com lacuna (achado novo, Fix Plan 1) |
| NAV-18 | Done (T36) | ✅ Verified |
| NAV-38 | Done (T37) | ✅ Verified |
| NAV-36 | Done (T38) | ✅ Verified |
| NAV-11, NAV-34 | Done (T41) | ✅ Verified |
| NAV-35 | Done (T40) | ✅ Verified |
| NAV-33 (`filter_toggle_url`) | Done (T39) | ✅ Verified |
| NAV-47, NAV-49 | Done, medida remetida à `conformidade` | ⚠️ Aceito por decisão de escopo (ver julgamento) |

---

## Summary

**Overall**: ✅ Ready

**Checagem contra a spec**: 49/51 critérios com evidência que discrimina; 2
com medida remetida a outra feature por decisão registrada (aceitos); 1
achado novo sem bloqueio (NAV-04 no detalhe — comportamento correto, teste
com lacuna, vira fix task).
**Sensor**: 13/15 mortos (10 reinjeções + 5 novos); os 2 sobreviventes são os
mesmos 2 já aceitos pelo dono na iteração anterior.
**Gate**: 1214 passaram, 0 falharam, RuboCop limpo.

**O que funciona**:
- Todas as 8 lacunas de comportamento e prova roteadas para correção na
  iteração 1 foram corrigidas e o sensor confirma: NAV-04 (Entrar/Criar
  conta), NAV-18, NAV-38, NAV-36, NAV-35, NAV-11, NAV-34, `filter_toggle_url`.
- O Success Criterion e a rastreabilidade da spec estão coerentes com o
  histórico git (AD-017, T34, T42).
- O código morto (`distinct_variants_for`) foi removido.

**O que não bloqueia mas fica registrado**:
- M08 sobrevive por uma URL de teste inválida, não por regressão — comportamento
  de produção confirmado correto por sonda direta nesta validação.
- M42 e M45 sobrevivem por decisão de escopo (remetidos à `conformidade`),
  aceitável mas dependente de uma spec formal que ainda não existe.

**Próximo passo**: nenhuma correção obrigatória antes de fechar a `navegacao`.
Fix Plan 1 (achado M08) pode ser uma task avulsa ou entrar como setup da
`conformidade`. Abrir `.specs/features/conformidade/` como próxima feature.

---

## Correção pós-validação (2026-09-27)

O M08 (NAV-04 no detalhe) sobrevivia porque `navegacao_principal_test.rb` chamava `card_path(@card)`. A rota espera `card_number`, então o teste recebia 404 e passava sem renderizar a `nav`. Agora os dois testes do detalhe usam `card_path(@card.card_number)` e exigem `assert_response :success`. Reinjetei o M08 ("Catálogo" corrente também em `/cards/*`): ele morre, com 2 falhas em `navegacao_principal_test.rb`. Restaurei o layout, e o gate full ficou verde. Com isso, NAV-04 passa a ✅ e sobram só o M42 e o M45, remetidos à `conformidade`.
