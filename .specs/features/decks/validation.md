# Decks — Validation

**Date**: 2026-10-02
**Spec**: `.specs/features/decks/spec.md` (DCK-01..44; `.context/requirements.md` Req. 14.1–14.44)
**Diff range**: `76bc2d7..1935782` (31 commits, de `688d9d6` a `1935782`)
**Verifier**: subagente independente (autor ≠ verificador), evidence-or-zero

## Validation verdict: PASS

**Result**: PASS — 44/44 critérios com evidência `file:line`; sensor 37/37 mutantes mortos; gate full verde (1748 runs, 0 falhas; RuboCop 0 ofensas; Brakeman 0 avisos). Pendência declarada, não falha: T21 (teste manual do dono sobre o LF no OPTCG Simulator e o deck `válido` a 360px).

---

## Task Completion

| Task | Status | Notes |
| ---- | ------ | ----- |
| T1–T20 | ✅ Done | Checkboxes marcados em `tasks.md` |
| T21 | ⏳ Pendente (declarada) | Espera o teste manual do dono: LF no simulador (`⚠️ VERIFICAR` do DCK-31) e montagem até `válido` a 360px. Únicos `- [ ]` abertos em `tasks.md` |
| T22–T25 | ✅ Done | Correções das revisões de banco, segurança e a11y |

---

## Spec-Anchored Acceptance Criteria

Testes citados pela linha do `test "..."`; a asserção vem entre crases.

### P1: Montar

| Critério | Resultado definido no spec | `file:line` + asserção | Result |
| --- | --- | --- | --- |
| DCK-01 criar deck | Deck vazio, sem Leader, do usuário, abre a página | `test/integration/decks_test.rb:42`: `assert_equal [ @user.id, "Luffy Preto", nil, 0 ], [deck.user_id, deck.name, deck.leader_card_id, deck.entries.count]` + `assert_redirected_to deck_path(deck)` | ✅ PASS |
| DCK-02 modelo sobre `cards`, unicidade no banco | `UNIQUE (deck_id, card_id)`, FK para `cards` | `test/models/deck_schema_test.rb:64` (`RecordNotUnique`), `:168`: `assert_equal [["deck_entries","cards","r"],["deck_entries","decks","c"],["decks","cards","r"],["decks","users","r"]], rows`; `:189` índices | ✅ PASS |
| DCK-03 controle − N + na carta não-Leader | Controle com quantidade atual | `test/integration/card_detail_deck_controls_test.rb:38`: `assert_includes controls.text.squish, "0 cópias de Carta Comum no deck"` + forms de increment/decrement; `:55`: `"3 cópias ..."` | ✅ PASS |
| DCK-04 "Usar como Leader" substitui | Ação no Leader; troca sem mexer nas entradas | `card_detail_deck_controls_test.rb:65` (botão `Usar como Leader`, sem `−/+`); `test/integration/deck_leader_test.rb:31`: `assert_equal @second.id, @deck.reload.leader_card_id` + `assert_equal [[@card.id, 3]], entries_of(@deck)` | ✅ PASS |
| DCK-05 uma ação, sem recarregar | Turbo Stream atualiza a quantidade | `test/integration/deck_entries_test.rb:103`: `turbo-stream[action='update'][target='deck_entry_card_N']` com `"3 cópias de Carta Preta no deck"`; `:119`: `assert_equal "morph", stream["method"]`; `:216` sem id duplicado | ✅ PASS (ver nota 1) |
| DCK-06 zero remove | Entrada removida | `deck_entries_test.rb:79`: `assert_not DeckEntry.exists?(deck: @deck, card: @card)`; `:136` Stream com zero | ✅ PASS |
| DCK-07 página agrupada, ordem, "N / 50" | Character/Event/Stage, custo, `card_number`, `N / 50` | `test/integration/deck_page_test.rb:68`: grupos `["Personagens","Eventos","Locais"]` e ordem `[["DT09-029","DT09-021","DT09-022","DT09-030"],…]`; `:115`: `"Deck principal: 50 / 50"`; `:94` Leader | ✅ PASS |
| DCK-08 lista de decks | Nome, Leader, N / 50, status | `decks_test.rb:127`: `["Leader Preto (DT08-001)","50 / 50","válido"]`, `["Sem Leader","3 / 50","incompleto"]`, `[…,"5 / 50","inválido"]` | ✅ PASS |
| DCK-09 excluir com confirmação | GET não apaga; DELETE apaga só o deck; coleção e wishlist intactas | `test/integration/deck_rename_delete_test.rb:76` (`assert_no_changes [Deck.count, DeckEntry.count]`), `:88`, `:100` (`assert_no_changes` em `CollectionItem` e `WishlistItem`) | ✅ PASS |
| DCK-10 renomear | Nome novo, Leader e entradas mantidos | `deck_rename_delete_test.rb:36`: `assert_equal ["Novo nome", @leader.id, [[@card.id, 3]]], snapshot(@deck)` | ✅ PASS |

### P1: Validar

| Critério | Resultado definido no spec | `file:line` + asserção | Result |
| --- | --- | --- | --- |
| DCK-11 status derivado, não persistido | Um de três, calculado na leitura | `test/models/deck/legality_test.rb:207`: `assert_empty Deck.column_names.grep(/status\|valid\|legal/)`; `:212` (`deck.reload.legality`) | ✅ PASS |
| DCK-12 `válido` | Leader, 50, ≤4, cores do Leader | `legality_test.rb:48`: `assert_equal :valid` + `assert_empty result.reasons`; `:134` multicolorida aceita; `:144` isenta com 8 | ✅ PASS |
| DCK-13 `inválido` | >50, >4 não isenta, cor fora | `legality_test.rb:81` (`"O deck tem 51 cartas; o máximo é 50"`), `:89` (`"OP01-016 tem 5 cópias; o máximo é 4"`), `:99` (`"OP02-001 é vermelha e o Leader é preto"`), `:153` | ✅ PASS |
| DCK-14 `incompleto` | Sem Leader ou <50 sem violação | `legality_test.rb:58` (`["Faltam 3 cartas para 50"]`), `:65`, `:73` (`["O deck não tem Leader"]`) | ✅ PASS |
| DCK-15 motivos em português | Textos dos exemplos do spec | Os três exemplos do spec são asseridos literalmente em `legality_test.rb:62,94,104`; na página, `deck_page_test.rb:126` e `:139` (`assert_equal [...], status_section.css("ul li")...`) | ✅ PASS |
| DCK-16 multicolorida | Todas as cores contam | `legality_test.rb:125` (`"OP05-002 é preta e vermelha e o Leader é preto"`), `:134` | ✅ PASS |
| DCK-17 aviso de banidas | "A lista de banidas não é verificada" | `deck_page_test.rb:155`: `assert_select "... p", text: BAN_NOTICE` (deck válido e vazio) | ✅ PASS |
| DCK-18 regra nunca recusa | 5ª cópia gravada, status muda | `deck_entries_test.rb:44`: `assert_equal 5, quantity_in` + `assert_equal :invalid`; `test/integration/deck_imports_test.rb:171` | ✅ PASS |
| DCK-19 fora da fonte | Marcada e contando | `deck_page_test.rb:191`: `assert_equal({"DT09-060"=>true,"DT09-061"=>false}, marks)` + `"Deck principal: 4 / 50"`; `:205` Leader; `test/services/ingestion/guarantees_test.rb:197` | ✅ PASS |
| DCK-43 isenção pelo texto | Frase isenta do 4, não do 50 | `legality_test.rb:144` (8 cópias, `:valid`), `:153` (sem a frase, motivo), `:196` (caixa e espaços); `guarantees_test.rb:216` (frase sobrevive ao Normalize); teto de 50 em `deck_schema_test.rb:85` | ✅ PASS |
| DCK-44 aviso de regra própria | Aviso + texto, status inalterado | `legality_test.rb:163`: `assert_equal :valid` + `assert_equal [rule], result.warnings` (OP12-001, OP13-079, P-117); `:185` (OP15-058 sem aviso); `deck_page_test.rb:166`: `strong` com o aviso + `blockquote` com a regra + `"Status: válido"`; `:179` | ✅ PASS |

### P1: O que falta na pasta (página do deck)

| Critério | Resultado definido no spec | `file:line` + asserção | Result |
| --- | --- | --- | --- |
| DCK-20 possuída = soma das variantes | Presentes ou não | `test/queries/deck_shortfall_query_test.rb:51` (`[4, 3, 1]`), `:74` (variante ausente conta) | ✅ PASS |
| DCK-21 pedida/possuída/falta | `max(0, pedida − possuída)` | `deck_shortfall_query_test.rb:88` (`[4, 7, 0]`); `test/integration/deck_shortfall_page_test.rb:54`: `"pedida 4, possuída 3, falta 1"`; `:66` Leader `"pedida 1, possuída 0, falta 1"` | ✅ PASS |
| DCK-22 total do deck | Total, "Você tem todas…", "Este deck ainda não tem cartas" | `deck_shortfall_page_test.rb:76` (`"Faltam 4 cópias para montar este deck"`), `:86`, `:115`, `:124` | ✅ PASS |
| DCK-23 derivado da coleção atual | Sem sincronização gravada | `deck_shortfall_query_test.rb:191` (`assert_empty writes`; falta 4 → 1); `deck_shortfall_page_test.rb:99` | ✅ PASS |

### P2: Importar e exportar

| Critério | Resultado definido no spec | `file:line` + asserção | Result |
| --- | --- | --- | --- |
| DCK-24 sempre cria deck novo | Nome informado ou o do Leader | `deck_imports_test.rb:63` (`assert_equal "Monkey.D.Luffy", deck.name`), `:82`, `:90` (primeiro deck intacto) | ✅ PASS (ver nota 2) |
| DCK-25 formato e fins de linha | CR/LF/CRLF, brancos, espaços, caixa | `test/models/deck/list_text_test.rb:65`, `:79`, `:95` | ✅ PASS |
| DCK-26 linha Leader vira Leader | — | `list_text_test.rb:65`: `assert_equal card("OP17-079"), result.leader`; `deck_imports_test.rb:63` | ✅ PASS |
| DCK-27 repetidas somam | Uma entrada | `list_text_test.rb:104`: `{"OP17-094" => 4, "OP17-086" => 1}` | ✅ PASS |
| DCK-28 tudo ou nada | Nada criado; linha e motivo listados | `list_text_test.rb:113,121,128,136,145,152,161,171`; `deck_imports_test.rb:106`: `assert_no_difference [Deck.count, DeckEntry.count]` + `["Linha 2: formato inválido…", "Linha 4: OP99-999 não existe no catálogo"]` | ✅ PASS |
| DCK-29 limite de tamanho | Recusa sem processar e informa o limite | `list_text_test.rb:180` e `:189` (`assert_empty queries`), `:197` (fronteira aceita); `deck_imports_test.rb:147`, `:158` | ✅ PASS |
| DCK-30 lista fora das regras é criada | Deck criado com `inválido`/`incompleto` | `deck_imports_test.rb:171`: `"Status: inválido"` | ✅ PASS |
| DCK-31 exportação | `1x<leader>` primeiro, ordem da página, LF | `list_text_test.rb:225` (texto exato + `assert_not_includes text, "\r"`); `test/integration/deck_export_test.rb:28` (`text/plain`, utf-8, corpo exato) | ✅ PASS (ver nota 3) |
| DCK-32 ida e volta | Mesmo Leader e entradas | `list_text_test.rb:246`, `:258`; `deck_imports_test.rb:200` (via HTTP `.txt` → import) | ✅ PASS |

### P2: Pasta

| Critério | Resultado definido no spec | `file:line` + asserção | Result |
| --- | --- | --- | --- |
| DCK-33 maior uso − possuída, Leader = 1 | `MAX`, não soma | `deck_shortfall_query_test.rb:99` (`[4, 1, 3]`), `:64`, `:168` (mesmo Leader em dois decks pede 1) | ✅ PASS |
| DCK-34 bloco com links | Carta, falta e links dos decks | `test/integration/deck_folder_shortfall_test.rb:28`: `"Carta Disputada DT18-010 faltam 3"` + links dos dois decks | ✅ PASS |
| DCK-35 bloco omitido | Sem decks ou nada faltando | `deck_folder_shortfall_test.rb:48`, `:58`: `assert_nil block` + `assert_not_includes response.body, TITLE` | ✅ PASS |

### Edge cases (DCK-36..42)

| Critério | Resultado definido no spec | `file:line` + asserção | Result |
| --- | --- | --- | --- |
| DCK-36 deck alheio = 404 | Ler, alterar, exportar, excluir | `decks_test.rb:160`; `deck_export_test.rb:49`; `deck_rename_delete_test.rb:115,124,134`; `deck_entries_test.rb:166`; `deck_leader_test.rb:92`; `test/integration/deck_editing_test.rb:52`, `:85`; `deck_shortfall_query_test.rb:134,145` | ✅ PASS |
| DCK-37 exige sessão | Redireciona sem aplicar nada | `decks_test.rb:171`, `:180`; `deck_entries_test.rb:201`; `deck_leader_test.rb:102`; `deck_editing_test.rb:62`; `deck_rename_delete_test.rb:146`; `deck_export_test.rb:58`; `deck_imports_test.rb:238` — cobre todas as 14 rotas de `config/routes.rb:125-141` | ✅ PASS |
| DCK-38 incrementos simultâneos | Os dois valem | `test/integration/deck_entries_concurrency_test.rb:133` (`[2]`), `:142` (`[3]`), `:167`, `:180`, com sobreposição forçada por trava | ✅ PASS |
| DCK-39 limites 1..50 e 1..60 | Recusa com mensagem em português | `deck_schema_test.rb:76,85,96,106,116,123,130`; `test/models/deck_test.rb:26`, `:38`; `deck_entries_test.rb:55` (`"O máximo é 50 cópias por carta no deck."`); `deck_entries_concurrency_test.rb:154`; `decks_test.rb:79`, `:114`; `deck_rename_delete_test.rb:54`, `:64` | ✅ PASS |
| DCK-40 ingestão preserva, sem cascata | Leader e entradas intactos | `guarantees_test.rb:182` (duas ingestões), `:197`; `deck_schema_test.rb:137`, `:153`, `:168` | ✅ PASS |
| DCK-41 deck em edição excluído | Controles somem | `card_detail_deck_controls_test.rb:116`: `assert_nil controls_for(@card)`; `deck_editing_test.rb:71` | ✅ PASS |
| DCK-42 sem Leader, sem regra de cor | Sem motivo de cor | `legality_test.rb:116`: `assert_equal ["O deck não tem Leader"], result.reasons` | ✅ PASS |

**Status**: ✅ 44/44 critérios cobertos. ⚠️ Três notas de precisão abaixo; nenhuma reprova.

### Notas de precisão

1. **DCK-05 ("sem recarregar a página inteira")**: sem navegador no container (`CLAUDE.md`), a prova é o formato da resposta: Stream `update`/`morph` sobre o alvo único (`deck_entries_test.rb:103,119,216`). O comportamento no navegador não tem prova automática; a T21 cobre manualmente.
2. **DCK-24, ⚠️ spec-precision gap**: o spec não diz o que acontece numa importação sem nome e sem Leader. A implementação recusa com 422 e pede um nome (`app/controllers/deck_imports_controller.rb:31` + validação do nome). O teste fixa essa escolha (`deck_imports_test.rb:186`) e registra o gap no comentário da linha 184. O comportamento é razoável, mas falta o critério no spec e no Req. 14.24.
3. **DCK-31, ⚠️ VERIFICAR declarado**: o LF está provado (`list_text_test.rb:225`, `deck_export_test.rb:28`). Ainda falta saber se o OPTCG Simulator aceita LF; isso fica com a T21, como o spec já registra.

**Success Criteria sem prova automática (fora dos ACs):** "o exemplo do dono importa num deck `válido`". `deck_imports_test.rb:63` confere o Leader, os 50 e as entradas, mas não asserta o status. A dedução é que ele daria `válido`: todas pretas, Leader preto, nenhuma carta acima de 4 e `legality_test.rb:48` cobre a regra. O "`válido` a 360px" é manual (T21).

---

## Discrimination Sensor

**Isolamento**: cópia `tar` da árvore real (sem `storage/`, `tmp/`, `log/`) em `/tmp/claude-1000/bindr/verifier-scratch/repo`. Os testes rodaram em container descartável da mesma imagem, com o volume `bundle` montado `:ro`, e o scratch montado em `/rails`. O banco de teste foi `bindr_verifier_test` (com sufixos `-N` dos workers paralelos), via `POSTGRES_TEST_DB`. O banco `bindr_test` não foi tocado. Cada mutação aplicou uma troca exata e única, rodou os 20 arquivos de teste da feature (213 runs) e restaurou o arquivo copiando-o de volta da árvore real. No fim, `diff -rq` entre a árvore real e o scratch saiu vazio.

`git status --porcelain` da árvore real: antes `?? .playwright-mcp/`, depois `?? .playwright-mcp/`. Saída idêntica.

| # | Arquivo | Mutação | Morto por | Killed? |
| --- | --- | --- | --- | --- |
| M01a | `app/queries/deck_shortfall_query.rb:76` | Ramo das entradas sem `decks.user_id = :user_id` | `deck_shortfall_query_test.rb:138` | ✅ |
| M01b | `app/queries/deck_shortfall_query.rb:80` | Ramo do Leader sem `decks.user_id = :user_id` | `deck_shortfall_query_test.rb:149` | ✅ |
| M02 | `app/queries/deck_shortfall_query.rb:70` | `MAX` → `SUM` | `deck_shortfall_query_test.rb:106,174`; `deck_folder_shortfall_test.rb` | ✅ |
| M03 | `app/models/deck/legality.rb:75` | Sem a isenção `unlimited_copies?` | `legality_test.rb:149`; `guarantees_test.rb:206` | ✅ |
| M04 | `app/models/deck/legality.rb:87` | "Basta uma cor em comum" (`colors & leader.colors`) | `legality_test.rb:129` | ✅ |
| M05 | `app/models/deck/legality.rb:75` | `quantity <= 4` → `< 4` (4 cópias viram motivo) | 18 falhas (`legality_test.rb:61`, `deck_page_test.rb:122`, …) | ✅ |
| M06 | `app/controllers/deck_entries_controller.rb:53` | Sem `WHERE quantity < 50` no `DO UPDATE` | `deck_entries_test.rb:55`; `deck_entries_concurrency_test.rb:154` | ✅ |
| M07a | `app/controllers/decks_controller.rb:54` | `show`: `Deck.find` em vez de `Current.user.decks` | `decks_test.rb:166`; `deck_export_test.rb:55` | ✅ |
| M07b | `app/controllers/decks_controller.rb:99` | `destroy` sem escopo | `deck_rename_delete_test.rb:137` | ✅ |
| M07c | `app/controllers/deck_entries_controller.rb:117` | `set_deck` sem escopo | `deck_entries_test.rb:172`; `deck_leader_test.rb:98` | ✅ |
| M07d | `app/controllers/decks_controller.rb:85` | `select` sem escopo | `deck_editing_test.rb:58` | ✅ |
| M07e | `app/controllers/decks_controller.rb:73` | `update` sem escopo | `deck_rename_delete_test.rb:120` | ✅ |
| M07f | `app/controllers/decks_controller.rb:68` | `edit` sem escopo | `deck_rename_delete_test.rb:128` | ✅ |
| M07g | `app/controllers/decks_controller.rb:93` | `delete` (confirmação) sem escopo | `deck_rename_delete_test.rb:131` | ✅ |
| M07h | `app/controllers/concerns/editing_deck.rb:37` | Deck em edição por `Deck.find_by` | `deck_editing_test.rb:94` | ✅ |
| M08 | `app/models/deck/list_text.rb:128` | Separador `"\n"` → `"\r\n"` | `list_text_test.rb:228,241,266`; `deck_export_test.rb:37` | ✅ |
| M09 | `app/models/deck/list_text.rb:51` | Linhas repetidas não somam (vale a última) | `list_text_test.rb:108` | ✅ |
| M10 | `app/models/deck/list_text.rb:48` | `parse` devolve o que deu certo apesar dos erros | 8 falhas (`deck_imports_test.rb:109`, `list_text_test.rb:131,141,148,155,174`) | ✅ |
| M10b | `app/controllers/deck_imports_controller.rb:27` | Controller ignora `errors` do `parse` | 5 falhas (`deck_imports_test.rb:114,130,137,155,166`) | ✅ |
| M11 | `app/controllers/decks_controller.rb:122` | Toda carta marcada "fora da fonte" | `deck_page_test.rb:201` | ✅ |
| M12 | `app/views/decks/show.html.erb:41` | Sem o aviso de banidas | `deck_page_test.rb:162` | ✅ |
| M13 | `app/queries/deck_shortfall_query.rb:88` | Possuída só da variante base | `deck_shortfall_query_test.rb:58`; `deck_shortfall_page_test.rb:62,110` | ✅ |
| M14 | `app/queries/deck_shortfall_query.rb:95` | Sem `GREATEST(0, …)` (falta negativa) | `deck_shortfall_query_test.rb:94` | ✅ |
| M15 | `app/models/deck/legality.rb:67` | 51 cartas aceitas | `legality_test.rb:84,111` | ✅ |
| M16 | `app/controllers/deck_entries_controller.rb:85` | Decremento em 1 não apaga | `deck_entries_test.rb:87,143`; `deck_entries_concurrency_test.rb:174` | ✅ |
| M17 | `app/models/card.rb:54` | Sem `"can only include"` | `legality_test.rb:179` (P-117) | ✅ |
| M18 | `app/models/deck/legality.rb:43` | `incompleto` vence `inválido` | 7 falhas (`legality_test.rb:111`, `deck_imports_test.rb:181`, …) | ✅ |
| M19 | `app/models/deck/list_text.rb:61` | 200 linhas recusadas (`>=`) | `list_text_test.rb:198` | ✅ |
| M20 | `app/models/deck/list_text.rb:50` | Leader importado descartado | 10 falhas (`deck_imports_test.rb:66`, `list_text_test.rb:88,99`, …) | ✅ |
| M21 | `app/controllers/progress_controller.rb:48` | Bloco da pasta mostra linhas com falta 0 | `deck_folder_shortfall_test.rb:67` | ✅ |
| M22 | `app/views/decks/show.html.erb:53` | Deck só com Leader diz "ainda não tem cartas" | `deck_shortfall_page_test.rb:131` | ✅ |
| M23 | `app/controllers/deck_entries_controller.rb:43` | Leader aceito em `increment` | `deck_entries_test.rb:69` | ✅ |
| M24 | `app/models/deck.rb:50` | `main_total` conta o Leader | 5 falhas (`deck_test.rb:94`, `deck_page_test.rb:121`, …) | ✅ |
| M25 | `app/models/deck.rb:44` | Custo nulo primeiro | `deck_test.rb:82`; `deck_page_test.rb:86`; `list_text_test.rb:266` | ✅ |
| M26 | `app/controllers/deck_imports_controller.rb:31` | Nome padrão fixo em vez do nome do Leader | `deck_imports_test.rb:73,189` | ✅ |
| M27 | `app/controllers/deck_entries_controller.rb:52` | Lost update: quantidade lida em Ruby antes do `INSERT` | `deck_entries_concurrency_test.rb:139,149` | ✅ |
| M28 | `db/structure.sql:918` | FK do Leader `ON DELETE SET NULL` | `deck_schema_test.rb:144,177` | ✅ |
| M29 | `db/structure.sql:234` | CHECK de quantidade até 99 | `deck_schema_test.rb:88,100` | ✅ |
| M30 | `app/controllers/decks_controller.rb:93` | `GET delete` apaga o deck | `deck_rename_delete_test.rb:79` | ✅ |

Nas mutações M28 e M29 o `structure.sql` foi trocado. O `maintain_test_schema` recarregou o banco do scratch nas duas direções: depois da restauração, `deck_schema_test.rb` rodou com 13 runs e 0 falhas.

**Sensor depth**: P0-full manual. A feature tem isolamento por usuário, integridade de dados e concorrência, e cobre todas as 12 mutações pedidas mais 25 extras.
**Result**: 37/37 mortos, 0 sobreviventes — PASS

---

## Code Quality

| Principle | Status |
| --- | --- |
| Minimum code | ✅ Quatro peças do design (`Deck::Legality`, `DeckShortfallQuery`, `Deck::ListText`, deck em edição na sessão), sem abstração extra |
| Surgical changes | ✅ Fora da feature, só `collection_items_controller.rb` (bind `BigInteger`, achado DB-L6 aplicado à posse; de mesma classe) e o teste protegido de consultas da pasta (AD-021) |
| No scope creep | ✅ Nada de banidas, variante no deck ou preço |
| Matches patterns | ✅ SQL atômico com bind params e resposta dupla, como `CollectionItemsController`; query object como `SetProgressQuery`; SQL nomeado (`-- listDeckShortfall`, `-- incrementDeckEntry`) |
| Spec-anchored outcome check | ✅ Os textos dos exemplos do DCK-15 e as frases do DCK-17, DCK-22 e DCK-44 são asseridos literalmente |
| Per-layer coverage | ✅ Domínio puro 1:1 (`legality_test`, `list_text_test`, `deck_shortfall_query_test`); rotas com caminho feliz, erro, 404 e falta de sessão |
| Every test maps to a requirement | ✅ Os testes citam DCK, Done-when ou achado de revisão (T22–T25) |
| Documented guidelines followed | ✅ `CLAUDE.md` (sessão por padrão, `Current.user` no escopo, sem cascata a partir de `cards`, sem system test) |

---

## Edge Cases

- [x] Deck de outro usuário → 404 (DCK-36)
- [x] Sem sessão → login, nada aplicado (DCK-37)
- [x] Incrementos simultâneos, ambos aplicados (DCK-38), com sobreposição forçada
- [x] Incremento acima de 50 recusado, quantidade mantida (DCK-39)
- [x] Nome vazio ou com mais de 60 caracteres (DCK-39)
- [x] Ingestão com decks existentes (DCK-40)
- [x] Deck em edição excluído (DCK-41)
- [x] Sem Leader, sem regra de cor (DCK-42)

---

## Gate Check

- **Gate command** (full, `tasks.md`): `docker compose exec -T app bin/rails test && docker compose exec -T app bin/rubocop && docker compose exec -T app bin/brakeman --no-pager`, na árvore real, com `DOCKER_CONFIG=/tmp/claude-1000/bindr-dockercfg`
- **Result**: 1748 runs, 7260 assertions, 0 failures, 0 errors, 0 skips; RuboCop: 211 arquivos, nenhuma ofensa; Brakeman: 0 avisos. A primeira rodada passou, sem o flake de `ingestion_*_task_test`.
- **Test count before feature**: 1549 (último gate full registrado no *Handoff* de 2026-10-01)
- **Test count after feature**: 1748
- **Delta**: +199
- **Skipped tests**: nenhum
- **Failures**: nenhuma

---

## Fix Plans

Nenhum bloqueante. Melhorias recomendadas (Minor):

### Fix 1: Fechar o spec-precision gap do DCK-24

- **Root cause**: o spec e o Req. 14.24 não dizem o que acontece numa importação sem nome e sem Leader.
- **Fix task**: emendar o DCK-24 e o Req. 14.24 com "sem nome e sem Leader, a importação é recusada com 422 pedindo um nome, sem criar deck", que é o comportamento atual (`deck_imports_test.rb:186`).
- **Priority**: Minor

### Fix 2: Assertar o status `válido` do exemplo do dono

- **Root cause**: o Success Criterion "o exemplo do dono importa num deck `válido`" não tem asserção.
- **Fix task**: em `deck_imports_test.rb:63`, depois do `follow_redirect!`, `assert_select "h2#deck-status-title", text: "Status: válido"`.
- **Priority**: Minor

---

## Requirement Traceability Update

| Requirement | Previous Status | New Status |
| --- | --- | --- |
| DCK-01..30, DCK-32..44 | Implemented | ✅ Verified |
| DCK-31 | Implemented | ✅ Verified (formato e LF); aceitação do LF pelo simulador pendente na T21 |

---

## Summary

**Overall**: ✅ Ready. A §9.3 do `.context/tasks.md` fecha com a T21 manual.

**Spec-anchored check**: 44/44 critérios com evidência; 1 spec-precision gap (DCK-24) e 2 notas (DCK-05 sem navegador; DCK-31 com `⚠️ VERIFICAR` declarado)
**Sensor**: 37/37 mortos
**Gate**: 1748 passed, 0 failed

**What works**: regras de montagem com isenção e aviso pelo texto do catálogo; isolamento por usuário em todas as rotas e na query; atomicidade e teto de 50 sob corrida; importação tudo ou nada com ida e volta; falta por deck e agregada pelo maior uso; ingestão sem tocar decks.

**Issues found**: Fix 1 e Fix 2 (Minor), nenhum bloqueante.

**Next steps**: o dono roda a T21; o orquestrador decide se aplica os Fix 1 e 2 antes do commit da validação.

## Correção das lacunas pelo orquestrador (2026-10-02)

- **Lacuna 1 (DCK-24)**: fechada por emenda do spec e do Req. 14.24, que registram o comportamento já testado: sem nome e sem Leader, a importação é recusada e pede um nome (`test/integration/deck_imports_test.rb:186`).
- **Lacuna 2 (Success Criterion "válido")**: fechada. O teste do exemplo do dono passa a afirmar `Status: válido` depois do redirect (`test/integration/deck_imports_test.rb`, teste "o exemplo do dono importa num deck com Leader OP17-079 e 50 cartas").
- Lacunas 3 e 4 (DCK-05 sem navegador, LF no OPTCG Simulator) continuam com o teste manual do dono na T21.
