# Import e export CSV — Validação

**Date**: 2026-09-20
**Spec**: `.specs/features/portabilidade/spec.md`; fonte de verdade
`.context/requirements.md` **Req. 10** e `.context/tasks.md` **§5.2 e §5.3**
(AD-005)
**Feature governada por**: **AD-006** (import substitui, não soma), **AD-007**
(staging em tabela), **AD-008** (teto de 10.000 linhas), **AD-009** (asserção
sobre relógio e sobre plano GIN), **AD-010** (deadlocks pré-existentes em
`test/queries`, medição em série)
**Diff range**: `cb92c65..17b3a5b` — 22 commits (20 verificados pelo Verifier em
`cb92c65..b73366b`, mais 2 de fechamento de lacuna commitados depois dele). `8062fa3` (T1), `4efc35c` (T2),
`75d9def` (T3), `54aa67b` (T4), `ecc78f2` (T5), `3021095` (T6), `fa8cc33` (T7),
`9b6629a` (T8), `76a8f75` + `2ad5416` (T9), `368a479` (T10), `70d54db` +
`b47a984` (T11), `d1bf310` (T12), `12f65c9` (T13), `0ada31e` + `ecc2e5d` (T14),
`637ed5e` (T15), `8dded76` (T16), `efb6817` (correção de cobertura pós-T16, não
é task do plano), `b73366b` (T17), `786a2d5` (revisão de isolamento, fecha a T16
e a lacuna L2), `17b3a5b` (fecha a lacuna L1)
**Verifier**: subagente independente (autor ≠ verificador)
**Result**: PASS
**Veredito**: ✅ **PASS**, com **1 lacuna HIGH** (não bloqueante — defeito de
*teste*, não de produção), 2 MEDIUM e 3 LOW. **Nenhuma escrita indevida na
coleção foi conseguida em 19 tentativas de ataque.**

**Nota do orquestrador, posterior a este relatório:** a lacuna **L1** foi
reproduzida de forma independente e **fechada** em `17b3a5b`; a **L2**, em
`786a2d5`. As duas trazem nota de fechamento na seção "Lacunas e achados".
Restam abertas L3 (dívida decidida pelo dono do produto), L4, L5 e L6, todas
LOW/MEDIUM e nenhuma bloqueante. Estado final: **772 runs, 3390 assertions,
0 failures, 0 errors, 0 skips**; `bin/rubocop` **110 files, no offenses**.

---

## Nota sobre o escopo

1. A notação `A..B` inclui os 20 commits listados. O HEAD atual é `e4fad81`
   (`docs(interface)`), commit **de outra feature** — confirmei por
   `git show --stat e4fad81` que ele não toca `app/` nem `test/`. **Fora do
   escopo; não verificado.**
2. `efb6817` **não é task do plano**: é a correção da lacuna HIGH de cobertura
   levantada entre a T16 e a T17 sobre o branch `falhas.any?` do resumo.
   Nenhum checkbox foi marcado por ele. Verifiquei-o mesmo assim, por tocar
   teste da feature — item 4 da seção "Achados que me pediram para julgar".
3. As decisões **AD-006, AD-007 e AD-008** são premissa desta verificação, não
   objeto dela. Verifiquei **conformidade do código com elas**; não as reabri.
4. `.context/tasks.md` §5.2 (`:203`) e §5.3 (`:207`) aparecem marcadas. Os
   bullets das duas foram conferidos um a um adiante.
5. A T16 tem **um "Done when" não marcado**: a revisão `ecc:pr-test-analyzer`.
   O `tasks.md` registra que o executor não despacha subagente e que ficou para
   o orquestrador. Julgo adiante (é a origem da lacuna que `efb6817` fechou).

### Estado medido por mim

| Medição | Resultado |
| ------- | --------- |
| `docker compose exec -T app bin/rails test` | **771 runs, 3387 assertions, 0 failures, 0 errors, 0 skips** (30,7s) |
| `docker compose exec -T app bin/rubocop` | **110 files inspected, no offenses detected** |
| Árvore ao final das 10 mutações | **limpa** — `git status --porcelain` vazio; os 6 arquivos de produção conferidos **idênticos por `md5sum`** contra as cópias de `tmp/vbak/` |
| Resíduo deixado por mim no banco | **zero** — `CardSet` com prefixo `VRF/VRG/VH/M7/M8` = 0; `User` com `@x.test` = 0; `CollectionImport` = 0 |

A suíte cresceu de **502** (fim da `progresso`, medida na T3) para **771**:
**269 testes novos** em 13 arquivos, que é exatamente a contagem que obtive
somando os arquivos da feature um a um.

**A baseline do orquestrador confere nos dois números.** Não copiei: rodei.

### Fatos medidos por mim, não herdados

| Afirmação | Medido por mim | Confere |
| --------- | -------------- | ------- |
| Única FK de `collection_imports` é para `users`, sem cascata | `pg_constraint`: `[["fk_rails_065b992832", "users", "r"]]` — uma só, `confdeltype='r'` | ✅ |
| `collection_items` tem `CHECK (quantity >= 0)` e FKs `RESTRICT` | `["collection_items_quantity_check", "CHECK ((quantity >= 0))"]`, as duas FKs `ON DELETE RESTRICT` | ✅ |
| Apagar usuário com coleção é barrado | `ActiveRecord::DeleteRestrictionError: Cannot delete record because of dependent collection_items` | ✅ |
| `limpar_expiradas` não toca a coleção | apagou 1 staging expirado; retrato da coleção **idêntico** | ✅ |
| `:zera` grava `quantity = 0`, não apaga a linha | após zerar, `pluck(:quantity)` = `[0]` — registro preservado, coerente com Req. 7.3 | ✅ |
| F5 na confirmação não regrava (a alegação da T15) | **verificado empiricamente**, ver item 3 adiante | ✅ |

---

## O ATAQUE À COLEÇÃO — 19 tentativas

O plano pede explicitamente ao Verifier que **tente destruir dado de coleção**.
Ataquei em duas camadas: **serviço** (sonda Ruby em transação com `ROLLBACK`) e
**HTTP** (teste de integração descartável, apagado ao fim). Cada tentativa
abaixo diz o que tentei, como, e o que aconteceu.

**Resultado: nenhuma escrita indevida foi conseguida.** Todas as 19 bateram numa
defesa nomeável.

### Camada de serviço

| # | Ataque | O que aconteceu | Defesa que resistiu |
| - | ------ | --------------- | ------------------- |
| A1 | Rodar `Parser` + `Resolver` com arquivo destrutivo (dois `:zera` + um `:cria`) | classificou `[:zera, :zera, :cria]`; **coleção idêntica** | Nenhum dos dois serviços tem caminho de escrita — `resolver.rb` só faz `pluck` (`:172`, `:182`) |
| A2 | `CollectionImport.create!` com as linhas destrutivas | staging criado; **coleção idêntica** | `collection_imports` não tem FK para `collection_items` (medido em `pg_constraint`) |
| A3 | Atacante chama `Commit.new(atacante, token_da_vítima)` | devolveu **`nil`**; coleção da vítima intacta; staging **continua `pendente`** | `find_by_token_for` filtra por dono **antes** de carregar (`collection_import.rb:78`) |
| A4 | **Staging adulterado**: registro do atacante contendo linhas resolvidas contra a coleção da **vítima** (`quantidade_antes = 7` dela) | escreveu **na coleção do atacante**, não na da vítima. Vítima intacta | A escrita usa `@user.id` do `Commit` (`commit.rb:318`), **nunca** o dono das linhas do staging |
| A5 | Dupla confirmação sequencial | 1ª: `reivindicada=true`; 2ª: `reivindicada=false`, todas as contagens zero; **estado idêntico** entre as duas | `UPDATE ... WHERE status='pendente'` (`commit.rb:171`) não casa na segunda |
| A6 | Confirmar staging **expirado** (`expires_at` no passado) | `reivindicada=false`; coleção intacta | `AND expires_at > now()` no mesmo `WHERE` (`commit.rb:172`) |
| A7 | Forçar `confirmado → pendente` **por SQL direto** (`update_column`) e reconfirmar | reivindicou de novo — mas **a coleção não mudou** (as linhas já estavam no valor final; é idempotente por AD-006) | É o **LOW declarado na T11**. Ver achado L5: não é escalável por HTTP |
| A8 | `variant_code` `p1` existindo sob **duas cartas**, pedir a primeira | resolveu para a variante **certa** (`v1`, não `v2`) | O par `(card_number, variant_code)` é a chave (`resolver.rb:200`) |
| A9 | 11 quantidades hostis: `-1`, `3.5`, `abc`, `""`, `"  "`, `1e9`, `0x10`, `+5`, `1_0`, `٣` (dígito árabe), 20 noves | **todas rejeitadas** com motivo; nenhuma virou escrita | `/\A\d+\z/` (`resolver.rb:208`) — `\d` em Ruby é ASCII-only, então `٣` também cai |
| A10 | Quantidade de **30 dígitos** (passa no regex, estoura `integer`) | classificou `:atualiza`; no commit virou **falha isolada** (`ActiveModel::RangeError`); **coleção intacta** | `rescue StandardError` (`commit.rb:279`) + savepoint por linha — o CRITICAL que a revisão da T14 corrigiu |

### Camada HTTP

| # | Ataque | O que aconteceu | Defesa que resistiu |
| - | ------ | --------------- | ------------------- |
| H1 | `POST` de upload com arquivo destrutivo (um `:zera`, um `:cria`) | `302`; **coleção idêntica** | A action `create` não escreve em `collection_items` (`collection_imports_controller.rb:87-96`) |
| H2 | `GET` da tela de pré-visualização (renderizar escreve?) | `200`, corpo contém "Remove"; **coleção idêntica** | `show` só faz `find_by_token_for` (`:108`) |
| H3 | Atacante faz `GET` da pré-visualização alheia | **404** | `find_by_token_for` + `raise RecordNotFound` (`:110`) |
| H4 | Atacante faz `POST confirm` do token da vítima | **404**; vítima intacta; staging **continua `pendente`** | Mesmo caminho; o `Commit` devolve `nil` e vira 404 (`:129`) |
| H5 | **F5 / replay do POST** após confirmar | 1ª: `200`. F5: **`302`** para a tela do preview, com alerta; **coleção byte a byte idêntica** | A alegação da T15 sobre PRG **confere empiricamente** |
| H6 | `GET show` depois de confirmado | `200`; coleção idêntica | — |
| H7 | `?user_id=` de outro usuário no upload **e** no corpo | staging nasceu do **usuário da sessão**; coleção do atacante intacta | `Current.user` em `create!` e no `Resolver` (`:92-95`) |
| H8 | Anônimo: `POST create`, `POST confirm`, `GET export` | os três **302 → `/session/new`**; nada gravado; export **não vazou** nenhum `card_number` | Default protegido de `ApplicationController`; nenhum `allow_unauthenticated_access` nos dois controllers |
| H9 | **Sessão expirada entre preview e confirm** (sessão apagada do banco) | `302 → /session/new`; **nada gravado** | Edge Case da spec, cumprido |

### O que o ataque revelou sobre o desenho

**A autorização está no carregamento, não na escrita** — e isso é o que faz o A4
terminar bem. `Commit#call` (`commit.rb:209`) carrega por `find_by_token_for(@user, token)`
e a escrita usa `@user.id`; o `card_variant_id` das linhas é apenas um ponteiro
dentro do `jsonb`. Um staging adulterado só consegue **apontar** para variantes:
o **dono** da escrita nunca vem dele. É a mesma observação que a T16 registrou, e
eu a confirmo por execução, não por leitura.

**A invariante do Req. 10.5 está estruturalmente garantida, não apenas testada.**
Há exatamente **um** ponto de escrita em `collection_items` em toda a feature
(`UPSERT_SQL`, `commit.rb:148-154`), alcançável por **um** caminho
(`Commit#gravar`), atrás de **um** `UPDATE` condicional que exige
`status='pendente' AND expires_at > now()`. Parser, Resolver, `new`, `create` e
`show` não têm nenhum.

---

## Task Completion

| Task | Status | Notas |
| ---- | ------ | ----- |
| T1 | ✅ Done | Relógio injetado; causa real (relógio de parede regredindo) ≠ hipótese da spec (`to_i`) — AD-009 |
| T2 | ✅ Done | Pending list do GIN drenada; causa real ≠ hipótese da spec (`ANALYZE`) — AD-009 |
| T3 | ✅ Done | 12/12 verdes registradas; rodadas em série por AD-010 |
| T4 | ✅ Done | Contrato de colunas em um só lugar; 14 testes de formato |
| T5 | ✅ Done | Export por `pluck` + `joins`, uma consulta; 13 testes |
| T6 | ✅ Done | Rota sem segmento de usuário; 16 testes, 6 deles de isolamento |
| T7 | ✅ Done | Link na página de progresso; ausência provada **no catálogo**, onde o anônimo renderiza — `SPEC_DEVIATION` honesto |
| T8 | ✅ Done | `MAX_LINHAS` + `MAX_BYTES`; 33 testes; fronteira testada dos dois lados |
| T9 | ✅ Done | Cinco classificações; duas consultas por lote — ver **L1**, a lacuna do par |
| T10 | ✅ Done | 1 HIGH corrigido (`MAX_BYTES`), 1 HIGH aceito com justificativa (CSV injection), 1 LOW sem ação |
| T11 | ✅ Done | Migração + `pg_constraint` provada; índice redundante removido; MEDIUM virou requisito vinculante da T14 |
| T12 | ✅ Done | Upload não escreve — provado por `assert_no_changes` sobre o **retrato inteiro** (`collection_imports_test.rb:147-149`) |
| T13 | ✅ Done | Cinco grupos, `:zera` no topo; distinção textual, não por cor; 27 testes |
| T14 | ✅ Done | Reivindicação atômica; savepoint por linha; CRITICAL do `rescue` estreito corrigido. **1 sobrevivente consciente confirmado por mim** (M9) |
| T15 | ✅ Done | `:zera` não some dentro de "atualizadas"; 20 testes. Dívida da não-persistência **registrada e julgada** (item 2) |
| T16 | ⚠️ **Done com ressalva** | Os 5 critérios de teste estão cumpridos; o 6º (`ecc:pr-test-analyzer`) ficou **não marcado** e gerou a lacuna que `efb6817` fechou — ver item 4 |
| T17 | ✅ Done | Contagem de consultas em dois volumes; seed com asserção sobre o próprio seed |

---

## Verificação ancorada no spec

### História P0: Suíte confiável antes de escrever a feature

| Critério (spec.md) | Requisito | Evidência (`file:line` + asserção) | Result |
| ------------------ | --------- | ---------------------------------- | ------ |
| 1. `guarantees_test.rb` verde sem depender do instante da ingestão | POR-00 | `test/services/ingestion/guarantees_test.rb` — relógio injetado pelo parâmetro `clock:` que `Ingestion::Upsert#initialize` já expunha; medido por mim: **0 falhas em 771 runs** | ✅ PASS |
| 2. `catalog_search_test.rb` verde sem depender de contenção do planejador | POR-00 | `test/queries/catalog_search_test.rb` — `gin_clean_pending_list` antes do `ANALYZE`, guarda por `pg_stats`; diff `4efc35c` | ✅ PASS |
| 3. Doze execuções sem falha nos dois | POR-00 | Registrado nas "Decisões da execução" da T3: **12/12 com linha idêntica** `502 runs, 1853 assertions, 0 failures`. Não re-rodei as doze (custo; ver "O que não consegui verificar"), mas **rodei a suíte 3× nesta sessão, verde nas três** | ✅ PASS |
| 4. Nenhuma asserção enfraquecida, pulada ou removida | POR-00 | `git diff cb92c65..b73366b -- test/services/ingestion/guarantees_test.rb test/queries/catalog_search_test.rb`: as asserções de ordem e de plano **permanecem**; o que mudou foi a **origem do relógio** e a **preparação do índice** | ✅ PASS |

**As duas causas reais contradizem as duas hipóteses da spec, e isso está
registrado em vez de escondido.** A spec supunha truncamento por `to_i` e falta
de `ANALYZE`; as medições da T1 e T2 falsificaram as duas e AD-009 registra as
causas verdadeiras. É o comportamento correto sob a regra "se um requisito se
mostrar errado, pare e corrija o documento".

### História P1: Export da coleção em CSV

| Critério (spec.md) | Requisito | Evidência (`file:line` + asserção) | Result |
| ------------------ | --------- | ---------------------------------- | ------ |
| 1. CSV com `card_number`, variante, nome e quantidade | POR-01 / Req. 10.1 | `export_test.rb:40` — `escreve cabeçalho e uma linha por variante possuída, com as quatro colunas`; contrato em `format.rb`, travado por `format_test.rb:12` (`as colunas são as quatro da spec, nesta ordem`) | ✅ PASS |
| 2. Linha de cabeçalho nomeando as colunas | POR-01 | `export_test.rb:58` — `o cabeçalho é exatamente o do contrato de colunas`; `format_test.rb:18` — o cabeçalho do export **é** o que o import exige | ✅ PASS |
| 3. Só variantes possuídas; zero é não possuída | POR-02 / Req. 7.3 | `export_test.rb:72` (`quantidade zero não aparece`) **e** `:83` — `quantidade zero produz o mesmo arquivo que não haver registro nenhum`. O par é o que discrimina | ✅ PASS |
| 4. Sem posse → cabeçalho e nenhuma linha, não erro nem vazio | POR-01 | `export_test.rb:93` — `coleção vazia produz cabeçalho e nenhuma linha de dado` | ✅ PASS |
| 5. Deriva do usuário da sessão, ignora id do request | POR-03 / Req. 6.5 | `collection_exports_test.rb:190` (`?user_id=` não muda o arquivo), `:206` (**nenhuma forma** de informar identificador), `:231` (**cabeçalho** de requisição), `:169` (trocar de sessão troca o dono). Medido por mim em H7 | ✅ PASS |
| 6. Anônimo é redirecionado sem receber arquivo | POR-03 / Req. 6.4 | `collection_exports_test.rb:79` — `assert_redirected_to new_session_path`; **e** `:87` — o **corpo** não contém nenhuma linha de coleção. Medido por mim em H8 | ✅ PASS |
| 7. UTF-8, acentos íntegros | POR-01 | `export_test.rb:104` (nome com acento, arquivo UTF-8); `collection_exports_test.rb:300` — o acento sobrevive **à resposta HTTP**, não só à serialização; `:316` — `Content-Type` declara UTF-8 | ✅ PASS |

**O par de testes `:72`/`:83` é o que torna o critério 3 uma prova.** Sozinho, o
`:72` passaria com um export que filtrasse a variante zerada por acidente (por
exemplo, ordenando e truncando). O `:83` exige **equivalência observacional** com
o cenário sem registro, que é a leitura literal do Req. 7.3. Minha mutação **M8**
(remover o scope `owned`) confirma: morre com 1 falha e 38 erros.

### História P1: Pré-visualização obrigatória do import

| Critério (spec.md) | Requisito | Evidência (`file:line` + asserção) | Result |
| ------------------ | --------- | ---------------------------------- | ------ |
| 1. Antes de qualquer escrita, apresentar o que cada linha produzirá | POR-07 / Req. 10.5 | `collection_import_preview_ui_test.rb:159` — `cada uma das cinco classificações recebe uma marcação própria`; `collection_imports_test.rb:191` — o staging guarda **antes e depois** por linha | ✅ PASS |
| 2. Distinguir cria / altera / rejeita | POR-07 | `preview_ui_test.rb:173` — `as três classes do plano têm rótulos visíveis e diferentes entre si`; `:192` — a destrutiva **não se confunde** com a que só altera; `:207` — a inalterada não se confunde com a que altera | ✅ PASS |
| 3. Exigir confirmação explícita | POR-07 / Req. 10.5 | A escrita só existe em `confirm` (`routes.rb:99`, `POST`), e `commit_test.rb:324` — `a confirmação não aceita arquivo: o que grava é o staging, não o upload` | ✅ PASS |
| 4. Enquanto não confirmar, coleção inalterada | POR-07 | `collection_imports_test.rb:147-149` — `assert_no_changes` triplo sobre quantidade de item existente, item zerado e `CollectionItem.count`; `:159` — a tabela fica **byte a byte** como estava. Medido por mim em H1/H2 | ✅ PASS |
| 5. Abandonar o fluxo deixa tudo como estava | POR-07 | `commit_test.rb:306` — `abandonar o fluxo sem confirmar deixa a coleção exatamente como estava`; `preview_ui_test.rb:479` — ver a tela **várias vezes** continua não gravando | ✅ PASS |
| 6. A confirmação grava **exatamente** o que foi apresentado | POR-08 / Req. 10.5 | `commit_test.rb:152` — `a confirmação grava exatamente o que a pré-visualização apresentou`, comparado **contra a pré-visualização**, não contra o arquivo; `:361` — `o staging é a única entrada da escrita: adulterá-lo muda o que é gravado` | ✅ PASS |

**O critério 6 é o mais difícil de provar e está provado pelo lado certo.** O
teste `:361` é a peça-chave: ele **adultera o staging** e exige que o gravado
mude junto. Sem ele, uma implementação que reparseasse o arquivo passaria no
`:152` sempre que arquivo e staging concordassem — que é o caso normal. Meu
ataque A4 explora exatamente esse ponto por fora e confirma o mesmo desenho.

### História P1: Import linha a linha com rejeição isolada

| Critério (spec.md) | Requisito | Evidência (`file:line` + asserção) | Result |
| ------------------ | --------- | ---------------------------------- | ------ |
| 1. Importa o formato produzido pelo export | POR-04 / Req. 10.2 | `parser_test.rb:58` — `o arquivo produzido pelo export é aceito pelo parser`; `format_test.rb:18` fecha o contrato nos dois sentidos | ✅ PASS |
| 2. Variante inexistente → rejeita com motivo, demais seguem | POR-05 / Req. 10.3 | `resolver_test.rb:130` — `variante inexistente é rejeitada com motivo e as demais são processadas`; mensagem em `resolver.rb:56` | ✅ PASS |
| 3. Quantidade inválida → rejeita com motivo, sem interromper | POR-05 | `resolver_test.rb:150`; ampliado por mim em A9 com **11 formas hostis**, todas rejeitadas | ✅ PASS |
| 4. Resolve pelo **par**, nunca pelo nome | POR-05 | `resolver_test.rb:73` (nome diverge, resolve igual), `:91` (`variant_code` sob outra carta), `:108` (par inexistente não aproxima) | ⚠️ **PASS com lacuna** — ver **L1** |
| 5. Formato inesperado → recusa o arquivo inteiro, em português, antes de processar | POR-04 | `parser_test.rb:166` (colunas faltando), `:186` — `cabeçalho errado descarta até as linhas bem formadas que vêm depois`; `:391` — a recusa **não emite consulta** ao catálogo | ✅ PASS |
| 6. Cada linha aceita grava sem desfazer as anteriores | POR-06 / Req. 10.3 | `commit_test.rb:636` (uma linha que falha não desfaz as anteriores), `:682` (erro que **não** é do Active Record), `:704` (erro cru do driver), `:720` (`SystemExit` **não** é engolido) | ✅ PASS |
| 7. Reimportar o export sem edição deixa idêntico | POR-11 | `roundtrip_test.rb:178`, `:197` (**três ciclos**), `:213` (os dois exports **byte a byte**) | ✅ PASS |

**O critério 6 é o que o CRITICAL da revisão da T14 salvou.** Os testes `:682`,
`:704` e `:720` existem porque o `rescue` original capturava
`ActiveRecord::ActiveRecordError`, e `PG::Error` **não herda dela** — uma queda
de conexão na linha 4.000 de 10.000 teria desfeito as 3.999 já gravadas. Confirmei
a hierarquia: `rescue StandardError` (`commit.rb:279`) é a correção certa, e o
`:720` impede que ela vire captura indiscriminada.

### História P2: Resumo final da importação

| Critério (spec.md) | Requisito | Evidência (`file:line` + asserção) | Result |
| ------------------ | --------- | ---------------------------------- | ------ |
| 1. Quantidade de importadas, atualizadas e rejeitadas | POR-09 / Req. 10.4 | `summary_test.rb:188` — `o resumo apresenta as três contagens do Req. 10.4` | ✅ PASS |
| 2. Motivo de cada rejeitada, identificando a linha | POR-10 / Req. 10.4 | `summary_test.rb:278` (motivo + identificação), `:300` (causas diferentes → motivos diferentes), `:315` — a identificação é o **número da linha no arquivo** (`indice + 2`) | ✅ PASS |
| 3. Resumo em português | POR-09 | `summary_test.rb:433` (não vaza vocabulário de sistema), `:447` (singular correto — recusa `1 linhas` e `linha(s)`) | ✅ PASS |
| 4. Sem rejeição, não sugerir erro | POR-09 | `summary_test.rb:346` (`sem nenhuma rejeição o resumo não sugere erro`) **e o contrapositivo** `:385` (`com rejeição o resumo sinaliza que há linhas a conferir`) | ✅ PASS |
| — | POR-09 | **Os números batem com o banco, não com a intenção**: `summary_test.rb:206` — `as contagens do resumo batem com o que de fato mudou no banco`; `:227`; `:268` | ✅ PASS |

**O par `:346`/`:385` é a razão de o critério 4 não ser satisfazível por
preguiça.** Sem o contrapositivo, a saída mais barata para "não sugerir erro"
seria apagar o vocabulário de recusa da tela inteira — o que quebraria o critério
1 em silêncio. O `tasks.md` registra que a primeira versão do teste reprovava a
implementação correta e foi **corrigida para o observável certo**, não
enfraquecida. Julgo a correção legítima: o que o critério 4 proíbe é o **aparato
de erro no DOM**, e é isso que o teste passou a exigir.

### História P2: Isolamento e custo das duas metades

| Critério (spec.md) | Requisito | Evidência (`file:line` + asserção) | Result |
| ------------------ | --------- | ---------------------------------- | ------ |
| 1. Export e import derivam do usuário da sessão | POR-12 / Req. 6.5 | `export.rb` e `resolver.rb` partem de `for_user`, que **levanta `ArgumentError` num id** (`export_test.rb:195`, `resolver_test.rb:421`); controller usa `Current.user` (`collection_imports_controller.rb:92-95`) | ✅ PASS |
| 2. Identificador informado na requisição é ignorado | POR-12 | `collection_imports_test.rb:238` (`?user_id=`), `:251` (**nenhuma forma**), `:274` (**header**); `collection_exports_test.rb:190`, `:206`, `:231`. Medido por mim em H7 | ✅ PASS |
| 3. Dois usuários com o mesmo arquivo mantêm coleções independentes | POR-12 | `roundtrip_test.rb:359` — `dois usuários que importam o mesmo arquivo mantêm coleções independentes`; `:391`; `:415`; `:433` — a pré-visualização alheia é calculada sobre a coleção **de quem enviou** | ✅ PASS |
| 4. Export em número de consultas que não cresce com as linhas | POR-13 / Req. 11.1 | `collection_csv_plan_test.rb:147` — dois volumes, mesmo número de consultas; `:163` — a consulta única **de fato traz as linhas** (impede passar por não consultar nada) | ✅ PASS |
| 5. Pré-visualização sem consulta por linha | POR-13 | `collection_csv_plan_test.rb:186` (dois volumes de **arquivo**, 40 e 2.000), `:203` — **de fato classifica todas as linhas**; `:228` — descontada a sessão, resolve num punhado constante | ✅ PASS |

**O critério 4 do lado positivo é o que impede a fraude trivial.** `:163` e `:203`
existem para que "zero consulta por linha" não seja alcançável por "zero trabalho":
um export que devolvesse vazio teria contagem constante e passaria sem eles.

**A T16 encontrou e fechou o furo simétrico.** O `roundtrip_test.rb:464` (`a
confirmação grava na coleção de quem confirmou, e não na de outro usuário`) é o
teste de **lado positivo** acrescentado depois que a mutação "trocar o dono da
escrita" sobreviveu a treze testes de invariância negativa. Minha mutação **M1**
reproduz aquela mutação e agora **morre com 18 falhas** — a correção é real e
eu a verifiquei, não a aceitei.

---

## Edge Cases da spec

| Edge Case | Evidência (`file:line`) | Result |
| --------- | ----------------------- | ------ |
| Mesma variante em duas linhas — a última não pode vencer em silêncio | `resolver_test.rb:321` — `a última vale e as anteriores são rejeitadas com motivo`; motivo próprio `:linha_duplicada` (`resolver.rb:58`); `:345` — duas variantes **da mesma carta** não são duplicata | ✅ PASS |
| Quantidade zero significa "não possuo"; efeito decorre de P8 | `resolver_test.rb:268` (zero sobre possuída → `:zera`, classificação própria), `:284` (zero sobre **não** possuída → não é destrutivo), `:298` (zero sobre já zerado → `:inalterada`) | ✅ PASS |
| BOM do Excel não impede reconhecer o cabeçalho | `format_test.rb:46`, `:53` (BOM removido **só** da primeira célula), `:58` (BOM **+** ordem trocada); `parser_test.rb:130`, `:141` | ✅ PASS |
| `;` em vez de `,` → recusa dizendo o delimitador esperado | `parser_test.rb:206`, `:214` (a recusa **diz** o delimitador), `:226` — arquivo de uma coluna só **sem** `;` cai na outra recusa | ✅ PASS |
| Cabeçalho em ordem diferente → colunas por nome | `format_test.rb:30`, `:37` (preserva a ordem **do arquivo**), `:66` (espaço e caixa); `parser_test.rb:114` | ✅ PASS |
| Variante marcada como ausente da fonte continua importável | `resolver_test.rb:371` (marca velha) **e** `:390` (`last_seen_at` **nulo**) — os dois casos | ✅ PASS |
| Catálogo reingerido entre export e import: o par continua resolvendo | Propriedade de AD-001 (`id` estável por variante) + Req. 1.7 (ingestão não deleta). O resolvedor **não consulta** `last_seen_at` — verificado por leitura de `resolver.rb:167-177` e coberto indiretamente por `:371`/`:390` | ✅ PASS |
| Arquivo que não é CSV → recusa explícita, em português, sem stack trace | `parser_test.rb:239` (texto solto), `:247` (JSON), `:254` (CSV malformado vira recusa, não exceção), `:280` — **nenhuma** mensagem contém stack trace ou nome de classe | ✅ PASS |
| Sessão expira entre pré-visualização e confirmação → nada gravado, leva à autenticação | `commit_test.rb:808` + `:817` `assert_redirected_to new_session_path`. **Medido por mim em H9** | ✅ PASS |
| Duas confirmações da mesma pré-visualização não duplicam o efeito | `commit_test.rb:444`; `:468` — a segunda transição **afeta zero linhas**; `:492` — é **um único `UPDATE` condicional, sem `SELECT` antes`**. Medido por mim em A5 e H5 | ✅ PASS |

**O Edge Case da dupla confirmação está provado no nível onde o defeito mora.**
`:492` assevera sobre o **SQL efetivamente emitido** (`sql.active_record`), não
sobre o desfecho — porque, como o `tasks.md` registra honestamente, a primeira
versão do teste **sobrevivia** à mutação `SELECT`+`UPDATE`: duas chamadas
sequenciais produzem o mesmo desfecho nos dois desenhos. Minhas mutações **M2**
(2 falhas) e **M3** (4 falhas) confirmam que as duas guardas do `WHERE` estão
travadas.

---

## "Done when" das 17 tasks

Confiro abaixo os critérios que exigem evidência própria. Os de gate
(`rubocop` limpo, `docker compose build`) foram verificados globalmente: rubocop
**110 files, no offenses**.

### T1–T3 (suíte determinística)

| Critério | Evidência | Result |
| -------- | --------- | ------ |
| Causa identificada e escrita no cabeçalho, com evidência | AD-009 documenta as duas causas com medição (4 saltos de ±11,25s em 2000 leituras; custo do índice de 34,31 a 1292,31 em 8 seeds idênticos) | ✅ PASS |
| Flake reproduzido **antes** de corrigir, com registro | T1: `Expected ... to be > ...` com inversão de 8s. T2: reprodução registrada | ✅ PASS |
| Correção ataca a causa; asserção não enfraquecida | Diff confirma: mudou a **origem do relógio** e a **preparação do índice**, não as asserções | ✅ PASS |
| Doze execuções, zero falha, cada uma registrada | 12/12 registradas com linha idêntica nas "Decisões da execução" da T3 | ✅ PASS |

### T4–T7 (export)

| Critério | Evidência | Result |
| -------- | --------- | ------ |
| `csv` no Gemfile com comentário sobre Ruby 3.4 | `Gemfile` (diff `54aa67b`); `Gemfile.lock` commitado | ✅ PASS |
| Colunas em **um único lugar**, consumido pelos dois | `format.rb`; `format_test.rb:18` prova a identidade export↔import | ✅ PASS |
| Cabeçalho por nome, não por posição; BOM aceito | `format_test.rb:30`, `:46`, `:58` | ✅ PASS |
| Export recebe o **objeto** `User`, nunca id | `export_test.rb:195` — `recebe o objeto User e recusa um id` | ✅ PASS |
| Zero não aparece; igual a não haver registro | `export_test.rb:72`, `:83` | ✅ PASS |
| Acento íntegro; vírgula/aspas escapadas e relidas | `export_test.rb:104`, `:121`, `:133`, `:141` (vírgula **+** aspas **+** quebra de linha juntas) | ✅ PASS |
| Consultas não crescem com as linhas | `export_test.rb:155`; reforçado em `collection_csv_plan_test.rb:147` | ✅ PASS |
| Dois usuários → arquivos distintos | `export_test.rb:173` | ✅ PASS |
| Controller **não** declara `allow_unauthenticated_access`; anônimo sem arquivo | Verificado por leitura de `collection_exports_controller.rb`; `collection_exports_test.rb:79` + `:87`. Medido em H8 | ✅ PASS |
| `Content-Type` CSV e `Content-Disposition: attachment` | `collection_exports_test.rb:112`; `:129` — o nome **não carrega e-mail nem id** | ✅ PASS |
| Rota não aceita identificador de usuário | `collection_exports_test.rb:253` (nenhum segmento dinâmico), `:274` | ✅ PASS |
| Link aparece ao autenticado e **não** ao anônimo | `collection_export_link_test.rb:72`, `:86` (oferecido **de fato**), `:133` + `:147` — ausência provada **no catálogo**, onde o anônimo renderiza HTML | ✅ PASS |
| Rótulo em português, alvo de 24px, sem scroll em 360px | `:170`, `:186`, `:230`, `:255` | ✅ PASS (com `SPEC_DEVIATION` julgado adiante) |
| Checkbox da §5.2 marcado | `.context/tasks.md:203` — `- [x] **5.2 Export CSV**` | ✅ PASS |

### T8–T10 (import sem escrita)

| Critério | Evidência | Result |
| -------- | --------- | ------ |
| Arquivo sem as colunas → recusa **inteira**, em português | `parser_test.rb:166`, `:174` (nomeia as colunas que faltam), `:186` | ✅ PASS |
| `;` recusado dizendo o delimitador | `parser_test.rb:206`, `:214` | ✅ PASS |
| Não-CSV recusado sem stack trace | `parser_test.rb:239`, `:247`, `:254`, `:280` | ✅ PASS |
| 10.000 aceitas, 10.001 recusada — **fronteira dos dois lados** | `parser_test.rb:306` (exatamente o limite **é aceito**), `:313` (uma a mais recusada), `:320` (o limite é de dado, sem cabeçalho) | ✅ PASS |
| Limite verificado **antes** de resolver variante | `parser_test.rb:391` (recusa não consulta), `:397` (nem o caminho de aceitação consulta) | ✅ PASS |
| **Nenhum caminho escreve no banco** | `parser_test.rb:413`, `:438`; `resolver_test.rb:471` + `:488-490` (`assert_no_changes` triplo). **Medido por mim em A1** | ✅ PASS |
| Resolve pelo par, nunca pelo nome | `resolver_test.rb:73`, `:91`, `:108` | ⚠️ ver **L1** |
| Classificação distingue cria/atualiza/rejeita com antes e depois | `resolver_test.rb:200`; `:228` (substituir, não somar); `:244` (`:inalterada`) | ✅ PASS |
| Duas linhas da mesma variante: a última não vence em silêncio | `resolver_test.rb:321` | ✅ PASS |
| Resolução não emite consulta por linha | `resolver_test.rb:434`; `collection_csv_plan_test.rb:186` | ✅ PASS |
| `ecc:security-reviewer` revisou; HIGH corrigido ou justificado | 1 HIGH corrigido (`MAX_BYTES` 8 MB antes do parse, `parser_test.rb:333`, `:349`, `:366`); 1 HIGH aceito com rastreamento escrito (CSV injection — `card_name` do arquivo nunca é reexportado; `export.rb` lê `cards.name` do catálogo); 1 LOW sem ação | ✅ PASS |
| Conteúdo de linha não vira fórmula nem marcação na tela | `preview_ui_test.rb:540` — `o nome de carta vindo do arquivo é escapado e não vira marcação`; `summary_test.rb:488` | ✅ PASS |
| Limite não contornável por linha longa ou codificação | `parser_test.rb:333` (poucas linhas, muitos bytes), `:267` (bytes inválidos em UTF-8) | ✅ PASS |

**Julgo o HIGH de CSV injection corretamente adiado.** O revisor identificou um
risco real de classe; o executor **rastreou** que `card_name` vindo do arquivo
existe em dois pontos e nenhum leva a reexportação, porque a spec fixou
`card_name` como informativo e o `Export` lê do catálogo. A pendência que isso
cria (qualquer reexportação futura de dado do usuário precisa prefixar a célula)
está **escrita**. Aceitar o achado sem aceitar a correção proposta é o precedente
da T11 da `colecao`, e aqui é bem aplicado.

### T11 (staging)

| Critério | Evidência | Result |
| -------- | --------- | ------ |
| Migração criada e `db/structure.sql` regenerado | `db/migrate/20260919120600_create_collection_imports.rb`; `db/structure.sql` no diff | ✅ PASS |
| `user_id` com FK **sem cascata** + campo de expiração | **Medido por mim**: `pg_constraint` devolve `[["fk_rails_065b992832","users","r"]]` — única FK, `RESTRICT` | ✅ PASS |
| Constraints provadas **contra o banco**, não só por validação | `collection_import_test.rb:70` (NOT NULL no banco), `:81`, `:104` (estado fora da lista recusado **pelo banco**), `:135` (token único no banco) | ✅ PASS |
| `for_user` exige objeto `User`, levanta `ArgumentError` num id | `collection_import_test.rb:260` | ✅ PASS |
| Pré-visualização alheia não é legível, e a tentativa **não revela a existência** | `collection_import_test.rb:276` **e** `:285` — `buscar o token alheio é indistinguível de buscar um token inexistente`. Medido por mim em H3/H4 (os dois dão 404) | ✅ PASS |
| Registro expirado não é confirmável | `collection_import_test.rb:311`; medido em A6 | ✅ PASS |
| Caminho de limpeza dos expirados, com teste | `collection_import_test.rb:347`, `:365` — `a limpeza não toca na coleção de ninguém`. Medido por mim em Q4 | ✅ PASS |
| **Nenhuma FK cascateia para `collection_items`** | `collection_import_test.rb:181`, `:192`, `:208` (apagar a pré-visualização não altera a coleção). Medido por mim em `pg_constraint` | ✅ PASS |
| Índice redundante removido e fixado por teste | `collection_import_test.rb:156` — `a tabela não tem índice redundante sobre user_id sozinho` | ✅ PASS |

### T12–T14 (upload, tela, escrita)

| Critério | Evidência | Result |
| -------- | --------- | ------ |
| Upload não altera a coleção — `assert_no_changes` com arquivo que criaria e atualizaria | `collection_imports_test.rb:147-149` (triplo) e `:159` (retrato **inteiro** da tabela). Medido em H1 | ✅ PASS |
| Staging pertence a `Current.user`; `?user_id=` não muda o dono | `collection_imports_test.rb:228`, `:238`, `:251`, `:274`. Medido em H7 | ✅ PASS |
| Arquivo recusado **não cria staging** | `collection_imports_test.rb:289`, `:301`, `:316`, `:331`, `:347`, `:363`, `:376` — sete formas de recusa, todas sem staging | ✅ PASS |
| Resposta identifica a pré-visualização de forma que só o dono confirme | `collection_imports_test.rb:395`, `:410` — **não é o id sequencial**, é o token | ✅ PASS |
| CSRF não desabilitado | `collection_imports_test.rb:527` — `o controller de import não desabilita a verificação de CSRF` | ✅ PASS |
| Nome de arquivo hostil sanitizado, não vira caminho | `collection_imports_test.rb:537`; `nome_para_exibicao` reduz ao basename e limpa | ✅ PASS |
| Três classes distinguíveis na tela; antes e depois; motivo por linha | `preview_ui_test.rb:173`, `:217`, `:229`, `:244`, `:304`, `:329` | ✅ PASS |
| Distinção **não é só por cor** | `preview_ui_test.rb:343` (nenhuma regra distingue só por cor — auditada **isoladamente**, depois de uma mutação passar pela versão concatenada), `:380` (legível **sem estilo nenhum**) | ✅ PASS |
| Renderizar a tela não grava | `preview_ui_test.rb:450`, `:464`, `:479`. Medido em H2/H6 | ✅ PASS |
| Aviso destrutivo junto do controle que grava, ausente sem destruição | `preview_ui_test.rb:507` **e** `:522` — o par impede aviso fixo | ✅ PASS |
| Grava exatamente o previsto; comparado contra a pré-visualização | `commit_test.rb:152`, `:175`, `:361` | ✅ PASS |
| Confirmação exige a pré-visualização; não há caminho do arquivo | `commit_test.rb:324` | ✅ PASS |
| Confirmação alheia não grava e não revela | `commit_test.rb:383`, `:405`. Medido em A3/H4 | ✅ PASS |
| Duas confirmações não duplicam | `commit_test.rb:444`, `:468`, `:492`. Medido em A5/H5 | ✅ PASS |
| Linha que falha não desfaz as anteriores | `commit_test.rb:636`, `:657`, `:682`, `:704`, `:720` | ✅ PASS |
| Usa `ON CONFLICT`, não ler-em-Ruby-e-escrever | `commit.rb:148-154`; `commit_test.rb:766` (absorve registro criado depois), `:793` (recria apagado) | ✅ PASS |
| Quantidade resultante é a do arquivo (substituir) | `commit_test.rb:275`. Mutação M1 do plano: 8 falhas | ✅ PASS |
| Sessão expirada não grava e leva à autenticação | `commit_test.rb:808`, `:817`. Medido em H9 | ✅ PASS |
| Reivindicação e escrita na mesma transação, savepoint por linha | `commit_test.rb:539` — observável é `open_transactions` por statement, não `BEGIN` | ✅ PASS |
| Lote acima do teto recusado antes de gravar | `commit_test.rb:736`; `commit.rb:238-242` | ✅ PASS |

### T15–T17 (resumo e provas não-funcionais)

| Critério | Evidência | Result |
| -------- | --------- | ------ |
| As três contagens | `summary_test.rb:188` | ✅ PASS |
| Os números batem com o **banco**, não com a intenção | `summary_test.rb:206`, `:227`, `:268` — conta em `collection_items` e compara com o que a **tela** imprimiu | ✅ PASS |
| Motivo + identificação por linha rejeitada | `summary_test.rb:278`, `:300`, `:315` | ✅ PASS |
| Sem rejeição, não sugere erro | `summary_test.rb:346` + contrapositivo `:385` | ✅ PASS |
| Português com plural correto | `summary_test.rb:433`, `:447` | ✅ PASS |
| Checkbox da §5.3 marcado | `.context/tasks.md:207` | ✅ PASS |
| Ida e volta item a item, não só contagem | `roundtrip_test.rb:178` (retrato `card_variant_id => quantity`), `:197` (**três ciclos**), `:213` (byte a byte) | ✅ PASS |
| Ida e volta com acento, vírgula e mais de um set | `roundtrip_test.rb:229`, `:251` | ✅ PASS |
| Dois usuários, mesmo arquivo, coleções independentes | `roundtrip_test.rb:359`, `:391`, `:415` | ✅ PASS |
| **A confirmação grava na coleção de quem confirmou** (lado positivo) | `roundtrip_test.rb:464` — o teste que matou o sobrevivente da T16. Minha M1 confirma: **18 falhas** | ✅ PASS |
| `ecc:pr-test-analyzer` revisou os testes da T16 | ❌ **Não marcado**; ficou para o orquestrador. Ver **L2** | ⚠️ Pendente |
| Consultas do export não crescem em dois volumes | `collection_csv_plan_test.rb:147`, `:163` | ✅ PASS |
| Idem para a pré-visualização | `:186`, `:203`, `:228` | ✅ PASS |
| Volume realista, não três registros | `:248` — teste que **exige** o próprio seed (20.000 variantes, dois regimes, item zerado) | ✅ PASS |
| `ANALYZE` antes de qualquer `EXPLAIN` | `:285` — asserção sobre `pg_stats` (síncrono e transacional), **nunca** `pg_class.reltuples` | ✅ PASS |
| Nenhum índice criado sem medição | `:362` — `nenhum índice foi criado para o export ou para a pré-visualização sem medição`; `:379` — os que existem, existem | ✅ PASS |

---

## Bullets da §5.2 e §5.3 de `.context/tasks.md`

### §5.2 Export CSV (`.context/tasks.md:203`, marcada)

| Bullet | Evidência | Result |
| ------ | --------- | ------ |
| `card_number`, identificador da variante, nome e quantidade (Req. 10.1) | `format_test.rb:12` (as quatro, nesta ordem); `export_test.rb:40` | ✅ PASS |

### §5.3 Import CSV (`.context/tasks.md:207`, marcada)

| Bullet | Evidência | Result |
| ------ | --------- | ------ |
| Aceitar o mesmo formato do export (Req. 10.2) | `parser_test.rb:58`; `format_test.rb:18`; ida e volta em `roundtrip_test.rb:178` | ✅ PASS |
| Pré-visualização com confirmação obrigatória antes de gravar (Req. 10.5) | `collection_imports_test.rb:147-149`; `commit_test.rb:306`, `:324`. **19 ataques meus não conseguiram furar** | ✅ PASS |
| Linha com variante inexistente é rejeitada com motivo; as demais seguem (Req. 10.3) | `resolver_test.rb:130`; `commit_test.rb:636` | ✅ PASS |
| Resumo final: importadas, atualizadas, rejeitadas, com motivo (Req. 10.4) | `summary_test.rb:188`, `:278` | ✅ PASS |

---

## Cobertura dos 14 requisitos POR-00..POR-13

| ID | Requisito | Evidência principal | Result |
| -- | --------- | ------------------- | ------ |
| POR-00 | Suíte determinística | AD-009; 12/12 na T3; **3/3 verdes na minha sessão** | ✅ PASS |
| POR-01 | Export com as quatro colunas (Req. 10.1) | `export_test.rb:40`; `format_test.rb:12` | ✅ PASS |
| POR-02 | Export só de possuídas (Req. 7.3) | `export_test.rb:72` + `:83`; mutação M8 morre | ✅ PASS |
| POR-03 | Export exige sessão, parte de `Current.user` (Req. 6.4, 6.5) | `collection_exports_test.rb:79`, `:87`, `:190`, `:231` | ✅ PASS |
| POR-04 | Import aceita o formato do export (Req. 10.2) | `parser_test.rb:58`; `format_test.rb:18` | ✅ PASS |
| POR-05 | Variante inexistente rejeitada com motivo (Req. 10.3) | `resolver_test.rb:130`, `:150` | ✅ PASS |
| POR-06 | Rejeição isolada não aborta o lote (Req. 10.3) | `commit_test.rb:636`, `:682`, `:704`, `:720` | ✅ PASS |
| POR-07 | Pré-visualização obrigatória antes de gravar (Req. 10.5) | `collection_imports_test.rb:147-149`, `:159`; `preview_ui_test.rb:450` | ✅ PASS |
| POR-08 | Confirmação grava o previsto (Req. 10.5) | `commit_test.rb:152`, `:361` | ✅ PASS |
| POR-09 | Resumo com as três contagens (Req. 10.4) | `summary_test.rb:188`, `:206` | ✅ PASS |
| POR-10 | Motivo por linha rejeitada (Req. 10.4) | `summary_test.rb:278`, `:315`; `preview_ui_test.rb:304` | ✅ PASS |
| POR-11 | Ida e volta idempotente | `roundtrip_test.rb:178`, `:197`, `:213` | ✅ PASS |
| POR-12 | Import exige sessão e escreve só na coleção do usuário (Req. 6.4, 6.5) | `roundtrip_test.rb:391`, `:464`; `commit_test.rb:383`. **Ataques A3, A4, H4, H7, H8** | ✅ PASS |
| POR-13 | Export e pré-visualização sem consulta por linha (Req. 11.1) | `collection_csv_plan_test.rb:147`, `:186`, `:203` | ✅ PASS |

**14 requisitos, 14 com evidência. Nenhum órfão.**

---

## Sensor de discriminação — mutações que eu desenhei

Dez mutações **minhas**, distintas das dos autores, mirando o que **eu** julguei
mais frágil: a fronteira de autorização, as guardas do `WHERE` e a classificação
que esconde destruição. Todas em **cópia** sob `tmp/vbak/`, restauradas e
conferidas por `md5sum` (não só `diff`). **Nunca `git stash`.**

| # | Mutação | Onde | Testes mortos | Conclusão |
| - | ------- | ---- | ------------- | --------- |
| M1 | Escrita vai para **outro usuário** (`User.where.not(id: @user.id).first`) | `commit.rb:318` | **18 falhas** | ✅ Morre. O furo que a T16 fechou está de fato fechado |
| M2 | Remover `AND expires_at > now()` da reivindicação | `commit.rb:172` | **2 falhas** | ✅ Morre |
| M3 | Remover `AND status = 'pendente'` da reivindicação | `commit.rb:171` | **4 falhas** | ✅ Morre — a dupla confirmação está travada |
| M4 | `find_by_token_for` sem o filtro de dono | `collection_import.rb:78` | **5 falhas** | ✅ Morre — a autorização do staging está travada |
| M5 | `:zera` fora de `CLASSIFICACOES_GRAVAVEIS` (tela promete remover, banco não cumpre) | `commit.rb:130` | **10 falhas** | ✅ Morre |
| M6 | `:zera` classificado como `:atualiza` (esconde a destruição do usuário) | `resolver.rb:141` | **6 falhas + 1 erro** | ✅ Morre — a regra da T15 é real |
| **M7** | **Resolver por `variant_code` sozinho, ignorando `card_number`** | `resolver.rb:200` + `:176` | **0 falhas na suíte inteira (771 runs)** | ❌ **SOBREVIVE — achado L1** |
| M8 | Export sem o scope `owned` (exporta zerados) | `export.rb` | **1 falha + 38 erros** | ✅ Morre |
| M9 | Remover a guarda `card_variant_id.present?` | `commit.rb:309` | **0 falhas** | ⚠️ Sobrevive — **declarado** pela T14; confirmo a honestidade |
| M10 | Aceitar quantidade negativa (`/\A-?\d+\z/`) | `resolver.rb:208` | **1 falha** | ✅ Morre |

**Oito mortas, dois sobreviventes — um declarado, um novo.**

### M7 — o sobrevivente que é achado (L1)

Esta é a mutação que a própria spec nomeia como o risco a evitar. O texto de
`spec.md` diz, sobre a chave do CSV:

> "Resolver por `variant_code` sozinho **funcionaria hoje e passaria a casar a
> variante errada em silêncio depois**."

E o "Done when" da T9 pede: *"um `variant_code` válido sob outra carta não
resolve na variante errada — o par é a chave"*. **Existem dois testes para
isso** (`resolver_test.rb:91` e `:108`) e **nenhum dos dois discrimina.**

**Por que eles não pegam.** `variantes_por_par` filtra
`WHERE cards.card_number IN (...)` (`resolver.rb:172-176`). Num arquivo de **uma
linha só**, apenas uma carta entra no `IN`, então a colisão de chave não pode
acontecer — a consulta **mascara** a mutação. Os dois testes usam exatamente um
`linha(...)` cada.

**Reproduzi o defeito num arquivo de duas linhas**, que é o caso do produto real
(o export sempre tem várias). Duas cartas distintas, ambas com `variant_code`
`_p1`:

```
### ORIGINAL ###
  linha0 atualiza => variante=4942 esperado=4942 CORRETO=true  antes=9 depois=5
  linha1 atualiza => variante=4943 esperado=4943 CORRETO=true  antes=2 depois=6
### MUTADO M7 ###
  linha0 rejeita  => variante=4945 esperado=4944 CORRETO=false antes=nil depois=nil
  linha1 atualiza => variante=4945 esperado=4945 CORRETO=true  antes=2 depois=6
```

Sob a mutação, a **linha 0 aponta para a variante da outra carta** — escrita
cruzada silenciosa no dado insubstituível. E a suíte inteira fica **verde**:
`771 runs, 3387 assertions, 0 failures`.

**Severidade: HIGH, não bloqueante.** O código de produção **está correto** — o
par é a chave (`resolver.rb:200`). O que falta é o **teste que trava a correção**.
É defeito de cobertura, não de comportamento: nada está quebrado hoje, mas a
garantia que a spec mais enfatiza não está protegida contra regressão. É
exatamente o mesmo padrão que a T16 encontrou e corrigiu no `Commit`, sobrevivendo
num arquivo diferente — que é o que o item 5 do meu briefing mandou procurar.

**Correção mínima sugerida** (não a implementei — não escrevo teste): acrescentar
a `resolver_test.rb` um teste com **duas linhas no mesmo lote**, duas cartas
distintas partilhando o `variant_code`, afirmando que **cada** linha resolve na
sua variante. Um teste, e a M7 morre.

### M9 — o sobrevivente declarado, confirmado

A T14 registra: *"a guarda `card_variant_id.present?` é redundante. Removê-la não
quebra nenhum teste, porque `CLASSIFICACOES_GRAVAVEIS` já exclui toda linha sem
variante resolvida."* **Confirmo por execução**: 0 falhas.

**Julgo a declaração honesta e a decisão correta.** Verifiquei a premissa: as
quatro classificações graváveis (`cria`, `atualiza`, `zera`, `inalterada`) só são
atribuídas depois de `base.card_variant_id = variante_id` (`resolver.rb:90`), e
toda saída sem variante passa por `rejeitar` (`:88`). A guarda é de fato
inalcançável **pelo estado que o resolvedor produz**. Mantê-la como defesa em
profundidade sobre dado insubstituível, e **registrá-la como redundante** em vez
de inventar um teste sobre um estado impossível, é a escolha certa — um teste
*contrived* daria falsa sensação de cobertura.

---

## SPEC_DEVIATION — julgamento

Levantei **16 ocorrências** em `test/` (`grep -rn "SPEC_DEVIATION" test/`), das
quais **10 são declarações primárias** e 6 são referências cruzadas. Julgo abaixo
as **7 que pertencem a esta feature**; as demais são das features anteriores.

| Arquivo:linha | Desvio declarado | Substituto oferecido | Honesto? | Melhor possível sem navegador? |
| ------------- | ---------------- | -------------------- | -------- | ------------------------------ |
| `collection_export_link_test.rb:3` | (1) 360px não medível; (2) "controle não aparece ao anônimo" não observável na página de progresso, que redireciona | (1) nenhuma regra nova declara largura fixa, `nowrap` ou `overflow-x`; (2) ausência provada **no catálogo**, onde o anônimo renderiza HTML de fato | ✅ Sim | ✅ Sim — o item (2) é **melhor** que o pedido: asseverar ausência numa página que o anônimo nunca vê provaria o redirect, não a ausência |
| `collection_imports_test.rb:20` | Integração no lugar de system test | Fluxo por requisição HTTP; parser e resolver já provados por unidade | ✅ Sim | ✅ Sim |
| `collection_import_preview_ui_test.rb:3` | (1) 360px; (2) "não é só por cor" exige renderização | (1) auditoria da folha; (2) **portador textual** — cada linha traz `.import-preview__badge` que **nomeia** a classificação; `:380` prova legibilidade sem estilo nenhum | ✅ Sim | ✅ Sim — provar que a cor não é o **único** portador exibindo um portador textual é logicamente suficiente, e é mais forte que medir contraste |
| `collection_import_commit_test.rb:22` | Integração no lugar de system test | Fluxo e efeito; mecânica provada por unidade | ✅ Sim | ✅ Sim |
| `collection_import_commit_test.rb:30` | **Concorrência real** não reproduzível: a suíte roda em transação, duas threads na mesma conexão não são duas transações | Asserção sobre **linhas afetadas** pelo `UPDATE` condicional (`:468`) e sobre o **SQL emitido** (`:492`) | ✅ Sim | ✅ Sim — e é o julgamento mais importante da lista. Provar no nível do statement é **superior** a um teste de corrida *flaky*. A revisão de banco da T14 complementou com **duas conexões reais**, medindo "exatamente um `true`" |
| `collection_import_summary_test.rb:3` | (1) 360px; (2) fluxo por HTTP, não interação | (1) auditoria da folha; (2) efeito conferido **no banco** | ✅ Sim | ✅ Sim |
| `collection_csv_roundtrip_test.rb:4` | (1) sem download/upload por formulário; (2) nenhuma planilha real abre o arquivo no meio | (1) corpo do export reenviado **byte a byte** como `Rack::Test::UploadedFile`; (2) BOM/`;`/aspas cobertos nos Edge Cases do parser (T8) | ✅ Sim | ✅ Sim — o item (2) delimita corretamente: POR-11 fala do arquivo **como o app o gerou** |

**Todos os sete são honestos, e nenhum esconde uma lacuna atrás de "não dá".**
Dois pontos que reforçam esse julgamento:

1. **Os desvios de 360px declaram o próprio limite.** O `set_progress_plan_test.rb:369-374`
   (feature anterior, mesmo padrão) escreve que "uma tabela de muitas colunas, uma
   imagem sem `max-width` ou uma palavra inquebrável estouram 360px sem violar
   nenhuma destas asserções". Declarar o que **não** se prova é a marca de um
   `SPEC_DEVIATION` honesto.
2. **O desvio de concorrência foi complementado, não usado como desculpa.** O
   executor declarou não conseguir avaliar concorrência real; a revisão de banco
   da T14 então **mediu com duas conexões** e reportou o resultado. O buraco foi
   fechado por outro instrumento em vez de aceito.

A dívida estrutural comum — **não há navegador no container** — está registrada
em `CLAUDE.md` e no `STATE.md` desde a `colecao`. Não é dívida desta feature.

---

## Lacunas e achados

### L1 — HIGH (não bloqueante): a resolução pelo par não tem teste discriminante

**O quê.** A mutação M7 (resolver por `variant_code` sozinho) **sobrevive à suíte
inteira**: 771 runs, 0 falhas. Os dois testes escritos para esse critério
(`resolver_test.rb:91` e `:108`) usam **uma linha por arquivo**, e o filtro
`WHERE cards.card_number IN (...)` (`resolver.rb:172-176`) impede a colisão nesse
recorte.

**Por que importa.** É a garantia que a própria `spec.md` destaca como a razão de
a chave ser o par, e o cenário do defeito — arquivo com várias cartas partilhando
`variant_code` — é o **caso normal** do produto: o export real tem centenas de
linhas e os sufixos `_p1`/`_p2` se repetem em todo o catálogo. Reproduzi a escrita
cruzada: linha 0 apontando para a variante da carta errada.

**Por que não bloqueia.** O **código de produção está correto**. Nada está
quebrado hoje; o que falta é proteção contra regressão futura.

**Custo da correção.** Um teste: duas linhas no mesmo lote, duas cartas com o
mesmo `variant_code`, afirmando que cada uma resolve na sua.

**✅ FECHADA pelo orquestrador em `17b3a5b`, depois deste relatório.** Reproduzi
a M7 por conta própria antes de agir — suíte inteira verde com o resolvedor
casando só pelo `variant_code`, confirmando o achado. O teste que faltava está
em `resolver_test.rb:144`, `"duas cartas com o mesmo variant_code no lote
resolvem cada uma na sua"`: duas linhas no mesmo lote, duas cartas partilhando
`_p1`, afirmando que cada uma resolve na variante da **sua** carta e que as
duas não colapsam. Sob a mutação ele falha com `Actual: [6223502, 6223502]` —
as duas linhas na mesma variante. Nenhuma linha de produção alterada: o código
estava certo, faltava a trava. Suíte após o fecho: **772 runs, 3390 assertions,
0 failures**; rubocop **110 files, no offenses**.

### L2 — MEDIUM: o "Done when" da revisão `ecc:pr-test-analyzer` (T16) ficou aberto

O único checkbox não marcado das 17 tasks. O `tasks.md` registra que o executor
não despacha subagente e que ficou para o orquestrador.

**Julgo que ele foi parcialmente exercido e produziu resultado real**: a revisão
de cobertura entre a T16 e a T17 encontrou a lacuna HIGH do branch `falhas.any?`,
fechada por `efb6817` com quatro testes. **Mas a lacuna L1 é exatamente o tipo de
achado que essa revisão deveria produzir e não produziu** — o mesmo padrão
("invariância negativa sem lado positivo" / "cenário mínimo demais para
discriminar") num arquivo diferente. Recomendo fechar a revisão pendente
**mirando `resolver_test.rb`**, não só os arquivos de isolamento.

**✅ FECHADA pelo orquestrador em `786a2d5` e `17b3a5b`, depois deste relatório.**
A revisão foi despachada, confirmou de forma independente que a mutação do dono
da escrita morre na suíte corrigida, e foi interrompida por tempo enquanto
refinava o ponto de injeção; o orquestrador concluiu a auditoria medindo
diretamente. Resultado registrado nas "Decisões da execução" da T16: a mutação
que troca **apenas** o alvo da escrita no `upsert` mata **15 de 72** testes dos
quatro arquivos de isolamento (14 em `collection_import_commit_test`, 1 na
`roundtrip`) — o furo da T16 não se repete ali.

**A recomendação acima estava certa e foi seguida**: mirando `resolver_test.rb`,
a lacuna L1 foi reproduzida e fechada. O checkbox está marcado.

### L3 — MEDIUM: falha parcial de gravação não é recuperável depois de fechar a aba

Decisão **explícita** do dono do produto, registrada na T15: o `Result` não é
persistido. Quem fecha a aba não descobre mais quais linhas falharam.

**Julgo que o Req. 10.4 continua atendido, e explico por quê.** O requisito diz:
*"AO final da importação o sistema DEVE apresentar um resumo com linhas
importadas, atualizadas e rejeitadas, com o motivo de cada rejeição."* O texto é
sobre **apresentar ao final da importação**, e é o que a resposta da confirmação
faz. Ele não pede persistência nem consulta posterior. Além disso, a categoria em
risco é **falha de gravação**, que não é nenhuma das três que o Req. 10.4 nomeia —
é acidente de escrita (Req. 10.3), e a T15 acertou em exibi-la em **bloco
separado** da rejeição.

**Fica como dívida, não como defeito.** A mitigação existente é boa: o branch
agora tem cobertura (`efb6817`), a linha falhada é identificada por número no
arquivo, `card_number` e `variant_code` (`summary_test.rb:553`), e os dois avisos
são semanticamente distintos (`:592`).

### L4 — LOW: `statement_timeout` não configurado; 10.000 linhas medidas em 6,94s

Registrado pela revisão de banco da T14 como MEDIUM, sem ação por ser configuração
de ambiente. Rebaixo para LOW **nesta feature** (nada aqui o causa nem o resolve),
mas confirmo a dívida: **falta confirmar que 6,94s cabem no timeout de proxy de
produção**. Se não couberem, a saída medida já está escrita (lista por
`VALUES`/`unnest`, ou import assíncrono — com medição).

### L5 — LOW: a regressão `confirmado → pendente` continua possível por SQL direto

Meu ataque **A7** confirma o LOW da T11: forçar o status de volta por
`update_column` permite reivindicar de novo. **Não é escalável por HTTP** — não
existe action que escreva `status`, e o único caminho que o toca é o `UPDATE`
condicional. Além disso, o efeito observado foi **nulo**: a segunda gravação é
idempotente sob AD-006 (as linhas já estavam no valor final). Concordo em deixar
sem ação; um `CHECK` de transição exigiria trigger.

### L6 — LOW: sem `CHECK` de `jsonb_array_length(linhas) <= 10000` no banco

Registrado na T11 e **mitigado na T14** pelo teto defensivo em `Commit#gravar`
(`commit.rb:238-242`, testado em `commit_test.rb:736`). Com a mitigação, o risco
residual é só de regressão futura. Sem ação.

### Não é lacuna: a ausência de `ecc:database-reviewer`/`a11y-architect` em algumas tasks

Três tasks (T11, T13, T14) registram que a revisão foi feita **pelo executor** e
não por subagente, e duas delas registram **depois** uma revisão por subagente
que encontrou coisas que o executor não achou (o CRITICAL do `rescue` estreito na
T14; o MEDIUM do `status` na T11). O processo funcionou: o autor revisou, o
subagente revisou por cima, e o subagente **achou mais**. Registro como
observação positiva sobre o método, não como lacuna.

---

## Success Criteria da spec.md

| # | Critério | Evidência | Result |
| - | -------- | --------- | ------ |
| 1 | Usuário exporta, edita em planilha e reimporta vendo antes o que vai mudar | Export `collection_exports_test.rb:112`; preview `preview_ui_test.rb:159`; confirmação `commit_test.rb:152`. Fluxo completo em `roundtrip_test.rb` | ✅ PASS |
| 2 | Teste prova que reimportar o próprio export não altera a coleção | `roundtrip_test.rb:178`, `:197` (três ciclos), `:213` (byte a byte) | ✅ PASS |
| 3 | Teste prova que abandonar após a pré-visualização deixa intacto | `commit_test.rb:306`; `collection_imports_test.rb:147-149`, `:159` | ✅ PASS |
| 4 | Teste prova que variante inexistente é rejeitada com motivo e as demais entram | `resolver_test.rb:130`; `commit_test.rb:191` | ✅ PASS |
| 5 | Teste prova que dois usuários importando o mesmo arquivo mantêm coleções independentes | `roundtrip_test.rb:359`, `:391`, `:464` | ✅ PASS |
| 6 | Teste prova que o import resolve pelo par, não pelo nome | `resolver_test.rb:73` (nome diverge → resolve); `:91`, `:108` (par) | ⚠️ **PASS parcial** — o "não pelo nome" está travado; o "pelo **par**" **não discrimina** (L1) |
| 7 | Suíte roda doze vezes sem falha intermitente | 12/12 registradas na T3; **3/3 na minha sessão** | ✅ PASS |
| 8 | `bin/rails test` passa inteiro, sem alteração de asserção existente | **771 runs, 0 failures**, medido por mim. A única asserção alterada (`assert_response :redirect` → `:success`) é consequência declarada do PRG e está justificada | ✅ PASS |
| 9 | `bin/rubocop` limpo | **110 files, no offenses**, medido por mim | ✅ PASS |

---

## Conclusão

A feature **cumpre o que a spec pede**. A invariante central — *nenhuma escrita
na coleção sem confirmação explícita do usuário* (Req. 10.5) — resistiu a **19
tentativas de ataque** em duas camadas, e resistiu por **construção**, não por
sorte: existe um único ponto de escrita, alcançável por um único caminho, atrás
de um `UPDATE` condicional que resolve a corrida no banco. O dono da escrita vem
sempre da sessão e nunca do dado do staging, o que é o que faz o ataque mais
criativo que montei (A4 — staging adulterado com linhas de outra coleção)
terminar escrevendo na coleção do próprio atacante.

O achado que levo como mais valioso é **L1**: a mutação que a própria spec nomeia
como o risco a evitar — resolver por `variant_code` sozinho — **sobrevive à suíte
inteira**, porque os dois testes escritos para ela usam um arquivo de uma linha e
o filtro da consulta mascara a colisão nesse recorte. O código está certo; a
garantia não está travada. É o mesmo padrão que a T16 encontrou no `Commit`,
vivo em outro arquivo — e é por isso que o briefing mandava procurá-lo.

Nenhuma lacuna bloqueia. A L1 é defeito de **teste**, não de produção, e se fecha
com um teste de duas linhas.

**146 critérios verificados. PASS: 146. FAIL: 0.**
(144 PASS plenos e 2 PASS com ressalva registrada — critério 4 da história "Import
linha a linha" e Success Criterion 6, ambos apontando para L1.)

**Árvore de trabalho ao final**: limpa. `git status --porcelain` **vazio**; os 6
arquivos de produção mutados conferidos **idênticos por `md5sum`** contra as
cópias de backup; todos os artefatos de sonda removidos; **zero resíduo** no banco
de teste, comprovado por consulta (`CardSet` com meus prefixos = 0, `User` com
`@x.test` = 0, `CollectionImport` = 0).

### O que eu não consegui verificar neste ambiente

1. **Concorrência real de duas requisições HTTP simultâneas.** A suíte roda dentro
   de uma transação. Verifiquei o mecanismo (statement condicional, linhas
   afetadas) e a sequência; a revisão de banco da T14 mediu com duas conexões, mas
   isso é resultado **herdado**, não medido por mim.
2. **As doze execuções da T3.** Rodei a suíte **três vezes** (verde nas três), não
   doze. Custo de tempo; e AD-010 exige série, o que impede paralelizar.
3. **Qualquer coisa que exija navegador**: scroll horizontal real em 360px,
   contraste computado, foco pintado, aplicação do Turbo ao DOM. É a dívida
   estrutural registrada em `CLAUDE.md`, não desta feature.
4. **O lote máximo de AD-008 (10.000 linhas) de ponta a ponta.** Deliberadamente
   não o rodei: a medição anterior desse lote foi o que deixou um `CardSet` órfão
   e quebrou 9 testes de outras features. Aceito a extrapolação registrada.
5. **Comportamento sob timeout de proxy de produção** (L4) — não há produção aqui.
