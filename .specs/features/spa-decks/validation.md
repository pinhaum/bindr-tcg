# spa-decks Validation

**Date**: 2026-10-11
**Spec**: `.specs/features/spa-decks/spec.md` (SDEC-01..61)
**Diff range**: `1238386..HEAD` (31 commits, 84 arquivos)
**Verifier**: independent sub-agent (author ≠ verifier); só leitura no repo, sensor numa cópia fora dele

## Validation: PASS ✅

**Result**: PASS — 61/61 SDEC com evidência `file:line`; 0 falhas nos gates; sensor 5/5 mutantes mortos; 4 lacunas menores (nenhuma bloqueante).

---

## Gate Check

- **Front** (`tmp/gate-front.sh`): svelte-check 0 erros/0 avisos, eslint limpo, **Vitest 74 arquivos, 982 testes passam**.
- **Rails** (`docker compose exec -T app bin/rails test`): **2069 runs, 8544 assertions, 0 failures, 0 errors, 0 skips**.
- **Rubocop**: 284 arquivos, nenhuma ofensa.
- **E2E** (`TAILN=8 tmp/gate-e2e.sh`, contra a API real): **204 passed** (5,6 min).
- Contagem de testes (grep de `test "` / `it(`): base 1958 Rails / 638 Vitest → HEAD 2032 / 732; **nenhum teste removido** (diff de `test/` só com `A`, exceto o `M` abaixo).
- Isolamento: `git status --porcelain` idêntico ao baseline (limpo) após o sensor.

### SDEC-61 — teste Rails existente editado

`git diff --name-status 1238386 -- test/`: só `A`, mais **um** `M`: `test/integration/api/cards_test.rb:49` (`card.except("variants", "featured_variant_code")` → `…, "editing_deck")`). Avaliação: **aceitável**. É emenda aditiva ao contrato `GET /api/cards/:card_number` exigida pelo próprio SDEC-50 (campo novo `editing_deck`); nenhuma asserção foi enfraquecida (o campo novo é testado à parte em `test/integration/api/cards_editing_deck_test.rb:33-69`), e a decisão está registrada em `tmp/orchestration-decisions.md` (T10) e no spec (SDEC-50: "emenda aditiva do API-23"). A cláusula "a suíte existente passa sem edição" fica tecnicamente violada em uma linha, mas o que o SDEC-61 protege (HTML e rotas) segue intacto: `config/routes.rb` só ganha linhas sob `/api`, nenhum arquivo em `app/views/` fora de `api/` mudou. Recomenda-se o dono confirmar (L3).

Nota: `decks_controller.rb` e `deck_entries_controller.rb` (HTML) **foram modificados** (extração para `DeckDetail` e `DeckEntry.increment_for!/decrement_for!`, SQL e mensagens idênticos). O "manter inalterados os controllers" é lido como "sem mudança de comportamento"; a suíte HTML inteira passa e T1/T2 previam a extração.

---

## Spec-Anchored Acceptance Criteria

Caminhos curtos: `B/` = `frontend/src/routes/baralhos/`, `C/` = `frontend/src/lib/components/`, `R/` = `test/integration/api/`.

| SDEC | Resultado esperado (spec) | `file:line` + asserção | Result |
|---|---|---|---|
| 01 | título "Baralhos — Bindr", h1 | `B/page.test.ts:103` título e h1; e2e `frontend/e2e/baralhos.spec.ts:314` | ✅ |
| 02 | entrada do casco → `/app/baralhos`, `aria-current` com query | `frontend/src/lib/navigation/nav-entries.test.ts:47` (`href: "/app/baralhos"`); `C/MainNav.test.ts:95` (`it.each(["/app/baralhos","/app/baralhos?x=1"])`) e `:108` (não marca em `/baralhos/7`) | ✅ |
| 03 | anônimo → `/app/entrar?return_to=…` sem chamar a API | `B/page.test.ts:74`, `B/novo/page.test.ts:32`, `B/[id]/page.test.ts:88`, `B/[id]/renomear/page.test.ts:31`, `B/[id]/excluir/page.test.ts:31`, `B/importar/page.test.ts:35` | ✅ |
| 04 | >200 ms `aria-busy` + "Carregando baralhos…/deck…"; antes mantém | `B/page.test.ts:152`; `B/[id]/page.test.ts:134` | ✅ |
| 05 | resposta de URL antiga descartada | `B/page.test.ts:173`; `B/[id]/page.test.ts:148` | ✅ |
| 06 | erro ≠404: `message` + "Tentar novamente" repete | `B/page.test.ts:193`; `B/[id]/page.test.ts:126` | ✅ |
| 07 | cada deck: h2, link, Leader/"Sem Leader", "N / 50", status | `B/page.test.ts:112`; rótulos `frontend/src/lib/decks/labels.test.ts:10-14` (`['válido','incompleto','inválido']`) | ✅ |
| 08 | "Você ainda não tem decks." | `B/page.test.ts:132` | ✅ |
| 09 | links "Novo deck"/"Importar lista" | `B/page.test.ts:140` | ✅ |
| 10 | título/h1, campo "Nome do deck (até 60 caracteres)", `maxlength=60`, preenchido ao renomear | `C/DeckNameForm.test.ts:13-18` (`toBeRequired`, `maxlength '60'`, valor inicial); `B/novo/page.test.ts:56`; `B/[id]/renomear/page.test.ts:56` | ✅ |
| 11 | criar → `/app/baralhos/<id>` + "Deck criado." | `B/novo/page.test.ts:64` | ✅ |
| 12 | renomear → página + "Deck renomeado." | `B/[id]/renomear/page.test.ts:73` | ✅ |
| 13 | `fields.name`: `aria-describedby`, `aria-invalid`, foco, valor mantido | `C/DeckNameForm.test.ts:21-34` (`aria-invalid 'true'`, `aria-describedby 'field-name-errors'`, `toHaveFocus`, `toHaveValue('Luffy')`) | ✅ |
| 14 | envio pendente: botão desabilitado, 2º envio ignorado | `C/DeckNameForm.test.ts:45-53` (`toBeDisabled`, `toHaveBeenCalledTimes(1)`) | ✅ |
| 15 | confirmação de exclusão sem apagar ao abrir | `B/[id]/excluir/page.test.ts:57` | ✅ |
| 16 | excluir → lista + "Deck “<nome>” excluído." | `B/[id]/excluir/page.test.ts:73` | ✅ |
| 17 | título "<nome> — Bindr" + h1 | `B/[id]/page.test.ts:111` | ✅ |
| 18 | 404 → "Deck não encontrado — Bindr", message, "Voltar aos baralhos" | `C/DeckNotFound.test.ts:11,16,21`; `B/[id]/page.test.ts:118`, `renomear/page.test.ts:65`, `excluir/page.test.ts:98` | ✅ |
| 19 | `editing:true` → "Em edição", senão botão | `B/[id]/page.test.ts:164-169` (`queryByRole(button 'Editar este deck')` ausente) | ✅ |
| 20 | select → "Em edição" + "Agora as cartas vão para o deck “Red Zoro”." | `B/[id]/page.test.ts:171-178` (`post('/api/decks/7/select', {})`, texto do status) | ✅ |
| 21 | "Status: <rótulo>" + `reasons` quando ≠valid | `B/[id]/page.test.ts:188`, `:195` (válido não lista) | ✅ |
| 22 | aviso + `<blockquote>` | `B/[id]/page.test.ts:203-208` | ✅ |
| 23 | "A lista de banidas não é verificada" sempre | `B/[id]/page.test.ts:188-200` | ✅ |
| 24 | quatro frases de "Na sua pasta" | `B/[id]/page.test.ts:210-220` (`it.each` das 4); `labels.test.ts:42-46` | ✅ |
| 25 | Leader link / "Sem Leader" | `B/[id]/page.test.ts:222-229` (`href '/app/cartas/OP01-001'`) | ✅ |
| 26 | "Deck principal: N / 50", h3 por tipo, "N×", link, "custo N" | `B/[id]/page.test.ts:231-242` (h3 `['Personagens','Eventos']`, `'4×'`, `'custo 2'`, Event sem "custo"); tipo desconhecido `labels.test.ts:21-24` (`'Don'`) | ✅ |
| 27 | "carta fora da fonte" | `B/[id]/page.test.ts:244-248` (`toHaveLength(1)`, só a entrada) | ⚠️ L1 |
| 28 | "pedida N, possuída N, falta N" | `B/[id]/page.test.ts:238,242` (entradas) | ⚠️ L1 |
| 29 | "Exportar lista" `/decks/<id>.txt` full-page; Renomear/Excluir/Voltar | `B/[id]/page.test.ts:250-259` (`href '/decks/7.txt'`, `data-sveltekit-reload`) | ✅ |
| 30 | formulário de importação com textos e atributos exatos | `B/importar/page.test.ts:64` | ✅ |
| 31 | importar → página + "Deck importado." | `B/importar/page.test.ts:82` | ✅ |
| 32 | recusa: resumo `role=alert` com foco, 3 linhas na ordem, `aria-*` na lista, `fields.name` | `B/importar/page.test.ts:95`, `:119` | ✅ |
| 33 | seção "Deck em edição" + link | `C/EditingDeckPanel.test.ts:38-43`; `frontend/src/routes/cartas/[card_number]/editing-deck.test.ts:79` | ✅ |
| 34 | sem sessão / `null` → sem seção | `editing-deck.test.ts:88`, `:97` | ✅ |
| 35 | "N cópia(s) de <nome> no deck", `aria-live=polite`, alvos 44px, nomes acessíveis | `C/EditingDeckPanel.test.ts:45-61` (0/1/2; `[aria-live="polite"]`; lê `min-block-size: var(--touch-target)` do CSS) | ✅ |
| 36 | stepper otimista: série, falha volta ao confirmado | `C/EditingDeckPanel.test.ts:63` (3 POSTs em série ao deck do payload), `:81` (422 do teto volta); `C/QuantityStepper.test.ts:65` (1..5), `:84` (falha no 3º); `editing-deck.test.ts:105` (trocar de carta) | ✅ |
| 37 | `−` em zero: `aria-disabled`, focável, sem envio, anuncia | `C/EditingDeckPanel.test.ts:89`; `C/QuantityStepper.test.ts:51` | ✅ |
| 38 | "Usar como Leader" / "é o Leader deste deck" `aria-disabled` | `C/EditingDeckPanel.test.ts:100,114,122` | ✅ |
| 39 | Leader aceito → troca botão + "<card_number> é o Leader do deck “…”." | `C/EditingDeckPanel.test.ts:100` | ✅ |
| 40 | bloco "Faltando para os baralhos" antes dos links, "falta 1/faltam N", decks com links | `C/DeckShortfall.test.ts:35`; `frontend/src/routes/pasta/shortfall.test.ts:79`; e2e `frontend/e2e/baralhos-montagem.spec.ts:223` | ✅ |
| 41 | sem cartas → bloco e cabeçalho omitidos | `C/DeckShortfall.test.ts:26`; `pasta/shortfall.test.ts:88` | ✅ |
| 42 | falha do bloco: message + "Tentar novamente", pasta intacta | `C/DeckShortfall.test.ts:61`; `pasta/shortfall.test.ts:96` | ✅ |
| 43 | `GET /api/decks` ordenado, campos, só do usuário | `R/decks_test.rb:54`, `:71` (status = HTML), `:84` (consultas fixas 1×3 decks), `:47` (401) | ✅ |
| 44 | `POST /api/decks` 201, vazio, em edição | `R/decks_write_test.rb:34` | ✅ |
| 45 | `PATCH` muda só o nome | `R/decks_write_test.rb:53` | ✅ |
| 46 | nome vazio/61 chars → 422 `fields.name`; import só sem Leader | `R/decks_write_test.rb:68,86`; `R/deck_imports_test.rb:61,68` | ✅ |
| 47 | `GET /api/decks/:id` com todos os campos e retrato único | `R/decks_test.rb:96,116,148,162,174`; `test/queries/deck_detail_test.rb:28,39,44` | ✅ |
| 48 | `DELETE` apaga deck e entradas, mantém coleção/wishlist | `R/decks_destroy_select_test.rb:33` | ✅ |
| 49 | `select` grava `session[:editing_deck_id]`, idempotente | `R/decks_destroy_select_test.rb:57` | ✅ |
| 50 | `editing_deck` com/sem sessão, quantity 0, `is_leader`, após excluir | `R/cards_editing_deck_test.rb:33,39,43,51,57,63,69` | ✅ |
| 51 | increment cria com 1 e soma | `R/deck_entries_test.rb:48`; `test/models/deck_entry_atomic_test.rb:18,23` | ✅ |
| 52 | decrement: apaga em 1; sem entrada 200 `quantity:0` sem gravar | `R/deck_entries_test.rb:77`; `deck_entry_atomic_test.rb:43,50,58` | ✅ |
| 53 | 50 → 422 com a frase, sem gravar | `R/deck_entries_test.rb:58`; `deck_entry_atomic_test.rb:36` | ✅ |
| 54 | Leader no increment → 422 com a frase | `R/deck_entries_test.rb:69` | ✅ |
| 55 | `PUT leader` grava/substitui; não-Leader 422 | `R/deck_entries_test.rb:94,110,118` | ✅ |
| 56 | concorrência sem perda, ≤50, ≥1 | `R/deck_entries_concurrency_test.rb:135,145,158,175,188,201` (`use_transactional_tests = false`) | ✅ |
| 57 | import aceito → 201, em edição, mesmo Leader/entradas | `R/deck_imports_test.rb:40` | ✅ |
| 58 | recusa: message + `fields.list` na ordem, sem deck | `R/deck_imports_test.rb:78,93,105` | ✅ |
| 59 | `shortfall`: só `missing>0`, ordenado, decks por id, consultas fixas | `R/decks_shortfall_test.rb:48,69,80,92,104` | ✅ |
| 60 | 401 / 422 CSRF / 404 (deck alheio, carta inexistente), `user_id` ignorado | `R/deck_entries_test.rb:143,153,170,183`; `R/decks_write_test.rb:103,122,140`; `R/decks_destroy_select_test.rb:70,81,98`; `R/deck_imports_test.rb:118,128,137`; `R/decks_shortfall_test.rb:41,80` | ✅ |
| 61 | HTML/rotas inalterados, suíte existente passa | Suíte Rails inteira verde; diff de `config/routes.rb` só aditivo sob `/api`; `app/views` fora de `api/` intocado; ver nota acima | ✅ (ressalva L3) |

**Status**: ✅ todos cobertos; ⚠️ SDEC-27/28 com asserção só nas entradas (L1).

### Edge Cases

- [x] `card_number` reservado codificado: `frontend/src/lib/decks/url.test.ts` ("codifica espaço e ponto", morta pelo mutante 5) e `R/deck_entries_test.rb:128`.
- [x] Deck trocado noutra aba (P12): cada operação leva o `id` do payload (`C/EditingDeckPanel.test.ts:63`, morta pelo mutante 3).
- [x] Trocar de carta com envio pendente: `editing-deck.test.ts:105`.
- [x] JSON malformado → 400: `R/decks_write_test.rb:133`.
- [x] Lista >200 linhas / >10.000 caracteres: `R/deck_imports_test.rb:93`.
- [x] Partes da pasta chegam em qualquer ordem: `pasta/shortfall.test.ts:64`.
- [x] Deck de outro usuário 404 nas leituras e mutações: `R/decks_test.rb:186`, `R/deck_entries_test.rb:153`.
- [~] Logout com detalhe aberto repete a consulta (SCAR-09): sem teste novo; herdado da `spa-carta` (L2).

---

## Discrimination Sensor

Cópia fora do repo (`scratchpad/m/frontend`, sem `node_modules`), Vitest em contêiner descartável `node:24.21.0-slim` (`npm ci && npx vitest run`). Árvore real intacta (`git status` = baseline).

| # | Arquivo:linha | Mutação | Killed? |
|---|---|---|---|
| 1 | `frontend/src/lib/decks/labels.ts:35` | `missing_total === 1` → `=== 2` | ✅ Killed (`labels.test.ts` "dá a frase de cada caso"; `page.test.ts` "Na sua pasta" 2) |
| 2 | `frontend/src/lib/components/DeckShortfall.svelte:30` | `cards.length > 0` → `>= 0` (bloco com lista vazia) | ✅ Killed (`DeckShortfall.test.ts` SDEC-41; `pasta/shortfall.test.ts` SDEC-41) |
| 3 | `frontend/src/lib/components/EditingDeckPanel.svelte:32` | `deck.id` → `deck.id + 1` (operação vai a outro deck) | ✅ Killed (`EditingDeckPanel.test.ts` "três + enviam três POST… ao deck do payload") |
| 4 | `frontend/src/routes/baralhos/[id]/+page.svelte:68` | "pedida" → "pedido" | ✅ Killed (`page.test.ts` SDEC-26/28) |
| 5 | `frontend/src/lib/decks/url.ts:13` | removido `encodeURIComponent(cardNumber)` | ✅ Killed (`url.test.ts` "codifica espaço e ponto") |

**Sensor depth**: lightweight, só front. **Result**: 5/5 killed — PASS ✅

**Limitação registrada**: mutações do lado Rails (`DeckEntry.increment_for!`, `Api::DecksController`, `DeckDetail`) **não foram rodadas**: exigiriam contêiner Rails + Postgres, e os únicos disponíveis são os desta worktree (ordem: não tocá-los). A discriminação do lado Rails fica sustentada só pela leitura das asserções (status, mensagem e quantidade exatos; teste de corrida com `use_transactional_tests = false`) e pelo e2e contra a API real. Recomendo uma rodada de mutação Rails (teto `< 50`, `quantity > 1`, `Current.user.decks`) num ambiente descartável.

---

## Code Quality

| Princípio | Status |
|---|---|
| Sem features além do pedido | ✅ |
| Sem abstração de uso único | ✅ (`QuantityStepper` generalizado tem dois usos: posse e deck) |
| Só arquivos necessários | ✅ (testes existentes tocados: `OwnershipStepper.test.ts`, `nav-entries.test.ts`, `MainNav.test.ts`, `pasta/page.test.ts` registrados em `tmp/orchestration-decisions.md`; `ownership-queue.svelte.test.ts` e `CardHeader.test.ts` não, ver L2) |
| Segue padrões existentes | ✅ (`api.get` desempacotado, `createLoader`, envelope de erro, `Current.user.decks`) |
| Testes mapeiam ACs, sem teste sem dono | ✅ (nomes citam SDEC-NN) |
| Cobertura por camada (domínio 1:1; rotas feliz+borda+erro) | ✅ |
| Diretrizes documentadas | CLAUDE.md do projeto (gates, SDEC-61, sem `git stash`) |

---

## Fix Plans / Lacunas ranqueadas (nenhuma bloqueia o PASS)

1. **L1 (Minor)** — SDEC-27 e SDEC-28 valem também para o **Leader**, mas os testes de página só afirmam "carta fora da fonte" (`frontend/src/routes/baralhos/[id]/page.test.ts:244`, `toHaveLength(1)`, só a entrada) e "pedida/possuída/falta" nas entradas (`:238,242`). O Leader usa o mesmo trecho de `+page.svelte:68` (o mutante 4 foi morto), mas uma regressão só no bloco do Leader passaria. Sugestão: asserir os dois no Leader.
2. **L2 (Minor, processo)** — `ownership-queue.svelte.test.ts` e `CardHeader.test.ts` (Vitest) foram editados e não constam de `tmp/orchestration-decisions.md`. Não afeta o SDEC-61 (Rails); registrar a justificativa. Também falta teste novo para "sair com o detalhe aberto oculta a seção" (edge case, herdado do SCAR-09).
3. **L3 (Minor, decisão do dono)** — a emenda de uma linha em `test/integration/api/cards_test.rb:49` e a extração interna dos controllers HTML contrariam a letra do SDEC-61 ("inalterados"/"sem edição"), não o efeito. Confirmar e, se preferir, ajustar a redação para "comportamento inalterado".
4. **L4 (Informativa)** — sensor de mutação Rails não executado (limitação de ambiente, acima).

## Requirement Traceability Update

| Requirement | Previous Status | New Status |
|---|---|---|
| SDEC-01..61 | Implemented | ✅ Verified (SDEC-27/28 e 61 com ressalvas L1/L3) |
