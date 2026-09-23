# Interface Validation

## Validation (rodada 3): interface - PASS ✅

**Date**: 2026-09-22
**Spec**: `.specs/features/interface/spec.md` (com a emenda do INT-08 AC3, `a8a9187`)
**Diff range da rodada**: `a8a9187..2b67f20` (`2b67f20`, só `test/design/flash_test.rb`)
**Verifier**: sub-agente independente (autor ≠ verificador), iteração 3 de 3 do ciclo fix → re-verify

**Veredito final**: **PASS** ✅. O Fix 1b fechou o gap 1: M2b, M2c, M2d e o espelho do M2d morrem em `test/design/flash_test.rb:61`. Dos três mutantes extras, o do shorthand morre no próprio `flash_test.rb` e o do peso literal morre na guarda de literais. O do `thin` sobrevive e foi classificado como fora do escopo razoável, com a justificativa abaixo. O gate full termina com exit 0 nos dois comandos. A T14 (revisão visual do dono e do `ecc:a11y-architect`) continua como item humano pendente e não é FAIL. As ressalvas ⚠️ 1 a 6 da rodada 1 continuam registradas, sem mudança.

### O que o Fix 1b mudou

`test/design/flash_test.rb:41-46` (`non_chromatic`) agora:

1. parte de `declared(rules, "body").to_h.slice(*INHERITED)`, com `INHERITED` definido em `:35` (`font-family font-size line-height font-weight font-style letter-spacing text-transform`);
2. aplica `.flash` e depois o modificador;
3. só então descarta as propriedades cromáticas (`:11`).

O sintético `:88-99` reproduz o M2d (`body` com peso, alert sem peso, notice com peso explícito) e assere igualdade (`:97`, `assert_equal`). A asserção real continua em `:61` (`assert_not_equal alert, notice`). A herança de `body` que o teste lê é `app/assets/stylesheets/catalog.css:76` (`font-weight: var(--body-weight)`).

### Sensor da rodada 3

As mutações incidem sobre `.flash--alert` (`app/assets/stylesheets/catalog.css:462-466`). No espelho do M2d, incidem também sobre `.flash--notice` (`catalog.css:460`). Os testes rodados são `test/design/*_test.rb` (11 arquivos) mais `test/integration/flash_ui_test.rb`. No controle, uma cópia sem mutação, o resultado foi `108 runs, 486 assertions, 0 failures`.

| # | Mutação | Aparência resultante | Resultado |
|---|---|---|---|
| M2b | alert: `border-width: 1px; border-color: var(--border-strong); font-weight: var(--body-weight)` | 1px sólido, peso 400, igual a notice | ✅ Morto: `flash_test.rb:61` |
| M2c | alert: `border-style: solid; border-color: var(--border-strong); font-weight: var(--body-weight)` | 1px sólido herdado de `.flash`, peso 400 | ✅ Morto: `flash_test.rb:61` |
| M2d | alert: `border-width: 1px; border-color: var(--border-strong)`, sem peso | peso herdado de `body` (`catalog.css:76`), 400 | ✅ Morto: `flash_test.rb:61`. Na rodada 2 ele sobrevivia. |
| M2d-espelho | alert: `border-width: 1px; border-color: var(--border-strong); font-weight: var(--body-weight)`. notice: `border-style: solid`, sem peso | bordas de 1px sólidas nas duas; notice herda 400 de `body` | ✅ Morto: `flash_test.rb:61` |
| M2e (extra) | alert: `border: 1px solid var(--border-strong)`, em shorthand, sem peso | igual a notice | ✅ Morto: `flash_test.rb:61`. O `expand` (`flash_test.rb:17-28`) decompõe o shorthand do modificador. |
| M2f (extra) | alert: `border-width: 1px; border-color: var(--border-strong); font-weight: 400` | peso 400 em literal, igual ao `var(--body-weight)` de notice | ✅ Morto por outro teste: `test/design/literal_values_test.rb:93` (guarda de literais). Sozinho, `flash_test.rb` não o pegaria, porque compara a string `400` com a string `var(--body-weight)`. |
| M2g (extra) | alert: `border-width: thin; border-color: var(--border-strong); font-weight: var(--body-weight)` | `thin` renderiza como 1px nos navegadores atuais, igual a notice | ⚠️ Sobrevive: 108 runs, 0 falhas |

**Por que o M2g fica fora do escopo razoável.** Ele é da mesma classe do M2f: a igualdade só aparece depois de resolver um valor para outro equivalente (`thin` para 1px, assim como `var(--body-weight)` para 400). Para pegá-lo, o teste precisaria de uma tabela de equivalências de keywords CSS, e esse é o caso que a rodada 3 permite classificar como fora do escopo razoável.

Também não é um defeito plausível. Nenhuma regra da folha usa `thin`, `medium` ou `thick`. Quem revertesse a borda do alerta escreveria `1px`, e isso é o M2b, que morre. O M2f mostra que a forma plausível dessa classe na folha, a de literal numérico, é barrada pela guarda de literais.

O M2g não é FAIL e não gerou fix task. Fica registrado como a ressalva ⚠️ 7.

**Resultado do sensor da rodada 3**: 7 injetadas, 6 mortas, 1 sobrevivente fora do escopo razoável (M2g). ✅

**Isolamento**:

- As cópias da folha ficaram em `tmp/mut3r/`, que o git ignora.
- Um runner nessa pasta redireciona `File.read` do caminho real de `catalog.css` para a cópia, só dentro do processo de teste. Os testes reais são carregados com `require`, sem cópia.
- Nenhum arquivo rastreado foi mutado.
- `tmp/mut3r/` foi movido com `mv` para `/home/pho/.claude/jobs/e4a249da/tmp/` antes do gate e do rubocop.
- `git status --porcelain` ficou idêntico antes e depois (`diff` vazio).

A base encontrada tem duas entradas além das que o orquestrador listou: `M app/controllers/registrations_controller.rb` e `M test/integration/sessions_test.rb`. É trabalho não commitado de outra frente, que não toquei. As duas continuam lá depois do sensor.

### Gate full (rodada 3)

- `docker compose exec -T app bin/rails test` → **exit 0**, `951 runs, 4230 assertions, 0 failures, 0 errors, 0 skips` (40.2s).
- `docker compose exec -T app bin/rubocop` → **exit 0**, `130 files inspected, no offenses detected`.
- Delta sobre a rodada 2 (949/4226): +2 runs, e nenhum teste sumiu.
  - Um é o sintético do M2d (`flash_test.rb:88`).
  - O outro é o teste `"cadastro enviado com os nomes de campo do próprio formulário cria a conta"`, da alteração não commitada em `test/integration/sessions_test.rb`. Ele não pertence a esta feature.

### Rastreabilidade final

| Requirement | Rodada 1 | Rodada 2 | Rodada 3 |
|---|---|---|---|
| INT-06 | ❌ Needs Fix (M2b) | ❌ Needs Fix (M2d) | ✅ Verified: `test/design/flash_test.rb:61`, `:88-99` |
| INT-08 | ❌ Needs Fix | ✅ Verified (texto emendado) | ✅ Verified, sem regressão |
| Demais (INT-01..05, 07, 09..12) | ✅ Verified | ✅ Verified | ✅ Verified, gate full verde |

### Ressalvas que continuam (não bloqueiam)

- **⚠️ 1 a 6**, da rodada 1, sem mudança:
  1. contagem 23 contra 25 (ponto c);
  2. `--radius-full: 360px` sem valor definido em §11.5;
  3. INT-11 contra o Req. 12.11;
  4. sintéticos tautológicos em `contrast_test.rb:281,295` e em `palette_test.rb`;
  5. ramo acromático permissivo em `palette_test.rb:127-134`;
  6. pares de contraste enumerados.
- **⚠️ 7** (nova): `flash_test.rb:41-46` compara os valores como texto, sem resolvê-los. Valores equivalentes escritos de formas diferentes (`thin` e `1px`, `400` e `var(--body-weight)`) contam como diferentes. A guarda de literais cobre a forma numérica. A forma com keyword (M2g) fica fora do escopo razoável.

### Itens humanos pendentes

- **T14**: revisão visual do dono e revisão do `ecc:a11y-architect`. ⏳ Pendente. Não conta como FAIL.

### Nota de formato

Para que `validate_state.py` leia só o veredito final, fiz três trocas de rótulo, sem mudar o conteúdo das rodadas anteriores:

- o cabeçalho da rodada 2 passou a ser `# Rodada 2 (preservada)`;
- o rótulo `**Result**` da rodada 2 passou a ser `**Resultado da rodada 2**`;
- o rótulo `**Result**` da rodada 1 passou a ser `**Resultado da rodada 1**`.

**Ranked gaps restantes**: nenhum bloqueante. Restam a T14, que é item humano, e as ressalvas ⚠️ 1 a 7.

---

# Rodada 2 (preservada): interface - FAIL ❌

**Date**: 2026-09-22
**Spec**: `.specs/features/interface/spec.md` (com a emenda do INT-08 AC3, `a8a9187`)
**Diff range da rodada**: `278e66b..a8a9187` (`28d1094`, `a8a9187`)
**Verifier**: sub-agente independente (autor ≠ verificador), iteração 2 de 3 do ciclo fix → re-verify

**Veredito**: **FAIL** ❌. O gap 2 fechou. O gap 1 fechou só para a forma exata do M2b: um mutante novo da mesma classe (M2d, `flash--alert` sem a declaração de peso) sobrevive, porque o estilo efetivo de `flash_test.rb:37-41` junta `.flash` e o modificador, mas não inclui a herança de `body` (`catalog.css:76`, `font-weight: var(--body-weight)`). A T14 continua aberta como item humano e não conta como FAIL.

### Gap 1 (INT-06, M2b): fechado para M2b e M2c, reaberto por M2d

`test/design/flash_test.rb:37-41` agora compara `declared(".flash").merge(declared(modificador))`, sem as propriedades cromáticas, e `:17-28` expande o atalho `border` em `border-width`, `border-style` e `border-color`. O sintético `:71-81` reproduz o M2b e assere igualdade. A asserção real é `:56` (`assert_not_equal alert, notice`).

| # | Mutação em `.flash--alert` (`catalog.css:462-466`) | Aparência resultante | Resultado |
|---|---|---|---|
| M2b | `border-width: 1px; border-color: var(--border-strong); font-weight: var(--body-weight)` | 1px sólido, peso 400: igual a notice, só a cor difere | ✅ Morto: `flash_test.rb:56`, os dois mapas saem idênticos |
| M2c (nova, pedida) | `border-style: solid; border-color: var(--border-strong); font-weight: var(--body-weight)` | 1px sólido (herdado de `.flash`), peso 400 | ✅ Morto: `flash_test.rb:56` |
| **M2d** (nova, do Verifier) | `border-width: 1px; border-color: var(--border-strong)`, **sem** `font-weight` | 1px sólido; peso herdado de `body` (`catalog.css:76`) = 400 = o `font-weight: var(--body-weight)` explícito de `.flash--notice` (`catalog.css:460`) | ❌ **Sobrevive** em `flash_test.rb` e em toda a suíte de design mais `flash_ui_test.rb` (107 runs, 0 falhas) |

Por que M2d vale como M2b: apagar a linha do peso é a mutação mais provável na prática (remover declaração exigida), e o resultado renderizado é o mesmo defeito que motivou a feature. O teste acusa "ausente" contra "400 explícito" como diferença, mas o navegador resolve os dois para 400. O `.flash` renderizado é `<p>` (`layouts/_flash_message.html.erb:14`) sem ancestral que redefina o peso: `.flash-area` só tem `:empty` (`catalog.css:685`).

### Gap 2 (INT-08, flash da wishlist): fechado pela emenda

O texto emendado (`.specs/features/interface/spec.md:120-122`, `.context/requirements.md` Req. 12.7) exclui mensagem de flash. `app/controllers/wishlist_items_controller.rb:50` é flash `notice` e sai por `layouts/_flash_message.html.erb:14`: está fora do critério.

Varredura de `card_number` e `variant_code` em `app/views`, `app/helpers`, `app/controllers`, `config/locales` e `app/javascript`:

- Em `<code class="code">`: `_ownership.html.erb:56`, `wishlist_items/index.html.erb:40`, `catalog/show.html.erb:112`, `collection_imports/resumo.html.erb:215`.
- Em elemento de classe com estilo `code`, conferido com `Stylesheet.code_styled?` = `true` para cada classe: `card-tile__placeholder-number` (`_card_tile.html.erb:42`), `card-tile__number` (`:54`), `card-detail__number` (`catalog/show.html.erb:8`), `variant__code` (`:126`), `import-summary__number-card` e `import-summary__variant` (`resumo.html.erb:174-175`), `import-preview__number` e `import-preview__variant` (`collection_imports/show.html.erb:165-166`).
- Excluídos pela T11 (`tasks.md:485`): `aria-label` em `_ownership.html.erb:71,101`, `wishlist_items/_mark.html.erb:49`, `wishlist_items/index.html.erb:92`; `<title>` em `catalog/show.html.erb:1`.
- Sem texto renderizado: rotas (`card_path`, `card_image_path`), `sort_by`, `alt: ""`.
- Os únicos flashes que citam identificador são o de `wishlist_items_controller.rb:50`. Os outros (`collection_items_controller.rb:51,85,87`, `sessions_controller.rb:42,49`, `registrations_controller.rb:23`, `wishlist_items_controller.rb:53,74`, `collection_imports_controller.rb:131,180`) não citam, e todos seriam excluídos de qualquer forma.

Nenhuma ocorrência fora de `code` que não seja flash. INT-08: ✅ PASS contra o texto emendado.

### Não regressão

- **Gate full**: `docker compose exec -T app bin/rails test` → `949 runs, 4226 assertions, 0 failures, 0 errors, 0 skips` (37.3s). `bin/rubocop` → `130 files inspected, no offenses detected`. São +1 run e +1 assertion sobre a rodada 1 (948/4225), que é o sintético novo de `flash_test.rb:71`. Nenhum teste sumiu.
- **Mutações da rodada 1 repetidas por amostragem**:

| # | Mutação | Teste | Resultado |
|---|---|---|---|
| M1 | `catalog.css:22` `--ink-muted: #3a4a52` | `contrast_test.rb` | ✅ Morto: 3 falhas (`ink-muted/surface-base: 1.92:1`, `surface-raised: 1.61:1`, `surface-sunken: 2.1:1`) |
| M3 | `collection_items/_ownership.html.erb:34` `quantity.positive?` → `quantity >= 0` | `ownership_badge_ui_test.rb` | ✅ Morto: `:34` e `:58` |
| M4b | `catalog.css:658` `outline: 2px solid currentcolor` | `focus_test.rb` | ✅ Morto: `:64` e `:72` |

### Sensor da rodada 2

Cópia isolada em `tmp/mut2/` (ignorada pelo git): cada mutante é uma cópia de `catalog.css`, e um runner (`tmp/mut2/run_test.rb`) redireciona `File.read` do caminho real para a cópia, só dentro do processo de teste, e carrega os testes reais sem copiá-los. O controle (cópia sem mutação) passou: 107 runs, 0 falhas. A mutação de view (M3) foi feita no arquivo rastreado, com backup em `/home/pho/.claude/jobs/e4a249da/tmp/ownership.bak` e restauração logo depois (`git diff` vazio). `tmp/mut2/` foi movido com `mv` para `/home/pho/.claude/jobs/e4a249da/tmp/`. `git status --porcelain` antes e depois: idêntico (`diff` vazio), com a base `M .specs/LESSONS.md`, `M .specs/lessons.json`, `?? .specs/features/interface/validation.md`, `?? untitled.md`.

**Resultado da rodada 2**: 6 injetadas, 5 mortas, 1 sobrevivente (M2d). FAIL ❌.

### Ressalvas da rodada 1

As ressalvas 1 a 6 continuam como estavam, sem motivo novo para mudar: contagem 23 contra 25 (ponto c), `--radius-full: 360px` sem valor em §11.5, INT-11 contra o Req. 12.11, sintéticos tautológicos de `contrast_test.rb:281,295` e `palette_test.rb`, ramo acromático permissivo de `palette_test.rb:127-134` e pares de contraste enumerados. São lacunas de precisão ou de qualidade e não bloqueiam.

### Fix 1b: incluir a herança no estilo efetivo do flash

- **Root cause**: `flash_test.rb:37-41` parte de `.flash`, mas uma propriedade herdada que nenhum dos dois declara (hoje só `font-weight`, declarado em `body`, `catalog.css:76`) fica ausente num lado e explícita no outro. O `Hash` acusa diferença onde o navegador renderiza igual.
- **Fix task**: semear o efetivo com as propriedades herdáveis não cromáticas de `body` (pelo menos `font-weight`, `font-size`, `line-height`, `font-family`, `font-style`) antes de aplicar `.flash` e o modificador. Acrescentar um sintético com o caso M2d (`.flash--alert` sem peso contra `.flash--notice { font-weight: var(--body-weight) }` com `body { font-weight: var(--body-weight) }`) que assere igualdade. A alternativa de só remover os no-ops de `.flash--notice` (`catalog.css:460`) não basta: o mutante simétrico (`alert` com peso 400 explícito e `notice` sem declaração) sobreviveria.
- **Verify**: M2b, M2c e M2d morrem; o gate full passa.
- **Priority**: Major. É o mesmo critério do Fix 1, e esta é a iteração 2 de 3.

### Rastreabilidade (rodada 2)

| Requirement | Rodada 1 | Rodada 2 |
|---|---|---|
| INT-06 | ❌ Needs Fix (M2b) | ❌ Needs Fix (M2d) |
| INT-08 | ❌ Needs Fix / decisão do dono | ✅ Verified (texto emendado) |
| Demais (INT-01..05, 07, 09..12) | ✅ Verified | ✅ Verified, sem regressão |

**Ranked gaps restantes**:
1. INT-06, M2d sobrevive: o estilo efetivo não considera herança de `body`, em `test/design/flash_test.rb:37-41` contra `app/assets/stylesheets/catalog.css:76`. Veja o Fix 1b.
2. T14, a revisão visual do dono e do `ecc:a11y-architect`, continua pendente. É item humano e não conta como FAIL.

---

# Rodada 1 (preservada)

**Date**: 2026-09-22
**Spec**: `.specs/features/interface/spec.md`
**Diff range**: `d9fa961..278e66b` (T4–T13, 11 commits). As T1–T3 foram commitadas antes da feature `imagens`, em `642def6..d2409f7` (`7662a60`, `14fbd39`, `d2409f7`), e foram verificadas no estado de `278e66b`.
**Verifier**: sub-agente independente (autor ≠ verificador)

**Veredito (rodada 1)**: **FAIL** ❌. Há um mutante sobrevivente no INT-06 (M2b) e uma ocorrência de `variant_code` fora de `code` no INT-08. A T14 continua aberta. Ela não conta como FAIL porque é item humano.

---

## Task Completion

| Task | Status | Notes |
|------|--------|-------|
| T1 | ✅ Done | Tokens e `color-scheme: dark` estão em `:root` (`catalog.css:10-67`). Commit `7662a60`, fora do intervalo. |
| T2 | ✅ Done | Contraste calculado. Commit `14fbd39`, fora do intervalo. |
| T3 | ✅ Done | Paleta sem sombra e sem gradiente. Commit `d2409f7`, fora do intervalo. |
| T4 | ✅ Done | `85724cb` |
| T5 | ✅ Done | `8aad3d7` |
| T6 | ✅ Done | `022009b` |
| T7 | ✅ Done | `dbe2772`. A guarda de literais cobre a folha inteira. |
| T8 | ⚠️ Done, com teste fraco | `b4ab25c`. O mutante M2b sobrevive: veja o Sensor. |
| T9 | ✅ Done | `28abd94` |
| T10 | ✅ Done | `c7d3e6c`. A guarda é derivada das views e cobre as 25 classes medidas. |
| T11 | ⚠️ Done, com uma ocorrência aberta | `6d79560`. O flash de `wishlist_items_controller.rb:50` ficou de fora: veja o ponto (a). |
| T12 | ✅ Done | `94ac922` |
| T13 | ✅ Done | `4c223e4`, `278e66b` |
| T14 | ⏳ Aberta (item humano) | A revisão visual do dono e a revisão do `ecc:a11y-architect` estão pendentes. Não conta como FAIL. |

Os sete arquivos protegidos (`catalog_grid_test.rb`, `progress_ui_test.rb`, `collection_ownership_ui_test.rb`, `collection_export_link_test.rb`, `collection_import_preview_ui_test.rb`, `collection_import_summary_test.rb`, `set_progress_plan_test.rb`) não aparecem em `git diff d9fa961..278e66b`. `catalog_grid_test.rb` só foi editado pela feature `imagens` (`ee86c9c`, `d9fa961`).

---

## Spec-Anchored Acceptance Criteria

### P1: Interface que não disputa com a arte

| Criterion | Spec-defined outcome | `file:line` + assertion | Result |
|---|---|---|---|
| INT-01 (P1.1): todo valor de cor, tipografia, espaçamento e raio é custom property em `:root` | 10 cores de §11.3, 6 estilos de §11.4 (tamanho, altura e peso), `space-1..4`, `radius-sm/md/full` | `test/design/tokens_test.rb:53,71,110,133` com `assert_equal(expected_value, tokens[token_name])`. A lista esperada vive no teste. | ✅ PASS |
| INT-02 (P1.2): `color-scheme: dark` e nenhuma `prefers-color-scheme` | presença e ausência | `test/design/tokens_test.rb:155` com `assert Stylesheet.has_color_scheme_dark?`. `test/design/tokens_test.rb:162` com `refute Stylesheet.has_prefers_color_scheme?` | ✅ PASS |
| INT-03 (P1.3): duas matizes, 228° e 66°, mais `danger` em 28° | toda cor é token de `:root` com matiz no alvo; nenhum literal de cor fora de `:root` | `test/design/palette_test.rb:99` com `assert hue_diff <= 6.0` por token. `palette_test.rb:30,43,56` com `found_hexes.empty?` e `rgb/hsl` vazios fora de `:root`. `palette_test.rb:257`: nenhuma cor nomeada. | ✅ PASS, com a ressalva baixa 5 |
| INT-04 (P1.4): sem sombra e sem gradiente | zero ocorrências | `test/design/palette_test.rb:185,195,205,215` com `matches.empty?` para `box-shadow`, `text-shadow`, `drop-shadow(` e `*-gradient(` | ✅ PASS |
| INT-01/INT-12 (P1.5, P1.6): os blocos consomem token; nenhum literal duplica token | nenhuma propriedade governada com literal, em qualquer seletor fora de `:root` | `test/design/literal_values_test.rb:90` com `assert_empty violations`, que varre `Stylesheet.rules` inteiro. `:116`: o conjunto de blocos é igual a `EXPECTED_BLOCKS`. `:97`: a guarda acusa um literal sintético num bloco fora da lista. | ✅ PASS |
| INT-12 (Req. 12.12): as verificações de 360px continuam passando | testes do Req. 2.5 verdes e sem edição | `test/integration/catalog_grid_test.rb:299` com `assert_operator pixels, :<=, 360` (sem diff no intervalo). `test/design/layout_test.rb:36,60` com `assert_operator total, :<=, 360` (`2×150 + 48 + 8 = 356`). | ✅ PASS |

### P2: Contraste provado, não afirmado

| Criterion | Spec-defined outcome | `file:line` + assertion | Result |
|---|---|---|---|
| INT-05 (P2.1): 4.5:1 em todo par de texto normal | `ink`, `ink-muted` e `accent` sobre as 3 superfícies; `on-accent` sobre `accent` e `danger`; `danger` sobre a base | `test/design/contrast_test.rb:81-202` (12 testes) com `assert(ratio >= 4.5, "Contraste X/Y: N:1 …")`. A fórmula foi provada em `:70` (21:1) e em `:75` (1:1). | ✅ PASS, com a ressalva baixa 6 |
| INT-05 (P2.2): 3:1 em borda de controle e anel de foco | `border-strong` e `accent` sobre as 3 superfícies | `test/design/contrast_test.rb:214-269` (6 testes) com `assert(ratio >= 3.0, …)` | ✅ PASS |
| INT-05 (P2.3): a falha nomeia o par e a razão | mensagem com o par e `N:1` | Mensagem real nas asserções de `:81-269`. O mutante M1 produziu `Contraste ink-muted/surface-base: 1.92:1 (mínimo 4.5:1)`. O teste sintético `:295` é tautológico: veja a ressalva baixa 4. | ✅ PASS, provado pelo sensor |
| INT-05 (P2.4): `border` só como hairline, nunca em controle, foco ou marca com significado | `var(--border)` ausente das regras de controle e de foco | `test/design/focus_test.rb:87` com `assert_empty decorative_border_on_controls(@rules)`. `:91` é a guarda sintética. O mutante M16 foi morto. | ✅ PASS |

### P3: Estado legível sem depender de cor

| Criterion | Spec-defined outcome | `file:line` + assertion | Result |
|---|---|---|---|
| INT-06 (P3.1): erro se distingue de sucesso por mais do que a cor | `flash--alert` e `flash--notice` diferem **visualmente** em propriedade não cromática | `test/design/flash_test.rb:29` com `assert_not_equal alert, notice`, sobre as declarações não cromáticas **da própria regra do modificador**. `test/integration/flash_ui_test.rb:10` com `assert_select "[role=alert] p.flash.flash--alert"`. `:18` faz o mesmo para `flash--notice`. | ❌ GAP: o mutante M2b sobrevive. A comparação é textual e não considera a cascata de `.flash`. Veja o Fix 1. |
| INT-07 (P3.2): badge com a quantidade só quando possuída; faltante sem badge | quantidade 2 mostra badge "2"; quantidade 0 e ausência de registro não mostram badge; o Stream 0→1 traz o badge; o Stream 1→0 não traz | `test/integration/ownership_badge_ui_test.rb:30` com `assert_select "… .ownership__count--owned", text: "2"`. `:34` com `assert_select "… .ownership__count--owned", 0` para as duas ausências. `:44` e `:58` cobrem o Stream. `test/design/ownership_badge_test.rb:31`: `radius-full` + `accent` + `on-accent`. `:40`: único uso de `radius-full`. `:50`: um só token âmbar. | ✅ PASS |
| INT-07 (Req. 12.6): estado ativo de filtro por rótulo escrito | o chip exibe o nome da cor | `test/integration/color_chip_ui_test.rb:13` com `assert_select ".filter-chip .filter-chip__label", text: "Cor: Red"` | ✅ PASS |
| INT-08 (P3.3): `card_number` e `variant_code` em `code` **em toda ocorrência**, inclusive inline | todo texto renderizado do identificador está num elemento em estilo `code` (mono, 500, 13px/18px) | `test/integration/code_identifiers_ui_test.rb:43-111` com `assert classes.any? { Stylesheet.code_styled?(klass) }` por tela (grade, detalhe, posse, wishlist, pré-visualização e resumo). `test/design/code_style_test.rb:14` com `assert_empty off`. **Sem evidência** para o flash `notice` de `app/controllers/wishlist_items_controller.rb:50`, que renderiza `"#{variant.card.name} #{variant.variant_code} na lista de desejos: …"` como texto puro em `layouts/_flash_message.html.erb:14`. | ❌ GAP, bloqueado por decisão do dono. Veja o ponto (a). |
| INT-09 (P3.4): anel sólido de 2px em `accent` com 2px de deslocamento | uma regra `:focus-visible` que cobre `a`, `button`, `input`, `select`, `textarea` e `summary`; nenhum anel removido, translúcido ou em `currentcolor` | `test/design/focus_test.rb:52` com `assert_equal 1, focus_rules.size`, `assert_includes parts, "summary:focus-visible"`, `RING = /\Aoutline:\s*2px solid var\(--accent\)\z/` e `assert_includes declarations, ["outline-offset","2px"]`. `:69`: `assert_empty ring_breakers` e sem `currentcolor`. | ✅ PASS |
| INT-10 (P3.5): sem emoji | zero codepoints de emoji em views, helpers e locales | `test/design/content_rules_test.rb:37` com `assert_empty offenses`, com prova de que entrou nos 3 diretórios. `:52`: a guarda sintética acusa U+2705, U+1F525, U+2B50 e U+FE0F. O mutante M14 foi morto. | ✅ PASS |
| INT-11 (P3.6): chip das cores do jogo nunca preenchido com `accent` | nenhum `background` em `accent` em `filter-chip*`; chip com `border-strong` | `test/design/content_rules_test.rb:58` com `assert_empty accent_filled_chips(...)` e `assert_match(/border:\s*1px solid var\(--border-strong\)/)` | ✅ PASS para a spec. ⚠️ Lacuna de precisão contra o Req. 12.11: veja a ressalva 3. |

**Status**: ❌ Há dois gaps (INT-06 por teste não discriminante, INT-08 por ocorrência aberta) e ⚠️ quatro lacunas de precisão sinalizadas.

---

## Pontos conhecidos

### (a) O flash de `wishlist_items_controller.rb:50` contra o INT-08: **FAIL do INT-08**, não lacuna de precisão

O INT-08 é preciso: "em toda ocorrência, inclusive inline em texto corrido". O flash `notice` do `create` é texto que o usuário lê, compõe `variant_code` no meio de uma frase e sai por `layouts/_flash_message.html.erb:14` (`<%= message %>`), sem `code`. É exatamente o caso inline que o critério nomeia. A lacuna, portanto, não está na precisão da spec: está na **permissão**.

A correção não cabe nas duas exceções de view da spec (classe condicional e `<code>` inline em view). Ela exigiria uma de três coisas:

- flash com HTML composto no controller, com risco de `html_safe` sobre dado da fonte;
- uma mudança de estrutura no partial do flash;
- ou uma emenda do Req. 12.7 que exclua mensagens transitórias compostas no servidor.

As três são decisões do dono (AD-005 e CLAUDE.md: "Se um requisito se mostrar errado durante a execução, pare e corrija `requirements.md`"). O resultado fica ❌ GAP bloqueado até a decisão, e não uma aprovação com ressalva. A regra do método é não aprovar em silêncio um critério literal não atendido.

### (b) A regra de foco lista elementos e também 12 classes

`catalog.css:640-660` é **uma** regra (`focus_test.rb:52` com `assert_equal 1, focus_rules.size`). Os seis seletores de elemento cobrem todo focável. As 12 classes são redundantes na declaração: têm as mesmas duas propriedades e mudam só a especificidade. Elas existem porque testes protegidos procuram cada controle nesse agrupamento. Não há divergência de comportamento, então não é FAIL. Vale registrar que remover um seletor de classe não quebra o anel, mas quebra os testes protegidos.

### (c) 23 modificadores na spec contra 25 classes medidas

A spec (Problem Statement, Goals, Success Criteria) e `.context/tasks.md` §6.4 dizem "23 modificadores". O inventário de `tasks.md` mediu 25 classes: 15 modificadores e 10 elementos. A guarda `class_coverage_test.rb:52` é **derivada** das views e não depende do número (o mutante M13 foi morto), então o comportamento está coberto. O número da spec está errado: é ⚠️ lacuna de precisão, com correção prevista na §7.2.

---

## Discrimination Sensor

A cópia isolada ficou em `tmp/mut/` (ignorada por `.gitignore:5`), com `catalog.css` mutado e cópias dos testes apontando para ela. As mutações em view foram feitas no arquivo rastreado, com backup em `/home/pho/.claude/jobs/e4a249da/tmp/` e `git checkout --` logo depois. `git status --porcelain` era `?? untitled.md` antes e depois (comparado com `diff`, idêntico). `tmp/mut/` foi movido com `mv` para fora do repo.

| # | Alvo | Mutação | Teste que rodou | Resultado |
|---|------|---------|-----------------|-----------|
| M1 | `catalog.css:22` | `--ink-muted: #9ba7ad` → `#3a4a52` (contraste baixo) | `contrast_test.rb` | ✅ Morto: 3 falhas, `ink-muted/surface-base: 1.92:1 (mínimo 4.5:1)` |
| M2 | `catalog.css:462-466` | `flash--alert` idêntico a `flash--notice` (`border-style: solid; font-weight: var(--body-weight)`), mudando só a cor | `flash_test.rb` | ✅ Morto (`flash_test.rb:33`) |
| **M2b** | `catalog.css:462-466` | `flash--alert` com `border-width: 1px; font-weight: var(--body-weight)`, **visualmente igual** a `notice`, porque `.flash` já é `1px solid` e o peso herdado é 400; só a cor difere | `flash_test.rb` e depois toda a suíte de design | ❌ **Sobrevive** (111 runs, 0 falhas) |
| M3 | `_ownership.html.erb:34` | `if quantity.positive?` → `if quantity >= 0` (badge com 0) | `ownership_badge_ui_test.rb` | ✅ Morto: `:34` e `:58` |
| M4a | `catalog.css:645` | remove `summary:focus-visible` | `focus_test.rb` | ✅ Morto: "o anel de foco não cobre summary" |
| M4b | `catalog.css:658` | `outline: 2px solid currentcolor` | `focus_test.rb` | ✅ Morto: 2 falhas, "sobrou anel em currentcolor" |
| M5 | `catalog.css:89` | tira `.card-detail__number` do grupo `code` | `code_style_test.rb` e `code_identifiers_ui_test.rb` | ✅ Morto: 2 falhas |
| M6 | `catalog.css:572` | badge com `radius-md` em vez de `radius-full` | `ownership_badge_test.rb` | ✅ Morto: 2 falhas |
| M7 | `wishlist_items/index.html.erb:40` | tira o `<code>` do `variant_code` | `code_identifiers_ui_test.rb` | ✅ Morto (`:71`) |
| M8 | `catalog.css` | `.filter-chip { background-color: var(--accent) }` | `content_rules_test.rb` | ✅ Morto (`:59`) |
| M9 | `catalog.css:447` | `.flash { padding: 8px … }` (literal) | `literal_values_test.rb` | ✅ Morto: "literal 8px" |
| M10 | `catalog.css:12` | `--tile-min: 170px` | `layout_test.rb` | ✅ Morto: `396.0px, acima de 360px` |
| M11 | `_flash_message.html.erb:14` | `flash--<%= kind %>` → `flash--notice` | `flash_ui_test.rb` | ✅ Morto (`:10`) |
| M12 | `catalog.css:464` | `flash--alert` com `border-color: var(--danger)` | `flash_test.rb` | ✅ Morto (`:51`) |
| M13 | `catalog.css:762` | `.wishlist-item__status--pending { }` (regra vazia) | `class_coverage_test.rb` | ✅ Morto: lista a classe |
| M14 | `app/views/_mut_emoji.html.erb` (novo, não rastreado) | `Atendido ✅` | `content_rules_test.rb` | ✅ Morto: `U+2705` |
| M15 | `catalog.css:22` | remove `--ink-muted` (Edge Case do token removido) | `contrast_test.rb` | ✅ Morto: "Token --ink-muted não encontrado na folha" |
| M16 | `catalog.css:499` | `.auth__field input { border: 1px solid var(--border) }` | `focus_test.rb` | ✅ Morto (`:88`) |

**Sensor depth**: expandido. Foram 18 mutações e todas as quatro pedidas estão presentes (M1, M2, M3, M4a e M4b).
**Resultado da rodada 1**: 17/18 mortas, **1 sobrevivente (M2b)**. **FAIL** ❌.

Por que M2b importa: o INT-06 é o único defeito percebido da feature, e o teste prova diferença **textual** entre as regras dos modificadores, não diferença **renderizada**. Hoje `.flash--notice { border-style: solid; … }` (`catalog.css:460`) já é um no-op sobre `.flash { border: 1px solid … }` (`:449`). A distinção real vem só de `border-width: 2px` e do peso 600 do `alert`. Se alguém trocar esses valores pelos do `.flash` base, o teste continua verde e a mensagem de erro volta a diferir só por cor.

---

## Edge Cases

- [x] Token removido ou renomeado faz o contraste falhar. As asserções reais chamam `assert_token_present` (`contrast_test.rb:82-83` etc.). M15 foi morto. O teste `:281` é tautológico (ressalva 4), mas a garantia está nos testes reais.
- [x] Largura fixa acima de 360px faz o Req. 2.5 falhar: `catalog_grid_test.rb:299` (sem edição) e `layout_test.rb:36,60`. M10 foi morto.
- [x] Imagem que falha deixa o placeholder na mesma caixa, sem reflow: `literal_values_test.rb:197`. Imagem e placeholder saem da mesma regra (`position: absolute; inset: 0; 100%`), a proporção é só do poço (`aspect-ratio: 5 / 7`) e nenhum dos dois declara caixa própria. Isso é prova textual. A prova renderizada fica com a T14.
- [x] Par que reprova se corrige no token, não no limiar. Nenhum par reprovou: os tokens batem com §11.3 (`tokens_test.rb:53`), e os limiares 4.5 e 3.0 são literais do teste (`contrast_test.rb:88`, `:219` etc.).

---

## Code Quality

| Principle | Status |
|---|---|
| Minimum code | ✅ |
| Surgical changes | ✅ As views mudaram só em classe condicional e `<code>` inline. O link da wishlist passou para a forma em bloco, com o texto preservado (`code_identifiers_ui_test.rb:72`). |
| No scope creep | ✅ |
| Matches patterns | ✅ Os testes textuais seguem `Stylesheet.rules`. |
| Spec-anchored outcome check | ❌ INT-06 (M2b) e INT-08 (flash). |
| Per-layer coverage | ✅ Folha em unit; HTML e Stream em integração. |
| Every test maps to a requirement | ✅ Cada arquivo cita o INT no cabeçalho. |
| Documented guidelines followed | ✅ CLAUDE.md, `.context/design.md` §11.7 e o protocolo de `tasks.md` (sem edição nos testes protegidos). |

### Ressalvas de precisão e de qualidade (não bloqueiam por si)

1. ⚠️ **Contagem 23 contra 25**: o ponto (c) acima.
2. ⚠️ **`--radius-full: 360px`** (`tokens_test.rb:50`, `catalog.css:64`). §11.5 não dá valor para `radius-full`, então o teste assere um número que a spec não define. O valor coincide com o teto de `catalog_grid_test.rb:299` (`<= 360`): um `9999px` convencional quebraria o teste protegido. Documentar em §11.5.
3. ⚠️ **INT-11 contra o Req. 12.11**: `.context/requirements.md` 12.11 diz que a seleção do chip "DEVE ser indicada por anel de 2px em `accent` mais rótulo escrito". A spec (P3.6) e §11.6 fixam, enquanto a P8 estiver aberta, "tratamento neutro com `border-strong` mais rótulo". A implementação segue a spec e §11.6. O Req. 12.11 precisa dizer que a segunda cláusula só vale depois da P8, senão `.context/` contradiz a si mesmo.
4. **Testes sintéticos tautológicos**: `contrast_test.rb:281` e `:295` não exercitam `assert_token_present` nem a mensagem real, reimplementam os dois. Os sintéticos de `palette_test.rb:70-95` e `:228-329` testam a própria regex literal do teste, não o caminho de produção. A discriminação real foi provada pelo sensor (M1, M15), então fica só como qualidade, severidade baixa.
5. **Ramo acromático permissivo**: `palette_test.rb:127-134` faz `assert(true)` para croma < 0.005. Um cinza puro entraria sem checagem de matiz. Hoje nenhum token cai nesse ramo. A regra é explícita, como o Done-when pede, mas aceita qualquer cinza como parte da "matiz 228°".
6. **Pares de contraste enumerados, não derivados do uso**: os 18 pares de `contrast_test.rb` foram conferidos à mão contra a folha. Os textos em uso são `ink`, `ink-muted` e `on-accent`; os fundos em uso são `surface-*` e `accent`. Todos os pares usados estão cobertos. Uma combinação nova de cor de texto e fundo, porém, não entraria no teste sozinha.

---

## Gate Check

- **Gate command** (full): `docker compose exec -T app bin/rails test && docker compose exec -T app bin/rubocop`
- **Result**: `948 runs, 4225 assertions, 0 failures, 0 errors, 0 skips` (35.9s, 8 processos). Rubocop: `130 files inspected, no offenses detected`.
- **Test count before feature**: 772 runs (medido antes da T1, conforme `tasks.md`).
- **Test count after feature**: 948 runs. O delta de +176 inclui os testes da feature `imagens`, commitada entre T3 e T4. O total só cresceu.
- **Skipped tests**: nenhum.
- **Failures**: nenhuma.

---

## Fix Plans

### Fix 1: INT-06 compara texto, não aparência (M2b)

- **Root cause**: `flash_test.rb:13-18` coleta as declarações de `sel == ".flash--alert"` e `sel == ".flash--notice"` isoladamente. Declaração que repete o valor herdado de `.flash` conta como diferença, e declaração que zera a diferença passa despercebida.
- **Fix task**: comparar o estilo **efetivo** não cromático de `.flash` + modificador, com o modificador vencendo por ordem (no molde de `Stylesheet.resolved`). Expandir os atalhos de `border` em `width`/`style` antes de comparar. Exigir que o efetivo de `alert` difira do de `notice`. Acrescentar um sintético com o caso M2b (modificador que repete o valor do base) e confirmar que ele falha. Opcional: remover o no-op `border-style: solid` de `.flash--notice` (`catalog.css:460`).
- **Verify**: rodar de novo a mutação M2b: ela precisa morrer.
- **Priority**: Major. É o defeito que motivou a feature.

### Fix 2: INT-08, flash com `variant_code` (bloqueado por decisão)

- **Root cause**: `wishlist_items_controller.rb:50` compõe o identificador em texto puro. O flash não passa por view que possa envolvê-lo em `code`.
- **Fix task**: aguardar a decisão do dono entre duas saídas. (i) Emendar o Req. 12.7, o INT-08 e §11.4 para excluir mensagens transitórias compostas no servidor. (ii) Autorizar a mudança no flash, por exemplo com o partial recebendo o identificador separado da frase, sem `html_safe` sobre dado da fonte, e mais um teste de integração que prove `code` no flash da wishlist.
- **Priority**: Major, bloqueado.

---

## Requirement Traceability Update

| Requirement | Previous Status | New Status |
|---|---|---|
| INT-01 | Mapped | ✅ Verified |
| INT-02 | Mapped | ✅ Verified |
| INT-03 | Mapped | ✅ Verified |
| INT-04 | Mapped | ✅ Verified |
| INT-05 | Mapped | ✅ Verified |
| INT-06 | Mapped | ❌ Needs Fix (teste não discriminante, M2b) |
| INT-07 | Mapped | ✅ Verified |
| INT-08 | Mapped | ❌ Needs Fix / decisão do dono (flash da wishlist) |
| INT-09 | Mapped | ✅ Verified |
| INT-10 | Mapped | ✅ Verified |
| INT-11 | Mapped | ✅ Verified (⚠️ divergência com o Req. 12.11) |
| INT-12 | Mapped | ✅ Verified |

---

## Summary

**Overall**: ❌ Not Ready

**Spec-anchored check**: 10 de 12 requisitos batem com o resultado da spec. Há 2 gaps (INT-06, INT-08) e 3 lacunas de precisão ⚠️ (contagem 23/25, valor de `radius-full`, Req. 12.11 contra INT-11).
**Sensor**: 17/18 mortas; M2b sobrevive.
**Gate**: 948 passed, 0 failed. Rubocop limpo.

**What works**: tokens, contraste, paleta, ausência de sombra e gradiente, guarda de literais na folha inteira, badge de posse (HTML e Stream), anel de foco, `code` nas telas, emoji, chip neutro e 360px.

**Issues found**: Fix 1 (fortalecer o `flash_test` para comparar o estilo efetivo) e Fix 2 (decisão do dono sobre o flash da wishlist).

**Next steps**: executar o Fix 1, levar o Fix 2 ao dono, fechar a T14 (revisão visual e `ecc:a11y-architect`) e verificar de novo.
